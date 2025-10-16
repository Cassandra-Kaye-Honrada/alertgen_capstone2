import 'dart:convert';
import 'dart:io';
import 'package:allergen/screens/feature/allergen_analysis.dart';
import 'package:allergen/screens/feature/dish_confimation_screen.dart';
import 'package:allergen/screens/feature/skin_allergy/skin_allergy.dart';
import 'package:allergen/screens/feature/skin_allergy/skin_result_option.dart';
import 'package:allergen/screens/feature/trivia/trivia.dart';
import 'package:allergen/screens/profile_screen_items/ProfileScreen.dart';
import 'package:allergen/screens/feature/homescreen.dart';
import 'package:allergen/screens/feature/result_screen.dart';
import 'package:allergen/services/emergency/emergency_service.dart';
import 'package:allergen/styleguide.dart';
import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

final apiKey = dotenv.env['API_KEY'] ?? '';

class CameraScannerScreen extends StatefulWidget {
  @override
  _CameraScannerScreenState createState() => _CameraScannerScreenState();
}

class _CameraScannerScreenState extends State<CameraScannerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController animationController;
  late Animation<double> animation;

  CameraController? cameraController;
  List<CameraDescription>? cameras;
  bool isCameraInitialized = false;
  FlashMode flashMode = FlashMode.auto;
  bool isRearCamera = true;

  File? image;
  final picker = ImagePicker();
  TextRecognizer? textRecognizer;

  bool loading = false;
  bool isOCRAnalysis = false;
  bool showManualInput = false;

  String dishName = '';
  String description = '';
  String analysisStatus = '';
  List<String> ingredients = [];
  List<AllergenInfo> allergens = [];
  List<IngredientColorInfo> ingredientColors = [];

  final AllergenAnalysis allergenAnalysis = AllergenAnalysis();
  final TextEditingController ingredientController = TextEditingController();
  final FocusNode ingredientFocusNode = FocusNode();
  final TextEditingController dishNameController = TextEditingController();

  bool isSkinAnalysis = false;

  @override
  void initState() {
    super.initState();
    textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    initializeCamera();
    setupAnimation();
    preloadUserAllergens();
  }

  @override
  void dispose() {
    animationController.dispose();
    cameraController?.dispose();
    textRecognizer?.close();
    ingredientController.dispose();
    ingredientFocusNode.dispose();
    dishNameController.dispose();
    super.dispose();
  }

  void setupAnimation() {
    animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: animationController, curve: Curves.easeInOut),
    );
    animationController.repeat(reverse: true);
  }

  Future<void> initializeCamera() async {
    try {
      cameras = await availableCameras();
      if (cameras?.isNotEmpty == true) {
        cameraController = CameraController(
          cameras![isRearCamera ? 0 : 1],
          ResolutionPreset.high,
          enableAudio: false,
        );
        await cameraController!.initialize();
        setState(() => isCameraInitialized = true);
      }
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  Future<void> switchCamera() async {
    if (cameras == null || cameras!.length < 2) return;

    setState(() {
      isRearCamera = !isRearCamera;
      isCameraInitialized = false;
    });

    await cameraController?.dispose();
    cameraController = CameraController(
      isRearCamera ? cameras![0] : cameras![1],
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await cameraController!.initialize();
      setState(() => isCameraInitialized = true);
    } catch (e) {
      print('Error switching camera: $e');
    }
  }

  Future<void> toggleFlash() async {
    if (cameraController?.value.isInitialized != true) return;

    try {
      switch (flashMode) {
        case FlashMode.auto:
          flashMode = FlashMode.always;
          break;
        case FlashMode.always:
          flashMode = FlashMode.off;
          break;
        case FlashMode.off:
          flashMode = FlashMode.torch;
          break;
        case FlashMode.torch:
          flashMode = FlashMode.auto;
          break;
        default:
          flashMode = FlashMode.auto;
      }

      await cameraController!.setFlashMode(flashMode);
      setState(() {});
    } catch (e) {
      print('Error toggling flash: $e');
    }
  }

  Future<void> captureImage() async {
    if (cameraController?.value.isInitialized != true || loading) return;

    try {
      setState(() => loading = true);
      final XFile capturedImage = await cameraController!.takePicture();
      final File imageFile = File(capturedImage.path);
      setState(() => image = imageFile);
      await analyzeImage(imageFile);
    } catch (e) {
      setState(() => loading = false);
      showSnackBar('Error capturing image: $e', Colors.red);
    }
  }

  Future<void> pickImage(ImageSource source) async {
    try {
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 75,
      );
      if (pickedFile != null) {
        setState(() {
          image = File(pickedFile.path);
          loading = true;
        });
        await analyzeImage(image!);
      }
    } catch (e) {
      setState(() => loading = false);
      showSnackBar('Error picking image: $e', Colors.red);
    }
  }

  Future<void> analyzeImage(File imageFile) async {
    try {
      setState(() {
        loading = true;
        analysisStatus = 'Determining image type';
      });

      final imageType = await determineImageType(imageFile);

      setState(() {
        isSkinAnalysis = (imageType == 'skin');
        analysisStatus =
            isSkinAnalysis
                ? 'Analyzing skin condition/allergy...'
                : 'Analyzing food...';
      });

      if (imageType == 'skin') {
        await analyzeSkinCondition(imageFile);
      } else {
        if (textRecognizer != null) {
          final inputImage = InputImage.fromFile(imageFile);
          final recognizedText = await textRecognizer!.processImage(inputImage);
          final ocrText = recognizedText.text.trim();

          if (ocrText.isNotEmpty && isLabeledProduct(ocrText)) {
            await analyzeOCRText(ocrText, imageFile);
          } else {
            await analyzeWithImage(imageFile);
          }
        } else {
          await analyzeWithImage(imageFile);
        }
      }
    } catch (e) {
      print('Error during image analysis: $e');
      setState(() {
        loading = false;
        analysisStatus = '';
        isSkinAnalysis = false;
      });
      showSnackBar('Error analyzing image: $e', Colors.red);
    }
  }

  Future<String> determineImageType(File imageFile) async {
    if (apiKey == 'YOUR_API_KEY_HERE') {
      setState(() => isSkinAnalysis = false);
      return 'food';
    }

    try {
      final model = GenerativeModel(model: 'gemini-2.5-pro', apiKey: apiKey);
      final imageBytes = await imageFile.readAsBytes();

      final prompt = '''
You are an expert image classifier. Analyze this image and determine if it shows:
1. FOOD - any food item, dish, meal, snack, beverage, or food product label
2. SKIN - human skin showing allergic reactions, rashes, irritation, or skin conditions

CRITICAL CLASSIFICATION RULES:
- If the image shows FOOD in any form → return "food"
- If the image shows SKIN with visible allergic reactions, rashes, hives, eczema, dermatitis, or any skin condition → return "skin"
- If unclear or neither → return "food" (default to food analysis)

Return ONLY ONE WORD in JSON format:
{
  "type": "food" or "skin"
}
''';

      final response = await model.generateContent([
        Content.multi([TextPart(prompt), DataPart('image/jpeg', imageBytes)]),
      ]);

      String responseText = response.text ?? '';
      String cleanResponse = responseText;

      if (responseText.contains('```json')) {
        cleanResponse = responseText.split('```json')[1].split('```')[0];
      } else if (responseText.contains('```')) {
        cleanResponse = responseText.split('```')[1];
      }

      final jsonData = json.decode(cleanResponse.trim());
      final imageType = jsonData['type'] ?? 'food';

      setState(() {
        isSkinAnalysis = (imageType == 'skin');
      });

      return imageType;
    } catch (e) {
      print('Error determining image type: $e');
      setState(() => isSkinAnalysis = false);
      return 'food';
    }
  }

  String get skinAnalysisPrompt => '''
You are an expert dermatologist AI specializing in identifying skin allergic reactions and conditions related to FOOD ALLERGIES.

CRITICAL: Generate 3-4 DIFFERENT possible skin condition interpretations with confidence scores. Consider:
1. Most likely condition based on visual characteristics
2. Alternative conditions with similar appearance  
3. Conditions that are commonly mistaken for each other
4. Different severity levels of the same condition

FOOD ALLERGY-RELATED SKIN CONDITIONS TO DETECT:

1. **URTICARIA (HIVES)** - Allergic Reaction
   - Raised, red, itchy welts on skin
   - Most common food allergy skin reaction
   - Can appear anywhere on body
   - Often caused by: shellfish, nuts, eggs, milk, soy, wheat, fish

2. **ANGIOEDEMA** - Severe Allergic Swelling
   - Deep swelling under skin
   - Often affects face, lips, tongue, throat
   - Can accompany hives
   - Emergency if affects breathing
   - Triggered by: nuts, shellfish, eggs, milk

3. **ATOPIC DERMATITIS (ECZEMA)** - Food-Triggered
   - Red, inflamed, itchy patches
   - Dry, scaly skin
   - Can be triggered or worsened by food allergens
   - Common triggers: milk, eggs, peanuts, soy, wheat, fish

4. **CONTACT DERMATITIS** - Direct Food Contact
   - Red, itchy rash where food touched skin
   - Blistering possible
   - Common with: citrus fruits, tomatoes, garlic

5. **FLUSHING** - Histamine Reaction
   - Sudden redness and warmth of skin
   - Often face and neck
   - Can occur with food allergies

6. **ERYTHEMA** - Allergic Redness
   - Red patches or widespread redness
   - Can indicate allergic reaction
   - May accompany other symptoms

7. **PERIORAL DERMATITIS** - Around Mouth
   - Rash around mouth area
   - Can be triggered by certain foods
   - Red bumps, scaling

Return JSON with this exact structure:
{
  "options": [
    {
      "conditionName": "Primary condition name (e.g., 'Urticaria (Hives)', 'Atopic Dermatitis')",
      "isFoodAllergyRelated": true/false,
      "confidence": 0.XX,
      "description": "Detailed description of what you see in the image",
      "severity": "mild|moderate|severe|emergency",
      "likelyFoodTriggers": [
        {
          "allergen": "Specific allergen name",
          "likelihood": "high|moderate|low",
          "reasoning": "Why this allergen is suspected"
        }
      ],
      "symptoms": ["symptom1", "symptom2", "symptom3"],
      "immediateActions": ["action1", "action2", "action3"],
      "foodsToAvoid": ["food1", "food2", "food3"],
      "whenToSeekHelp": "Description of when to seek immediate medical attention",
      "additionalNotes": "Any important additional information"
    }
  ]
}

CONFIDENCE SCORING RULES:
- 0.90-1.00: Very clear visual match
- 0.70-0.89: Good match but could be similar condition
- 0.50-0.69: Moderate match, some ambiguity

CRITICAL REQUIREMENTS:
1. Generate 3-4 distinct options ordered by confidence
2. ONLY identify conditions RELATED TO FOOD ALLERGIES
3. If a condition is NOT food allergy-related, set isFoodAllergyRelated: false
4. Be specific about likely food allergen triggers
5. Provide actionable advice
6. Indicate severity accurately
7. Include emergency warning signs
8. Focus on the 9 FDA major allergens as primary triggers
''';

  Future<void> analyzeSkinCondition(File imageFile) async {
    if (apiKey == 'YOUR_API_KEY_HERE') {
      setState(() => loading = false);
      return;
    }

    try {
      setState(() {
        isSkinAnalysis = true;
        analysisStatus = 'Analyzing skin condition/allergy...';
      });

      final model = GenerativeModel(model: 'gemini-2.5-pro', apiKey: apiKey);
      final imageBytes = await imageFile.readAsBytes();

      final response = await model.generateContent([
        Content.multi([
          TextPart(skinAnalysisPrompt),
          DataPart('image/jpeg', imageBytes),
        ]),
      ]);

      final skinOptions = await parseMultiOptionSkinResponse(
        response.text ?? '',
      );

      setState(() {
        loading = false;
        analysisStatus = '';
      });

      // Show selection screen for multiple options
      await showSkinConditionSelectionScreen(skinOptions, imageFile);
    } catch (e) {
      setState(() {
        loading = false;
        analysisStatus = '';
      });
      showSnackBar('Error analyzing skin condition: $e', Colors.red);
    }
  }

  Future<List<SkinConditionOption>> parseMultiOptionSkinResponse(
    String response,
  ) async {
    try {
      String cleanResponse = response;
      if (response.contains('```json')) {
        cleanResponse = response.split('```json')[1].split('```')[0];
      } else if (response.contains('```')) {
        cleanResponse = response.split('```')[1];
      }

      final jsonData = json.decode(cleanResponse.trim());
      final List<dynamic> optionsJson = jsonData['options'] ?? [];

      final options =
          optionsJson
              .map((optionJson) => SkinConditionOption.fromJson(optionJson))
              .toList();

      options.sort((a, b) => b.confidence.compareTo(a.confidence));

      return options;
    } catch (e) {
      print('Error parsing multi-option skin response: $e');
      return [
        SkinConditionOption(
          conditionName: 'Analysis Complete',
          isFoodAllergyRelated: false,
          confidence: 0.5,
          description:
              'Unable to parse skin analysis. Please consult a healthcare professional.',
          severity: 'unknown',
          likelyFoodTriggers: [],
          symptoms: [],
          immediateActions: ['Consult a dermatologist'],
          foodsToAvoid: [],
          whenToSeekHelp: 'If symptoms worsen or persist',
          additionalNotes:
              'Please consult a healthcare professional for accurate diagnosis',
        ),
      ];
    }
  }

  Future<void> showSkinConditionSelectionScreen(
    List<SkinConditionOption> options,
    File imageFile,
  ) async {
    final selectedOption = await Navigator.push<SkinConditionOption>(
      context,
      MaterialPageRoute(
        builder:
            (context) => SkinConditionSelectionScreen(
              options: options,
              onOptionSelected: (option) {
                Navigator.pop(context, option);
              },
              onManualEntry: () {
                Navigator.pop(context, null);

                showSnackBar(
                  'Please consult a healthcare professional for accurate diagnosis',
                  Colors.blue,
                );
              },
            ),
      ),
    );

    if (selectedOption != null) {
      final skinData = selectedOption.toJson();
      navigateToSkinResults(skinData, imageFile);
    } else {
      setState(() {
        image = null;
        loading = false;
      });
    }
  }

  void navigateToSkinResults(
    Map<String, dynamic> skinData,
    File imageFile,
  ) async {
    await saveSkinToFirebase(skinData, imageFile);

    bool shouldReset = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => SkinResultScreen(skinData: skinData, image: imageFile),
      ),
    );

    if (shouldReset == true) {
      resetCameraState();
    }
  }

  Future<void> saveSkinToFirebase(
    Map<String, dynamic> skinData,
    File imageFile,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      String? imageUrl;
      String? fileName;

      if (await imageFile.exists()) {
        fileName = 'skin_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('skin_images')
            .child(user.uid)
            .child(fileName);

        final uploadTask = storageRef.putFile(imageFile);
        final uploadResult = await uploadTask;
        imageUrl = await uploadResult.ref.getDownloadURL();
      }

      final scanData = {
        'type': 'skin_analysis',
        'conditionName': skinData['conditionName'] ?? 'Unknown Condition',
        'isFoodAllergyRelated': skinData['isFoodAllergyRelated'] ?? false,
        'confidence': skinData['confidence'] ?? 0.5,
        'description': skinData['description'] ?? '',
        'severity': skinData['severity'] ?? 'unknown',
        'likelyFoodTriggers': skinData['likelyFoodTriggers'] ?? [],
        'symptoms': skinData['symptoms'] ?? [],
        'immediateActions': skinData['immediateActions'] ?? [],
        'foodsToAvoid': skinData['foodsToAvoid'] ?? [],
        'whenToSeekHelp': skinData['whenToSeekHelp'] ?? '',
        'additionalNotes': skinData['additionalNotes'] ?? '',
        'imageUrl': imageUrl ?? '',
        'fileName': fileName ?? '',
        'timestamp': FieldValue.serverTimestamp(),
        'scanDate': DateTime.now().toIso8601String(),
        'userId': user.uid,
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('skin_history')
          .add(scanData);
    } catch (e) {
      print('Failed to save skin scan: $e');
    }
  }

  Future<void> preloadUserAllergens() async {
    try {
      await getUserAllergens();
    } catch (e) {
      print('Error preloading user allergens: $e');
    }
  }

  Future<List<String>> getUserAllergens() async {
    try {
      final allergenData = await allergenAnalysis.getUserAllergenData();
      return List<String>.from(allergenData['names']);
    } catch (e) {
      print('Error getting user allergens: $e');
      return [];
    }
  }

  void showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.fixed,
      ),
    );
  }

  bool isLabeledProduct(String ocrText) {
    final lowerText = ocrText.toLowerCase();

    final labelKeywords = [
      'ingredients:',
      'ingredients',
      'contains:',
      'allergens:',
      'nutrition facts',
      'nutritional information',
      'manufactured by',
      'produced by',
      'best before',
      'expiry date',
      'exp date',
      'use by',
      'serving size',
      'calories',
      'total fat',
      'may contain',
      'allergen information',
      'mg',
      'g ',
      ' g',
      'ml',
      ' ml',
      'kcal',
      'kj',
      'sodium',
      'protein',
      'carbohydrate',
      'sugar',
      'barcode',
      'upc',
      'sku',
    ];

    bool hasLabelKeywords = labelKeywords.any(
      (keyword) => lowerText.contains(keyword),
    );

    bool hasIngredientPattern =
        lowerText.contains(',') && (lowerText.split(',').length >= 3);

    bool hasPercentages = RegExp(r'\d+%').hasMatch(lowerText);

    return hasLabelKeywords || hasIngredientPattern || hasPercentages;
  }

  String get ocrIngredientExtractionPrompt => '''
You are an expert food product analyzer specializing in extracting ingredients from OCR text of Filipino and international food product labels.

FILIPINO FOOD FOCUS: Your primary expertise is Filipino cuisine and Filipino food products. However, you can also identify international products commonly found in the Philippines.

PRODUCT IDENTIFICATION STRATEGY:
1. PRIORITIZE FILIPINO BRANDS AND PRODUCTS first
2. Look for BRAND NAMES and PRODUCT NAMES in the OCR text
3. Use your knowledge of popular Filipino food brands and products
4. Cross-reference with known product lines from major manufacturers
5. Consider product categories (snacks, instant noodles, canned goods, etc.)
6. If international product, note it but still analyze thoroughly

COMMON FILIPINO FOOD BRANDS TO RECOGNIZE:
- Lucky Me! (instant noodles)
- Nissin (Cup Noodles, instant noodles)
- Payless (crackers, biscuits)
- Ricoa (chocolates, candies)
- Argentina (corned beef, canned meat)
- CDO (processed meats, canned goods)
- Spam (canned meat)
- Monde Nissin (SkyFlakes, Fita, biscuits)
- Universal Robina Corporation products (Jack 'n Jill, etc.)
- San Miguel (various food products)
- Del Monte (canned fruits, sauces)
- Hunt's (tomato sauce, pasta sauce)
- Maggi (seasonings, instant noodles)
- Knorr (seasonings, soup mixes)
- Nestlé products (popular in Philippines)
- Unilever products

INGREDIENT EXTRACTION RULES:
1. Look for "INGREDIENTS:" or similar sections in the text
2. Parse comma-separated ingredient lists carefully
3. Handle ingredients with parenthetical information (e.g., "wheat flour (enriched)")
4. Recognize technical/scientific ingredient names
5. Account for percentage indicators (e.g., "sugar 15%")
6. Process multi-line ingredient lists
7. Handle both English and Filipino ingredient names

COMMON FILIPINO INGREDIENT TRANSLATIONS:
- Asukal = Sugar
- Asin = Salt  
- Mantika = Oil
- Gatas = Milk
- Itlog = Egg
- Bagoong = Fermented fish paste
- Toyo = Soy sauce
- Suka = Vinegar
- Paminta = Black pepper
- Bawang = Garlic
- Sibuyas = Onion
- Harina = Flour
- Niyog/Gata = Coconut
- Mani = Peanut

Return JSON with this exact structure (DO NOT include allergens):
{
  "dishName": "Specific product brand and name (e.g., 'Lucky Me! Pancit Canton Sweet Style')",
  "description": "Brief description including product category, key features, and brand information. Note if international product.",
  "ingredients": ["ingredient1", "ingredient2", "ingredient3"]
}

CRITICAL REQUIREMENTS:
1. Focus PRIMARILY on Filipino food products but analyze international ones too
2. Focus ONLY on product identification and ingredient extraction
3. Do NOT analyze allergens in this step
4. Provide accurate ingredient lists based on OCR text
5. Use product knowledge to identify brands and products correctly
''';

  String get imageIngredientExtractionPrompt => '''
You are an expert Filipino food identification system with PRIMARY FOCUS on Filipino cuisine. Your goal is ACCURATE DISH IDENTIFICATION and COMPLETE, DETAILED INGREDIENT LIST.

FILIPINO CUISINE PRIORITY: You are PRIMARILY specialized in Filipino dishes and cuisine. While you can identify international foods, your main expertise and focus should be on Filipino food.

CRITICAL IDENTIFICATION RULES:
1. PRIORITIZE Filipino dish identification - look for visual characteristics of traditional Filipino foods
2. Look carefully at the VISUAL CHARACTERISTICS of the dish
3. Identify based on what you SEE and what is known to be in the dish
4. Be SPECIFIC with Filipino dish names
5. If the food appears to be international (like chocolate cake, croissant, etc.), still analyze it but note that your primary expertise is Filipino cuisine
6. **CRITICAL ALLERGEN RULE: When identifying ingredients like sauces, pastes, or broths, you MUST break them down and list their primary allergenic base ingredient.**
   - For Kare-Kare sauce, you MUST list "peanut butter" or "peanuts"
   - For bagoong, you MUST specify "shrimp paste (bagoong)" or "fish paste (bagoong)"
   - For soy-based sauces, you MUST list "soy sauce"
   - For creamy soups, you MUST list "milk" or "cream"

FILIPINO DISHES - VISUAL IDENTIFICATION WITH ALLERGEN FOCUS (PRIMARY FOCUS):

KARE-KARE:
- Thick, orange/brown peanut-based sauce - **MUST include "peanut butter" in ingredients**
- Usually has oxtail, beef, or tripe
- Vegetables: bok choy, string beans, eggplant
- Served with bagoong on the side - **MUST specify "shrimp paste" or "fish paste"**

ADOBO:
- Dark, soy sauce-colored - **MUST list "soy sauce"**
- Glossy appearance from oil and soy sauce
- Chicken or pork pieces

SINIGANG:
- Clear, sour broth - may contain **fish sauce (patis)** - list if present
- Vegetables clearly visible in soup

GINILING (Ground Pork/Beef):
- Small, minced/ground meat pieces
- Usually contains soy sauce - **MUST list "soy sauce"**
- May have oyster sauce - **MUST list "oyster sauce" (contains shellfish)**

DINENGDENG:
- Clear broth with bagoong - **MUST specify "fish paste (bagoong)" or "shrimp paste (bagoong)"**
- Mixed vegetables clearly visible

PINAKBET:
- Mixed vegetables with bagoong - **MUST specify "shrimp paste" or "fish paste"**

BICOL EXPRESS:
- Creamy, spicy dish - **MUST list "coconut milk" and "chili peppers"**

LAING:
- Taro leaves in coconut milk - **MUST list "coconut milk" and "taro leaves"**

INTERNATIONAL FOODS (Secondary focus):
- If you identify chocolate cake, croissant, pasta, etc., still analyze thoroughly
- Note in description that this is outside primary Filipino cuisine expertise
- Still extract all ingredients accurately

INGREDIENT IDENTIFICATION RULES:
1. Base ingredient identification on VISIBLE ingredients and the KNOWN TRADITIONAL RECIPE of the identified dish
2. Include all common seasonings, sauces, and oils
3. **Your most important task is to ensure allergenic components are explicitly named.** Do not just say "sauce"; specify "peanut sauce" or "peanut butter"
4. For international dishes, research typical ingredients used

Return JSON with this exact structure (DO NOT include allergens):
{
  "dishName": "Exact dish name (prioritize Filipino dishes)",
  "description": "Brief description of the dish characteristics and preparation method, mentioning key flavors. Note if this is outside primary Filipino cuisine focus.",
  "ingredients": ["ingredient1", "ingredient2", "ingredient3", "etc"]
}

CRITICAL REQUIREMENTS:
1. PRIMARY FOCUS on Filipino cuisine identification
2. Focus ONLY on dish identification and ingredient extraction
3. Do NOT analyze allergens in this step
4. **Ensure base allergenic ingredients (peanuts, shrimp, fish, soy, milk, etc.) are explicitly listed in the ingredients array.** This is mandatory
5. If international dish, still analyze but note in description
''';

  String getAllergenAnalysisPrompt(List<String> userAllergens) {
    String userAllergensText =
        userAllergens.isNotEmpty ? userAllergens.join(', ') : '';
    return '''
You are an expert allergen detection specialist with advanced linguistic intelligence. Analyze the provided ingredients list to identify SPECIFIC allergens from BOTH the 9 FDA major allergens AND the user's custom allergens.

CRITICAL DETECTION RULES:
- Detect SPECIFIC allergens, NOT categories (e.g., "Shrimp" not "Shellfish", "Cashew" not "Tree Nuts")
- AVOID DUPLICATE ALLERGENS - Each unique allergen should only appear ONCE in the results
- If multiple specific allergens exist in the same FDA category, list them SEPARATELY (e.g., both "Shrimp" and "Crab" if both are present)

FDA MAJOR ALLERGENS - DETECT SPECIFICALLY:

1. MILK ALLERGEN:
   - Name as: "Milk"
   - Detect in: dairy, casein, whey, lactose, gatas, milk powder, cheese, butter, cream, yogurt, ghee, condensed milk, evaporated milk

2. EGGS ALLERGEN:
   - Name as: "Eggs"
   - Detect in: egg, albumin, lecithin (if egg-derived), ovalbumin, itlog, egg powder, egg whites, egg yolk, mayonnaise, meringue

3. FISH ALLERGENS (detect each fish type separately):
   - Name as specific fish: "Anchovies", "Tilapia", "Bangus", "Galunggong", "Tuna", "Salmon", "Sardines", "Mackerel", "Cod", "Haddock", "Pollock"
   - Also detect: dried fish, isda, fish sauce/patis, bagoong isda, fish paste (specify fish type if known)
   - If fish type unknown, use "Fish Sauce" or "Fish Paste" or "Fish"

4. CRUSTACEAN SHELLFISH (detect each type separately):
   - Name as: "Shrimp" (hipon, alamang, shrimp paste, bagoong alamang, dried shrimp)
   - Name as: "Crab" (alimango, crab paste, crab stick)
   - Name as: "Lobster" 
   - Name as: "Prawns"
   - Name as: "Crayfish"

5. MOLLUSK SHELLFISH (detect each type separately):
   - Name as: "Clams" (halaan)
   - Name as: "Mussels" (tahong)
   - Name as: "Scallops"
   - Name as: "Oysters" (talaba, oyster sauce)
   - Name as: "Squid" (pusit, calamari)
   - Name as: "Octopus"
   - Name as: "Snails"

6. TREE NUT ALLERGENS (detect each nut separately - NOT peanuts, NOT coconut):
   - Name as: "Cashew" (kasuy, cashew nuts)
   - Name as: "Almonds"
   - Name as: "Walnuts"
   - Name as: "Pecans"
   - Name as: "Hazelnuts"
   - Name as: "Pistachios"
   - Name as: "Macadamia"
   - Name as: "Pine Nuts"
   - Name as: "Brazil Nuts"
   - Name as: "Chestnuts"

7. PEANUTS ALLERGEN:
   - Name as: "Peanuts"
   - Detect in: mani, peanut oil, peanut butter, groundnuts, peanut sauce, peanut flour

8. WHEAT ALLERGEN:
   - Name as: "Wheat"
   - Detect in: gluten, flour, wheat flour, bread crumbs, harina, lumpia wrapper, spring roll wrapper, wheat noodles, pasta, bread, couscous, semolina, farro

9. SOY ALLERGEN:
   - Name as: "Soy"
   - Detect in: soybean, soy sauce, tofu, soybean oil, toyo, miso, tempeh, edamame, soy protein, soy lecithin

10. SESAME ALLERGEN:
   - Name as: "Sesame"
   - Detect in: sesame oil, tahini, linga, sesame seeds, benne, sesame paste

USER'S CUSTOM ALLERGENS (also check for these): ${userAllergensText.isNotEmpty ? userAllergensText : 'None specified'}

ENHANCED ALLERGEN DETECTION RULES WITH INTELLIGENT MATCHING:

1. **SPECIFIC ALLERGEN NAMING**: Always use the most specific allergen name:
   - If ingredient is "shrimp paste" → allergen name is "Shrimp" (NOT "Shellfish")
   - If ingredient is "oyster sauce" → allergen name is "Oysters" (NOT "Shellfish")
   - If ingredient is "cashew nuts" → allergen name is "Cashew" (NOT "Tree Nuts")
   - If ingredient is "tuna" → allergen name is "Tuna" (NOT "Fish")
   - If ingredient is "soy sauce" → allergen name is "Soy" (NOT just listing ingredient)
   - If ingredient is "bagoong alamang" → allergen name is "Shrimp" (NOT "Shellfish")

2. **MULTIPLE SPECIFIC ALLERGENS**: If dish contains multiple specific allergens from same FDA category, list each separately:
   - Example: If dish has both "shrimp paste" and "oyster sauce" → list TWO allergens: "Shrimp" and "Oysters"
   - Example: If dish has both "cashews" and "almonds" → list TWO allergens: "Cashew" and "Almonds"
   - Example: If dish has "tuna" and "anchovies" → list TWO allergens: "Tuna" and "Anchovies"

3. **SMART LINGUISTIC MATCHING**: Use AI intelligence to match allergens with variations:
   - SINGULAR/PLURAL: "egg" matches "eggs", "shrimp" matches "shrimps", "cashew" matches "cashews"
   - SYNONYM MATCHING: "soy" matches "soybean"/"soya", "milk" matches "dairy", "gatas" matches "milk"
   - DERIVATIVE MATCHING: "wheat" matches "flour"/"gluten", "soy" matches "tofu"/"soy sauce"
   - FILIPINO TERMS: 
     * "gatas" = "Milk"
     * "hipon" = "Shrimp"
     * "isda" = "Fish"
     * "mani" = "Peanuts"
     * "kasuy" = "Cashew"
     * "itlog" = "Eggs"
     * "toyo" = "Soy"
     * "patis" = "Fish Sauce"
     * "bagoong alamang" = "Shrimp"
     * "bagoong isda" = "Fish Paste"
     * "alimango" = "Crab"
     * "talaba" = "Oysters"
     * "tahong" = "Mussels"
     * "halaan" = "Clams"
     * "pusit" = "Squid"

4. **DEDUPLICATE ALLERGENS**: If same allergen found in multiple ingredients, list it ONCE with ALL sources:
   - Example: "soy sauce" and "tofu" both contain soy → ONE "Soy" allergen with sources: "soy sauce, tofu"
   - Example: "shrimp" and "shrimp paste" → ONE "Shrimp" allergen with sources: "shrimp, shrimp paste"
   - Example: "milk" and "cheese" → ONE "Milk" allergen with sources: "milk, cheese"

5. **CONTEXT-AWARE DETECTION**:
   - Fish sauce (patis) → detect as "Fish Sauce"
   - Bagoong isda → detect as "Fish Paste"  
   - Bagoong alamang → detect as "Shrimp"
   - Oyster sauce → detect as "Oysters"
   - Lumpia wrapper → detect as "Wheat"
   - Soy sauce (toyo) → detect as "Soy"
   - Shrimp paste (alamang) → detect as "Shrimp"

6. **USER ALLERGEN MATCHING**: For custom allergens, be MORE inclusive and specific:
   - Use linguistic intelligence to find related ingredients
   - Match root words and common variations
   - Consider both English and Filipino terms
   - **IMPORTANT**: If user allergen is "shellfish" → detect ALL specific shellfish separately (Shrimp, Crab, Oysters, Clams, etc.) and mark each as isUserAllergen: true
   - **IMPORTANT**: If user allergen is "nut" or "nuts" → detect ALL specific nuts separately (Cashew, Almonds, Walnuts, Peanuts, etc.) and mark each as isUserAllergen: true
   - **IMPORTANT**: If user allergen is "fish" → detect ALL specific fish separately (Tuna, Salmon, Bangus, etc.) and mark each as isUserAllergen: true
   - If user allergen is specific (e.g., "shrimp") → only detect that specific allergen

7. **WHOLE-WORD MATCHING**: Avoid false positives:
   - "Eggplant" does NOT contain eggs
   - "Butternut squash" does NOT contain butter/milk
   - "Coconut" is NOT a tree nut (it's a fruit)
   - Use context to avoid matching unrelated words

8. **RISK LEVEL ASSIGNMENT**:
   - severe: Life-threatening allergens, common severe reactions (peanuts, shellfish, tree nuts, fish)
   - moderate: Can cause significant reactions (milk, eggs, soy, wheat, sesame)
   - mild: Generally mild reactions
   - safe: No allergen detected or trace amounts

9. **SYMPTOMS ASSIGNMENT**: Provide specific, relevant symptoms for each allergen:
   - Severe allergens: anaphylaxis, difficulty breathing, swelling of throat, severe hives, drop in blood pressure
   - Moderate allergens: hives, itching, nausea, stomach cramps, diarrhea, vomiting
   - All: Always include relevant symptoms based on the specific allergen

Return JSON with this exact structure:
{
  "allergens": [
    {
      "name": "Specific allergen name (e.g., 'Shrimp', 'Cashew', 'Tuna', 'Milk', 'Eggs' - NOT 'Shellfish' or 'Tree Nuts')",
      "riskLevel": "severe|moderate|mild|safe",
      "symptoms": ["specific symptom1", "specific symptom2", "specific symptom3"],
      "sources": ["ingredient1", "ingredient2", "ingredient3"],
      "category": "FDA_MAJOR|USER_CUSTOM",
      "isUserAllergen": true/false,
      "matchingReason": "Brief explanation of detection"
    }
  ]
}

CRITICAL REQUIREMENTS:
1. Use SPECIFIC allergen names, NOT categories
2. Check for BOTH FDA major allergens AND user's custom allergens
3. ELIMINATE DUPLICATES - each unique specific allergen appears only once
4. COMBINE SOURCES - if same allergen in multiple ingredients, list all sources together
5. Provide appropriate risk levels and symptoms
''';
  }

  String get ingredientSimplificationPrompt => '''
You are an expert ingredient name standardizer. Your task is to convert complex ingredient names into simple, recognizable names while preserving allergen-relevant context.

SIMPLIFICATION RULES:
1. **PRESERVE FOOD CONTEXT**: Keep recognizable food names intact
   - CORRECT: "Lumpia wrapper" -> "lumpia wrapper"
   - CORRECT: "Soy sauce" -> "soy sauce"  
   - CORRECT: "Fish sauce" -> "fish sauce"
   - INCORRECT: "Lumpia wrapper" -> "wheat"
   - INCORRECT: "Soy sauce" -> "soy"

2. **SIMPLIFY TECHNICAL/MARKETING TERMS**: Remove unnecessary descriptors
   - "Enriched wheat flour" -> "wheat flour"
   - "Farm-fresh whole eggs" -> "eggs"
   - "Extra virgin olive oil" -> "olive oil"

3. **PRESERVE ALLERGEN CONTEXT**: Keep allergen-containing ingredients recognizable
   - "Creamy peanut butter" -> "peanut butter"
   - "Fermented shrimp paste" -> "shrimp paste"
   - "Whole milk powder" -> "milk powder"

4. **CONVERT TECHNICAL NAMES**: Simplify scientific/chemical names
   - "Monosodium glutamate" -> "MSG"
   - "Ascorbic acid" -> "Vitamin C"

Return JSON with this exact structure:
{
  "simplifiedIngredients": [
    {
      "original": "original ingredient name",
      "simplified": "simplified name that preserves food context and allergen information"
    }
  ]
}

CRITICAL REQUIREMENTS:
1. Keep common food names recognizable (lumpia wrapper, soy sauce, fish sauce)
2. Only simplify overly technical or marketing terms
3. Preserve allergen context within food names
''';

  String get multiOptionOCRPrompt => '''
You are an expert food product analyzer specializing in extracting ingredients from OCR text of Filipino and international food product labels.

FILIPINO FOOD FOCUS: Your primary expertise is Filipino cuisine and Filipino food products. However, you can also identify international products commonly found in the Philippines.

CRITICAL: Generate 3-4 DIFFERENT possible product interpretations with confidence scores. Consider:
1. Most likely product based on brand recognition
2. Alternative products with similar ingredients
3. Generic product category if brand unclear
4. Different product variants (e.g., flavor variations)

PRODUCT IDENTIFICATION STRATEGY:
1. PRIORITIZE FILIPINO BRANDS AND PRODUCTS first
2. Look for BRAND NAMES and PRODUCT NAMES in the OCR text
3. Use your knowledge of popular Filipino food brands and products
4. Cross-reference with known product lines from major manufacturers
5. Consider product categories (snacks, instant noodles, canned goods, etc.)
6. If international product, note it but still analyze thoroughly

Return JSON with this exact structure (DO NOT include allergens):
{
  "options": [
    {
      "dishName": "Specific product brand and name",
      "description": "Brief description including product category",
      "ingredients": ["ingredient1", "ingredient2", "ingredient3"],
      "confidence": 0.95
    },
    {
      "dishName": "Alternative interpretation",
      "description": "Different possible product identification",
      "ingredients": ["ingredient1", "ingredient2", "ingredient3"],
      "confidence": 0.75
    }
  ]
}

CONFIDENCE SCORING RULES:
- 0.90-1.00: Strong brand/product name match, clear ingredient list
- 0.70-0.89: Good match but some ambiguity
- 0.50-0.69: Moderate match, missing some information

CRITICAL REQUIREMENTS:
1. Generate 3-4 distinct options ordered by confidence
2. Focus ONLY on product identification and ingredient extraction
3. Do NOT analyze allergens in this step
''';

  String get multiOptionImagePrompt => '''
You are an expert Filipino food identification system with PRIMARY FOCUS on Filipino cuisine.

CRITICAL: Generate 3-4 DIFFERENT possible dish interpretations with confidence scores. Consider:
1. Most likely Filipino dish based on visual characteristics
2. Similar-looking Filipino dishes
3. Regional variations of the same dish
4. Alternative interpretations if visual characteristics are ambiguous

Return JSON with this exact structure (DO NOT include allergens):
{
  "options": [
    {
      "dishName": "Most likely Filipino dish name",
      "description": "Brief description of visual characteristics",
      "ingredients": ["ingredient1", "ingredient2", "ingredient3"],
      "confidence": 0.90
    },
    {
      "dishName": "Alternative Filipino dish interpretation",
      "description": "Different possible dish identification",
      "ingredients": ["ingredient1", "ingredient2", "ingredient3"],
      "confidence": 0.75
    }
  ]
}

CONFIDENCE SCORING RULES:
- 0.90-1.00: Very clear visual match
- 0.70-0.89: Good match but could be similar dish variant
- 0.50-0.69: Moderate match, some ambiguity

CRITICAL REQUIREMENTS:
1. Generate 3-4 distinct options ordered by confidence
2. PRIMARY FOCUS on Filipino cuisine identification
3. Focus ONLY on dish identification and ingredient extraction
4. Do NOT analyze allergens in this step
''';

  Future<void> analyzeOCRText(String ocrText, File imageFile) async {
    if (apiKey == 'YOUR_API_KEY_HERE') {
      setState(() => loading = false);
      return;
    }

    try {
      setState(() {
        isOCRAnalysis = true;
        analysisStatus = 'Generating dish options...';
      });

      final model = GenerativeModel(model: 'gemini-2.5-pro', apiKey: apiKey);
      final ingredientPrompt = '''$multiOptionOCRPrompt

EXTRACTED TEXT FROM FOOD LABEL:
"$ocrText"

Generate 3-4 possible product interpretations with confidence scores.
''';

      final ingredientResponse = await model.generateContent([
        Content.text(ingredientPrompt),
      ]);

      final dishOptions = await parseMultiOptionResponse(
        ingredientResponse.text ?? '',
      );

      setState(() {
        loading = false;
        analysisStatus = '';
      });

      await showDishSelectionScreen(dishOptions, imageFile);
    } catch (e) {
      setState(() {
        loading = false;
        analysisStatus = '';
      });
      showSnackBar('Error analyzing product label: $e', Colors.red);
    }
  }

  Future<void> analyzeWithImage(File imageFile) async {
    if (apiKey == 'YOUR_API_KEY_HERE') {
      setState(() => loading = false);
      return;
    }

    try {
      setState(() {
        isOCRAnalysis = false;
        analysisStatus = 'Generating dish options...';
      });

      final model = GenerativeModel(model: 'gemini-2.5-pro', apiKey: apiKey);
      final imageBytes = await imageFile.readAsBytes();

      final ingredientPrompt = '''$multiOptionImagePrompt

VISUAL ANALYSIS INSTRUCTIONS:
Carefully examine this food image. PRIMARY FOCUS should be on Filipino dishes and cuisine.
Generate 3-4 possible dish interpretations with confidence scores.
''';

      final ingredientResponse = await model.generateContent([
        Content.multi([
          TextPart(ingredientPrompt),
          DataPart('image/jpeg', imageBytes),
        ]),
      ]);

      final dishOptions = await parseMultiOptionResponse(
        ingredientResponse.text ?? '',
      );

      setState(() {
        loading = false;
        analysisStatus = '';
      });

      await showDishSelectionScreen(dishOptions, imageFile);
    } catch (e) {
      setState(() {
        loading = false;
        analysisStatus = '';
      });
      showSnackBar('Error analyzing image: $e', Colors.red);
    }
  }

  Future<void> showDishSelectionScreen(
    List<DishOption> options,
    File imageFile,
  ) async {
    final selectedOption = await Navigator.push<DishOption>(
      context,
      MaterialPageRoute(
        builder:
            (context) => DishSelectionScreen(
              options: options,
              onOptionSelected: (option) {
                Navigator.pop(context, option);
              },
              onManualEntry: () {
                Navigator.pop(context, null);
                toggleManualInput();
              },
            ),
      ),
    );

    if (selectedOption != null) {
      await processDishOption(selectedOption, imageFile);
    } else {
      setState(() {
        image = null;
        loading = false;
      });
    }
  }

  Future<void> processDishOption(
    DishOption selectedOption,
    File imageFile,
  ) async {
    setState(() {
      loading = true;
      dishName = selectedOption.dishName;
      description = selectedOption.description;
      analysisStatus = 'Simplifying ingredients...';
    });

    try {
      final model = GenerativeModel(model: 'gemini-2.5-pro', apiKey: apiKey);

      List<String> simplifiedIngredients = await simplifyIngredientNames(
        selectedOption.ingredients,
        model,
      );

      setState(() {
        ingredients = simplifiedIngredients;
        analysisStatus = 'Determining allergens...';
      });

      await analyzeAllergensFromIngredients(simplifiedIngredients);

      setState(() {
        loading = false;
        analysisStatus = '';
      });

      navigateToResults();

      saveToFirebase(imageFile).catchError((e) {
        print('Background save error: $e');
      });
    } catch (e) {
      setState(() {
        loading = false;
        analysisStatus = '';
      });
      showSnackBar('Error processing dish: $e', Colors.red);
    }
  }

  Widget buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScannerOverlay(animation: animation, status: analysisStatus),

            const SizedBox(height: 40),
            AnalysisTrivia(
              analysisType: isSkinAnalysis ? 'skin' : 'food',
              onTriviaLoaded: () {
                print('Trivia loaded successfully');
              },
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<List<String>> simplifyIngredientNames(
    List<String> originalIngredients,
    GenerativeModel model,
  ) async {
    try {
      final simplificationPrompt = '''$ingredientSimplificationPrompt

INGREDIENTS TO SIMPLIFY:
${originalIngredients.join(', ')}
''';

      final simplificationResponse = await model.generateContent([
        Content.text(simplificationPrompt),
      ]);

      final simplificationData = await parseSimplificationResponse(
        simplificationResponse.text ?? '',
      );

      List<String> simplifiedIngredients = [];
      List<dynamic> simplifications =
          simplificationData['simplifiedIngredients'] ?? [];

      for (var item in simplifications) {
        if (item is Map<String, dynamic> && item['simplified'] != null) {
          simplifiedIngredients.add(item['simplified'].toString().trim());
        }
      }

      if (simplifiedIngredients.isEmpty) {
        return originalIngredients;
      }

      return simplifiedIngredients;
    } catch (e) {
      print('Error simplifying ingredient names: $e');
      return originalIngredients;
    }
  }

  Future<List<DishOption>> parseMultiOptionResponse(String response) async {
    try {
      String cleanResponse = response;
      if (response.contains('```json')) {
        cleanResponse = response.split('```json')[1].split('```')[0];
      } else if (response.contains('```')) {
        cleanResponse = response.split('```')[1];
      }

      final jsonData = json.decode(cleanResponse.trim());
      final List<dynamic> optionsJson = jsonData['options'] ?? [];

      return optionsJson
          .map((optionJson) => DishOption.fromJson(optionJson))
          .toList();
    } catch (e) {
      print('Error parsing multi-option response: $e');
      return [
        DishOption(
          dishName: 'Analysis Complete',
          description: 'Unable to parse multiple options',
          ingredients: ['Unable to parse ingredients'],
          confidence: 0.5,
        ),
      ];
    }
  }

  Future<Map<String, dynamic>> parseSimplificationResponse(
    String response,
  ) async {
    try {
      String cleanResponse = response;
      if (response.contains('```json')) {
        cleanResponse = response.split('```json')[1].split('```')[0];
      } else if (response.contains('```')) {
        cleanResponse = response.split('```')[1];
      }

      return json.decode(cleanResponse.trim());
    } catch (e) {
      print('Error parsing simplification response: $e');
      return {'simplifiedIngredients': []};
    }
  }

  Future<Map<String, dynamic>> parseIngredientResponse(String response) async {
    try {
      String cleanResponse = response;
      if (response.contains('```json')) {
        cleanResponse = response.split('```json')[1].split('```')[0];
      } else if (response.contains('```')) {
        cleanResponse = response.split('```')[1];
      }
      return json.decode(cleanResponse.trim());
    } catch (e) {
      print('Error parsing ingredient response: $e');
      return {
        'dishName': 'Analysis Complete',
        'description': response,
        'ingredients': ['Unable to parse ingredients'],
      };
    }
  }

  Future<void> analyzeAllergensFromIngredients(
    List<String> ingredientList,
  ) async {
    try {
      final allergenData = await allergenAnalysis.getUserAllergenData();
      List<String> userAllergens = List<String>.from(allergenData['names']);

      final model = GenerativeModel(model: 'gemini-2.5-pro', apiKey: apiKey);

      final allergenPrompt = '''${getAllergenAnalysisPrompt(userAllergens)}

INGREDIENTS TO ANALYZE:
${ingredientList.join(', ')}

Analyze each ingredient carefully and identify allergens.
''';

      final allergenResponse = await model.generateContent([
        Content.text(allergenPrompt),
      ]);

      final parsedAllergenData = await allergenAnalysis.parseAllergenResponse(
        allergenResponse.text ?? '',
      );

      List<AllergenInfo> detectedAllergens =
          (parsedAllergenData['allergens'] as List? ?? [])
              .map((a) => AllergenInfo.fromJson(a))
              .toList();

      List<IngredientColorInfo> ingredientColors = await allergenAnalysis
          .computeIngredientColors(ingredientList, detectedAllergens);

      for (AllergenInfo allergen in detectedAllergens) {
        allergen.ingredientColors.clear();
        allergen.ingredientColors.addAll(ingredientColors);
      }

      setState(() {
        allergens = detectedAllergens;
      });
    } catch (e) {
      print('Error analyzing allergens: $e');
      setState(() {
        allergens = [];
      });
    }
  }

  void navigateToResults() async {
    List<IngredientColorInfo> computedIngredientColors = await allergenAnalysis
        .computeIngredientColors(ingredients, allergens);

    bool shouldReset = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ResultScreen(
              ingredientColors: computedIngredientColors,
              image: image,
              dishName: dishName,
              description: description,
              ingredients: ingredients,
              allergens: allergens,
              onIngredientsChanged: updateAllergens,
              isOCRAnalysis: isOCRAnalysis,
              isFromHistory: false,
            ),
      ),
    );

    if (shouldReset == true) {
      resetCameraState();
    }
  }

  void resetCameraState() {
    setState(() {
      image = null;
      dishName = '';
      description = '';
      ingredients = [];
      allergens = [];
      isOCRAnalysis = false;
      isSkinAnalysis = false;
    });
    if (cameraController != null && !cameraController!.value.isInitialized) {
      initializeCamera();
    }
  }

  Future<String> generateDescription(
    String dishName,
    List<String> ingredients,
  ) async {
    if (apiKey == 'YOUR_API_KEY_HERE') return "Description not available";

    try {
      final model = GenerativeModel(model: 'gemini-2.5-pro', apiKey: apiKey);

      final prompt = '''
Generate a detailed description focusing on Filipino cuisine.

The dish "$dishName" contains these ingredients: ${ingredients.join(', ')}.

Make the description:
1. Culturally accurate (prioritize Filipino cuisine knowledge)
2. 2-3 sentences long
3. Enticing and informative
''';

      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? 'No description available';
    } catch (e) {
      print('Error generating description: $e');
      return 'Description not available due to error';
    }
  }

  void submitManualIngredients() async {
    final dishNameText = dishNameController.text.trim();
    final ingredientText = ingredientController.text.trim();

    if (dishNameText.isEmpty || ingredientText.isEmpty) {
      showSnackBar('Please enter both dish name and ingredients', Colors.red);
      return;
    }

    final enteredIngredients =
        ingredientText
            .split(',')
            .map((ingredient) => ingredient.trim())
            .where((ingredient) => ingredient.isNotEmpty)
            .toList();

    setState(() {
      loading = true;
      dishName = dishNameText;
      isOCRAnalysis = false;
      showManualInput = false;
      analysisStatus = 'Simplifying ingredients...';
    });

    try {
      final model = GenerativeModel(model: 'gemini-2.5-pro', apiKey: apiKey);

      List<String> simplifiedIngredients = await simplifyIngredientNames(
        enteredIngredients,
        model,
      );

      setState(() {
        ingredients = simplifiedIngredients;
        image = null;
        analysisStatus = 'Generating description...';
      });

      final generatedDescription = await generateDescription(
        dishNameText,
        simplifiedIngredients,
      );

      setState(() {
        description = generatedDescription;
        analysisStatus = 'Determining allergens...';
      });

      await analyzeAllergensFromIngredients(simplifiedIngredients);
      setState(() {
        loading = false;
        analysisStatus = '';
      });
      navigateToResults();

      saveToFirebase(null).catchError((e) {
        print('Background save error: $e');
      });
    } catch (e) {
      showSnackBar('Error analyzing ingredients: $e', Colors.red);
      setState(() {
        loading = false;
        analysisStatus = '';
      });
    } finally {
      setState(() => loading = false);
    }

    dishNameController.clear();
    ingredientController.clear();
  }

  Future<void> saveToFirebase(File? imageFile) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        showSnackBar('Please log in to save your scan results', Colors.red);
        return;
      }

      final allergenData = await allergenAnalysis.getUserAllergenData();
      List<String> userAllergenNames = List<String>.from(allergenData['names']);

      List<Map<String, dynamic>> userAllergensWithSeverity = [];

      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        QuerySnapshot profile =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .collection('profile')
                .where('type', isEqualTo: 'allergen')
                .get();

        for (QueryDocumentSnapshot doc in profile.docs) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          userAllergensWithSeverity.add({
            'name': data['name']?.toString() ?? '',
            'severity': (data['severity'] ?? 0.5).toDouble(),
          });
        }
      }

      String? imageUrl;
      String? fileName;

      if (imageFile != null && await imageFile.exists()) {
        fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('food_images')
            .child(user.uid)
            .child(fileName!);

        final uploadTask = storageRef.putFile(imageFile);
        final uploadResult = await uploadTask;
        imageUrl = await uploadResult.ref.getDownloadURL();
      }

      List<IngredientColorInfo> ingredientColors = [];
      if (allergens.isNotEmpty && allergens.first.ingredientColors.isNotEmpty) {
        ingredientColors = allergens.first.ingredientColors;
      } else {
        ingredientColors = await allergenAnalysis.computeIngredientColors(
          ingredients,
          allergens,
        );
      }

      final scanData = {
        'dishName': dishName.isNotEmpty ? dishName : 'Unknown Product',
        'description':
            description.isNotEmpty ? description : 'User-entered dish',
        'ingredients': ingredients.isNotEmpty ? ingredients : [],
        'allergens':
            allergens
                .map(
                  (a) => {
                    'name': a.name,
                    'riskLevel': a.riskLevel,
                    'symptoms': a.symptoms,
                    'sources': a.sources,
                    'category': a.category,
                    'isUserAllergen': a.isUserAllergen,
                  },
                )
                .toList(),
        'ingredientColors': ingredientColors.map((ic) => ic.toJson()).toList(),
        'imageUrl': imageUrl ?? '',
        'fileName': fileName ?? '',
        'isOCRAnalysis': isOCRAnalysis,
        'timestamp': FieldValue.serverTimestamp(),
        'scanDate': DateTime.now().toIso8601String(),
        'userId': user.uid,
        'userAllergensAtScanTime':
            userAllergensWithSeverity,
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('history')
          .add(scanData);
    } catch (e) {
      showSnackBar('Failed to save scan results: ${e.toString()}', Colors.red);
    }
  }


  Map<String, double> extractHistoricalSeverityData(
    Map<String, dynamic> scanData,
  ) {
    Map<String, double> severityMap = {};

    List<dynamic> userAllergensAtScanTime =
        scanData['userAllergensAtScanTime'] ?? [];

    if (userAllergensAtScanTime.isNotEmpty) {
      for (var allergenData in userAllergensAtScanTime) {
        if (allergenData is Map<String, dynamic>) {
          String name =
              allergenData['name']?.toString().toLowerCase().trim() ?? '';
          double severity = (allergenData['severity'] ?? 0.5).toDouble();
          if (name.isNotEmpty) {
            severityMap[name] = severity;
          }
        } else if (allergenData is String) {
          String allergenName = allergenData.toLowerCase().trim();

          List<dynamic> allergens = scanData['allergens'] ?? [];
          for (var allergen in allergens) {
            if (allergen is Map<String, dynamic>) {
              String name =
                  allergen['name']?.toString().toLowerCase().trim() ?? '';
              if (name == allergenName && allergen['isUserAllergen'] == true) {
                String riskLevel =
                    allergen['riskLevel']?.toString().toLowerCase() ??
                    'moderate';
                double severity;
                switch (riskLevel) {
                  case 'severe':
                    severity = 0.8;
                    break;
                  case 'moderate':
                    severity = 0.5;
                    break;
                  case 'mild':
                    severity = 0.2;
                    break;
                  default:
                    severity = 0.5;
                }
                severityMap[allergenName] = severity;
              }
            }
          }
        }
      }
    } else {
      List<dynamic> allergens = scanData['allergens'] ?? [];
      for (var allergen in allergens) {
        if (allergen is Map<String, dynamic> &&
            allergen['isUserAllergen'] == true) {
          String allergenName =
              allergen['name']?.toString().toLowerCase().trim() ?? '';
          String riskLevel =
              allergen['riskLevel']?.toString().toLowerCase() ?? 'moderate';

          double severity;
          switch (riskLevel) {
            case 'severe':
              severity = 0.8;
              break;
            case 'moderate':
              severity = 0.5;
              break;
            case 'mild':
              severity = 0.2;
              break;
            default:
              severity = 0.5;
          }

          if (allergenName.isNotEmpty) {
            severityMap[allergenName] = severity;
          }
        }
      }
    }

    print('Extracted historical severity data: $severityMap');
    return severityMap;
  }

  void navigateToHistoryDetails(Map<String, dynamic> scanData) {
    Map<String, double> historicalSeverity = extractHistoricalSeverityData(
      scanData,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ResultScreen(
              image:
                  scanData['imageUrl'] != null &&
                          scanData['imageUrl'].isNotEmpty
                      ? File(scanData['imageUrl'])
                      : null,
              dishName: scanData['dishName'] ?? 'Unknown Dish',
              description: scanData['description'] ?? '',
              ingredients: List<String>.from(scanData['ingredients'] ?? []),
              allergens:
                  (scanData['allergens'] as List? ?? [])
                      .map((a) => AllergenInfo.fromJson(a))
                      .toList(),
              onIngredientsChanged: (_) async {},
              isOCRAnalysis: scanData['isOCRAnalysis'] ?? false,
              ingredientColors:
                  (scanData['ingredientColors'] as List? ?? [])
                      .map((ic) => IngredientColorInfo.fromJson(ic))
                      .toList(),
              isFromHistory: true,
              historicalSeverityData: historicalSeverity,
            ),
      ),
    );
  }

  Future<void> updateAllergens(List<String> newIngredients) async {
    setState(() {
      loading = true;
    });

    try {
      await analyzeAllergensFromIngredients(newIngredients);
      setState(() {
        ingredients = newIngredients;
      });
    } catch (e) {
      print('Error updating allergens: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  void showHelpDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.help_outline, color: Colors.blue.shade600, size: 24),
                const SizedBox(width: 12),
                const Text(
                  'How to Use',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildSimpleStep(
                  Icons.restaurant,
                  'Scan food or skin allergic reactions',
                ),
                const SizedBox(height: 12),
                buildSimpleStep(
                  Icons.camera_alt,
                  'AI automatically detects type',
                ),
                const SizedBox(height: 12),
                buildSimpleStep(
                  Icons.smart_toy,
                  'Identifies allergens & triggers',
                ),
                const SizedBox(height: 12),
                buildSimpleStep(Icons.shield, 'Get safety recommendations'),
                const SizedBox(height: 16),
                Text(
                  'Tip: You can also enter ingredients manually',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Got it'),
              ),
            ],
          ),
    );
  }

  Widget buildSimpleStep(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.blue.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 15, height: 1.3)),
        ),
      ],
    );
  }

  IconData getFlashIcon() {
    switch (flashMode) {
      case FlashMode.auto:
        return Icons.flash_auto;
      case FlashMode.always:
        return Icons.flash_on;
      case FlashMode.off:
        return Icons.flash_off;
      case FlashMode.torch:
        return Icons.highlight;
      default:
        return Icons.flash_auto;
    }
  }

  Widget buildCameraControls() {
    return Positioned(
      bottom: 120,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          buildControlButton(
            Icons.photo_library,
            () => pickImage(ImageSource.gallery),
          ),
          buildControlButton(getFlashIcon(), toggleFlash),
          if (cameras != null && cameras!.length > 1)
            buildControlButton(Icons.flip_camera_ios, switchCamera),
        ],
      ),
    );
  }

  Widget buildControlButton(IconData icon, VoidCallback onPressed) {
    return IconButton(
      onPressed: onPressed,
      icon: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }

  Widget buildBottomNavigation() {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 2,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                buildNavButton(
                  'assets/navigation/menu_inactive.png',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => Homescreen()),
                  ),
                ),
                const SizedBox(width: 70),
                buildNavButton(
                  'assets/navigation/Profile_inactive.png',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) =>
                              UserProfile(emergencyService: EmergencyService()),
                    ),
                  ),
                ),
              ],
            ),
          ),
          buildCenterCaptureButton(),
        ],
      ),
    );
  }

  Widget buildNavButton(String assetPath, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Image.asset(assetPath, width: 24, height: 24),
    );
  }

  Widget buildCenterCaptureButton() {
    return Positioned(
      top: -20,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFF00BCD4),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00BCD4).withOpacity(0.3),
                blurRadius: 15,
                spreadRadius: 3,
              ),
            ],
          ),
          child: GestureDetector(
            onTap: loading ? null : captureImage,
            child:
                loading
                    ? const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    )
                    : Image.asset(
                      'assets/navigation/scan_active.png',
                      width: 24,
                      height: 24,
                    ),
          ),
        ),
      ),
    );
  }

  void toggleManualInput() {
    setState(() {
      showManualInput = !showManualInput;
      if (showManualInput) {
        dishNameController.clear();
        ingredientController.clear();
      }
    });
  }

  Widget buildManualInputForm() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      bottom: showManualInput ? 0 : -600,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.grey[50]!],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 24,
              spreadRadius: 0,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.restaurant_menu_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Enter Dish Details',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.label_outline_rounded,
                      size: 18,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Dish Name',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: dishNameController,
                  decoration: InputDecoration(
                    hintText: 'What\'s the name of your dish?',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 16, right: 12),
                      child: Icon(
                        Icons.restaurant_rounded,
                        color: Colors.grey[500],
                        size: 20,
                      ),
                    ),
                  ),
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.list_alt_rounded,
                      size: 18,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Ingredients',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[100]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: Colors.blue[600],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'AI will analyze ingredients for potential allergens',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ingredientController,
                  focusNode: ingredientFocusNode,
                  maxLines: 5,
                  minLines: 4,
                  decoration: InputDecoration(
                    hintText:
                        'e.g., chicken breast, soy sauce, garlic, onions...',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.all(20),
                  ),
                  style: const TextStyle(fontSize: 15, height: 1.4),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => submitManualIngredients(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: OutlinedButton(
                    onPressed: toggleManualInput,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey[400]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      backgroundColor: Colors.transparent,
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.primary.withOpacity(0.8),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: submitManualIngredients,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                      ),
                      child: const Text(
                        'Analyze Dish',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child:
                image != null
                    ? Image.file(image!, fit: BoxFit.contain)
                    : isCameraInitialized
                    ? CameraPreview(cameraController!)
                    : Container(
                      color: Colors.black,
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF00BCD4),
                        ),
                      ),
                    ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: Colors.transparent,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white38,
                      child: IconButton(
                        icon: const Icon(
                          Icons.help_outline,
                          color: Colors.white,
                        ),
                        onPressed: showHelpDialog,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: CircleAvatar(
                        backgroundColor: Colors.white38,
                        child: IconButton(
                          icon: const Icon(
                            Icons.edit_note,
                            color: Colors.white,
                          ),
                          onPressed: toggleManualInput,
                          tooltip: 'Enter ingredients manually',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (image == null && isCameraInitialized && !showManualInput)
            Center(child: ScannerOverlay(animation: animation)),
          if (loading) buildLoadingOverlay(),
          if (!showManualInput) buildCameraControls(),
          if (!showManualInput) buildBottomNavigation(),
          buildManualInputForm(),
        ],
      ),
    );
  }
}

