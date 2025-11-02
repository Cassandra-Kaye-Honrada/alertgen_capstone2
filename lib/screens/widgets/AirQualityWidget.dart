import 'package:allergen/screens/widgets/Air%20Quality/AirQualityDetailScreen.dart';
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

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _getLocation();
    await _determinePopulationFromFirebase();
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
          'LOCAL_AQI',
          'POLLUTANT_ADDITIONAL_INFO',
        ],
        'languageCode': 'en',
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

  void _navigateToDetailScreen() {
    if (_airQualityData != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              // (context) => AirQualityForecastScreen(
              //   location: _location,
              //   currentAQI: _airQualityData!.aqi,
              // ),

          (context) => AirQualityDetailScreen(
            airQualityData: _airQualityData!,
            location: _location,
            applicablePopulations: _applicablePopulations,
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
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child:
            _isLoading
                ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                )
                : _error != null
                ? _buildErrorWidget()
                : _airQualityData != null
                ? _buildAirQualityContent()
                : const Center(child: Text('No data available')),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              _initialize();
            },
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
        // Location header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_on, color: Color(0xFF666666), size: 20),
              const SizedBox(width: 6),
              Text(
                _location,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
        ),

        // Gauge and info section
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Row(
            children: [
              // Circular gauge
              SizedBox(
                width: 140,
                height: 140,
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
                          '$aqi AQI',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333),
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
                      style: TextStyle(fontSize: 14, color: Color(0xFF999999)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      quality,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Dominant pollutant: $dominantPollutant',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Suggestion section
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
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
                    const SizedBox(height: 8),
                    if (_airQualityData!.healthRecommendation != null)
                      Text(
                        _airQualityData!.healthRecommendation!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF666666),
                          height: 1.5,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.arrow_forward,
                color: Color(0xFF333333),
                size: 24,
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
    final radius = size.width / 2 - 12;

    // Background arc
    final backgroundPaint =
        Paint()
          ..color = Colors.grey[300]!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 16
          ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.65,
      math.pi * 1.7,
      false,
      backgroundPaint,
    );

    // Gradient colors based on AQI ranges
    final colors =
        [
          const Color(0xFFFF6B6B), // Red (Hazardous)
          const Color(0xFFFF9F40), // Orange (Unhealthy)
          const Color(0xFFFFD93D), // Yellow (Moderate)
          const Color(0xFF6BCF7F), // Light green (Good)
          const Color(0xFF4CAF50), // Green (Excellent)
        ].reversed.toList();

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
          ..strokeWidth = 16
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
    // Parse indexes array to get AQI data
    final indexes = json['indexes'] as List<dynamic>?;

    Map<String, dynamic>? aqiIndex;
    if (indexes != null && indexes.isNotEmpty) {
      // Try to find uaqi (Universal AQI) or usa_epa first
      aqiIndex = indexes.firstWhere(
        (index) => index['code'] == 'uaqi' || index['code'] == 'usa_epa',
        orElse: () => indexes[0],
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

      // Get dominant pollutant from the index object
      if (aqiIndex['dominantPollutant'] != null) {
        final pollutantCode = aqiIndex['dominantPollutant'] as String;
        dominantPollutant = _formatPollutantName(pollutantCode);
      }
    }

    // Parse health recommendations
    String? healthRecommendation;
    Map<String, String> allHealthRecommendations = {};
    final healthRecommendations =
        json['healthRecommendations'] as Map<String, dynamic>?;

    if (healthRecommendations != null) {
      // Store all available health recommendations
      for (var entry in healthRecommendations.entries) {
        if (entry.value is String && (entry.value as String).isNotEmpty) {
          allHealthRecommendations[entry.key] = entry.value as String;
        }
      }

      // Get the primary recommendation for the current population
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

    // Parse pollutants array to get concentrations
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
