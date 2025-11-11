import 'package:allergen/screens/feature/allergen_analysis.dart';
import 'package:allergen/services/translation/translation.dart';
import 'package:allergen/styleguide.dart';
import 'package:flutter/material.dart';
import 'package:allergen/screens/feature/scan_screen.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class IngredientAllergenModal extends StatefulWidget {
  final String ingredient;
  final Color ingredientColor;
  final List<AllergenInfo> availableAllergens;
  final bool isFromHistory;
  final Map<String, double>? historicalSeverityData;
  final List<String>? historicalMatchedAllergens;
  final String? ingredientBenefits;

  const IngredientAllergenModal({
    Key? key,
    required this.ingredient,
    required this.ingredientColor,
    required this.availableAllergens,
    this.isFromHistory = false,
    this.historicalSeverityData,
    this.historicalMatchedAllergens,
    this.ingredientBenefits,
  }) : super(key: key);

  @override
  State<IngredientAllergenModal> createState() =>
      _IngredientAllergenModalState();
}

class _IngredientAllergenModalState extends State<IngredientAllergenModal> {
  Map<String, double> displaySeverityData = {};
  bool isLoading = true;
  List<AllergenInfo> matchingAllergens = [];
  final AllergenAnalysis allergenAnalysis = AllergenAnalysis();
  final TranslationService translationService = TranslationService();

  @override
  void initState() {
    super.initState();
    if (widget.isFromHistory) {
      loadHistoricalData();
    } else {
      loadCurrentData();
    }
  }

