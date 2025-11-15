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
You are an expert food image comparison AI specializing in Filipino cuisine AND international dishes. Compare these two images to determine if they show THE SAME DISH (possibly from different angles).

═══════════════════════════════════════════════════════════════════════════════
CRITICAL FILIPINO DISH DISTINCTIONS
═══════════════════════════════════════════════════════════════════════════════

PINAPAITAN vs DINUGUAN vs DINARDARAAN vs TIYULA ITUM:

PINAPAITAN (Bitter Soup):
- Broth Color: GREEN-BROWN, OLIVE-TONED, yellowish-green
- Texture: CLEAR to slightly cloudy broth (NOT thick)
- Key Visual: Greenish tint, chunks of intestines/organs, ginger slices visible
- Consistency: THIN soup/broth
- Taste Profile: BITTER (from bile)
- If you see: Green tint + clear broth + organ chunks → PINAPAITAN

DINUGUAN (Chocolate Meat):
- Broth Color: VERY DARK BROWN to BLACK
- Texture: THICK, gravy-like, opaque
- Key Visual: No greenish tint, thick sauce coating meat
- Consistency: Thick gravy/sauce
- Taste Profile: SWEET-SOUR (from blood and vinegar)
- If you see: Black + thick + gravy consistency → DINUGUAN

DINARDARAAN (Ilocano Blood Stew):
- Essentially same as Dinuguan
- DARK, THICK, blood-based
- Regional name, same characteristics as Dinuguan

TIYULA ITUM (Black Soup):
- Broth Color: COMPLETELY BLACK from burnt coconut
- Texture: LIQUID broth (NOT thick like Dinuguan)
- Key Visual: Very black but soup consistency, beef/chicken pieces
- Consistency: THIN soup/broth
- Taste Profile: SMOKY, spicy from burnt coconut
- If you see: Black + liquid broth (not thick) → TIYULA ITUM

TOMATO-BASED STEWS (Menudo vs Afritada vs Caldereta vs Mechado):

MENUDO:
- Color: RED-ORANGE from tomato sauce
- Meat Size: SMALL cubes (1-2 cm)
- Contains: Liver, potatoes, carrots, raisins, sometimes hotdog
- Sauce: Medium consistency
- If you see: Small meat cubes + liver + red sauce → MENUDO

AFRITADA:
- Color: RED-ORANGE from tomato sauce
- Meat Size: LARGER chunks (3-4 cm) than Menudo
- Contains: Bell peppers prominent, potatoes, carrots
- Sauce: Less liver than Menudo
- If you see: Larger meat chunks + bell peppers → AFRITADA

CALDERETA:
- Color: DARK RED, richer than Afritada
- Sauce: THICK, rich (liver spread/pâté added)
- Contains: Bell peppers, olives, potatoes
- Spicy: Often has chili peppers
- If you see: Dark red + thick sauce + olives → CALDERETA

MECHADO:
- Color: DARK RED-BROWN (darker than others)
- Key Feature: SOY SAUCE added (makes it darker)
- Contains: Beef chunks with visible fat, potatoes
- Sauce: Soy + tomato combination
- If you see: Dark brown-red + beef + soy undertone → MECHADO

KARE-KARE VARIATIONS:
- Must have: ORANGE-BROWN peanut sauce (thick)
- Protein: Oxtail, beef, pork, or seafood
- Vegetables: Bok choy, eggplant, string beans
- Served with: Bagoong (shrimp paste) on side
- If you see: Orange peanut sauce + vegetables → KARE-KARE

SINIGANG VARIATIONS:
- Must have: CLEAR SOUR BROTH (not cloudy unless with miso)
- Souring agent: Tamarind (most common), kamias, or calamansi
- Vegetables: Radish, tomatoes, kangkong, string beans, eggplant
- Protein: Pork, beef, shrimp, fish, milkfish
- If you see: Clear sour broth + vegetables → SINIGANG

ADOBO VARIATIONS:
- Color: DARK BROWN, glossy from oil
- Sauce: Soy sauce + vinegar base
- Can be: Chicken, pork, squid
- Adobo sa Gata: Has coconut milk (lighter, creamy)
- If you see: Dark glossy brown + soy-based → ADOBO

REGIONAL SPECIALTY DISTINCTIONS:

SINANGLAW (Ilocos):
- GRILLED beef in SOUR soup
- Dark brown broth, charred/grilled meat visible
- Similar to Sinigang but with grilled components

HUMBA (Cebu):
- SWEET pork belly stew
- Dark brown, thick sauce
- Black beans and dried banana blossoms
- Stickier and sweeter than Adobo

