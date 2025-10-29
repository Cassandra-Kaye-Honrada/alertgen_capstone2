import 'dart:ui';
import 'package:allergen/styleguide.dart';
import 'package:flutter/material.dart';
import 'image_search_service.dart';

class SkinConditionOption {
  final String conditionName;
  final bool isFoodAllergyRelated;
  final double confidence;
  final String description;
  final String severity;
  final List<Map<String, dynamic>> likelyFoodTriggers;
  final List<String> symptoms;
  final List<String> immediateActions;
  final List<String> foodsToAvoid;
  final String whenToSeekHelp;
  final String additionalNotes;
  List<String>? imageUrls;

  SkinConditionOption({
    required this.conditionName,
    required this.isFoodAllergyRelated,
    required this.confidence,
    required this.description,
    required this.severity,
    required this.likelyFoodTriggers,
    required this.symptoms,
    required this.immediateActions,
    required this.foodsToAvoid,
    required this.whenToSeekHelp,
    required this.additionalNotes,
    this.imageUrls,
  });

  factory SkinConditionOption.fromJson(Map<String, dynamic> json) {
    return SkinConditionOption(
      conditionName: json['conditionName']?.toString() ?? 'Unknown Condition',
      isFoodAllergyRelated: json['isFoodAllergyRelated'] ?? false,
      confidence: (json['confidence'] ?? 0.5).toDouble(),
      description: json['description']?.toString() ?? '',
      severity: json['severity']?.toString() ?? 'unknown',
      likelyFoodTriggers:
          (json['likelyFoodTriggers'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [],
      symptoms:
          (json['symptoms'] as List?)?.map((e) => e.toString()).toList() ?? [],
      immediateActions:
          (json['immediateActions'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      foodsToAvoid:
          (json['foodsToAvoid'] as List?)?.map((e) => e.toString()).toList() ??
          [],
      whenToSeekHelp: json['whenToSeekHelp']?.toString() ?? '',
      additionalNotes: json['additionalNotes']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'conditionName': conditionName,
      'isFoodAllergyRelated': isFoodAllergyRelated,
      'confidence': confidence,
      'description': description,
      'severity': severity,
      'likelyFoodTriggers': likelyFoodTriggers,
      'symptoms': symptoms,
      'immediateActions': immediateActions,
      'foodsToAvoid': foodsToAvoid,
      'whenToSeekHelp': whenToSeekHelp,
      'additionalNotes': additionalNotes,
      'imageUrls': imageUrls,
    };
  }
}

class SkinConditionSelectionScreen extends StatefulWidget {
  final List<SkinConditionOption> options;
  final Function(SkinConditionOption) onOptionSelected;
  final Function() onManualEntry;

  const SkinConditionSelectionScreen({
    Key? key,
    required this.options,
    required this.onOptionSelected,
    required this.onManualEntry,
  }) : super(key: key);

  @override
  _SkinConditionSelectionScreenState createState() =>
      _SkinConditionSelectionScreenState();
}

class _SkinConditionSelectionScreenState
    extends State<SkinConditionSelectionScreen>
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
    for (int i = 0; i < widget.options.length; i++) {
      pageControllers[i] = PageController();

      if (widget.options[i].imageUrls != null &&
          widget.options[i].imageUrls!.isNotEmpty) {
        setState(() {
          imageCache[i] = widget.options[i].imageUrls!;
          currentImageIndex[i] = 0;
        });
        continue;
      }

      setState(() {
        loadingImages[i] = true;
        currentImageIndex[i] = 0;
      });

      try {
        final imageUrls = await ImageSearchService.fetchConditionImages(
          widget.options[i].conditionName,
          maxResults: 3,
        );

        if (mounted) {
          setState(() {
            if (imageUrls.isNotEmpty) {
              imageCache[i] = imageUrls;
            } else {
              imageCache[i] = List.generate(
                3,
                (index) => ImageSearchService.getPlaceholderImage(
                  '${widget.options[i].conditionName} ${index + 1}',
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
              (index) => ImageSearchService.getPlaceholderImage(
                '${widget.options[i].conditionName} ${index + 1}',
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
                    colors: [Colors.white, AppColors.primary.withOpacity(0.05)],
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
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primary,
                                    AppColors.primary.withOpacity(0.7),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.healing,
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
                                    'Skin Condition Analysis',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Select the best match',
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
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.primary.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                '${widget.options.length}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
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

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final option = widget.options[index];
                return buildConditionOption(option, index);
              }, childCount: widget.options.length),
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
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            widget.onOptionSelected(
                              widget.options[selectedIndex!],
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
                          'None of these match',
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

  Widget buildConditionOption(SkinConditionOption option, int index) {
    bool isSelected = selectedIndex == index;
    Color severityColor = getSeverityColor(option.severity);
    List<String>? imageUrls = imageCache[index];
    bool isLoadingImage = loadingImages[index] ?? false;
    int currentImageIndex = this.currentImageIndex[index] ?? 0;

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
                color: isSelected ? AppColors.primary : Colors.grey[200]!,
                width: isSelected ? 3 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      isSelected
                          ? AppColors.primary.withOpacity(0.2)
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
                  severityColor,
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
                              color: severityColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.medical_services,
                              size: 18,
                              color: severityColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              option.conditionName,
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

                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          buildEnhancedTag(
                            icon: Icons.warning_amber_rounded,
                            text: option.severity.toUpperCase(),
                            textColor: severityColor,
                            bgColor: severityColor.withOpacity(0.12),
                            borderColor: severityColor.withOpacity(0.3),
                          ),
                          buildEnhancedTag(
                            icon:
                                option.isFoodAllergyRelated
                                    ? Icons.restaurant
                                    : Icons.block,
                            text:
                                option.isFoodAllergyRelated
                                    ? 'Food Related'
                                    : 'Not Food Related',
                            textColor:
                                option.isFoodAllergyRelated
                                    ? Colors.orange[800]!
                                    : Colors.grey[700]!,
                            bgColor:
                                option.isFoodAllergyRelated
                                    ? Colors.orange[50]!
                                    : Colors.grey[100]!,
                            borderColor:
                                option.isFoodAllergyRelated
                                    ? Colors.orange[200]!
                                    : Colors.grey[300]!,
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

                      if (option.symptoms.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue[50]!,
                                Colors.blue[50]!.withOpacity(0.3),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue[100]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.fact_check_outlined,
                                    size: 16,
                                    color: Colors.blue[700],
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Key Symptoms',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.blue[900],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ...option.symptoms
                                  .take(3)
                                  .map(
                                    (symptom) => Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 4,
                                            height: 4,
                                            decoration: BoxDecoration(
                                              color: Colors.blue[600],
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              symptom,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.blue[800],
                                                height: 1.4,
                                              ),
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

                      if (isSelected) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary.withOpacity(0.15),
                                AppColors.primary.withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.4),
                              width: 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Selected for detailed analysis',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 14,
                                color: AppColors.primary,
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
    Color severityColor,
    SkinConditionOption option,
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
                    color: severityColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.verified, size: 14, color: severityColor),
                ),
                const SizedBox(width: 6),
                Text(
                  '${(option.confidence * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: severityColor,
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

        if (isSelected)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary, width: 3),
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
                      AppColors.primary.withOpacity(0.3),
                    ),
                  ),
                ),
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
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
                  Icon(Icons.image_search, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Loading examples...',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
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
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
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
                Icons.photo_library_outlined,
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

  Widget buildEnhancedTag({
    required IconData icon,
    required String text,
    required Color textColor,
    required Color bgColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: textColor,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Color getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'emergency':
        return const Color(0xFFD32F2F);
      case 'severe':
        return const Color(0xFFFF6F00);
      case 'moderate':
        return const Color(0xFFFFA000);
      case 'mild':
        return const Color(0xFF388E3C);
      default:
        return const Color(0xFF757575);
    }
  }
}
