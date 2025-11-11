import 'dart:async';
import 'dart:io';
import 'package:allergen/screens/feature/result_screen.dart';
import 'package:allergen/screens/feature/scan_screen.dart';
import 'package:allergen/screens/feature/allergen_analysis.dart';
import 'package:allergen/screens/feature/skin_allergy/skin_allergy.dart';
import 'package:allergen/styleguide.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class ScanHistoryScreen extends StatefulWidget {
  const ScanHistoryScreen({Key? key}) : super(key: key);

  @override
  State<ScanHistoryScreen> createState() => _ScanHistoryScreenState();
}

class _ScanHistoryScreenState extends State<ScanHistoryScreen> {
  final TextEditingController searchController = TextEditingController();
  String searchQuery = '';
  final AllergenAnalysis allergenAnalysis = AllergenAnalysis();
  String selectedFilter = 'all';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Stream<List<DocumentSnapshot>> getCombinedHistory() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final foodStream =
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('history')
            .orderBy('timestamp', descending: true)
            .snapshots();

    final skinStream =
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('skin_history')
            .orderBy('timestamp', descending: true)
            .snapshots();

    final controller = StreamController<List<DocumentSnapshot>>();

    List<QuerySnapshot>? lastFoodData;
    List<QuerySnapshot>? lastSkinData;

    final foodSubscription = foodStream.listen((foodSnapshot) {
      lastFoodData = [foodSnapshot];
      combinedData(controller, lastFoodData, lastSkinData);
    });

    final skinSubscription = skinStream.listen((skinSnapshot) {
      lastSkinData = [skinSnapshot];
      combinedData(controller, lastFoodData, lastSkinData);
    });

    controller.onCancel = () {
      foodSubscription.cancel();
      skinSubscription.cancel();
    };