KANSI (Iloilo):
- Beef soup with LEMONGRASS
- Sour from batwan (native fruit)
- Clear yellowish broth
- Beef shanks visible

BINAKOL (Visayas):
- Chicken in COCONUT WATER
- Clear broth, coconut flavor
- May be served in coconut shell

LA PAZ BATCHOY (Iloilo):
- Noodle soup with pork organs
- Crushed chicharon on top
- Rich pork broth with egg noodles

═══════════════════════════════════════════════════════════════════════════════
INTERNATIONAL DISH DISTINCTIONS
═══════════════════════════════════════════════════════════════════════════════

NOODLE DISHES:

PANCIT (Filipino) vs PAD THAI (Thai) vs CHOW MEIN (Chinese) vs PHO (Vietnamese):

PANCIT:
- Yellow or white noodles
- Filipino vegetables (cabbage, carrots, green beans)
- Soy sauce base
- Dry or slightly saucy

PAD THAI:
- ORANGE-RED color from tamarind and chili
- Peanuts visible, lime wedges
- Bean sprouts
- Distinct sweet-sour-savory

CHOW MEIN:
- Brown from soy sauce
- Can have crispy noodles
- Chinese vegetables
- Darker than Pancit

PHO:
- CLEAR aromatic broth
- Flat white rice noodles
- Fresh herbs (basil, cilantro) on side
- Raw beef slices

RICE DISHES:

FRIED RICE (Chinese) vs BRINGHE (Kapampangan) vs BIRYANI (Indian) vs PAELLA (Spanish):

FRIED RICE:
- Individual grains visible
- Brown from soy sauce
- Scrambled egg pieces

BRINGHE:
- YELLOW from turmeric
- Sticky consistency (glutinous rice)
- Coconut milk base

BIRYANI:
- YELLOW-ORANGE from saffron/turmeric
- Layered with meat
- Whole spices visible

PAELLA:
- YELLOW from saffron
- Cooked in wide shallow pan
- Seafood on top
- Crispy bottom layer (socarrat)

CURRY DISHES:

KARE-KARE (Filipino) vs GREEN CURRY (Thai) vs BUTTER CHICKEN (Indian) vs RENDANG (Indonesian/Mindanao):

KARE-KARE:
- ORANGE-BROWN peanut sauce
- Filipino vegetables
- Served with bagoong

GREEN CURRY:
- BRIGHT GREEN
- Thai basil, bamboo shoots
- Very green from herbs

BUTTER CHICKEN:
- ORANGE-RED creamy
- Tomato-cream base
- Very rich

RENDANG:
- DARK BROWN, almost black
- Very dry, thick
- Slow-cooked coconut

GRILLED DISHES:

CHICKEN INASAL (Filipino) vs TANDOORI CHICKEN (Indian) vs TERIYAKI CHICKEN (Japanese) vs BBQ CHICKEN (American):

CHICKEN INASAL:
- GOLDEN-ORANGE from annatto
- Served with rice and sinamak
- Charred grill marks

TANDOORI:
- RED from tandoori spices
- Yogurt marinade
- Clay oven cooked

TERIYAKI:
- GLOSSY brown sweet glaze
- Caramelized appearance
- Soy-mirin sauce

BBQ CHICKEN:
- Dark BBQ sauce
- American-style seasoning
- Smoky flavor

SOUP DISHES:

SINIGANG (Filipino) vs TOM YUM (Thai) vs RAMEN (Japanese) vs PHO (Vietnamese):

SINIGANG:
- CLEAR sour broth
- Tamarind base
- Filipino vegetables

TOM YUM:
- ORANGE-RED from chili oil
- Lemongrass, galangal
- Very aromatic

RAMEN:
- Clear or creamy broth
- Thin wheat noodles
- Soft-boiled egg, chashu pork

PHO:
- CLEAR aromatic broth
- Star anise flavor
- Fresh herbs on side

FRIED FOODS:

LUMPIA (Filipino) vs SPRING ROLLS (Chinese/Vietnamese) vs SAMOSA (Indian) vs EMPANADA (Latin/Filipino):

LUMPIA:
- Thin wrapper
- Smaller diameter
- Filipino vegetables/meat

CHINESE SPRING ROLLS:
- Thicker wrapper
- Larger
- Chinese vegetables

VIETNAMESE SPRING ROLLS (Fresh):
- TRANSLUCENT rice paper
- Vegetables/shrimp visible
- Not fried

SAMOSA:
- TRIANGULAR shape
- Thicker pastry
- Spiced potato filling

EMPANADA:
- Half-moon shape
- Ilocano: Orange from annatto
- Latin: Yellow/white pastry

═══════════════════════════════════════════════════════════════════════════════
COMPARISON RULES
═══════════════════════════════════════════════════════════════════════════════

