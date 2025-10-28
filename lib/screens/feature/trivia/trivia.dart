import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AnalysisTrivia extends StatefulWidget {
  final String analysisType;
  final VoidCallback? onTriviaLoaded;
  final int delaySeconds; // New parameter to control delay

  const AnalysisTrivia({
    Key? key,
    required this.analysisType,
    this.onTriviaLoaded,
    this.delaySeconds = 3, // Default to 3 seconds delay
  }) : super(key: key);

  @override
  State<AnalysisTrivia> createState() => _AnalysisTriviaState();
}

class _AnalysisTriviaState extends State<AnalysisTrivia>
    with SingleTickerProviderStateMixin {
  String currentTrivia = '';
  bool isLoading = true;
  bool showTrivia = false;
  Timer? triviaTimer;
  Timer? delayTimer;
  int triviaIndex = 0;
  List<String> triviaList = [];
  late AnimationController fadeController;
  late Animation<double> fadeAnimation;

  static const Color primaryTeal = Color(0xFF00A99D);
  static const Color darkTeal = Color(0xFF008B8B);
  // static const Color lightTeal = Color(0xFF4DD0E1);

  final List<String> fallbackFoodTrivia = [
    "🥘 Kare-Kare's peanut sauce makes it unsafe for people with peanut allergies!",
    "🦐 Bagoong (shrimp paste) is a common hidden allergen in Filipino dishes like Pinakbet.",
    "🍜 Lucky Me! Pancit Canton contains wheat and soy - two of the top 9 FDA allergens.",
    "🥚 Leche Flan contains eggs and milk - be careful if you're allergic!",
    "🌾 Lumpia wrappers are made from wheat flour, making them unsafe for gluten allergies.",
    "🐟 Patis (fish sauce) is hidden in many Filipino dishes and can trigger fish allergies.",
    "🥥 Coconut is technically a fruit, not a tree nut, so it's safe for most nut allergy sufferers!",
    "🍖 Adobo typically contains soy sauce - a major allergen for people with soy allergies.",
    "🧀 Filipino spaghetti often contains dairy products like cheese and milk.",
    "🥜 Peanuts are one of the most common severe allergens and can cause anaphylaxis.",
    "🍲 Sinigang often contains shrimp or fish - always check before eating if you have seafood allergies!",
    "🌰 Cashews (kasuy) are tree nuts and can cause severe allergic reactions.",
    "🥛 Condensed milk in Filipino desserts like Halo-Halo contains dairy allergens.",
    "🍤 Ukoy (shrimp fritters) contains both shellfish and wheat - double allergen alert!",
    "🍚 Champorado sometimes has milk added - check if you're lactose intolerant or allergic to dairy.",
  ];

  final List<String> fallbackSkinTrivia = [
    "🔴 Food allergies can show up on your skin within minutes to 2 hours after eating!",
    "🩺 Hives (urticaria) are the most common skin reaction to food allergies.",
    "🥜 Peanut allergies often cause skin reactions like rashes and swelling.",
    "🦐 Shellfish allergies can cause severe skin reactions including angioedema.",
    "🧬 Atopic dermatitis (eczema) can be triggered by foods like milk, eggs, and peanuts.",
    "⚠️ If you experience facial swelling, seek emergency medical help immediately!",
    "🍳 Egg allergies commonly cause skin reactions, especially in children.",
    "🥛 Milk allergies can cause skin rashes and itching around the mouth area.",
    "🌡️ Flushing (sudden redness) can indicate a food allergic reaction in progress.",
    "🚨 If your skin reaction comes with breathing difficulty, call emergency services!",
    "💊 Antihistamines can help with mild allergic skin reactions, but severe cases need epinephrine.",
    "🔬 Contact dermatitis occurs when food physically touches your skin, common with citrus fruits.",
    "🩹 Scratching allergic rashes can lead to infection - try to avoid it!",
    "🧴 Keep your skin moisturized if you have food allergy-related eczema.",
    "📋 Keep a food diary to track which foods trigger your skin reactions.",
  ];

  @override
  void initState() {
    super.initState();
    fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: fadeController, curve: Curves.easeInOut));

    loadTrivia();
  }

  @override
  void dispose() {
    triviaTimer?.cancel();
    delayTimer?.cancel();
    fadeController.dispose();
    super.dispose();
  }

  Future<void> populateFirebaseTrivia() async {
    try {
      final firestore = FirebaseFirestore.instance;

      final foodBatch = firestore.batch();
      for (int i = 0; i < fallbackFoodTrivia.length; i++) {
        final docRef = firestore.collection('food_trivia').doc();
        foodBatch.set(docRef, {
          'text': fallbackFoodTrivia[i],
          'order': i + 1,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await foodBatch.commit();

      final skinBatch = firestore.batch();
      for (int i = 0; i < fallbackSkinTrivia.length; i++) {
        final docRef = firestore.collection('skin_trivia').doc();
        skinBatch.set(docRef, {
          'text': fallbackSkinTrivia[i],
          'order': i + 1,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await skinBatch.commit();
      print('Skin trivia populated: ${fallbackSkinTrivia.length} items');

      print('All trivia successfully added to Firebase!');
    } catch (e) {
      print('Error populating Firebase: $e');
    }
  }

  Future<void> loadTrivia() async {
    delayTimer = Timer(Duration(seconds: widget.delaySeconds), () {
      if (mounted) {
        setState(() {
          showTrivia = true;
        });
        fadeController.forward();
        startTriviaRotation();
      }
    });

    try {
      final collection =
          widget.analysisType == 'food' ? 'food_trivia' : 'skin_trivia';

      final snapshot = await FirebaseFirestore.instance
          .collection(collection)
          .orderBy('order')
          .get()
          .timeout(const Duration(seconds: 5));

      if (snapshot.docs.isNotEmpty && mounted) {
        final firebaseTrivia =
            snapshot.docs.map((doc) => doc.data()['text'] as String).toList();

        if (firebaseTrivia.isNotEmpty) {
          if (mounted) {
            setState(() {
              triviaList = firebaseTrivia;
              triviaIndex = 0;
              currentTrivia = triviaList[0];
              isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      print('Error loading Firebase trivia: $e');
      print('ℹ Using fallback trivia instead');
      useFallbackTrivia();
    }

    widget.onTriviaLoaded?.call();
  }

  void useFallbackTrivia() {
    final fallbackList =
        widget.analysisType == 'food' ? fallbackFoodTrivia : fallbackSkinTrivia;

    setState(() {
      triviaList = List.from(fallbackList)..shuffle();
      currentTrivia = triviaList[0];
      isLoading = false;
    });
  }

  void startTriviaRotation() {
    triviaTimer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (mounted && triviaList.isNotEmpty && showTrivia) {
        fadeController.reverse().then((_) {
          if (mounted) {
            setState(() {
              triviaIndex = (triviaIndex + 1) % triviaList.length;
              currentTrivia = triviaList[triviaIndex];
            });
            fadeController.forward();
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading || !showTrivia) {
      return const SizedBox.shrink();
    }

    return FadeTransition(
      opacity: fadeAnimation,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [primaryTeal.withOpacity(0.95), darkTeal.withOpacity(0.95)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: primaryTeal.withOpacity(0.3),
              blurRadius: 16,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Icon(
                widget.analysisType == 'food'
                    ? Icons.info_outline_rounded
                    : Icons.health_and_safety_outlined,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        widget.analysisType == 'food'
                            ? 'Did You Know?'
                            : 'Health Insight',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.analysisType == 'food' ? '🇵🇭' : '💡',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    currentTrivia,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                      letterSpacing: 0.2,
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
}
