import 'dart:convert';
import 'dart:io';
import 'package:allergen/screens/feature/scan_screen.dart';
import 'package:allergen/services/translation/translation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class AllergenAnalysis {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseStorage storage = FirebaseStorage.instance;

  Future<Map<String, dynamic>?> checkFoodCache(
    String dishName, {
    File? imageFile,
    String? apiKey,
  }) async {
    try {
      final cacheKey = generateCacheKey(dishName);
      print('Enhanced cache check for: $dishName (cacheKey: $cacheKey)');

      if (imageFile != null) {
        final imageHash = generateImageHash(imageFile);
        if (imageHash.isNotEmpty) {
          final exactImageMatch = await checkExactImageMatch(imageHash);
          if (exactImageMatch != null) {
            print('Level 1: Exact image hash match');
            return {
              ...exactImageMatch,
              'matchType': 'exact_image',
              'matchLevel': 1,
              'fromCache': true,
            };
          } else {
            print('Level 1: No exact image hash match');
          }
        }
      }

      if (imageFile != null && apiKey != null && apiKey.isNotEmpty) {
        print('Level 2: Checking visual similarity...');
        final similarMatch = await checkSimilarFoodImage(
          imageFile,
          apiKey,
          dishName,
        );
        if (similarMatch != null) {
          print(
            'Level 2: Visual similarity match (same dish, different angle)',
          );
          return similarMatch;
        } else {
          print('Level 2: No visual similarity match');
        }
      }

      final cacheKeyMatch = await checkCacheKeyMatch(cacheKey);
      if (cacheKeyMatch != null) {
        print('Level 3: Cache key match');
        return {
          ...cacheKeyMatch,
          'matchType': 'cache_key',
          'matchLevel': 3,
          'fromCache': true,
        };
      } else {
        print(' Level 3: No cache key match');
      }

      print(' No cache match found at any level');
      return null;
    } catch (e) {
      print(' Error in enhanced cache check: $e');
      return null;
    }
  }

  String generateCacheKey(String dishName) {
    String original = dishName.toLowerCase().trim();
    original = original.replaceAll(RegExp(r'\([^)]*\)'), '').trim();

    String mainProtein = extractMainProtein(original);

    String normalized =
        original
            .replaceAll(
              RegExp(
                r'\b(filipino|pinoy|style|traditional|classic|homemade|authentic|special|deluxe|premium|original|eggplant|omelet|omelette)\b',
              ),
              '',
            )
            .replaceAll(
              RegExp(r'\b(fried|grilled|roasted|steamed|boiled|stewed)\b'),
              '',
            )
            .replaceAll(RegExp(r'\b(with|and)\b'), '')
            .replaceAll(RegExp(r'[^\w\s]'), '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

    if (mainProtein.isNotEmpty) {
      normalized =
          normalized.replaceAll(RegExp('\\b$mainProtein\\b'), '').trim();
      normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
    }

    String baseDish = normalizeDishName(normalized);

    if (mainProtein.isNotEmpty) {
      return '${mainProtein}_$baseDish';
    }

    return baseDish;
  }

  String extractMainProtein(String dishName) {
    final List<Map<String, dynamic>> proteinKeywords = [
      {
        'keywords': ['seafood', 'mixed seafood'],
        'value': 'seafood',
      },
      {
        'keywords': ['shrimp', 'hipon', 'prawn'],
        'value': 'shrimp',
      },
      {
        'keywords': ['fish', 'isda', 'tilapia', 'bangus', 'galunggong'],
        'value': 'fish',
      },
      {
        'keywords': ['crab', 'alimango'],
        'value': 'crab',
      },
      {
        'keywords': ['squid', 'pusit', 'calamari'],
        'value': 'squid',
      },
      {
        'keywords': ['mussel', 'tahong'],
        'value': 'mussel',
      },
      {
        'keywords': ['clam', 'halaan'],
        'value': 'clam',
      },
      {
        'keywords': ['oyster', 'talaba'],
        'value': 'oyster',
      },
      {
        'keywords': ['chicken', 'manok'],
        'value': 'chicken',
      },
      {
        'keywords': ['pork', 'baboy'],
        'value': 'pork',
      },
      {
        'keywords': ['beef', 'baka'],
        'value': 'beef',
      },
      {
        'keywords': ['oxtail', 'buntot'],
        'value': 'oxtail',
      },
      {
        'keywords': ['tripe', 'goto', 'tuwalya'],
        'value': 'tripe',
      },
      {
        'keywords': ['goat', 'kambing'],
        'value': 'goat',
      },
      {
        'keywords': ['lamb', 'tupa'],
        'value': 'lamb',
      },
      {
        'keywords': ['vegetable', 'gulay', 'veggie'],
        'value': 'vegetable',
      },
      {
        'keywords': ['mushroom', 'kabute'],
        'value': 'mushroom',
      },
    ];

    String cleaned = dishName.toLowerCase().trim();

    for (var protein in proteinKeywords) {
      List<String> keywords = protein['keywords'] as List<String>;
      for (String keyword in keywords) {
        if (cleaned.contains(keyword)) {
          return protein['value'] as String;
        }
      }
    }

    return '';
  }

  String normalizeDishName(String dishName) {
    final Map<String, List<String>> dishVariations = {
      'kare_kare': ['kare kare', 'karekare', 'kare-kare', 'kare kareng'],
      'adobo': ['adobo', 'adobong'],
      'sinigang': ['sinigang', 'sinigang na', 'singang'],
      'afritada': ['afritada', 'apritada', 'afridata'],
      'menudo': ['menudo', 'minudo'],
      'sinanglaw': ['sinanglaw', 'sinanglao'],
      'pinaitan': ['pinaitan', 'papaitan', 'piniatan'],
      'caldereta': ['caldereta', 'kaldereta', 'calderetang'],
      'mechado': ['mechado', 'mitšado', 'mechadong'],
      'bistek': ['bistek', 'bistik', 'bistek tagalog'],
      'tocino': ['tocino', 'tutsino', 'tocinong'],
      'longganisa': ['longganisa', 'longanisa'],
      'tapsilog': ['tapsilog', 'tapa', 'tapang'],
      'ginataang': ['ginataang', 'ginataan'],
      'dinuguan': ['dinuguan', 'dinardaraan', 'tidtad'],
      'sisig': ['sisig', 'sizzling sisig'],
      'lechon': ['lechon', 'litson'],
      'lechon_kawali': ['lechon kawali', 'litson kawali'],
      'lumpia': ['lumpia', 'lumpiang'],
      'pancit_canton': ['pancit canton', 'pansit canton'],
      'pancit_bihon': ['pancit bihon', 'pansit bihon'],
      'pancit': ['pancit', 'pansit'],
      'bicol_express': ['bicol express', 'bicol ekspres'],
      'laing': ['laing', 'natong'],
      'pinakbet': ['pinakbet', 'pakbet'],
      'dinengdeng': ['dinengdeng', 'inabraw'],
      'bulalo': ['bulalo', 'bone marrow soup'],
      'nilaga': ['nilaga', 'nilagang'],
      'tinola': ['tinola', 'tinolang'],
      'arroz_caldo': ['arroz caldo', 'aroskaldo', 'lugaw'],
      'goto': ['goto'],
      'champorado': ['champorado', 'tsampurado'],
      'halo_halo': ['halo halo', 'halohalo', 'halo-halo'],
      'leche_flan': ['leche flan', 'letse flan', 'flan'],
      'ube_halaya': ['ube halaya', 'halayang ube'],
      'bibingka': ['bibingka', 'bibingkang'],
      'puto': ['puto', 'putong'],
      'turon': ['turon', 'turong', 'banana lumpia'],
      'ukoy': ['ukoy', 'okoy'],
      'kwek_kwek': ['kwek kwek', 'kwek-kwek', 'tokneneng'],
      'isaw': ['isaw'],
      'chocolate_cake': ['chocolate cake', 'choco cake'],
      'sans_rival': ['sans rival', 'sansrival', 'sans-rival'],
      'silvanas': ['silvanas', 'silvana', 'sylvanas'],
      'tortang_talong': [
        'tortang talong',
        'torta talong',
        'tortang talong filipino eggplant omelet',
        'tortang talong eggplant omelet',
        'eggplant omelet',
        'talong omelet',
      ],
    };

    String cleaned = dishName.toLowerCase().trim();

    for (var entry in dishVariations.entries) {
      String baseKey = entry.key;
      List<String> variations = entry.value;

      for (String variation in variations) {
        if (cleaned == variation ||
            cleaned.startsWith('$variation ') ||
            cleaned.endsWith(' $variation') ||
            cleaned.contains(' $variation ')) {
          return baseKey;
        }
      }
    }

    return cleaned.replaceAll(RegExp(r'\s+'), '_');
  }

  Future<Map<String, dynamic>?> checkSimilarFoodImage(
    File imageFile,
    String apiKey,
    String currentDishName,
  ) async {
    try {
      final querySnapshot =
          await firestore
              .collection('food_cache')
              .where('thumbnailUrl', isNull: false)
              .orderBy('timestamp', descending: true)
              .limit(15)
              .get();

      if (querySnapshot.docs.isEmpty) {
        print('No cached images found for comparison');
        return null;
      }

      final currentImageBytes = await imageFile.readAsBytes();
      final model = GenerativeModel(
        model: 'gemini-2.0-flash-exp',
        apiKey: apiKey,
      );

      for (var doc in querySnapshot.docs) {
        final cachedData = doc.data();
        final cachedImageUrl = cachedData['thumbnailUrl'] as String?;
        final cachedDishName = cachedData['dishName'] as String? ?? 'Unknown';

        if (cachedImageUrl == null || cachedImageUrl.isEmpty) {
          continue;
        }

        try {
          final ref = storage.refFromURL(cachedImageUrl);
          final cachedImageBytes = await ref.getData();
          if (cachedImageBytes == null) continue;

          final comparisonPrompt = '''
You are an expert food image comparison AI. Compare these two images to determine if they show THE SAME DISH (possibly from different angles).

COMPARISON RULES:
1. ACCEPT (confidence 0.80+) if:
   - Same base dish (e.g., both are Pork Menudo, Chicken Adobo, Seafood Paella)
   - Same main protein and key ingredients visible
   - Same visual characteristics (sauce color, texture, consistency)
   - Different angles, lighting, or plating are OK
   - Minor garnish differences are OK

2. REJECT (confidence <0.75) if:
   - Different base dishes
   - Different main proteins
   - Significantly different visual appearance

CURRENT DISH NAME: $currentDishName
CACHED DISH NAME: $cachedDishName

Return ONLY JSON:
{
  "isSameDish": true/false,
  "confidence": 0.XX,
  "reasoning": "Brief explanation"
}
''';

          final response = await model.generateContent([
            Content.multi([
              TextPart(comparisonPrompt),
              TextPart("CACHED IMAGE:"),
              DataPart('image/jpeg', cachedImageBytes),
              TextPart("CURRENT IMAGE:"),
              DataPart('image/jpeg', currentImageBytes),
            ]),
          ]);

          final comparisonResult = parseComparisonResponse(response.text ?? '');
          final confidence = comparisonResult['confidence'];
          final isSameDish = comparisonResult['isSameDish'] == true;

          print(
            'Comparison result for $cachedDishName: confidence=$confidence, isSameDish=$isSameDish',
          );

          if (isSameDish && confidence >= 0.75) {
            print('Visual similarity detected (confidence: $confidence)');

            await firestore.collection('food_cache').doc(doc.id).update({
              'lastAccessed': FieldValue.serverTimestamp(),
              'accessCount': FieldValue.increment(1),
              'lastMatchConfidence': confidence,
              'lastMatchDate': DateTime.now().toIso8601String(),
            });

            return {
              ...cachedData,
              'fromCache': true,
              'matchType': 'visual_similarity',
              'matchLevel': 2,
              'matchConfidence': confidence,
              'matchReasoning': comparisonResult['reasoning'],
            };
          }
        } catch (e) {
          print('Error comparing with cached image: $e');
          continue;
        }
      }

      return null;
    } catch (e) {
      print('Error in visual similarity check: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> checkExactImageMatch(String imageHash) async {
    try {
      final querySnapshot =
          await firestore
              .collection('food_cache')
              .where('imageHash', isEqualTo: imageHash)
              .limit(1)
              .get();

      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data();

        firestore
            .collection('food_cache')
            .doc(querySnapshot.docs.first.id)
            .update({
              'lastAccessed': FieldValue.serverTimestamp(),
              'accessCount': FieldValue.increment(1),
            })
            .catchError((e) => print('Error updating cache stats: $e'));

        return data;
      }

      return null;
    } catch (e) {
      print('Error checking exact image match: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> checkCacheKeyMatch(String cacheKey) async {
    try {
      final doc = await firestore.collection('food_cache').doc(cacheKey).get();

      if (doc.exists) {
        print('Found cache key match for: $cacheKey');

        firestore
            .collection('food_cache')
            .doc(cacheKey)
            .update({
              'lastAccessed': FieldValue.serverTimestamp(),
              'accessCount': FieldValue.increment(1),
            })
            .catchError((e) => print('Error updating cache stats: $e'));

        return doc.data();
      }

      return null;
    } catch (e) {
      print('Error checking cache key match: $e');
      return null;
    }
  }

  String generateImageHash(File imageFile) {
    try {
      final bytes = imageFile.readAsBytesSync();
      final digest = sha256.convert(bytes);
      return digest.toString();
    } catch (e) {
      print('Error generating image hash: $e');
      return '';
    }
  }

  Map<String, dynamic> parseComparisonResponse(String response) {
    try {
      String cleanResponse = response;
      if (response.contains('```json')) {
        cleanResponse = response.split('```json')[1].split('```')[0];
      } else if (response.contains('```')) {
        cleanResponse = response.split('```')[1];
      }

      final parsed = json.decode(cleanResponse.trim());

      return {
        'isSameDish': parsed['isSameDish'] ?? false,
        'confidence': (parsed['confidence'] ?? 0.0).toDouble(),
        'reasoning': parsed['reasoning'] ?? 'No reasoning provided',
      };
    } catch (e) {
      print('Error parsing comparison response: $e');
      return {
        'isSameDish': false,
        'confidence': 0.0,
        'reasoning': 'Failed to parse comparison',
      };
    }
  }

  Future<void> saveFoodCache(
    String dishName,
    String description,
    List<String> ingredients,
    List<dynamic> allergens, {
    IngredientBenefitsMap? ingredientBenefitsMap,
    File? imageFile,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final cacheKey = generateCacheKey(dishName);
      print(' Saving to global cache with key: $cacheKey');

      String? imageHash;
      String? thumbnailUrl;

      if (imageFile != null) {
        imageHash = generateImageHash(imageFile);

        try {
          final thumbnailFileName =
              'food_thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final thumbnailRef = storage
              .ref()
              .child('food_thumbnails')
              .child('global')
              .child(thumbnailFileName);

          await thumbnailRef.putFile(imageFile);
          thumbnailUrl = await thumbnailRef.getDownloadURL();
          print('Thumbnail uploaded successfully');
        } catch (e) {
          print('Error uploading thumbnail: $e');
        }
      }

      Map<String, dynamic> cacheData = {
        'dishName': dishName,
        'description': description,
        'ingredients': ingredients,
        'allergens': allergens.map((a) => a is Map ? a : a.toJson()).toList(),
        'timestamp': FieldValue.serverTimestamp(),
        'lastAccessed': FieldValue.serverTimestamp(),
        'cacheKey': cacheKey,
        'accessCount': 1,
        'createdBy': user.uid,
      };

      if (imageHash != null) {
        cacheData['imageHash'] = imageHash;
      }
      if (thumbnailUrl != null) {
        cacheData['thumbnailUrl'] = thumbnailUrl;
      }

      if (ingredientBenefitsMap != null) {
        Map<String, String> benefitsToSave = {};
        for (String ingredient in ingredients) {
          String? benefit = ingredientBenefitsMap.getBenefit(ingredient);
          if (benefit != null && benefit.isNotEmpty) {
            benefitsToSave[ingredient] = benefit;
          }
        }
        cacheData['ingredientBenefits'] = benefitsToSave;
      }

      await firestore
          .collection('food_cache')
          .doc(cacheKey)
          .set(cacheData, SetOptions(merge: true));

      print(
        'Food analysis cached successfully to global collection: $cacheKey',
      );
    } catch (e) {
      print('Error saving food cache: $e');
    }
  }

  Future<Map<String, dynamic>> getUserAllergenData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {'names': <String>[], 'severity': <String, double>{}};
      }
      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('profile')
              .where('type', isEqualTo: 'allergen')
              .get();

      List<String> userAllergens = [];
      Map<String, double> allergenSeverity = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final allergenName =
            data['name']?.toString().toLowerCase().trim() ?? '';
        final severity = (data['severity'] ?? 0.5).toDouble();
        if (allergenName.isNotEmpty) {
          userAllergens.add(allergenName);
          allergenSeverity[allergenName] = severity;
        }
      }
      return {'names': userAllergens, 'severity': allergenSeverity};
    } catch (e) {
      print('Error fetching user allergen data: $e');
      return {'names': <String>[], 'severity': <String, double>{}};
    }
  }

  Future<Map<String, dynamic>> parseAllergenResponse(String response) async {
    try {
      String cleanResponse = response;
      if (response.contains('```json')) {
        cleanResponse = response.split('```json')[1].split('```')[0];
      } else if (response.contains('```')) {
        cleanResponse = response.split('```')[1];
      }
      return json.decode(cleanResponse.trim());
    } catch (e) {
      print('Error parsing allergen response: $e');
      return {'allergens': []};
    }
  }

  Future<List<IngredientColorInfo>> computeIngredientColors(
    List<String> ingredients,
    List<AllergenInfo> allergens,
  ) async {
    final allergenData = await getUserAllergenData();
    Map<String, double> userAllergenSeverity = Map<String, double>.from(
      allergenData['severity'],
    );

    Map<String, double> translatedSeverity = {};
    for (var entry in userAllergenSeverity.entries) {
      String tagalogName = entry.key;
      String englishName = await TranslationService.instance.translateToEnglish(
        tagalogName,
      );
      translatedSeverity[englishName.toLowerCase().trim()] = entry.value;
      translatedSeverity[tagalogName.toLowerCase().trim()] = entry.value;
    }

    List<IngredientColorInfo> computedIngredientColors = [];

    for (String ingredient in ingredients) {
      double maxSeverity = -1.0;
      List<String> matchedAllergens = [];
      String lowerIngredient = ingredient.toLowerCase().trim();

      for (AllergenInfo allergenInfo in allergens) {
        bool isSourceMatch = allergenInfo.sources.any(
          (source) =>
              isIngredientMatch(lowerIngredient, source.toLowerCase().trim()),
        );

        if (isSourceMatch) {
          String allergenName = allergenInfo.name.toLowerCase();

          String? matchedUserAllergen = await findMatchingUserAllergen(
            allergenName,
            translatedSeverity.keys.toList(),
          );

          if (matchedUserAllergen != null) {
            double severity = translatedSeverity[matchedUserAllergen]!;
            if (severity > maxSeverity) {
              maxSeverity = severity;
              matchedAllergens = [allergenInfo.name];
            } else if (severity == maxSeverity) {
              matchedAllergens.add(allergenInfo.name);
            }
          }
        }
      }

      Color ingredientColor;
      if (maxSeverity == -1.0) {
        ingredientColor = const Color(0xFFDFDFDF);
      } else if (maxSeverity < 0.33) {
        ingredientColor = Colors.green;
      } else if (maxSeverity < 0.67) {
        ingredientColor = Colors.orange;
      } else {
        ingredientColor = Colors.red;
      }

      computedIngredientColors.add(
        IngredientColorInfo(
          ingredient: ingredient,
          color: ingredientColor,
          severity: maxSeverity == -1.0 ? 0.0 : maxSeverity,
          matchedAllergens: matchedAllergens,
        ),
      );
    }

    return computedIngredientColors;
  }

  bool isIngredientMatch(String ingredient1, String ingredient2) {
    if (ingredient1 == ingredient2) return true;
    String clean1 = cleanIngredientName(ingredient1);
    String clean2 = cleanIngredientName(ingredient2);
    if (clean1 == clean2) return true;

    if (isCompoundWordMismatch(clean1, clean2)) return false;

    if (clean1.contains(clean2) || clean2.contains(clean1)) return true;
    if (isSingularPlural(clean1, clean2)) return true;
    return false;
  }

  String cleanIngredientName(String ingredient) {
    return ingredient
        .toLowerCase()
        .trim()
        .replaceAll(
          RegExp(
            r'\b(powder|paste|sauce|oil|extract|fresh|dried|whole|ground|chopped)\b',
          ),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool isSingularPlural(String word1, String word2) {
    if (word2 == '${word1}s' || word1 == '${word2}s') return true;
    if (word2 == '${word1}es' || word1 == '${word2}es') return true;
    if (word1.endsWith('y') &&
        word2 == '${word1.substring(0, word1.length - 1)}ies')
      return true;
    if (word2.endsWith('y') &&
        word1 == '${word2.substring(0, word2.length - 1)}ies')
      return true;
    return false;
  }

  Future<String?> findMatchingUserAllergen(
    String allergenName,
    List<String> userAllergens,
  ) async {
    String cleanAllergenName = allergenName.toLowerCase().trim();

    for (String userAllergen in userAllergens) {
      String cleanUserAllergen = userAllergen.toLowerCase().trim();

      if (cleanAllergenName == cleanUserAllergen) {
        return userAllergen;
      }

      bool areEquivalent = await TranslationService.instance.areTermsEquivalent(
        cleanAllergenName,
        cleanUserAllergen,
      );
      if (areEquivalent) {
        return userAllergen;
      }

      if (isSingularPlural(cleanAllergenName, cleanUserAllergen)) {
        return userAllergen;
      }

      if (areAllergenSynonyms(cleanAllergenName, cleanUserAllergen)) {
        return userAllergen;
      }
    }

    return null;
  }

  Future<void> updateAllergenHighlighting(List<AllergenInfo> allergens) async {
    final allergenData = await getUserAllergenData();

    Map<String, double> translatedSeverity = {};
    for (var entry
        in (allergenData['severity'] as Map<String, double>).entries) {
      String tagalogName = entry.key;
      String englishName = await TranslationService.instance.translateToEnglish(
        tagalogName,
      );
      translatedSeverity[englishName.toLowerCase().trim()] = entry.value;
      translatedSeverity[tagalogName.toLowerCase().trim()] = entry.value;
    }

    for (AllergenInfo allergen in allergens) {
      String allergenName = allergen.name.toLowerCase().trim();

      String? matchedUserAllergen = await findMatchingUserAllergen(
        allergenName,
        translatedSeverity.keys.toList(),
      );

      allergen.isUserAllergen = matchedUserAllergen != null;
    }
  }

  bool isCompoundWordMismatch(String compound, String part) {
    const List<List<String>> exclusions = [
      ['shrimp', 'shellfish'],
      ['crab', 'shellfish'],
      ['lobster', 'shellfish'],
      ['shellfish', 'fish'],
      ['cashew', 'nut'],
      ['almond', 'nut'],
      ['walnut', 'nut'],
      ['pistachio', 'nut'],
      ['hazelnut', 'nut'],
      ['pecan', 'nut'],
      ['macadamia', 'nut'],
      ['brazil nut', 'nut'],
      ['peanut', 'nut'],
      ['peanuts', 'nut'],
      ['coconut', 'nut'],
      ['nutmeg', 'nut'],
      ['butternut', 'nut'],
      ['chestnut', 'nut'],
      ['water chestnut', 'nut'],
      ['donut', 'nut'],
      ['doughnut', 'nut'],
      ['bagoong', 'fish'],
      ['patis', 'fish'],
      ['fish sauce', 'fish'],
      ['catfish', 'fish'],
      ['fishball', 'fish'],
      ['jellyfish', 'fish'],
      ['starfish', 'fish'],
      ['coconut milk', 'milk'],
      ['almond milk', 'milk'],
      ['soy milk', 'milk'],
      ['oat milk', 'milk'],
      ['rice milk', 'milk'],
      ['eggplant', 'egg'],
      ['eggplant', 'eggs'],
      ['talong', 'egg'],
      ['gata', 'milk'],
      ['buckwheat', 'wheat'],
      ['mushroom', 'room'],
      ['watercress', 'cress'],
      ['butterscotch', 'butter'],
    ];

    for (var pair in exclusions) {
      if (compound == pair[0] && part == pair[1]) return true;
      if (compound == pair[1] && part == pair[0]) return true;
    }
    return false;
  }

  bool areAllergenSynonyms(String allergen1, String allergen2) {
    const Map<String, List<String>> synonymGroups = {
      'milk': ['dairy', 'milk', 'lactose', 'casein', 'whey'],
      'cheese': ['cheese'],
      'yogurt': ['yogurt', 'yoghurt'],
      'butter': ['butter'],
      'cream': ['cream'],
      'egg': ['egg', 'eggs', 'albumin'],
      'peanut': ['peanut', 'peanuts', 'groundnut', 'groundnuts'],
      'fish': ['fish'],
      'tuna': ['tuna'],
      'salmon': ['salmon'],
      'tilapia': ['tilapia'],
      'bangus': ['bangus', 'milkfish'],
      'bagoong': ['bagoong', 'shrimp paste'],
      'patis': ['patis', 'fish sauce'],
      'shellfish': ['shellfish', 'shell fish', 'crustacean', 'crustaceans'],
      'shrimp': ['shrimp', 'shrimps', 'prawn', 'prawns'],
      'crab': ['crab', 'crabs'],
      'lobster': ['lobster', 'lobsters'],
      'wheat': ['wheat', 'gluten'],
      'tofu': ['tofu', 'tokwa'],
      'soy': [
        'soy',
        'soya',
        'soybean',
        'soybeans',
        'soy sauce',
        'soybean oil',
        'toyo',
        'edamame',
        'soy protein',
      ],
      'nuts': ['nuts', 'tree nuts'],
      'cashew': ['cashew', 'cashews'],
      'almond': ['almond', 'almonds'],
      'walnut': ['walnut', 'walnuts'],
      'pistachio': ['pistachio', 'pistachios'],
      'hazelnut': ['hazelnut', 'hazelnuts'],
      'pecan': ['pecan', 'pecans'],
      'sesame': ['sesame', 'sesame seed', 'sesame seeds'],
    };

    for (var group in synonymGroups.values) {
      if (group.contains(allergen1) && group.contains(allergen2)) {
        return true;
      }
    }
    return false;
  }
}
