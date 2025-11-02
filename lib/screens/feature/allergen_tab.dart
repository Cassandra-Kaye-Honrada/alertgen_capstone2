import 'dart:math' as math;

import 'package:allergen/screens/feature/scan_screen.dart';
import 'package:allergen/screens/models/food_alterntive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:allergen/styleguide.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AllergenTab extends StatefulWidget {
  final List<AllergenInfo> currentAllergens;
  final bool isUpdatingAllergens;
  final String? productName;
  final bool isOCRAnalysis;
  const AllergenTab({
    Key? key,
    required this.currentAllergens,
    required this.isUpdatingAllergens,
    this.productName,
    required this.isOCRAnalysis,
  }) : super(key: key);
  @override
  AllergenTabState createState() => AllergenTabState();
}

class AllergenTabState extends State<AllergenTab> {
  List<FoodAlternative> foodAlternatives = [];
  bool isLoadingAlternatives = false;
  Set<String> userAllergens = {};
  bool isLoadingUserAllergens = true;
  bool showAllAllergens = true;
  String? errorMessage;
  bool isCurrentlyLoadingAlternatives = false;
  String? currentProductDocId;

  static const String GEMINI_API_URL =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      initializeData();
    });
  }

  Future<void> initializeData() async {
    await loadUserAllergens();
    await loadDisplaySetting();
    if (hasUserAllergens()) {
      await loadOrGenerateAlternatives();
    }
  }

  @override
  void didUpdateWidget(AllergenTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!isLoadingUserAllergens &&
        !widget.isUpdatingAllergens &&
        !listEquals(oldWidget.currentAllergens, widget.currentAllergens) &&
        widget.isOCRAnalysis &&
        widget.currentAllergens.isNotEmpty &&
        widget.productName != null) {
      Future.delayed(Duration(milliseconds: 50), () {
        if (mounted) {
          loadOrGenerateAlternatives();
        }
      });
    }
  }

  Future<void> loadOrGenerateAlternatives() async {
    if (widget.productName == null || widget.productName!.isEmpty) {
      print('No product name, skipping alternatives');
      return;
    }

    List<FoodAlternative>? savedAlternatives =
        await loadAlternativesFromFirebase();

    if (savedAlternatives != null && savedAlternatives.isNotEmpty) {
      if (mounted) {
        setState(() {
          foodAlternatives = savedAlternatives;
          isLoadingAlternatives = false;
        });
      }
      print('Loaded ${savedAlternatives.length} alternatives from Firebase');
    } else {
      await generateAndSaveAlternatives();
    }
  }

  Future<List<FoodAlternative>?> loadAlternativesFromFirebase() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      String productKey = getProductKey();

      QuerySnapshot querySnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('food_alternatives')
              .where('productKey', isEqualTo: productKey)
              .limit(1)
              .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      DocumentSnapshot doc = querySnapshot.docs.first;
      currentProductDocId = doc.id;

      List<dynamic> alternativesData = doc['alternatives'] ?? [];
      List<FoodAlternative> alternatives =
          alternativesData
              .map(
                (data) =>
                    FoodAlternative.fromJson(data as Map<String, dynamic>),
              )
              .toList();

      return alternatives;
    } catch (e) {
      print('Error loading alternatives from Firebase: $e');
      return null;
    }
  }

  Future<void> saveAlternativesToFirebase(
    List<FoodAlternative> alternatives,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      String productKey = getProductKey();

      Map<String, dynamic> data = {
        'productKey': productKey,
        'productName': widget.productName,
        'alternatives': alternatives.map((alt) => alt.toJson()).toList(),
        'timestamp': FieldValue.serverTimestamp(),
        'userAllergens': userAllergens.toList(),
      };

      if (currentProductDocId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('food_alternatives')
            .doc(currentProductDocId)
            .update(data);
      } else {
        DocumentReference docRef = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('food_alternatives')
            .add(data);
        currentProductDocId = docRef.id;
      }
    } catch (e) {
      print('Error saving alternatives to Firebase: $e');
    }
  }

  String getProductKey() {
    String normalized = widget.productName?.toLowerCase().trim() ?? '';
    List<String> allergensKey = userAllergens.toList()..sort();
    return '$normalized-${allergensKey.join(',')}';
  }

  Future<void> generateAndSaveAlternatives() async {
    if (isCurrentlyLoadingAlternatives) {
      print('Already loading alternatives');
      return;
    }

    isCurrentlyLoadingAlternatives = true;

    if (!mounted) {
      isCurrentlyLoadingAlternatives = false;
      return;
    }

    setState(() {
      isLoadingAlternatives = true;
      errorMessage = null;
    });

    try {
      List<FoodAlternative> alternatives = await getAIPoweredAlternatives();

      if (alternatives.isNotEmpty) {
        await saveAlternativesToFirebase(alternatives);
      }

      if (mounted) {
        setState(() {
          foodAlternatives = alternatives;
          isLoadingAlternatives = false;
        });
      }
    } catch (e) {
      print('Error loading alternatives: $e');

      if (mounted) {
        setState(() {
          foodAlternatives = [];
          isLoadingAlternatives = false;
          errorMessage = 'Failed to load alternatives';
        });
      }
    } finally {
      isCurrentlyLoadingAlternatives = false;
    }
  }

  Future<void> refreshAlternatives() async {
    await generateAndSaveAlternatives();
  }

  Future<String?> searchProductImage(String productName, String brand) async {
    try {
      String apiKey = dotenv.env['GOOGLE_API_KEY'] ?? '';
      String cseId = dotenv.env['GOOGLE_CSE_ID'] ?? '';

      if (apiKey.isEmpty || cseId.isEmpty) {
        print('Google API keys not configured in .env file');
        return null;
      }

      List<String> searchQueries = [
        '$brand $productName food product Philippines',
        '$brand $productName grocery product',
        '$productName $brand food package',
      ];

      for (String query in searchQueries) {
        print('Searching image: $query');

        try {
          final response = await http
              .get(
                Uri.parse(
                  'https://www.googleapis.com/customsearch/v1?'
                  'key=$apiKey&'
                  'cx=$cseId&'
                  'q=${Uri.encodeQueryComponent(query)}&'
                  'searchType=image&'
                  'num=5&'
                  'imgSize=medium&'
                  'safe=active&'
                  'imgType=photo',
                ),
              )
              .timeout(Duration(seconds: 10));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);

            if (data['items'] != null && data['items'].isNotEmpty) {
              for (var item in data['items']) {
                String? imageUrl = item['link'] as String?;
                String? title = item['title']?.toString().toLowerCase() ?? '';
                String? snippet =
                    item['snippet']?.toString().toLowerCase() ?? '';
                String? contextLink =
                    item['image']?['contextLink']?.toString().toLowerCase() ??
                    '';

                if (imageUrl != null &&
                    imageUrl.isNotEmpty &&
                    (imageUrl.startsWith('http://') ||
                        imageUrl.startsWith('https://')) &&
                    isFoodRelatedImage(
                      imageUrl,
                      title,
                      snippet,
                      contextLink,
                      productName,
                      brand,
                    )) {
                  print(
                    'Found food image: ${imageUrl.substring(0, math.min(50, imageUrl.length))}...',
                  );
                  return imageUrl;
                }
              }
              print('Images found but none appear to be food products');
            } else {
              print('No images in response for: $query');
            }
          } else if (response.statusCode == 429) {
            print('Rate limit reached for Google Custom Search');
            break;
          } else {
            print(
              'API error ${response.statusCode}: ${response.body.substring(0, math.min(100, response.body.length))}',
            );
          }
        } catch (e) {
          print('Search error for "$query": $e');
          continue;
        }
      }

      print('No valid food images found after trying all queries');
      return null;
    } catch (e) {
      print('Fatal error in image search: $e');
      return null;
    }
  }

  bool isFoodRelatedImage(
    String imageUrl,
    String title,
    String snippet,
    String contextLink,
    String productName,
    String brand,
  ) {
    List<String> foodKeywords = [
      'food',
      'grocery',
      'product',
      'package',
      'snack',
      'drink',
      'beverage',
      'nutrition',
      'ingredient',
      'brand',
      'supermarket',
      'store',
      'milk',
      'bread',
      'cereal',
      'sauce',
      'chip',
      'cookie',
      'candy',
      'chocolate',
      productName.toLowerCase(),
      brand.toLowerCase(),
    ];

    List<String> excludeKeywords = [
      'person',
      'people',
      'man',
      'woman',
      'child',
      'baby',
      'face',
      'logo',
      'icon',
      'clipart',
      'vector',
      'illustration',
      'drawing',
      'restaurant',
      'recipe',
      'cooking',
      'prepared',
      'dish',
      'meal',
      'served',
      'plate',
      'bowl',
    ];

    String combinedText =
        '$title $snippet $contextLink $imageUrl'.toLowerCase();

    bool hasFoodKeyword = foodKeywords.any(
      (keyword) => keyword.isNotEmpty && combinedText.contains(keyword),
    );

    bool hasExcludedKeyword = excludeKeywords.any(
      (keyword) => combinedText.contains(keyword),
    );

    bool isFromGrocerySite =
        contextLink.contains('shop') ||
        contextLink.contains('store') ||
        contextLink.contains('grocery') ||
        contextLink.contains('lazada') ||
        contextLink.contains('shopee') ||
        contextLink.contains('amazon');

    bool hasValidImageUrl =
        !imageUrl.toLowerCase().contains('avatar') &&
        !imageUrl.toLowerCase().contains('profile') &&
        !imageUrl.toLowerCase().contains('user');

    return hasFoodKeyword && !hasExcludedKeyword && hasValidImageUrl ||
        isFromGrocerySite;
  }

  bool hasUserAllergens() {
    return widget.currentAllergens.any((allergen) => allergen.isUserAllergen);
  }

  Future<List<FoodAlternative>> getAIPoweredAlternatives() async {
    try {
      String apiKey = dotenv.env['API_KEY'] ?? '';
      if (apiKey.isEmpty) {
        throw Exception('Gemini API key not found in .env file');
      }

      print('Sending request to Gemini API...');
      String prompt = buildGeminiPrompt();

      final response = await http.post(
        Uri.parse('$GEMINI_API_URL?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt},
              ],
            },
          ],
          'generationConfig': {
            'temperature': 0.7,
            'topK': 40,
            'topP': 0.95,
            'maxOutputTokens': 8192,
            'responseMimeType': 'application/json',
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['candidates'] == null || data['candidates'].isEmpty) {
          throw Exception('No candidates in response');
        }

        final candidate = data['candidates'][0];
        String? generatedText;

        if (candidate['content']?['parts'] != null) {
          final parts = candidate['content']['parts'] as List;
          if (parts.isNotEmpty && parts[0]['text'] != null) {
            generatedText = parts[0]['text'] as String;
          }
        }

        if (generatedText == null || generatedText.trim().isEmpty) {
          return getMockAlternatives();
        }

        List<FoodAlternative> alternatives = parseGeminiResponse(generatedText);

        for (var alternative in alternatives) {
          try {
            String? imageUrl = await searchProductImage(
              alternative.name,
              alternative.brand,
            );
            if (imageUrl != null) {
              final index = alternatives.indexOf(alternative);
              alternatives[index] = FoodAlternative(
                name: alternative.name,
                brand: alternative.brand,
                description: alternative.description,
                isPhilippines: alternative.isPhilippines,
                availableAt: alternative.availableAt,
                ingredients: alternative.ingredients,
                isSafeForUserAllergens: alternative.isSafeForUserAllergens,
                imageUrl: imageUrl,
              );
            }
          } catch (e) {
            print('Error getting image for ${alternative.name}: $e');
          }
        }

        if (alternatives.isEmpty) {
          return getMockAlternatives();
        }

        return alternatives;
      } else {
        print('API Error: ${response.statusCode} - ${response.body}');
        throw Exception('API request failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in Alternative Product Search: $e');
      return getMockAlternatives();
    }
  }

  String buildGeminiPrompt() {
    String allergensText = userAllergens.join(', ');
    String productName = widget.productName ?? 'food product';

    return '''
You are a Philippine food product expert. Find 3 allergen-safe alternatives.

Product to replace: "$productName"
User allergies: $allergensText

Return ONLY a JSON array (no markdown, no explanation):
[
  {
    "name": "Product Name",
    "brand": "Brand Name", 
    "description": "Brief description",
    "isPhilippines": true,
    "availableAt": ["SM", "Puregold"],
    "price": 100.0,
    "ingredients": ["ingredient1", "ingredient2"],
    "isSafeForUserAllergens": true
  }
]

Requirements:
- Must be available in the Philippines
- Must NOT contain: $allergensText
- Include price in Philippine Peso
- List actual stores (SM, Puregold, Robinson's, Shopee, Lazada, etc.)
- Provide specific, real product names and brands for image search
''';
  }

  List<FoodAlternative> parseGeminiResponse(String response) {
    try {
      print('Parsing response...');
      String jsonStr = response.trim();

      if (jsonStr.startsWith('```')) {
        jsonStr = jsonStr.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
        jsonStr = jsonStr.replaceFirst(RegExp(r'\s*```\s*$'), '');
        jsonStr = jsonStr.trim();
      }

      if (!jsonStr.endsWith(']')) {
        int lastCloseBrace = jsonStr.lastIndexOf('}');

        if (lastCloseBrace > 0) {
          jsonStr = jsonStr.substring(0, lastCloseBrace + 1);

          if (!jsonStr.trim().endsWith(']')) {
            jsonStr = jsonStr.trim() + '\n]';
          }
        } else {
          print('Could not repair JSON');
          return [];
        }
      }

      dynamic parsedData = jsonDecode(jsonStr);
      print('JSON parsed successfully');

      List<dynamic> alternativesJson = [];

      if (parsedData is List) {
        alternativesJson = parsedData;
      } else if (parsedData is Map<String, dynamic>) {
        if (parsedData.containsKey('alternatives')) {
          alternativesJson = parsedData['alternatives'] as List;
        } else if (parsedData.containsKey('products')) {
          alternativesJson = parsedData['products'] as List;
        } else {
          alternativesJson = [parsedData];
        }
      }

      print('Found ${alternativesJson.length} products to parse');

      List<FoodAlternative> alternatives = [];

      for (var item in alternativesJson) {
        if (item is! Map<String, dynamic>) {
          continue;
        }

        try {
          if (item['name'] == null || item['name'].toString().isEmpty) {
            continue;
          }

          if (item['brand'] == null || item['brand'].toString().isEmpty) {
            continue;
          }

          FoodAlternative alt = FoodAlternative.fromJson(item);
          alternatives.add(alt);
          print('Parsed: ${alt.name} by ${alt.brand}');
        } catch (e) {
          print('Error parsing item: $e');
          continue;
        }
      }

      print('Successfully parsed ${alternatives.length} alternatives');
      return alternatives;
    } catch (e) {
      print('Parse error: $e');
      print(
        'Raw response (first 300 chars): ${response.substring(0, math.min(300, response.length))}',
      );
      return [];
    }
  }

  String getCategoryFromProductName(String productName) {
    String name = productName.toLowerCase();
    if (name.contains('milk') || name.contains('dairy')) return 'dairy';
    if (name.contains('bread') || name.contains('wheat')) return 'bakery';
    if (name.contains('snack') || name.contains('chip')) return 'snacks';
    if (name.contains('sauce') || name.contains('dressing'))
      return 'condiments';
    if (name.contains('cereal')) return 'breakfast';
    return 'general';
  }

  List<FoodAlternative> getMockAlternatives() {
    String productCategory = getCategoryFromProductName(
      widget.productName ?? '',
    );

    Map<String, List<FoodAlternative>> categoryAlternatives = {
      'dairy': [
        FoodAlternative(
          name: 'Coconut Milk',
          brand: 'Fiesta',
          description: 'Local coconut milk, naturally dairy-free',
          isPhilippines: true,
          availableAt: ['SM Supermarket', 'Puregold', 'Robinson\'s'],
          isSafeForUserAllergens: true,
          imageUrl: null,
        ),
      ],
    };

    return categoryAlternatives[productCategory] ??
        categoryAlternatives['dairy']!;
  }

  Future<void> loadUserAllergens() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        QuerySnapshot allergenSnapshot =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('profile')
                .where('type', isEqualTo: 'allergen')
                .get();
        Set<String> allergens = {};
        for (QueryDocumentSnapshot doc in allergenSnapshot.docs) {
          String allergenName = doc['name'].toString().toLowerCase();
          allergens.add(allergenName);
        }
        if (mounted) {
          setState(() {
            userAllergens = allergens;
            isLoadingUserAllergens = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            isLoadingUserAllergens = false;
          });
        }
      }
    } catch (e) {
      print('Error loading user allergens: $e');
      if (mounted) {
        setState(() {
          isLoadingUserAllergens = false;
        });
      }
    }
  }

  Future<void> loadDisplaySetting() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot snapshot =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('settings')
                .doc('allergen_display')
                .get();
        if (snapshot.exists) {
          if (mounted) {
            setState(() {
              showAllAllergens = snapshot['showAllAllergens'] ?? true;
            });
          }
        }
      }
    } catch (e) {
      print('Error loading display setting: $e');
    }
  }

  List<AllergenInfo> getAllergensToDisplay() {
    if (showAllAllergens) {
      return widget.currentAllergens;
    }

    final filteredAllergens = widget.currentAllergens.where((allergen) {
      return allergen.isUserAllergen;
    });

    return filteredAllergens.toList();
  }

  Color getAllergenColor(AllergenInfo allergen) {
    if (allergen.isUserAllergen) {
      return Colors.red;
    }
    return AppColors.primary;
  }

  Color getAllergenBackgroundColor(AllergenInfo allergen) {
    if (allergen.isUserAllergen) {
      return Colors.red.withOpacity(0.1);
    }
    return Colors.white;
  }

  Color getAllergenBorderColor(AllergenInfo allergen) {
    if (allergen.isUserAllergen) {
      return Colors.red.withOpacity(0.3);
    }
    return Colors.transparent;
  }

  bool isAllergenMatch(String detectedAllergen) {
    String cleanDetected = detectedAllergen.toLowerCase().trim();

    for (String userAllergen in userAllergens) {
      String cleanUser = userAllergen.toLowerCase().trim();

      if (cleanUser == cleanDetected) return true;

      if (isSingularPlural(cleanUser, cleanDetected)) return true;

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

      bool userIsPeanut = cleanUser.contains('peanut');
      bool detectedIsPeanut = cleanDetected.contains('peanut');

      bool userIsSpecificTreeNut = treeNuts.any(
        (nut) => cleanUser.contains(nut),
      );

      bool detectedIsSpecificTreeNut = treeNuts.any(
        (nut) => cleanDetected.contains(nut),
      );

      bool userIsGenericNut =
          (cleanUser == 'nut' ||
              cleanUser == 'nuts' ||
              cleanUser == 'tree nut' ||
              cleanUser == 'tree nuts');

      if (userIsGenericNut && detectedIsPeanut) {
        continue;
      }

      if (userIsPeanut &&
          (cleanDetected == 'nut' ||
              cleanDetected == 'nuts' ||
              cleanDetected == 'tree nut' ||
              cleanDetected == 'tree nuts')) {
        continue;
      }

      if (userIsPeanut && detectedIsPeanut) {
        return true;
      }

      if (userIsSpecificTreeNut && detectedIsSpecificTreeNut) {
        bool sameTreeNut = treeNuts.any((nut) {
          return cleanUser.contains(nut) && cleanDetected.contains(nut);
        });
        if (sameTreeNut) return true;
        continue;
      }

      if (userIsSpecificTreeNut &&
          (cleanDetected == 'nut' ||
              cleanDetected == 'nuts' ||
              cleanDetected == 'tree nut' ||
              cleanDetected == 'tree nuts')) {
        continue;
      }

      if (userIsGenericNut && detectedIsSpecificTreeNut) {
        return true;
      }

      if ((userIsPeanut && detectedIsSpecificTreeNut) ||
          (userIsSpecificTreeNut && detectedIsPeanut)) {
        continue;
      }

      bool userIsSpecificShellfish = [
        'shrimp',
        'crab',
        'lobster',
      ].any((specific) => cleanUser.contains(specific));

      bool detectedIsSpecificShellfish = [
        'shrimp',
        'crab',
        'lobster',
      ].any((specific) => cleanDetected.contains(specific));

      if (userIsSpecificShellfish && detectedIsSpecificShellfish) {
        bool sameType = ['shrimp', 'crab', 'lobster'].any((type) {
          return cleanUser.contains(type) && cleanDetected.contains(type);
        });
        if (sameType) return true;
        continue;
      }

      if (userIsSpecificShellfish &&
          (cleanDetected.contains('shellfish') ||
              cleanDetected.contains('crustacean'))) {
        continue;
      }

      if ((cleanUser.contains('shellfish') ||
              cleanUser.contains('crustacean')) &&
          detectedIsSpecificShellfish) {
        return true;
      }

      String? userGroup = findAllergenGroup(cleanUser, getAllergenGroups());
      String? detectedGroup = findAllergenGroup(
        cleanDetected,
        getAllergenGroups(),
      );

      if (userGroup != null &&
          detectedGroup != null &&
          userGroup == detectedGroup) {
        return true;
      }

      RegExp userPattern = RegExp(r'\b' + RegExp.escape(cleanUser) + r'\b');
      RegExp detectedPattern = RegExp(
        r'\b' + RegExp.escape(cleanDetected) + r'\b',
      );

      if (userPattern.hasMatch(cleanDetected) ||
          detectedPattern.hasMatch(cleanUser)) {
        if (cleanUser == 'fish' && cleanDetected.contains('shellfish')) {
          continue;
        }
        if (cleanDetected == 'fish' && cleanUser.contains('shellfish')) {
          continue;
        }
        return true;
      }
    }

    return false;
  }

  Map<String, List<String>> getAllergenGroups() {
    return {
      'milk': ['milk', 'dairy', 'lactose', 'casein', 'whey'],
      'egg': ['egg', 'eggs', 'albumin'],
      'peanut': ['peanut', 'peanuts', 'groundnut', 'groundnuts'],
      'fish': ['fish', 'tuna', 'salmon', 'cod', 'mackerel'],
      'shellfish': ['shellfish', 'shell fish', 'crustacean', 'crustaceans'],
      'shrimp': ['shrimp', 'shrimps', 'prawn', 'prawns'],
      'crab': ['crab', 'crabs'],
      'lobster': ['lobster', 'lobsters'],
      'wheat': ['wheat', 'gluten'],
      'soy': ['soy', 'soya', 'soybean', 'soybeans'],
      'tree_nuts': [
        'tree nuts',
        'tree nut',
        'almond',
        'almonds',
        'walnut',
        'walnuts',
        'cashew',
        'cashews',
        'hazelnut',
        'hazelnuts',
        'pecan',
        'pecans',
        'pistachio',
        'pistachios',
        'macadamia',
        'brazil nut',
        'brazil nuts',
      ],
      'sesame': ['sesame', 'sesame seed', 'sesame seeds'],
    };
  }

  bool isSingularPlural(String word1, String word2) {
    if (word2 == word1 + 's' || word1 == word2 + 's') return true;
    if (word2 == word1 + 'es' || word1 == word2 + 'es') return true;
    if (word1.endsWith('y') &&
        word2 == word1.substring(0, word1.length - 1) + 'ies') {
      return true;
    }
    if (word2.endsWith('y') &&
        word1 == word2.substring(0, word2.length - 1) + 'ies') {
      return true;
    }
    return false;
  }

  String? findAllergenGroup(
    String allergen,
    Map<String, List<String>> allergenGroups,
  ) {
    for (String group in allergenGroups.keys) {
      if (allergenGroups[group]!.any((item) => allergen.contains(item))) {
        return group;
      }
    }
    return null;
  }

  Widget buildAllergenContent() {
    List<AllergenInfo> displayAllergens = getAllergensToDisplay();
    if (displayAllergens.isNotEmpty) {
      return Wrap(
        spacing: 12,
        runSpacing: 16,
        children:
            displayAllergens.map((allergen) {
              Color allergenColor = getAllergenColor(allergen);
              Color backgroundColor = getAllergenBackgroundColor(allergen);
              Color borderColor = getAllergenBorderColor(allergen);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      border: Border.all(color: borderColor, width: 1.5),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          spreadRadius: 1,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: FaIcon(
                        allergen.iconData,
                        color: AppColors.primaryColor3,
                        size: 22,
                      ),
                    ),
                  ),
                  SizedBox(height: 6),
                  SizedBox(
                    width: 80,
                    child: Text(
                      allergen.name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: allergenColor,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );
            }).toList(),
      );
    } else {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              spreadRadius: 1,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 48),
            SizedBox(height: 8),
            Text(
              'No Allergens Detected',
              style: TextStyle(
                color: Colors.green,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'This food appears to be safe',
              style: TextStyle(color: Colors.green[700], fontSize: 14),
            ),
          ],
        ),
      );
    }
  }

  Widget buildAlternativesSection() {
    if (!hasUserAllergens()) {
      return SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Safe Alternatives',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
              // Refresh button
              if (!isLoadingAlternatives && foodAlternatives.isNotEmpty)
                IconButton(
                  icon: Icon(Icons.refresh, color: AppColors.primary),
                  tooltip: 'Refresh alternatives',
                  onPressed: () async {
                    await refreshAlternatives();
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),

          if (isLoadingAlternatives)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text(
                      'Finding safe alternatives...',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            )
          else if (foodAlternatives.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No alternatives found',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: foodAlternatives.length,
              separatorBuilder: (context, index) => Divider(height: 24),
              itemBuilder: (context, index) {
                FoodAlternative alt = foodAlternatives[index];
                return buildAlternativeCard(alt);
              },
            ),
        ],
      ),
    );
  }

  Widget buildAlternativeCard(FoodAlternative alternative) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.defaultbackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (alternative.imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: alternative.imageUrl!,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    placeholder:
                        (context, url) => Container(
                          width: 50,
                          height: 50,
                          color: Colors.grey.shade300,
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                    errorWidget:
                        (context, url, error) => Container(
                          width: 50,
                          height: 50,
                          color: Colors.grey.shade300,
                          child: Icon(
                            Icons.fastfood,
                            color: Colors.grey.shade500,
                          ),
                        ),
                  ),
                )
              else
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.fastfood, color: AppColors.primary),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alternative.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    Text(
                      alternative.brand,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (alternative.isPhilippines)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '🇵🇭 PH',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            alternative.description,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),

          if (alternative.availableAt.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children:
                  alternative.availableAt.map((store) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        store,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget buildCenteredLoadingIndicator() {
    return Container(
      width: double.infinity,
      height: 250,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 50,
            height: 50,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Analyzing Allergens...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Please wait while we check for allergens',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Allergenic Overview',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          widget.isUpdatingAllergens || isLoadingUserAllergens
              ? buildCenteredLoadingIndicator()
              : buildAllergenContent(),
          SizedBox(height: 24),
          if (widget.isOCRAnalysis) ...[
            if (errorMessage != null)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 32),
                    SizedBox(height: 8),
                    Text(
                      'Search Failed',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      errorMessage!,
                      style: TextStyle(color: Colors.red[700], fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else if (!widget.isUpdatingAllergens &&
                getAllergensToDisplay().isNotEmpty)
              buildAlternativesSection()
            else if (!widget.isUpdatingAllergens)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.info, color: Colors.blue, size: 32),
                    SizedBox(height: 8),
                    Text(
                      'No Alternatives Needed',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'This product is safe for you!',
                      style: TextStyle(color: Colors.blue[700], fontSize: 12),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
