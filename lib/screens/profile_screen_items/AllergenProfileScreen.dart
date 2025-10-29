import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:allergen/styleguide.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class AllergenProfileScreen extends StatefulWidget {
  const AllergenProfileScreen({Key? key}) : super(key: key);

  @override
  State<AllergenProfileScreen> createState() => _AllergenProfileScreenState();
}

class _AllergenProfileScreenState extends State<AllergenProfileScreen> {
  final TextEditingController searchController = TextEditingController();
  Set<String> selectedAllergens = {};
  Map<String, double> allergenSeverity = {};
  List<String> filteredAllergens = [];
  List<String> usdaIngredients = [];
  List<String> savedAllergens = [];

  Set<String> dictionaryResults = {};
  bool searchedUSDA = false;

  bool isLoading = true;
  bool isSearching = false;
  bool isGeneralProductAllergensEnabled = true;

  Timer? _debounceTimer;

  String GEMINI_API_KEY = dotenv.env['API_KEY'] ?? '';

  static const double MILD = 0.0;
  static const double MODERATE = 0.5;
  static const double SEVERE = 1.0;

  final List<String> commonAllergens = [
    'Shellfish',
    'Sesame',
    'Egg',
    'Peanut',
    'Fish',
    'Milk',
    'Soybean',
    'Shrimp',
    'Nuts',
    'Wheat',
  ];

  final List<String> fdaMajorAllergens = [
    'Milk',
    'Eggs',
    'Fish',
    'Crustacean shellfish',
    'Tree nuts',
    'Peanuts',
    'Wheat',
    'Soybeans',
    'Sesame',
  ];

  @override
  void initState() {
    super.initState();
    filteredAllergens = List.from(commonAllergens);
    loadUserAllergens();
    searchController.addListener(onSearchChanged);
    loadToggleSetting();
    initializeTagalogDictionary();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    searchController.removeListener(onSearchChanged);
    searchController.dispose();
    super.dispose();
  }

  void onSearchChanged() async {
    _debounceTimer?.cancel();

    String searchTerm = searchController.text.trim();

    if (searchTerm.isEmpty) {
      setState(() {
        updateFilteredAllergens();
        isSearching = false;
        usdaIngredients.clear();
        dictionaryResults.clear();
        searchedUSDA = false;
      });
    } else if (searchTerm.length >= 2) {
      setState(() {
        isSearching = true;
      });

      _debounceTimer = Timer(const Duration(seconds: 1), () async {
        if (mounted) {
          String translatedTerm = await translateTagalogToEnglish(searchTerm);
          print(
            'Search: Original: "$searchTerm", Translated: "$translatedTerm"',
          );

          await searchUSDAIngredients(translatedTerm, originalTerm: searchTerm);
        }
      });
    } else {
      setState(() {
        filteredAllergens =
            getAllAllergens()
                .where(
                  (allergen) =>
                      allergen.toLowerCase().contains(searchTerm.toLowerCase()),
                )
                .toList();
        isSearching = false;
        usdaIngredients.clear();
        dictionaryResults.clear();
        searchedUSDA = false;
      });
    }
  }

