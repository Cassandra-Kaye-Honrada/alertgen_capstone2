import 'package:flutter/material.dart';
import 'package:allergen/screens/feature/scan_screen.dart';
import 'ingredient_chip.dart';

class IngredientChipsList extends StatelessWidget {
  final List<String> ingredients;
  final List<AllergenInfo> allergens;
  final bool isEditing;
  final Color Function(String) getColor;
  final Function(int) onRemove;
  final VoidCallback onAdd;
  final bool isFromHistory;
  final Map<String, double>? historicalSeverityData;
  final List<IngredientColorInfo>? ingredientColors;
    final IngredientBenefitsMap? ingredientBenefitsMap;

  const IngredientChipsList({
    Key? key,
    required this.ingredients,
    required this.allergens,
    required this.isEditing,
    required this.getColor,
    required this.onRemove,
    required this.onAdd,
    this.isFromHistory = false,
    this.historicalSeverityData,
    this.ingredientColors,
      this.ingredientBenefitsMap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...ingredients.asMap().entries.map((entry) {
          int index = entry.key;
          String ingredient = entry.value;
          return IngredientChip(
            ingredient: ingredient,
            index: index,
            color: getColor(ingredient),
            isEditing: isEditing,
            allergens: allergens,
            onRemove: onRemove,
            isFromHistory: isFromHistory,
            historicalSeverityData: historicalSeverityData,
            ingredientColors: ingredientColors,
            ingredientBenefitsMap: ingredientBenefitsMap, 
          );
        }).toList(),
        if (isEditing && !isFromHistory)
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue[300]!, width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 16, color: Colors.blue[700]),
                  const SizedBox(width: 4),
                  Text(
                    'Add',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}