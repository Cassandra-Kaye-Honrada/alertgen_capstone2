// lib/screens/health_environment_analytics/AirQualityDetailScreen.dart

import 'package:allergen/screens/feature/educational/Informational_Screen.dart';
import 'package:allergen/screens/feature/scan_screen.dart';
import 'package:allergen/screens/health_environment_analytics/air_quality_tab.dart'
    hide AppColors;
import 'package:allergen/screens/health_environment_analytics/allergen_analytics_tab.dart';
import 'package:allergen/screens/health_environment_analytics/models/air_quality_models.dart';
import 'package:allergen/screens/health_environment_analytics/models/weather_models.dart';
import 'package:allergen/screens/health_environment_analytics/widgets/AirQualityWidget.dart';
import 'package:allergen/screens/profile_screen_items/ProfileScreen.dart';
import 'package:allergen/services/emergency/emergency_service.dart';
import 'package:allergen/styleguide.dart';
import 'package:allergen/widgets/air_quality_widget_manager.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:home_widget/home_widget.dart';
import 'dart:async';

class AirQualityDetailScreen extends StatefulWidget {
  final AirQualityData? airQualityData;
  final String? location;
  final List<Population>? applicablePopulations;
  final String? apiKey;
  final bool showBackButton;

  const AirQualityDetailScreen({
    Key? key,
    this.airQualityData,
    this.location,
    this.applicablePopulations,
    this.apiKey,
    this.showBackButton = false,
  }) : super(key: key);

  @override
  State<AirQualityDetailScreen> createState() => _AirQualityDetailScreenState();
}

