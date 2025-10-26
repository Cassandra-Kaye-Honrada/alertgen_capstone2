import 'dart:io';
import 'package:allergen/screens/feature/homescreen.dart';
import 'package:allergen/styleguide.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileDetailsScreen extends StatefulWidget {
  const ProfileDetailsScreen({Key? key}) : super(key: key);

  @override
  State<ProfileDetailsScreen> createState() => _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends State<ProfileDetailsScreen> {
  final formKey = GlobalKey<FormState>();
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final birthdateController = TextEditingController();
  final otherHealthController = TextEditingController();

  File? imageFile;
  bool isSaving = false;
  bool isLoading = true;
  DateTime? selectedBirthdate;
  int currentStep = 0;

  String? selectedGender;

  bool foodAllergies = false;
  bool drugAllergies = false;
  bool asthmaRespiratory = false;
  bool skinSensitivity = false;
  bool otherHealth = false;

  bool lungDisease = false;
  bool heartDisease = false;
  bool sportsActivities = false;
  bool isPregnant = false;

  bool caresForChildren = false;
  bool caresForToddlers = false;
  bool caresForBabies = false;

  String? userGroup;

  final Color primaryColor = AppColors.primary;

  @override
  void initState() {
    super.initState();
    fetchUserProfile();
  }

  Future<void> fetchUserProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;

        setState(() {
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
              updateUserGroup();
            }
          }

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
        });
      }
    } catch (e) {
      print('Error fetching profile: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void updateUserGroup() {
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
              primary: primaryColor,
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
        updateUserGroup();
      });
    }
  }

  bool validateCurrentStep() {
    if (currentStep == 0) {
      if (!formKey.currentState!.validate()) return false;
      if (selectedGender == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please select your gender'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        return false;
      }
      return true;
    }
    return true;
  }

  void nextStep() {
    if (validateCurrentStep()) {
      if (currentStep < 2) {
        setState(() => currentStep++);
      }
    }
  }

  void previousStep() {
    if (currentStep > 0) {
      setState(() => currentStep--);
    }
  }

  Future<void> saveProfile() async {
    if (!validateCurrentStep()) return;

    setState(() => isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return;
      }

      String? imageUrl;

      if (imageFile != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('profile_images')
            .child(user.uid);
        await ref.putFile(imageFile!);
        imageUrl = await ref.getDownloadURL();
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
        'imageUrl': imageUrl ?? '',

        'foodAllergies': foodAllergies,
        'drugAllergies': drugAllergies,
        'asthmaRespiratory': asthmaRespiratory,
        'skinSensitivity': skinSensitivity,
        'otherHealth': otherHealth,
        'otherHealthDetails': otherHealthController.text.trim(),

        'lungDisease': lungDisease,
        'heartDisease': heartDisease,
        'sportsActivities': sportsActivities,
        'isPregnant': isPregnant,

        'caresForChildren': caresForChildren,
        'caresForToddlers': caresForToddlers,
        'caresForBabies': caresForBabies,

        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => Homescreen()));
    } catch (e) {
      print('Error saving profile: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => isSaving = false);
    }
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    birthdateController.dispose();
    otherHealthController.dispose();
    super.dispose();
  }

  Widget buildBasicInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: GestureDetector(
                  onTap: pickImage,
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: primaryColor.withOpacity(0.1),
                    backgroundImage:
                        imageFile != null ? FileImage(imageFile!) : null,
                    child:
                        imageFile == null
                            ? Icon(
                              Icons.person,
                              size: 50,
                              color: primaryColor.withOpacity(0.5),
                            )
                            : null,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: pickImage,
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        Center(
          child: Text(
            'Tap to add profile photo',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
        ),
        const SizedBox(height: 40),

        buildInputField(
          controller: firstNameController,
          label: 'First Name',
          icon: Icons.person_outline,
          validator:
              (value) =>
                  value == null || value.trim().isEmpty
                      ? 'Enter your first name'
                      : null,
        ),
        const SizedBox(height: 20),

        buildInputField(
          controller: lastNameController,
          label: 'Last Name',
          icon: Icons.person_outline,
          validator:
              (value) =>
                  value == null || value.trim().isEmpty
                      ? 'Enter your last name'
                      : null,
        ),
        const SizedBox(height: 20),

        buildGenderSelector(),
        const SizedBox(height: 20),

        buildInputField(
          controller: birthdateController,
          label: 'Date of Birth',
          icon: Icons.cake_outlined,
          readOnly: true,
          onTap: selectBirthdate,
          validator: (value) {
            if (selectedBirthdate == null) {
              return 'Select your date of birth';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: primaryColor),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.red.shade300),
        ),
      ),
      validator: validator,
    );
  }

  Widget buildGenderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Gender',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(child: buildGenderOption('Male', Icons.male)),
            SizedBox(width: 16),
            Expanded(child: buildGenderOption('Female', Icons.female)),
          ],
        ),
      ],
    );
  }

  Widget buildGenderOption(String gender, IconData icon) {
    final isSelected = selectedGender == gender;
    return GestureDetector(
      onTap: () => setState(() => selectedGender = gender),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color:
              isSelected ? primaryColor.withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 40,
              color: isSelected ? primaryColor : Colors.grey.shade400,
            ),
            SizedBox(height: 8),
            Text(
              gender,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? primaryColor : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildHealthAspectsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                primaryColor.withOpacity(0.1),
                primaryColor.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              Icon(Icons.health_and_safety, color: primaryColor, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Select health aspects for personalized recommendations',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 24),

        _buildHealthOption(
          title: 'Food allergies',
          icon: '🍔',
          value: foodAllergies,
          onChanged: (val) => setState(() => foodAllergies = val),
        ),
        _buildHealthOption(
          title: 'Drug allergies',
          icon: '💊',
          value: drugAllergies,
          onChanged: (val) => setState(() => drugAllergies = val),
        ),
        _buildHealthOption(
          title: 'Asthma or respiratory conditions',
          icon: '🫁',
          value: asthmaRespiratory,
          onChanged: (val) => setState(() => asthmaRespiratory = val),
        ),
        _buildHealthOption(
          title: 'Skin sensitivity (e.g., eczema)',
          icon: '🧴',
          value: skinSensitivity,
          onChanged: (val) => setState(() => skinSensitivity = val),
        ),
        _buildHealthOption(
          title: 'Other',
          icon: '➕',
          value: otherHealth,
          onChanged: (val) => setState(() => otherHealth = val),
        ),

        if (otherHealth) ...[
          SizedBox(height: 16),
          TextFormField(
            controller: otherHealthController,
            decoration: InputDecoration(
              labelText: 'Please specify other health concerns',
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: primaryColor, width: 2),
              ),
            ),
            maxLines: 3,
          ),
        ],
      ],
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
        color: value ? primaryColor.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: value ? primaryColor : Colors.grey.shade200,
          width: value ? 2 : 1,
        ),
      ),
      child: CheckboxListTile(
        title: Row(
          children: [
            Text(icon, style: TextStyle(fontSize: 24)),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: value ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        value: value,
        activeColor: primaryColor,
        onChanged: (val) => onChanged(val ?? false),
        controlAffinity: ListTileControlAffinity.trailing,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  Widget _buildHealthBackgroundStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                primaryColor.withOpacity(0.1),
                primaryColor.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              Icon(Icons.medical_information, color: primaryColor, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Help us understand your health profile',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 24),

        if (userGroup != null) ...[
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryColor.withOpacity(0.2),
                  primaryColor.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    userGroup == 'elderly' ? '🧓' : '🧒',
                    style: TextStyle(fontSize: 28),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'User Group',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        userGroup == 'elderly' ? 'Elderly User' : 'Child User',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24),
        ],

        buildSectionTitle('Medical Conditions', Icons.local_hospital),
        SizedBox(height: 12),
        buildToggleOption(
          title: 'Lung disease',
          icon: '🫁',
          value: lungDisease,
          onChanged: (val) => setState(() => lungDisease = val),
        ),
        buildToggleOption(
          title: 'Heart disease',
          icon: '❤️',
          value: heartDisease,
          onChanged: (val) => setState(() => heartDisease = val),
        ),

        SizedBox(height: 24),
        buildSectionTitle('Lifestyle', Icons.directions_run),
        SizedBox(height: 12),
        buildYesNoOption(
          question: 'Do you engage in sports or strenuous outdoor activities?',
          icon: '🏃',
          value: sportsActivities,
          onChanged: (val) => setState(() => sportsActivities = val),
        ),

        if (selectedGender == 'Female') ...[
          SizedBox(height: 24),
          buildYesNoOption(
            question: 'Are you currently in any stage of pregnancy?',
            icon: '🤰',
            value: isPregnant,
            onChanged: (val) => setState(() => isPregnant = val),
          ),
        ],

        SizedBox(height: 24),
        buildSectionTitle('Care Responsibilities', Icons.family_restroom),
        SizedBox(height: 12),
        buildToggleOption(
          title: 'Children',
          icon: '👧',
          value: caresForChildren,
          onChanged: (val) => setState(() => caresForChildren = val),
        ),
        buildToggleOption(
          title: 'Toddlers',
          icon: '👶',
          value: caresForToddlers,
          onChanged: (val) => setState(() => caresForToddlers = val),
        ),
        buildToggleOption(
          title: 'Babies',
          icon: '🍼',
          value: caresForBabies,
          onChanged: (val) => setState(() => caresForBabies = val),
        ),
      ],
    );
  }

  Widget buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: primaryColor, size: 20),
        SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  Widget buildToggleOption({
    required String title,
    required String icon,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: value ? primaryColor.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: value ? primaryColor : Colors.grey.shade200,
          width: value ? 2 : 1,
        ),
      ),
      child: SwitchListTile(
        title: Row(
          children: [
            Text(icon, style: TextStyle(fontSize: 24)),
            SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: value ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
        value: value,
        activeColor: primaryColor,
        onChanged: (val) => onChanged(val),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Widget buildYesNoOption({
    required String question,
    required String icon,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: TextStyle(fontSize: 24)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  question,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: buildYesNoButton(
                  label: 'Yes',
                  isSelected: value == true,
                  onTap: () => onChanged(true),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: buildYesNoButton(
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

  Widget buildYesNoButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: primaryColor),
              SizedBox(height: 16),
              Text(
                'Loading profile...',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    final steps = ['Basic Info', 'Health Aspects', 'Health Background'];

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Complete Your Profile',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: primaryColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            child: Column(
              children: [
                Row(
                  children: List.generate(3, (index) {
                    return Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color:
                                        index <= currentStep
                                            ? primaryColor
                                            : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                if (index < currentStep)
                                  Positioned(
                                    right: 0,
                                    child: Container(
                                      padding: EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: primaryColor,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.check,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (index < 2) SizedBox(width: 8),
                        ],
                      ),
                    );
                  }),
                ),
                SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(3, (index) {
                    return Expanded(
                      child: Text(
                        steps[index],
                        textAlign:
                            index == 0
                                ? TextAlign.left
                                : index == 2
                                ? TextAlign.right
                                : TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              index == currentStep
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                          color:
                              index <= currentStep
                                  ? primaryColor
                                  : Colors.grey.shade400,
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Form(
                    key: formKey,
                    child:
                        currentStep == 0
                            ? buildBasicInfoStep()
                            : currentStep == 1
                            ? buildHealthAspectsStep()
                            : _buildHealthBackgroundStep(),
                  ),
                ),
              ),
            ),
          ),

          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  if (currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: previousStep,
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: primaryColor, width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.arrow_back, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Back',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (currentStep > 0) SizedBox(width: 12),
                  Expanded(
                    flex: currentStep == 0 ? 1 : 2,
                    child: ElevatedButton(
                      onPressed:
                          isSaving
                              ? null
                              : (currentStep < 2 ? nextStep : saveProfile),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 4,
                        shadowColor: primaryColor.withOpacity(0.4),
                      ),
                      child:
                          isSaving
                              ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                              : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    currentStep < 2 ? 'Next' : 'Complete',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(
                                    currentStep < 2
                                        ? Icons.arrow_forward
                                        : Icons.check_circle,
                                    size: 18,
                                  ),
                                ],
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
}
