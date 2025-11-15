import 'package:allergen/screens/feature/educational/ResourceDetailScreen.dart';
import 'package:allergen/screens/feature/educational/allergens_data.dart';
import 'package:allergen/screens/feature/educational/resources_data.dart';
import 'package:allergen/screens/feature/scan_screen.dart';
import 'package:allergen/screens/first_Aid_screens/FirstAidScreen.dart';
import 'package:allergen/screens/health_environment_analytics/AirQualityDetailScreen.dart';
import 'package:allergen/screens/profile_screen_items/ProfileScreen.dart';
import 'package:allergen/services/emergency/emergency_service.dart';
import 'package:allergen/styleguide.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';

// Data Models
class Allergen {
  final String name;
  final String description;
  final String prevalence;
  final IconData icon;
  final Color color;
  final List<String> symptoms;
  final List<String> hiddenSources;
  final String? imagePath;
  final String detailedInfo;
  final String livingWith;
  final String allergicReactions;
  final String avoidance;
  final String outgrow;

  Allergen({
    required this.name,
    required this.description,
    required this.prevalence,
    required this.icon,
    required this.color,
    required this.symptoms,
    required this.hiddenSources,
    this.imagePath,
    this.detailedInfo = '',
    this.livingWith = '',
    this.allergicReactions = '',
    this.avoidance = '',
    this.outgrow = '',
  });
}

class Article {
  final String title;
  final String timeAgo;
  final String summary;
  final IconData icon;
  final Color color;
  final String url;

  Article({
    required this.title,
    required this.timeAgo,
    required this.summary,
    required this.icon,
    required this.color,
    required this.url,
  });
}

class ResourceLink {
  final String title;
  final String description;
  final String url;
  final IconData icon;
  final Color color;
  final String category;
  final String detailedContent;
  final List<String> imagePaths;

  ResourceLink({
    required this.title,
    required this.description,
    required this.url,
    required this.icon,
    required this.color,
    required this.category,
    required this.detailedContent,
    required this.imagePaths,
  });
}

class StatisticCard {
  final IconData icon;
  final String number;
  final String label;
  final String description;
  final Color color;
  final String? imagePath;

  StatisticCard({
    required this.icon,
    required this.number,
    required this.label,
    required this.description,
    required this.color,
    this.imagePath,
  });
}

class FoodAllergyScreen extends StatefulWidget {
  const FoodAllergyScreen({Key? key}) : super(key: key);

  @override
  State<FoodAllergyScreen> createState() => _FoodAllergyScreenState();
}

