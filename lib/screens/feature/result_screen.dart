import 'dart:io';
import 'package:allergen/screens/feature/allergen_analysis.dart';
import 'package:allergen/screens/profile_screen_items/scanHistoryScreen.dart';
import 'package:allergen/screens/first_Aid_screens/FirstAidScreen.dart';
import 'package:allergen/screens/feature/scan_screen.dart';
import 'package:allergen/screens/feature/allergen_tab.dart';
import 'package:allergen/screens/feature/description_tab.dart';
import 'package:allergen/styleguide.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';

class ResultScreen extends StatefulWidget {
  final File? image;
  final String dishName;
  final String description;
  final List<String> ingredients;
  final List<AllergenInfo> allergens;
  final Function(List<String>) onIngredientsChanged;
  final bool isOCRAnalysis;
  final List<IngredientColorInfo> ingredientColors;
  final bool isFromHistory;
  final Map<String, double>? historicalSeverityData;
  final IngredientBenefitsMap? ingredientBenefitsMap;

  const ResultScreen({
    Key? key,
    required this.image,
    required this.dishName,
    required this.description,
    required this.ingredients,
    required this.allergens,
    required this.onIngredientsChanged,
    required this.isOCRAnalysis,
    required this.ingredientColors,
    this.isFromHistory = false,
    this.historicalSeverityData,
    this.ingredientBenefitsMap,
  }) : super(key: key);

  @override
  _ResultScreenState createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  late TabController tabController;
  late List<String> currentIngredients;
  late List<AllergenInfo> currentAllergens;
  List<IngredientColorInfo> currentIngredientColors = [];

  bool isAnalyzing = false;

  bool isEditing = false;
  String? documentId;
  final TextEditingController ingredientController = TextEditingController();
  final AllergenAnalysis allergenAnalysis = AllergenAnalysis();

