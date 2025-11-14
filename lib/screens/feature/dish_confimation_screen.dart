import 'dart:ui';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

// Image Cache Service for Dishes
class DishImageCacheService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'dish_image_cache';

  /// Fetch images for a dish - first checks Firebase cache, then Google API
  static Future<List<String>> fetchDishImages(
    String dishName, {
    int maxResults = 3,
  }) async {
    try {
      final normalizedName = dishName.trim().toLowerCase();

      // Check Firebase cache first
      final cachedImages = await _getFromCache(normalizedName);
      if (cachedImages != null && cachedImages.isNotEmpty) {
        print('✓ Found cached images for: $dishName');
        return cachedImages;
      }

      // Fetch from Google API
      print('× No cache found. Fetching from Google API: $dishName');
      final fetchedImages = await _fetchFromGoogleAPI(
        dishName,
        maxResults: maxResults,
      );

      // Save to Firebase cache
      if (fetchedImages.isNotEmpty) {
        await _saveToCache(normalizedName, fetchedImages);
        print('✓ Saved ${fetchedImages.length} images to cache');
      }

      return fetchedImages;
    } catch (e) {
      print('Error in fetchDishImages: $e');
      return [];
    }
  }

  static Future<List<String>?> _getFromCache(String normalizedName) async {
    try {
      final docSnapshot =
          await _firestore
              .collection(_collectionName)
              .doc(normalizedName)
              .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        if (data != null && data['imageUrls'] != null) {
          final List<dynamic> urls = data['imageUrls'];
          return urls.map((url) => url.toString()).toList();
        }
      }
      return null;
    } catch (e) {
      print('Error getting from cache: $e');
      return null;
    }
  }

  static Future<void> _saveToCache(
    String normalizedName,
    List<String> imageUrls,
  ) async {
    try {
      await _firestore.collection(_collectionName).doc(normalizedName).set({
        'dishName': normalizedName,
        'imageUrls': imageUrls,
        'cachedAt': FieldValue.serverTimestamp(),
        'lastAccessed': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving to cache: $e');
    }
  }

  static Future<List<String>> _fetchFromGoogleAPI(
    String dishName, {
    int maxResults = 3,
  }) async {
    try {
      final apiKey = dotenv.env['GOOGLE_API_KEY'] ?? '';
      final searchEngineId = dotenv.env['GOOGLE_CSE_ID'] ?? 'd2c0d6b5a5ac44bc4';

      if (apiKey.isEmpty) {
        print('Google API Key is missing. Please add GOOGLE_API_KEY to .env');
        return [];
      }

      final query = Uri.encodeComponent('$dishName food dish meal');

      final url = Uri.parse(
        'https://www.googleapis.com/customsearch/v1?'
        'key=$apiKey&'
        'cx=$searchEngineId&'
        'q=$query&'
        'searchType=image&'
        'num=$maxResults&'
        'safe=active&'
        'imgSize=medium&'
        'imgType=photo',
      );

      final response = await http
          .get(url)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Request timeout'),
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<String> imageUrls = [];

        if (data['items'] != null) {
          for (var item in data['items']) {
            if (item['link'] != null) {
              imageUrls.add(item['link']);
            }
          }
        }

        return imageUrls;
      } else {
        print('Google API Error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Exception fetching from Google API: $e');
      return [];
    }
  }

  static String getPlaceholderImage(String dishName) {
    return 'https://via.placeholder.com/400x200/FFE0B2/F57C00?text=${Uri.encodeComponent(dishName)}';
  }
}

class DishOption {
  final String dishName;
  final String description;
  final List<String> ingredients;
  final List<IngredientWithBenefits> ingredientsWithBenefits;
  final double confidence;
  List<String>? imageUrls;

  DishOption({
    required this.dishName,
    required this.description,
    required this.ingredients,
    List<IngredientWithBenefits>? ingredientsWithBenefits,
    this.confidence = 1.0,
    this.imageUrls,
  }) : ingredientsWithBenefits = ingredientsWithBenefits ?? [];

  factory DishOption.fromJson(Map<String, dynamic> json) {
    List<IngredientWithBenefits> ingredientsWithBenefits = [];

    if (json['ingredients'] is List) {
      for (var item in json['ingredients']) {
        if (item is Map<String, dynamic>) {
          ingredientsWithBenefits.add(
            IngredientWithBenefits(
              name: item['name']?.toString().trim() ?? '',
              benefits: item['benefits']?.toString() ?? '',
            ),
          );
        }
      }
    }

    return DishOption(
      dishName: json['dishName'] ?? '',
      description: json['description'] ?? '',
      ingredients: ingredientsWithBenefits.map((e) => e.name).toList(),
      ingredientsWithBenefits: ingredientsWithBenefits,
      confidence: (json['confidence'] ?? 1.0).toDouble(),
      imageUrls:
          json['imageUrls'] != null
              ? List<String>.from(json['imageUrls'])
              : null,
    );
  }
}

class IngredientWithBenefits {
  final String name;
  final String benefits;

  IngredientWithBenefits({required this.name, required this.benefits});
}

class DishSelectionScreen extends StatefulWidget {
  final List<DishOption> options;
  final Function(DishOption) onOptionSelected;
  final VoidCallback onManualEntry;

  const DishSelectionScreen({
    Key? key,
    required this.options,
    required this.onOptionSelected,
    required this.onManualEntry,
  }) : super(key: key);

  @override
  State<DishSelectionScreen> createState() => _DishSelectionScreenState();
}

class _DishSelectionScreenState extends State<DishSelectionScreen>
    with TickerProviderStateMixin {
  int? selectedIndex;
  final Map<int, List<String>> imageCache = {};
  final Map<int, bool> loadingImages = {};
  final Map<int, int> currentImageIndex = {};
  final Map<int, PageController> pageControllers = {};
  late AnimationController pulseController;

  @override
  void initState() {
    super.initState();
    loadImages();
    pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    pulseController.dispose();
    for (var controller in pageControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> loadImages() async {
    final validOptions =
        widget.options.where((option) {
          return option.ingredients.isNotEmpty &&
              option.ingredients.length >= 2;
        }).toList();

    for (int i = 0; i < validOptions.length; i++) {
      pageControllers[i] = PageController();

      if (validOptions[i].imageUrls != null &&
          validOptions[i].imageUrls!.isNotEmpty) {
        setState(() {
          imageCache[i] = validOptions[i].imageUrls!;
          currentImageIndex[i] = 0;
        });
        continue;
      }

      setState(() {
        loadingImages[i] = true;
        currentImageIndex[i] = 0;
      });

      try {
        final imageUrls = await DishImageCacheService.fetchDishImages(
          validOptions[i].dishName,
          maxResults: 3,
        );

        if (mounted) {
          setState(() {
            if (imageUrls.isNotEmpty) {
              imageCache[i] = imageUrls;
              validOptions[i].imageUrls = imageUrls;
            } else {
              imageCache[i] = List.generate(
                3,
                (index) => DishImageCacheService.getPlaceholderImage(
                  '${validOptions[i].dishName} ${index + 1}',
                ),
              );
            }
            loadingImages[i] = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            imageCache[i] = List.generate(
              3,
              (index) => DishImageCacheService.getPlaceholderImage(
                '${validOptions[i].dishName} ${index + 1}',
              ),
            );
            loadingImages[i] = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final validOptions =
        widget.options.where((option) {
          return option.ingredients.isNotEmpty &&
              option.ingredients.length >= 2;
        }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.white,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      const Color(0xFF00BCD4).withOpacity(0.05),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF00BCD4),
                                    Color(0xFF00ACC1),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF00BCD4,
                                    ).withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.restaurant_menu,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Dish Recognition',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Select the correct match',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00BCD4).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(
                                    0xFF00BCD4,
                                  ).withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                '${validOptions.length}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF00BCD4),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (validOptions.isEmpty)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.red[50]!,
                      Colors.red[100]!.withOpacity(0.3),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red[200]!, width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red[100],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.error_outline,
                        color: Colors.red[700],
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No Valid Items',
                            style: TextStyle(
                              color: Colors.red[900],
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Could not extract valid ingredients',
                            style: TextStyle(
                              color: Colors.red[800],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue[50]!,
                      Colors.blue[100]!.withOpacity(0.3),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue[200]!, width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lightbulb_outline,
                        color: Colors.blue[700],
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Compare & Select',
                            style: TextStyle(
                              color: Colors.blue[900],
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Swipe images to view examples',
                            style: TextStyle(
                              color: Colors.blue[800],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (validOptions.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.no_food_rounded,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No valid food items detected',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'The scanned image doesn\'t appear to contain food or a product label with ingredients.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final option = validOptions[index];
                  return buildDishOption(option, index);
                }, childCount: validOptions.length),
              ),
            ),
        ],
      ),
      floatingActionButton: buildFloatingActions(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget buildFloatingActions() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selectedIndex != null)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00BCD4), Color(0xFF00ACC1)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00BCD4).withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            final validOptions =
                                widget.options.where((option) {
                                  return option.ingredients.isNotEmpty &&
                                      option.ingredients.length >= 2;
                                }).toList();
                            widget.onOptionSelected(
                              validOptions[selectedIndex!],
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'Confirm Selection',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                FadeTransition(
                                  opacity: pulseController,
                                  child: const Icon(
                                    Icons.arrow_forward,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onManualEntry,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          color: Colors.grey[700],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'None of these - Enter manually',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildDishOption(DishOption option, int index) {
    bool isSelected = selectedIndex == index;
    List<String>? imageUrls = imageCache[index];
    bool isLoadingImage = loadingImages[index] ?? false;
    int currentImageIndex = this.currentImageIndex[index] ?? 0;

    final hasDetailedBenefits =
        option.ingredientsWithBenefits.isNotEmpty &&
        option.ingredientsWithBenefits.any(
          (ing) =>
              ing.benefits.isNotEmpty &&
              ing.benefits != 'No nutritional information available.' &&
              ing.benefits != 'Nutritional information not available.',
        );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 16),
      transform: Matrix4.identity()..scale(isSelected ? 1.0 : 0.98),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              selectedIndex = index;
            });
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? const Color(0xFF00BCD4) : Colors.grey[200]!,
                width: isSelected ? 3 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      isSelected
                          ? const Color(0xFF00BCD4).withOpacity(0.2)
                          : Colors.black.withOpacity(0.05),
                  blurRadius: isSelected ? 20 : 10,
                  offset: Offset(0, isSelected ? 8 : 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildEnhancedCarousel(
                  imageUrls,
                  isLoadingImage,
                  index,
                  currentImageIndex,
                  option,
                  isSelected,
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00BCD4).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.restaurant,
                              size: 18,
                              color: Color(0xFF00BCD4),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              option.dishName,
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: Colors.grey[900],
                                letterSpacing: -0.5,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Text(
                          option.description.length > 120
                              ? '${option.description.substring(0, 120)}...'
                              : option.description,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                            height: 1.6,
                            letterSpacing: 0.2,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (option.ingredients.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.green[50]!,
                                Colors.green[50]!.withOpacity(0.3),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green[100]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.eco_rounded,
                                    size: 16,
                                    color: Colors.green[700],
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Ingredients (${option.ingredients.length})',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.green[900],
                                    ),
                                  ),
                                  const Spacer(),
                                  if (hasDetailedBenefits)
                                    GestureDetector(
                                      onTap: () {
                                        showIngredientBenefitsDialog(option);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue[50],
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.blue[200]!,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.info_outline,
                                              size: 12,
                                              color: Colors.blue[700],
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Benefits',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.blue[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children:
                                    option.ingredients
                                        .take(6)
                                        .map(
                                          (ingredient) => Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.green[300]!,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 4,
                                                  height: 4,
                                                  decoration: BoxDecoration(
                                                    color: Colors.green[600],
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  ingredient,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.green[800],
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                        .toList(),
                              ),
                              if (option.ingredients.length > 6)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    '+${option.ingredients.length - 6} more',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green[700],
                                      fontStyle: FontStyle.italic,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                      if (isSelected) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF00BCD4).withOpacity(0.15),
                                const Color(0xFF00BCD4).withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF00BCD4).withOpacity(0.4),
                              width: 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF00BCD4),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Selected for confirmation',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF00BCD4),
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios,
                                size: 14,
                                color: Color(0xFF00BCD4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildEnhancedCarousel(
    List<String>? imageUrls,
    bool isLoadingImage,
    int cardIndex,
    int currentImageIndex,
    DishOption option,
    bool isSelected,
  ) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
          child: Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.grey[100]!, Colors.grey[200]!],
              ),
            ),
            child:
                isLoadingImage
                    ? buildLoadingState()
                    : imageUrls != null && imageUrls.isNotEmpty
                    ? PageView.builder(
                      controller: pageControllers[cardIndex],
                      itemCount: imageUrls.length,
                      onPageChanged: (index) {
                        setState(() {
                          this.currentImageIndex[cardIndex] = index;
                        });
                      },
                      itemBuilder: (context, imageIndex) {
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              imageUrls[imageIndex],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return buildErrorState(imageIndex);
                              },
                              loadingBuilder: (
                                context,
                                child,
                                loadingProgress,
                              ) {
                                if (loadingProgress == null) return child;
                                return buildImageLoadingState(loadingProgress);
                              },
                            ),
                            Container(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  center: Alignment.center,
                                  radius: 1.0,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.1),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    )
                    : buildPlaceholderState(),
          ),
        ),

        // Bottom gradient overlay
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
              ),
            ),
          ),
        ),

        // Page indicators
        if (imageUrls != null && imageUrls.length > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                imageUrls.length,
                (dotIndex) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: currentImageIndex == dotIndex ? 28 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color:
                        currentImageIndex == dotIndex
                            ? Colors.white
                            : Colors.white.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      if (currentImageIndex == dotIndex)
                        BoxShadow(
                          color: Colors.white.withOpacity(0.5),
                          blurRadius: 8,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Navigation arrows
        if (imageUrls != null && imageUrls.length > 1) ...[
          Positioned(
            left: 12,
            top: 0,
            bottom: 0,
            child: Center(
              child: AnimatedOpacity(
                opacity: currentImageIndex > 0 ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.chevron_left,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed:
                        currentImageIndex > 0
                            ? () {
                              pageControllers[cardIndex]?.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                            : null,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 12,
            top: 0,
            bottom: 0,
            child: Center(
              child: AnimatedOpacity(
                opacity: currentImageIndex < imageUrls.length - 1 ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.chevron_right,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed:
                        currentImageIndex < imageUrls.length - 1
                            ? () {
                              pageControllers[cardIndex]?.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                            : null,
                  ),
                ),
              ),
            ),
          ),
        ],

        // Confidence badge
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, Colors.white.withOpacity(0.95)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00BCD4).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified,
                    size: 14,
                    color: Color(0xFF00BCD4),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${(option.confidence * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF00BCD4),
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  'match',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Image counter
        if (imageUrls != null && imageUrls.length > 1)
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.collections, size: 14, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    '${currentImageIndex + 1}/${imageUrls.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Selection border overlay
        if (isSelected)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF00BCD4), width: 3),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(19),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget buildLoadingState() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.grey[100]!, Colors.grey[200]!],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      const Color(0xFF00BCD4).withOpacity(0.3),
                    ),
                  ),
                ),
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF00BCD4),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.image_search,
                    size: 16,
                    color: Color(0xFF00BCD4),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Loading images...',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF00BCD4),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildErrorState(int imageIndex) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.grey[200]!, Colors.grey[300]!],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.broken_image_outlined,
                size: 40,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Image ${imageIndex + 1} unavailable',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildImageLoadingState(ImageChunkEvent loadingProgress) {
    return Container(
      color: Colors.grey[100],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                value:
                    loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                strokeWidth: 3,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF00BCD4),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (loadingProgress.expectedTotalBytes != null)
              Text(
                '${((loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!) * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget buildPlaceholderState() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.grey[200]!, Colors.grey[300]!],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.restaurant_menu,
                size: 48,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'No images available',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void showIngredientBenefitsDialog(DishOption option) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder:
                (context, scrollController) => Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                          border: Border(
                            bottom: BorderSide(color: Colors.grey[200]!),
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 40,
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.green[50],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.local_hospital_rounded,
                                    color: Colors.green[700],
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Ingredient Health Benefits',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        option.dishName,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.all(20),
                          itemCount: option.ingredientsWithBenefits.length,
                          itemBuilder: (context, index) {
                            final ingredient =
                                option.ingredientsWithBenefits[index];
                            final hasBenefits =
                                ingredient.benefits.isNotEmpty &&
                                ingredient.benefits !=
                                    'No nutritional information available.' &&
                                ingredient.benefits !=
                                    'Nutritional information not available.';

                            if (!hasBenefits) return const SizedBox.shrink();

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[200]!),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ExpansionTile(
                                tilePadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                childrenPadding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  16,
                                ),
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.green[100]!,
                                        Colors.blue[100]!,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.eco_rounded,
                                    color: Colors.green[700],
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  ingredient.name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.lightbulb_outline,
                                          size: 16,
                                          color: Colors.green[700],
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            ingredient.benefits,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[800],
                                              height: 1.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }
}
