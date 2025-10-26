import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class TranslationService {
  static final TranslationService instance = TranslationService._internal();
  factory TranslationService() => instance;
  TranslationService._internal();

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final String apiKey = dotenv.env['API_KEY'] ?? '';
  
  final Map<String, String> memoryCache = {};
  
  final Map<String, String> filipinoAllergenMap = {
    'hipon': 'shrimp',
    'alamang': 'shrimp',
    'isda': 'fish',
    'gatas': 'milk',
    'itlog': 'egg',
    'mani': 'peanut',
    'kasuy': 'cashew',
    'toyo': 'soy',
    'trigo': 'wheat',
    'harina': 'wheat',
    'alimango': 'crab',
    'talaba': 'oyster',
    'tahong': 'mussel',
    'halaan': 'clam',
    'pusit': 'squid',
    'niyog': 'coconut',
    'gata': 'coconut milk',
    'bagoong': 'shrimp paste',
    'patis': 'fish sauce',
    'tuna': 'tuna',
    'bangus': 'milkfish',
    'galunggong': 'mackerel',
    'tilapia': 'tilapia',
    'maya-maya': 'red snapper',
    'lapu-lapu': 'grouper',
    'tanigue': 'spanish mackerel',
    'dilis': 'anchovies',
    'sardinas': 'sardines',
    'keso': 'cheese',
    'mantikilya': 'butter',
    'mantika': 'oil',
    'asukal': 'sugar',
    'asin': 'salt',
    'paminta': 'pepper',
    'bawang': 'garlic',
    'sibuyas': 'onion',
  };

  Future<String> translateToEnglish(String tagalogWord) async {
    if (tagalogWord.isEmpty) return tagalogWord;

    String normalizedWord = tagalogWord.toLowerCase().trim();

    if (filipinoAllergenMap.containsKey(normalizedWord)) {
      return filipinoAllergenMap[normalizedWord]!;
    }

    if (memoryCache.containsKey(normalizedWord)) {
      return memoryCache[normalizedWord]!;
    }

    try {
      final cachedTranslation = await getCachedTranslation(normalizedWord);
      
      if (cachedTranslation != null) {
        memoryCache[normalizedWord] = cachedTranslation;
        return cachedTranslation;
      }

      final aiTranslation = await getAITranslation(normalizedWord);
      
      if (aiTranslation != null && aiTranslation.isNotEmpty) {
        await saveCachedTranslation(normalizedWord, aiTranslation);
        memoryCache[normalizedWord] = aiTranslation;
        return aiTranslation;
      }

      return tagalogWord;
    } catch (e) {
      print('Translation error for "$tagalogWord": $e');
      return tagalogWord;
    }
  }

  Future<bool> areTermsEquivalent(String term1, String term2) async {
    String normalized1 = term1.toLowerCase().trim();
    String normalized2 = term2.toLowerCase().trim();
    
    if (normalized1 == normalized2) return true;
    
    String translated1 = await translateToEnglish(normalized1);
    String translated2 = await translateToEnglish(normalized2);
    
    if (translated1 == translated2) return true;
    
    if (translated1.contains(translated2) || translated2.contains(translated1)) return true;
    
    String? filipino1 = filipinoAllergenMap[normalized1];
    String? filipino2 = filipinoAllergenMap[normalized2];
    
    if (filipino1 != null && (filipino1 == normalized2 || filipino1 == translated2)) return true;
    if (filipino2 != null && (filipino2 == normalized1 || filipino2 == translated1)) return true;
    
    return false;
  }

  Future<bool> doesIngredientContainAllergen(String ingredient, String allergen) async {
    String normalizedIngredient = ingredient.toLowerCase().trim();
    String normalizedAllergen = allergen.toLowerCase().trim();
    
    if (normalizedIngredient.contains(normalizedAllergen)) return true;
    
    String translatedAllergen = await translateToEnglish(normalizedAllergen);
    if (normalizedIngredient.contains(translatedAllergen)) return true;
    
    if (normalizedIngredient.contains('paste') || 
        normalizedIngredient.contains('sauce') ||
        normalizedIngredient.contains('powder') ||
        normalizedIngredient.contains('oil')) {
      List<String> words = normalizedIngredient.split(' ');
      for (String word in words) {
        if (await areTermsEquivalent(word, normalizedAllergen)) {
          return true;
        }
      }
    }
    
    return false;
  }

  Future<Map<String, String>> translateBatch(List<String> words) async {
    Map<String, String> translations = {};
    
    List<String> wordsToTranslate = [];
    for (String word in words) {
      String normalized = word.toLowerCase().trim();
      
      if (filipinoAllergenMap.containsKey(normalized)) {
        translations[word] = filipinoAllergenMap[normalized]!;
        continue;
      }
      
      if (memoryCache.containsKey(normalized)) {
        translations[word] = memoryCache[normalized]!;
      } else {
        wordsToTranslate.add(word);
      }
    }

    if (wordsToTranslate.isEmpty) {
      return translations;
    }

    try {
      final batchTranslations = await getAIBatchTranslation(wordsToTranslate);
      
      for (var entry in batchTranslations.entries) {
        String normalized = entry.key.toLowerCase().trim();
        translations[entry.key] = entry.value;
        memoryCache[normalized] = entry.value;
        
        await saveCachedTranslation(normalized, entry.value);
      }
    } catch (e) {
      print('Batch translation error: $e');
      
      for (String word in wordsToTranslate) {
        translations[word] = word;
      }
    }

    return translations;
  }

  Future<String?> getCachedTranslation(String tagalogWord) async {
    try {
      final doc = await firestore
          .collection('translations')
          .doc(tagalogWord)
          .get();

      if (doc.exists) {
        final data = doc.data();
        return data?['english'] as String?;
      }
      return null;
    } catch (e) {
      print('Error fetching cached translation: $e');
      return null;
    }
  }

  Future<void> saveCachedTranslation(String tagalogWord, String englishWord) async {
    try {
      await firestore.collection('translations').doc(tagalogWord).set({
        'tagalog': tagalogWord,
        'english': englishWord,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving translation cache: $e');
    }
  }

  Future<String?> getAITranslation(String tagalogWord) async {
    if (apiKey.isEmpty || apiKey == 'YOUR_API_KEY_HERE') {
      return null;
    }

    try {
      final model = GenerativeModel(model: 'gemini-2.0-flash-exp', apiKey: apiKey);
      
      final prompt = '''
Translate this Filipino/Tagalog food-related word to English.

RULES:
1. Return ONLY the English translation, nothing else
2. If it's already English, return the same word
3. For food allergen names, use standard English allergen terminology
4. Be consistent with common food terms
5. For compound words or phrases, translate to common English equivalent

Word to translate: "$tagalogWord"

Return format: Just the English word or phrase, no explanations.
''';

      final response = await model.generateContent([Content.text(prompt)]);
      String translation = response.text?.trim() ?? tagalogWord;
      
      translation = translation.toLowerCase().trim();
      
      return translation;
    } catch (e) {
      print('AI translation error: $e');
      return null;
    }
  }

  Future<Map<String, String>> getAIBatchTranslation(List<String> words) async {
    if (apiKey.isEmpty || apiKey == 'YOUR_API_KEY_HERE') {
      return {for (var word in words) word: word};
    }

    try {
      final model = GenerativeModel(model: 'gemini-2.0-flash-exp', apiKey: apiKey);
      
      final prompt = '''
Translate these Filipino/Tagalog food-related words to English.

RULES:
1. Return ONLY a JSON object mapping each word to its English translation
2. If already English, keep the same word
3. Use standard English allergen terminology
4. Be consistent with common food terms

Words to translate:
${words.map((w) => '- $w').join('\n')}

Return format (JSON only, no markdown):
{
  "word1": "translation1",
  "word2": "translation2"
}
''';

      final response = await model.generateContent([Content.text(prompt)]);
      String responseText = response.text ?? '';
      
      String cleanResponse = responseText;
      if (responseText.contains('```json')) {
        cleanResponse = responseText.split('```json')[1].split('```')[0];
      } else if (responseText.contains('```')) {
        cleanResponse = responseText.split('```')[1];
      }
      
      final jsonData = json.decode(cleanResponse.trim()) as Map<String, dynamic>;
      
      Map<String, String> translations = {};
      for (var entry in jsonData.entries) {
        translations[entry.key] = entry.value.toString().toLowerCase().trim();
      }
      
      return translations;
    } catch (e) {
      print('AI batch translation error: $e');
      return {for (var word in words) word: word};
    }
  }

  void clearMemoryCache() {
    memoryCache.clear();
  }
}