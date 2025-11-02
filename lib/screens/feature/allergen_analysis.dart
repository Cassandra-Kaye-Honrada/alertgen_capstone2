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
    String cacheKey, {
    File? imageFile,
    String? apiKey,
    List<String>? ingredients,
  }) async {
    try {
      print('Enhanced cache check for: $cacheKey');

      final exactMatch = await checkExactFoodCache(cacheKey);
      if (exactMatch != null) {
        print('Level 1: Exact cache key match');
        return {...exactMatch, 'matchType': 'exact_key', 'matchLevel': 1};
      }

      if (imageFile != null) {
        final imageHash = generateImageHash(imageFile);
        if (imageHash.isNotEmpty) {
          final exactImageMatch = await checkExactImageMatch(imageHash);
          if (exactImageMatch != null) {
            print('Level 2: Exact image hash match');
            return {...exactImageMatch, 'matchType': 'exact_image', 'matchLevel': 2};
          }
        }
      }

      if (imageFile != null && apiKey != null && apiKey.isNotEmpty && ingredients != null) {
        print('Level 3: Checking visual similarity...');
        final similarMatch = await checkSimilarFoodImage(
          imageFile, 
          apiKey, 
          ingredients,
        );
        if (similarMatch != null) {
          print('Level 3: Visual similarity match with smart ingredient merge');
          return similarMatch;
        }
      }

      print('No cache match found at any level');
      return null;
    } catch (e) {
      print('Error in enhanced cache check: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> checkSimilarFoodImage(
    File imageFile,
    String apiKey,
    List<String> currentIngredients,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final querySnapshot = await firestore
          .collection('users')
          .doc(user.uid)
          .collection('food_cache')
          .where('thumbnailUrl', isNull: false)
          .orderBy(' ', descending: true)
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
        final cachedIngredients = List<String>.from(cachedData['ingredients'] ?? []);
        final cachedAllergens = cachedData['allergens'] as List? ?? [];

        if (cachedImageUrl == null || cachedImageUrl.isEmpty || cachedIngredients.isEmpty) {
          continue;
        }

        try {
          final ref = storage.refFromURL(cachedImageUrl);
          final cachedImageBytes = await ref.getData();
          if (cachedImageBytes == null) continue;

          final comparisonPrompt = '''
You are an expert food image comparison AI. Compare these two images to determine if they show THE SAME DISH.

COMPARISON RULES:
1. ACCEPT (confidence 0.80+) if:
   - Same base dish (e.g., both are Menudo, Kare-Kare, Adobo)
   - Same main protein (oxtail, pork, chicken, seafood)
   - Same visual characteristics (sauce color, texture, consistency)
   - Different angles, lighting, or plating are OK
   - Minor garnish differences are OK

2. REJECT (confidence <0.75) if:
   - Different base dishes
   - Different main proteins
   - Significantly different visual appearance

CACHED DISH:
- Name: $cachedDishName
- Ingredients: ${cachedIngredients.join(', ')}

CURRENT INGREDIENTS:
${currentIngredients.join(', ')}

Return ONLY JSON:
{
  "isSameDish": true/false,
  "confidence": 0.XX,
  "baseDishMatch": true/false,
  "mainProteinMatch": true/false,
  "visualSimilarity": 0.XX,
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
          final baseDishMatch = comparisonResult['baseDishMatch'] == true;
          final proteinMatch = comparisonResult['mainProteinMatch'] == true;

          if (isSameDish && confidence >= 0.75 && baseDishMatch && proteinMatch) {
            print('Visual similarity detected (confidence: $confidence)');
            
            final ingredientComparison = compareIngredients(
              cachedIngredients, 
              currentIngredients,
              cachedAllergens,
            );

            if (ingredientComparison['canReuseCache'] == true) {
              print('Safe to reuse cache: ${ingredientComparison['reason']}');
              
              await firestore
                  .collection('users')
                  .doc(user.uid)
                  .collection('food_cache')
                  .doc(doc.id)
                  .update({
                    'lastAccessed': FieldValue.serverTimestamp(),
                    'accessCount': FieldValue.increment(1),
                    'lastMatchConfidence': confidence,
                    'lastMatchDate': DateTime.now().toIso8601String(),
                  });

              return {
                ...cachedData,
                'fromCache': true,
                'matchType': 'visual_similarity',
                'matchLevel': 3,
                'matchConfidence': confidence,
                'matchReasoning': comparisonResult['reasoning'],
                'ingredientComparison': ingredientComparison,
              };
            } else if (ingredientComparison['shouldMerge'] == true) {
              print('Merging new ingredients with cached data');
              
              return await mergeCachedDataWithNewIngredients(
                cachedData,
                currentIngredients,
                doc.id,
                confidence,
                comparisonResult['reasoning'],
              );
            } else {
              print('Cache rejected: ${ingredientComparison['reason']}');
            }
          }
        } catch (e) {
          print('Error comparing with cached image: $e');
          continue;
        }
      }

      return null;
    } catch (e) {
      print('Error in enhanced visual similarity check: $e');
      return null;
    }
  }

  Map<String, dynamic> compareIngredients(
    List<String> cachedIngredients,
    List<String> currentIngredients,
    List<dynamic> cachedAllergens,
  ) {
    final cachedAllergenIngredients = extractAllergenContainingIngredients(cachedIngredients);
    final currentAllergenIngredients = extractAllergenContainingIngredients(currentIngredients);

    print('Ingredient Comparison:');
    print('Cached allergen ingredients: ${cachedAllergenIngredients.join(", ")}');
    print('Current allergen ingredients: ${currentAllergenIngredients.join(", ")}');

    if (isSubsetOrEqual(currentAllergenIngredients, cachedAllergenIngredients)) {
      return {
        'canReuseCache': true,
        'shouldMerge': false,
        'reason': 'Current ingredients are subset of cached (no new allergens)',
        'action': 'reuse_cache',
      };
    }

    if (hasNewAllergenIngredients(currentAllergenIngredients, cachedAllergenIngredients)) {
      final newIngredients = currentAllergenIngredients
          .where((ing) => !cachedAllergenIngredients.any(
              (cached) => ingredientsMatch(ing, cached)))
          .toList();
      
      return {
        'canReuseCache': false,
        'shouldMerge': true,
        'reason': 'New allergen ingredients detected: ${newIngredients.join(", ")}',
        'action': 'merge_and_reanalyze',
        'newIngredients': newIngredients,
      };
    }

    if (hasMissingAllergenIngredients(currentAllergenIngredients, cachedAllergenIngredients)) {
      final missingIngredients = cachedAllergenIngredients
          .where((cached) => !currentAllergenIngredients.any(
              (ing) => ingredientsMatch(cached, ing)))
          .toList();
      
      return {
        'canReuseCache': false,
        'shouldMerge': false,
        'reason': 'Missing allergen ingredients: ${missingIngredients.join(", ")}',
        'action': 'create_new_variant',
      };
    }

    return {
      'canReuseCache': false,
      'shouldMerge': false,
      'reason': 'Different allergen ingredients detected',
      'action': 'full_reanalysis',
    };
  }

  bool isSubsetOrEqual(List<String> a, List<String> b) {
    return a.every((item) => b.any((cached) => ingredientsMatch(item, cached)));
  }

  bool hasNewAllergenIngredients(List<String> current, List<String> cached) {
    return current.any((item) => !cached.any((cached) => ingredientsMatch(item, cached)));
  }

  bool hasMissingAllergenIngredients(List<String> current, List<String> cached) {
    return cached.any((item) => !current.any((curr) => ingredientsMatch(item, curr)));
  }

  bool ingredientsMatch(String ing1, String ing2) {
    final clean1 = ing1.toLowerCase().trim();
    final clean2 = ing2.toLowerCase().trim();
    
    if (clean1 == clean2) return true;
    
    if (clean1.contains(clean2) || clean2.contains(clean1)) {
      if (isCompoundWordMismatch(clean1, clean2)) return false;
      return true;
    }
    
    if (isSingularPlural(clean1, clean2)) return true;
    
    return false;
  }

  Future<Map<String, dynamic>> mergeCachedDataWithNewIngredients(
    Map<String, dynamic> cachedData,
    List<String> currentIngredients,
    String docId,
    double confidence,
    String reasoning,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return cachedData;

      print('Merging ingredients...');
      
      final mergedIngredients = <String>{
        ...List<String>.from(cachedData['ingredients'] ?? []),
        ...currentIngredients,
      }.toList();

      print('Merged ingredients: ${mergedIngredients.join(", ")}');

      return {
        ...cachedData,
        'fromCache': true,
        'matchType': 'visual_similarity_merged',
        'matchLevel': 3,
        'matchConfidence': confidence,
        'matchReasoning': reasoning,
        'mergedIngredients': mergedIngredients,
        'requiresAllergenReanalysis': true,
        'originalCachedIngredients': cachedData['ingredients'],
        'newIngredients': currentIngredients.where(
          (ing) => !cachedData['ingredients'].any(
            (cached) => ingredientsMatch(ing, cached)
          )
        ).toList(),
      };
    } catch (e) {
      print('Error merging cached data: $e');
      return cachedData;
    }
  }

  String generateCacheKey(String dishName, {List<String>? ingredients}) {
    String original = dishName.toLowerCase().trim();
    String mainProtein = extractMainProtein(original);
    String normalized =
        original
            .replaceAll(
              RegExp(
                r'\b(filipino|pinoy|style|traditional|classic|homemade|authentic|special|deluxe|premium|original)\b',
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

    String baseDish = normalizeDishName(normalized);

    String allergenSuffix = '';
    if (ingredients != null && ingredients.isNotEmpty) {
      List<String> allergenIngredients = extractAllergenContainingIngredients(
        ingredients,
      );
      if (allergenIngredients.isNotEmpty) {
        allergenIngredients.sort();
        allergenSuffix = '_${allergenIngredients.join('_')}';
      }
    }

    if (mainProtein.isNotEmpty) {
      return '${mainProtein}_$baseDish$allergenSuffix';
    }

    return '$baseDish$allergenSuffix';
  }

  List<String> extractAllergenContainingIngredients(List<String> ingredients) {
    const Map<String, String> allergenKeywords = {
      'hotdog': 'hotdog',
      'hot dog': 'hotdog',
      'sausage': 'sausage',
      'ham': 'ham',
      'bacon': 'bacon',
      'chorizo': 'chorizo',
      'tocino': 'tocino',
      'longganisa': 'longganisa',
      'egg': 'egg',
      'eggs': 'egg',
      'tofu': 'tofu',
      'tokwa': 'tofu',
      'cheese': 'cheese',
      'milk': 'milk',
      'cream': 'cream',
      'shrimp': 'shrimp',
      'hipon': 'shrimp',
      'crab': 'crab',
      'alimango': 'crab',
      'fish': 'fish',
      'peanut': 'peanut',
      'mani': 'peanut',
      'cashew': 'cashew',
      'kasuy': 'cashew',
      'almond': 'almond',
      'walnut': 'walnut',
      'oyster sauce': 'oyster',
      'bagoong': 'bagoong',
      'patis': 'patis',
    };

    List<String> foundAllergens = [];
    for (String ingredient in ingredients) {
      String lower = ingredient.toLowerCase().trim();
      for (var entry in allergenKeywords.entries) {
        if (lower.contains(entry.key)) {
          String normalized = entry.value;
          if (!foundAllergens.contains(normalized)) {
            foundAllergens.add(normalized);
          }
        }
      }
    }

    return foundAllergens;
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

  Future<Map<String, dynamic>?> checkExactFoodCache(String cacheKey) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final doc =
          await firestore
              .collection('users')
              .doc(user.uid)
              .collection('food_cache')
              .doc(cacheKey)
              .get();

      if (doc.exists) {
        print('Found exact cache match for: $cacheKey');

        firestore
            .collection('users')
            .doc(user.uid)
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
      print('Error checking exact food cache: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> checkExactImageMatch(String imageHash) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final querySnapshot =
          await firestore
              .collection('users')
              .doc(user.uid)
              .collection('food_cache')
              .where('imageHash', isEqualTo: imageHash)
              .limit(1)
              .get();

      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data();

        firestore
            .collection('users')
            .doc(user.uid)
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
        'baseDishMatch': parsed['baseDishMatch'] ?? false,
        'mainProteinMatch': parsed['mainProteinMatch'] ?? false,
        'allergenIngredientsMatch': parsed['allergenIngredientsMatch'] ?? false,
        'reasoning': parsed['reasoning'] ?? 'No reasoning provided',
      };
    } catch (e) {
      print('Error parsing comparison response: $e');
      print('Raw response: $response');
      return {
        'isSameDish': false,
        'confidence': 0.0,
        'baseDishMatch': false,
        'mainProteinMatch': false,
        'allergenIngredientsMatch': false,
        'reasoning': 'Failed to parse comparison - treating as different dish for safety',
      };
    }
  }

  Future<void> saveFoodCache(
    String cacheKey,
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
              .child(user.uid)
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
          .collection('users')
          .doc(user.uid)
          .collection('food_cache')
          .doc(cacheKey)
          .set(cacheData, SetOptions(merge: true));

      print('Food analysis cached successfully: $cacheKey');
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

  bool hasWordBoundaryMatch(String text, String word) {
    final regex = RegExp(r'\b' + RegExp.escape(word) + r'\b');
    return regex.hasMatch(text);
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
      print('Checking user allergen: "$cleanUserAllergen"');

      if (cleanAllergenName == cleanUserAllergen) {
        print('EXACT MATCH - returning: $userAllergen');
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

      List<String> treeNuts = [
        'cashew',
        'almond',
        'walnut',
        'pistachio',
        'hazelnut',
        'pecan',
        'macadamia',
        'brazil nut',
      ];

      bool userIsPeanut =
          cleanUserAllergen == 'peanut' || cleanUserAllergen == 'peanuts';
      bool detectedIsPeanut =
          cleanAllergenName == 'peanut' || cleanAllergenName == 'peanuts';

      bool userIsGenericNut =
          cleanUserAllergen == 'nut' ||
          cleanUserAllergen == 'nuts' ||
          cleanUserAllergen == 'tree nut' ||
          cleanUserAllergen == 'tree nuts';

      bool userIsSpecificTreeNut = treeNuts.any(
        (nut) => cleanUserAllergen == nut || cleanUserAllergen == '${nut}s',
      );
      bool detectedIsSpecificTreeNut = treeNuts.any(
        (nut) => cleanAllergenName == nut || cleanAllergenName == '${nut}s',
      );

      if (userIsGenericNut && detectedIsPeanut) {
        continue;
      }

      if (userIsPeanut &&
          (cleanAllergenName == 'nut' ||
              cleanAllergenName == 'nuts' ||
              cleanAllergenName == 'tree nut' ||
              cleanAllergenName == 'tree nuts')) {
        continue;
      }

      if (userIsPeanut && detectedIsPeanut) {
        return userAllergen;
      }

      if (userIsSpecificTreeNut && detectedIsSpecificTreeNut) {
        for (String nut in treeNuts) {
          if ((cleanUserAllergen == nut || cleanUserAllergen == '${nut}s') &&
              (cleanAllergenName == nut || cleanAllergenName == '${nut}s')) {
            return userAllergen;
          }
        }
        continue;
      }

      if (userIsSpecificTreeNut &&
          (cleanAllergenName == 'nut' ||
              cleanAllergenName == 'nuts' ||
              cleanAllergenName == 'tree nut' ||
              cleanAllergenName == 'tree nuts')) {
        continue;
      }

      if (userIsGenericNut && detectedIsSpecificTreeNut) {
        return userAllergen;
      }

      if ((userIsPeanut && detectedIsSpecificTreeNut) ||
          (userIsSpecificTreeNut && detectedIsPeanut)) {
        continue;
      }

      bool userIsSpecificShellfish = [
        'shrimp',
        'crab',
        'lobster',
      ].any((specific) => cleanUserAllergen.contains(specific));
      bool detectedIsSpecificShellfish = [
        'shrimp',
        'crab',
        'lobster',
      ].any((specific) => cleanAllergenName.contains(specific));

      if (userIsSpecificShellfish && detectedIsSpecificShellfish) {
        bool sameType = ['shrimp', 'crab', 'lobster'].any((type) {
          return cleanUserAllergen.contains(type) &&
              cleanAllergenName.contains(type);
        });
        if (sameType) {
          return userAllergen;
        }
        continue;
      }

      if (userIsSpecificShellfish &&
          (cleanAllergenName.contains('shellfish') ||
              cleanAllergenName.contains('crustacean'))) {
        continue;
      }

      if ((cleanUserAllergen.contains('shellfish') ||
              cleanUserAllergen.contains('crustacean')) &&
          detectedIsSpecificShellfish) {
        return userAllergen;
      }

      List<String> specificFish = [
        'tuna',
        'salmon',
        'tilapia',
        'bangus',
        'milkfish',
        'galunggong',
        'mackerel',
        'cod',
        'sardines',
        'bagoong',
        'fish sauce',
        'patis',
      ];

      bool userIsSpecificFish = specificFish.any(
        (fish) => cleanUserAllergen.contains(fish),
      );
      bool detectedIsSpecificFish = specificFish.any(
        (fish) => cleanAllergenName.contains(fish),
      );

      if (userIsSpecificFish && detectedIsSpecificFish) {
        bool sameType = specificFish.any((type) {
          return cleanUserAllergen.contains(type) &&
              cleanAllergenName.contains(type);
        });
        if (sameType) {
          return userAllergen;
        }
        continue;
      }

      if (userIsSpecificFish && cleanAllergenName == 'fish') {
        continue;
      }

      if (cleanUserAllergen == 'fish' && detectedIsSpecificFish) {
        return userAllergen;
      }

      List<String> specificDairy = [
        'milk',
        'cheese',
        'yogurt',
        'butter',
        'cream',
        'whey',
        'casein',
      ];
      bool userIsSpecificDairy = specificDairy.any(
        (dairy) => cleanUserAllergen.contains(dairy),
      );
      bool detectedIsSpecificDairy = specificDairy.any(
        (dairy) => cleanAllergenName.contains(dairy),
      );

      if (userIsSpecificDairy && detectedIsSpecificDairy) {
        bool sameType = specificDairy.any((type) {
          return cleanUserAllergen.contains(type) &&
              cleanAllergenName.contains(type);
        });
        if (sameType) {
          return userAllergen;
        }
        continue;
      }

      if (userIsSpecificDairy && cleanAllergenName == 'dairy') {
        continue;
      }

      if (cleanUserAllergen == 'dairy' && detectedIsSpecificDairy) {
        return userAllergen;
      }

      if (areAllergenSynonyms(cleanAllergenName, cleanUserAllergen)) {
        return userAllergen;
      }

      if (cleanAllergenName != cleanUserAllergen) {
        RegExp wordBoundary = RegExp(
          r'\b' + RegExp.escape(cleanUserAllergen) + r'\b',
        );
        if (wordBoundary.hasMatch(cleanAllergenName)) {
          if (!isCompoundWordMismatch(cleanAllergenName, cleanUserAllergen)) {
            return userAllergen;
          }
        }

        RegExp reverseWordBoundary = RegExp(
          r'\b' + RegExp.escape(cleanAllergenName) + r'\b',
        );
        if (reverseWordBoundary.hasMatch(cleanUserAllergen)) {
          if (!isCompoundWordMismatch(cleanUserAllergen, cleanAllergenName)) {
            return userAllergen;
          }
        }
      }
    }

    return null;
  }

  Future<void> updateAllergenHighlighting(List<AllergenInfo> allergens) async {
    final allergenData = await getUserAllergenData();
    List<String> currentUserAllergens = List<String>.from(
      allergenData['names'],
    );

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
      print('Processing allergen: "$allergenName"');

      String? matchedUserAllergen = await findMatchingUserAllergen(
        allergenName,
        translatedSeverity.keys.toList(),
      );

      if (matchedUserAllergen != null) {
        allergen.isUserAllergen = true;
      } else {
        allergen.isUserAllergen = false;
      }
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
      ['peanut', 'nuts'],
      ['peanuts', 'nuts'],
      ['peanut', 'tree nut'],
      ['peanuts', 'tree nuts'],
      ['peanut', 'tree nuts'],
      ['peanuts', 'tree nut'],
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