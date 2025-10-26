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
  final otherHealthController = TextEditingController();

  File? imageFile;
  bool isSaving = false;
  bool isEditing = false;
  String? imageUrl;
  String? email;
  DateTime? selectedBirthdate;
  bool isLoading = true;

  // Basic Info
  String? selectedGender;

  // Health Aspects
  bool foodAllergies = false;
  bool drugAllergies = false;
  bool asthmaRespiratory = false;
  bool skinSensitivity = false;
  bool otherHealth = false;

  // Health Background
  bool lungDisease = false;
  bool heartDisease = false;
  bool sportsActivities = false;
  bool isPregnant = false;

  // Care responsibilities
  bool caresForChildren = false;
  bool caresForToddlers = false;
  bool caresForBabies = false;

  // Computed user group
  String? userGroup;

  @override
  void initState() {
    super.initState();
    loadUserProfile();
  }

  void _updateUserGroup() {
    if (selectedBirthdate == null) return;

    final age = DateTime.now().difference(selectedBirthdate!).inDays ~/ 365;

    if (age >= 60) {
      userGroup = 'elderly';
    } else if (age <= 12) {
      userGroup = 'child';
    } else {
      userGroup = null;
    }
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
      selectedGender = data['gender'];

      if (data['birthdate'] != null) {
        if (data['birthdate'] is Timestamp) {
          selectedBirthdate = (data['birthdate'] as Timestamp).toDate();
        } else if (data['birthdate'] is String) {
          selectedBirthdate = DateTime.tryParse(data['birthdate']);
        }

        if (selectedBirthdate != null) {
          birthdateController.text =
              "${selectedBirthdate!.day}/${selectedBirthdate!.month}/${selectedBirthdate!.year}";
          _updateUserGroup();
        }
      }

      imageUrl = data['imageUrl'];

      // Load health data
      foodAllergies = data['foodAllergies'] ?? false;
      drugAllergies = data['drugAllergies'] ?? false;
      asthmaRespiratory = data['asthmaRespiratory'] ?? false;
      skinSensitivity = data['skinSensitivity'] ?? false;
      otherHealth = data['otherHealth'] ?? false;
      otherHealthController.text = data['otherHealthDetails'] ?? '';

      lungDisease = data['lungDisease'] ?? false;
      heartDisease = data['heartDisease'] ?? false;
      sportsActivities = data['sportsActivities'] ?? false;
      isPregnant = data['isPregnant'] ?? false;

      caresForChildren = data['caresForChildren'] ?? false;
      caresForToddlers = data['caresForToddlers'] ?? false;
      caresForBabies = data['caresForBabies'] ?? false;
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        selectedBirthdate = pickedDate;
        birthdateController.text =
            "${pickedDate.day}/${pickedDate.month}/${pickedDate.year}";
        _updateUserGroup();
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
        'gender': selectedGender,
        'birthdate':
            selectedBirthdate != null
                ? Timestamp.fromDate(selectedBirthdate!)
                : null,
        'userGroup': userGroup,
        'imageUrl': uploadedImageUrl ?? '',

        // Health aspects
        'foodAllergies': foodAllergies,
        'drugAllergies': drugAllergies,
        'asthmaRespiratory': asthmaRespiratory,
        'skinSensitivity': skinSensitivity,
        'otherHealth': otherHealth,
        'otherHealthDetails': otherHealthController.text.trim(),

        // Health background
        'lungDisease': lungDisease,
        'heartDisease': heartDisease,
        'sportsActivities': sportsActivities,
        'isPregnant': isPregnant,

        // Care responsibilities
        'caresForChildren': caresForChildren,
        'caresForToddlers': caresForToddlers,
        'caresForBabies': caresForBabies,

        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() {
        isEditing = false;
        imageFile = null;
        imageUrl = uploadedImageUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Profile updated successfully'),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
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
    otherHealthController.dispose();
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

                              // Email (always visible, not editable)
                              if (!isEditing)
                                buildViewModeField(
                                  label: 'Email',
                                  value: email ?? '',
                                  icon: Icons.email_outlined,
                                ),
                              if (!isEditing) const SizedBox(height: 16),

                              // Basic Information Section
                              _buildSectionHeader(
                                'Basic Information',
                                Icons.person,
                              ),
                              const SizedBox(height: 16),

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

                              // Gender
                              if (isEditing)
                                _buildGenderSelector()
                              else
                                buildViewModeField(
                                  label: 'Gender',
                                  value: selectedGender ?? '-',
                                  icon:
                                      selectedGender == 'Male'
                                          ? Icons.male
                                          : Icons.female,
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

                              // User Group Badge (if applicable)
                              if (userGroup != null && !isEditing) ...[
                                const SizedBox(height: 16),
                                Container(
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.primary.withOpacity(0.2),
                                        AppColors.primary.withOpacity(0.1),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        userGroup == 'elderly' ? '🧓' : '🧒',
                                        style: TextStyle(fontSize: 28),
                                      ),
                                      SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'User Group',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade700,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            userGroup == 'elderly'
                                                ? 'Elderly User'
                                                : 'Child User',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 32),

                              // Health Aspects Section
                              _buildSectionHeader(
                                'Health Aspects',
                                Icons.health_and_safety,
                              ),
                              const SizedBox(height: 16),

                              if (isEditing)
                                Column(
                                  children: [
                                    _buildHealthOption(
                                      title: 'Food allergies',
                                      icon: '🍔',
                                      value: foodAllergies,
                                      onChanged:
                                          (val) => setState(
                                            () => foodAllergies = val,
                                          ),
                                    ),
                                    _buildHealthOption(
                                      title: 'Drug allergies',
                                      icon: '💊',
                                      value: drugAllergies,
                                      onChanged:
                                          (val) => setState(
                                            () => drugAllergies = val,
                                          ),
                                    ),
                                    _buildHealthOption(
                                      title: 'Asthma or respiratory conditions',
                                      icon: '🫁',
                                      value: asthmaRespiratory,
                                      onChanged:
                                          (val) => setState(
                                            () => asthmaRespiratory = val,
                                          ),
                                    ),
                                    _buildHealthOption(
                                      title: 'Skin sensitivity (e.g., eczema)',
                                      icon: '🧴',
                                      value: skinSensitivity,
                                      onChanged:
                                          (val) => setState(
                                            () => skinSensitivity = val,
                                          ),
                                    ),
                                    _buildHealthOption(
                                      title: 'Other',
                                      icon: '➕',
                                      value: otherHealth,
                                      onChanged:
                                          (val) =>
                                              setState(() => otherHealth = val),
                                    ),
                                    if (otherHealth) ...[
                                      SizedBox(height: 8),
                                      buildEditableField(
                                        label: 'Other Health Concerns',
                                        controller: otherHealthController,
                                        hintText: 'Please specify',
                                      ),
                                    ],
                                  ],
                                )
                              else
                                _buildHealthAspectsView(),

                              const SizedBox(height: 32),

                              // Health Background Section
                              _buildSectionHeader(
                                'Health Background',
                                Icons.medical_information,
                              ),
                              const SizedBox(height: 16),

                              if (isEditing)
                                _buildHealthBackgroundEdit()
                              else
                                _buildHealthBackgroundView(),
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

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  Widget _buildGenderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Gender',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(child: _buildGenderOption('Male', Icons.male)),
            SizedBox(width: 16),
            Expanded(child: _buildGenderOption('Female', Icons.female)),
          ],
        ),
      ],
    );
  }

  Widget _buildGenderOption(String gender, IconData icon) {
    final isSelected = selectedGender == gender;
    return GestureDetector(
      onTap: () => setState(() => selectedGender = gender),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppColors.primary.withOpacity(0.1)
                  : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? AppColors.primary : Colors.grey.shade400,
            ),
            SizedBox(height: 6),
            Text(
              gender,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppColors.primary : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthOption({
    required String title,
    required String icon,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: value ? AppColors.primary.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? AppColors.primary : Colors.grey.shade200,
          width: value ? 2 : 1,
        ),
      ),
      child: CheckboxListTile(
        title: Row(
          children: [
            Text(icon, style: TextStyle(fontSize: 20)),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: value ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        value: value,
        activeColor: AppColors.primary,
        onChanged: (val) => onChanged(val ?? false),
        controlAffinity: ListTileControlAffinity.trailing,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
    );
  }

  Widget _buildHealthAspectsView() {
    final healthAspects = <String>[];
    if (foodAllergies) healthAspects.add('🍔 Food allergies');
    if (drugAllergies) healthAspects.add('💊 Drug allergies');
    if (asthmaRespiratory) healthAspects.add('🫁 Asthma/Respiratory');
    if (skinSensitivity) healthAspects.add('🧴 Skin sensitivity');
    if (otherHealth && otherHealthController.text.isNotEmpty) {
      healthAspects.add('➕ ${otherHealthController.text}');
    }

    if (healthAspects.isEmpty) {
      return buildViewModeField(
        label: 'Health Aspects',
        value: 'None specified',
        icon: Icons.health_and_safety,
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.health_and_safety, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Health Aspects',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                healthAspects
                    .map(
                      (aspect) => Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          aspect,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    )
                    .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthBackgroundEdit() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Medical Conditions',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        SizedBox(height: 12),
        _buildToggleOption(
          title: 'Lung disease',
          icon: '🫁',
          value: lungDisease,
          onChanged: (val) => setState(() => lungDisease = val),
        ),
        _buildToggleOption(
          title: 'Heart disease',
          icon: '❤️',
          value: heartDisease,
          onChanged: (val) => setState(() => heartDisease = val),
        ),
        SizedBox(height: 20),
        Text(
          'Lifestyle',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        SizedBox(height: 12),
        _buildYesNoOption(
          question: 'Sports or strenuous activities?',
          icon: '🏃',
          value: sportsActivities,
          onChanged: (val) => setState(() => sportsActivities = val),
        ),
        if (selectedGender == 'Female') ...[
          SizedBox(height: 12),
          _buildYesNoOption(
            question: 'Currently pregnant?',
            icon: '🤰',
            value: isPregnant,
            onChanged: (val) => setState(() => isPregnant = val),
          ),
        ],
        SizedBox(height: 20),
        Text(
          'Care Responsibilities',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        SizedBox(height: 12),
        _buildToggleOption(
          title: 'Children',
          icon: '👧',
          value: caresForChildren,
          onChanged: (val) => setState(() => caresForChildren = val),
        ),
        _buildToggleOption(
          title: 'Toddlers',
          icon: '👶',
          value: caresForToddlers,
          onChanged: (val) => setState(() => caresForToddlers = val),
        ),
        _buildToggleOption(
          title: 'Babies',
          icon: '🍼',
          value: caresForBabies,
          onChanged: (val) => setState(() => caresForBabies = val),
        ),
      ],
    );
  }

  Widget _buildHealthBackgroundView() {
    return Column(
      children: [
        // Medical Conditions
        if (lungDisease || heartDisease) ...[
          _buildInfoCard(
            title: 'Medical Conditions',
            icon: Icons.local_hospital,
            items: [
              if (lungDisease) '🫁 Lung disease',
              if (heartDisease) '❤️ Heart disease',
            ],
          ),
          SizedBox(height: 12),
        ],

        // Lifestyle
        _buildInfoCard(
          title: 'Lifestyle',
          icon: Icons.directions_run,
          items: [
            sportsActivities
                ? '🏃 Engages in sports/strenuous activities'
                : '🚶 No sports/strenuous activities',
          ],
        ),

        // Pregnancy (if female)
        if (selectedGender == 'Female') ...[
          SizedBox(height: 12),
          _buildInfoCard(
            title: 'Pregnancy Status',
            icon: Icons.pregnant_woman,
            items: [isPregnant ? '🤰 Currently pregnant' : 'Not pregnant'],
          ),
        ],

        // Care Responsibilities
        if (caresForChildren || caresForToddlers || caresForBabies) ...[
          SizedBox(height: 12),
          _buildInfoCard(
            title: 'Care Responsibilities',
            icon: Icons.family_restroom,
            items: [
              if (caresForChildren) '👧 Children',
              if (caresForToddlers) '👶 Toddlers',
              if (caresForBabies) '🍼 Babies',
            ],
          ),
        ],

        // If no care responsibilities
        if (!caresForChildren && !caresForToddlers && !caresForBabies) ...[
          SizedBox(height: 12),
          buildViewModeField(
            label: 'Care Responsibilities',
            value: 'None',
            icon: Icons.family_restroom,
          ),
        ],
      ],
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<String> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleOption({
    required String title,
    required String icon,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: value ? AppColors.primary.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? AppColors.primary : Colors.grey.shade200,
          width: value ? 2 : 1,
        ),
      ),
      child: SwitchListTile(
        title: Row(
          children: [
            Text(icon, style: TextStyle(fontSize: 20)),
            SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: value ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
        value: value,
        activeColor: AppColors.primary,
        onChanged: (val) => onChanged(val),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
    );
  }

  Widget _buildYesNoOption({
    required String question,
    required String icon,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: TextStyle(fontSize: 20)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  question,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildYesNoButton(
                  label: 'Yes',
                  isSelected: value == true,
                  onTap: () => onChanged(true),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildYesNoButton(
                  label: 'No',
                  isSelected: value == false,
                  onTap: () => onChanged(false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildYesNoButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
          ),
        ),
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
