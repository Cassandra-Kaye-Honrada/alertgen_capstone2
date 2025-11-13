import 'dart:convert';
import 'package:allergen/screens/feature/educational/Informational_Screen.dart';
import 'package:allergen/screens/feature/educational/educational_allergen.dart';
import 'package:allergen/screens/feature/chatbot/floating_chatbot.dart';
import 'package:allergen/screens/health_environment_analytics/AirQualityDetailScreen.dart';
import 'package:allergen/screens/health_environment_analytics/widgets/AirQualityWidget.dart';
import 'package:allergen/screens/profile_screen_items/allergen.dart';
import 'package:allergen/screens/profile_screen_items/scanHistoryScreen.dart';
import 'package:allergen/screens/profile_screen_items/ProfileScreen.dart';
import 'package:allergen/screens/first_Aid_screens/FirstAidScreen.dart';
import 'package:allergen/screens/feature/scan_screen.dart';
import 'package:allergen/screens/feature/result_screen.dart';
import 'package:allergen/screens/feature/allergen_analysis.dart';
import 'package:allergen/screens/feature/skin_allergy/skin_allergy.dart';
import 'package:allergen/services/emergency/emergency_service.dart';
import 'package:allergen/services/push_notification_service.dart';
import 'package:allergen/styleguide.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';
import '../profile_screen_items/AllergenProfileScreen.dart';

class Homescreen extends StatefulWidget {
  @override
  HomescreenState createState() => HomescreenState();
}

