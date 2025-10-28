import 'dart:convert';
import 'package:allergen/screens/feature/scan_screen.dart';
import 'package:allergen/services/translation/translation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AllergenAnalysis {
  String generateCacheKey(String dishName) {
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

    if (mainProtein.isNotEmpty) {
      return '${mainProtein}_${baseDish}';
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
    };

    String cleaned = dishName.toLowerCase().trim();

    for (var entry in dishVariations.entries) {
      String baseKey = entry.key;
      List<String> variations = entry.value;

      for (String variation in variations) {
        if (cleaned == variation ||
            cleaned.startsWith(variation + ' ') ||
            cleaned.endsWith(' ' + variation) ||
            cleaned.contains(' ' + variation + ' ')) {
          return baseKey;
        }
      }
    }

    return cleaned.replaceAll(RegExp(r'\s+'), '_');
  }

  Future<Map<String, dynamic>?> checkFoodCache(String cacheKey) async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('food_cache')
              .doc(cacheKey)
              .get();

      if (doc.exists) {
        FirebaseFirestore.instance
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
      print('Error checking cache: $e');
      return null;
    }
  }

  Future<void> saveFoodCache(
    String cacheKey,
    String dishName,
    String description,
    List<String> ingredients,
    List<AllergenInfo> allergens,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('food_cache')
          .doc(cacheKey)
          .set({
            'dishName': dishName,
            'description': description,
            'ingredients': ingredients,
            'allergens': allergens.map((a) => a.toJson()).toList(),
            'timestamp': FieldValue.serverTimestamp(),
            'lastAccessed': FieldValue.serverTimestamp(),
            'accessCount': 1,
          });
    } catch (e) {
      print('Error saving to cache: $e');
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
    String englishName = await TranslationService.instance.translateToEnglish(tagalogName);
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
  translatedSeverity.keys.toList(),          );

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
    if (word2 == word1 + 's' || word1 == word2 + 's') return true;
    if (word2 == word1 + 'es' || word1 == word2 + 'es') return true;
    if (word1.endsWith('y') &&
        word2 == word1.substring(0, word1.length - 1) + 'ies')
      return true;
    if (word2.endsWith('y') &&
        word1 == word2.substring(0, word2.length - 1) + 'ies')
      return true;
    return false;
  }

  Future<String?> findMatchingUserAllergen (
    String allergenName,
    List<String> userAllergens,
  ) async{
    String cleanAllergenName = allergenName.toLowerCase().trim();

    for (String userAllergen in userAllergens) {
      String cleanUserAllergen = userAllergen.toLowerCase().trim();

      if (cleanAllergenName == cleanUserAllergen) return userAllergen;

          bool areEquivalent = await TranslationService.instance.areTermsEquivalent(
      cleanAllergenName,
      cleanUserAllergen,
    );
    if (areEquivalent) return userAllergen;

      if (isSingularPlural(cleanAllergenName, cleanUserAllergen))
        return userAllergen;

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

      List<String> specificNuts = [
        'cashew',
        'almond',
        'walnut',
        'pistachio',
        'hazelnut',
        'pecan',
        'macadamia',
        'brazil nut',
      ];
      bool userIsSpecificNut = specificNuts.any(
        (specific) => cleanUserAllergen.contains(specific),
      );

      bool detectedIsSpecificNut = specificNuts.any(
        (specific) => cleanAllergenName.contains(specific),
      );

      if (userIsSpecificNut && detectedIsSpecificNut) {
        bool sameType = specificNuts.any((type) {
          return cleanUserAllergen.contains(type) &&
              cleanAllergenName.contains(type);
        });

        if (sameType) {
          return userAllergen;
        }
        continue;
      }

      if (userIsSpecificNut &&
          (cleanAllergenName.contains('nut') ||
              cleanAllergenName.contains('tree nut'))) {
        continue;
      }

      if ((cleanUserAllergen.contains('nut') ||
              cleanUserAllergen.contains('tree nut')) &&
          detectedIsSpecificNut) {
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
        (specific) => cleanUserAllergen.contains(specific),
      );

      bool detectedIsSpecificFish = specificFish.any(
        (specific) => cleanAllergenName.contains(specific),
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

      if (userIsSpecificFish && cleanAllergenName.contains('fish')) {
        continue;
      }

      if (cleanUserAllergen.contains('fish') && detectedIsSpecificFish) {
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
        (specific) => cleanUserAllergen.contains(specific),
      );

      bool detectedIsSpecificDairy = specificDairy.any(
        (specific) => cleanAllergenName.contains(specific),
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

      if (userIsSpecificDairy && cleanAllergenName.contains('dairy')) {
        continue;
      }

      if (cleanUserAllergen.contains('dairy') && detectedIsSpecificDairy) {
        return userAllergen;
      }

      if (areAllergenSynonyms(cleanAllergenName, cleanUserAllergen))
        return userAllergen;

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

  bool isCompoundWordMismatch(String compound, String part) {
    const List<List<String>> exclusions = [
      // Shellfish
      ['shrimp', 'shellfish'],
      ['crab', 'shellfish'],
      ['lobster', 'shellfish'],
      ['shellfish', 'fish'],
      // Nuts
      ['cashew', 'nut'],
      ['almond', 'nut'],
      ['walnut', 'nut'],
      ['pistachio', 'nut'],
      ['hazelnut', 'nut'],
      ['pecan', 'nut'],
      ['macadamia', 'nut'],
      ['brazil nut', 'nut'],
      ['peanut', 'nut'],
      ['coconut', 'nut'],
      ['nutmeg', 'nut'],
      ['butternut', 'nut'],
      ['chestnut', 'nut'],
      ['water chestnut', 'nut'],
      ['donut', 'nut'],
      ['doughnut', 'nut'],
      // Fish
      ['bagoong', 'fish'],
      ['patis', 'fish'],
      ['fish sauce', 'fish'],
      ['catfish', 'fish'],
      ['fishball', 'fish'],
      ['jellyfish', 'fish'],
      ['starfish', 'fish'],
      // Dairy
      ['coconut milk', 'milk'],
      ['almond milk', 'milk'],
      ['soy milk', 'milk'],
      ['oat milk', 'milk'],
      ['rice milk', 'milk'],
      // Other
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
      'soy': ['soy', 'soya', 'soybean', 'soybeans'],
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