ACCEPT as SAME DISH (confidence 0.80+) if:
1. IDENTICAL base dish name
   - Both are "Pork Menudo" or both are "Pinapaitan"
   - Both are "Chicken Adobo" or both are "Pad Thai"
   - Both are "Butter Chicken" or both are "Kare-Kare"

2. SAME visual characteristics:
   - Sauce/broth color matches (green-brown vs black, orange vs red)
   - Sauce/broth consistency matches (clear vs thick, creamy vs dry)
   - Same protein type visible
   - Same key ingredients visible
   - Same cultural origin (Filipino vs Thai vs Japanese, etc.)

3. ALLOW these differences:
   - Different camera angles
   - Different lighting conditions
   - Different plating/serving vessels
   - Minor garnish variations
   - Different portion sizes

REJECT as DIFFERENT DISH (confidence <0.75) if:
1. DIFFERENT base dishes:
   - One is Pinapaitan (green broth), other is Dinuguan (black gravy) → DIFFERENT
   - One is Pancit (Filipino), other is Pad Thai (Thai) → DIFFERENT
   - One is Kare-Kare (peanut), other is Green Curry (coconut-herb) → DIFFERENT
   - One is Sinigang (clear sour), other is Tom Yum (red spicy) → DIFFERENT

2. DIFFERENT visual characteristics:
   - Color completely different (green vs black, orange vs red, yellow vs brown)
   - Consistency different (thick gravy vs clear soup, dry vs saucy)
   - Different main protein (pork vs beef, chicken vs seafood)
   - Different cultural markers (Filipino vegetables vs Chinese vs Thai)

3. CRITICAL DISTINCTIONS:
   - Filipino vs International: Look at ingredients, color, presentation style
   - Pinapaitan vs Dinuguan: Broth color and consistency
   - Menudo vs Afritada: Meat chunk size
   - Pancit vs Pad Thai: Color and toppings (peanuts, lime)
   - Kare-Kare vs Thai Curry: Peanut sauce vs coconut-herb
   - Adobo vs Teriyaki: Vinegar-soy vs sweet glaze
   - Lumpia vs Spring Rolls: Wrapper thickness, size, filling type

ANALYSIS INSTRUCTIONS

CURRENT DISH NAME: $currentDishName
CACHED DISH NAME: $cachedDishName

Step 1: Identify the BASE DISH and CULTURAL ORIGIN in each image
- What is the fundamental dish? (e.g., Pinapaitan, Pad Thai, Butter Chicken)
- What cuisine? (Filipino, Thai, Japanese, Chinese, Indian, Western, etc.)
- Look at broth/sauce color and consistency FIRST
- Identify main protein and cooking method

Step 2: Compare KEY VISUAL CHARACTERISTICS
- Broth/Sauce Color: Do they match exactly?
- Broth/Sauce Consistency: Both thin or both thick?
- Main Protein: Same type visible in both?
- Key Ingredients: Same vegetables/components/cultural markers?
- Cultural indicators: Filipino vs International styling?

Step 3: Check for CRITICAL DIFFERENCES
- Different cuisines? (Filipino vs Thai vs Chinese, etc.) → Likely DIFFERENT
- Is one a clear soup and the other a thick gravy? → DIFFERENT
- Is one green-tinted and the other black? → DIFFERENT (Pinapaitan vs Dinuguan)
- Different signature ingredients? (peanuts vs no peanuts, tamarind vs lemongrass)
- Are meat pieces drastically different sizes? → Might be DIFFERENT

Step 4: Make FINAL DETERMINATION
- If base dish, color, consistency, AND cultural origin match → SAME (high confidence)
- If similar looking but different cuisines → DIFFERENT (medium-high confidence)
- If only dish name similar but visuals differ → DIFFERENT (low confidence)
- If unsure due to lighting/angle → Medium confidence (0.70-0.79)

Return ONLY JSON:
{
  "isSameDish": true/false,
  "confidence": 0.XX,
  "reasoning": "Detailed explanation: [Base dish identification + cultural origin] + [Color/consistency comparison] + [Key visual matches/differences] + [Cultural markers]"
}

Example reasoning format:
"Both images show Filipino Pinapaitan with characteristic greenish-brown clear broth and visible organ meat chunks. Sauce consistency and color match despite different angles."

OR

"Current image shows Filipino Dinuguan with black thick gravy, while cached image shows Pinapaitan with greenish clear broth. These are different Filipino dishes despite both being organ-based stews."

OR

"Current image shows Thai Pad Thai with orange-red noodles, peanuts, and lime, while cached image shows Filipino Pancit Canton with yellow noodles and Filipino vegetables. Different cuisines and distinct visual characteristics make these different dishes."

