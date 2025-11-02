import 'package:allergen/first_launch.dart';
import 'package:allergen/screens/auth/login.dart';
import 'package:flutter/material.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  int currentScreen = 0;
  late PageController pageController;
  late AnimationController pulseController;
  late Animation<double> pulseAnimation;

  @override
  void initState() {
    super.initState();
    pageController = PageController();
    pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    pageController.dispose();
    pulseController.dispose();
    super.dispose();
  }

  final List<OnboardingScreenData> screens = [
    OnboardingScreenData(
      id: 1,
      title: "Welcome to AlertGen",
      description: "Your personal food safety companion",
      iconType: OnboardingIconType.logo,
    ),
    OnboardingScreenData(
      id: 2,
      title: "Scan Any Food",
      description:
          "Use your camera or upload to scan food labels, meals, or ingredients and instantly check for allergens.",
      iconType: OnboardingIconType.camera,
    ),
    OnboardingScreenData(
      id: 3,
      title: "Personalized Alerts",
      description:
          "Set your allergies and get personalized alerts when a food contains ingredients you should avoid.",
      iconType: OnboardingIconType.alert,
    ),
    OnboardingScreenData(
      id: 4,
      title: "Safe Food History",
      description:
          "Keep track of your previous scans and build a history of safe foods you can eat.",
      iconType: OnboardingIconType.history,
    ),
  ];

  void nextScreen() {
    if (currentScreen < screens.length - 1) {
      setState(() {
        currentScreen++;
      });
      pageController.animateToPage(
        currentScreen,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void goToScreen(int index) {
    setState(() {
      currentScreen = index;
    });
    pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void handleGetStarted() async {
    await AppPreferences.setLaunched();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F9FF),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: handleGetStarted,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF027A9B).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF027A9B),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: pageController,
                onPageChanged: (index) {
                  setState(() {
                    currentScreen = index;
                  });
                },
                itemCount: screens.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          screens[index].title,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3748),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        buildIcon(screens[index].iconType),
                        const SizedBox(height: 32),
                        Text(
                          screens[index].description,
                          style: const TextStyle(
                            fontSize: 18,
                            color: Color(0xFF667085),
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(screens.length, (index) {
                  return GestureDetector(
                    onTap: () => goToScreen(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 12,
                      width: index == currentScreen ? 32 : 12,
                      decoration: BoxDecoration(
                        color:
                            index == currentScreen
                                ? const Color(0xFF027A9B)
                                : const Color(0xFFD2D4D6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  );
                }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
              child: GestureDetector(
                onTap: () {
                  if (currentScreen == screens.length - 1) {
                    handleGetStarted();
                  } else {
                    nextScreen();
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF027A9B),
                        Color(0xFF02B3AB),
                        Color(0xFF1AA2CC),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF027A9B).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Text(
                    currentScreen == screens.length - 1
                        ? 'Get Started'
                        : 'Continue',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildIcon(OnboardingIconType iconType) {
    switch (iconType) {
      case OnboardingIconType.logo:
        return Container(
          width: 128,
          height: 128,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              'assets/images/logo.png',
              width: 128,
              height: 128,
              fit: BoxFit.contain,
            ),
          ),
        );

      case OnboardingIconType.camera:
        return Stack(
          children: [
            Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF027A9B), Color(0xFF1AA2CC)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.camera_alt,
                size: 64,
                color: Colors.white,
              ),
            ),
            Positioned(
              bottom: -8,
              right: -8,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF02B3AB),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(Icons.upload, size: 24, color: Colors.white),
              ),
            ),
          ],
        );

      case OnboardingIconType.alert:
        return Stack(
          children: [
            Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFB22222), Color(0xFFFFC700)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(Icons.warning, size: 64, color: Colors.white),
            ),
            Positioned(
              top: -8,
              right: -8,
              child: AnimatedBuilder(
                animation: pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: pulseAnimation.value,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFC700),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.security,
                        size: 24,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );

      case OnboardingIconType.history:
        return Stack(
          children: [
            Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF027A9B), Color(0xFF8EBFCE)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(Icons.history, size: 64, color: Colors.white),
            ),
            Positioned(
              bottom: -8,
              right: -8,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF5CC520),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(Icons.check, size: 24, color: Colors.white),
              ),
            ),
          ],
        );
    }
  }
}

class OnboardingScreenData {
  final int id;
  final String title;
  final String description;
  final OnboardingIconType iconType;

  OnboardingScreenData({
    required this.id,
    required this.title,
    required this.description,
    required this.iconType,
  });
}

enum OnboardingIconType { logo, camera, alert, history }
