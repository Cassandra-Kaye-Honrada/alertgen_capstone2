import 'package:allergen/screens/health_environment_analytics/AirQualityDetailScreen.dart';
import 'package:allergen/services/push_notification_service.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

enum Population {
  generalPopulation,
  elderly,
  lungDiseasePopulation,
  heartDiseasePopulation,
  athletes,
  pregnantWomen,
  children,
}

class AirQualityWidget extends StatefulWidget {
  final double? latitude;
  final double? longitude;
  final String? apiKey;

  const AirQualityWidget({Key? key, this.latitude, this.longitude, this.apiKey})
    : super(key: key);

  @override
  State<AirQualityWidget> createState() => _AirQualityWidgetState();
}

class _AirQualityWidgetState extends State<AirQualityWidget> {
  AirQualityData? _airQualityData;
  bool _isLoading = false;
  String? _error;
  Population _currentPopulation = Population.generalPopulation;
  List<Population> _applicablePopulations = [];
  double? _latitude;
  double? _longitude;
  String _location = "Loading...";
  int _weeklyAllergenCount = 0;
  int _environmentalAlerts = 0;
  bool _hasCurrentAlert = false;
  String? _alertMessage;
  bool _isAlertDismissed = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _getLocation();
    await _determinePopulationFromFirebase();
    await _fetchWeeklyAllergenCount();
    await _fetchEnvironmentalAlerts();
  }

  Future<void> _fetchEnvironmentalAlerts() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final now = DateTime.now();
      final startDate = now.subtract(const Duration(days: 7));

      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('environmental_alerts')
              .where(
                'timestamp',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
              )
              .get();

      setState(() {
        _environmentalAlerts = snapshot.docs.length;
      });
    } catch (e) {
      print('Error fetching environmental alerts: $e');
      setState(() {
        _environmentalAlerts = 0;
      });
    }
  }

  Future<void> _fetchWeeklyAllergenCount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final startDate = DateTime(2025, 10, 1);
      final endDate = DateTime(2025, 10, 31, 23, 59, 59);

      final foodSnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('history')
              .where(
                'timestamp',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
              )
              .where(
                'timestamp',
                isLessThanOrEqualTo: Timestamp.fromDate(endDate),
              )
              .get();

      final skinSnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('skin_history')
              .where(
                'timestamp',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
              )
              .where(
                'timestamp',
                isLessThanOrEqualTo: Timestamp.fromDate(endDate),
              )
              .get();

      Set<String> uniqueAllergens = {};

      for (var doc in foodSnapshot.docs) {
        final data = doc.data();
        final allergens = data['allergens'] as List<dynamic>?;
        if (allergens != null) {
          for (var allergen in allergens) {
            if (allergen is Map<String, dynamic>) {
              final isUserAllergen =
                  allergen['isUserAllergen'] as bool? ?? false;
              if (isUserAllergen) {
                final name = allergen['name']?.toString().toLowerCase().trim();
                if (name != null && name.isNotEmpty) {
                  uniqueAllergens.add(name);
                }
              }
            }
          }
        }
      }

      for (var doc in skinSnapshot.docs) {
        final data = doc.data();
        final isFoodAllergyRelated =
            data['isFoodAllergyRelated'] as bool? ?? false;
        final likelyFoodTriggers = data['likelyFoodTriggers'] as List<dynamic>?;
        if (isFoodAllergyRelated && likelyFoodTriggers != null) {
          for (var trigger in likelyFoodTriggers) {
            final triggerName = trigger.toString().toLowerCase().trim();
            if (triggerName.isNotEmpty) {
              uniqueAllergens.add(triggerName);
            }
          }
        }
      }

      setState(() {
        _weeklyAllergenCount = uniqueAllergens.length;
      });
    } catch (e) {
      print('Error fetching weekly allergen count: $e');
      setState(() {
        _weeklyAllergenCount = 0;
      });
    }
  }

  Future<void> _getLocation() async {
    if (widget.latitude != null && widget.longitude != null) {
      _latitude = widget.latitude;
      _longitude = widget.longitude;
      await _getLocationName(_latitude!, _longitude!);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _error = 'Location services are disabled. Please enable location.';
          _isLoading = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _error = 'Location permission denied';
            _isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _error =
              'Location permission permanently denied. Please enable in settings.';
          _isLoading = false;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Location request timed out');
        },
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });

      await _getLocationName(_latitude!, _longitude!);
    } catch (e) {
      setState(() {
        _error = 'Error getting location: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _getLocationName(double lat, double lon) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _location =
              '${place.locality ?? place.subAdministrativeArea ?? "Unknown"}';
        });
      }
    } catch (e) {
      print('Error getting location name: $e');
      setState(() {
        _location = 'Current Location';
      });
    }
  }

  Future<void> _determinePopulationFromFirebase() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

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
        await _fetchAirQuality();
      } else {
        _applicablePopulations = [Population.generalPopulation];
        _currentPopulation = Population.generalPopulation;
        await _fetchAirQuality();
      }
    } catch (e) {
      print('Error determining population: $e');
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
      setState(() {
        _error = 'Location not available';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiKey =
          widget.apiKey ??
          const String.fromEnvironment('GOOGLE_AIR_QUALITY_API_KEY');

      if (apiKey.isEmpty) {
        setState(() {
          _error =
              'API key not configured.\n\n'
              'Please provide an API key:\n'
              '1. Pass it as a parameter: AirQualityWidget(apiKey: "YOUR_KEY")\n'
              '2. Or set it as an environment variable: GOOGLE_AIR_QUALITY_API_KEY\n\n'
              'To get an API key:\n'
              '1. Go to console.cloud.google.com\n'
              '2. Enable Air Quality API\n'
              '3. Create an API key\n'
              '4. Add API key restrictions for security';
          _isLoading = false;
        });
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
          'LOCAL_AQI', // Use local AQI (NAQI for India)
          'POLLUTANT_ADDITIONAL_INFO',
        ],
        'languageCode': 'en',
        'universalAqi': false, // Prefer local AQI over universal
      };

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode(requestBody),
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw Exception('Request timed out');
            },
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _airQualityData = AirQualityData.fromGoogleJson(
            data,
            _currentPopulation,
            _getPopulationRecommendationKey(_currentPopulation),
            _applicablePopulations,
          );
          _isLoading = false;
        });

        // Check if current air quality warrants an alert
        await _checkAndSaveAlert();
      } else {
        final errorData = json.decode(response.body);
        final errorMessage = errorData['error']?['message'] ?? 'Unknown error';
        final errorStatus = errorData['error']?['status'] ?? '';

        setState(() {
          _error =
              'API Error (${response.statusCode}): $errorMessage\n'
              'Status: $errorStatus\n\n'
              'Common causes:\n'
              '• Invalid or missing API key\n'
              '• Air Quality API not enabled in Google Cloud\n'
              '• Billing not set up on Google Cloud project\n'
              '• API key restrictions blocking the request\n'
              '• Quota exceeded';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error fetching air quality data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _checkAndSaveAlert() async {
    if (_airQualityData == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    bool shouldAlert = false;
    String alertLevel = '';
    String affectedPopulations = '';

    final aqi = _airQualityData!.aqi;

    // NAQI (India) thresholds:
    // 0-50: Good
    // 51-100: Satisfactory
    // 101-200: Moderate
    // 201-300: Poor
    // 301-400: Very Poor
    // 401-500: Severe

    // Check alert thresholds based on populations
    if (_applicablePopulations.contains(Population.pregnantWomen) ||
        _applicablePopulations.contains(Population.lungDiseasePopulation) ||
        _applicablePopulations.contains(Population.heartDiseasePopulation) ||
        _applicablePopulations.contains(Population.children)) {
      // Sensitive groups: alert at NAQI > 100 (Moderate and above)
      if (aqi > 100) {
        shouldAlert = true;
        if (aqi > 400) {
          alertLevel = 'Severe';
        } else if (aqi > 300) {
          alertLevel = 'Very Poor';
        } else if (aqi > 200) {
          alertLevel = 'Poor';
        } else {
          alertLevel = 'Moderate';
        }
      }
    } else {
      // General population: alert at NAQI > 200 (Poor and above)
      if (aqi > 200) {
        shouldAlert = true;
        if (aqi > 400) {
          alertLevel = 'Severe';
        } else if (aqi > 300) {
          alertLevel = 'Very Poor';
        } else {
          alertLevel = 'Poor';
        }
      }
    }

    if (shouldAlert) {
      // Build affected populations string
      List<String> popNames = [];
      for (var pop in _applicablePopulations) {
        switch (pop) {
          case Population.pregnantWomen:
            popNames.add('Pregnant Women');
            break;
          case Population.lungDiseasePopulation:
            popNames.add('Lung Disease');
            break;
          case Population.heartDiseasePopulation:
            popNames.add('Heart Disease');
            break;
          case Population.children:
            popNames.add('Children');
            break;
          case Population.elderly:
            popNames.add('Elderly');
            break;
          case Population.athletes:
            popNames.add('Athletes');
            break;
          default:
            break;
        }
      }
      affectedPopulations = popNames.join(', ');

      // Check if we should send an alert
      // Logic: Send alert if either:
      // 1. No alert exists for this location today
      // 2. Last alert for this location was more than 6 hours ago
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final sixHoursAgo = now.subtract(const Duration(hours: 1));

      final recentAlerts =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('environmental_alerts')
              .where('location', isEqualTo: _location)
              .where(
                'timestamp',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
              )
              .orderBy('timestamp', descending: true)
              .limit(1)
              .get();

      bool shouldSendNotification = false;

      if (recentAlerts.docs.isEmpty) {
        // No alert today for this location
        shouldSendNotification = true;
      } else {
        // Check if last alert was more than 6 hours ago
        final lastAlert = recentAlerts.docs.first;
        final lastAlertTime = (lastAlert['timestamp'] as Timestamp).toDate();

        if (lastAlertTime.isBefore(sixHoursAgo)) {
          shouldSendNotification = true;
        }
      }

      // Save alert and send notification if needed
      if (shouldSendNotification) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('environmental_alerts')
            .add({
              'timestamp': FieldValue.serverTimestamp(),
              'aqi': aqi,
              'alertLevel': alertLevel,
              'qualityLevel': _airQualityData!.qualityLevel,
              'dominantPollutant': _airQualityData!.dominantPollutant,
              'location': _location,
              'affectedPopulations': affectedPopulations,
              'healthRecommendation': _airQualityData!.healthRecommendation,
            });

        // Send push notification
        await PushNotificationService().showEnvironmentalAlert(
          title: '⚠️ $alertLevel Air Quality Alert',
          body:
              'NAQI: $aqi in $_location. ${_airQualityData!.healthRecommendation ?? "Take precautions."}',
          alertLevel: alertLevel,
          aqi: aqi,
        );

        // Refresh alert count
        await _fetchEnvironmentalAlerts();
      }

      // Set alert for UI display (always show if conditions are poor)
      setState(() {
        _hasCurrentAlert = true;
        _isAlertDismissed = false; // Reset dismiss state for new alert
        _alertMessage = '$alertLevel Air Quality • NAQI $aqi';
      });
    } else {
      setState(() {
        _hasCurrentAlert = false;
        _alertMessage = null;
        _isAlertDismissed = false; // Reset dismiss state
      });
    }
  }

  void _navigateToDetailScreen() {
    if (_airQualityData != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => AirQualityDetailScreen(
                airQualityData: _airQualityData!,
                location: _location,
                applicablePopulations: _applicablePopulations,
                showBackButton:
                    true, // ADD THIS LINE - tells it to show back button
              ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _navigateToDetailScreen,
      child: Container(
        child:
            _isLoading
                ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                )
                : _error != null
                ? _buildErrorWidget()
                : _airQualityData != null
                ? _buildAirQualityContent()
                : const Center(
                  child: Text(
                    'No data available',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.white70),
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _initialize,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF2B9EB3),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildAirQualityContent() {
    final aqi = _airQualityData!.aqi;
    final quality = _airQualityData!.qualityLevel;
    final dominantPollutant = _airQualityData!.dominantPollutant;

    return Column(
      children: [
        // Alert banner (if applicable)
        if (_hasCurrentAlert && _alertMessage != null && !_isAlertDismissed)
          Container(
            margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade50, Colors.orange.shade100],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade300, width: 1),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade200,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning_rounded,
                    color: Colors.orange.shade800,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _alertMessage!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade900,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isAlertDismissed = true;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close,
                      size: 18,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),

        Container(
          padding: const EdgeInsets.fromLTRB(10, 24, 20, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '$_weeklyAllergenCount',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'potential allergens\ndetected this week',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 60, color: Colors.white30),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '$_environmentalAlerts',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'environmental\nalerts this week',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Location
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_on, color: Colors.white70, size: 18),
              const SizedBox(width: 6),
              Text(
                _location,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // White card section
        Container(
          margin: const EdgeInsets.fromLTRB(5, 0, 5, 5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                spreadRadius: 2,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // AQI gauge and info
              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Circular gauge
                    SizedBox(
                      width: 110,
                      height: 120,
                      child: CustomPaint(
                        painter: AQIGaugePainter(
                          aqi: aqi.toDouble(),
                          color: _airQualityData!.color,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$aqi',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF333333),
                                ),
                              ),
                              const Text(
                                'AQI',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF666666),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 24),

                    // Air quality info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Air Quality Index',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF999999),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            quality,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF333333),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Dominant pollutant: $dominantPollutant',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF666666),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Divider
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                color: const Color(0xFFE0E0E0),
              ),

              // Suggestion section
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Suggestion for you',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_airQualityData!.healthRecommendation != null)
                      Text(
                        _airQualityData!.healthRecommendation!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF666666),
                          height: 1.5,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class AQIGaugePainter extends CustomPainter {
  final double aqi;
  final Color color;

  AQIGaugePainter({required this.aqi, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    // Background arc
    final backgroundPaint =
        Paint()
          ..color = Colors.grey[200]!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.65,
      math.pi * 1.7,
      false,
      backgroundPaint,
    );

    // NAQI (India) color gradient
    final colors = [
      const Color(0xFF00E400), // Green (0-50: Good)
      const Color(0xFF92D050), // Light Green (51-100: Satisfactory)
      const Color(0xFFFFFF00), // Yellow (101-200: Moderate)
      const Color(0xFFFF7E00), // Orange (201-300: Poor)
      const Color(0xFFFF0000), // Red (301-400: Very Poor)
      const Color(0xFF990000), // Dark Red (401-500: Severe)
    ];

    final gradient = SweepGradient(
      startAngle: math.pi * 0.65,
      endAngle: math.pi * 2.35,
      colors: colors,
    );

    final foregroundPaint =
        Paint()
          ..shader = gradient.createShader(
            Rect.fromCircle(center: center, radius: radius),
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round;

    // Calculate sweep angle (max AQI 500)
    final normalizedAqi = (aqi / 500).clamp(0.0, 1.0);
    final sweepAngle = normalizedAqi * math.pi * 1.7;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.65,
      sweepAngle,
      false,
      foregroundPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class AirQualityData {
  final int aqi;
  final String qualityLevel;
  final Color color;
  final String dominantPollutant;
  final String? healthRecommendation;
  final Map<String, double> components;
  final Map<String, String> allHealthRecommendations;

  AirQualityData({
    required this.aqi,
    required this.qualityLevel,
    required this.color,
    required this.dominantPollutant,
    this.healthRecommendation,
    required this.components,
    required this.allHealthRecommendations,
  });

  factory AirQualityData.fromGoogleJson(
    Map<String, dynamic> json,
    Population population,
    String populationRecommendationKey,
    List<Population> applicablePopulations,
  ) {
    final indexes = json['indexes'] as List<dynamic>?;

    Map<String, dynamic>? aqiIndex;
    if (indexes != null && indexes.isNotEmpty) {
      // Look for India's NAQI (CPCB) first
      aqiIndex = indexes.firstWhere(
        (index) => index['code'] == 'ind_cpcb', // India CPCB/NAQI code
        orElse: () {
          // Fallback to any local AQI, then universal
          return indexes.firstWhere(
            (index) => index['code'] != 'uaqi',
            orElse: () => indexes[0],
          );
        },
      );
    }

    int aqi = 0;
    String qualityLevel = 'Unknown';
    Color color = Colors.grey;
    String dominantPollutant = 'N/A';

    if (aqiIndex != null) {
      aqi = (aqiIndex['aqi'] as num?)?.toInt() ?? 0;
      qualityLevel = aqiIndex['category'] ?? 'Unknown';
      color = _getColorForCategory(aqiIndex['color'] as Map<String, dynamic>?);

      if (aqiIndex['dominantPollutant'] != null) {
        final pollutantCode = aqiIndex['dominantPollutant'] as String;
        dominantPollutant = _formatPollutantName(pollutantCode);
      }
    }

    String? healthRecommendation;
    Map<String, String> allHealthRecommendations = {};
    final healthRecommendations =
        json['healthRecommendations'] as Map<String, dynamic>?;

    if (healthRecommendations != null) {
      for (var entry in healthRecommendations.entries) {
        if (entry.value is String && (entry.value as String).isNotEmpty) {
          allHealthRecommendations[entry.key] = entry.value as String;
        }
      }

      healthRecommendation =
          healthRecommendations[populationRecommendationKey] as String?;

      if (healthRecommendation == null || healthRecommendation.isEmpty) {
        healthRecommendation =
            healthRecommendations['generalPopulation'] as String?;
      }

      if (healthRecommendation == null || healthRecommendation.isEmpty) {
        for (var entry in healthRecommendations.entries) {
          if (entry.value is String && (entry.value as String).isNotEmpty) {
            healthRecommendation = entry.value as String;
            break;
          }
        }
      }
    }

    Map<String, double> components = {};
    final pollutants = json['pollutants'] as List<dynamic>?;
    if (pollutants != null) {
      for (var pollutant in pollutants) {
        final code = pollutant['code'] as String?;
        final concentration = pollutant['concentration']?['value'] as num?;
        if (code != null && concentration != null) {
          components[code] = concentration.toDouble();
        }
      }
    }

    return AirQualityData(
      aqi: aqi,
      qualityLevel: qualityLevel,
      color: color,
      dominantPollutant: dominantPollutant,
      healthRecommendation: healthRecommendation,
      components: components,
      allHealthRecommendations: allHealthRecommendations,
    );
  }

  static Color _getColorForCategory(Map<String, dynamic>? colorData) {
    if (colorData == null) return Colors.grey;

    final red = (colorData['red'] as num?)?.toInt() ?? 128;
    final green = (colorData['green'] as num?)?.toInt() ?? 128;
    final blue = (colorData['blue'] as num?)?.toInt() ?? 128;

    return Color.fromARGB(255, red, green, blue);
  }

  static String _formatPollutantName(String code) {
    final pollutantNames = {
      'pm25': 'PM2.5',
      'pm10': 'PM10',
      'o3': 'Ozone',
      'no2': 'Nitrogen Dioxide',
      'so2': 'Sulfur Dioxide',
      'co': 'Carbon Monoxide',
    };

    return pollutantNames[code.toLowerCase()] ?? code.toUpperCase();
  }
}
