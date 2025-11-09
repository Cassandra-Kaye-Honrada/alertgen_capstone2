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
  late AnimationController _controller;
  late Animation<double> _widthAnimation;
  late Animation<double> _fadeAnimation;
  bool _isExpanded = false;
  bool _hasAnimated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _widthAnimation = Tween<double>(begin: 56.0, end: 150.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
      ),
    );

    // Start animation after widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasAnimated) {
        _startAnimationCycle();
      }
    });
  }

  void _startAnimationCycle() async {
    if (!mounted || _hasAnimated) return;

    _hasAnimated = true;

    // Small delay before starting
    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      // Expand to show text
      setState(() => _isExpanded = true);
      _controller.forward();

      // Wait 5 seconds while expanded
      await Future.delayed(const Duration(milliseconds: 5000));

      if (mounted) {
        // Collapse back to just logo
        _controller.reverse();
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          setState(() => _isExpanded = false);
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: _widthAnimation.value,
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
            backgroundColor: Colors.transparent,
            label: Container(
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(28)),
                gradient: LinearGradient(
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
                    if (_isExpanded) ...[
                      FadeTransition(
                        opacity: _fadeAnimation,
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