class _FoodAllergyScreenState extends State<FoodAllergyScreen>
    with TickerProviderStateMixin {
  List<Allergen> allergens = [];
  List<ResourceLink> resources = [];
  bool isLoading = true;
  String searchQuery = '';
  String selectedFilter = 'All';
  late AnimationController _fabController;
  late AnimationController _statsController;
  Timer? _refreshTimer;
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _autoScrollTimer;

  final List<String> filters = ['All', 'Children', 'Adults', 'Severe'];

  final List<StatisticCard> statistics = [
    StatisticCard(
      icon: Icons.people,
      number: '33 Million',
      label: 'Americans Impacted',
      description: 'People in the U.S. living with food allergies',
      color: AppColors.primary,
      imagePath: 'assets/statistics/people_stat.png',
    ),
    StatisticCard(
      icon: Icons.child_care,
      number: '1 in 13',
      label: 'Children Affected',
      description: 'Children have food allergies in the United States',
      color: AppColors.primaryColor3,
      imagePath: 'assets/statistics/children_stat.png',
    ),
    StatisticCard(
      icon: Icons.person,
      number: '11%',
      label: 'Adult Population',
      description: 'Adults living with food allergies',
      color: AppColors.primary,
      imagePath: 'assets/statistics/adults_stat.png',
    ),
    StatisticCard(
      icon: Icons.restaurant,
      number: '9 Major',
      label: 'Food Allergens',
      description: 'Recognized major food allergens by FASTER Act',
      color: AppColors.primaryColor3,
      imagePath: 'assets/statistics/allergens_stat.png',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _statsController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    loadData();
    _startAutoRefresh();
    _startAutoScroll();
  }

  @override
  void dispose() {
    _fabController.dispose();
    _statsController.dispose();
    _refreshTimer?.cancel();
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      loadData();
    });
  }

  void _startAutoScroll() {
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_pageController.hasClients) {
        int nextPage = (_currentPage + 1) % statistics.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open $urlString'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  Widget _buildResourceImage({
    required String? imagePath,
    required double width,
    required double height,
    required Color placeholderColor,
    required IconData placeholderIcon,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(12),
        color: placeholderColor.withOpacity(0.1),
      ),
      child:
          imagePath != null
              ? ClipRRect(
                borderRadius: borderRadius ?? BorderRadius.circular(12),
                child: Image.asset(
                  imagePath,
                  width: width,
                  height: height,
                  fit: fit,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildResourcePlaceholder(
                      width: width,
                      height: height,
                      color: placeholderColor,
                      icon: placeholderIcon,
                      borderRadius: borderRadius,
                    );
                  },
                ),
              )
              : _buildResourcePlaceholder(
                width: width,
                height: height,
                color: placeholderColor,
                icon: placeholderIcon,
                borderRadius: borderRadius,
              ),
    );
  }

  Widget _buildResourcePlaceholder({
    required double width,
    required double height,
    required Color color,
    required IconData icon,
    BorderRadius? borderRadius,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(12),
        color: color.withOpacity(0.1),
      ),
      child: Icon(icon, color: color.withOpacity(0.5)),
    );
  }

  Future<void> loadData() async {
    setState(() => isLoading = true);

    setState(() {
      allergens = AllergensData.getAllergens();
      resources = ResourcesData.getResources();
      isLoading = false;
    });

    _statsController.forward(from: 0);
  }

  List<Allergen> getFilteredAllergens() {
    var filtered = allergens;

    if (searchQuery.isNotEmpty) {
      filtered =
          filtered
              .where(
                (a) =>
                    a.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                    a.description.toLowerCase().contains(
                      searchQuery.toLowerCase(),
                    ),
              )
              .toList();
    }

    if (selectedFilter != 'All') {
      filtered =
          filtered.where((a) {
            switch (selectedFilter) {
              case 'Children':
                return a.prevalence.toLowerCase().contains('children');
              case 'Adults':
                return a.prevalence.toLowerCase().contains('adults');
              case 'Severe':
                return a.symptoms.any(
                  (s) => s.toLowerCase().contains('anaphylaxis'),
                );
              default:
                return true;
            }
          }).toList();
    }

    return filtered;
  }

  Widget buildTreatmentSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How to Treat Allergic Reaction',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Learn essential first aid steps for allergic reactions.',
                    style: TextStyle(fontSize: 12, color: AppColors.textGray),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => FirstAidScreen()),
                  ),
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.arrow_forward, color: Colors.white, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      margin: const EdgeInsets.all(20),
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
          GestureDetector(
            onTap:
                () => Navigator.of(context).popUntil((route) => route.isFirst),
            child: Icon(Icons.home, color: AppColors.Gray, size: 24),
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
              color: AppColors.Gray,
              size: 24,
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CameraScannerScreen()),
              );
            },
            child: Image.asset(
              'assets/navigation/scan_gray.png',
              width: 18,
              height: 18,
              errorBuilder:
                  (context, error, stackTrace) => Icon(
                    Icons.camera_alt,
                    color: Color(0xFF64748B),
                    size: 24,
                  ),
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FoodAllergyScreen()),
              );
            },
            child: const Icon(Icons.school, color: AppColors.primary, size: 35),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) =>
                          UserProfile(emergencyService: EmergencyService()),
                ),
              );
            },
            child: Icon(Icons.person, color: AppColors.Gray, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCarousel() {
    return AnimatedBuilder(
      animation: _statsController,
      builder: (context, child) {
        return Opacity(
          opacity: _statsController.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - _statsController.value)),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              height: 240,
              child: Column(
                children: [
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() {
                          _currentPage = index;
                        });
                      },
                      itemCount: statistics.length,
                      itemBuilder: (context, index) {
                        return _buildStatCard(statistics[index]);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      statistics.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color:
                              _currentPage == index
                                  ? statistics[index].color
                                  : Colors.grey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(StatisticCard stat) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [stat.color, stat.color.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: stat.color.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background pattern/image
          if (stat.imagePath != null)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Opacity(
                  opacity: 0.2,
                  child: Image.asset(
                    stat.imagePath!,
                    fit: BoxFit.cover,
                    alignment: Alignment.centerRight,
                    errorBuilder: (context, error, stackTrace) => SizedBox(),
                  ),
                ),
              ),
            ),
          // Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(stat.icon, color: Colors.white, size: 32),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.schedule, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Live',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stat.number,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      stat.label,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      stat.description,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.defaultbackground,
      appBar: AppBar(
        title: Text(
          'Learn About Allergy',
          style: AppTextStyles.headline.copyWith(
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.primary,
        elevation: 0,
        // actions: [
        //   IconButton(
        //     icon: Icon(Icons.info_outline, color: Colors.white),
        //     onPressed: () =>{},
        //     // _showInfoDialog(context),
        //     tooltip: 'About',
        //   ),
        // ],
      ),
      body:
          isLoading
              ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              )
              : RefreshIndicator(
                onRefresh: loadData,
                backgroundColor: AppColors.primary,
                color: Colors.white,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSearchBar(),
                      _buildFilterChips(),
                      _buildStatisticsCarousel(),
                      const SizedBox(height: 8),
                      _buildSectionHeader(
                        context,
                        'Major Food Allergens',
                        Icons.restaurant,
                      ),
                      _buildAllergensGrid(),
                      const SizedBox(height: 16),
                      buildTreatmentSection(),
                      _buildSectionHeader(
                        context,
                        'Educational Resources',
                        Icons.menu_book,
                      ),
                      ...resources.map(
                        (resource) => _buildResourceItem(resource, context),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.textBlack.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          onChanged: (value) {
            setState(() {
              searchQuery = value;
            });
          },
          decoration: InputDecoration(
            hintText: 'Search allergens, symptoms...',
            hintStyle: TextStyle(color: AppColors.textGray),
            prefixIcon: Icon(Icons.search, color: AppColors.primary, size: 24),
            suffixIcon:
                searchQuery.isNotEmpty
                    ? IconButton(
                      icon: Icon(Icons.clear, color: AppColors.textGray),
                      onPressed: () {
                        setState(() {
                          searchQuery = '';
                        });
                      },
                    )
                    : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: FilterChip(
              label: Text(
                filter,
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textBlack,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  selectedFilter = selected ? filter : 'All';
                });
              },
              backgroundColor: Colors.white,
              selectedColor: AppColors.primary,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.textBlack,
              ),
              elevation: isSelected ? 4 : 1,
              shadowColor: AppColors.primary.withOpacity(0.3),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.textBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          SizedBox(width: 12),
          Text(
            title,
            style: AppTextStyles.headline.copyWith(
              fontSize: 20,
              color: AppColors.textBlack,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllergensGrid() {
    final filtered = getFilteredAllergens();

    if (filtered.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(48),
        child: Center(
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.lightGray,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.search_off,
                  size: 64,
                  color: AppColors.textGray,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No allergens found',
                style: AppTextStyles.headline.copyWith(
                  color: AppColors.textBlack,
                  fontSize: 18,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Try adjusting your search or filters',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textGray,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.85,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        return _buildAllergenCard(filtered[index]);
      },
    );
  }

  Widget _buildAllergenCard(Allergen allergen) {
    return Card(
      elevation: 3,
      shadowColor: allergen.color.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _showAllergenDetails(allergen),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: allergen.color.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: allergen.color.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Icon(allergen.icon, color: allergen.color, size: 24),
                ),
                const SizedBox(height: 6),
                Flexible(
                  child: Text(
                    allergen.name,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textBlack,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: allergen.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Tap to learn',
                    style: TextStyle(
                      fontSize: 8,
                      color: allergen.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResourceItem(ResourceLink resource, BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        elevation: 2,
        shadowColor: resource.color.withOpacity(0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: () => _navigateToResourceDetail(resource, context),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _buildResourceImage(
                    imagePath: resource.imagePaths[0],
                    width: 56,
                    height: 56,
                    placeholderColor: resource.color,
                    placeholderIcon: resource.icon,
                    borderRadius: BorderRadius.circular(12),
                    fit: BoxFit.cover,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          resource.title,
                          style: AppTextStyles.body.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textBlack,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          resource.description,
                          style: AppTextStyles.body.copyWith(
                            fontSize: 13,
                            color: AppColors.textGray,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: resource.color.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                resource.category,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: resource.color,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            // Spacer(),
                            // Text(
                            //   'Read more',
                            //   style: TextStyle(
                            //     fontSize: 12,
                            //     color: resource.color,
                            //     fontWeight: FontWeight.w600,
                            //   ),
                            // ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: resource.color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward_ios,
                      color: resource.color,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToResourceDetail(ResourceLink resource, BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResourceDetailScreen(resource: resource),
      ),
    );
  }

  Widget _buildAccordionSection(Allergen allergen) {
    return Column(
      children: [
        // Allergic Reactions
        if (allergen.allergicReactions.isNotEmpty)
          _buildAccordionItem(
            title: 'Allergic Reactions to ${allergen.name}',
            content: allergen.allergicReactions,
            color: allergen.color,
            icon: Icons.warning_amber_rounded,
          ),

        // Hidden Sources

        // Avoiding section
        if (allergen.avoidance.isNotEmpty)
          _buildAccordionItem(
            title: 'Avoiding ${allergen.name}',
            content: allergen.avoidance,
            color: allergen.color,
            icon: Icons.block,
          ),

        // Outgrow section
        if (allergen.outgrow.isNotEmpty)
          _buildAccordionItem(
            title: 'Will My Child Outgrow a ${allergen.name} Allergy?',
            content: allergen.outgrow,
            color: allergen.color,
            icon: Icons.child_care,
          ),
        if (allergen.hiddenSources.isNotEmpty)
          _buildAccordionItemWithList(
            title: 'Hidden Sources of ${allergen.name}',
            items: allergen.hiddenSources,
            color: allergen.color,
            icon: Icons.search,
          ),
      ],
    );
  }

  Widget _buildAccordionItem({
    required String title,
    required String content,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: ThemeData(
          dividerColor: Colors.transparent,
          splashColor: color.withOpacity(0.1),
          highlightColor: color.withOpacity(0.05),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textBlack,
            ),
          ),
          iconColor: color,
          collapsedIconColor: color.withOpacity(0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          children: [
            Text(
              content,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: AppColors.textGray,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccordionItemWithList({
    required String title,
    required List<String> items,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: ThemeData(
          dividerColor: Colors.transparent,
          splashColor: color.withOpacity(0.1),
          highlightColor: color.withOpacity(0.05),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textBlack,
            ),
          ),
          iconColor: color,
          collapsedIconColor: color.withOpacity(0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:
                  items.map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 6, right: 12),
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              item,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.6,
                                color: AppColors.textGray,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showAllergenDetails(Allergen allergen) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.9,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            expand: false,
            builder:
                (context, scrollController) => Container(
                  decoration: BoxDecoration(
                    color: AppColors.defaultbackground,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Drag handle
                      Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 8),
                        child: Center(
                          child: Container(
                            width: 50,
                            height: 5,
                            decoration: BoxDecoration(
                              color: AppColors.lightGray,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                      // Header with image
                      Container(
                        height: 180,
                        margin: EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: allergen.color.withOpacity(0.3),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            // Background image
                            if (allergen.imagePath != null)
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Image.asset(
                                    allergen.imagePath!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              allergen.color,
                                              allergen.color.withOpacity(0.7),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            // Gradient overlay
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.1),
                                      Colors.black.withOpacity(0.7),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Content
                            Positioned(
                              bottom: 20,
                              left: 20,
                              right: 20,
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.3),
                                        width: 2,
                                      ),
                                    ),
                                    child: Icon(
                                      allergen.icon,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          allergen.name,
                                          style: TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(
                                              0.25,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: Colors.white.withOpacity(
                                                0.3,
                                              ),
                                            ),
                                          ),
                                          child: Text(
                                            allergen.prevalence,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Scrollable content
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Main information section
                              if (allergen.detailedInfo.isNotEmpty)
                                _buildInfoSection(
                                  'What Is ${allergen.name} Allergy?',
                                  allergen.detailedInfo,
                                  allergen.color,
                                ),

                              // Living With section
                              Text(
                                'Living With ${allergen.name} Allergy',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 20),

                              _buildAccordionSection(allergen),

                              const SizedBox(height: 24),

                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _showEmergencyInfo();
                                      },
                                      icon: const Icon(
                                        Icons.emergency,
                                        size: 20,
                                      ),
                                      label: const Text(
                                        'Emergency Info',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => Navigator.pop(context),
                                      icon: const Icon(Icons.check, size: 20),
                                      label: const Text(
                                        'Got it',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: allergen.color,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        side: BorderSide(
                                          color: allergen.color,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  Widget _buildInfoSection(String title, String content, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textBlack,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            content,
            style: AppTextStyles.body.copyWith(
              fontSize: 14,
              color: AppColors.textGray,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSymptomsList(String title, List<String> symptoms, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: AppTextStyles.body.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textBlack,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...symptoms.map(
            (symptom) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      symptom,
                      style: AppTextStyles.body.copyWith(
                        fontSize: 14,
                        color: AppColors.textGray,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHiddenSourcesList(
    String title,
    List<String> sources,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.visibility_off, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: AppTextStyles.body.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textBlack,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                sources
                    .map(
                      (source) => Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: color.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          source,
                          style: TextStyle(
                            fontSize: 13,
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                    .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(
    String title,
    String content,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              SizedBox(width: 8),
              Text(
                title,
                style: AppTextStyles.body.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textBlack,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: AppTextStyles.body.copyWith(
              fontSize: 14,
              color: AppColors.textGray,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  void _showEmergencyInfo() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.emergency,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Anaphylaxis Emergency',
                    style: AppTextStyles.headline.copyWith(fontSize: 18),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      'Anaphylaxis is a severe, potentially life-threatening allergic reaction.',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Signs & Symptoms:',
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textBlack,
                    ),
                  ),
                  SizedBox(height: 8),
                  _buildSymptomItem('Difficulty breathing or wheezing'),
                  _buildSymptomItem('Swelling of throat, tongue, or lips'),
                  _buildSymptomItem('Rapid pulse'),
                  _buildSymptomItem('Dizziness or fainting'),
                  _buildSymptomItem('Skin reactions (hives, itching)'),
                  const SizedBox(height: 16),
                  Text(
                    'Treatment Steps:',
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textBlack,
                    ),
                  ),
                  SizedBox(height: 8),
                  _buildTreatmentStep('1', 'Inject epinephrine immediately'),
                  _buildTreatmentStep('2', 'Call 911'),
                  _buildTreatmentStep(
                    '3',
                    'Lay person down with legs elevated',
                  ),
                  _buildTreatmentStep(
                    '4',
                    'Give second dose if no improvement in 5-15 min',
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor2Teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primaryColor2Teal.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.primaryColor2Teal,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Always carry TWO epinephrine auto-injectors',
                            style: TextStyle(
                              color: AppColors.primaryColor2Teal,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Close',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildSymptomItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.circle, size: 8, color: AppColors.primary),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.body.copyWith(
                fontSize: 13,
                height: 1.4,
                color: AppColors.textGray,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTreatmentStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                text,
                style: AppTextStyles.body.copyWith(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.textGray,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // void _showInfoDialog(BuildContext context) {
  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       shape: RoundedRectangleBorder(
  //         borderRadius: BorderRadius.circular(20),
  //       ),
  //       title: Row(
  //         children: [
  //           Container(
  //             padding: EdgeInsets.all(8),
  //             decoration: BoxDecoration(
  //               color: AppColors.textBackground,
  //               shape: BoxShape.circle,
  //             ),
  //             child: Icon(Icons.info, color: AppColors.primary, size: 24),
  //           ),
  //           SizedBox(width: 12),
  //           Text(
  //             'About This App',
  //             style: AppTextStyles.headline.copyWith(fontSize: 18),
  //           ),
  //         ],
  //       ),
  //       content: SingleChildScrollView(
  //         child: Column(
  //           mainAxisSize: MainAxisSize.min,
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             Text(
  //               'This educational app provides information about food allergies based on data from FoodAllergy.org (FARE) and AAAAI.',
  //               style: AppTextStyles.body.copyWith(height: 1.5),
  //             ),
  //             const SizedBox(height: 20),
  //             _buildInfoSection(
  //               'Key Facts',
  //               Icons.analytics,
  //               AppColors.primary,
  //               [
  //                 '33 million Americans impacted',
  //                 '1 in 13 children affected',
  //                 '9 major allergens recognized',
  //               ],
  //             ),
  //             const SizedBox(height: 16),
  //             _buildInfoSection(
  //               'Features',
  //               Icons.stars,
  //               AppColors.primaryColor2Teal,
  //               [
  //                 'Search allergens',
  //                 'Filter by category',
  //                 'Emergency info access',
  //                 'Educational resources',
  //               ],
  //             ),
  //             const SizedBox(height: 16),
  //             Container(
  //               padding: EdgeInsets.all(12),
  //               decoration: BoxDecoration(
  //                 color: AppColors.primary.withOpacity(0.1),
  //                 borderRadius: BorderRadius.circular(10),
  //                 border: Border.all(
  //                   color: AppColors.primary.withOpacity(0.3),
  //                 ),
  //               ),
  //               child: Row(
  //                 children: [
  //                   Icon(
  //                     Icons.medical_information,
  //                     color: AppColors.primary,
  //                     size: 20,
  //                   ),
  //                   SizedBox(width: 10),
  //                   Expanded(
  //                     child: Text(
  //                       'Always consult healthcare providers for medical advice.',
  //                       style: TextStyle(
  //                         fontStyle: FontStyle.italic,
  //                         fontSize: 12,
  //                         color: AppColors.primary,
  //                       ),
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(context),
  //           child: Text(
  //             'Close',
  //             style: AppTextStyles.body.copyWith(
  //               fontWeight: FontWeight.w600,
  //               color: AppColors.primary,
  //             ),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  //   Widget _buildInfoSection(
  //     String title,
  //     IconData icon,
  //     Color color,
  //     List<String> items,
  //   ) {
  //     return Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Row(
  //           children: [
  //             Icon(icon, color: color, size: 18),
  //             SizedBox(width: 8),
  //             Text(
  //               title,
  //               style: AppTextStyles.body.copyWith(
  //                 fontWeight: FontWeight.bold,
  //                 fontSize: 15,
  //                 color: AppColors.textBlack,
  //               ),
  //             ),
  //           ],
  //         ),
  //         SizedBox(height: 8),
  //         ...items.map(
  //           (item) => Padding(
  //             padding: const EdgeInsets.only(left: 26, bottom: 4),
  //             child: Row(
  //               crossAxisAlignment: CrossAxisAlignment.start,
  //               children: [
  //                 Text('• ', style: TextStyle(color: color)),
  //                 Expanded(
  //                   child: Text(
  //                     item,
  //                     style: AppTextStyles.body.copyWith(
  //                       fontSize: 13,
  //                       height: 1.3,
  //                       color: AppColors.textGray,
  //                     ),
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ),
  //       ],
  //     );
  //   }
  // }
}