  static final String _apiKey = dotenv.env['API_KEY'] ?? '';

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 2, vsync: this);
    currentIngredients = List.from(widget.ingredients);
    currentAllergens = List.from(widget.allergens);
    currentIngredientColors = List.from(widget.ingredientColors);
    
   
  }

  @override
  void dispose() {
    tabController.dispose();
    ingredientController.dispose();
    super.dispose();
  }

  bool hasUserAllergen() {
    return currentAllergens.any((allergen) => allergen.isUserAllergen == true);
  }

  void toggleEdit() {
    if (widget.isFromHistory) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cannot edit ingredients from history. Please rescan to make changes.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      isEditing = !isEditing;
    });
  }

  Future<void> performAllergenAnalysis(List<String> ingredients) async {
    if (widget.isFromHistory) {
      return;
    }

    if (isAnalyzing || !mounted) return;

    setState(() {
      isAnalyzing = true;
    });

    try {
      final allergenData = await allergenAnalysis.getUserAllergenData();
      List<String> userAllergens = List<String>.from(allergenData['names']);

      final model = GenerativeModel(model: 'gemini-2.5-pro', apiKey: _apiKey);

      final allergenPrompt = '''${getAllergenAnalysisPrompt(userAllergens)}

INGREDIENTS TO ANALYZE:
${ingredients.join(', ')}

Analyze each ingredient carefully and identify any allergens from BOTH the FDA major allergens AND the user's custom allergens: ${userAllergens.join(', ')}

CRITICAL: Ensure NO DUPLICATE allergens in the results. Each allergen should appear only once with all its sources listed.
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
          .computeIngredientColors(ingredients, detectedAllergens);

      for (AllergenInfo allergen in detectedAllergens) {
        allergen.ingredientColors.clear();
        allergen.ingredientColors.addAll(ingredientColors);
      }

      if (mounted) {
        setState(() {
          currentAllergens = detectedAllergens;
          currentIngredientColors = ingredientColors;
          currentIngredients = ingredients;
        });
      }
    } catch (e) {
      print('Error analyzing allergens: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error analyzing allergens: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isAnalyzing = false;
        });
      }
    }
  }

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

Return JSON with this exact structure:
{
  "allergens": [
    {
      "name": "Specific allergen name",
      "riskLevel": "severe|moderate|mild|safe",
      "symptoms": ["symptom1", "symptom2", "symptom3"],
      "sources": ["ingredient1", "ingredient2"],
      "category": "FDA_MAJOR|USER_CUSTOM",
      "isUserAllergen": true/false,
      "matchingReason": "Brief explanation"
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

  Future saveChanges() async {
    setState(() {
      isEditing = false;
    });

    await performAllergenAnalysis(currentIngredients);

    try {
      await updateInFirebase();
      await widget.onIngredientsChanged(currentIngredients);
    } catch (e) {
      print('Error saving changes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save changes: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> updateInFirebase() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      if (documentId == null) {
        final querySnapshot =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('history')
                .orderBy('timestamp', descending: true)
                .limit(1)
                .get();
        if (querySnapshot.docs.isNotEmpty) {
          documentId = querySnapshot.docs.first.id;
        } else {
          throw Exception('No document found to update');
        }
      }
      final updateData = {
        'ingredients': currentIngredients,
        'allergens':
            currentAllergens
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
        'ingredientColors':
            currentIngredientColors.map((ic) => ic.toJson()).toList(),
        'lastUpdated': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('history')
          .doc(documentId)
          .update(updateData);
      print('Successfully updated document in Firebase');
    } catch (e) {
      print('Error updating Firebase: $e');
      throw e;
    }
  }

  void addIngredient() {
    if (widget.isFromHistory) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cannot edit ingredients from history. Please rescan to make changes.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final TextEditingController ingredientController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Ingredient'),
          content: TextField(
            controller: ingredientController,
            decoration: const InputDecoration(
              hintText: 'Enter ingredient name',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            onSubmitted: (_) {
              if (ingredientController.text.trim().isNotEmpty) {
                addIngredientAndReanalyze(ingredientController.text.trim());
                Navigator.pop(context);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (ingredientController.text.trim().isNotEmpty) {
                  addIngredientAndReanalyze(ingredientController.text.trim());
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Future<void> addIngredientAndReanalyze(String ingredient) async {
    final updatedIngredients = List<String>.from(currentIngredients);
    updatedIngredients.add(ingredient);
    await performAllergenAnalysis(updatedIngredients);
  }

  Future<void> removeIngredient(int index) async {
    final updatedIngredients = List<String>.from(currentIngredients);
    updatedIngredients.removeAt(index);
    await performAllergenAnalysis(updatedIngredients);
  }

  Widget buildAllergenBadge() {
    final hasUserAllergenDetected = hasUserAllergen();

    return hasUserAllergenDetected
        ? Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.red[50],
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                spreadRadius: 1,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/emergency.png', width: 20, height: 20),
              SizedBox(width: 4),
              Text(
                'Contains Your Allergen',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ),
        )
        : Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                spreadRadius: 1,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/check.png', width: 20, height: 20),
              SizedBox(width: 4),
              Text(
                'Does Not Contain Your Allergen',
                style: TextStyle(color: Colors.green, fontSize: 12),
              ),
            ],
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Result'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context, true),
        ),
        actions: [
          if (!widget.isFromHistory)
            GestureDetector(
              onTap:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ScanHistoryScreen()),
                  ),
              child: Padding(
                padding: const EdgeInsets.only(right: 18.0),
                child: Image.asset(
                  'assets/images/history.png',
                  width: 35,
                  height: 35,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                if (widget.image != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      widget.image!,
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.photo, size: 40, color: Colors.grey),
                  ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.dishName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      buildAllergenBadge(),
                      SizedBox(height: 10),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => FirstAidScreen()),
                          );
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 6,
                                spreadRadius: 1,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/images/first_aid.png',
                                width: 20,
                                height: 20,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Learn about first aid',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          TabBar(
            controller: tabController,
            tabs: [Tab(text: 'Allergen'), Tab(text: 'Description')],
            labelColor: AppColors.textBlack,
            unselectedLabelColor: AppColors.textGray,
            indicatorColor: AppColors.primary,
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.tab,
          ),
          Expanded(
            child: TabBarView(
              controller: tabController,
              children: [
                AllergenTab(
                  currentAllergens: currentAllergens,
                  isUpdatingAllergens: isAnalyzing,
                  productName: widget.dishName,
                  isOCRAnalysis: widget.isOCRAnalysis,
                ),
                DescriptionTab(
                  description: widget.description,
                  currentIngredients: currentIngredients,
                  currentAllergens: currentAllergens,
                  isEditing: isEditing,
                  ingredientColors: currentIngredientColors,
                  toggleEdit: toggleEdit,
                  addIngredient: addIngredient,
                  removeIngredient: removeIngredient,
                  saveChanges: saveChanges,
                  onIngredientsChanged: performAllergenAnalysis,
                  isFromHistory: widget.isFromHistory,
                  historicalSeverityData: widget.historicalSeverityData,
                  ingredientBenefitsMap: widget.ingredientBenefitsMap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}