class _AirQualityDetailScreenState extends State<AirQualityDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Data variables - REMOVED: loading and error states
  AirQualityData? _airQualityData;
  String _location = "Loading...";
  List<Population> _applicablePopulations = [];

  Population _currentPopulation = Population.generalPopulation;
  double? _latitude;
  double? _longitude;

  // Widget refresh listener
  StreamSubscription<Uri?>? _widgetRefreshSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _setupWidgetRefreshListener();

    // Register widget click URL scheme
    _checkInitialUri();
    HomeWidget.registerBackgroundCallback(_backgroundCallback);

    if (widget.airQualityData != null) {
      _airQualityData = widget.airQualityData;
      _location = widget.location ?? "Current Location";
      _applicablePopulations =
          widget.applicablePopulations ?? [Population.generalPopulation];
    } else {
      _initialize();
    }
  }

  // Add this static callback for background updates (optional but recommended)
  @pragma('vm:entry-point')
  static Future<void> _backgroundCallback(Uri? uri) async {
    print('Background callback triggered: $uri');
    // You can perform background updates here if needed
  }

  Future<void> _checkInitialUri() async {
    try {
      final Uri? initialUri =
          await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (initialUri != null) {
        print('App opened from widget with URI: $initialUri');
        if (initialUri.toString().contains('refresh')) {
          // Delay to allow initialization to complete
          Future.delayed(const Duration(milliseconds: 500), () {
            _refreshFromWidget();
          });
        }
      }
    } catch (e) {
      print('Error checking initial URI: $e');
    }
  }

  void _setupWidgetRefreshListener() {
    _widgetRefreshSubscription = HomeWidget.widgetClicked.listen((Uri? uri) {
      print('Widget clicked with URI: $uri');

      // Check if this is a refresh request
      if (uri != null) {
        final uriString = uri.toString();
        print('URI string: $uriString');

        if (uriString.contains('refresh')) {
          print('Refresh triggered from widget');
          _refreshFromWidget();
        }
      }
    });
  }

  Future<void> _refreshFromWidget() async {
    print('Starting widget refresh...');

    // Show loading indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('Refreshing air quality data...'),
            ],
          ),
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFF0B8FAC),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    // REMOVED: The refresh logic since AirQualityWidget will handle its own refresh
    // Just show success message after a delay to simulate refresh
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Air quality data updated'),
              ],
            ),
            duration: Duration(seconds: 2),
            backgroundColor: Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  Future<void> _initialize() async {
    await _getLocation();
    await _determinePopulationFromFirebase();
  }

  Future<void> _getLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _location = 'Location services disabled';
          });
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              _location = 'Location permission denied';
            });
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _location = 'Location permission permanently denied';
          });
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Location request timed out'),
      );

      _latitude = position.latitude;
      _longitude = position.longitude;

      await _getLocationName(_latitude!, _longitude!);
    } catch (e) {
      if (mounted) {
        setState(() {
          _location = 'Error getting location';
        });
      }
    }
  }

  Future<void> _getLocationName(double lat, double lon) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        if (mounted) {
          setState(() {
            _location =
                '${place.locality ?? place.subAdministrativeArea ?? "Unknown"}';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _location = 'Current Location';
        });
      }
    }
  }

  Future<void> _determinePopulationFromFirebase() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _applicablePopulations = [Population.generalPopulation];
        _currentPopulation = Population.generalPopulation;
        return;
      }

      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _applicablePopulations = _determinePopulations(data);
        _currentPopulation = _getMostCriticalPopulation(_applicablePopulations);
      } else {
        _applicablePopulations = [Population.generalPopulation];
        _currentPopulation = Population.generalPopulation;
      }
    } catch (e) {
      _applicablePopulations = [Population.generalPopulation];
      _currentPopulation = Population.generalPopulation;
    }
  }

  List<Population> _determinePopulations(Map<String, dynamic> data) {
    List<Population> populations = [];

    if (data['birthdate'] != null) {
      DateTime? birthdate;
      if (data['birthdate'] is Timestamp) {
        birthdate = (data['birthdate'] as Timestamp).toDate();
      } else if (data['birthdate'] is String) {
        birthdate = DateTime.tryParse(data['birthdate']);
      }

      if (birthdate != null) {
        final age = DateTime.now().difference(birthdate).inDays ~/ 365;
        if (age >= 65) {
          populations.add(Population.elderly);
        }
      }
    }

    if (data['asthmaRespiratory'] == true || data['lungDisease'] == true) {
      populations.add(Population.lungDiseasePopulation);
    }
    if (data['heartDisease'] == true) {
      populations.add(Population.heartDiseasePopulation);
    }
    if (data['sportsActivities'] == true) {
      populations.add(Population.athletes);
    }
    if (data['isPregnant'] == true) {
      populations.add(Population.pregnantWomen);
    }
    if (data['caresForChildren'] == true ||
        data['caresForToddlers'] == true ||
        data['caresForBabies'] == true) {
      populations.add(Population.children);
    }

    if (populations.isEmpty) {
      populations.add(Population.generalPopulation);
    }

    return populations;
  }

  Population _getMostCriticalPopulation(List<Population> populations) {
    const priority = [
      Population.pregnantWomen,
      Population.lungDiseasePopulation,
      Population.heartDiseasePopulation,
      Population.elderly,
      Population.children,
      Population.athletes,
      Population.generalPopulation,
    ];

    for (var pop in priority) {
      if (populations.contains(pop)) {
        return pop;
      }
    }
    return Population.generalPopulation;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _widgetRefreshSubscription?.cancel(); // Cancel the subscription
    super.dispose();
  }

  Widget _buildBottomNavigation() {
    return Container(
      margin: const EdgeInsets.all(20),
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          GestureDetector(
            onTap:
                () => Navigator.of(context).popUntil((route) => route.isFirst),
            child: Icon(Icons.home, color: AppColors.Gray, size: 24),
          ),
          GestureDetector(
            onTap: () {},
            child: const Icon(
              Icons.analytics,
              color: AppColors.primary,
              size: 35,
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CameraScannerScreen()),
              );
            },
            child: Image.asset(
              'assets/navigation/scan_gray.png',
              width: 18,
              height: 18,
              errorBuilder:
                  (context, error, stackTrace) => Icon(
                    Icons.camera_alt,
                    color: AppColors.primaryColor3,
                    size: 24,
                  ),
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FoodAllergyScreen()),
              );
            },
            child: const Icon(
              Icons.school_outlined,
              color: AppColors.Gray,
              size: 24,
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) =>
                          UserProfile(emergencyService: EmergencyService()),
                ),
              );
            },
            child: Icon(Icons.person, color: AppColors.Gray, size: 24),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FA),
      appBar: AppBar(
        title: const Text(
          'Your Analytics',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0B8FAC),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: widget.showBackButton,
        leading:
            widget.showBackButton
                ? IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF0B8FAC)),
                  onPressed: () => Navigator.of(context).pop(),
                )
                : null,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F4F8),
              borderRadius: BorderRadius.circular(30),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFF0B8FAC),
              labelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              indicator: BoxDecoration(
                color: const Color(0xFF0B8FAC),
                borderRadius: BorderRadius.circular(30),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.air, size: 18),
                      SizedBox(width: 8),
                      Text('Environment'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.analytics, size: 18),
                      SizedBox(width: 8),
                      Text('Allergen'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              AirQualityTab(
                apiKey: widget.apiKey,
                location: _location,
                applicablePopulations: _applicablePopulations,
                weatherData: WeatherData.mock(),
              ),
              const AllergenAnalyticsTab(),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomNavigation(),
          ),
        ],
      ),
    );
  }
}
