import 'dart:async';
import 'package:allergen/screens/auth/signupscreen.dart';
import 'package:allergen/screens/splashscreen/onboarding.dart';
import 'package:allergen/styleguide.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;

  const VerifyEmailScreen({Key? key, required this.email}) : super(key: key);

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool isVerifying = false;
  String? statusMessage;

  @override
  void initState() {
    super.initState();
    checkIfGoogleUser();
  }

  Future<void> checkIfGoogleUser() async {
    final user = FirebaseAuth.instance.currentUser;
    final isGoogleUser =
        user?.providerData.any((p) => p.providerId == "google.com") ?? false;

    if (isGoogleUser) {
      if (mounted) {
        setState(() => isVerifying = true);
      }
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => OnboardingScreen()));
    }
  }

  Future<void> checkEmailVerified() async {
    if (!mounted) return;
    setState(() {
      isVerifying = true;
      statusMessage = null;
    });

    try {
      User? user = FirebaseAuth.instance.currentUser;

      await Future.delayed(const Duration(milliseconds: 500));

      for (int i = 0; i < 3; i++) {
        await user?.reload();
        user = FirebaseAuth.instance.currentUser;

        if (user != null && user.emailVerified) {
          break;
        }

        if (i < 2) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }

      if (!mounted) return;

      if (user != null && user.emailVerified) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => OnboardingScreen()),
        );
      } else {
        setState(() {
          statusMessage =
              'Email not verified yet. Please check your email and click the verification link first.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        statusMessage = 'Something went wrong. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          isVerifying = false;
        });
      }
    }
  }

  Future<void> resendVerificationEmail() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.sendEmailVerification();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification email resent. Please check your inbox.'),
          backgroundColor: Color(0xFF2563EB),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to resend: ${e.toString().contains('too-many-requests') ? 'Please wait a moment before trying again.' : 'An error occurred.'}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> handleBackToSignUp() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.delete();
      }
    } catch (e) {
      print('Failed to delete user: $e');
      try {
        await FirebaseAuth.instance.signOut();
      } catch (signOutError) {
        print('Failed to sign out: $signOutError');
      }
    } finally {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => SignUpScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isGoogleUser =
        user?.providerData.any((p) => p.providerId == "google.com") ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar:
          !isGoogleUser
              ? AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF1F2937)),
                  onPressed: handleBackToSignUp,
                ),
              )
              : null,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(32),
            constraints: BoxConstraints(minHeight: isGoogleUser ? 300 : 0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isGoogleUser)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        const SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 6,
                          ),
                        ),
                        const SizedBox(height: 32),
                        const Text(
                          "Verifying your account",
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Please wait while we verify your account...",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    children: [
                      const Icon(
                        Icons.email_outlined,
                        color: AppColors.primary,
                        size: 50,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Check your email',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'We sent a verification link to\n${widget.email}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black54,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 25),

                      if (statusMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.orange[700],
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  statusMessage!,
                                  style: TextStyle(
                                    color: Colors.orange[900],
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      ElevatedButton(
                        onPressed: isVerifying ? null : checkEmailVerified,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 5,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child:
                            isVerifying
                                ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: Colors.white,
                                  ),
                                )
                                : const Text(
                                  'I Verified My Email',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                      ),

                      const SizedBox(height: 24),

                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 14,
                          ),
                          children: [
                            const TextSpan(
                              text:
                                  "Didn't get the email? Please check your spam folder or ",
                            ),
                            TextSpan(
                              text: "Resend",
                              style: const TextStyle(
                                color: Color(0xFF2563EB),
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.w500,
                              ),
                              recognizer:
                                  TapGestureRecognizer()
                                    ..onTap = resendVerificationEmail,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
