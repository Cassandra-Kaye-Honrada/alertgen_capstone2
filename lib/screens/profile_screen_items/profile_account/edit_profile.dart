import 'dart:io';
import 'package:allergen/styleguide.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditProfileDetailsScreen extends StatefulWidget {
  @override
  State<EditProfileDetailsScreen> createState() =>
      _EditProfileDetailsScreenState();
}

class _EditProfileDetailsScreenState extends State<EditProfileDetailsScreen> {
  final formKey = GlobalKey<FormState>();
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final birthdateController = TextEditingController();

  File? imageFile;
  bool isSaving = false;
  bool isEditing = false;
  String? imageUrl;
  String? email;
  DateTime? selectedBirthdate;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadUserProfile();
  }

  Future<void> loadUserProfile() async {
    setState(() => isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    email = user.email;

    final userDocs =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

    if (userDocs.exists) {
      final data = userDocs.data()!;
      firstNameController.text = data['firstName'] ?? '';
      lastNameController.text = data['lastName'] ?? '';

      if (data['birthdate'] != null) {
        if (data['birthdate'] is Timestamp) {
          selectedBirthdate = (data['birthdate'] as Timestamp).toDate();
        } else if (data['birthdate'] is String) {
          selectedBirthdate = DateTime.tryParse(data['birthdate']);
        }

        if (selectedBirthdate != null) {
          birthdateController.text =
              "${selectedBirthdate!.day}/${selectedBirthdate!.month}/${selectedBirthdate!.year}";
        }
      }

      imageUrl = data['imageUrl'];
    }
    setState(() => isLoading = false);
  }

  Future<void> pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      setState(() {
        imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> selectBirthdate() async {
    if (!isEditing) return;

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate:
          selectedBirthdate ??
          DateTime.now().subtract(Duration(days: 365 * 20)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null) {
      setState(() {
        selectedBirthdate = pickedDate;
        birthdateController.text =
            "${pickedDate.day}/${pickedDate.month}/${pickedDate.year}";
      });
    }
  }

  Future<void> saveProfile() async {
    if (!formKey.currentState!.validate()) return;

    setState(() => isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      String? uploadedImageUrl = imageUrl;

      if (imageFile != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('profile_images')
            .child('${user.uid}');
        await ref.putFile(imageFile!);
        uploadedImageUrl = await ref.getDownloadURL();
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'firstName': firstNameController.text.trim(),
        'lastName': lastNameController.text.trim(),
        'birthdate':
            selectedBirthdate != null
                ? Timestamp.fromDate(selectedBirthdate!)
                : null,
        'imageUrl': uploadedImageUrl ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() {
        isEditing = false;
        imageFile = null;
        imageUrl = uploadedImageUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => isSaving = false);
    }
  }

  void cancelEdit() {
    setState(() {
      isEditing = false;
      imageFile = null;
    });
    loadUserProfile();
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    birthdateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.defaultbackground,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: const Text(
          'Personal Details',
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
        actions: [
          if (!isEditing && !isLoading)
            TextButton(
              onPressed: () => setState(() => isEditing = true),
              child: const Text(
                'Edit',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
      body:
          isLoading
              ? Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
              : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Form(
                          key: formKey,
                          child: Column(
                            children: [
                              // Profile Image Section
                              Center(
                                child: Stack(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFFE5E7EB),
                                          width: 2,
                                        ),
                                      ),
                                      child: CircleAvatar(
                                        radius: 60,
                                        backgroundColor: const Color(
                                          0xFFF3F4F6,
                                        ),
                                        backgroundImage:
                                            imageFile != null
                                                ? FileImage(imageFile!)
                                                : (imageUrl != null &&
                                                            imageUrl!.isNotEmpty
                                                        ? NetworkImage(
                                                          imageUrl!,
                                                        )
                                                        : null)
                                                    as ImageProvider?,
                                        child:
                                            imageFile == null &&
                                                    (imageUrl == null ||
                                                        imageUrl!.isEmpty)
                                                ? Icon(
                                                  Icons.person,
                                                  size: 50,
                                                  color: const Color(
                                                    0xFF9CA3AF,
                                                  ),
                                                )
                                                : null,
                                      ),
                                    ),
                                    if (isEditing)
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: GestureDetector(
                                          onTap: pickImage,
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 3,
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.camera_alt,
                                              size: 18,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 32),

                              if (!isEditing) ...[
                                buildViewModeField(
                                  label: 'Email',
                                  value: email ?? '',
                                  icon: Icons.email_outlined,
                                ),
                                const SizedBox(height: 16),
                              ],

                              // First Name
                              if (isEditing)
                                buildEditableField(
                                  label: 'First Name',
                                  controller: firstNameController,
                                  hintText: 'Enter your first name',
                                  validator:
                                      (value) =>
                                          value == null || value.trim().isEmpty
                                              ? 'Please enter your first name'
                                              : null,
                                )
                              else
                                buildViewModeField(
                                  label: 'First Name',
                                  value: firstNameController.text,
                                  icon: Icons.person_outline,
                                ),
                              const SizedBox(height: 16),

                              // Last Name
                              if (isEditing)
                                buildEditableField(
                                  label: 'Last Name',
                                  controller: lastNameController,
                                  hintText: 'Enter your last name',
                                  validator:
                                      (value) =>
                                          value == null || value.trim().isEmpty
                                              ? 'Please enter your last name'
                                              : null,
                                )
                              else
                                buildViewModeField(
                                  label: 'Last Name',
                                  value: lastNameController.text,
                                  icon: Icons.person_outline,
                                ),
                              const SizedBox(height: 16),

                              // Date of Birth
                              if (isEditing)
                                buildEditableField(
                                  label: 'Date of Birth',
                                  controller: birthdateController,
                                  hintText: 'Select your date of birth',
                                  readOnly: true,
                                  onTap: selectBirthdate,
                                  suffixIcon: Icons.calendar_today,
                                  validator: (value) {
                                    if (selectedBirthdate == null) {
                                      return 'Please select your date of birth';
                                    }
                                    return null;
                                  },
                                )
                              else
                                buildViewModeField(
                                  label: 'Date of Birth',
                                  value: birthdateController.text,
                                  icon: Icons.calendar_today_outlined,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  if (isEditing)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isSaving ? null : cancelEdit,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                side: BorderSide(color: Colors.grey.shade300),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: Container(
                              height: 56,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient:
                                    isSaving
                                        ? null
                                        : LinearGradient(
                                          colors: [
                                            AppColors.primary,
                                            AppColors.primary.withOpacity(0.8),
                                          ],
                                        ),
                                boxShadow:
                                    isSaving
                                        ? null
                                        : [
                                          BoxShadow(
                                            color: AppColors.primary
                                                .withOpacity(0.3),
                                            blurRadius: 15,
                                            offset: const Offset(0, 5),
                                          ),
                                        ],
                              ),
                              child: ElevatedButton(
                                onPressed: isSaving ? null : saveProfile,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      isSaving
                                          ? Colors.grey.shade300
                                          : Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child:
                                    isSaving
                                        ? SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.grey.shade600,
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                        : const Text(
                                          'Save Changes',
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
    );
  }

  Widget buildViewModeField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF6B7280)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.isEmpty ? '-' : value,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF374151),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildEditableField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    bool readOnly = false,
    VoidCallback? onTap,
    IconData? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          onTap: onTap,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              fontFamily: 'Poppins',
              color: Colors.grey.shade500,
              fontSize: 14,
            ),
            suffixIcon:
                suffixIcon != null
                    ? Icon(suffixIcon, color: Colors.grey.shade600, size: 20)
                    : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.all(16),
          ),
          validator: validator,
        ),
      ],
    );
  }
}
