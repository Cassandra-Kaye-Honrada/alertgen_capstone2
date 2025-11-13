import 'dart:convert';
import 'dart:io';
import 'package:allergen/screens/feature/allergen_analysis.dart';
import 'package:allergen/screens/feature/dish_confimation_screen.dart';
import 'package:allergen/screens/feature/educational/Informational_Screen.dart';
import 'package:allergen/screens/feature/skin_allergy/skin_allergy.dart';
import 'package:allergen/screens/feature/skin_allergy/skin_cache.dart';
import 'package:allergen/screens/feature/skin_allergy/skin_result_option.dart';
import 'package:allergen/screens/feature/trivia/trivia.dart';
import 'package:allergen/screens/health_environment_analytics/AirQualityDetailScreen.dart';
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
  IngredientBenefitsMap ingredientBenefitsMap = IngredientBenefitsMap();
  final SkinAnalysisCache skinCache = SkinAnalysisCache();

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
        imageQuality: 90,
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
        analysisStatus = "Determining Image Type";
      });

      final imageType = await determineImageType(imageFile);

      if (imageType == 'other') {
        return;
      }

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
      setState(() {
        loading = false;
        image = null;
      });
      showSnackBar('API key not configured', Colors.red);
      return 'other';
    }

    try {
      final model = GenerativeModel(model: 'gemini-2.5-pro', apiKey: apiKey);
      final imageBytes = await imageFile.readAsBytes();

      final prompt = '''
You are an EXPERT image classifier. Analyze this image with STRICT rules:

**FOOD/PRODUCT** - MUST show one of these:
1. Actual food: dishes, meals, cooked food, fruits, vegetables, beverages
2. Food product labels: packaged foods with visible ingredient lists or nutrition facts
3. Food packaging: boxes, cans, bottles with clear food branding

**SKIN** - MUST show:
1. Human skin with visible allergic reactions (hives, rashes, eczema, dermatitis)
2. Skin conditions clearly related to food allergies

**OTHER** - Everything else including:
- Computer screens/monitors showing text
- Screenshots of documents or websites
- Random objects, scenery, animals, people
- Text documents, papers, books (NOT food labels)
- Any non-food related content

CRITICAL RULES:
- Text on a computer screen = OTHER (not food)
- Random text documents = OTHER (not food)
- Screenshots = OTHER (not food)
- Food product labels must have VISIBLE ingredients list or nutrition facts
- Confidence MUST be ≥ 0.70 for "food" or "skin", otherwise return "other"

Return JSON:
{
  "type": "food" or "skin" or "other",
  "confidence": 0.XX (minimum 0.70 for food/skin),
  "reason": "Short, direct description of what is seen in the image (no rule references)"
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
      final imageType = jsonData['type'] ?? 'other';
      final confidence = (jsonData['confidence'] ?? 0.0).toDouble();
      final reason = jsonData['reason'] ?? '';

      print('Image type detected: $imageType (confidence: $confidence)');
      print('Reason: $reason');

      if ((imageType == 'food' || imageType == 'skin') && confidence < 0.70) {
        print('Confidence too low, rejecting as OTHER');
        setState(() {
          loading = false;
          image = null;
          analysisStatus = '';
        });
        showNotFoodOrSkinDialog('Low confidence detection: $reason');
        return 'other';
      }

      setState(() {
        isSkinAnalysis = (imageType == 'skin');
      });

      if (imageType == 'other') {
        setState(() {
          loading = false;
          image = null;
          analysisStatus = '';
        });

        showNotFoodOrSkinDialog(reason);
        return 'other';
      }

      return imageType;
    } catch (e) {
      print('Error determining image type: $e');
      setState(() {
        loading = false;
        image = null;
        analysisStatus = '';
      });
      showSnackBar('Failed to analyze image type', Colors.red);
      return 'other';
    }
  }

  void showNotFoodOrSkinDialog(String reason) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 8,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Colors.grey[50]!],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.grey[300]!,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.info_outline_rounded,
                                color: Colors.grey[700],
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                reason.isNotEmpty
                                    ? reason
                                    : 'This image doesn\'t appear to contain food or a skin condition.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[800],
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 1,
                              color: Colors.grey[300],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'SUPPORTED SCANS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              height: 1,
                              color: Colors.grey[300],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      buildScanOption(
                        Icons.restaurant_menu_rounded,
                        'Food & Products',
                        'Dishes, meals, packaged foods(ingredients)',
                        const Color(0xFF4CAF50),
                      ),
                      const SizedBox(height: 12),
                      buildScanOption(
                        Icons.health_and_safety_rounded,
                        'Skin Conditions',
                        'Allergic reactions, rashes, hives, eczema',
                        const Color(0xFF2196F3),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00BCD4), Color(0xFF00838F)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00BCD4).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).pop();
                          resetCameraState();
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: const Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Scan Again',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildScanOption(
    IconData icon,
    String title,
    String description,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 24, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle, size: 20, color: color),
          ),
        ],
      ),
    );
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
        analysisStatus = 'Analyzing skin allergy...';
      });

      final imageHash = skinCache.generateImageHash(imageFile);
      final exactMatch = await skinCache.checkExactImageMatch(imageHash);

      if (exactMatch != null) {
        setState(() {
          loading = false;
          // analysisStatus = '';
        });

        navigateToSkinResults(exactMatch, imageFile, fromCache: true);
        return;
      }

      setState(() {
        analysisStatus = 'Analyzing skin allergy...';
      });

      final similarMatch = await skinCache.checkSimilarSkinCondition(
        imageFile,
        apiKey,
      );

      if (similarMatch != null) {
        setState(() {
          loading = false;
          analysisStatus = 'Analyzing skin allergy...';
        });

        navigateToSkinResults(similarMatch, imageFile, fromCache: true);
        return;
      }

      setState(() {
        analysisStatus = 'Analyzing skin allergy...';
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

      if (skinOptions.isNotEmpty) {
        skinOptions.sort((a, b) => b.confidence.compareTo(a.confidence));

        await showSkinConditionSelectionScreen(
          skinOptions,
          imageFile,
          imageHash,
        );
      } else {
        showSnackBar('Unable to analyze skin condition', Colors.red);
        setState(() {
          image = null;
          loading = false;
        });
      }
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
    String imageHash,
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

      skinCache
          .saveSkinAnalysisCache(skinData, imageFile, imageHash)
          .catchError((e) {
            print('Error saving skin analysis: $e');
          });

      navigateToSkinResults(skinData, imageFile, fromCache: false);
    } else {
      setState(() {
        image = null;
        loading = false;
      });
    }
  }

  void navigateToSkinResults(
    Map<String, dynamic> skinData,
    File imageFile, {
    bool fromCache = false,
  }) async {
    if (fromCache) {
      print('Using previous analysis result');
    }

    bool shouldReset = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => SkinResultScreen(skinData: skinData, image: imageFile),
      ),
    );

    if (!fromCache) {
      saveSkinToFirebase(skinData, imageFile)
          .catchError((e) {
            print('Background save error for skin analysis: $e');
          })
          .then((_) {
            print('Skin analysis saved successfully to Firebase');
          });
    }

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
  "ingredients": [
    {
      "name": "ingredient1",
      "benefits": "Health benefits, nutritional value, and key properties for health-conscious individuals"
    },
    {
      "name": "ingredient2",
      "benefits": "Health benefits, nutritional value, and key properties for health-conscious individuals"
    }
  ]
}

INGREDIENT BENEFITS GUIDELINES:
- Include nutritional highlights (vitamins, minerals, protein, fiber, etc.)
- Mention health benefits (heart health, immunity, digestion, etc.)
- Note any concerns (allergens, high sodium, processed, etc.)
- Keep each benefit description concise (1-2 sentences)
- For processed ingredients, be honest about nutritional limitations


CRITICAL REQUIREMENTS:
1. Focus PRIMARILY on Filipino food products but analyze international ones too
2. Focus ONLY on product identification and ingredient extraction
3. Do NOT analyze allergens in this step
4. Provide accurate ingredient lists based on OCR text
5. Use product knowledge to identify brands and products correctly
''';

  String get imageIngredientExtractionPrompt => '''
CRITICAL INSTRUCTION - READ FIRST 

**ABSOLUTE RULE: NEVER GROUP INGREDIENTS - LIST EACH ONE SEPARATELY**

WRONG EXAMPLES:
- "mixed seafood (shrimp, crab, mussels)" 
- "assorted vegetables (carrots, peas, beans)"
- "various nuts (cashews, almonds)"
- "seafood mix"

 CORRECT EXAMPLES:
- "shrimp" (separate entry)
- "crab" (separate entry)
- "mussels" (separate entry)
- "carrots" (separate entry)
- "peas" (separate entry)

**MANDATORY REQUIREMENT:**
Each visible ingredient = One separate entry in the ingredients array
If you see 5 different seafood items, you MUST create 5 separate ingredient entries.


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

**CRITICAL RULE #1: NEVER GROUP INGREDIENTS**
- WRONG: "mixed seafood (shrimp, crab, mussels)"
- CORRECT: List each as separate ingredients: "shrimp", "crab", "mussels"
- WRONG: "assorted vegetables (carrots, peas)"
- CORRECT: List each separately: "carrots", "peas"

**CRITICAL RULE #2: ONE INGREDIENT PER ENTRY**
Each ingredient MUST be its own separate entry in the ingredients array.
If you see multiple seafood items, create SEPARATE ingredient entries for EACH ONE.

SEAFOOD DISHES - LIST EACH ITEM SEPARATELY:
- If you see shrimp → add ingredient entry: "shrimp"
- If you see crab → add ingredient entry: "crab"  
- If you see mussels → add ingredient entry: "mussels"
- If you see lobster → add ingredient entry: "lobster"
- **NEVER combine them as "mixed seafood" or "seafood mix"**

**CRITICAL: LIST EACH INGREDIENT INDIVIDUALLY**
- **NEVER use generic terms like "mixed seafood", "mixed vegetables", "assorted vegetables", or "various seafood"**
- **ALWAYS list each specific ingredient separately:** 
  - Instead of "mixed seafood" → list "shrimp", "squid", "mussels", "fish" (as separate entries)
  - Instead of "mixed vegetables" → list "cabbage", "carrots", "green beans", "eggplant" (as separate entries)
  - Instead of "assorted nuts" → list "cashews", "almonds", "peanuts" (as separate entries)
- **Be as specific as possible with each ingredient you can visually identify**

FILIPINO DISHES - VISUAL IDENTIFICATION WITH ALLERGEN FOCUS (PRIMARY FOCUS):

KARE-KARE:
- Thick, orange/brown peanut-based sauce - **MUST include "peanut butter" in ingredients**
- Usually has oxtail, beef, or tripe
- Vegetables: List individually: "bok choy", "string beans", "eggplant" (NOT "mixed vegetables")
- Served with bagoong on the side - **MUST specify "shrimp paste" or "fish paste"**

ADOBO:
- Dark, soy sauce-colored - **MUST list "soy sauce"**
- Glossy appearance from oil and soy sauce
- Chicken or pork pieces

SINIGANG:
- Clear, sour broth - may contain **fish sauce (patis)** - list if present
- Vegetables clearly visible: List individually: "radish", "tomatoes", "water spinach", "long beans" (NOT "mixed vegetables")

GINILING (Ground Pork/Beef):
- Small, minced/ground meat pieces
- Usually contains soy sauce - **MUST list "soy sauce"**
- May have oyster sauce - **MUST list "oyster sauce" (contains shellfish)**
- List vegetables individually: "carrots", "potatoes", "peas" (NOT "mixed vegetables")

DINENGDENG:
- Clear broth with bagoong - **MUST specify "fish paste (bagoong)" or "shrimp paste (bagoong)"**
- List vegetables individually: "bitter melon", "squash", "okra", "eggplant" (NOT "mixed vegetables")

PINAKBET:
- List vegetables individually: "bitter melon", "eggplant", "squash", "okra", "tomatoes" (NOT "mixed vegetables")
- With bagoong - **MUST specify "shrimp paste" or "fish paste"**

BICOL EXPRESS:
- Creamy, spicy dish - **MUST list "coconut milk" and "chili peppers"**
- List other ingredients: "pork", "shrimp paste", "garlic", "onions" (as separate entries)

LAING:
- Taro leaves in coconut milk - **MUST list "coconut milk" and "taro leaves"**
- List other ingredients: "coconut cream", "chili peppers", "ginger" (as separate entries)

SEAFOOD DISHES - CRITICAL SEPARATION RULES:
- **NEVER say "mixed seafood" or "assorted seafood"**
- **ALWAYS list each type separately as individual entries:**
  - "shrimp" (separate entry)
  - "squid" (separate entry)
  - "mussels" (separate entry)
  - "clams" (separate entry)
  - "fish" (separate entry)
  - "crab" (separate entry)
- Be specific with fish types if identifiable: "tilapia", "bangus", "tuna"

VEGETABLE DISHES - CRITICAL SEPARATION RULES:
- **NEVER say "mixed vegetables" or "assorted vegetables"**
- **ALWAYS list each vegetable separately as individual entries:**
  - "cabbage" (separate entry)
  - "carrots" (separate entry)
  - "green beans" (separate entry)
  - "bell peppers" (separate entry)
  - "onions" (separate entry)

INTERNATIONAL FOODS (Secondary focus):
- If you identify chocolate cake, croissant, pasta, etc., still analyze thoroughly
- Note in description that this is outside primary Filipino cuisine expertise
- Still extract all ingredients accurately and individually

INGREDIENT IDENTIFICATION RULES:
1. Base ingredient identification on VISIBLE ingredients and the KNOWN TRADITIONAL RECIPE of the identified dish
2. Include all common seasonings, sauces, and oils
3. **List EVERY ingredient separately - no grouping or generic terms**
4. **Your most important task is to ensure allergenic components are explicitly named.** Do not just say "sauce"; specify "peanut sauce" or "peanut butter"
5. For international dishes, research typical ingredients used
6. **If you can see multiple vegetables or seafood items, list each one individually as separate entries**

CORRECT JSON STRUCTURE EXAMPLE:

WRONG:
{
  "dishName": "Seafood Paella",
  "description": "Spanish rice dish with mixed seafood",
  "ingredients": [
    {
      "name": "mixed seafood (shrimp, mussels, squid)",
      "benefits": "Rich in protein and omega-3..."
    },
    {
      "name": "rice",
      "benefits": "Source of carbohydrates..."
    }
  ]
}

CORRECT:
{
  "dishName": "Seafood Paella",
  "description": "Spanish rice dish with various seafood",
  "ingredients": [
    {
      "name": "shrimp",
      "benefits": "Excellent source of protein, omega-3 fatty acids, and selenium. Low in calories..."
    },
    {
      "name": "mussels",
      "benefits": "High in protein, iron, zinc, and vitamin B12. Supports immune function..."
    },
    {
      "name": "squid",
      "benefits": "Rich in protein, vitamins, and minerals. Contains copper and selenium..."
    },
    {
      "name": "rice",
      "benefits": "Source of carbohydrates for energy. Contains B vitamins..."
    }
  ]
}

Return JSON with this exact structure (DO NOT include allergens):
{
  "dishName": "Exact dish name (prioritize Filipino dishes)",
  "description": "Brief description of the dish characteristics and preparation method, mentioning key flavors. Note if this is outside primary Filipino cuisine focus.",
  "ingredients": [
    {
      "name": "ingredient1",
      "benefits": "Nutritional value, health benefits, and educational information for health-conscious individuals"
    },
    {
      "name": "ingredient2",
      "benefits": "Nutritional value, health benefits, and educational information for health-conscious individuals"
    },
    {
      "name": "ingredient3",
      "benefits": "Nutritional value, health benefits, and educational information for health-conscious individuals"
    }
  ]
}

INGREDIENT BENEFITS GUIDELINES:
- Highlight nutritional content (vitamins, minerals, macronutrients)
- Mention specific health benefits (anti-inflammatory, antioxidant properties, etc.)
- Include traditional medicinal uses if applicable (especially for Filipino ingredients)
- **CRITICAL: For allergenic ingredients, ALWAYS provide BOTH health benefits AND allergen warning**
- **DO NOT skip health benefits just because it's an allergen - balance both aspects**
- Note potential concerns (high sodium, saturated fat, allergens)
- Be specific: "Rich in Vitamin C and antioxidants" rather than "healthy"
- For Filipino ingredients, mention cultural significance if relevant

EXAMPLES OF PROPER ALLERGENIC INGREDIENT BENEFITS:

- Peanuts: "Excellent source of plant-based protein, healthy monounsaturated fats, and vitamin E. Rich in niacin, folate, and magnesium which support heart health and energy metabolism. Contains resveratrol, a powerful antioxidant. Major allergen - can cause severe reactions in sensitive individuals."

- Shrimp: "Excellent source of high-quality protein and omega-3 fatty acids. Rich in selenium, vitamin B12, and astaxanthin (powerful antioxidant). Low in calories and supports heart, brain, and immune health. Contains iodine for thyroid function. Shellfish allergen - avoid if allergic."

- Crab: "High-quality protein source with omega-3 fatty acids. Rich in vitamin B12, selenium, and zinc. Supports immune function and metabolism. Contains copper for bone health. Shellfish allergen - can cause severe allergic reactions."

- Mussels: "Excellent source of protein, iron, zinc, and vitamin B12. Rich in omega-3 fatty acids and selenium. Supports immune function, energy production, and red blood cell formation. Shellfish allergen."

- Lobster: "High-quality protein with minimal fat. Rich in vitamin B12, zinc, copper, and selenium. Supports immune health and metabolism. Contains omega-3 fatty acids. Premium shellfish allergen."

- Eggs: "Complete protein source with all essential amino acids. Rich in choline for brain health, vitamin D for bones, and lutein for eye health. Contains B vitamins and selenium. One of the most nutritious foods available. Common allergen, especially in children."

- Milk: "Excellent source of calcium, vitamin D, and high-quality protein. Supports bone health and muscle growth. Rich in B vitamins and phosphorus. Contains beneficial probiotics in fermented forms. Dairy allergen - those with lactose intolerance or milk allergy should avoid."

- Soy sauce: "Adds rich umami flavor to dishes. Contains some antioxidants and beneficial compounds from fermentation. Source of amino acids and minerals. High in sodium - use moderately. Contains soy allergen."

- Fish (general): "Excellent source of omega-3 fatty acids (EPA and DHA) crucial for heart and brain health. High-quality protein with all essential amino acids. Rich in vitamin D, B vitamins, selenium, and iodine. Supports cognitive function and reduces inflammation. Fish allergen."

- Cashews: "Rich in heart-healthy monounsaturated fats and copper. Good source of magnesium for bone health and iron for blood health. Contains antioxidants and supports immune function. Lower in fat than most nuts. Tree nut allergen."

- Wheat flour: "Source of complex carbohydrates for energy. Whole wheat provides fiber, B vitamins, iron, and magnesium. Enriched versions contain added nutrients. Supports digestive health when whole grain. Contains gluten - allergen for those with celiac disease or wheat allergy."

- Oyster sauce: "Rich umami flavor enhancer. Contains zinc, iron, and vitamin B12 from oysters. Provides minerals that support immune function and metabolism. High in sodium - use in moderation. Shellfish allergen derived from oysters."

- Bagoong (shrimp paste): "Traditional Filipino fermented condiment rich in protein and umami flavor. Contains beneficial probiotics from fermentation. Source of calcium and omega-3 fatty acids. High in sodium - use sparingly. Shellfish allergen from fermented shrimp."

- Coconut milk: "Rich in medium-chain triglycerides (MCTs) that provide quick energy. Contains lauric acid with antimicrobial properties. Good source of manganese, copper, and iron. Adds creamy texture and tropical flavor. While generally safe, some individuals may have coconut allergies."

CRITICAL REQUIREMENTS:
1. PRIMARY FOCUS on Filipino cuisine identification
2. Focus ONLY on dish identification and ingredient extraction
3. Do NOT analyze allergens in this step
4. **List EVERY ingredient individually - absolutely NO generic terms like "mixed vegetables", "mixed seafood", "assorted vegetables", "various seafood", "seafood mix", etc.**
5. **Each visible ingredient must be a separate entry in the ingredients array**
6. **Ensure base allergenic ingredients (peanuts, shrimp, fish, soy, milk, etc.) are explicitly listed in the ingredients array.** This is mandatory
7. **Provide health benefits for EACH individual ingredient**
8. If international dish, still analyze but note in description
9. **When you see multiple seafood or vegetables, count them and create that many separate ingredient entries**
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
- **CRITICAL**: When detecting tree nuts, list EACH TYPE separately (Cashew, Almond, Walnut, Hazelnut, Pecan, Pistachio, Macadamia, etc.)

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

6. TREE NUT ALLERGENS (detect EACH nut separately - NOT peanuts, NOT coconut):
    - **CRITICAL**: Each tree nut must be listed separately with its own entry
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
    - **Example**: If ingredients contain "cashews, almonds, walnuts" → create 3 separate allergen entries: one for Cashew, one for Almonds, one for Walnuts

7. PEANUTS ALLERGEN (LEGUME - NOT A TREE NUT):
   - Name as: "Peanuts"
   - Detect in: mani, peanut oil, peanut butter, groundnuts, peanut sauce, peanut flour
   - CRITICAL: Peanuts are legumes, NOT tree nuts. If user allergen is "nuts" or "tree nuts", DO NOT match peanuts.
   - Only match peanuts if user specifically has "peanut" or "peanuts" as their allergen.

8. WHEAT ALLERGEN:
    - Name as: "Wheat"
    - Detect in: gluten, flour, wheat flour, bread crumbs, harina, lumpia wrapper, spring roll wrapper, wheat noodles, pasta, bread, couscous, semolina, farro

9. SOY ALLERGEN:
    - Name as: "Soy"
    - Detect in: soybean, soy sauce, soybean oil, toyo, miso, tempeh, edamame, soy protein, soy lecithin
    - CRITICAL: If the user's allergen list contains "tofu," identify the allergen as **"Tofu"** instead of **"Soy"** for tofu-specific ingredients/sources. **Tofu** itself can be a distinct user-allergen.

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
    - **If ingredients contain multiple tree nuts (e.g., "cashews, almonds, walnuts") → create SEPARATE allergen entries for EACH: "Cashew", "Almonds", "Walnuts"**

2. **MULTIPLE SPECIFIC ALLERGENS**: If dish contains multiple specific allergens from same FDA category, list each separately:
    - Example: If dish has both "shrimp paste" and "oyster sauce" → list TWO allergens: "Shrimp" and "Oysters"
    - **Example: If dish has "cashews", "almonds", and "walnuts" → list THREE allergens: "Cashew", "Almonds", "Walnuts"**
    - Example: If dish has "tuna" and "anchovies" → list TWO allergens: "Tuna" and "Anchovies"

3. **USER ALLERGEN MATCHING - CATEGORY EXPANSION**:
    - **CRITICAL**: If user allergen is "shellfish" → detect ALL specific shellfish separately (Shrimp, Crab, Oysters, Clams, Mussels, etc.) and mark EACH as isUserAllergen: true
    - **CRITICAL**: If user allergen is "nut", "nuts", or "tree nuts" → detect ALL specific tree nuts separately (Cashew, Almonds, Walnuts, Hazelnuts, Pecans, Pistachios, Macadamia, etc.) and mark EACH as isUserAllergen: true
    - **CRITICAL**: If user allergen is "fish" → detect ALL specific fish separately (Tuna, Salmon, Bangus, Anchovies, etc.) and mark EACH as isUserAllergen: true
    - If user allergen is specific (e.g., "shrimp", "cashew") → only detect that specific allergen and mark it as isUserAllergen: true
    - **Example**: User has "nuts" allergen, ingredients contain "cashews, almonds, walnuts" → create 3 separate entries ALL marked isUserAllergen: true

4. **SMART LINGUISTIC MATCHING**: Use AI intelligence to match allergens with variations:
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

5. **DEDUPLICATE ALLERGENS**: If same allergen found in multiple ingredients, list it ONCE with ALL sources:
    - Example: "soy sauce" and "tofu" both contain soy → ONE "Soy" allergen with sources: "soy sauce, tofu"
    - Example: "shrimp" and "shrimp paste" → ONE "Shrimp" allergen with sources: "shrimp, shrimp paste"
    - Example: "milk" and "cheese" → ONE "Milk" allergen with sources: "milk, cheese"
    - **BUT**: "cashews" and "almonds" are DIFFERENT allergens → TWO separate entries

6. **CONTEXT-AWARE DETECTION**:
    - Fish sauce (patis) → detect as "Fish Sauce"
    - Bagoong isda → detect as "Fish Paste"  
    - Bagoong alamang → detect as "Shrimp"
    - Oyster sauce → detect as "Oysters"
    - Lumpia wrapper → detect as "Wheat"
    - Soy sauce (toyo) → detect as "Soy"
    - Shrimp paste (alamang) → detect as "Shrimp"

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
            "name": "Specific allergen name (e.g., 'Shrimp', 'Cashew', 'Almonds', 'Walnuts', 'Tuna', 'Milk', 'Eggs' - NOT 'Shellfish' or 'Tree Nuts')",
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
5. **LIST EACH TREE NUT SEPARATELY** - never group as "Tree Nuts" or "Mixed Nuts"
6. **When user has category allergen (nuts, shellfish, fish), mark ALL specific items in that category as isUserAllergen: true**
7. Provide appropriate risk levels and symptoms
''';
  }

  String get ingredientSimplificationPrompt => '''
You are an expert ingredient name standardizer. Your task is to convert complex ingredient names into simple, recognizable names while preserving allergen-relevant context.

**CRITICAL**: You MUST return a JSON array with BOTH "original" and "simplified" for EVERY ingredient, maintaining the EXACT same order.


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
1. Return ALL ingredients in the SAME ORDER as provided
2. ALWAYS include both "original" and "simplified" fields
3. If no simplification needed, return the same name for both
4. Keep common food names recognizable (lumpia wrapper, soy sauce, fish sauce)
5. Only simplify overly technical or marketing terms
6. Preserve allergen context within food names
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
  "ingredients": [
        {
          "name": "ingredient1",
          "benefits": "Health benefits and nutritional information"
        },
        {
          "name": "ingredient2",
          "benefits": "Health benefits and nutritional information"
        }
      ],
            "confidence": 0.95
    },
    {
      "dishName": "Alternative interpretation",
      "description": "Different possible product identification",
  "ingredients": [
        {
          "name": "ingredient1",
          "benefits": "Health benefits and nutritional information"
        },
        {
          "name": "ingredient2",
          "benefits": "Health benefits and nutritional information"
        }
      ],      "confidence": 0.75
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
You are an EXPERT food identification system specializing in Filipino cuisine and regional/international dishes.

PRIMARY MISSION: IDENTIFY DISHES WITH CLEAN, RECOGNIZABLE NAMES

CRITICAL DISH NAMING RULES:
- Use BASE DISH NAME + PROTEIN TYPE only
- NEVER include optional ingredients in dish name (hotdog, raisins, etc.)
- NEVER include location/region in dish name
- Keep names SHORT and RECOGNIZABLE (2-3 words maximum)
- Use generic dish names, not regional variations

CORRECT DISH NAMING EXAMPLES:

FILIPINO DISHES - Base + Protein:
 "Pork Menudo" (NOT "Pork Menudo with Hotdog")
 "Oxtail Kare-Kare" (NOT "Oxtail Kare-Kare with Vegetables")
 "Chicken Adobo" (NOT "Chicken Adobo with Eggs")
 "Shrimp Sinigang" (NOT "Shrimp Sinigang with Vegetables")
 "Beef Caldereta" (NOT "Beef Caldereta with Olives")
 "Dinuguan" (NOT "Ilocos Dinuguan")
 "Dinardaraan" (NOT "Ilocano Dinardaraan")

GENERIC DISHES - Simple Names:
 "Seafood Boil" (NOT "Cajun Seafood Boil" or "Louisiana Crawfish Boil")
 "Crawfish Boil" (NOT "Louisiana Crawfish Boil")
 "Clam Bake" (NOT "New England Clam Bake")
 "Paella" (NOT "Spanish Paella")
 "Cioppino" (NOT "Italian Cioppino")
 "Tom Yum" (NOT "Thai Tom Yum")
 "Seafood Platter"
 "Mixed Grill"
 "Seafood Pasta"
 "Fried Chicken"

WRONG DISH NAMES (NEVER USE):
 "Pork Menudo with Hotdog and Raisins"
 "Seafood Boil with Crab Mussels Shrimp"
 "Kare-Kare with Vegetables"
 "Mixed_Seafood_Crab_Shrimp"
 "Cajun Seafood Boil"
 "Louisiana Crawfish Boil"
 "New England Clam Bake"
 "Ilocos Dinuguan"

PHASE 1: DISH IDENTIFICATION

FILIPINO DISHES (Primary Focus):

TOMATO-BASED STEWS:
- Pork Menudo, Beef Menudo, Chicken Menudo
- Pork Afritada, Chicken Afritada
- Beef Caldereta, Goat Caldereta
- Beef Mechado

PEANUT-BASED:
- Oxtail Kare-Kare, Pork Kare-Kare, Seafood Kare-Kare

SOY-BASED:
- Chicken Adobo, Pork Adobo, Squid Adobo
- Adobo sa Gata (if coconut milk visible)

SOUR SOUP:
- Pork Sinigang, Shrimp Sinigang, Fish Sinigang, Beef Sinigang

CREAMY/SPICY:
- Bicol Express, Laing, Ginataang Gulay

BLOOD-BASED:
- Dinuguan, Dinardaraan

INTERNATIONAL DISHES (Secondary Focus):

SEAFOOD BOILS:
- Seafood Boil (mixed shellfish with corn and potatoes)
- Crawfish Boil (crawfish-focused)
- Clam Bake (clam-focused with seafood)

RICE DISHES:
- Paella (saffron rice with seafood/meat)
- Seafood Paella (paella variation)
- Jambalaya (rice with meat and vegetables)
- Arroz con Mariscos (seafood rice)

PASTA DISHES:
- Seafood Pasta (generic)
- Linguine ai Frutti di Mare (seafood linguine)
- Pad Thai (rice noodles)

SOUPS & STEWS:
- Bouillabaisse (fish stew)
- Cioppino (seafood stew)
- Tom Yum (sour and spicy soup)

IDENTIFICATION STRATEGY:

1. LOOK FOR COOKING STYLE MARKERS:
   - Red-orange spices, corn, potatoes, sausage → Seafood Boil
   - Clams, lobster, simple seasoning → Clam Bake
   - Saffron yellow rice, chorizo, bell peppers → Paella
   - Tomato-based sauce, white wine, herbs → Cioppino
   - Lemongrass, galangal, lime leaves, clear broth → Tom Yum

2. PROTEIN TYPE:
   - Identify primary protein: pork, beef, chicken, oxtail, seafood
   - Use in dish name: "Pork Menudo", "Oxtail Kare-Kare"

3. SAUCE/BROTH CHARACTERISTICS:
   - Tomato-based red sauce → Menudo/Afritada/Caldereta
   - Peanut sauce → Kare-Kare
   - Dark soy sauce → Adobo
   - Clear sour broth → Sinigang
   - Creamy coconut → Bicol Express/Laing
   - Dark blood-based → Dinuguan/Dinardaraan

PHASE 2: INGREDIENT LISTING

LIST ALL VISIBLE AND TRADITIONAL INGREDIENTS SEPARATELY:

SEAFOOD (list each type):
- "shrimp" (separate entry)
- "crab" (separate entry)
- "mussels" (separate entry)
- "clams" (separate entry)
- "crawfish" (separate entry)
- "lobster" (separate entry)

VEGETABLES (list each type):
- "corn" (separate entry)
- "potatoes" (separate entry)
- "carrots" (separate entry)
- "bell peppers" (separate entry)

PROCESSED MEATS (list each type):
- "hotdog" (if visible)
- "sausage" (specify type: andouille, chorizo, etc.)
- "bacon"

ALLERGEN INGREDIENTS (must list with warnings):
- Peanut butter (in Kare-Kare)
- Shrimp paste (bagoong)
- Soy sauce
- Fish sauce
- Eggs
- Dairy products

CONFIDENCE SCORING:

0.90-0.95: Clear identification with cooking style markers visible
0.75-0.89: Good identification, some details visible
0.60-0.74: Base category identified, limited details
0.50-0.59: Generic fallback category

OUTPUT FORMAT:

{
  "options": [
    {
      "dishName": "Seafood Boil",
      "description": "Mixed shellfish boil with spices, featuring shrimp, crab, mussels, corn, and potatoes in seasoned broth",
      "ingredients": [
        {"name": "shrimp", "benefits": "Excellent lean protein with omega-3 fatty acids. SHELLFISH ALLERGEN."},
        {"name": "crab", "benefits": "High-quality protein with vitamins. SHELLFISH ALLERGEN."},
        {"name": "mussels", "benefits": "Rich in iron and protein. SHELLFISH ALLERGEN."},
        {"name": "corn", "benefits": "Good source of fiber and vitamins."},
        {"name": "potatoes", "benefits": "Complex carbohydrates and vitamin C."},
        {"name": "sausage", "benefits": "Protein source. May contain MILK, WHEAT allergens."},
        {"name": "cajun seasoning", "benefits": "Spice blend with paprika, cayenne, garlic."},
        {"name": "butter", "benefits": "Fat-soluble vitamins. DAIRY allergen."}
      ],
      "confidence": 0.92
    },
    {
      "dishName": "Crawfish Boil",
      "description": "Crawfish-focused boil with vegetables and spices",
      "ingredients": [...],
      "confidence": 0.75
    }
  ]
}

CRITICAL RULES:
 Base dish name + protein only
 NO region/location names in dish name
 List ALL ingredients separately
 Include allergen warnings
 3-4 options with confidence scores
 NO optional ingredients in dish name
 NO ingredient lists as dish names
 NO underscores or concatenation

NOW ANALYZE THE IMAGE.
''';

  Future<void> analyzeOCRText(String ocrText, File imageFile) async {
    if (apiKey == 'YOUR_API_KEY_HERE') {
      setState(() => loading = false);
      return;
    }

    try {
      setState(() {
        isOCRAnalysis = true;
        analysisStatus = 'Analyzing product label...';
      });

      final model = GenerativeModel(model: 'gemini-2.5-pro', apiKey: apiKey);

      final quickExtractPrompt = '''
Extract ONLY the product name from this OCR text. Return just the product name, nothing else.

OCR TEXT:
"$ocrText"

Return only the product name.
''';

      final quickResponse = await model.generateContent([
        Content.text(quickExtractPrompt),
      ]);

      String possibleProductName = (quickResponse.text ?? '').trim();

      setState(() {
        analysisStatus = 'Checking cache...';
      });

      var cachedData = await allergenAnalysis.checkFoodCache(
        possibleProductName,
        imageFile: imageFile,
        apiKey: apiKey,
      );

      if (cachedData != null) {
        print('Product found in cache');

        setState(() {
          dishName = cachedData['dishName'] ?? possibleProductName;
          description = cachedData['description'] ?? '';
          ingredients = List<String>.from(cachedData['ingredients'] ?? []);
          analysisStatus = 'Loading from cache...';
        });

        ingredientBenefitsMap = IngredientBenefitsMap();
        if (cachedData.containsKey('ingredientBenefits')) {
          var benefitsData = cachedData['ingredientBenefits'];
          if (benefitsData is Map) {
            Map<String, dynamic> benefits = Map<String, dynamic>.from(
              benefitsData,
            );
            benefits.forEach((key, value) {
              ingredientBenefitsMap.addBenefit(
                key.toString(),
                value.toString(),
              );
            });
          }
        }

        List<AllergenInfo> cachedAllergens =
            (cachedData['allergens'] as List? ?? [])
                .map((a) => AllergenInfo.fromJson(a))
                .toList();

        await allergenAnalysis.updateAllergenHighlighting(cachedAllergens);

        List<IngredientColorInfo> ingredientColors = await allergenAnalysis
            .computeIngredientColors(ingredients, cachedAllergens);

        for (AllergenInfo allergen in cachedAllergens) {
          allergen.ingredientColors.clear();
          allergen.ingredientColors.addAll(ingredientColors);
        }

        setState(() {
          allergens = cachedAllergens;
          loading = false;
          analysisStatus = '';
        });

        navigateToResults();

        saveToFirebase(imageFile).catchError((e) {
          print('Background save error: $e');
        });

        return;
      }

      setState(() {
        analysisStatus = 'Analyzing ingredients...';
      });

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
        analysisStatus = 'Generating dish options';
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
        analysisStatus = 'Analyzing food...';
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

      if (dishOptions.isNotEmpty) {
        dishOptions.sort((a, b) => b.confidence.compareTo(a.confidence));

        final topDish = dishOptions.first;

        setState(() {
          analysisStatus = 'Checking cache...';
        });

        var cachedData = await allergenAnalysis.checkFoodCache(
          topDish.dishName,
          imageFile: imageFile,
          apiKey: apiKey,
        );

        if (cachedData != null) {
          final matchLevel = cachedData['matchLevel'] ?? 0;
          final matchType = cachedData['matchType'] ?? 'unknown';
          final matchConfidence = cachedData['matchConfidence'] ?? 1.0;

          print(
            'Cache hit (Level $matchLevel: $matchType, confidence: $matchConfidence)',
          );

          if (matchType == 'visual_similarity') {
            showSnackBar(
              'Found similar dish from ${DateTime.now().difference(DateTime.parse(cachedData['timestamp'] ?? DateTime.now().toIso8601String())).inDays} days ago (${(matchConfidence * 100).toInt()}% match)',
              Colors.blue,
            );
          }

          setState(() {
            dishName = cachedData['dishName'] ?? topDish.dishName;
            description = cachedData['description'] ?? '';
            ingredients = List<String>.from(cachedData['ingredients'] ?? []);
            analysisStatus = 'Loading from cache...';
          });

          ingredientBenefitsMap = IngredientBenefitsMap();
          if (cachedData.containsKey('ingredientBenefits')) {
            var benefitsData = cachedData['ingredientBenefits'];
            if (benefitsData is Map) {
              Map<String, dynamic> benefits = Map<String, dynamic>.from(
                benefitsData,
              );
              benefits.forEach((key, value) {
                ingredientBenefitsMap.addBenefit(
                  key.toString(),
                  value.toString(),
                );
              });
            }
          }

          List<AllergenInfo> cachedAllergensList =
              (cachedData['allergens'] as List? ?? [])
                  .map((a) => AllergenInfo.fromJson(a))
                  .toList();

          await allergenAnalysis.updateAllergenHighlighting(
            cachedAllergensList,
          );

          List<IngredientColorInfo> ingredientColors = await allergenAnalysis
              .computeIngredientColors(ingredients, cachedAllergensList);

          for (AllergenInfo allergen in cachedAllergensList) {
            allergen.ingredientColors.clear();
            allergen.ingredientColors.addAll(ingredientColors);
          }

          setState(() {
            allergens = cachedAllergensList;
            loading = false;
            analysisStatus = '';
          });

          navigateToResults();

          saveToFirebase(imageFile).catchError((e) {
            print('Background save error: $e');
          });

          return;
        }
      }

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
      analysisStatus = 'Processing...';
    });

    try {
      List<IngredientWithBenefits> processedIngredients =
          splitGroupedIngredients(selectedOption.ingredientsWithBenefits);

      ingredientBenefitsMap = IngredientBenefitsMap();
      for (var ingWithBenefits in processedIngredients) {
        ingredientBenefitsMap.addBenefit(
          ingWithBenefits.name,
          ingWithBenefits.benefits,
        );
      }

      List<String> currentIngredients =
          processedIngredients.map((e) => e.name).toList();

      setState(() {
        analysisStatus = 'Checking cache...';
      });

      var cachedData = await allergenAnalysis.checkFoodCache(
        selectedOption.dishName,
        imageFile: imageFile,
        apiKey: apiKey,
      );

      if (cachedData != null) {
        print('Cache hit after dish selection');

        setState(() {
          analysisStatus = 'Loading from cache...';
          ingredients = List<String>.from(cachedData['ingredients'] ?? []);
        });

        List<AllergenInfo> cachedAllergens =
            (cachedData['allergens'] as List? ?? [])
                .map((a) => AllergenInfo.fromJson(a))
                .toList();

        await allergenAnalysis.updateAllergenHighlighting(cachedAllergens);

        List<IngredientColorInfo> ingredientColors = await allergenAnalysis
            .computeIngredientColors(ingredients, cachedAllergens);

        for (AllergenInfo allergen in cachedAllergens) {
          allergen.ingredientColors.clear();
          allergen.ingredientColors.addAll(ingredientColors);
        }

        setState(() {
          allergens = cachedAllergens;
          loading = false;
          analysisStatus = '';
        });

        navigateToResults();

        saveToFirebase(imageFile).catchError((e) {
          print('Background save error: $e');
        });

        return;
      }

      final model = GenerativeModel(model: 'gemini-2.5-pro', apiKey: apiKey);

      setState(() {
        analysisStatus = 'Simplifying ingredients...';
      });

      List<String> originalIngredients =
          processedIngredients.map((e) => e.name).toList();

      List<String> simplifiedIngredients = await simplifyIngredientNames(
        originalIngredients,
        model,
      );

      IngredientBenefitsMap finalBenefitsMap = IngredientBenefitsMap();

      for (
        int i = 0;
        i < originalIngredients.length && i < simplifiedIngredients.length;
        i++
      ) {
        String simplifiedName = simplifiedIngredients[i];
        String? benefit = processedIngredients[i].benefits;

        if (benefit != null && benefit.isNotEmpty) {
          finalBenefitsMap.addBenefit(simplifiedName, benefit);
          finalBenefitsMap.addBenefit(
            simplifiedName.toLowerCase().trim(),
            benefit,
          );
        }
      }

      ingredientBenefitsMap = finalBenefitsMap;

      setState(() {
        ingredients = simplifiedIngredients;
        analysisStatus = 'Analyzing allergens...';
      });

      await analyzeAllergensFromIngredients(simplifiedIngredients);

      await allergenAnalysis.saveFoodCache(
        dishName,
        description,
        ingredients,
        allergens,
        ingredientBenefitsMap: ingredientBenefitsMap,
        imageFile: imageFile,
      );

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

  List<IngredientWithBenefits> splitGroupedIngredients(
    List<IngredientWithBenefits> ingredients,
  ) {
    List<IngredientWithBenefits> result = [];

    for (var ingredient in ingredients) {
      String name = ingredient.name.toLowerCase();

      if (name.contains('(') ||
          name.contains('mixed') ||
          name.contains('assorted')) {
        RegExp parenRegex = RegExp(r'\((.*?)\)');
        Match? match = parenRegex.firstMatch(name);

        if (match != null) {
          String itemsInParen = match.group(1) ?? '';
          List<String> individualItems =
              itemsInParen
                  .split(',')
                  .map((item) => item.trim())
                  .where((item) => item.isNotEmpty)
                  .toList();

          for (String item in individualItems) {
            result.add(
              IngredientWithBenefits(name: item, benefits: ingredient.benefits),
            );
          }

          print(
            'Split grouped ingredient: "${ingredient.name}" into: $individualItems',
          );
        } else {
          print(
            'WARNING: Grouped ingredient without parentheses: "${ingredient.name}"',
          );
          result.add(ingredient);
        }
      } else {
        result.add(ingredient);
      }
    }

    return result;
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
              delaySeconds: 1,
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

  Future<void> ensureAllIngredientBenefits(
    List<String> ingredients,
    GenerativeModel model,
  ) async {
    List<String> missingBenefits = [];

    for (String ingredient in ingredients) {
      String? benefit = ingredientBenefitsMap.getBenefit(ingredient);
      if (benefit == null || benefit.isEmpty) {
        missingBenefits.add(ingredient);
      }
    }

    if (missingBenefits.isEmpty) return;

    try {
      final benefitsPrompt = '''
You are a nutritional expert. For each ingredient provided, give detailed health benefits in 2-3 sentences.

INGREDIENTS: ${missingBenefits.join(', ')}

Return JSON with this structure:
{
  "benefits": [
    {
      "name": "ingredient name",
      "benefits": "Detailed nutritional value, health benefits, vitamins, minerals."
    }
  ]
}

GUIDELINES:
- Highlight nutritional content (vitamins, minerals, macronutrients)
- Mention specific health benefits (anti-inflammatory, antioxidant, etc.)
- Note potential allergens if applicable
- Be specific and educational
- Keep each benefit description 2-3 sentences
- Focus on facts, no promotional language
''';

      final benefitsResponse = await model.generateContent([
        Content.text(benefitsPrompt),
      ]);

      String responseText = benefitsResponse.text ?? '';
      String cleanResponse = responseText;

      if (responseText.contains('```json')) {
        cleanResponse = responseText.split('```json')[1].split('```')[0];
      } else if (responseText.contains('```')) {
        cleanResponse = responseText.split('```')[1];
      }

      final jsonData = json.decode(cleanResponse.trim());
      final List<dynamic> benefitsList = jsonData['benefits'] ?? [];

      for (var item in benefitsList) {
        if (item is Map<String, dynamic>) {
          String name = item['name']?.toString() ?? '';
          String benefits = item['benefits']?.toString() ?? '';
          if (name.isNotEmpty && benefits.isNotEmpty) {
            ingredientBenefitsMap.addBenefit(name, benefits);
          }
        }
      }
    } catch (e) {
      print('Error fetching missing benefits: $e');
    }
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

      Map<String, String> originalToSimplified = {};

      for (var item in simplifications) {
        if (item is Map<String, dynamic> &&
            item['original'] != null &&
            item['simplified'] != null) {
          String original = item['original'].toString().trim();
          String simplified = item['simplified'].toString().trim();
          originalToSimplified[original.toLowerCase()] = simplified;
          simplifiedIngredients.add(simplified);
        }
      }

      if (simplifiedIngredients.isEmpty ||
          simplifiedIngredients.length != originalIngredients.length) {
        return originalIngredients;
      }

      for (int i = 0; i < originalIngredients.length; i++) {
        print(
          'Simplification: "${originalIngredients[i]}" → "${simplifiedIngredients[i]}"',
        );
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
              ingredientBenefitsMap: ingredientBenefitsMap,
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

    final rawIngredients = ingredientText.split(',');
    final enteredIngredients = <String>[];
    for (int i = 0; i < rawIngredients.length; i++) {
      final trimmed = rawIngredients[i].trim();
      if (trimmed.isNotEmpty) {
        enteredIngredients.add(trimmed);
      }
    }

    setState(() {
      loading = true;
      dishName = dishNameText;
      isOCRAnalysis = false;
      showManualInput = false;
      analysisStatus = 'Checking cache...';
    });

    try {
      final cachedData = await allergenAnalysis.checkFoodCache(dishNameText);

      if (cachedData != null) {
        print(' Manual entry: Cache hit for "$dishNameText"');

        final cachedIngredients = List<String>.from(
          cachedData['ingredients'] ?? [],
        );
        final cachedDescription = cachedData['description'] ?? '';
        final cachedAllergensRaw = cachedData['allergens'] as List? ?? [];

        final cachedAllergens = <AllergenInfo>[];
        for (int i = 0; i < cachedAllergensRaw.length; i++) {
          final allergen = AllergenInfo.fromJson(cachedAllergensRaw[i]);
          cachedAllergens.add(allergen);
        }

        ingredientBenefitsMap = IngredientBenefitsMap();
        if (cachedData.containsKey('ingredientBenefits')) {
          var benefitsData = cachedData['ingredientBenefits'];
          if (benefitsData is Map) {
            Map<String, dynamic> benefits = Map<String, dynamic>.from(
              benefitsData,
            );
            benefits.forEach((key, value) {
              ingredientBenefitsMap.addBenefit(
                key.toString(),
                value.toString(),
              );
            });
          }
        }

        final ingredientColors = await allergenAnalysis.computeIngredientColors(
          cachedIngredients,
          cachedAllergens,
        );

        for (int i = 0; i < cachedAllergens.length; i++) {
          cachedAllergens[i].ingredientColors.clear();
          for (int j = 0; j < ingredientColors.length; j++) {
            cachedAllergens[i].ingredientColors.add(ingredientColors[j]);
          }
        }

        setState(() {
          ingredients = cachedIngredients;
          description = cachedDescription;
          allergens = cachedAllergens;
          loading = false;
          analysisStatus = '';
          image = null;
        });

        showSnackBar('Loaded from cache', Colors.blue);
        navigateToResults();
        saveToFirebase(null).catchError((_) {});
        dishNameController.clear();
        ingredientController.clear();
        return;
      }

      print('Manual entry: No cache, analyzing "$dishNameText"');

      final flashModel = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
      );

      setState(() {
        analysisStatus = 'Analyzing ingredients...';
      });

      final benefitsPrompt = '''
You are a nutritional expert. For each ingredient provided, give detailed health benefits in 2-3 sentences.

INGREDIENTS: ${enteredIngredients.join(', ')}

Return JSON with this structure:
{
  "benefits": [
    {
      "name": "ingredient name",
      "benefits": "Detailed nutritional value, health benefits, vitamins, minerals."
    }
  ]
}

GUIDELINES:
- Highlight nutritional content (vitamins, minerals, macronutrients)
- Mention specific health benefits (anti-inflammatory, antioxidant, etc.)
- Note potential allergens if applicable
- Be specific and educational
- Keep each benefit description 2-3 sentences
- Focus on facts, no promotional language
''';

      final benefitsResponse = await flashModel.generateContent([
        Content.text(benefitsPrompt),
      ]);

      final benefitsData = await parseIngredientResponse(
        benefitsResponse.text ?? '',
      );
      final benefitsList = benefitsData['benefits'] ?? [];

      ingredientBenefitsMap = IngredientBenefitsMap();

      for (int i = 0; i < benefitsList.length; i++) {
        final item = benefitsList[i];
        if (item is Map<String, dynamic>) {
          final name = item['name']?.toString() ?? '';
          final benefits = item['benefits']?.toString() ?? '';
          if (name.isNotEmpty && benefits.isNotEmpty) {
            ingredientBenefitsMap.addBenefit(name, benefits);
          }
        }
      }

      setState(() {
        analysisStatus = 'Simplifying ingredients...';
      });

      final model = GenerativeModel(model: 'gemini-2.5-pro', apiKey: apiKey);
      final simplifiedIngredients = await simplifyIngredientNames(
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
        analysisStatus = 'Analyzing allergens...';
      });

      await analyzeAllergensFromIngredients(simplifiedIngredients);

      await allergenAnalysis.saveFoodCache(
        dishName,
        description,
        ingredients,
        allergens,
        ingredientBenefitsMap: ingredientBenefitsMap,
      );

      setState(() {
        loading = false;
        analysisStatus = '';
      });

      navigateToResults();
      saveToFirebase(null).catchError((_) {});
    } catch (e) {
      showSnackBar('Error analyzing ingredients: $e', Colors.red);
      setState(() {
        loading = false;
        analysisStatus = '';
      });
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

      Map<String, String> benefitsToSave = {};
      for (String ingredient in ingredients) {
        String? benefit = ingredientBenefitsMap.getBenefit(ingredient);
        if (benefit != null && benefit.isNotEmpty) {
          benefitsToSave[ingredient] = benefit;
        }
      }

      Map<String, double> userSeverities = Map<String, double>.from(
        allergenData['severities'] ?? {},
      );

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
                    'severity':
                        a.isUserAllergen
                            ? userSeverities[a.name.toLowerCase()]
                            : null,
                  },
                )
                .toList(),
        'ingredientColors': ingredientColors.map((ic) => ic.toJson()).toList(),
        'ingredientBenefits': benefitsToSave,

        'imageUrl': imageUrl ?? '',
        'fileName': fileName ?? '',
        'isOCRAnalysis': isOCRAnalysis,
        'timestamp': FieldValue.serverTimestamp(),
        'scanDate': DateTime.now().toIso8601String(),
        'userId': user.uid,
        'userAllergensAtScanTime': userAllergensWithSeverity,
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
                    severity = 1.0;
                    break;
                  case 'moderate':
                    severity = 0.5;
                    break;
                  case 'mild':
                    severity = 0.0;
                    break;
                  default:
                    severity = 0.0;
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
    IngredientBenefitsMap? benefitsMap;
    if (scanData.containsKey('ingredientBenefits')) {
      benefitsMap = IngredientBenefitsMap();
      var benefitsData = scanData['ingredientBenefits'];
      print('ingredientBenefits type: ${benefitsData.runtimeType}');
      print('ingredientBenefits content: $benefitsData');

      if (benefitsData is Map) {
        Map<String, dynamic> benefits = Map<String, dynamic>.from(benefitsData);

        benefits.forEach((key, value) {
          String ingredientKey = key.toString();
          String benefitValue = value.toString();
          benefitsMap!.addBenefit(ingredientKey, benefitValue);
          print(
            'Added benefit for "$ingredientKey": ${benefitValue.substring(0, benefitValue.length > 50 ? 50 : benefitValue.length)}...',
          );
        });
      }
    }

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
              ingredientBenefitsMap: benefitsMap,
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
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => AirQualityDetailScreen(
                              apiKey: 'AIzaSyCWva81wgqeq5qIShLvoO9hs20ejk73gCE',
                            ),
                      ),
                    );
                  },
                  child: const Icon(
                    Icons.analytics_outlined,
                    color: AppColors.primaryColor3,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 70),

                //   buildNavButton(assetPath, onTap)
                GestureDetector(
                  onTap: () {
                    // Navigate to food allergy screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FoodAllergyScreen(),
                      ),
                    );
                  },
                  child: const Icon(
                    Icons.school,
                    color: AppColors.primaryColor3,
                    size: 24,
                  ),
                ),

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
  bool isUserAllergen;
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

class IngredientBenefitsMap {
  Map<String, String> benefitsMap = {};

  void addBenefit(String ingredient, String benefit) {
    benefitsMap[ingredient.toLowerCase().trim()] = benefit;
  }

  String? getBenefit(String ingredient) {
    return benefitsMap[ingredient.toLowerCase().trim()];
  }
}
