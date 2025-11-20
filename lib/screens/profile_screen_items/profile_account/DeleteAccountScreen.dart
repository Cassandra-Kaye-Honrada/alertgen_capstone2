import 'package:allergen/screens/auth/login.dart';
import 'package:allergen/styleguide.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

class DeleteAccountScreen extends StatefulWidget {
  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen>
    with SingleTickerProviderStateMixin {
  final formKey = GlobalKey<FormState>();
  final passwordController = TextEditingController();
  final confirmationController = TextEditingController();

  bool obscurePassword = true;
  bool isLoading = false;
  bool isChecked1 = false;
  bool isChecked2 = false;
  bool isChecked3 = false;
  String? passwordError;
  bool isGoogleUser = false;

  late AnimationController animationController;
  late Animation<double> fadeAnimation;

  @override
  void initState() {
    super.initState();
    animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    fadeAnimation = CurvedAnimation(
      parent: animationController,
      curve: Curves.easeInOut,
    );
    animationController.forward();
    checkAuthProvider();
  }

  void checkAuthProvider() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      isGoogleUser = user.providerData.any(
        (info) => info.providerId == 'google.com',
      );
      setState(() {});
    }
  }

  @override
  void dispose() {
    animationController.dispose();
    passwordController.dispose();
    confirmationController.dispose();
    super.dispose();
  }

  Future<void> deleteAccount() async {
    if (!formKey.currentState!.validate()) return;

    if (!isChecked1 || !isChecked2 || !isChecked3) {
      showSnackBar('Please confirm all checkboxes', Colors.red);
      return;
    }

    if (confirmationController.text.trim().toUpperCase() != 'DELETE') {
      showSnackBar('Please type DELETE to confirm', Colors.red);
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.warning_rounded,
                    color: Colors.red.shade600,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Final Confirmation',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            content: const Text(
              'This action cannot be undone. Are you absolutely sure you want to delete your account?',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Delete Account',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
    );

    if (shouldDelete != true) return;

    setState(() => isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      if (isGoogleUser) {
        try {
          final GoogleSignIn googleSignIn = GoogleSignIn(scopes: ['email']);
          final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

          if (googleUser == null) {
            showSnackBar('Sign-in cancelled', Colors.orange);
            setState(() => isLoading = false);
            return;
          }

          final GoogleSignInAuthentication googleAuth =
              await googleUser.authentication;

          final credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );

          await user.reauthenticateWithCredential(credential);
        } catch (e) {
          showSnackBar('Google re-authentication failed', Colors.red);
          setState(() => isLoading = false);
          return;
        }
      } else {
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: passwordController.text,
        );

        await user.reauthenticateWithCredential(credential);
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .delete();

      try {
        await FirebaseStorage.instance
            .ref()
            .child('profile_images')
            .child(user.uid)
            .delete();
      } catch (e) {}

      await user.delete();

      if (isGoogleUser) {
        await GoogleSignIn().signOut();
      }

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => LoginScreen()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'wrong-password') {
          passwordError = 'Incorrect password';
        } else if (e.code == 'requires-recent-login') {
          passwordError =
              'Please log out and log back in before deleting your account';
        } else {
          passwordError = 'Authentication failed: ${e.message}';
        }
      });
      formKey.currentState!.validate();
    } catch (e) {
      showSnackBar('Error: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Poppins')),
        backgroundColor: color,
        behavior: SnackBarBehavior.fixed,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),

        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.defaultbackground,
      appBar: AppBar(
        backgroundColor: Colors.red.shade600,
        elevation: 0,
        title: const Text(
          'Delete Account',
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: FadeTransition(
                opacity: fadeAnimation,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        buildWarningCard(),
                        const SizedBox(height: 24),
                        buildDeletionInfoSection(),
                        const SizedBox(height: 24),
                        buildConfirmationSection(),
                        const SizedBox(height: 24),
                        if (!isGoogleUser) buildPasswordField(),
                        const SizedBox(height: 16),

                        buildConfirmationField(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          buildBottomButton(),
        ],
      ),
    );
  }

  Widget buildWarningCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade50, Colors.red.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.1),
            blurRadius: 10,
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.warning_rounded,
              color: Colors.red.shade700,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Permanent Action',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.red.shade900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'This action cannot be reversed. All your data will be permanently deleted.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: Colors.red.shade800,
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

  Widget buildDeletionInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.delete_outline,
                  color: Colors.red.shade600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'What will be deleted:',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          buildInfoItem(
            'Personal information and profile',
            Icons.person_outline,
          ),
          buildInfoItem(
            'Allergen preferences and history',
            Icons.medical_information_outlined,
          ),
          buildInfoItem('Saved products and scans', Icons.inventory_2_outlined),
          buildInfoItem('Account settings and data', Icons.settings_outlined),
        ],
      ),
    );
  }

  Widget buildInfoItem(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ),
          Icon(Icons.close, size: 18, color: Colors.red.shade400),
        ],
      ),
    );
  }

  Widget buildConfirmationSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.check_circle_outline,
                  color: Colors.orange.shade600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Please confirm:',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          buildCheckbox(
            value: isChecked1,
            onChanged: (val) => setState(() => isChecked1 = val!),
            label: 'I understand this action is permanent',
          ),
          buildCheckbox(
            value: isChecked2,
            onChanged: (val) => setState(() => isChecked2 = val!),
            label: 'I want to delete all my data',
          ),
          buildCheckbox(
            value: isChecked3,
            onChanged: (val) => setState(() => isChecked3 = val!),
            label: 'I confirm I want to proceed',
          ),
        ],
      ),
    );
  }

  Widget buildCheckbox({
    required bool value,
    required Function(bool?) onChanged,
    required String label,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color:
                  value
                      ? AppColors.primary.withOpacity(0.05)
                      : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color:
                    value
                        ? AppColors.primary.withOpacity(0.3)
                        : Colors.grey.shade200,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: value ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: value ? AppColors.primary : Colors.grey.shade400,
                      width: 2,
                    ),
                  ),
                  child:
                      value
                          ? const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 16,
                          )
                          : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: Colors.grey.shade800,
                      fontWeight: value ? FontWeight.w500 : FontWeight.w400,
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

  Widget buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Icon(Icons.lock_outline, size: 18, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Text(
                'Enter Your Password',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            controller: passwordController,
            obscureText: obscurePassword,
            decoration: InputDecoration(
              hintText: 'Confirm your identity',
              hintStyle: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.grey.shade400,
                fontSize: 14,
              ),
              prefixIcon: Icon(
                Icons.vpn_key,
                color: Colors.grey.shade400,
                size: 20,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey.shade600,
                  size: 20,
                ),
                onPressed:
                    () => setState(() => obscurePassword = !obscurePassword),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color:
                      passwordError != null ? Colors.red : Colors.grey.shade300,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color:
                      passwordError != null ? Colors.red : Colors.grey.shade200,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: passwordError != null ? Colors.red : AppColors.primary,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            validator: (value) {
              if (passwordError != null) return passwordError;
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              return null;
            },
            onChanged: (value) {
              if (passwordError != null) {
                setState(() => passwordError = null);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget buildConfirmationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Icon(Icons.text_fields, size: 18, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Text(
                'Type "DELETE" to confirm',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            controller: confirmationController,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
            decoration: InputDecoration(
              hintText: 'Type DELETE in capital letters',
              hintStyle: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.grey.shade400,
                fontSize: 14,
                fontWeight: FontWeight.normal,
                letterSpacing: 0,
              ),
              prefixIcon: Icon(
                Icons.edit_outlined,
                color: Colors.grey.shade400,
                size: 20,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please type DELETE to confirm';
              }
              if (value.toUpperCase() != 'DELETE') {
                return 'Must type DELETE exactly';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget buildBottomButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient:
                isLoading
                    ? null
                    : LinearGradient(
                      colors: [Colors.red.shade500, Colors.red.shade700],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
            boxShadow:
                isLoading
                    ? null
                    : [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
          ),
          child: ElevatedButton(
            onPressed: isLoading ? null : deleteAccount,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isLoading ? Colors.grey.shade300 : Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child:
                isLoading
                    ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.grey.shade600,
                        strokeWidth: 2.5,
                      ),
                    )
                    : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.delete_forever,
                          color: Colors.white,
                          size: 22,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Delete My Account',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
          ),
        ),
      ),
    );
  }
}
