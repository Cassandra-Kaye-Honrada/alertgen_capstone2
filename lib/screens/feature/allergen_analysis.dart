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
        You are an EXPERT food image comparison AI specializing in Filipino and international cuisine. 
        Your mission is to determine if two images show THE SAME DISH (possibly from different angles, lighting, or plating).

        CURRENT DISH NAME: $currentDishName
        CACHED DISH NAME: $cachedDishName

        DETAILED COMPARISON CRITERIA:
 
        1. DISH IDENTITY (40% weight):
          - Is the BASE DISH the same? (e.g., both are Kare-Kare, Adobo, Paella, etc.)
          - Verify dish name match: Does "$currentDishName" semantically match "$cachedDishName"?
          - Consider regional variations (e.g., "Ilocos Bagnet" vs "Bagnet" = SAME)
          - Consider protein variations (e.g., "Pork Adobo" vs "Chicken Adobo" = DIFFERENT)

        2. VISUAL CHARACTERISTICS (30% weight):
          
          SAUCE/BROTH ANALYSIS:
          - Color: Is the sauce/broth color similar? (Red, brown, yellow, black, clear, creamy white)
          - Consistency: Same thickness? (Thick stew, thin soup, dry, creamy)
          - Texture: Same visual texture? (Glossy, matte, oily surface, grainy)
          
          COOKING METHOD MARKERS:
          - Grilled (char marks, smoky appearance)
          - Fried (golden-brown, crispy texture)
          - Stewed (sauce-coated, tender appearance)
          - Boiled (clear broth, whole ingredients)
          - Steamed (moist, delicate appearance)
          
          COLOR SIGNATURE:
          - Tomato-based: Red-orange color
          - Soy-based: Dark brown, glossy
          - Peanut-based: Orange-brown, thick
          - Coconut-based: Creamy white or yellow
          - Blood-based: Very dark brown/black
          - Turmeric-based: Bright yellow
          - Burnt coconut: Jet black

        3. MAIN PROTEIN MATCH (20% weight):
          - Is the PRIMARY PROTEIN the same?
          - Seafood types: shrimp, crab, fish, mixed seafood
          - Meat types: pork, beef, chicken, oxtail, goat
          - Vegetarian: tofu, vegetables only
          - NOTE: Different proteins = DIFFERENT DISH (even if cooking style similar)

        4. KEY INGREDIENT PATTERNS (10% weight):
          - Are SIGNATURE INGREDIENTS visible in both?
          - Filipino dishes: Check for regional markers
            * Ilocos: Dark bile soup, ultra-crispy pork
            * Bicol: Red chilies in coconut milk
            * Mindanao: Turmeric yellow, black soup
          - International dishes: Check for distinctive elements
            * Paella: Saffron rice, arranged seafood
            * Seafood Boil: Red Cajun spices, corn, potatoes
            * Tom Yum: Lemongrass, galangal, clear broth

        5. ACCEPTABLE VARIATIONS (These are OK):
          - Different camera angles (top-down vs side view)
          - Different lighting conditions (bright vs dim)
          - Different plating/servingware (bowl vs plate, banana leaf)
          - Different garnish amount (more/less onions, herbs)
          - Different portion sizes
          - Minor vegetable quantity differences
          - Different cooking doneness (slightly more/less cooked)

        6. REJECTION TRIGGERS (These indicate DIFFERENT dishes):
          - Different base dish entirely (Adobo vs Menudo)
          - Different main protein (Pork vs Chicken version)
          - Completely different color signature (Red sauce vs Black soup)
          - Different cooking method (Fried vs Stewed)
          - Different cuisine category (Filipino vs Italian)
          - One is dessert, other is main dish
          - Significantly different ingredient composition

        FILIPINO-SPECIFIC COMPARISON RULES:

        Regional Variations (Accept as SAME):
        - "Dinuguan" = "Dinardaraan" (same dish, different regions)
        - "Sinanglaw" = "Sinanglao" (spelling variation)
        - "Pinapaitan" = "Papaitan" (spelling variation)
        - "Kansi" from Iloilo = "Kansi" from Negros
        - "Sinigang" with different souring agents (tamarind vs calamansi)

        Protein Variations (Different dishes):
        - "Pork Menudo" ≠ "Chicken Menudo"
        - "Chicken Adobo" ≠ "Pork Adobo"
        - "Oxtail Kare-Kare" ≠ "Pork Kare-Kare"
        - "Beef Sinigang" ≠ "Shrimp Sinigang"

        Look-alike Dishes (Carefully distinguish):
        - Menudo vs Afritada vs Caldereta (all tomato-based, but different sauce thickness and ingredients)
        - Dinuguan vs Dinardaraan vs Tidtad (all blood-based, but regional differences)
        - La Paz Batchoy vs Pancit Molo (both noodle soups, but different components)

        CONFIDENCE SCORING GUIDELINES:

        0.95-1.00: PERFECT MATCH
        - Exact same dish, same angle, nearly identical visual characteristics
        - All markers match: color, texture, ingredients visible, cooking method
        - Example: "Pork Adobo" with dark glossy sauce in both images

        0.85-0.94: VERY STRONG MATCH
        - Same dish from different angle or lighting
        - All key characteristics match, minor variation in garnish/plating
        - Example: "Bicol Express" - both have red chilies in creamy coconut sauce

        0.75-0.84: STRONG MATCH (Accept)
        - Same base dish, same protein, same visual signature
        - Some differences in garnish, portion size, or exact presentation
        - Example: "Seafood Paella" - both have yellow rice, mixed seafood, similar arrangement

        0.65-0.74: MODERATE MATCH (Borderline - be cautious)
        - Similar dish type but may have protein variation
        - Visual characteristics similar but not identical
        - Recommend: REJECT unless you're very confident

        0.50-0.64: WEAK MATCH (Reject)
        - Different dishes that happen to look somewhat similar
        - Example: Menudo vs Afritada (both tomato-based but different)

        Below 0.50: NO MATCH
        - Completely different dishes
        - Different cuisine, cooking method, or category

        ANALYSIS PROCESS:

        Step 1: Identify both dishes independently
        - What dish is shown in CACHED IMAGE?
        - What dish is shown in CURRENT IMAGE?

        Step 2: Compare base dish names
        - Do the dish names semantically match?
        - Are they regional variations of the same dish?

        Step 3: Visual characteristic comparison
        - Compare: sauce color, consistency, texture
        - Compare: cooking method indicators
        - Compare: overall color signature

        Step 4: Protein verification
        - Is the main protein the same in both images?

        Step 5: Key ingredient check
        - Are signature ingredients visible in both?
        - Do they match the dish identity?

        Step 6: Calculate confidence
        - Weight each criterion appropriately
        - Consider both strengths and discrepancies

        OUTPUT REQUIREMENTS:

        Return ONLY valid JSON (no markdown, no preamble):
        {
          "isSameDish": true/false,
          "confidence": 0.XX,
          "reasoning": "DETAILED MULTI-POINT EXPLANATION",
          "cachedDishIdentified": "What dish you identified in cached image",
          "currentDishIdentified": "What dish you identified in current image",
          "visualCharacteristics": {
            "sauceColorMatch": true/false,
            "consistencyMatch": true/false,
            "cookingMethodMatch": true/false,
            "proteinMatch": true/false
          },
          "matchingFeatures": ["List 3-5 specific matching features"],
          "differentFeatures": ["List any concerning differences"]
        }

        REASONING FORMAT:
        Provide a detailed 3-5 sentence explanation covering:
        1. What dishes you identified in each image
        2. Key matching visual characteristics (color, texture, ingredients)
        3. Whether proteins match
        4. Why you assigned this confidence score
        5. Any notable differences or concerns

        EXAMPLE REASONING (Good):
        "Both images show Pork Adobo with characteristic dark brown glossy sauce from soy and vinegar. The CACHED image appears to be a top-down view while CURRENT is a side angle, but both display the same sauce consistency, tender pork chunks, and shiny caramelized coating. The main protein (pork) matches in both. Minor difference in garnish amount but core dish identity is identical. High confidence this is the same dish photographed differently."

        EXAMPLE REASONING (Rejection):
        "CACHED image shows Pork Menudo with red-orange tomato sauce and diced vegetables. CURRENT image shows Chicken Adobo with dark brown soy-based sauce. Despite both being Filipino stews, they are fundamentally different dishes with different base sauces (tomato vs soy), different proteins (pork vs chicken), and different cooking methods. Cannot confirm as same dish."

        Now analyze the two images provided and determine if they show the same dish.
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

  Future<Map<String, dynamic>?> checkManualEntryCache(String dishName) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final cacheKey = generateCacheKey(dishName);
    print(' Checking manual entry cache for: $dishName (key: $cacheKey)');

    final doc = await firestore
        .collection('users')
        .doc(user.uid)
        .collection('manual_entry_cache')
        .doc(cacheKey)
        .get();

    if (doc.exists) {
      print(' Manual entry cache HIT for: $cacheKey');
      print('   Original entry: ${doc.data()?['dishName']}');
      
      firestore
          .collection('users')
          .doc(user.uid)
          .collection('manual_entry_cache')
          .doc(cacheKey)
          .update({
            'lastAccessed': FieldValue.serverTimestamp(),
            'accessCount': FieldValue.increment(1),
          })
          .catchError((e) => print('Error updating cache stats: $e'));

      return {
        ...doc.data()!,
        'fromCache': true,
        'cacheType': 'manual_entry',
      };
    }

    print(' Manual entry cache MISS for: $cacheKey');
    return null;
  } catch (e) {
    print('Error checking manual entry cache: $e');
    return null;
  }
}