  Future<void> initializeTagalogDictionary() async {
    try {
      final dictionaryRef = FirebaseFirestore.instance.collection(
        'tagalog_dictionary',
      );

      final Map<String, String> commonTranslations = {
        'hipon': 'shrimp',
        'alamang': 'shrimp paste',
        'bagoong': 'fermented shrimp',
        'pusit': 'squid',
        'tahong': 'mussels',
        'talaba': 'oyster',
        'halaan': 'clams',
        'alimango': 'crab',
        'isda': 'fish',
        'tuyo': 'dried fish',
        'tinapa': 'smoked fish',
        'bangus': 'milkfish',
        'tilapia': 'tilapia',
        'galunggong': 'mackerel',
        'gatas': 'milk',
        'itlog': 'egg',
        'manok': 'chicken',
        'baboy': 'pork',
        'baka': 'beef',
        'keso': 'cheese',
        'mantikilya': 'butter',
        'kape': 'coffee',
        'asukal': 'sugar',
        'asin': 'salt',
        'paminta': 'pepper',
        'bawang': 'garlic',
        'sibuyas': 'onion',
        'luya': 'ginger',
        'sili': 'chili',
        'kamatis': 'tomato',
        'patatas': 'potato',
        'kamote': 'sweet potato',
        'mais': 'corn',
        'palay': 'rice grain',
        'bigas': 'rice',
        'harina': 'flour',
        'trigo': 'wheat',
        'monggo': 'mung bean',
        'sitaw': 'string beans',
        'talong': 'eggplant',
        'kalabasa': 'squash',
        'repolyo': 'cabbage',
        'pechay': 'bok choy',
        'kangkong': 'water spinach',
        'ampalaya': 'bitter gourd',
        'sayote': 'chayote',
        'mani': 'peanut',
        'niyog': 'coconut',
        'langka': 'jackfruit',
        'saging': 'banana',
        'mangga': 'mango',
        'papaya': 'papaya',
        'pinya': 'pineapple',
        'bayabas': 'guava',
        'santol': 'santol',
        'duhat': 'java plum',
        'atis': 'sugar apple',
        'guyabano': 'soursop',
        'kalamansi': 'calamansi',
        'dalandan': 'orange',
        'dalanghita': 'tangerine',
        'ubas': 'grapes',
        'pakwan': 'watermelon',
        'melon': 'melon',
        'peras': 'pear',
        'mansanas': 'apple',
        'prutas': 'fruit',
        'gulay': 'vegetable',
        'karne': 'meat',
        'pagkain': 'food',
        'inumin': 'drink',
        'tubig': 'water',
        'suka': 'vinegar',
        'toyo': 'soy sauce',
        'patis': 'fish sauce',
        'pampalasa': 'seasoning',
        'tanglad': 'lemongrass',
        'dahon ng laurel': 'bay leaf',
        'oregano': 'oregano',
        'rosmarino': 'rosemary',
        'kintsay': 'celery',
        'wansoy': 'cilantro',
        'mustasa': 'mustard',
        'labanos': 'radish',
        'singkamas': 'jicama',
        'ube': 'purple yam',
        'taro': 'taro',
        'gabi': 'taro',
        'kamoteng kahoy': 'cassava',
      };

      print(
        'Starting dictionary initialization with ${commonTranslations.length} entries...',
      );

      WriteBatch batch = FirebaseFirestore.instance.batch();
      int batchCount = 0;
      int totalAdded = 0;

      for (var entry in commonTranslations.entries) {
        final docId = entry.key.toLowerCase().trim();
        final docRef = dictionaryRef.doc(docId);

        final doc = await docRef.get();

        if (!doc.exists) {
          batch.set(docRef, {
            'tagalog': entry.key,
            'english': entry.value,
            'category': 'ingredient',
            'createdAt': FieldValue.serverTimestamp(),
            'source': 'preset',
          });

          batchCount++;
          totalAdded++;

          if (batchCount >= 500) {
            await batch.commit();
            print('Committed batch of $batchCount entries');
            batch = FirebaseFirestore.instance.batch();
            batchCount = 0;
          }
        }
      }

      if (batchCount > 0) {
        await batch.commit();
        print('Committed final batch of $batchCount entries');
      }

      print(
        'Dictionary initialization complete! Added $totalAdded new entries.',
      );
    } catch (e) {
      print('Error initializing dictionary: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error initializing dictionary: ${e.toString()}',
              style: const TextStyle(fontFamily: 'Poppins'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String> translateTagalogToEnglish(String tagalogWord) async {
    try {
      final normalizedWord = tagalogWord.toLowerCase().trim();

      final dictionaryRef = FirebaseFirestore.instance.collection(
        'tagalog_dictionary',
      );
      final doc = await dictionaryRef.doc(normalizedWord).get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['english'] != null) {
          print('Found in dictionary: $tagalogWord -> ${data['english']}');
          return data['english'];
        }
      }

      print('Not found in dictionary, using Gemini AI for: $tagalogWord');
      final translation = await translateWithGemini(tagalogWord);

      if (translation.isNotEmpty && translation != tagalogWord) {
        await dictionaryRef.doc(normalizedWord).set({
          'tagalog': tagalogWord,
          'english': translation,
          'category': 'ingredient',
          'createdAt': FieldValue.serverTimestamp(),
          'source': 'gemini_ai',
        });

        print('Saved new translation: $tagalogWord -> $translation');
        return translation;
      }

      return tagalogWord;
    } catch (e) {
      print('Error in translateTagalogToEnglish: $e');
      return tagalogWord;
    }
  }

  Future<String> translateWithGemini(String tagalogWord) async {
    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=$GEMINI_API_KEY',
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'contents': [
            {
              'parts': [
                {
                  'text':
                      'Translate this Tagalog food ingredient or allergen word to English. '
                      'Only respond with the English translation, nothing else. '
                      'If it\'s already in English or not a food-related word, respond with the original word. '
                      'Word: $tagalogWord',
                },
              ],
            },
          ],
          'generationConfig': {'temperature': 0.1, 'maxOutputTokens': 50},
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final translation =
            data['candidates']?[0]?['content']?['parts']?[0]?['text']?.trim() ??
            '';

        final cleanedTranslation =
            translation.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();

        return cleanedTranslation.isNotEmpty ? cleanedTranslation : tagalogWord;
      } else {
        print('Gemini API error: ${response.statusCode}');
        return tagalogWord;
      }
    } catch (e) {
      print('Error translating with Gemini: $e');
      return tagalogWord;
    }
  }