class HomescreenState extends State<Homescreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  String username = 'User';
  String? profileImageUrl;
  bool isLoading = true;
  int currentIndex = 0;
  bool isDisposed = false;
  bool _imageLoadError = false;
  late EmergencyService emergencyService;
  late Stream<List<Map<String, dynamic>>> recentHistory;
  late Stream<List<Map<String, dynamic>>> allergenProfile;
  Map<String, File?> imageCache = {};
  final AllergenAnalysis allergenAnalysis = AllergenAnalysis();

  @override
  void initState() {
    super.initState();
    initializeEmergencyService();
    setupHistory();
    setupAllergenProfile();
    fetchUserProfile();
  }

  Future<void> initializeEmergencyService() async {
    emergencyService = EmergencyService();
    await emergencyService.initialize();
    setState(() => isLoading = false);
  }

  Future<void> fetchUserProfile() async {
    if (user == null) return;
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user!.uid)
              .get();

      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;

        setState(() {
          final firstName = data['firstName'] ?? '';
          final lastName = data['lastName'] ?? '';
          final fullName = "$firstName $lastName".trim();

          username =
              fullName.isNotEmpty ? fullName : (data['username'] ?? 'User');
          profileImageUrl = data['imageUrl'];
          _imageLoadError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          username = 'User';
          profileImageUrl = null;
        });
      }
    }
  }

  void setupAllergenProfile() {
    if (user == null) {
      allergenProfile = Stream.value([]);
      return;
    }

    allergenProfile = FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('profile')
        .where('type', isEqualTo: 'allergen')
        .snapshots()
        .map((snapshot) {
          List<Map<String, dynamic>> allergens = [];
          for (var doc in snapshot.docs) {
            if (doc.data() != null) {
              Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
              allergens.add({
                'name': data['name']?.toString() ?? 'Unknown',
                'id': doc.id,
                'severity': (data['severity'] ?? 0.5).toDouble(),
                'type': data['type']?.toString() ?? 'allergen',
                'createdAt': data['createdAt'],
              });
            }
          }
          return allergens;
        });
  }

  void setupHistory() {
    if (user == null) {
      recentHistory = Stream.value([]);
      return;
    }

    final foodStream =
        FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('history')
            .orderBy('timestamp', descending: true)
            .limit(3)
            .snapshots();

    final skinStream =
        FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('skin_history')
            .orderBy('timestamp', descending: true)
            .limit(3)
            .snapshots();

    final controller = StreamController<List<Map<String, dynamic>>>();
    List<QuerySnapshot>? lastFoodData;
    List<QuerySnapshot>? lastSkinData;

    final foodSubscription = foodStream.listen((foodSnapshot) {
      lastFoodData = [foodSnapshot];
      emitCombinedHistory(controller, lastFoodData, lastSkinData);
    });

    final skinSubscription = skinStream.listen((skinSnapshot) {
      lastSkinData = [skinSnapshot];
      emitCombinedHistory(controller, lastFoodData, lastSkinData);
    });

    controller.onCancel = () {
      foodSubscription.cancel();
      skinSubscription.cancel();
    };

    recentHistory = controller.stream;
  }

  void emitCombinedHistory(
    StreamController<List<Map<String, dynamic>>> controller,
    List<QuerySnapshot>? foodData,
    List<QuerySnapshot>? skinData,
  ) async {
    if (foodData != null && skinData != null) {
      List<Map<String, dynamic>> combined = [];

      for (var doc in foodData[0].docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        String? fileName = data['fileName'] as String?;
        if (fileName == null) {
          final imagePath = data['imagePath'] as String?;
          if (imagePath != null) {
            fileName = imagePath.split('/').last;
          }
        }

        File? imageFile;
        if (fileName != null && fileName.isNotEmpty) {
          if (imageCache.containsKey(fileName)) {
            imageFile = imageCache[fileName];
          } else {
            imageFile = await downloadAndCacheImage(fileName, 'food');
            imageCache[fileName] = imageFile;
          }
        }

        final ingredientColorsData =
            data['ingredientColors'] as List<dynamic>? ?? [];
        final ingredientColors =
            ingredientColorsData.map((item) {
              return IngredientColorInfo.fromJson(item as Map<String, dynamic>);
            }).toList();

        Map<String, dynamic>? ingredientBenefits;
        if (data.containsKey('ingredientBenefits')) {
          ingredientBenefits = Map<String, dynamic>.from(
            data['ingredientBenefits'] as Map? ?? {},
          );
        }

        combined.add({
          'id': doc.id,
          'type': 'food',
          'dishName': data['dishName'] ?? 'Unknown Dish',
          'description': data['description'] ?? '',
          'ingredients': List<String>.from(data['ingredients'] ?? []),
          'allergens': data['allergens'] ?? [],
          'imageUrl': data['imageUrl'] ?? '',
          'fileName': fileName ?? '',
          'imagePath': data['imagePath'] ?? '',
          'timestamp': data['timestamp'],
          'scanDate': data['scanDate'] ?? '',
          'isOCRAnalysis': data['isOCRAnalysis'] ?? false,
          'cachedImage': imageFile,
          'ingredientColors': ingredientColors,
          'ingredientBenefits': ingredientBenefits,
        });
      }

      for (var doc in skinData[0].docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        String? fileName = data['fileName'] as String?;
        File? imageFile;
        if (fileName != null && fileName.isNotEmpty) {
          if (imageCache.containsKey(fileName)) {
            imageFile = imageCache[fileName];
          } else {
            imageFile = await downloadAndCacheImage(fileName, 'skin');
            imageCache[fileName] = imageFile;
          }
        }

        combined.add({
          'id': doc.id,
          'type': 'skin',
          'conditionName': data['conditionName'] ?? 'Unknown Condition',
          'isFoodAllergyRelated': data['isFoodAllergyRelated'] ?? false,
          'confidence': data['confidence'] ?? 0.5,
          'description': data['description'] ?? '',
          'severity': data['severity'] ?? 'unknown',
          'likelyFoodTriggers': data['likelyFoodTriggers'] ?? [],
          'symptoms': data['symptoms'] ?? [],
          'immediateActions': data['immediateActions'] ?? [],
          'foodsToAvoid': data['foodsToAvoid'] ?? [],
          'whenToSeekHelp': data['whenToSeekHelp'] ?? '',
          'additionalNotes': data['additionalNotes'] ?? '',
          'imageUrl': data['imageUrl'] ?? '',
          'fileName': fileName ?? '',
          'timestamp': data['timestamp'],
          'scanDate': data['scanDate'] ?? '',
          'cachedImage': imageFile,
        });
      }

      combined.sort((a, b) {
        final aTimestamp = a['timestamp'] as Timestamp?;
        final bTimestamp = b['timestamp'] as Timestamp?;
        if (aTimestamp == null || bTimestamp == null) return 0;
        return bTimestamp.compareTo(aTimestamp);
      });

      if (combined.length > 3) {
        combined = combined.sublist(0, 3);
      }

      controller.add(combined);
    }
  }

  @override
  void dispose() {
    isDisposed = true;
    super.dispose();
  }

  bool hasUserAllergenInHistory(Map<String, dynamic> item) {
    try {
      if (item['type'] == 'skin') {
        return item['isFoodAllergyRelated'] ?? false;
      }

      final List<dynamic> itemAllergens = item['allergens'] ?? [];

      for (final allergen in itemAllergens) {
        if (allergen is Map<String, dynamic>) {
          final isUserFlagged = allergen['isUserAllergen'] == true;
          if (isUserFlagged) {
            return true;
          }
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  Color getSeverityColor(double severity) {
    if (severity < 0.33) return AppColors.mild;
    if (severity < 0.67) return AppColors.moderate;
    return AppColors.dangerAlert;
  }

  String getSeverityText(double severity) {
    if (severity < 0.33) return 'Mild';
    if (severity < 0.67) return 'Moderate';
    return 'Severe';
  }

  String getTimeAgo(dynamic timestamp) {
    if (timestamp == null) return 'Unknown time';
    DateTime dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else if (timestamp is String) {
      try {
        dateTime = DateTime.parse(timestamp);
      } catch (e) {
        return 'Unknown time';
      }
    } else {
      return 'Unknown time';
    }
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hr${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} min ago';
    } else {
      return 'Just now';
    }
  }

  Future<File?> getCachedImage(String fileName) async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String filePath = '${tempDir.path}/$fileName';
      final File file = File(filePath);
      if (await file.exists()) {
        return file;
      }
      return await downloadAndCacheImage(fileName, 'food');
    } catch (e) {
      return null;
    }
  }

  void navigateToResultScreen(Map<String, dynamic> historyItem) async {
    try {
      final scanType = historyItem['type'] ?? 'food';

      if (scanType == 'skin') {
        await navigateToSkinResult(historyItem);
      } else {
        await navigateToFoodResult(historyItem);
      }
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening scan result: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> navigateToSkinResult(Map<String, dynamic> historyItem) async {
    String? fileName = historyItem['fileName'] as String?;
    File? imageFile = historyItem['cachedImage'];

    if (imageFile == null && fileName != null && fileName.isNotEmpty) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0B8FAC)),
              ),
            ),
      );

      imageFile = await downloadAndCacheImage(fileName, 'skin');

      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
    }

    final skinData = {
      'conditionName': historyItem['conditionName'] ?? 'Unknown Condition',
      'isFoodAllergyRelated': historyItem['isFoodAllergyRelated'] ?? false,
      'confidence': historyItem['confidence'] ?? 0.5,
      'description': historyItem['description'] ?? '',
      'severity': historyItem['severity'] ?? 'unknown',
      'likelyFoodTriggers': historyItem['likelyFoodTriggers'] ?? [],
      'symptoms': historyItem['symptoms'] ?? [],
      'immediateActions': historyItem['immediateActions'] ?? [],
      'foodsToAvoid': historyItem['foodsToAvoid'] ?? [],
      'whenToSeekHelp': historyItem['whenToSeekHelp'] ?? '',
      'additionalNotes': historyItem['additionalNotes'] ?? '',
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => SkinResultScreen(
              skinData: skinData,
              image: imageFile ?? File(''),
            ),
      ),
    );
  }

  Map<String, double> extractHistoricalSeverityData(
    Map<String, dynamic> historyItem,
  ) {
    Map<String, double> severityMap = {};

    List<dynamic> userAllergensAtScanTime =
        historyItem['userAllergensAtScanTime'] ?? [];

    print('User allergens at scan time: $userAllergensAtScanTime');

    if (userAllergensAtScanTime.isNotEmpty) {
      print('Loading from userAllergensAtScanTime');
      for (var allergenData in userAllergensAtScanTime) {
        if (allergenData is Map<String, dynamic>) {
          String name =
              allergenData['name']?.toString().toLowerCase().trim() ?? '';
          double severity = (allergenData['severity'] ?? 0.5).toDouble();
          if (name.isNotEmpty) {
            severityMap[name] = severity;
            print('  $name: $severity');
          }
        } else if (allergenData is String) {
          String allergenName = allergenData.toLowerCase().trim();

          List<dynamic> allergens = historyItem['allergens'] ?? [];
          for (var allergen in allergens) {
            if (allergen is Map<String, dynamic>) {
              String name =
                  allergen['name']?.toString().toLowerCase().trim() ?? '';
              if (name == allergenName && allergen['isUserAllergen'] == true) {
                double severity = (allergen['severity'] ?? 0.5).toDouble();
                severityMap[allergenName] = severity;
                print('$allergenName: $severity (from allergen data)');
              }
            }
          }
        }
      }
    } else {
      print('Loading from allergens array (fallback)');
      List<dynamic> allergens = historyItem['allergens'] ?? [];
      for (var allergen in allergens) {
        if (allergen is Map<String, dynamic> &&
            allergen['isUserAllergen'] == true) {
          String allergenName =
              allergen['name']?.toString().toLowerCase().trim() ?? '';

          double severity;
          if (allergen.containsKey('severity')) {
            severity = (allergen['severity'] ?? 0.5).toDouble();
            print('  $allergenName: $severity (from severity field)');
          } else {
            String riskLevel =
                allergen['riskLevel']?.toString().toLowerCase() ?? 'moderate';

            switch (riskLevel) {
              case 'severe':
                severity = 0.8;
                break;
              case 'moderate':
                severity = 0.5;
                break;
              case 'mild':
                severity = 0.2;
                break;
              case 'safe':
                severity = 0.0;
                break;
              default:
                severity = 0.2;
                print(
                  'Unknown risk level "$riskLevel" for $allergenName, defaulting to 0.2 (mild)',
                );
            }
            print('$allergenName: $severity (from riskLevel: $riskLevel)');
          }

          if (allergenName.isNotEmpty) {
            severityMap[allergenName] = severity;
          }
        }
      }
    }

    print('Final severity map: $severityMap');
    return severityMap;
  }

  Future<void> navigateToFoodResult(Map<String, dynamic> historyItem) async {
    final dishName = historyItem['dishName'] ?? 'Unknown Dish';
    final description =
        historyItem['description'] ?? 'No description available';
    final ingredients = List<String>.from(historyItem['ingredients'] ?? []);
    final allergenData = historyItem['allergens'] as List<dynamic>? ?? [];
    final bool isOCRAnalysis = historyItem['isOCRAnalysis'] as bool? ?? false;

    final List<IngredientColorInfo> ingredientColors =
        historyItem['ingredientColors'] as List<IngredientColorInfo>? ?? [];

    String? fileName = historyItem['fileName'] as String?;

    if (fileName == null || fileName.isEmpty) {
      final imagePath = historyItem['imagePath'] as String?;
      if (imagePath != null) {
        fileName = imagePath.split('/').last;
      }
    }

    final List<AllergenInfo> allergens =
        allergenData.map((allergen) {
          final allergenMap = allergen as Map<String, dynamic>;
          return AllergenInfo(
            name: allergenMap['name'] ?? 'Unknown',
            riskLevel: allergenMap['riskLevel'] ?? 'mild',
            symptoms: List<String>.from(allergenMap['symptoms'] ?? []),
            sources:
                allergen['source'] is List
                    ? List<String>.from(allergen['source'])
                    : (allergen['source'] != null
                        ? [allergen['source'].toString()]
                        : []),
            category: allergenMap['category'] ?? 'FDA_MAJOR',
            isUserAllergen: allergenMap['isUserAllergen'] ?? false,
          );
        }).toList();

    File? imageFile = historyItem['cachedImage'];

    if (imageFile == null && fileName != null && fileName.isNotEmpty) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0B8FAC)),
              ),
            ),
      );

      imageFile = await downloadAndCacheImage(fileName, 'food');

      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
    }

    Map<String, double> historicalSeverity = extractHistoricalSeverityData(
      historyItem,
    );

    IngredientBenefitsMap? benefitsMap;
    if (historyItem.containsKey('ingredientBenefits')) {
      benefitsMap = IngredientBenefitsMap();
      var benefitsData = historyItem['ingredientBenefits'];

      if (benefitsData is Map) {
        Map<String, dynamic> benefits = Map<String, dynamic>.from(benefitsData);

        benefits.forEach((key, value) {
          String ingredientKey = key.toString();
          String benefitValue = value.toString();
          benefitsMap!.addBenefit(ingredientKey, benefitValue);
          print(
            '  - $ingredientKey: ${benefitValue.substring(0, benefitValue.length > 50 ? 50 : benefitValue.length)}...',
          );
        });
      }
    } else {
      print('Available fields: ${historyItem.keys.join(', ')}');
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ResultScreen(
              image: imageFile,
              dishName: dishName,
              description: description,
              ingredients: ingredients,
              allergens: allergens,
              isOCRAnalysis: isOCRAnalysis,
              ingredientColors: ingredientColors,
              onIngredientsChanged: (updatedIngredients) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'This is historical data. To update allergen analysis with your current profile, please scan again.',
                      ),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 4),
                    ),
                  );
                }
              },
              isFromHistory: true,
              historicalSeverityData: historicalSeverity,
              ingredientBenefitsMap: benefitsMap,
            ),
      ),
    );
  }

  Future<File?> downloadAndCacheImage(String fileName, String scanType) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final cleanFileName = fileName.split('/').last;
      final folderName = scanType == 'skin' ? 'skin_images' : 'food_images';

      final storageRef = FirebaseStorage.instance
          .ref()
          .child(folderName)
          .child(user.uid)
          .child(cleanFileName);

      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/$cleanFileName';
      final file = File(tempPath);

      if (await file.exists()) return file;

      try {
        final data = await storageRef.getData();
        if (data != null) {
          await file.writeAsBytes(data);
          return file;
        }
      } catch (e) {
        return null;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> refreshUserData() async {
    if (!isDisposed && mounted) {
      setState(() {
        isLoading = true;
        _imageLoadError = false;
      });
      imageCache.clear();
      await fetchUserProfile();
      await Future.delayed(Duration(milliseconds: 500));
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF2B9EB3),
              Color(0xFF1E7A8C),
              Color(0xFFF8F9FA),
              Color(0xFFFFFFFF),
            ],
          ),
        ),
        child: Column(
          children: [
            Container(
              //color: Color(0xFFF8F9FA),
              child: SafeArea(
                bottom: false,
                child: Container(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 5,
                    bottom: 0,
                  ),
                  child: buildHeader(),
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: refreshUserData,
                child: SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: EdgeInsets.only(left: 20, right: 20, top: 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ElevatedButton(
                        //   onPressed: () async {
                        //     await PushNotificationService()
                        //         .showEnvironmentalAlert(
                        //           title: 'Test Alert',
                        //           body: 'This is a test environmental alert',
                        //           alertLevel: 'Unhealthy',
                        //           aqi: 155,
                        //         );
                        //   },
                        //   child: Text('Test Local Notification'),
                        // ),
                        AirQualityWidget(
                          apiKey: 'AIzaSyCWva81wgqeq5qIShLvoO9hs20ejk73gCE',
                        ),
                        //SizedBox(height: 30),
                        // buildEmergencySection(),
                        SizedBox(height: 30),
                        buildAllergenProfileSection(),
                        SizedBox(height: 20),
                        buildTreatmentSection(),
                        SizedBox(height: 30),
                        buildRecentHistorySection(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingChatbotButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: buildBottomNavigation(),
    );
  }

  Widget buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Image.asset('assets/images/alertgenW.png', height: 40, width: 40),
            SizedBox(width: 5),
            Image.asset('assets/images/alertgenWW.png', height: 60, width: 100),
          ],
        ),
        Row(
          children: [
            GestureDetector(
              onTap: () {
                emergencyService.startEmergencyCallFromUI(context);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3F3),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE53935),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.call,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Call for Help',
                      style: TextStyle(
                        color: Color(0xFFE53935),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // GestureDetector(
            //   onTap: () async {
            //     final result = await Navigator.push(
            //       context,
            //       MaterialPageRoute(
            //         builder:
            //             (context) =>
            //                 UserProfile(emergencyService: EmergencyService()),
            //       ),
            //     );
            //     if (result == true) {
            //       await fetchUserProfile();
            //     }
            //   },
            //   child: Container(
            //     padding: EdgeInsets.all(3),
            //     decoration: BoxDecoration(
            //       shape: BoxShape.circle,
            //       border: Border.all(color: Color(0xFF0B8FAC), width: 2),
            //       boxShadow: [
            //         BoxShadow(
            //           color: Colors.black.withOpacity(0.1),
            //           blurRadius: 4,
            //           offset: Offset(0, 2),
            //         ),
            //       ],
            //     ),
            //     child: buildProfileAvatar(),
            //   ),
            // ),
            // IconButton(
            //   onPressed: () {
            //     Navigator.push(
            //       context,
            //       MaterialPageRoute(
            //         builder: (context) => const AllergenProfile(),
            //       ),
            //     );
            //   },
            //   icon: const Icon(Icons.chat),
            //   tooltip: 'Community Forum',
            //   color: AppColors.primary,
            // ),
          ],
        ),
      ],
    );
  }

  Widget buildProfileAvatar() {
    if (user == null) return buildDefaultAvatar();

    return StreamBuilder<DocumentSnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('users')
              .doc(user!.uid)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return buildDefaultAvatar();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final imageUrl = data['imageUrl'] as String?;
        final hasValidImage = imageUrl != null && imageUrl.isNotEmpty;

        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFE2E8F0),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child:
                hasValidImage
                    ? Image.network(
                      imageUrl,
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return buildDefaultAvatar();
                      },
                    )
                    : buildDefaultAvatar(),
          ),
        );
      },
    );
  }

  Widget buildDefaultAvatar() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFE2E8F0),
      ),
      child: Icon(Icons.person, color: Color(0xFF64748B), size: 24),
    );
  }

  Widget buildEmergencySection() {
    return GestureDetector(
      onLongPress: () {
        emergencyService.startEmergencyCallFromUI(context);
      },
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Color(0xFFF6F8FA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Are you in an\nemergency?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Long press this area, your live location will be shared with the nearest help centre',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textGray,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 16),
            Container(
              width: 60,
              height: 60,
              child: Image.asset('assets/images/emergency_light.png'),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildAllergenProfileSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Allergen Profile',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textBlack,
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: allergenProfile,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              );
            }

            if (snapshot.hasError) {
              return Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.red),
                    SizedBox(height: 12),
                    Text(
                      'Error loading allergen profile',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textBlack,
                      ),
                    ),
                  ],
                ),
              );
            }

            final allergens = snapshot.data ?? [];

            if (allergens.isEmpty) {
              return buildEmptyAllergenState();
            }

            return Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Spacer(),
                    GestureDetector(
                      onTap:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AllergenProfileScreen(),
                            ),
                          ),
                      child: Text(
                        '${allergens.length} allergen${allergens.length > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textGray,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                buildAllergenGrid(allergens),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget buildAllergenGrid(List<Map<String, dynamic>> allergens) {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: allergens.length + 1,
        itemBuilder: (context, index) {
          if (index == allergens.length) {
            return buildAddAllergenIcon();
          }
          return buildAllergenIcon(allergens[index]);
        },
      ),
    );
  }

  Widget buildAllergenIcon(Map<String, dynamic> allergenData) {
    final double severity = (allergenData['severity'] ?? 0.5).toDouble();
    final Color severityColor = getSeverityColor(severity);

    return Container(
      margin: EdgeInsets.only(right: 16),
      child: IntrinsicHeight(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFFF0F9FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Color(0xFFE0F2FE)),
                  ),
                  child: getAllergenIcon(allergenData['name']),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: severityColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Flexible(
              child: Container(
                width: 66,
                child: Text(
                  allergenData['name'],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildAddAllergenIcon() {
    return Container(
      margin: EdgeInsets.only(right: 16),
      child: Column(
        children: [
          GestureDetector(
            onTap:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AllergenProfileScreen(),
                  ),
                ),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(0xFFE2E8F0)),
              ),
              child: Icon(Icons.add, color: Color(0xFF64748B), size: 24),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Add',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildEmptyAllergenState() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(Icons.add_circle_outline, size: 48, color: AppColors.textGray),
          SizedBox(height: 12),
          Text(
            'No allergens added yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textBlack,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Add your allergens to get personalized food safety alerts',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textGray),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AllergenProfileScreen(),
                  ),
                ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Add Allergens', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget buildTreatmentSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.defaultbackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How to Treat Allergic Reaction',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Learn essential first aid steps for allergic reactions.',
                  style: TextStyle(fontSize: 12, color: AppColors.textGray),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => FirstAidScreen()),
                ),
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.arrow_forward, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildRecentHistorySection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent History',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3748),
              ),
            ),
            GestureDetector(
              onTap:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ScanHistoryScreen(),
                    ),
                  ),
              child: Text(
                'View all',
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: this.recentHistory,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              );
            }
            if (snapshot.hasError) {
              return Text('Error loading history');
            }
            final recentHistory = snapshot.data ?? [];
            if (recentHistory.isEmpty) {
              return buildEmptyHistory();
            }
            return Column(
              children:
                  recentHistory
                      .map(
                        (item) => Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: buildHistoryItem(item),
                        ),
                      )
                      .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget buildEmptyHistory() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(Icons.history, size: 48, color: AppColors.textGray),
          SizedBox(height: 12),
          Text(
            'No scan history yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textBlack,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Start scanning food items to see your history here',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textGray),
          ),
        ],
      ),
    );
  }

  Widget buildHistoryItem(Map<String, dynamic> item) {
    final scanType = item['type'] ?? 'food';
    File? cachedImage = item['cachedImage'];
    String? fileName = item['fileName'] as String?;
    bool isManualEntry = (fileName == null || fileName.isEmpty);

    if (scanType == 'skin') {
      return buildSkinHistoryItem(item, cachedImage, fileName);
    } else {
      return buildFoodHistoryItem(item, cachedImage, fileName, isManualEntry);
    }
  }

  Widget buildSkinHistoryItem(
    Map<String, dynamic> item,
    File? cachedImage,
    String? fileName,
  ) {
    String conditionName = item['conditionName'] ?? 'Unknown Condition';
    String severity = item['severity'] ?? 'unknown';
    bool isFoodAllergyRelated = item['isFoodAllergyRelated'] ?? false;

    return GestureDetector(
      onTap: () => navigateToResultScreen(item),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.moderate.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Color(0xFFE2E8F0)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child:
                    cachedImage != null && cachedImage.existsSync()
                        ? Image.file(
                          cachedImage,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.medical_services,
                              color: AppColors.moderate,
                              size: 24,
                            );
                          },
                        )
                        : Icon(
                          Icons.medical_services,
                          color: AppColors.moderate,
                          size: 24,
                        ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.medical_services,
                        size: 14,
                        color: AppColors.moderate,
                      ),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          conditionName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2D3748),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Severity: ${severity.toUpperCase()}',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        isFoodAllergyRelated
                            ? AppColors.moderate.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.medical_services,
                        size: 12,
                        color:
                            isFoodAllergyRelated
                                ? AppColors.moderate
                                : Colors.grey,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Skin',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color:
                              isFoodAllergyRelated
                                  ? AppColors.moderate
                                  : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  getTimeAgo(item['timestamp']),
                  style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildFoodHistoryItem(
    Map<String, dynamic> item,
    File? cachedImage,
    String? fileName,
    bool isManualEntry,
  ) {
    List<dynamic> allergensList = item['allergens'] ?? [];
    String dishName = item['dishName'] ?? 'Unknown Dish';

    bool hasUserAllergen = hasUserAllergenInHistory(item);

    int allergenCount = 0;
    for (var allergen in allergensList) {
      if (allergen is Map<String, dynamic>) {
        bool isUserAllergen = allergen['isUserAllergen'] ?? false;
        if (isUserAllergen) {
          allergenCount++;
        }
      }
    }

    return GestureDetector(
      onTap: () => navigateToResultScreen(item),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Color(0xFFE2E8F0)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child:
                    cachedImage != null && cachedImage.existsSync()
                        ? Image.file(
                          cachedImage,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.image,
                              color: Colors.grey[400],
                              size: 24,
                            );
                          },
                        )
                        : Icon(
                          isManualEntry ? Icons.photo : Icons.image,
                          color: Colors.grey[400],
                          size: 24,
                        ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dishName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D3748),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Text(
                    hasUserAllergen
                        ? 'Contains $allergenCount allergen${allergenCount > 1 ? 's' : ''}'
                        : 'Safe to consume',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        hasUserAllergen
                            ? AppColors.dangerAlert.withOpacity(0.1)
                            : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasUserAllergen ? Icons.warning : Icons.check_circle,
                        size: 12,
                        color:
                            hasUserAllergen
                                ? AppColors.dangerAlert
                                : Colors.green,
                      ),
                      SizedBox(width: 4),
                      Text(
                        hasUserAllergen ? 'Warning' : 'Safe',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color:
                              hasUserAllergen
                                  ? AppColors.dangerAlert
                                  : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  getTimeAgo(item['timestamp']),
                  style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildBottomNavigation() {
    return Container(
      margin: EdgeInsets.all(20),
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          GestureDetector(
            onTap: () => setState(() => currentIndex = 0),
            child: Image.asset(
              'assets/navigation/menu_active.png',
              width: 24,
              height: 24,
              errorBuilder:
                  (context, error, stackTrace) =>
                      Icon(Icons.home, color: Color(0xFF64748B), size: 24),
            ),
          ),

          // ✅ UPDATED: Navigate to Air Quality Home Screen
          GestureDetector(
            onTap: () {
              setState(() => currentIndex = 1);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => AirQualityDetailScreen(
                        apiKey: 'AIzaSyCWva81wgqeq5qIShLvoO9hs20ejk73gCE',
                        // No data passed - will fetch on its own
                      ),
                ),
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.analytics_outlined,
                  color:
                      currentIndex == 1 ? Color(0xFF1AA2CC) : Color(0xFF00BCD4),
                  size: 24,
                ),
              ],
            ),
          ),

          GestureDetector(
            onTap:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CameraScannerScreen(),
                  ),
                ),
            child: Image.asset(
              'assets/navigation/scan_inactive.png',
              width: 24,
              height: 24,
              errorBuilder:
                  (context, error, stackTrace) => Icon(
                    Icons.camera_alt,
                    color: Color(0xFF1AA2CC),
                    size: 24,
                  ),
            ),
          ),

          GestureDetector(
            onTap: () {
              setState(() => currentIndex = 1);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FoodAllergyScreen()),
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.school_outlined,
                  color:
                      currentIndex == 1 ? Color(0xFF1AA2CC) : Color(0xFF00BCD4),
                  size: 24,
                ),
              ],
            ),
          ),

          GestureDetector(
            onTap: () {
              setState(() => currentIndex = 2);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) =>
                          UserProfile(emergencyService: EmergencyService()),
                ),
              );
            },
            child: Image.asset(
              'assets/navigation/Profile_inactive.png',
              width: 24,
              height: 24,
              errorBuilder:
                  (context, error, stackTrace) =>
                      Icon(Icons.person, color: Color(0xFF00BCD4), size: 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget getAllergenIcon(String allergenName) {
    final String name = allergenName.toLowerCase().trim();
    switch (name) {
      case 'milk':
      case 'dairy':
        return FaIcon(
          FontAwesomeIcons.glassWater,
          color: AppColors.primaryColor3,
          size: 22,
        );
      case 'cashew':
      case 'nuts':
      case 'nut':
      case 'tree nuts':
        return FaIcon(
          FontAwesomeIcons.seedling,
          color: AppColors.primaryColor3,
          size: 22,
        );
      case 'egg':
      case 'eggs':
        return FaIcon(
          FontAwesomeIcons.egg,
          color: AppColors.primaryColor3,
          size: 22,
        );
      case 'fish':
        return FaIcon(
          FontAwesomeIcons.fish,
          color: AppColors.primaryColor3,
          size: 22,
        );
      case 'wheat':
      case 'gluten':
        return FaIcon(
          FontAwesomeIcons.wheatAwn,
          color: AppColors.primaryColor3,
          size: 22,
        );
      case 'soy':
      case 'soybean':
      case 'soya':
        return FaIcon(
          FontAwesomeIcons.leaf,
          color: AppColors.primaryColor3,
          size: 22,
        );
      case 'shellfish':
      case 'seafood':
      case 'crustacean':
        return FaIcon(
          FontAwesomeIcons.shrimp,
          color: AppColors.primaryColor3,
          size: 22,
        );
      case 'peanut':
      case 'peanuts':
        return FaIcon(
          FontAwesomeIcons.circleNodes,
          color: AppColors.primaryColor3,
          size: 22,
        );
      case 'sesame':
        return FaIcon(
          FontAwesomeIcons.pepperHot,
          color: AppColors.primaryColor3,
          size: 22,
        );
      case 'lupin':
        return FaIcon(
          FontAwesomeIcons.spa,
          color: AppColors.primaryColor3,
          size: 22,
        );
      default:
        return FaIcon(
          FontAwesomeIcons.triangleExclamation,
          color: AppColors.primaryColor3,
          size: 22,
        );
    }
  }
}
