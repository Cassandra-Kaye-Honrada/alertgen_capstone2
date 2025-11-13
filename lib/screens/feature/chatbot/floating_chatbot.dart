import 'package:allergen/screens/feature/chatbot/chatbot.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FloatingChatbotButton extends StatefulWidget {
  const FloatingChatbotButton({Key? key}) : super(key: key);

  @override
  _FloatingChatbotButtonState createState() => _FloatingChatbotButtonState();
}

class _FloatingChatbotButtonState extends State<FloatingChatbotButton>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;
  late Animation<double> widthAnimation;
  late Animation<double> fadeAnimation;
  bool isExpanded = false;
  bool hasAnimated = false;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    widthAnimation = Tween<double>(begin: 56.0, end: 150.0).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeInOutCubic),
    );

    fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!hasAnimated) {
        startAnimationCycle();
      }
    });
  }

  void startAnimationCycle() async {
    if (!mounted || hasAnimated) return;

    hasAnimated = true;

    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      setState(() => isExpanded = true);
      controller.forward();

      await Future.delayed(const Duration(milliseconds: 5000));

      if (mounted) {
        controller.reverse();
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          setState(() => isExpanded = false);
        }
      }
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return SizedBox(
          width: widthAnimation.value,
          height: 56.0,
          child: FloatingActionButton.extended(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => ChatbotModal(),
              );
            },
            elevation: 0.0,
            highlightElevation: 0.0,
            backgroundColor: Colors.transparent,
            label: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E7A8C).withOpacity(0.3),
                    spreadRadius: 1,
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF2B9EB3), Color(0xFF1E7A8C)],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 12.0,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isExpanded) ...[
                      FadeTransition(
                        opacity: fadeAnimation,
                        child: const Text(
                          'Ask Allei',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Image.asset(
                      'assets/images/Allei.png',
                      width: 28,
                      height: 28,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