  List<String> getAllAllergens() {
    Set<String> allAllergens = {};
    allAllergens.addAll(commonAllergens);
    allAllergens.addAll(savedAllergens);
    return allAllergens.toList();
  }

  void clearSearch() {
    _debounceTimer?.cancel();
    searchController.clear();
  }

  void updateFilteredAllergens() {
    filteredAllergens = getAllAllergens();
  }

  Future<void> saveToggleSetting(bool value) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('settings')
            .doc('allergen_display')
            .set({
              'showAllAllergens': value,
              'updatedAt': FieldValue.serverTimestamp(),
            });
      }
    } catch (e) {
      print('Error saving toggle setting: $e');
    }
  }

  Future<void> loadToggleSetting() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot snapshot =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('settings')
                .doc('allergen_display')
                .get();

        if (snapshot.exists) {
          setState(() {
            isGeneralProductAllergensEnabled =
                snapshot['showAllAllergens'] ?? true;
          });
        }
      }
    } catch (e) {
      print('Error loading toggle setting: $e');
    }
  }

  void toggleAllergen(String allergen) {
    setState(() {
      if (selectedAllergens.contains(allergen)) {
        selectedAllergens.remove(allergen);
        allergenSeverity.remove(allergen);
      } else {
        selectedAllergens.add(allergen);
        allergenSeverity[allergen] = MODERATE;
      }
    });
  }

  double snapToDiscreteLevel(double value) {
    if (value < 0.25) return MILD;
    if (value < 0.75) return MODERATE;
    return SEVERE;
  }

  Future<void> searchUSDAIngredients(
    String searchTerm, {
    String? originalTerm,
  }) async {
    setState(() {
      isSearching = true;
      dictionaryResults.clear();
      searchedUSDA = false;
    });

    try {
      Set<String> foundIngredients = {};

      // STEP 1: Search the Tagalog dictionary for exact matches
      print('Step 1: Searching dictionary for "$searchTerm"');
      await searchTagalogDictionary(
        searchTerm,
        foundIngredients,
        exactMatch: true,
      );
      if (originalTerm != null && originalTerm != searchTerm) {
        await searchTagalogDictionary(
          originalTerm,
          foundIngredients,
          exactMatch: true,
        );
      }

      // Store dictionary results
      if (foundIngredients.isNotEmpty) {
        dictionaryResults = Set<String>.from(foundIngredients);
        print('Dictionary results: $dictionaryResults');
      }

      // STEP 2: Search USDA (regardless of dictionary results)
      print('Step 2: Searching USDA for "$searchTerm"');
      String usdaApiKey = dotenv.env['USDA_API_KEY'] ?? '';

      if (usdaApiKey.isNotEmpty) {
        try {
          final response = await http.get(
            Uri.parse(
              'https://api.nal.usda.gov/fdc/v1/foods/search?api_key=$usdaApiKey&query=$searchTerm&pageSize=10',
            ),
          );

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            if (data['foods'] != null && (data['foods'] as List).isNotEmpty) {
              searchedUSDA = true;
              print('USDA returned ${data['foods'].length} results');

              for (var food in data['foods']) {
                String foodName = food['description'] ?? '';
                if (foodName.isNotEmpty) {
                  String cleanedName = cleanIngredientName(foodName);
                  if (cleanedName.length <= 50) {
                    foundIngredients.add(cleanedName);
                  }
                }

                if (food['ingredients'] != null) {
                  String ingredients = food['ingredients'];
                  List<String> extracted = extractPotentialAllergens(
                    ingredients,
                    searchTerm,
                  );
                  foundIngredients.addAll(extracted);
                }
              }
            } else {
              print('USDA returned no results');
            }
          }
        } catch (e) {
          print('Error searching USDA: $e');
        }
      }

      // STEP 3: If USDA returned nothing, translate with AI and search again
      if (!searchedUSDA ||
          (foundIngredients.isEmpty && dictionaryResults.isEmpty)) {
        print(
          'Step 3: No USDA results, checking if Tagalog and translating...',
        );

        String aiTranslation = await translateWithGemini(searchTerm);

        if (aiTranslation.isNotEmpty &&
            aiTranslation.toLowerCase() != searchTerm.toLowerCase()) {
          print('AI translated "$searchTerm" to "$aiTranslation"');

          final normalizedWord = searchTerm.toLowerCase().trim();
          await FirebaseFirestore.instance
              .collection('tagalog_dictionary')
              .doc(normalizedWord)
              .set({
                'tagalog': searchTerm,
                'english': aiTranslation,
                'category': 'ingredient',
                'createdAt': FieldValue.serverTimestamp(),
                'source': 'gemini_ai',
              });

          String formattedTranslation = formatIngredientName(aiTranslation);
          foundIngredients.add(formattedTranslation);
          dictionaryResults.add(formattedTranslation);

          print('Searching USDA again with translation: "$aiTranslation"');
          if (usdaApiKey.isNotEmpty) {
            try {
              final response = await http.get(
                Uri.parse(
                  'https://api.nal.usda.gov/fdc/v1/foods/search?api_key=$usdaApiKey&query=$aiTranslation&pageSize=10',
                ),
              );

              if (response.statusCode == 200) {
                final data = json.decode(response.body);
                if (data['foods'] != null) {
                  searchedUSDA = true;
                  print(
                    'USDA found ${data['foods'].length} results for translation',
                  );
                  for (var food in data['foods']) {
                    String foodName = food['description'] ?? '';
                    if (foodName.isNotEmpty) {
                      String cleanedName = cleanIngredientName(foodName);
                      if (cleanedName.length <= 50) {
                        foundIngredients.add(cleanedName);
                      }
                    }

                    if (food['ingredients'] != null) {
                      String ingredients = food['ingredients'];
                      List<String> extracted = extractPotentialAllergens(
                        ingredients,
                        aiTranslation,
                      );
                      foundIngredients.addAll(extracted);
                    }
                  }
                }
              }
            } catch (e) {
              print('Error searching USDA with translation: $e');
            }
          }
        }
      }

      for (String allergen in fdaMajorAllergens) {
        if (allergen.toLowerCase().contains(searchTerm.toLowerCase())) {
          foundIngredients.add(allergen);
        }
      }

      if (originalTerm != null && originalTerm != searchTerm) {
        for (String allergen in fdaMajorAllergens) {
          if (allergen.toLowerCase().contains(originalTerm.toLowerCase())) {
            foundIngredients.add(allergen);
          }
        }
      }

      await searchTagalogDictionary(
        searchTerm,
        foundIngredients,
        exactMatch: false,
      );
      if (originalTerm != null && originalTerm != searchTerm) {
        await searchTagalogDictionary(
          originalTerm,
          foundIngredients,
          exactMatch: false,
        );
      }

      setState(() {
        usdaIngredients = foundIngredients.toList();

        Set<String> combinedAllergens = {};
        combinedAllergens.addAll(
          getAllAllergens().where(
            (allergen) =>
                allergen.toLowerCase().contains(searchTerm.toLowerCase()) ||
                (originalTerm != null &&
                    allergen.toLowerCase().contains(
                      originalTerm.toLowerCase(),
                    )),
          ),
        );

        if (usdaIngredients.isNotEmpty) {
          filteredAllergens = usdaIngredients;
        } else {
          filteredAllergens = combinedAllergens.toList();
        }

        isSearching = false;
      });

      print('Final results count: ${filteredAllergens.length}');
      print('Dictionary results: ${dictionaryResults.length}');
      print('USDA searched: $searchedUSDA');
    } catch (e) {
      print('Error searching: $e');
      setState(() {
        filteredAllergens =
            getAllAllergens()
                .where(
                  (allergen) =>
                      allergen.toLowerCase().contains(searchTerm.toLowerCase()),
                )
                .toList();
        isSearching = false;
      });
    }
  }

  Future<void> searchTagalogDictionary(
    String searchTerm,
    Set<String> foundIngredients, {
    bool exactMatch = false,
  }) async {
    try {
      final dictionaryRef = FirebaseFirestore.instance.collection(
        'tagalog_dictionary',
      );

      if (exactMatch) {
        final exactDoc =
            await dictionaryRef.doc(searchTerm.toLowerCase().trim()).get();
        if (exactDoc.exists) {
          final data = exactDoc.data() as Map<String, dynamic>?;
          if (data != null && data['english'] != null) {
            String englishWord = data['english'].toString();
            foundIngredients.add(formatIngredientName(englishWord));
          }
        }

        final exactQuery =
            await dictionaryRef
                .where('tagalog', isEqualTo: searchTerm.toLowerCase())
                .get();

        for (var doc in exactQuery.docs) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['english'] != null) {
            String englishWord = data['english'].toString();
            foundIngredients.add(formatIngredientName(englishWord));
          }
        }
      } else {
        final tagalogQuery =
            await dictionaryRef
                .where(
                  'tagalog',
                  isGreaterThanOrEqualTo: searchTerm.toLowerCase(),
                )
                .where(
                  'tagalog',
                  isLessThanOrEqualTo: '${searchTerm.toLowerCase()}\uf8ff',
                )
                .get();

        final englishQuery =
            await dictionaryRef
                .where(
                  'english',
                  isGreaterThanOrEqualTo: searchTerm.toLowerCase(),
                )
                .where(
                  'english',
                  isLessThanOrEqualTo: '${searchTerm.toLowerCase()}\uf8ff',
                )
                .get();

        for (var doc in tagalogQuery.docs) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['english'] != null) {
            String englishWord = data['english'].toString();
            foundIngredients.add(formatIngredientName(englishWord));
          }
        }

        for (var doc in englishQuery.docs) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['english'] != null) {
            String englishWord = data['english'].toString();
            foundIngredients.add(formatIngredientName(englishWord));
          }
        }
      }
    } catch (e) {
      print('Error searching Tagalog dictionary: $e');
    }
  }

  String formatIngredientName(String name) {
    return name
        .split(' ')
        .map(
          (word) =>
              word.isNotEmpty
                  ? word[0].toUpperCase() + word.substring(1).toLowerCase()
                  : '',
        )
        .where((word) => word.isNotEmpty)
        .join(' ');
  }

  List<String> extractPotentialAllergens(String text, String searchTerm) {
    List<String> allergens = [];
    String lowerText = text.toLowerCase();
    String lowerSearchTerm = searchTerm.toLowerCase();

    if (lowerText.contains(lowerSearchTerm)) {
      String cleanedText = cleanIngredientName(text);

      if (cleanedText.isNotEmpty && cleanedText.length <= 50) {
        allergens.add(cleanedText);
      }

      List<String> words = text.split(RegExp(r'[,;()\[\]\s]+'));
      for (String word in words) {
        String cleanWord = cleanIngredientName(word);
        if (cleanWord.toLowerCase().contains(lowerSearchTerm) &&
            cleanWord.length >= 3 &&
            cleanWord.length <= 30) {
          allergens.add(cleanWord);
        }
      }
    }

    return allergens;
  }

  String cleanIngredientName(String text) {
    String cleaned =
        text
            .replaceAll(
              RegExp(
                r'\b(hydrochloride|hcl|sulfate|sodium|mg|mcg|iu)\b',
                caseSensitive: false,
              ),
              '',
            )
            .replaceAll(RegExp(r'[^\w\s-]'), '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

    return cleaned
        .split(' ')
        .map(
          (word) =>
              word.isNotEmpty
                  ? word[0].toUpperCase() + word.substring(1).toLowerCase()
                  : '',
        )
        .where((word) => word.isNotEmpty)
        .join(' ');
  }

  Future<void> loadUserAllergens() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        QuerySnapshot snapshot =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('profile')
                .where('type', isEqualTo: 'allergen')
                .get();

        setState(() {
          selectedAllergens.clear();
          allergenSeverity.clear();
          savedAllergens.clear();

          for (QueryDocumentSnapshot doc in snapshot.docs) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            String allergenName = data['name'] ?? '';
            double severity = (data['severity'] ?? 0.5).toDouble();

            severity = snapToDiscreteLevel(severity);

            if (allergenName.isNotEmpty) {
              selectedAllergens.add(allergenName);
              allergenSeverity[allergenName] = severity;
              savedAllergens.add(allergenName);

              if (!commonAllergens.contains(allergenName)) {
                commonAllergens.add(allergenName);
              }
            }
          }
          updateFilteredAllergens();
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user allergens: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Color getSeverityColor(double severity) {
    if (severity <= MILD) return const Color(0xFF10B981);
    if (severity <= MODERATE) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String getSeverityLabel(double severity) {
    if (severity <= MILD) return 'Mild';
    if (severity <= MODERATE) return 'Moderate';
    return 'Severe';
  }

  void showAllergenModal(String allergen, {bool isManualAdd = false}) {
    double currentSeverity = allergenSeverity[allergen] ?? MODERATE;
    TextEditingController manualAllergenController = TextEditingController();

    if (isManualAdd) {
      manualAllergenController.text = allergen;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setModalState) => Container(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    24,
                    24,
                    MediaQuery.of(context).viewInsets.bottom + 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isManualAdd) ...[
                        const Text(
                          'Manually add your allergen',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Poppins',
                            color: Color(0xFF374151),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: manualAllergenController,
                          decoration: InputDecoration(
                            hintText: 'Enter allergen name',
                            hintStyle: const TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontFamily: 'Poppins',
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFE5E7EB),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.primaryColor3,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ] else ...[
                        Row(
                          children: [
                            Text(
                              allergen,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Poppins',
                                color: Color(0xFF374151),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.info_outline,
                              size: 18,
                              color: Colors.grey.shade600,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],

                      const Text(
                        'How severe is this allergen reaction?',
                        style: TextStyle(
                          fontSize: 16,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Column(
                        children: [
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 8,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 12,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 20,
                              ),
                              activeTrackColor: getSeverityColor(
                                currentSeverity,
                              ),
                              inactiveTrackColor: Colors.grey.shade300,
                              thumbColor: getSeverityColor(currentSeverity),
                              overlayColor: getSeverityColor(
                                currentSeverity,
                              ).withOpacity(0.2),
                              showValueIndicator: ShowValueIndicator.always,
                            ),
                            child: Slider(
                              value: currentSeverity,
                              min: 0.0,
                              max: 1.0,
                              divisions: 2,
                              onChanged: (value) {
                                setModalState(() {
                                  currentSeverity = snapToDiscreteLevel(value);
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Mild',
                                style: TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontSize: 14,
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                'Moderate',
                                style: TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontSize: 14,
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                'Severe',
                                style: TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontSize: 14,
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: getSeverityColor(
                            currentSeverity,
                          ).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: getSeverityColor(currentSeverity),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.warning_rounded,
                              color: getSeverityColor(currentSeverity),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Selected: ${getSeverityLabel(currentSeverity)}',
                              style: TextStyle(
                                color: getSeverityColor(currentSeverity),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            String finalAllergen =
                                isManualAdd
                                    ? manualAllergenController.text.trim()
                                    : allergen;

                            if (finalAllergen.isNotEmpty) {
                              Navigator.of(context, rootNavigator: true).pop();

                              FocusScope.of(context).unfocus();

                              setState(() {
                                selectedAllergens.add(finalAllergen);
                                allergenSeverity[finalAllergen] =
                                    currentSeverity;

                                if (isManualAdd &&
                                    !savedAllergens.contains(finalAllergen)) {
                                  savedAllergens.add(finalAllergen);
                                }
                                if (!commonAllergens.contains(finalAllergen)) {
                                  commonAllergens.add(finalAllergen);
                                }
                                updateFilteredAllergens();
                              });

                              await saveAllergenToFirebase(
                                finalAllergen,
                                currentSeverity,
                              );

                              searchController.clear();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryColor3,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: Text(
                            isManualAdd
                                ? 'Add Allergen'
                                : selectedAllergens.contains(allergen)
                                ? 'Update Severity'
                                : 'Add Allergen',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  Future<void> saveAllergenToFirebase(
    String allergenName,
    double severity,
  ) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        QuerySnapshot existingAllergen =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('profile')
                .where('type', isEqualTo: 'allergen')
                .where('name', isEqualTo: allergenName)
                .get();

        if (existingAllergen.docs.isNotEmpty) {
          await existingAllergen.docs.first.reference.update({
            'severity': severity,
          });
        } else {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('profile')
              .add({
                'name': allergenName,
                'severity': severity,
                'type': 'allergen',
                'createdAt': FieldValue.serverTimestamp(),
                'source':
                    usdaIngredients.contains(allergenName) ? 'USDA' : 'manual',
              });
        }
      }
    } catch (e) {
      print('Error saving allergen: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Error saving allergen. Please try again.',
            style: TextStyle(fontFamily: 'Poppins'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void showRemoveConfirmation(String allergenName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Remove Allergen',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          content: Text(
            'Are you sure you want to remove "$allergenName" from your allergen profile?',
            style: const TextStyle(
              fontFamily: 'Poppins',
              color: Color(0xFF6B7280),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                removeAllergen(allergenName);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Remove',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> removeAllergen(String allergenName) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        QuerySnapshot allergenDocs =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('profile')
                .where('type', isEqualTo: 'allergen')
                .where('name', isEqualTo: allergenName)
                .get();

        for (QueryDocumentSnapshot doc in allergenDocs.docs) {
          await doc.reference.delete();
        }

        setState(() {
          selectedAllergens.remove(allergenName);
          allergenSeverity.remove(allergenName);
          savedAllergens.remove(allergenName);
          updateFilteredAllergens();
        });
      }
    } catch (e) {
      print('Error removing allergen: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Error removing allergen. Please try again.',
            style: TextStyle(fontFamily: 'Poppins'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // NEW: Helper method to build allergen list items with correct badges
  Widget buildAllergenListItem(String allergen) {
    final isSelected = selectedAllergens.contains(allergen);
    final isFromDictionary = dictionaryResults.contains(allergen);
    final isFromUSDA = usdaIngredients.contains(allergen) && !isFromDictionary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppColors.primaryColor3 : const Color(0xFFE5E7EB),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => showAllergenModal(allergen),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        allergen,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Poppins',
                          color:
                              isSelected
                                  ? AppColors.primaryColor3
                                  : const Color(0xFF374151),
                        ),
                      ),
                      if (isFromDictionary) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'DICTIONARY',
                            style: TextStyle(
                              color: Color(0xFF8B5CF6),
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ],
                      if (isFromUSDA) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'USDA',
                            style: TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ],
                      if (isSelected) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: getSeverityColor(
                              allergenSeverity[allergen] ?? MODERATE,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            getSeverityLabel(
                              allergenSeverity[allergen] ?? MODERATE,
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  isSelected ? Icons.check_circle : Icons.add_circle_outline,
                  color:
                      isSelected
                          ? AppColors.primaryColor3
                          : const Color(0xFF9CA3AF),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.defaultbackground,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: const Text(
          'Allergen Profile',
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'General Product Allergens',
                        style: TextStyle(
                          fontSize: 16,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Enable the filter to view all allergens including those affecting you.',
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w400,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isGeneralProductAllergensEnabled,
                  onChanged: (value) {
                    setState(() {
                      isGeneralProductAllergensEnabled = value;
                    });
                    saveToggleSetting(value);
                  },
                  activeColor: const Color(0xFF0EA5E9),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Search for allergens and ingredients',
            style: TextStyle(
              fontSize: 18,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search ingredients... (e.g., alamang, hipon)',
                hintStyle: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 14,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon:
                    isSearching
                        ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primaryColor3,
                              ),
                            ),
                          ),
                        )
                        : const Icon(
                          Icons.search,
                          color: Color(0xFF9CA3AF),
                          size: 20,
                        ),
                suffixIcon:
                    searchController.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(
                            Icons.clear,
                            color: Color(0xFF9CA3AF),
                          ),
                          onPressed: clearSearch,
                          tooltip: 'Clear search',
                        )
                        : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => showAllergenModal('', isManualAdd: true),
              child: const Text(
                'Not here? Manually add',
                style: TextStyle(
                  color: Color(0xFF0EA5E9),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ),
          if (searchController.text.isNotEmpty &&
              filteredAllergens.isNotEmpty) ...[
            const Text(
              'Available Allergens',
              style: TextStyle(
                fontSize: 16,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredAllergens.length,
              itemBuilder: (context, index) {
                final allergen = filteredAllergens[index];
                return buildAllergenListItem(allergen);
              },
            ),
          ],
          const SizedBox(height: 24),
          if (isLoading)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF0EA5E9)),
            )
          else if (selectedAllergens.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(Icons.info_outline, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No allergens added yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Poppins',
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add allergens to help us recommend better products for you',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Poppins',
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            )
          else ...[
            const Text(
              'Your Allergens',
              style: TextStyle(
                fontSize: 16,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 12),
            ...selectedAllergens.map((allergen) {
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => showAllergenModal(allergen),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  allergen,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Poppins',
                                    color: Color(0xFF374151),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: getSeverityColor(
                                      allergenSeverity[allergen] ?? MODERATE,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    getSeverityLabel(
                                      allergenSeverity[allergen] ?? MODERATE,
                                    ),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => showRemoveConfirmation(allergen),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Color(0xFFEF4444),
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
