import 'package:allergen/screens/feature/profile_details.dart';
import 'package:allergen/styleguide.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class OnboardingScreen extends StatefulWidget {
  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  String username = '';
  Set<String> selectedAllergens = {};
  Map<String, double> allergenSeverity = {};
  TextEditingController searchController = TextEditingController();
  List<String> filteredAllergens = [];
  List<String> fdaIngredients = [];
  bool isSearchingFDA = false;
  List<String> savedAllergens = [];

  final List<String> commonAllergens = [
    'Shellfish',
    'Sesame',
    'Egg',
    'Peanut',
    'Fish',
    'Milk',
    'Soybean',
    'Nuts',
    'Wheat',
  ];

  final List<String> fdaMajorAllergens = [
    'Milk',
    'Eggs',
    'Fish',
    'Shellfish',
    'Tree nuts',
    'Peanuts',
    'Wheat',
    'Soy',
    'Sesame',
  ];

  @override
  void initState() {
    super.initState();
    filteredAllergens = List.from(commonAllergens);
    fetchUsername();
    loadExistingAllergens();
  }

  List<String> getAllAllergens() {
    Set<String> allAllergens = {};
    allAllergens.addAll(commonAllergens);
    allAllergens.addAll(savedAllergens);
    return allAllergens.toList();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void clearSearch() {
    searchController.clear();
    setState(() {
      updateFilteredAllergens();
      isSearchingFDA = false;
    });
  }

  void onSearchChanged(String searchTerm) {
    if (searchTerm.isEmpty) {
      setState(() {
        updateFilteredAllergens();
        isSearchingFDA = false;
      });
    } else if (searchTerm.length >= 2) {
      searchFDAIngredients(searchTerm);
    } else {
      setState(() {
        List<String> filtered = [];
        for (String allergen in commonAllergens) {
          if (allergen.toLowerCase().contains(searchTerm.toLowerCase())) {
            filtered.add(allergen);
          }
        }
        filteredAllergens = filtered;
        isSearchingFDA = false;
      });
    }
  }

  void updateFilteredAllergens() {
    filteredAllergens = getAllAllergens();
  }

  Future<void> searchFDAIngredients(String searchTerm) async {
    setState(() {
      isSearchingFDA = true;
    });

    try {
      List<String> searchFields = [
        'active_ingredient',
        'inactive_ingredient',
        'substance_name',
        'openfda.substance_name',
        'openfda.generic_name',
      ];

      Set<String> foundIngredients = {};

      for (String field in searchFields) {
        try {
          final response = await http.get(
            Uri.parse(
              'https://api.fda.gov/drug/label.json?search=$field:"$searchTerm"&limit=50',
            ),
          );

          if (response.statusCode == 200) {
            final data = json.decode(response.body);

            if (data['results'] != null) {
              for (var result in data['results']) {
                extractIngredientsFromResult(
                  result,
                  searchTerm,
                  foundIngredients,
                );
              }
            }
          }
        } catch (e) {
          print('Error searching $field: $e');
          continue;
        }
      }

      try {
        final broadResponse = await http.get(
          Uri.parse(
            'https://api.fda.gov/drug/label.json?search=active_ingredient:*$searchTerm*+OR+inactive_ingredient:*$searchTerm*&limit=30',
          ),
        );

        if (broadResponse.statusCode == 200) {
          final broadData = json.decode(broadResponse.body);
          if (broadData['results'] != null) {
            for (var result in broadData['results']) {
              extractIngredientsFromResult(
                result,
                searchTerm,
                foundIngredients,
              );
            }
          }
        }
      } catch (e) {
        print('Error in broad search: $e');
      }

      for (String allergen in fdaMajorAllergens) {
        if (allergen.toLowerCase().contains(searchTerm.toLowerCase())) {
          foundIngredients.add(allergen);
        }
      }

      setState(() {
        fdaIngredients = foundIngredients.toList();

        Set<String> combinedAllergens = {};

        for (String allergen in commonAllergens) {
          if (allergen.toLowerCase().contains(searchTerm.toLowerCase())) {
            combinedAllergens.add(allergen);
          }
        }

        combinedAllergens.addAll(fdaIngredients);

        filteredAllergens = combinedAllergens.toList();
        isSearchingFDA = false;
      });
    } catch (e) {
      print('Error searching FDA: $e');
      setState(() {
        List<String> filtered = [];
        for (String allergen in commonAllergens) {
          if (allergen.toLowerCase().contains(searchTerm.toLowerCase())) {
            filtered.add(allergen);
          }
        }
        filteredAllergens = filtered;
        isSearchingFDA = false;
      });
    }
  }

  void extractIngredientsFromResult(
    Map<String, dynamic> result,
    String searchTerm,
    Set<String> foundIngredients,
  ) {
    if (result['active_ingredient'] != null) {
      for (var ingredient in result['active_ingredient']) {
        String ingredientName = '';
        if (ingredient is String) {
          ingredientName = ingredient;
        } else if (ingredient is Map && ingredient['name'] != null) {
          ingredientName = ingredient['name'].toString();
        }

        if (ingredientName.isNotEmpty) {
          List<String> extracted = extractPotentialAllergens(
            ingredientName,
            searchTerm,
          );
          foundIngredients.addAll(extracted);
        }
      }
    }

    if (result['inactive_ingredient'] != null) {
      for (var ingredient in result['inactive_ingredient']) {
        String ingredientName = ingredient.toString();
        if (ingredientName.isNotEmpty) {
          List<String> extracted = extractPotentialAllergens(
            ingredientName,
            searchTerm,
          );
          foundIngredients.addAll(extracted);
        }
      }
    }

    if (result['openfda'] != null) {
      var openfda = result['openfda'];

      if (openfda['substance_name'] != null) {
        for (var substance in openfda['substance_name']) {
          List<String> extracted = extractPotentialAllergens(
            substance.toString(),
            searchTerm,
          );
          foundIngredients.addAll(extracted);
        }
      }

      if (openfda['generic_name'] != null) {
        for (var name in openfda['generic_name']) {
          List<String> extracted = extractPotentialAllergens(
            name.toString(),
            searchTerm,
          );
          foundIngredients.addAll(extracted);
        }
      }
    }
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

    List<String> words = cleaned.split(' ');
    List<String> capitalizedWords = [];
    for (String word in words) {
      if (word.isNotEmpty) {
        String capitalized =
            word[0].toUpperCase() + word.substring(1).toLowerCase();
        capitalizedWords.add(capitalized);
      }
    }
    return capitalizedWords.join(' ');
  }

  Future<void> fetchUsername() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();

        if (userDoc.exists) {
          setState(() {
            username = userDoc['username'] ?? 'User';
          });
        }
      }
    } catch (e) {
      print('Error fetching username: $e');
      setState(() {
        username = 'User';
      });
    }
  }

  Future<void> loadExistingAllergens() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        QuerySnapshot profileSnapshot =
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

          for (QueryDocumentSnapshot doc in profileSnapshot.docs) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            String allergenName = data['name'] ?? '';
            double severity = (data['severity'] ?? 0.5).toDouble();

            if (allergenName.isNotEmpty) {
              selectedAllergens.add(allergenName);
              allergenSeverity[allergenName] = severity;
              savedAllergens.add(allergenName);
            }
          }
          updateFilteredAllergens();
        });
      }
    } catch (e) {
      print('Error loading existing allergens: $e');
    }
  }

  Future<void> deleteAllergen(String allergen) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        QuerySnapshot docs =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('profile')
                .where('type', isEqualTo: 'allergen')
                .where('name', isEqualTo: allergen)
                .get();

        for (QueryDocumentSnapshot doc in docs.docs) {
          await doc.reference.delete();
        }

        setState(() {
          selectedAllergens.remove(allergen);
          allergenSeverity.remove(allergen);
          savedAllergens.remove(allergen);
          updateFilteredAllergens();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting allergen: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void toggleAllergen(String allergen) {
    setState(() {
      if (selectedAllergens.contains(allergen)) {
        selectedAllergens.remove(allergen);
        allergenSeverity.remove(allergen);
      } else {
        selectedAllergens.add(allergen);
        allergenSeverity[allergen] = 0.5;
      }
    });
  }

  Color getSeverityColor(double severity) {
    if (severity < 0.33) return Colors.green.shade300;
    if (severity < 0.67) return Colors.orange.shade300;
    return Colors.red.shade300;
  }

  void showAllergenModal(String allergen, {bool isManualAdd = false}) {
    double currentSeverity = allergenSeverity[allergen] ?? 0.5;
    TextEditingController manualAllergenController = TextEditingController();
    if (isManualAdd) manualAllergenController.text = allergen;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
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
                      if (isManualAdd)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Manually add your allergen',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 16),
                            TextField(
                              controller: manualAllergenController,
                              decoration: InputDecoration(
                                hintText: 'Enter allergen name',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Text(
                              allergen,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Spacer(),
                            if (selectedAllergens.contains(allergen))
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  Navigator.pop(context);
                                  deleteAllergen(allergen);
                                },
                              ),
                          ],
                        ),
                      SizedBox(height: 24),
                      Text(
                        'How severe is this allergen reaction?',
                        style: TextStyle(fontSize: 16),
                      ),
                      SizedBox(height: 24),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 8,
                          activeTrackColor: getSliderColor(currentSeverity),
                          thumbColor: getSliderColor(currentSeverity),
                        ),
                        child: Slider(
                          value: currentSeverity,
                          onChanged:
                              (value) =>
                                  setModalState(() => currentSeverity = value),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Mild',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          Text(
                            'Moderate',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          Text(
                            'Severe',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                      SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            String finalAllergen =
                                isManualAdd
                                    ? manualAllergenController.text.trim()
                                    : allergen;
                            if (finalAllergen.isNotEmpty) {
                              setState(() {
                                selectedAllergens.add(finalAllergen);
                                allergenSeverity[finalAllergen] =
                                    currentSeverity;
                                if (!savedAllergens.contains(finalAllergen)) {
                                  savedAllergens.add(finalAllergen);
                                }
                                updateFilteredAllergens();
                              });
                            }
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF0891B2),
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            isManualAdd ? 'Save Allergen' : 'Save Selection',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
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

  Color getSliderColor(double value) {
    if (value < 0.33) return Colors.green;
    if (value < 0.67) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: EdgeInsets.fromLTRB(24, 60, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome ${username.isNotEmpty ? username : 'User'}!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Search for allergens and drug ingredients',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: searchController,
                onChanged: onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search ingredients...',
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  prefixIcon:
                      isSearchingFDA
                          ? Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF0891B2),
                                ),
                              ),
                            ),
                          )
                          : Icon(Icons.search, color: Colors.grey.shade500),
                  suffixIcon:
                      searchController.text.isNotEmpty
                          ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              color: Colors.grey.shade500,
                            ),
                            onPressed: clearSearch,
                            tooltip: 'Clear search',
                          )
                          : null,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: buildAllergenChips(),
                ),
              ),
            ),
            SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => showAllergenModal('', isManualAdd: true),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.primary),
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Add manually',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        User? user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          WriteBatch batch = FirebaseFirestore.instance.batch();
                          CollectionReference profileRef = FirebaseFirestore
                              .instance
                              .collection('users')
                              .doc(user.uid)
                              .collection('profile');

                          QuerySnapshot existingAllergens =
                              await profileRef
                                  .where('type', isEqualTo: 'allergen')
                                  .get();
                          for (QueryDocumentSnapshot doc
                              in existingAllergens.docs) {
                            batch.delete(doc.reference);
                          }

                          for (String allergen in selectedAllergens) {
                            DocumentReference allergenDoc = profileRef.doc();
                            batch.set(allergenDoc, {
                              'name': allergen,
                              'severity': allergenSeverity[allergen] ?? 0.5,
                              'createdAt': FieldValue.serverTimestamp(),
                              'type': 'allergen',
                              'source':
                                  fdaIngredients.contains(allergen)
                                      ? 'FDA_DRUG'
                                      : 'manual',
                            });
                          }

                          await batch.commit();

                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => ProfileDetailsScreen(),
                            ),
                          );

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Allergens saved successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error saving allergens: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> buildAllergenChips() {
    List<Widget> chips = [];
    for (String allergen in filteredAllergens) {
      bool isSelected = selectedAllergens.contains(allergen);
      bool isFromFDA = fdaIngredients.contains(allergen);
      bool isSaved = savedAllergens.contains(allergen);
      Color chipColor =
          isSelected
              ? getSeverityColor(allergenSeverity[allergen] ?? 0.5)
              : Colors.grey.shade200;

      chips.add(
        GestureDetector(
          onTap: () {
            if (isSelected) {
              showAllergenModal(allergen);
            } else {
              toggleAllergen(allergen);
              showAllergenModal(allergen);
            }
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: chipColor,
              borderRadius: BorderRadius.circular(20),
              border:
                  isSelected
                      ? Border.all(color: Colors.green, width: 2)
                      : isFromFDA
                      ? Border.all(color: Color(0xFF0891B2), width: 1)
                      : isSaved
                      ? Border.all(color: Colors.purple, width: 1)
                      : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: buildChipContent(
                isSelected,
                isFromFDA,
                isSaved,
                allergen,
              ),
            ),
          ),
        ),
      );
    }
    return chips;
  }

  List<Widget> buildChipContent(
    bool isSelected,
    bool isFromFDA,
    bool isSaved,
    String allergen,
  ) {
    List<Widget> content = [];

    if (isSelected) {
      content.add(Icon(Icons.check_circle, size: 16, color: Colors.green));
      content.add(SizedBox(width: 8));
    }

    if (isFromFDA && !isSelected) {
      content.add(Icon(Icons.medication, size: 14, color: Color(0xFF0891B2)));
      content.add(SizedBox(width: 6));
    }

    if (isSaved && !isSelected && !isFromFDA) {
      content.add(Icon(Icons.bookmark, size: 14, color: Colors.purple));
      content.add(SizedBox(width: 6));
    }

    content.add(
      Flexible(
        child: Text(
          allergen,
          style: TextStyle(
            color: Colors.black87,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );

    return content;
  }
}
