import 'package:allergen/first_launch.dart';
import 'package:allergen/screens/feature/homescreen.dart';
import 'package:allergen/screens/auth/login.dart';
import 'package:allergen/screens/splashscreen/onboarding.dart';
import 'package:allergen/screens/splashscreen/onboarding_screen.dart';
import 'package:allergen/screens/auth/verify_google.dart';
import 'package:allergen/screens/splashscreen/animation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class AuthWrapper extends StatefulWidget {
  @override
  _AuthWrapperState createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool isInitializing = true;
  Widget? targetScreen;
  StreamSubscription<User?>? authState;

  @override
  void initState() {
    super.initState();
    initializeApp();
  }

  @override
  void dispose() {
    authState?.cancel();
    super.dispose();
  }

  Future<void> initializeApp() async {
    try {
      await Future.wait([
        Future.delayed(Duration(seconds: 3)),
        determineInitialScreen(),
      ]);

      if (mounted) {
        setState(() {
          isInitializing = false;
        });
      }
    } catch (e) {
      print('Error initializing app: $e');
      if (mounted) {
        setState(() {
          targetScreen = LoginScreen();
          isInitializing = false;
        });
      }
    }
  }

  Future<void> determineInitialScreen() async {
    try {
      bool isFirstLaunch = await AppPreferences.isFirstLaunch();

      if (isFirstLaunch) {
        targetScreen = WelcomeScreen();
        return;
      }

      User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        targetScreen = LoginScreen();

        authState = FirebaseAuth.instance
            .authStateChanges()
            .listen(handleAuthStateChange);
        return;
      }

      await handleLoggedInUser(currentUser);
    } catch (e) {
      print('Error determining initial screen: $e');
      targetScreen = LoginScreen();
    }
  }

  void handleAuthStateChange(User? user) async {
    if (!mounted) return;

    if (user != null) {
      await handleLoggedInUser(user);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => targetScreen ?? LoginScreen()),
        );
      }
    } else {
      if (mounted) {
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => LoginScreen()));
      }
    }
  }

  Future<void> handleLoggedInUser(User user) async {
    try {
      if (!user.emailVerified) {
        targetScreen = VerifyEmailScreen(email: user.email ?? 'your email');
        return;
      }

      bool hasCompletedOnboarding = await checkIfCompletedOnboarding();

      if (hasCompletedOnboarding) {
        targetScreen = Homescreen();
      } else {
        targetScreen = OnboardingScreen();
      }
    } catch (e) {
      print('Error handling logged in user: $e');
      targetScreen = LoginScreen();
    }
  }

  Future<bool> checkIfCompletedOnboarding() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        QuerySnapshot allergenSnapshot =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('profile')
                .where('type', isEqualTo: 'allergen')
                .limit(1)
                .get();

        return allergenSnapshot.docs.isNotEmpty;
      }
      return false;
    } catch (e) {
      print('Error checking onboarding: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isInitializing) {
      return SplashScreen();
    }

    return targetScreen ?? LoginScreen();
  }
}
