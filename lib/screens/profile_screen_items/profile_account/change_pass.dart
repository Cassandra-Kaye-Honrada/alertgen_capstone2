import 'package:allergen/screens/auth/login.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:allergen/styleguide.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({Key? key}) : super(key: key);

  @override
  State<ChangePasswordScreen> createState() => ChangePasswordScreenState();
}

class ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final formKey = GlobalKey<FormState>();
  final TextEditingController currentPasswordController =
      TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool isLoading = false;
  bool isGoogleUser = false;
  bool obscureCurrentPassword = true;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  User? user;

  String? currentPasswordError;
  String? newPasswordError;

  @override
  void initState() {
    super.initState();
    checkIfGoogleUser();
  }

  Future<void> checkIfGoogleUser() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() {
      user = currentUser;
      isGoogleUser = currentUser.providerData.any(
        (p) => p.providerId == "google.com",
      );
    });
  }

  String? validatePasswordStrength(String password) {
    if (password.isEmpty) return "Please enter a password";
    if (password.length < 6) return "Password must be at least 6 characters";

    bool hasUppercase = password.contains(RegExp(r'[A-Z]'));
    bool hasLowercase = password.contains(RegExp(r'[a-z]'));
    bool hasDigits = password.contains(RegExp(r'[0-9]'));
    bool hasSpecialCharacters = password.contains(
      RegExp(r'[!@#$%^&*(),.?":{}|<>]'),
    );

    List<String> commonWeak = [
      '123456',
      'password',
      'qwerty',
      '111111',
      'abc123',
    ];
    if (commonWeak.contains(password.toLowerCase()))
      return "This password is too common and weak";

    if (RegExp(r'(.)\1{2,}').hasMatch(password))
      return "Password should not have repeated characters";

    if (!hasUppercase || !hasLowercase || !hasDigits)
      return "Password should contain uppercase, lowercase letters and numbers";

    return null;
  }

  Future<void> changePassword() async {
    if (isGoogleUser) {
      showSnackBar(
        "Cannot change password for Google accounts. Please update via Google Account settings.",
        isSuccess: false,
      );
      return;
    }

    final shouldProceed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              "Confirm Password Change",
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
              ),
            ),
            content: const Text(
              "Are you sure you want to update your password?",
              style: TextStyle(fontFamily: 'Poppins', fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text(
                  "Cancel",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: AppColors.primary,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text(
                  "Confirm",
                  style: TextStyle(fontFamily: 'Poppins', color: Colors.white),
                ),
              ),
            ],
          ),
    );

    if (shouldProceed != true) return;

    setState(() {
      currentPasswordError = null;
      newPasswordError = null;
    });

    if (!formKey.currentState!.validate()) return;

    final currentPassword = currentPasswordController.text.trim();
    final newPassword = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (newPassword != confirmPassword) {
      setState(() {
        newPasswordError = "Passwords do not match";
      });
      return;
    }

    final passwordStrengthError = validatePasswordStrength(newPassword);
    if (passwordStrengthError != null) {
      setState(() {
        newPasswordError = passwordStrengthError;
      });
      return;
    }

    if (user?.email == null) {
      setState(() {
        currentPasswordError = "No email associated with this account";
      });
      return;
    }

    setState(() => isLoading = true);

    try {
      final credential = EmailAuthProvider.credential(
        email: user!.email!,
        password: currentPassword,
      );

      await user!.reauthenticateWithCredential(credential);
      await user!.reload();

      await user!.updatePassword(newPassword);

      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
        'passwordUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('saved_email');
      if (savedEmail != null &&
          savedEmail.toLowerCase() == user!.email!.toLowerCase()) {
        await prefs.setBool('remember_me', false);
        await prefs.setBool('auto_login', false);
        await prefs.remove('saved_email');
        await prefs.remove('saved_password');
      }

      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (context) => LoginScreen()));
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        setState(() {
          currentPasswordError = "Current password is incorrect";
        });
        formKey.currentState!.validate();
      } else if (e.code == 'weak-password') {
        setState(() {
          newPasswordError = "New password is too weak. Use a stronger one.";
        });
        formKey.currentState!.validate();
      } else if (e.code == 'requires-recent-login') {
        showSnackBar(
          "Your session expired. Please log out and log in again, then try changing your password.",
          isSuccess: false,
        );
      } else {
        showSnackBar(
          "Failed to update password: ${e.message ?? "Unknown error"}",
          isSuccess: false,
        );
      }
    } catch (e) {
      showSnackBar("Unexpected error: $e", isSuccess: false);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;

    final username = parts[0];
    final domain = parts[1];

    final visible = username.length > 2 ? username.substring(0, 2) : username;
    final maskedUsername = visible + '*' * (username.length - visible.length);

    return '$maskedUsername@$domain';
  }

  Future<void> forgotPassword() async {
    if (user?.email != null) {
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: user!.email!);

        if (!mounted) return;
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text("Password Reset Email Sent"),
                content: Text(
                  "We’ve sent a reset link to ${maskEmail(user!.email!)}. Please check your inbox.",
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text("OK"),
                  ),
                ],
              ),
        );
      } catch (e) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text("Error"),
                content: Text("Failed to send reset email: $e"),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text("OK"),
                  ),
                ],
              ),
        );
      }
    }
  }

  void showSnackBar(String message, {required bool isSuccess}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle_outline : Icons.error_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor:
            isSuccess ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
        duration: const Duration(seconds: 4),
        elevation: 6,
      ),
    );
  }

  @override
  void dispose() {
    currentPasswordController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.defaultbackground,
      appBar: buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: isGoogleUser ? buildGoogleUserUI() : buildManualUserUI(),
              ),
            ),
            if (!isGoogleUser) buildBottomButton(),
          ],
        ),
      ),
    );
  }

  AppBar buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.primary,
      elevation: 0,
      title: const Text(
        'Change Password',
        style: TextStyle(
          fontFamily: 'Poppins',
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      centerTitle: true,
    );
  }

  Widget buildGoogleUserUI() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 60),
          buildGoogleIcon(),
          const SizedBox(height: 24),
          buildGoogleUserInfo(),
          const SizedBox(height: 32),
          buildInfoCard(),
          const SizedBox(height: 32),
          buildGoogleAccountButton(),
        ],
      ),
    );
  }

  Widget buildGoogleIcon() {
    return Container(
      width: 100,
      height: 100,

      child: Icon(Icons.account_circle, size: 80, color: AppColors.primary),
    );
  }

  Widget buildGoogleUserInfo() {
    return Column(
      children: [
        const Text(
          "Signed in with Google",
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D3748),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          user?.email ?? "Unknown email",
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            color: Color(0xFF4A5568),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3CD),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Icon(
              Icons.info_outline,
              size: 32,
              color: Color(0xFFFF9800),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Password Management",
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "To change your password, please update it in your Google Account settings. This ensures your security across all Google services.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15,
              color: Color(0xFF718096),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildGoogleAccountButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: () async {
          final url = Uri.parse("https://myaccount.google.com/security");
          if (await canLaunchUrl(url))
            await launchUrl(url, mode: LaunchMode.externalApplication);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.open_in_new, size: 20, color: Colors.white),
        label: const Text(
          "Open Google Account Settings",
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget buildManualUserUI() {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          buildHeader(),
          const SizedBox(height: 32),
          buildCurrentPasswordField(),
          const SizedBox(height: 24),
          buildPasswordField(),
          const SizedBox(height: 24),
          buildConfirmPasswordField(),
          const SizedBox(height: 5),
          buildForgotPasswordSection(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(Icons.security, color: AppColors.primary, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              "Your password must be at least 6 characters and should include uppercase, lowercase letters, numbers, and special characters.",
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildCurrentPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            "Current Password",
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
        ),
        TextFormField(
          controller: currentPasswordController,
          obscureText: obscureCurrentPassword,
          decoration: InputDecoration(
            hintText: "Enter your current password",
            hintStyle: TextStyle(
              fontFamily: 'Poppins',
              color: Colors.grey.shade500,
              fontSize: 14,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                obscureCurrentPassword
                    ? Icons.visibility_off
                    : Icons.visibility,
                color: Colors.grey.shade600,
                size: 20,
              ),
              onPressed:
                  () => setState(
                    () => obscureCurrentPassword = !obscureCurrentPassword,
                  ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color:
                    currentPasswordError != null
                        ? Colors.red
                        : Colors.grey.shade300,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color:
                    currentPasswordError != null
                        ? Colors.red
                        : AppColors.primary,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.all(16),
          ),
          validator: (value) {
            if (currentPasswordError != null) return currentPasswordError;
            if (value == null || value.isEmpty)
              return "Please enter your current password";
            return null;
          },
          onChanged: (value) {
            if (currentPasswordError != null)
              setState(() => currentPasswordError = null);
          },
        ),
      ],
    );
  }

  Widget buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            "New Password",
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
        ),
        TextFormField(
          controller: passwordController,
          obscureText: obscurePassword,
          decoration: InputDecoration(
            hintText: "Enter at least 6 characters",
            hintStyle: TextStyle(
              fontFamily: 'Poppins',
              color: Colors.grey.shade500,
              fontSize: 14,
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
                    newPasswordError != null
                        ? Colors.red
                        : Colors.grey.shade300,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color:
                    newPasswordError != null ? Colors.red : AppColors.primary,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.all(16),
          ),
          validator: (value) {
            if (newPasswordError != null) return newPasswordError;
            if (value == null || value.isEmpty)
              return "Please enter a password";
            if (value.length < 6)
              return "Password must be at least 6 characters";
            if (value == currentPasswordController.text)
              return "New password must be different from current password";
            return validatePasswordStrength(value);
          },
          onChanged: (value) {
            if (newPasswordError != null)
              setState(() => newPasswordError = null);
          },
        ),
      ],
    );
  }

  Widget buildConfirmPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            "Confirm New Password",
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
        ),
        TextFormField(
          controller: confirmPasswordController,
          obscureText: obscureConfirmPassword,
          decoration: InputDecoration(
            hintText: "Re-enter your new password",
            hintStyle: TextStyle(
              fontFamily: 'Poppins',
              color: Colors.grey.shade500,
              fontSize: 14,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                obscureConfirmPassword
                    ? Icons.visibility_off
                    : Icons.visibility,
                color: Colors.grey.shade600,
                size: 20,
              ),
              onPressed:
                  () => setState(
                    () => obscureConfirmPassword = !obscureConfirmPassword,
                  ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.all(16),
          ),
          validator: (value) {
            if (value == null || value.isEmpty)
              return "Please confirm your password";
            if (value != passwordController.text)
              return "Passwords do not match";
            return null;
          },
        ),
      ],
    );
  }

  Widget buildForgotPasswordSection() {
    return Center(
      child: TextButton(
        onPressed: forgotPassword,
        child: Text(
          "Forgot Password?",
          style: TextStyle(
            fontFamily: 'Poppins',
            color: AppColors.primary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget buildBottomButton() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient:
              isLoading
                  ? null
                  : LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withOpacity(0.8),
                    ],
                  ),
          boxShadow:
              isLoading
                  ? null
                  : [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : changePassword,
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
                  : const Text(
                    "Update Password",
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
        ),
      ),
    );
  }
}
