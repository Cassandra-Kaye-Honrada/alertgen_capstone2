import 'dart:async';

import 'package:allergen/screens/auth/authwrapper.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  bool logoVisible = false;
  bool wavesVisible = false;
  bool iconsVisible = false;

  double logoScale = 0.0;
  double logoOpacity = 0.0;
  double waveScale = 0.5;
  double rotation = 0.0;

  late AnimationController rotationController;
  late AnimationController waveController;
  late AnimationController pulseController;

  late Animation<double> waveAnimation;
  late Animation<double> pulseAnimation;

  @override
  void initState() {
    super.initState();

    rotationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 12),
    );

    waveController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 3),
    );

    pulseController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );

    waveAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: waveController, curve: Curves.easeInOut),
    );

    pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: pulseController, curve: Curves.easeInOut),
    );

    rotationController.addListener(() {
      if (!mounted) return;
      setState(() {
        rotation = rotationController.value * 2 * math.pi;
      });
    });

    waveController.addListener(() {
      if (mounted) {
        setState(() {
          waveScale = wavesVisible ? waveAnimation.value : 0.5;
        });
      }
    });

    pulseController.addListener(() {
      if (mounted) {
        if (logoVisible) logoScale = pulseAnimation.value;
      }
    });

    startAnimationSequence();
    navigateAfterDelay();
  }

  void startAnimationSequence() async {
    await Future.delayed(Duration(milliseconds: 300));
    if (!mounted) return;

    setState(() {
      logoVisible = true;
      logoScale = 1.0;
      logoOpacity = 1.0;
    });

    pulseController.repeat(reverse: true);

    await Future.delayed(Duration(milliseconds: 600));
    if (!mounted) return;

    setState(() {
      wavesVisible = true;
    });
    waveController.repeat(reverse: true);

    await Future.delayed(Duration(milliseconds: 800));
    if (!mounted) return;

    setState(() {
      iconsVisible = true;
    });

    rotationController.repeat();
  }

  Timer? _navigationTimer;

  void navigateAfterDelay() {
    _navigationTimer = Timer(Duration(seconds: 5), () {
      if (!mounted) return;

      rotationController.stop();
      waveController.stop();
      pulseController.stop();

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder:
              (context, animation, secondaryAnimation) => AuthWrapper(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: Duration(milliseconds: 500),
        ),
      );
    });
  }

  @override
  void dispose() {
    rotationController.stop();
    waveController.stop();
    pulseController.stop();

    rotationController.dispose();
    waveController.dispose();
    pulseController.dispose();

    _navigationTimer?.cancel(); 

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF14B8A6), Color(0xFF0891B2), Color(0xFF1E40AF)],
          ),
        ),
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedOpacity(
                duration: Duration(milliseconds: 800),
                curve: Curves.easeInOut,
                opacity: wavesVisible ? 1.0 : 0.0,
                child: Stack(
                  alignment: Alignment.center,
                  children: List.generate(4, (index) {
                    return buildDetectionWave(index);
                  }),
                ),
              ),
              AnimatedOpacity(
                duration: Duration(milliseconds: 1000),
                curve: Curves.easeInOut,
                opacity: iconsVisible ? 1.0 : 0.0,
                child: Transform.rotate(
                  angle: rotation,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      buildOrbitingIcon('assets/allergens/Eggs.png', 0, 180),
                      buildOrbitingIcon(
                        'assets/allergens/Gluten.png',
                        math.pi / 4,
                        150,
                      ),
                      buildOrbitingIcon(
                        'assets/allergens/Milk.png',
                        math.pi / 2,
                        170,
                      ),
                      buildOrbitingIcon(
                        'assets/allergens/Nuts.png',
                        3 * math.pi / 4,
                        160,
                      ),
                      buildOrbitingIcon(
                        'assets/allergens/Cashew.png',
                        math.pi,
                        190,
                      ),
                      buildOrbitingIcon(
                        'assets/allergens/Soy Bean.png',
                        5 * math.pi / 4,
                        165,
                      ),
                      buildOrbitingIcon(
                        'assets/allergens/Fish.png',
                        3 * math.pi / 2,
                        175,
                      ),
                      buildOrbitingIcon(
                        'assets/allergens/Crab.png',
                        7 * math.pi / 4,
                        155,
                      ),
                      buildOrbitingIcon(
                        'assets/allergens/Sesame.png',
                        2 * math.pi,
                        185,
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedOpacity(
                duration: Duration(milliseconds: 1200),
                curve: Curves.easeInOut,
                opacity: logoOpacity,
                child: AnimatedScale(
                  duration: Duration(milliseconds: 1500),
                  curve: Curves.elasticOut,
                  scale: logoScale,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 25,
                          offset: Offset(0, 12),
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: Colors.white.withOpacity(0.8),
                          blurRadius: 10,
                          offset: Offset(0, -5),
                          spreadRadius: -5,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 80,
                        height: 80,
                      ),
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

  Widget buildDetectionWave(int index) {
    double baseRadius = 100 + (index * 40);
    return AnimatedContainer(
      duration: Duration(milliseconds: 1200 + (index * 200)),
      curve: Curves.easeOutBack,
      width: wavesVisible ? baseRadius * 2 * waveScale : 0,
      height: wavesVisible ? baseRadius * 2 * waveScale : 0,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withOpacity(0.7 - (index * 0.15)),
          width: 2.5,
        ),
      ),
    );
  }

  Widget buildOrbitingIcon(String assetPath, double angle, double radius) {
    double x = radius * math.cos(angle);
    double y = radius * math.sin(angle);

    return Transform.translate(
      offset: Offset(x, y),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 800),
        curve: Curves.easeOutBack,
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              offset: Offset(0, 3),
              spreadRadius: 1,
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.6),
              blurRadius: 5,
              offset: Offset(0, -2),
              spreadRadius: -2,
            ),
          ],
        ),
        child: AnimatedScale(
          duration: Duration(milliseconds: 600),
          curve: Curves.easeOutBack,
          scale: iconsVisible ? 1.0 : 0.0,
          child: Padding(
            padding: EdgeInsets.all(8.0),
            child: Image.asset(assetPath, width: 24, height: 24),
          ),
        ),
      ),
    );
  }
}