OR

"Both images show Indian Butter Chicken with orange-red creamy curry sauce and similar chicken pieces. Cultural markers and sauce consistency match despite different plating."
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

    Map<String, List<String>> allergenCategories = {
      'nuts': [
        'cashew',
        'cashews',
        'almond',
        'almonds',
        'walnut',
        'walnuts',
        'pistachio',
        'pistachios',
        'hazelnut',
        'hazelnuts',
        'pecan',
        'pecans',
        'macadamia',
        'macadamias',
        'brazil nut',
        'brazil nuts',
        'pine nut',
        'pine nuts',
        'chestnut',
        'chestnuts',
      ],
      'tree nuts': [
        'cashew',
        'cashews',
        'almond',
        'almonds',
        'walnut',
        'walnuts',
        'pistachio',
        'pistachios',
        'hazelnut',
        'hazelnuts',
        'pecan',
        'pecans',
        'macadamia',
        'macadamias',
        'brazil nut',
        'brazil nuts',
        'pine nut',
        'pine nuts',
        'chestnut',
        'chestnuts',
      ],
      'shellfish': [
        'shrimp',
        'shrimps',
        'prawn',
        'prawns',
        'crab',
        'crabs',
        'lobster',
        'lobsters',
        'crayfish',
        'mussel',
        'mussels',
        'clam',
        'clams',
        'oyster',
        'oysters',
        'scallop',
        'scallops',
        'squid',
        'squids',
        'octopus',
      ],
      'crustacean': [
        'shrimp',
        'shrimps',
        'prawn',
        'prawns',
        'crab',
        'crabs',
        'lobster',
        'lobsters',
        'crayfish',
      ],
      'fish': [
        'tuna',
        'salmon',
        'tilapia',
        'bangus',
        'milkfish',
        'cod',
        'mackerel',
        'sardines',
        'sardine',
        'anchovies',
        'anchovy',
        'galunggong',
        'fish sauce',
        'patis',
        'fish paste',
        'bagoong isda',
      ],
      'milk': [
        'milk',
        'dairy',
        'cheese',
        'butter',
        'cream',
        'yogurt',
        'yoghurt',
        'whey',
        'casein',
        'lactose',
        'gatas',
      ],
      'dairy': [
        'milk',
        'cheese',
        'butter',
        'cream',
        'yogurt',
        'yoghurt',
        'whey',
        'casein',
        'lactose',
        'gatas',
      ],
      'soy': [
        'soy',
        'soya',
        'soybean',
        'soybeans',
        'soy sauce',
        'toyo',
        'tofu',
        'tokwa',
        'edamame',
        'soy protein',
        'soy milk',
      ],
      'egg': ['egg', 'eggs', 'itlog', 'albumin'],
      'eggs': ['egg', 'eggs', 'itlog', 'albumin'],
      'wheat': ['wheat', 'gluten', 'flour', 'harina'],
      'gluten': ['wheat', 'gluten', 'flour', 'harina'],
      'sesame': ['sesame', 'sesame seed', 'sesame seeds', 'tahini'],
    };

    for (String userAllergen in userAllergens) {
      String cleanUserAllergen = userAllergen.toLowerCase().trim();

      if (cleanAllergenName == cleanUserAllergen) {
        return userAllergen;
      }

      if (isSingularPlural(cleanAllergenName, cleanUserAllergen)) {
        return userAllergen;
      }
    }

    for (String userAllergen in userAllergens) {
      String cleanUserAllergen = userAllergen.toLowerCase().trim();

      if (allergenCategories.containsKey(cleanUserAllergen)) {
        List<String> categoryItems = allergenCategories[cleanUserAllergen]!;

        for (String categoryItem in categoryItems) {
          if (cleanAllergenName == categoryItem ||
              cleanAllergenName.contains(categoryItem) ||
              categoryItem.contains(cleanAllergenName)) {
            print(
              'Category match: "$cleanAllergenName" matches user allergen "$cleanUserAllergen"',
            );
            return userAllergen;
          }
        }
      }

      if (allergenCategories.containsKey(cleanAllergenName)) {
        List<String> categoryItems = allergenCategories[cleanAllergenName]!;

        if (categoryItems.any(
          (item) =>
              item == cleanUserAllergen ||
              item.contains(cleanUserAllergen) ||
              cleanUserAllergen.contains(item),
        )) {
          print(
            'category match: user allergen "$cleanUserAllergen" is in detected category "$cleanAllergenName"',
          );
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
        return userAllergen;
      }
    }

    for (String userAllergen in userAllergens) {
      String cleanUserAllergen = userAllergen.toLowerCase().trim();

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