Future<void> saveManualEntryCache(
  String dishName,
  String description,
  List<String> ingredients,
  List<dynamic> allergens, {
  IngredientBenefitsMap? ingredientBenefitsMap,
}) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final cacheKey = generateCacheKey(dishName);
    print('Saving to manual entry cache with key: $cacheKey');

    Map<String, dynamic> cacheData = {
      'dishName': dishName,
      'description': description,
      'ingredients': ingredients,
      'allergens': allergens.map((a) => a is Map ? a : a.toJson()).toList(),
      'timestamp': FieldValue.serverTimestamp(),
      'lastAccessed': FieldValue.serverTimestamp(),
      'cacheKey': cacheKey,
      'accessCount': 1,
      'entryType': 'manual',
    };

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
        .collection('manual_entry_cache')
        .doc(cacheKey)
        .set(cacheData, SetOptions(merge: true));

    print(' Manual entry cached successfully: $cacheKey');
  } catch (e) {
    print(' Error saving manual entry cache: $e');
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

    debugPrint("Raw user allergen severity: $userAllergenSeverity");

    Map<String, double> translatedSeverity = {};
    for (var entry in userAllergenSeverity.entries) {
      String tagalogName = entry.key;
      String englishName = await TranslationService.instance.translateToEnglish(
        tagalogName,
      );
      translatedSeverity[englishName.toLowerCase().trim()] = entry.value;
      translatedSeverity[tagalogName.toLowerCase().trim()] = entry.value;

      debugPrint(
        "Translated allergen: '$tagalogName' -> '$englishName' with severity ${entry.value}",
      );
    }

    List<String> userAllergenNames = translatedSeverity.keys.toList();
    debugPrint("User allergen names (normalized): $userAllergenNames");

    List<IngredientColorInfo> computedIngredientColors = [];

    for (String ingredient in ingredients) {
      double maxSeverity = -1.0;
      List<String> matchedAllergens = [];
      String lowerIngredient = ingredient.toLowerCase().trim();

      debugPrint("Processing ingredient: '$ingredient'");

      for (AllergenInfo allergenInfo in allergens) {
        bool isSourceMatch = allergenInfo.sources.any(
          (source) =>
              isIngredientMatch(lowerIngredient, source.toLowerCase().trim()),
        );

        if (isSourceMatch) {
          debugPrint(
            "  Ingredient '$ingredient' matches allergen source: ${allergenInfo.sources}",
          );

          String allergenName = allergenInfo.name.toLowerCase();

          String? matchedUserAllergen = await findMatchingUserAllergen(
            allergenName,
            userAllergenNames,
          );

          if (matchedUserAllergen != null) {
            double severity = translatedSeverity[matchedUserAllergen]!;
            debugPrint(
              "    Found matching user allergen '$matchedUserAllergen' with severity $severity",
            );

            if (severity > maxSeverity) {
              maxSeverity = severity;
              matchedAllergens = [allergenInfo.name];
              debugPrint(
                "    New max severity: $maxSeverity (from ${allergenInfo.name})",
              );
            } else if (severity == maxSeverity) {
              matchedAllergens.add(allergenInfo.name);
              debugPrint(
                "    Equal severity match: added ${allergenInfo.name}",
              );
            }
          } else {
            debugPrint("    No user allergen match for '${allergenInfo.name}'");
          }
        }
      }

      Color ingredientColor;
      if (maxSeverity == -1.0) {
        ingredientColor = const Color(0xFFDFDFDF);
        debugPrint("  No allergen match for '$ingredient' → Color: Gray");
      } else if (maxSeverity < 0.33) {
        ingredientColor = Colors.green;
        debugPrint("  Severity $maxSeverity → Color: Green");
      } else if (maxSeverity < 0.67) {
        ingredientColor = Colors.orange;
        debugPrint("  Severity $maxSeverity → Color: Orange");
      } else {
        ingredientColor = Colors.red;
        debugPrint("  Severity $maxSeverity → Color: Red");
      }

      computedIngredientColors.add(
        IngredientColorInfo(
          ingredient: ingredient,
          color: ingredientColor,
          severity: maxSeverity == -1.0 ? 0.0 : maxSeverity,
          matchedAllergens: matchedAllergens,
        ),
      );

      debugPrint(
        "Final result for '$ingredient': severity=${maxSeverity == -1.0 ? 0.0 : maxSeverity}, matchedAllergens=$matchedAllergens, color=$ingredientColor",
      );
    }

    debugPrint("Completed ingredient color computation.");
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

    Map<String, Set<String>> allergenCategories = {
      'nuts': {
        'cashew', 'cashews', 'almond', 'almonds', 'walnut', 'walnuts',
        'pistachio', 'pistachios', 'hazelnut', 'hazelnuts', 'pecan', 'pecans',
        'macadamia', 'macadamias', 'brazil nut', 'brazil nuts',
        'pine nut', 'pine nuts', 'chestnut', 'chestnuts',
      },
      'tree nuts': {
        'cashew', 'cashews', 'almond', 'almonds', 'walnut', 'walnuts',
        'pistachio', 'pistachios', 'hazelnut', 'hazelnuts', 'pecan', 'pecans',
        'macadamia', 'macadamias', 'brazil nut', 'brazil nuts',
        'pine nut', 'pine nuts', 'chestnut', 'chestnuts',
      },
      'shellfish': {
        'shrimp', 'shrimps', 'prawn', 'prawns', 'crab', 'crabs',
        'lobster', 'lobsters', 'crayfish', 'mussel', 'mussels',
        'clam', 'clams', 'oyster', 'oysters', 'scallop', 'scallops',
        'squid', 'squids', 'octopus',
      },
      'crustacean': {
        'shrimp', 'shrimps', 'prawn', 'prawns', 'crab', 'crabs',
        'lobster', 'lobsters', 'crayfish',
      },
      'fish': {
        'tuna', 'salmon', 'tilapia', 'bangus', 'milkfish', 'cod',
        'mackerel', 'sardines', 'sardine', 'anchovies', 'anchovy',
        'galunggong', 'fish sauce', 'patis', 'fish paste', 'bagoong isda',
      },
    };

    Map<String, Set<String>> directAllergens = {
      'milk': {'milk', 'dairy', 'cheese', 'butter', 'cream', 'yogurt', 'yoghurt', 'whey', 'casein', 'lactose', 'gatas'},
      'dairy': {'milk', 'dairy', 'cheese', 'butter', 'cream', 'yogurt', 'yoghurt', 'whey', 'casein', 'lactose', 'gatas'},
      'soy': {'soy', 'soya', 'soybean', 'soybeans', 'soy sauce', 'toyo', 'tofu', 'tokwa', 'edamame', 'soy protein', 'soy milk'},
      'egg': {'egg', 'eggs', 'itlog', 'albumin'},
      'eggs': {'egg', 'eggs', 'itlog', 'albumin'},
      'wheat': {'wheat', 'gluten', 'flour', 'harina'},
      'gluten': {'wheat', 'gluten', 'flour', 'harina'},
      'sesame': {'sesame', 'sesame seed', 'sesame seeds', 'tahini'},
      'peanut': {'peanut', 'peanuts', 'groundnut', 'groundnuts', 'mani'},
      'peanuts': {'peanut', 'peanuts', 'groundnut', 'groundnuts', 'mani'},
    };

    Map<String, Set<String>> allAllergenMaps = {}
      ..addAll(allergenCategories)
      ..addAll(directAllergens);

    debugPrint("findMatchingUserAllergen called:");
    debugPrint("  Detected allergen: '$cleanAllergenName'");
    debugPrint("  User allergens: $userAllergens");

    for (String userAllergen in userAllergens) {
      String cleanUserAllergen = userAllergen.toLowerCase().trim();

      if (cleanAllergenName == cleanUserAllergen) {
        debugPrint("  ✓ MATCH: Exact match with '$userAllergen'");
        return userAllergen;
      }

      if (isSingularPlural(cleanAllergenName, cleanUserAllergen)) {
        debugPrint("  ✓ MATCH: Singular/plural match with '$userAllergen'");
        return userAllergen;
      }
    }

    for (String userAllergen in userAllergens) {
      String cleanUserAllergen = userAllergen.toLowerCase().trim();

      if (allergenCategories.containsKey(cleanUserAllergen)) {
        Set<String> categoryItems = allergenCategories[cleanUserAllergen]!;

        if (categoryItems.contains(cleanAllergenName)) {
          debugPrint("  ✓ MATCH: '$cleanAllergenName' is in user category '$cleanUserAllergen'");
          return userAllergen;
        }

        for (String categoryItem in categoryItems) {
          if (cleanAllergenName.contains(categoryItem) && categoryItem.length > 3) {
            debugPrint("  ✓ MATCH: '$cleanAllergenName' contains category item '$categoryItem' from user category '$cleanUserAllergen'");
            return userAllergen;
          }
        }
      }
    }

    if (allergenCategories.containsKey(cleanAllergenName)) {
      Set<String> categoryItems = allergenCategories[cleanAllergenName]!;

      for (String userAllergen in userAllergens) {
        String cleanUserAllergen = userAllergen.toLowerCase().trim();

        if (categoryItems.contains(cleanUserAllergen)) {
          debugPrint("  ✓ MATCH: User allergen '$cleanUserAllergen' is in detected category '$cleanAllergenName'");
          return userAllergen;
        }
      }
    }

    for (String userAllergen in userAllergens) {
      String cleanUserAllergen = userAllergen.toLowerCase().trim();

      for (var entry in allAllergenMaps.entries) {
        String allergenKey = entry.key;
        Set<String> allergenItems = entry.value;

        if (allergenItems.contains(cleanAllergenName) && 
            allergenItems.contains(cleanUserAllergen)) {
          debugPrint("  ✓ MATCH: Both '$cleanAllergenName' and '$cleanUserAllergen' are in allergen group '$allergenKey'");
          return userAllergen;
        }
      }
    }

    for (String userAllergen in userAllergens) {
      String cleanUserAllergen = userAllergen.toLowerCase().trim();

      bool areEquivalent = await TranslationService.instance.areTermsEquivalent(
        cleanAllergenName,
        cleanUserAllergen,
      );
      if (areEquivalent) {
        debugPrint("  ✓ MATCH: Translation equivalence with '$userAllergen'");
        return userAllergen;
      }
    }

    for (String userAllergen in userAllergens) {
      String cleanUserAllergen = userAllergen.toLowerCase().trim();

      if (areAllergenSynonyms(cleanAllergenName, cleanUserAllergen)) {
        debugPrint("  ✓ MATCH: Synonym match with '$userAllergen'");
        return userAllergen;
      }
    }

    debugPrint("  ✗ NO MATCH: '$cleanAllergenName' does not match any user allergen");
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
      'milk': ['milk', 'dairy', 'lactose', 'casein', 'whey'],
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