class ScannerOverlay extends StatelessWidget {
  final Animation<double> animation;
  final String? status;

  const ScannerOverlay({Key? key, required this.animation, this.status})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 250,
              height: 250,
              child: Stack(
                children: [
                  ...List.generate(4, (index) => buildCornerBracket(index)),
                  Positioned(
                    top: animation.value * 220,
                    left: 15,
                    right: 15,
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00BCD4),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00BCD4).withOpacity(0.6),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (status != null)
              Positioned(
                top: 120,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      status!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

            Positioned(
              bottom: -80,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Specializing in Filipino cuisine - analyzing ingredients for allergens',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget buildCornerBracket(int index) {
    final positions = [
      {
        'top': 0.0,
        'left': 0.0,
        'borders': ['top', 'left'],
      },
      {
        'top': 0.0,
        'right': 0.0,
        'borders': ['top', 'right'],
      },
      {
        'bottom': 0.0,
        'left': 0.0,
        'borders': ['bottom', 'left'],
      },
      {
        'bottom': 0.0,
        'right': 0.0,
        'borders': ['bottom', 'right'],
      },
    ];

    final pos = positions[index];
    return Positioned(
      top: pos['top'] as double?,
      left: pos['left'] as double?,
      right: pos['right'] as double?,
      bottom: pos['bottom'] as double?,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          border: Border(
            top:
                (pos['borders'] as List).contains('top')
                    ? const BorderSide(color: Colors.white, width: 3)
                    : BorderSide.none,
            left:
                (pos['borders'] as List).contains('left')
                    ? const BorderSide(color: Colors.white, width: 3)
                    : BorderSide.none,
            right:
                (pos['borders'] as List).contains('right')
                    ? const BorderSide(color: Colors.white, width: 3)
                    : BorderSide.none,
            bottom:
                (pos['borders'] as List).contains('bottom')
                    ? const BorderSide(color: Colors.white, width: 3)
                    : BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class IngredientColorInfo {
  final String ingredient;
  final Color color;
  final double severity;
  final List<String> matchedAllergens;

  IngredientColorInfo({
    required this.ingredient,
    required this.color,
    required this.severity,
    required this.matchedAllergens,
  });

  factory IngredientColorInfo.fromJson(Map<String, dynamic> json) {
    return IngredientColorInfo(
      ingredient: json['ingredient'] ?? '',
      color: Color(json['colorValue'] ?? 0xFF9E9E9E),
      severity: (json['severity'] ?? 0.0).toDouble(),
      matchedAllergens: List<String>.from(json['matchedAllergens'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ingredient': ingredient,
      'colorValue': color.value,
      'severity': severity,
      'matchedAllergens': matchedAllergens,
    };
  }
}

class AllergenInfo {
  final String name;
  final String riskLevel;
  final List<String> symptoms;
  final List<String> sources;
  final String category;
  final bool isUserAllergen;
  List<IngredientColorInfo> ingredientColors;

  AllergenInfo({
    required this.name,
    required this.riskLevel,
    required this.symptoms,
    required this.sources,
    this.category = 'FDA_MAJOR',
    this.isUserAllergen = false,
    List<IngredientColorInfo>? ingredientColors,
  }) : ingredientColors = ingredientColors ?? [];

  factory AllergenInfo.fromJson(Map<String, dynamic> json) {
    return AllergenInfo(
      name: json['name'] ?? '',
      riskLevel: json['riskLevel'] ?? 'safe',
      symptoms: List<String>.from(json['symptoms'] ?? []),
      sources:
          json['sources'] != null
              ? List<String>.from(json['sources'])
              : (json['source'] != null ? [json['source'].toString()] : []),
      category: json['category'] ?? 'FDA_MAJOR',
      isUserAllergen: json['isUserAllergen'] ?? false,
      ingredientColors:
          json['ingredientColors'] != null
              ? (json['ingredientColors'] as List)
                  .map((e) => IngredientColorInfo.fromJson(e))
                  .toList()
              : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'riskLevel': riskLevel,
      'symptoms': symptoms,
      'sources': sources,
      'category': category,
      'isUserAllergen': isUserAllergen,
      'ingredientColors': ingredientColors.map((e) => e.toJson()).toList(),
    };
  }

  String get iconPath {
    final firstLetter = name[0].toUpperCase();
    final rest = name.substring(1).toLowerCase();
    return 'assets/allergens/$firstLetter$rest.png';
  }

  String get formattedSources => "Sources: ${sources.join(', ')}";

  IconData get iconData {
    final String name = this.name.toLowerCase().trim();
    switch (name) {
      case 'milk':
      case 'dairy':
        return FontAwesomeIcons.glassWater;
      case 'cashew':
      case 'nuts':
      case 'nut':
      case 'tree nuts':
        return FontAwesomeIcons.seedling;
      case 'egg':
      case 'eggs':
        return FontAwesomeIcons.egg;
      case 'fish':
        return FontAwesomeIcons.fish;
      case 'wheat':
      case 'gluten':
        return FontAwesomeIcons.wheatAwn;
      case 'soy':
      case 'soybean':
      case 'soya':
        return FontAwesomeIcons.leaf;
      case 'shellfish':
      case 'seafood':
      case 'crustacean':
        return FontAwesomeIcons.shrimp;
      case 'peanut':
      case 'peanuts':
        return FontAwesomeIcons.circleNodes;
      case 'sesame':
        return FontAwesomeIcons.pepperHot;
      case 'lupin':
        return FontAwesomeIcons.spa;
      default:
        return FontAwesomeIcons.triangleExclamation;
    }
  }
}
