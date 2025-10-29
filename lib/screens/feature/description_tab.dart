import 'dart:async';
import 'package:allergen/screens/feature/ingredient_chip_list.dart';
import 'package:allergen/screens/feature/scan_screen.dart';
import 'package:allergen/services/translation/translation.dart';
import 'package:flutter/material.dart';
import 'package:allergen/styleguide.dart';

class DescriptionTab extends StatefulWidget {
  final String description;
  final List<String> currentIngredients;
  final List<AllergenInfo> currentAllergens;
  final List<IngredientColorInfo> ingredientColors;
  final bool isEditing;
  final VoidCallback toggleEdit;
  final VoidCallback addIngredient;
  final Function(int) removeIngredient;
  final VoidCallback saveChanges;
  final Function(List<String>) onIngredientsChanged;
  final bool isFromHistory;
  final Map<String, double>? historicalSeverityData;
  final IngredientBenefitsMap? ingredientBenefitsMap;

  const DescriptionTab({
    Key? key,
    required this.description,
    required this.currentIngredients,
    required this.currentAllergens,
    required this.ingredientColors,
    required this.isEditing,
    required this.toggleEdit,
    required this.addIngredient,
    required this.removeIngredient,
    required this.saveChanges,
    required this.onIngredientsChanged,
    this.isFromHistory = false,
    this.historicalSeverityData,
    this.ingredientBenefitsMap,
  }) : super(key: key);

  @override
  _DescriptionTabState createState() => _DescriptionTabState();
}

class _DescriptionTabState extends State<DescriptionTab>
    with AutomaticKeepAliveClientMixin {
  bool isReanalyzing = false;
  StreamSubscription? allergenSubscription;
  Timer? debounce;

  Map<String, Color> ingredientColorMap = {};
  String? lastColor;

  List<String> editableIngredients = [];
  final TranslationService translationService = TranslationService();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    editableIngredients = List.from(widget.currentIngredients);
    updateIngredientColorMap();

    print('🔍 DescriptionTab initState:');
    if (widget.ingredientBenefitsMap != null) {
      print('  - Benefits map is NOT null');
      print(
        '  - Contains ${widget.ingredientBenefitsMap!.benefitsMap.length} benefits',
      );
      print(
        '  - Keys: ${widget.ingredientBenefitsMap!.benefitsMap.keys.toList()}',
      );
    } else {
      print('  - Benefits map is NULL');
    }
  }

  void updateIngredientColorMap() {
    final currentColor = widget.ingredientColors
        .map((c) => '${c.ingredient}:${c.color.value}')
        .join('|');

    if (lastColor != currentColor) {
      ingredientColorMap.clear();
      for (var colorInfo in widget.ingredientColors) {
        ingredientColorMap[colorInfo.ingredient.toLowerCase().trim()] =
            colorInfo.color;
      }
      lastColor = currentColor;
    }
  }

  @override
  void didUpdateWidget(DescriptionTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.currentIngredients != widget.currentIngredients) {
      editableIngredients = List.from(widget.currentIngredients);
    }

    updateIngredientColorMap();
  }

  @override
  void dispose() {
    allergenSubscription?.cancel();
    debounce?.cancel();
    super.dispose();
  }

  Color getIngredientColor(String ingredient) {
    return ingredientColorMap[ingredient.toLowerCase().trim()] ??
        const Color(0xFFDFDFDF);
  }

  void addIngredientToChip(String ingredient) {
    if (ingredient.trim().isNotEmpty &&
        !editableIngredients.contains(ingredient.trim())) {
      setState(() {
        editableIngredients.add(ingredient.trim());
      });
    }
  }

  void removeIngredientFromChip(int index) {
    if (index >= 0 && index < editableIngredients.length) {
      setState(() {
        editableIngredients.removeAt(index);
      });
    }
  }

  void customAddIngredient() {
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
                addIngredientToChip(ingredientController.text.trim());
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
                  addIngredientToChip(ingredientController.text.trim());
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

  Future<void> customSaveChanges() async {
    if (widget.isFromHistory) {
      return;
    }

    setState(() {
      isReanalyzing = true;
    });

    try {
      await widget.onIngredientsChanged(editableIngredients);
      widget.saveChanges();
    } finally {
      if (mounted) {
        setState(() {
          isReanalyzing = false;
        });
      }
    }
  }

  Widget buildColorLegendItem(Color color, String label) {
    return Column(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget buildLoadingIndicator() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            Text(
              'Analyzing ingredients...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            widget.description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Ingredients Analysis',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (!isReanalyzing && !widget.isFromHistory)
                IconButton(
                  onPressed: widget.toggleEdit,
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                          widget.isEditing
                              ? Colors.red[50]
                              : AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      widget.isEditing ? Icons.close : Icons.edit,
                      color: widget.isEditing ? Colors.red : AppColors.primary,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Allergen Risk Colors:',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    buildColorLegendItem(
                      const Color.fromARGB(255, 242, 242, 242),
                      'Safe',
                    ),
                    buildColorLegendItem(Colors.green, 'Mild Risk'),
                    buildColorLegendItem(Colors.orange, 'Moderate Risk'),
                    buildColorLegendItem(Colors.red, 'Severe Risk'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          isReanalyzing && !widget.isFromHistory
              ? buildLoadingIndicator()
              : Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 4,
                      spreadRadius: 1,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detected Ingredients (${editableIngredients.length}):',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: AppColors.textBlack,
                      ),
                    ),
                    const SizedBox(height: 12),
                    IngredientChipsList(
                      ingredients: editableIngredients,
                      allergens: widget.currentAllergens,
                      isEditing: widget.isEditing,
                      getColor: getIngredientColor,
                      onRemove: removeIngredientFromChip,
                      onAdd: customAddIngredient,
                      isFromHistory: widget.isFromHistory,
                      historicalSeverityData: widget.historicalSeverityData,
                      ingredientColors: widget.ingredientColors,
                      ingredientBenefitsMap: widget.ingredientBenefitsMap,
                    ),
                  ],
                ),
              ),
          if (widget.isEditing && !isReanalyzing && !widget.isFromHistory)
            Column(
              children: [
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: customSaveChanges,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: const Text(
                            'Save Changes',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              editableIngredients = List.from(
                                widget.currentIngredients,
                              );
                            });
                            widget.toggleEdit();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[100],
                            foregroundColor: Colors.grey[700],
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                            side: BorderSide(color: Colors.grey[300]!),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