    return controller.stream;
  }

  void combinedData(
    StreamController<List<DocumentSnapshot>> controller,
    List<QuerySnapshot>? foodData,
    List<QuerySnapshot>? skinData,
  ) {
    if (foodData != null && skinData != null) {
      List<DocumentSnapshot> combined = [];

      for (var doc in foodData[0].docs) {
        combined.add(doc);
      }

      for (var doc in skinData[0].docs) {
        combined.add(doc);
      }

      combined.sort((a, b) {
        final aData = a.data() as Map<String, dynamic>?;
        final bData = b.data() as Map<String, dynamic>?;

        final aTimestamp = aData?['timestamp'] as Timestamp?;
        final bTimestamp = bData?['timestamp'] as Timestamp?;

        if (aTimestamp == null || bTimestamp == null) return 0;
        return bTimestamp.compareTo(aTimestamp);
      });

      controller.add(combined);
    }
  }

  String getScanType(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    final type = data?['type'] as String?;

    if (type == 'skin_analysis' || doc.reference.parent.id == 'skin_history') {
      return 'skin';
    }
    return 'food';
  }

  List<DocumentSnapshot> filterDocuments(List<DocumentSnapshot> docs) {
    List<DocumentSnapshot> filtered = docs;

    if (searchQuery.isNotEmpty) {
      filtered =
          docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final scanType = getScanType(doc);

            if (scanType == 'food') {
              final dishName =
                  (data['dishName'] ?? '').toString().toLowerCase();
              return dishName.contains(searchQuery.toLowerCase());
            } else {
              final conditionName =
                  (data['conditionName'] ?? '').toString().toLowerCase();
              return conditionName.contains(searchQuery.toLowerCase());
            }
          }).toList();
    }

    if (selectedFilter != 'all') {
      filtered =
          filtered.where((doc) {
            return getScanType(doc) == selectedFilter;
          }).toList();
    }

    return filtered;
  }

  Map<String, List<DocumentSnapshot>> groupDocumentsByDate(
    List<DocumentSnapshot> docs,
  ) {
    final Map<String, List<DocumentSnapshot>> grouped = {};
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = data['timestamp'] as Timestamp?;
      if (timestamp != null) {
        final date = timestamp.toDate();
        final dateString = DateFormat('dd MMM, yyyy').format(date);
        grouped[dateString] = grouped[dateString] ?? [];
        grouped[dateString]!.add(doc);
      }
    }
    return grouped;
  }

  Future<String?> getImageUrl(String fileName, String scanType) async {
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
      return await storageRef.getDownloadURL();
    } catch (_) {
      return null;
    }
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
      final data = await storageRef.getData();
      if (data != null) {
        await file.writeAsBytes(data);
        return file;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Map<String, double> extractHistoricalSeverityData(
    Map<String, dynamic> scanData,
  ) {
    Map<String, double> severityMap = {};

    List<dynamic> userAllergensAtScanTime =
        scanData['userAllergensAtScanTime'] ?? [];

    if (userAllergensAtScanTime.isNotEmpty) {
      for (var allergenData in userAllergensAtScanTime) {
        if (allergenData is Map<String, dynamic>) {
          String name =
              allergenData['name']?.toString().toLowerCase().trim() ?? '';
          double severity = (allergenData['severity'] ?? 0.5).toDouble();
          if (name.isNotEmpty) {
            severityMap[name] = severity;
          }
        } else if (allergenData is String) {
          String allergenName = allergenData.toLowerCase().trim();

          List<dynamic> allergens = scanData['allergens'] ?? [];
          for (var allergen in allergens) {
            if (allergen is Map<String, dynamic>) {
              String name =
                  allergen['name']?.toString().toLowerCase().trim() ?? '';
              if (name == allergenName && allergen['isUserAllergen'] == true) {
                String riskLevel =
                    allergen['riskLevel']?.toString().toLowerCase() ??
                    'moderate';
                double severity;
                switch (riskLevel) {
                  case 'severe':
                    severity = 1.0;
                    break;
                  case 'moderate':
                    severity = 0.5;
                    break;
                  case 'mild':
                    severity = 0.0;
                    break;
                  default:
                    severity = 0.5;
                }
                severityMap[allergenName] = severity;
              }
            }
          }
        }
      }
    } else {
      List<dynamic> allergens = scanData['allergens'] ?? [];
      for (var allergen in allergens) {
        if (allergen is Map<String, dynamic> &&
            allergen['isUserAllergen'] == true) {
          String allergenName =
              allergen['name']?.toString().toLowerCase().trim() ?? '';
          String riskLevel =
              allergen['riskLevel']?.toString().toLowerCase() ?? 'moderate';

          double severity;
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
            default:
              severity = 0.5;
          }

          if (allergenName.isNotEmpty) {
            severityMap[allergenName] = severity;
          }
        }
      }
    }

    return severityMap;
  }

  void navigateToResult(BuildContext context, DocumentSnapshot doc) async {
    try {
      final scanType = getScanType(doc);
      final data = doc.data() as Map<String, dynamic>;

      if (scanType == 'skin') {
        await navigateToSkinResult(context, doc, data);
      } else {
        await navigateToFoodResult(context, doc, data);
      }
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error opening result: $e')));
    }
  }

  Future<void> navigateToSkinResult(
    BuildContext context,
    DocumentSnapshot doc,
    Map<String, dynamic> data,
  ) async {
    String? fileName = data['fileName'];
    File? imageFile;

    if (fileName != null && fileName.isNotEmpty) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (_) => const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0B8FAC)),
              ),
            ),
      );
      imageFile = await downloadAndCacheImage(fileName, 'skin');
      Navigator.of(context).pop();
    }

    final skinData = {
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

  Future<void> navigateToFoodResult(
    BuildContext context,
    DocumentSnapshot doc,
    Map<String, dynamic> data,
  ) async {
    final dishName = data['dishName'] ?? 'Unknown Dish';
    final description = data['description'] ?? '';
    final ingredients = List<String>.from(data['ingredients'] ?? []);
    final allergensData = data['allergens'] as List<dynamic>? ?? [];
    final isOCRAnalysis = data['isOCRAnalysis'] as bool? ?? false;
    final ingredientColorsData =
        data['ingredientColors'] as List<dynamic>? ?? [];

    final ingredientColors =
        ingredientColorsData.map((item) {
          return IngredientColorInfo.fromJson(item as Map<String, dynamic>);
        }).toList();

    String? fileName = data['fileName'] ?? data['imagePath']?.split('/').last;
    File? imageFile;

    if (fileName != null && fileName.isNotEmpty) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (_) => const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0B8FAC)),
              ),
            ),
      );
      imageFile = await downloadAndCacheImage(fileName, 'food');
      Navigator.of(context).pop();
      if (imageFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load image: $fileName')),
        );
      }
    }

    final allergens =
        allergensData.map((item) {
          final map = item as Map<String, dynamic>;
          return AllergenInfo(
            name: map['name'] ?? 'Unknown',
            riskLevel: map['riskLevel'] ?? 'mild',
            symptoms: List<String>.from(map['symptoms'] ?? []),
            sources:
                map['source'] is List
                    ? List<String>.from(map['source'])
                    : (map['source'] != null ? [map['source'].toString()] : []),
            category: map['category'] ?? 'FDA_MAJOR',
            isUserAllergen: map['isUserAllergen'] ?? false,
          );
        }).toList();

    Map<String, double> historicalSeverity = extractHistoricalSeverityData(
      data,
    );

    IngredientBenefitsMap? benefitsMap;
    if (data.containsKey('ingredientBenefits')) {
      benefitsMap = IngredientBenefitsMap();
      var benefitsData = data['ingredientBenefits'];

      if (benefitsData is Map) {
        Map<String, dynamic> benefits = Map<String, dynamic>.from(benefitsData);
        benefits.forEach((key, value) {
          String ingredientKey = key.toString();
          String benefitValue = value.toString();
          benefitsMap!.addBenefit(ingredientKey, benefitValue);
        });
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => ResultScreen(
              ingredientColors: ingredientColors,
              image: imageFile,
              dishName: dishName,
              description: description,
              ingredients: ingredients,
              allergens: allergens,
              isOCRAnalysis: isOCRAnalysis,
              onIngredientsChanged: (updatedIngredients) async {
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

  Widget buildStatusIcon(bool hasUserAllergen, String scanType) {
    if (scanType == 'skin') {
      return Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: AppColors.moderate,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.medical_services, color: Colors.white, size: 12),
      );
    }

    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: hasUserAllergen ? AppColors.dangerAlert : AppColors.mild,
        shape: BoxShape.circle,
      ),
      child: Icon(
        hasUserAllergen ? Icons.warning : Icons.check,
        color: Colors.white,
        size: 12,
      ),
    );
  }

  Widget buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          buildFilterChip('All', 'all'),
          const SizedBox(width: 8),
          buildFilterChip('Food', 'food'),
          const SizedBox(width: 8),
          buildFilterChip('Skin', 'skin'),
        ],
      ),
    );
  }

  Widget buildFilterChip(String label, String value) {
    final isSelected = selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          selectedFilter = value;
        });
      },
      backgroundColor: Colors.white,
      selectedColor: AppColors.primary.withOpacity(0.2),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 14,
        color: isSelected ? AppColors.primary : const Color(0xFF6C8797),
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
      ),
    );
  }

  Widget buildSearchBar() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: TextField(
        controller: searchController,
        onChanged: (value) {
          setState(() {
            searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText:
              selectedFilter == 'skin'
                  ? 'Search condition name...'
                  : 'Search dish name...',
          hintStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: Color(0xFF6C8797),
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: Color(0xFF6C8797),
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          color: Color(0xFF494949),
        ),
      ),
    );
  }

  Widget buildHistoryCard(
    DocumentSnapshot doc,
    bool isSmallScreen,
    BuildContext context,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    final scanType = getScanType(doc);
    final timestamp = data['timestamp'] as Timestamp?;
    final imageSize = isSmallScreen ? 48.0 : 53.0;

    String timeAgo = 'Just now';
    if (timestamp != null) {
      final difference = DateTime.now().difference(timestamp.toDate());
      if (difference.inDays > 0) {
        timeAgo = '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        timeAgo = '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        timeAgo = '${difference.inMinutes}m ago';
      }
    }

    if (scanType == 'skin') {
      return buildSkinHistoryCard(
        doc,
        data,
        isSmallScreen,
        context,
        timeAgo,
        imageSize,
      );
    } else {
      return buildFoodHistoryCard(
        doc,
        data,
        isSmallScreen,
        context,
        timeAgo,
        imageSize,
      );
    }
  }

  Widget buildSkinHistoryCard(
    DocumentSnapshot doc,
    Map<String, dynamic> data,
    bool isSmallScreen,
    BuildContext context,
    String timeAgo,
    double imageSize,
  ) {
    final conditionName = data['conditionName'] ?? 'Unknown Condition';
    final severity = data['severity'] ?? 'unknown';
    String? fileName = data['fileName'];

    return GestureDetector(
      onTap: () => navigateToResult(context, doc),
      child: Container(
        height: isSmallScreen ? 76 : 84,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.moderate.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Padding(
              padding: EdgeInsets.only(left: isSmallScreen ? 15 : 17),
              child: Container(
                width: imageSize,
                height: imageSize,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(9),
                ),
                child:
                    fileName != null
                        ? FutureBuilder<String?>(
                          future: getImageUrl(fileName, 'skin'),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            }
                            if (snapshot.hasData && snapshot.data != null) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: Image.network(
                                  snapshot.data!,
                                  fit: BoxFit.cover,
                                ),
                              );
                            }
                            return const Icon(Icons.medical_services, size: 24);
                          },
                        )
                        : const Icon(Icons.medical_services, size: 24),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(15, 16, 60, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.medical_services,
                          size: 12,
                          color: AppColors.moderate,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            conditionName,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Color(0xFF494949),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Severity: ${severity.toUpperCase()}',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w400,
                        fontSize: 10,
                        color: Color(0xFF6C8797),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(right: isSmallScreen ? 12 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const SizedBox(height: 8),
                  buildStatusIcon(false, 'skin'),
                  const Spacer(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 10,
                        color: Color(0xFF6C8797),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        timeAgo,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 7,
                          color: Color(0xFF6C8797),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildFoodHistoryCard(
    DocumentSnapshot doc,
    Map<String, dynamic> data,
    bool isSmallScreen,
    BuildContext context,
    String timeAgo,
    double imageSize,
  ) {
    final dishName = data['dishName'] ?? 'Unknown Dish';
    final allergens = data['allergens'] as List<dynamic>? ?? [];
    final ingredients = data['ingredients'] as List<dynamic>? ?? [];
    String? fileName = data['fileName'] ?? data['imagePath']?.split('/').last;

    bool hasUserAllergen = false;
    for (var allergen in allergens) {
      if (allergen is Map<String, dynamic>) {
        bool isUserAllergen = allergen['isUserAllergen'] ?? false;
        if (isUserAllergen) {
          hasUserAllergen = true;
          break;
        }
      }
    }

    return GestureDetector(
      onTap: () => navigateToResult(context, doc),
      child: Container(
        height: isSmallScreen ? 76 : 84,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Padding(
              padding: EdgeInsets.only(left: isSmallScreen ? 15 : 17),
              child: Container(
                width: imageSize,
                height: imageSize,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(9),
                ),
                child:
                    fileName != null
                        ? FutureBuilder<String?>(
                          future: getImageUrl(fileName, 'food'),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            }
                            if (snapshot.hasData && snapshot.data != null) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: Image.network(
                                  snapshot.data!,
                                  fit: BoxFit.cover,
                                ),
                              );
                            }
                            return const Icon(Icons.image, size: 24);
                          },
                        )
                        : const Icon(Icons.image, size: 24),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(15, 16, 60, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      dishName,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Color(0xFF494949),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${ingredients.length} ingredients',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w400,
                        fontSize: 10,
                        color: Color(0xFF6C8797),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(right: isSmallScreen ? 12 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const SizedBox(height: 8),
                  buildStatusIcon(hasUserAllergen, 'food'),
                  const Spacer(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 10,
                        color: Color(0xFF6C8797),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        timeAgo,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 7,
                          color: Color(0xFF6C8797),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildHistorySection(
    String date,
    List<DocumentSnapshot> docs,
    bool isSmallScreen,
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          date,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w400,
            fontSize: isSmallScreen ? 14 : 16,
            color: const Color(0xFF1D2939),
            letterSpacing: -0.45,
          ),
        ),
        const SizedBox(height: 8),
        ...docs.map((doc) => buildHistoryCard(doc, isSmallScreen, context)),
      ],
    );
  }

  Widget buildNoResultsFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No results found',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or filters',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 640;

    return Scaffold(
      backgroundColor: AppColors.defaultbackground,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: const Text(
          'Scan History',
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
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 16 : 23,
              vertical: 20,
            ),
            child: buildSearchBar(),
          ),
          buildFilterChips(),
          Expanded(
            child: StreamBuilder<List<DocumentSnapshot>>(
              stream: getCombinedHistory(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF0B8FAC),
                      ),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading history'));
                }
                final docs = snapshot.data ?? [];
                if (docs.isEmpty &&
                    searchQuery.isEmpty &&
                    selectedFilter == 'all') {
                  return const Center(child: Text('No scan history found'));
                }
                final filteredDocs = filterDocuments(docs);
                if (filteredDocs.isEmpty) {
                  return buildNoResultsFound();
                }
                final groupedDocs = groupDocumentsByDate(filteredDocs);
                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 16 : 23,
                  ),
                  child: Column(
                    children: [
                      ...groupedDocs.entries.map((entry) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            buildHistorySection(
                              entry.key,
                              entry.value,
                              isSmallScreen,
                              context,
                            ),
                            const SizedBox(height: 24),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );  
  }
}
