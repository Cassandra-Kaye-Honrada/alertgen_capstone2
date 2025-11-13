import 'package:allergen/styleguide.dart';
import 'package:flutter/material.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({Key? key}) : super(key: key);

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController animationController;
  late Animation<double> fadeAnimation;
  late Animation<Offset> slideAnimation;

  @override
  void initState() {
    super.initState();
    animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: animationController, curve: Curves.easeOut),
    );
    slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: animationController, curve: Curves.easeOut),
    );
    animationController.forward();
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.defaultbackground,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: AppColors.primary,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'About AlertGen',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              centerTitle: true,
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.primary, AppColors.primaryColor2Teal],
                  ),
                ),
                child: Container(
                  height: 1,
                  width: 1,
                  child: Image.asset('assets/images/logo.png'),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: fadeAnimation,
              child: SlideTransition(
                position: slideAnimation,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      buildHeaderSection(),
                      const SizedBox(height: 32),
                      buildMissionSection(),
                      const SizedBox(height: 32),
                      buildFeaturesSection(),
                      const SizedBox(height: 32),
                      buildTechnologySection(),
                      const SizedBox(height: 32),
                      buildCapabilitiesSection(),
                      const SizedBox(height: 32),
                      buildLimitationsSection(),
                      const SizedBox(height: 32),
                      buildContactSection(),
                      const SizedBox(height: 24),
                      buildFooter(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildHeaderSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Image.asset(
                'assets/images/logo.png',
                height: 30,
                width: 30,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'AlertGen',
            style: TextStyle(
              color: AppColors.textBlack,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Complete Allergy Management & Safety Platform',
            style: TextStyle(
              color: AppColors.textGray,
              fontSize: 16,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.1)),
            ),
            child: const Text(
              'Version 1.0.0',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildMissionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSectionTitle('Our Mission'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.lightGray.withOpacity(0.3)),
          ),
          child: const Text(
            'ALERTGEN is a comprehensive AI-driven mobile application designed to protect individuals with allergies. '
            'Our mission is to provide smart allergen detection for both food and skin allergies using OCR and AI, '
            'real-time environmental monitoring with air quality tracking, personalized allergy profiles, '
            'detailed allergen analytics, educational resources, safe food alternatives, and emergency support '
            'to ensure confidence and safety in every aspect of daily life.',
            style: TextStyle(
              color: AppColors.textGray,
              fontSize: 15,
              height: 1.6,
              letterSpacing: 0.2,
            ),
            textAlign: TextAlign.start,
          ),
        ),
      ],
    );
  }

  Widget buildFeaturesSection() {
    final features = [
      {
        'icon': Icons.camera_alt,
        'title': 'Food & Skin Allergen Scanning',
        'desc':
            'Scan food labels and check for skin allergies using camera or image uploads with instant allergen detection',
      },
      {
        'icon': Icons.air,
        'title': 'Air Quality Monitoring',
        'desc':
            'Track real-time air quality and AQI levels in your location with push notifications for high pollution alerts',
      },
      {
        'icon': Icons.analytics,
        'title': 'Allergen Analytics',
        'desc':
            'Comprehensive insights and trends from your scan history to understand allergen exposure patterns',
      },
      {
        'icon': Icons.school,
        'title': 'Allergen Education',
        'desc':
            'Learn about allergies with comprehensive information and educational resources about allergens',
      },
      {
        'icon': Icons.person_outline,
        'title': 'Personalized Profiles',
        'desc':
            'Custom allergy profiles to track and manage your specific allergen sensitivities',
      },
      {
        'icon': Icons.restaurant_menu,
        'title': 'Safe Alternatives',
        'desc':
            'Intelligent suggestions for allergen-free food substitutes tailored to your profile',
      },
      {
        'icon': Icons.history,
        'title': 'Scan History',
        'desc':
            'Keep track of all your previous scans and build a database of safe foods',
      },
      {
        'icon': Icons.health_and_safety,
        'title': 'Emergency Support',
        'desc':
            'First aid guide and quick emergency contacts for allergic reactions',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSectionTitle('Core Features'),
        SizedBox(
          height: 900,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.85,
            ),
            itemCount: features.length,
            itemBuilder: (context, index) {
              final feature = features[index];
              return buildFeatureCard(
                feature['icon'] as IconData,
                feature['title'] as String,
                feature['desc'] as String,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget buildFeatureCard(IconData icon, String title, String description) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGray.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textBlack,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              description,
              style: TextStyle(
                color: AppColors.textGray.withOpacity(0.8),
                fontSize: 11,
                height: 1.3,
                letterSpacing: 0.2,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildTechnologySection() {
    final technologies = [
      'Optical Character Recognition (OCR)',
      'Machine Learning Algorithms',
      'AI Image Analysis',
      'Real-time Air Quality API Integration',
      'Push Notification Service',
      'Cloud-Based Processing',
      'Real-time Database Integration',
      'Advanced Analytics Engine',
      'Secure Data Encryption',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSectionTitle('Technology Stack'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.lightGray.withOpacity(0.3)),
          ),
          child: Column(
            children: technologies.map((tech) => buildTechItem(tech)).toList(),
          ),
        ),
      ],
    );
  }

  Widget buildTechItem(String technology) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              technology,
              style: const TextStyle(
                color: AppColors.textGray,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildCapabilitiesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSectionTitle('Detection & Monitoring Capabilities'),
        const SizedBox(height: 16),
        buildCapabilityItem(
          'Food & Skin Allergen Detection',
          'Comprehensive scanning of food labels and skin allergy identification including nuts, dairy, gluten, shellfish, and various skin irritants',
        ),
        const SizedBox(height: 12),
        buildCapabilityItem(
          'Environmental Monitoring',
          'Real-time air quality tracking with AQI measurements and background monitoring with automatic alerts for high pollution levels',
        ),
        const SizedBox(height: 12),
        buildCapabilityItem(
          'Analytics & Insights',
          'Detailed allergen exposure analysis with historical trends, patterns, and personalized recommendations based on your scan history',
        ),
        const SizedBox(height: 12),
        buildCapabilityItem(
          'Educational Resources',
          'Comprehensive allergen information database with learning materials about allergy symptoms, prevention, and management strategies',
        ),
        const SizedBox(height: 12),
        buildCapabilityItem(
          'Personalized Detection',
          'Customizable allergen profiles with sensitivity tracking, exposure monitoring, and tailored alert preferences',
        ),
      ],
    );
  }

  Widget buildCapabilityItem(String title, String description) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGray.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.check_circle,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textBlack,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: AppColors.textGray,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildLimitationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSectionTitle('Important Considerations'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.moderate.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.moderate, size: 20),
                  const SizedBox(width: 12),
                  const Text(
                    'Performance Factors',
                    style: TextStyle(
                      color: AppColors.textBlack,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              buildLimitationItem(
                'Image quality and lighting conditions affect detection accuracy',
              ),
              buildLimitationItem(
                'OCR performance varies with font styles and label clarity',
              ),
              buildLimitationItem(
                'Requires stable internet connection for AI processing and air quality updates',
              ),
              buildLimitationItem(
                'Regional and uncommon foods may present detection challenges',
              ),
              buildLimitationItem(
                'Air quality data accuracy depends on local monitoring stations and API availability',
              ),
              buildLimitationItem(
                'Background notifications require proper permissions and may vary by device',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildLimitationItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.moderate,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textGray,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildContactSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightGray.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.contact_support, size: 32, color: AppColors.primary),
          const SizedBox(height: 16),
          const Text(
            'Support & Contact',
            style: TextStyle(
              color: AppColors.textBlack,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'We are dedicated to continuous improvement and value your feedback '
            'in enhancing our platform.',
            style: TextStyle(
              color: AppColors.textGray,
              fontSize: 14,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Icon(Icons.email, color: AppColors.primary, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Contact Support',
                        style: TextStyle(
                          color: AppColors.textBlack,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'alertgenn@gmail.com',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
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
    );
  }

  Widget buildFooter() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.health_and_safety,
            size: 32,
            color: AppColors.primary,
          ),
          const SizedBox(height: 12),
          const Text(
            'Committed to Comprehensive Allergy Safety',
            style: TextStyle(
              color: AppColors.textBlack,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Dedicated to creating a safer environment for individuals with allergies through intelligent detection, monitoring, and education',
            style: TextStyle(
              color: AppColors.textGray,
              fontSize: 13,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Last updated: ${DateTime.now().year}',
            style: TextStyle(
              color: AppColors.textGray.withOpacity(0.7),
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.textBlack,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    );
  }
}
