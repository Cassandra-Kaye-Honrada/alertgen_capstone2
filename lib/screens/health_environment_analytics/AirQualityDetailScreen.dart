// lib/screens/health_environment_analytics/AirQualityDetailScreen.dart

import 'package:allergen/screens/feature/educational/Informational_Screen.dart';
import 'package:allergen/screens/feature/scan_screen.dart';
import 'package:allergen/screens/health_environment_analytics/air_quality_tab.dart';
import 'package:allergen/screens/health_environment_analytics/allergen_analytics_tab.dart';
import 'package:allergen/screens/health_environment_analytics/models/weather_models.dart';
import 'package:allergen/screens/health_environment_analytics/widgets/AirQualityWidget.dart';
import 'package:allergen/screens/profile_screen_items/ProfileScreen.dart';
import 'package:allergen/services/emergency/emergency_service.dart';
import 'package:allergen/styleguide.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class AirQualityDetailScreen extends StatefulWidget {
  final AirQualityData? airQualityData;
  final String? location;
  final List<Population>? applicablePopulations;
  final String? apiKey;

  const AirQualityDetailScreen({
    Key? key,
    this.airQualityData,
    this.location,
    this.applicablePopulations,
    this.apiKey,
  }) : super(key: key);

  @override
  State<AirQualityDetailScreen> createState() => _AirQualityDetailScreenState();
}

class _AirQualityDetailScreenState extends State<AirQualityDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Data variables
  AirQualityData? _airQualityData;
  String _location = "Loading...";
  List<Population> _applicablePopulations = [];
  bool _isLoadingData = false;
  String? _error;

  Population _currentPopulation = Population.generalPopulation;
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Check if data was provided
    if (widget.airQualityData != null) {
      // Use provided data
      _airQualityData = widget.airQualityData;
      _location = widget.location ?? "Current Location";
      _applicablePopulations =
          widget.applicablePopulations ?? [Population.generalPopulation];
    } else {
      // Fetch data silently in background
      _initialize();
    }
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
            _error = 'Location services are disabled';
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
              _error = 'Location permission denied';
            });
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _error = 'Location permission permanently denied';
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
          _error = 'Error getting location: ${e.toString()}';
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
        await _fetchAirQuality();
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

      await _fetchAirQuality();
    } catch (e) {
      _applicablePopulations = [Population.generalPopulation];
      _currentPopulation = Population.generalPopulation;
      await _fetchAirQuality();
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

  String _getPopulationRecommendationKey(Population population) {
    switch (population) {
      case Population.generalPopulation:
        return 'generalPopulation';
      case Population.elderly:
        return 'elderly';
      case Population.lungDiseasePopulation:
        return 'lungDiseasePopulation';
      case Population.heartDiseasePopulation:
        return 'heartDiseasePopulation';
      case Population.athletes:
        return 'athletes';
      case Population.pregnantWomen:
        return 'pregnantWomen';
      case Population.children:
        return 'children';
    }
  }

  Future<void> _fetchAirQuality() async {
    if (_latitude == null || _longitude == null) {
      if (mounted) {
        setState(() {
          _error = 'Location not available';
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingData = true;
      });
    }

    try {
      final apiKey =
          widget.apiKey ??
          const String.fromEnvironment('GOOGLE_AIR_QUALITY_API_KEY');

      if (apiKey.isEmpty) {
        if (mounted) {
          setState(() {
            _error = 'API key not configured';
            _isLoadingData = false;
          });
        }
        return;
      }

      final url = Uri.parse(
        'https://airquality.googleapis.com/v1/currentConditions:lookup?key=$apiKey',
      );

      final requestBody = {
        'location': {'latitude': _latitude, 'longitude': _longitude},
        'extraComputations': [
          'HEALTH_RECOMMENDATIONS',
          'DOMINANT_POLLUTANT_CONCENTRATION',
          'POLLUTANT_CONCENTRATION',
          'LOCAL_AQI',
          'POLLUTANT_ADDITIONAL_INFO',
        ],
        'languageCode': 'en',
        'universalAqi': false,
      };

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode(requestBody),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _airQualityData = AirQualityData.fromGoogleJson(
              data,
              _currentPopulation,
              _getPopulationRecommendationKey(_currentPopulation),
              _applicablePopulations,
            );
            _isLoadingData = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Failed to load air quality data';
            _isLoadingData = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error: ${e.toString()}';
          _isLoadingData = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.white,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF0B8FAC)),
            SizedBox(height: 16),
            Text(
              'Loading air quality data...',
              style: TextStyle(color: Color(0xFF666666), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initialize,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0B8FAC),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
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
          // Home
          GestureDetector(
            onTap:
                () => Navigator.of(context).popUntil((route) => route.isFirst),
            child: Image.asset(
              'assets/navigation/menu_inactive.png',
              width: 24,
              height: 24,
              errorBuilder:
                  (context, error, stackTrace) =>
                      Icon(Icons.home, color: Color(0xFF64748B), size: 24),
            ),
          ),

          // Air Quality (Current - Active)
          GestureDetector(
            onTap: () {}, // Already on this screen
            child: const Icon(
              Icons.analytics,
              color: AppColors.primary,
              size: 35,
            ),
          ),

          // Scanner
          GestureDetector(
            onTap: () {
              // Navigate to scanner - you'll need to import your scanner screen
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CameraScannerScreen()),
              );
            },
            child: Image.asset(
              'assets/navigation/scan_inactive.png',
              width: 24,
              height: 24,
              errorBuilder:
                  (context, error, stackTrace) => Icon(
                    Icons.camera_alt,
                    color: AppColors.primaryColor3,
                    size: 24,
                  ),
            ),
          ),

          // Education/Food Allergy
          GestureDetector(
            onTap: () {
              // Navigate to food allergy screen
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FoodAllergyScreen()),
              );
            },
            child: const Icon(
              Icons.school_outlined,
              color: AppColors.primaryColor3,
              size: 24,
            ),
          ),

          // Profile
          GestureDetector(
            onTap: () {
              // Navigate to profile
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

  @override
  Widget build(BuildContext context) {
    // Show tabs immediately, let content handle loading/error states
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health & Environment Details'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF0B8FAC),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF0B8FAC),
          tabs: const [
            Tab(icon: Icon(Icons.air), text: 'Air Quality'),
            Tab(icon: Icon(Icons.analytics), text: 'Allergen Analytics'),
          ],
        ),
      ),
      body: Stack(
        children: [
          _airQualityData == null
              ? (_error != null ? _buildErrorState() : _buildLoadingOverlay())
              : TabBarView(
                controller: _tabController,
                children: [
                  AirQualityTab(
                    airQualityData: _airQualityData!,
                    location: _location,
                    applicablePopulations: _applicablePopulations,
                    weatherData: WeatherData.mock(),
                  ),
                  AllergenAnalyticsTab(airQualityData: _airQualityData!),
                ],
              ),
          // Bottom Navigation
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