  Future<void> loadHistoricalData() async {
    try {
      Map<String, double> historicalSeverity =
          widget.historicalSeverityData ?? {};
      List<AllergenInfo> historicalAllergens = [];

      if (widget.historicalMatchedAllergens != null &&
          widget.historicalMatchedAllergens!.isNotEmpty) {
        for (String allergenName in widget.historicalMatchedAllergens!) {
          AllergenInfo? foundAllergen;
          String lowerAllergenName = allergenName.toLowerCase().trim();

          for (AllergenInfo allergen in widget.availableAllergens) {
            String lowerAvailableName = allergen.name.toLowerCase().trim();

            if (lowerAvailableName == lowerAllergenName ||
                lowerAvailableName.contains(lowerAllergenName) ||
                lowerAllergenName.contains(lowerAvailableName)) {
              foundAllergen = allergen;
              break;
            }
          }

          if (foundAllergen == null) {
            double severity = 0.5;
            historicalSeverity.forEach((key, value) {
              if (key.toLowerCase().trim() == lowerAllergenName) {
                severity = value;
              }
            });

            String riskLevel;
            if (severity <= 0.3) {
              riskLevel = 'mild';
            } else if (severity <= 0.6) {
              riskLevel = 'moderate';
            } else {
              riskLevel = 'severe';
            }

            foundAllergen = AllergenInfo(
              name: allergenName,
              riskLevel: riskLevel,
              symptoms: ['Allergic reaction possible'],
              sources: [widget.ingredient],
              isUserAllergen: true,
            );
          }

          historicalAllergens.add(foundAllergen);
        }
      }

      setState(() {
        matchingAllergens = historicalAllergens;
        displaySeverityData = historicalSeverity;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading historical data: $e');
      setState(() {
        matchingAllergens = [];
        displaySeverityData = {};
        isLoading = false;
      });
    }
  }

  Future<void> loadCurrentData() async {
    try {
      Map<String, double> severityMap = {};

      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        QuerySnapshot profile =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('profile')
                .where('type', isEqualTo: 'allergen')
                .get();

        for (QueryDocumentSnapshot doc in profile.docs) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          String allergenName =
              data['name']?.toString().toLowerCase().trim() ?? '';
          double severity = (data['severity'] ?? 0.5).toDouble();

          if (allergenName.isNotEmpty) {
            String translatedName = await translationService.translateToEnglish(
              allergenName,
            );
            print(translatedName);

            severityMap[translatedName] = severity;

            if (translatedName != allergenName) {
              severityMap[allergenName] = severity;
            }
          }
        }
      }

      setState(() {
        displaySeverityData = severityMap;
      });

      if (widget.historicalMatchedAllergens != null &&
          widget.historicalMatchedAllergens!.isNotEmpty) {
        await findAllergensFromMatchedList();
      } else {
        await findMatchingAllergensFromIngredient();
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('Error loading current data: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> findAllergensFromMatchedList() async {
    List<AllergenInfo> matchedAllergens = [];

    for (String allergenName in widget.historicalMatchedAllergens!) {
      String lowerAllergenName = allergenName.toLowerCase().trim();

      AllergenInfo? foundAllergen;
      for (AllergenInfo allergen in widget.availableAllergens) {
        String lowerAvailableName = allergen.name.toLowerCase().trim();

        if (lowerAvailableName == lowerAllergenName ||
            isAllergenMatch(lowerAllergenName, [lowerAvailableName]) ||
            isAllergenMatch(lowerAvailableName, [lowerAllergenName])) {
          foundAllergen = allergen;
          break;
        }
      }

      if (foundAllergen == null) {
        String? matchedUserAllergen = await allergenAnalysis
            .findMatchingUserAllergen(
              lowerAllergenName,
              displaySeverityData.keys.toList(),
            );

        double severity =
            matchedUserAllergen != null
                ? displaySeverityData[matchedUserAllergen]!
                : 0.5;

        String riskLevel =
            severity >= 0.67
                ? 'severe'
                : severity >= 0.33
                ? 'moderate'
                : 'mild';

        foundAllergen = AllergenInfo(
          name: allergenName,
          riskLevel: riskLevel,
          symptoms: ['Allergic reaction possible'],
          sources: [widget.ingredient],
          isUserAllergen: matchedUserAllergen != null,
        );
      }

      matchedAllergens.add(foundAllergen);

      if (!displaySeverityData.containsKey(lowerAllergenName)) {
        String? matchedUserAllergen = await allergenAnalysis
            .findMatchingUserAllergen(
              lowerAllergenName,
              displaySeverityData.keys.toList(),
            );

        if (matchedUserAllergen != null) {
          displaySeverityData[lowerAllergenName] =
              displaySeverityData[matchedUserAllergen]!;
        } else {
          displaySeverityData[lowerAllergenName] = 0.5;
        }
      }
    }

    setState(() {
      matchingAllergens = matchedAllergens;
    });
  }

  Future<void> findMatchingAllergensFromIngredient() async {
    String lowerIngredient = widget.ingredient.toLowerCase().trim();
    String translatedIngredient = await translationService.translateToEnglish(
      lowerIngredient,
    );

    Map<String, String> translatedUserAllergens = {};
    for (String userAllergen in displaySeverityData.keys) {
      String translated = await translationService.translateToEnglish(
        userAllergen.toLowerCase().trim(),
      );
      translatedUserAllergens[userAllergen] = translated;
    }

    List<AllergenInfo> matchedAllergens = [];

    for (AllergenInfo allergenInfo in widget.availableAllergens) {
      String allergenNameLower = allergenInfo.name.toLowerCase().trim();

      bool isSourceMatch = allergenInfo.sources.any((source) {
        String lowerSource = source.toLowerCase().trim();
        return allergenAnalysis.isIngredientMatch(
              lowerIngredient,
              lowerSource,
            ) ||
            allergenAnalysis.isIngredientMatch(
              translatedIngredient,
              lowerSource,
            );
      });

      if (!isSourceMatch) {
        isSourceMatch =
            allergenAnalysis.isIngredientMatch(
              lowerIngredient,
              allergenNameLower,
            ) ||
            allergenAnalysis.isIngredientMatch(
              translatedIngredient,
              allergenNameLower,
            );
      }

      if (isSourceMatch) {
        String? matchedUserAllergen;

        for (var entry in translatedUserAllergens.entries) {
          String userAllergen = entry.key.toLowerCase().trim();
          String translatedUserAllergen = entry.value.toLowerCase().trim();

          if (allergenNameLower == translatedUserAllergen ||
              isAllergenMatch(allergenNameLower, [translatedUserAllergen]) ||
              isAllergenMatch(translatedUserAllergen, [allergenNameLower])) {
            matchedUserAllergen = entry.key;
            break;
          }
        }

        if (matchedUserAllergen == null) {
          matchedUserAllergen = await allergenAnalysis.findMatchingUserAllergen(
            allergenNameLower,
            displaySeverityData.keys.toList(),
          );
        }

        if (matchedUserAllergen != null) {
          matchedAllergens.add(allergenInfo);
        }
      }
    }

    setState(() {
      matchingAllergens = matchedAllergens;
    });
  }

  bool isAllergenMatch(
    String detectedAllergen,
    List<String> userAllergensList,
  ) {
    String cleanDetected = detectedAllergen.toLowerCase().trim();

    for (String userAllergen in userAllergensList) {
      String cleanUser = userAllergen.toLowerCase().trim();

      if (cleanUser == cleanDetected) return true;

      bool userIsPeanut = cleanUser.contains('peanut');
      bool detectedIsPeanut = cleanDetected.contains('peanut');

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

      if (userIsGenericNut && detectedIsPeanut) continue;
      if (userIsPeanut &&
          (cleanDetected == 'nut' ||
              cleanDetected == 'nuts' ||
              cleanDetected == 'tree nut' ||
              cleanDetected == 'tree nuts')) {
        continue;
      }

      if (userIsPeanut && detectedIsPeanut) return true;

      if ((userIsPeanut && detectedIsSpecificTreeNut) ||
          (userIsSpecificTreeNut && detectedIsPeanut)) {
        continue;
      }

      if (userIsGenericNut && detectedIsSpecificTreeNut) return true;
    }

    return false;
  }

  Future<List<Widget>> buildAllergenWidgets() async {
    List<Widget> widgets = [];

    for (AllergenInfo allergen in matchingAllergens) {
      String? matchedAllergenKey = await allergenAnalysis
          .findMatchingUserAllergen(
            allergen.name.toLowerCase().trim(),
            displaySeverityData.keys.toList(),
          );

      String displayName = allergen.name;
      if (matchedAllergenKey != null) {
        displayName = matchedAllergenKey;
      }

      widgets.add(
        Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(child: getAllergenIcon(allergen.name)),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 70,
              child: Text(
                displayName,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    return widgets;
  }

  Widget getAllergenIcon(String allergenName) {
    IconData iconData;
    final String name = allergenName.toLowerCase().trim();

    switch (name) {
      case 'milk':
      case 'dairy':
        iconData = FontAwesomeIcons.glassWater;
        break;
      case 'cashew':
      case 'nuts':
      case 'nut':
      case 'tree nuts':
        iconData = FontAwesomeIcons.seedling;
        break;
      case 'egg':
      case 'eggs':
        iconData = FontAwesomeIcons.egg;
        break;
      case 'fish':
        iconData = FontAwesomeIcons.fish;
        break;
      case 'wheat':
      case 'gluten':
        iconData = FontAwesomeIcons.wheatAwn;
        break;
      case 'soy':
      case 'soybean':
      case 'soya':
        iconData = FontAwesomeIcons.leaf;
        break;
      case 'shellfish':
      case 'seafood':
      case 'crustacean':
      case 'shrimp':
      case 'crab':
      case 'oysters':
      case 'clams':
      case 'mussels':
      case 'squid':
        iconData = FontAwesomeIcons.shrimp;
        break;
      case 'peanut':
      case 'peanuts':
        iconData = FontAwesomeIcons.circleNodes;
        break;
      case 'sesame':
        iconData = FontAwesomeIcons.pepperHot;
        break;
      case 'lupin':
        iconData = FontAwesomeIcons.spa;
        break;
      default:
        iconData = FontAwesomeIcons.triangleExclamation;
        break;
    }

    return FaIcon(iconData, color: AppColors.primary, size: 30);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.isFromHistory
                        ? 'Historical Ingredient Analysis'
                        : 'Ingredient Analysis',
                    style: const TextStyle(
                      fontSize: 18,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              )
            else ...[
              Text(
                widget.ingredient,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.isFromHistory ? Icons.history : Icons.psychology,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'AI Analysis',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              if (widget.ingredientBenefits != null &&
                  widget.ingredientBenefits!.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade50, Colors.blue.shade50],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.local_hospital_rounded,
                            color: Colors.green.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Health Information',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.green.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.ingredientBenefits!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade800,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.grey.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.isFromHistory
                              ? 'No health information was recorded for this ingredient during the original scan.'
                              : 'No health information available for this ingredient.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),
              if (matchingAllergens.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.isFromHistory
                            ? 'No allergens detected at scan time'
                            : 'No allergens detected',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.red.shade700),
                  ),
                  child: Text(
                    'Contains ${matchingAllergens.length} of your allergens',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              if (matchingAllergens.isNotEmpty) ...[
                FutureBuilder<List<Widget>>(
                  future: buildAllergenWidgets(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('Error loading allergens'));
                    }

                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: snapshot.data ?? [],
                    );
                  },
                ),
              ],
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
