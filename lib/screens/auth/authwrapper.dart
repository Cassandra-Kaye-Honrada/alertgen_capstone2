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
  bool showSplash = false;
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
      User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        bool isFirstLaunch = await AppPreferences.isFirstLaunch();

        if (isFirstLaunch) {
          if (!mounted) return;
          setState(() {
            showSplash = true;
            targetScreen = WelcomeScreen();
          });

          await Future.delayed(Duration(seconds: 3));

          if (!mounted) return;
          setState(() {
            isInitializing = false;
          });
          return;
        }

        if (!mounted) return;
        setState(() {
          showSplash = false;
          targetScreen = LoginScreen();
          isInitializing = false;
        });

        authState = FirebaseAuth.instance.authStateChanges().listen(
          handleAuthStateChange,
        );
        return;
      }

      if (!mounted) return;
      setState(() {
        showSplash = true;
      });

      await Future.delayed(Duration(seconds: 3));

      if (!mounted) return;
      await handleLoggedInUser(currentUser);

      if (!mounted) return;
      setState(() {
        isInitializing = false;
      });
    } catch (e) {
      print('Error initializing app: $e');
      if (!mounted) return;
      setState(() {
        showSplash = false;
        targetScreen = LoginScreen();
        isInitializing = false;
      });
    }
  }

  void handleAuthStateChange(User? user) async {
    if (!mounted) return;

    if (user != null) {
      await handleLoggedInUser(user);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => targetScreen ?? LoginScreen()),
      );
    } else {
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => LoginScreen()));
    }
  }

  Future<void> handleLoggedInUser(User user) async {
    try {
      if (!user.emailVerified) {
        if (!mounted) return;
        setState(() {
          targetScreen = VerifyEmailScreen(email: user.email ?? 'your email');
        });
        return;
      }

      bool hasCompletedOnboarding = await checkIfCompletedOnboarding();

      if (!mounted) return;
      setState(() {
        if (hasCompletedOnboarding) {
          targetScreen = Homescreen();
        } else {
          targetScreen = OnboardingScreen();
        }
      });
    } catch (e) {
      print('Error handling logged in user: $e');
      if (!mounted) return;
      setState(() {
        targetScreen = LoginScreen();
      });
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
      if (showSplash) {
        return SplashScreen();
      } else {
        return LoginScreen();
      }
    }

    return targetScreen ?? LoginScreen();
  }
}