import 'package:allergen/screens/feature/ingredientmodal.dart';
import 'package:allergen/screens/feature/scan_screen.dart';
import 'package:flutter/material.dart';

class IngredientChip extends StatelessWidget {
  final String ingredient;
  final int index;
  final Color color;
  final bool isEditing;
  final List<AllergenInfo> allergens;
  final Function(int) onRemove;
  final bool isFromHistory;
  final Map<String, double>? historicalSeverityData;
  final List<IngredientColorInfo>? ingredientColors;

  const IngredientChip({
    Key? key,
    required this.ingredient,
    required this.index,
    required this.color,
    required this.isEditing,
    required this.allergens,
    required this.onRemove,
    this.isFromHistory = false,
    this.historicalSeverityData,
    this.ingredientColors,
  }) : super(key: key);

  List<String> getHistoricalMatchedAllergens() {
    if (ingredientColors == null || ingredientColors!.isEmpty) {
      return [];
    }

    String lowerIngredient = ingredient.toLowerCase().trim();

    for (IngredientColorInfo colorInfo in ingredientColors!) {
      String colorIngredient = colorInfo.ingredient.toLowerCase().trim();

      if (colorIngredient == lowerIngredient) {
        return List<String>.from(colorInfo.matchedAllergens);
      }
    }

    for (IngredientColorInfo colorInfo in ingredientColors!) {
      String colorIngredient = colorInfo.ingredient.toLowerCase().trim();

      if (colorIngredient.contains(lowerIngredient) ||
          lowerIngredient.contains(colorIngredient)) {
        return List<String>.from(colorInfo.matchedAllergens);
      }
    }

    return [];
  }

  double getHistoricalSeverity() {
    if (ingredientColors == null || ingredientColors!.isEmpty) {
      return 0.0;
    }

    String lowerIngredient = ingredient.toLowerCase().trim();

    for (IngredientColorInfo colorInfo in ingredientColors!) {
      if (colorInfo.ingredient.toLowerCase().trim() == lowerIngredient) {
        return colorInfo.severity;
      }
    }

    return 0.0;
  }

  Map<String, double> buildSeverityMapForIngredient() {
    if (!isFromHistory || historicalSeverityData == null) {
      return {};
    }

    List<String> matchedAllergens = getHistoricalMatchedAllergens();

    if (matchedAllergens.isEmpty) {
      return {};
    }

    Map<String, double> severityMap = {};

    for (String allergenName in matchedAllergens) {
      String lowerAllergen = allergenName.toLowerCase().trim();
      bool found = false;

      historicalSeverityData!.forEach((key, value) {
        String lowerKey = key.toLowerCase().trim();
        if (lowerKey == lowerAllergen) {
          severityMap[allergenName] = value;
          found = true;
        }
      });

      if (!found) {
        historicalSeverityData!.forEach((key, value) {
          String lowerKey = key.toLowerCase().trim();
          if (lowerKey.contains(lowerAllergen) ||
              lowerAllergen.contains(lowerKey)) {
            severityMap[allergenName] = value;
            found = true;
          }
        });
      }

      if (!found) {
        double ingredientSeverity = getHistoricalSeverity();
        if (ingredientSeverity > 0) {
          severityMap[allergenName] = ingredientSeverity;
        }
      }
    }

    return severityMap;
  }

  @override
  Widget build(BuildContext context) {
    bool isSafe = color == const Color(0xFFDFDFDF);

    return GestureDetector(
      onTap: () {
        List<String>? historicalMatched;
        Map<String, double>? severityToPass;

        if (isFromHistory && ingredientColors != null) {
          historicalMatched = getHistoricalMatchedAllergens();
          severityToPass = buildSeverityMapForIngredient();
        } else if (!isFromHistory) {
          if (ingredientColors != null) {
            historicalMatched = getHistoricalMatchedAllergens();
          }
        }

        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder:
              (_) => DraggableScrollableSheet(
                expand: false,
                builder:
                    (_, controller) => SingleChildScrollView(
                      controller: controller,
                      child: IngredientAllergenModal(
                        ingredientColor: color,
                        ingredient: ingredient,
                        availableAllergens: allergens,
                        isFromHistory: isFromHistory,
                        historicalSeverityData:
                            severityToPass ?? historicalSeverityData,
                        historicalMatchedAllergens: historicalMatched,
                      ),
                    ),
              ),
        );
      },
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: isSafe ? color.withOpacity(0.15) : color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSafe ? color.withOpacity(0.4) : color.withOpacity(0.8),
            width: isSafe ? 1.5 : 0,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isEditing ? 10 : 12,
            vertical: 8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  ingredient,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: isSafe ? Colors.black87 : Colors.white,
                    fontWeight: isSafe ? FontWeight.w500 : FontWeight.w600,
                  ),
                ),
              ),
              if (!isEditing) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: isSafe ? Colors.black54 : Colors.white70,
                ),
              ],
              if (isEditing) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => onRemove(index),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color:
                          isSafe
                              ? Colors.black.withOpacity(0.1)
                              : Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close,
                      size: 12,
                      color: isSafe ? Colors.black54 : Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
