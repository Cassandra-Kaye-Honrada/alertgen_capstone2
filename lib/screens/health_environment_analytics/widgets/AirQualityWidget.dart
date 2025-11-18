import 'package:allergen/screens/health_environment_analytics/AirQualityDetailScreen.dart';
import 'package:allergen/screens/health_environment_analytics/models/air_quality_models.dart';
import 'package:allergen/services/push_notification_service.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class AirQualityWidget extends StatefulWidget {
  final double? latitude;
  final double? longitude;
  final String? apiKey;
  final bool overflow;
  final bool showSearch;
  final bool showRefresh;
  final bool showLocation;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final double gaugeSize;
    final bool healthRecoOverflow;

  const AirQualityWidget({
    Key? key,
    this.latitude,
    this.longitude,
    this.apiKey,
    this.overflow = true,
    this.showSearch = true,
    this.showRefresh = true,
    this.showLocation = true,
    this.margin,
    this.padding,
    this.gaugeSize = 100,   this.healthRecoOverflow = true,
  }) : super(key: key);

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

  // Search related
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchSuggestions = [];
  bool _isLoadingSuggestions = false;
  Timer? _debounceTimer;
  bool _isUsingSearchedLocation = false;

  // Caching related
  Timer? _refreshTimer;
  DateTime? _lastFetchTime;
  static const Duration _cacheDuration = Duration(minutes: 5);

  // Cached data for placeholder
  AirQualityData? _cachedAirQualityData;
  bool _isUsingCachedData = false;

  @override
  void initState() {
    super.initState();
    _initialize();
    _setupAutoRefresh();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _setupAutoRefresh() {
    _refreshTimer = Timer.periodic(_cacheDuration, (timer) {
      if (!_isUsingSearchedLocation) {
        _refreshAirQualityData();
      }
    });
  }

  Future<void> _refreshAirQualityData() async {
    if (_latitude != null && _longitude != null && !_isUsingSearchedLocation) {
      await _fetchAirQuality(forceRefresh: true);
    }
  }

  Future<void> _initialize() async {
    // First try to load cached data immediately for instant display
    await _loadCachedDataForPlaceholder();

    // Then proceed with normal initialization
    await _loadCachedData();
    await _getLocation();
    await _determinePopulationFromFirebase();
  }

  Future<void> _loadCachedDataForPlaceholder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('cached_aqi_data');

      if (cachedData != null) {
        final data = json.decode(cachedData);
        final airQualityData = data['airQualityData'];

        // Create AirQualityData from cached data for placeholder
        setState(() {
          _cachedAirQualityData = AirQualityData.fromGoogleJson(
            airQualityData,
            _currentPopulation,
            _getPopulationRecommendationKey(_currentPopulation),
            _applicablePopulations,
          );
          _location = data['location'] ?? 'Current Location';
        });
      }
    } catch (e) {
      print('Error loading cached data for placeholder: $e');
    }
  }

  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('cached_aqi_data');
      final cachedTimestamp = prefs.getInt('cached_aqi_timestamp');

      if (cachedData != null && cachedTimestamp != null) {
        final cacheTime = DateTime.fromMillisecondsSinceEpoch(cachedTimestamp);
        _lastFetchTime = cacheTime;

        if (DateTime.now().difference(cacheTime) < _cacheDuration) {
          final data = json.decode(cachedData);
          setState(() {
            _airQualityData = AirQualityData.fromGoogleJson(
              data['airQualityData'],
              _currentPopulation,
              _getPopulationRecommendationKey(_currentPopulation),
              _applicablePopulations,
            );
            _location = data['location'] ?? 'Current Location';
            _latitude = data['latitude'];
            _longitude = data['longitude'];
          });
        }
      }
    } catch (e) {
      print('Error loading cached data: $e');
    }
  }

  Future<void> _saveCachedData(Map<String, dynamic> airQualityResponse) async {
    if (_isUsingSearchedLocation) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'airQualityData': airQualityResponse,
        'location': _location,
        'latitude': _latitude,
        'longitude': _longitude,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await prefs.setString('cached_aqi_data', json.encode(cacheData));
      await prefs.setInt(
        'cached_aqi_timestamp',
        DateTime.now().millisecondsSinceEpoch,
      );
      _lastFetchTime = DateTime.now();
    } catch (e) {
      print('Error saving cached data: $e');
    }
  }

  void _onSearchChanged(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    if (query.isEmpty) {
      setState(() {
        _searchSuggestions = [];
        _isLoadingSuggestions = false;
      });
      return;
    }

    setState(() {
      _isLoadingSuggestions = true;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _fetchLocationSuggestions(query);
    });
  }

  Future<void> _fetchLocationSuggestions(String query) async {
    try {
      final apiKey =
          widget.apiKey ??
          const String.fromEnvironment('GOOGLE_AIR_QUALITY_API_KEY');

      if (apiKey.isEmpty) {
        setState(() {
          _searchSuggestions = [];
          _isLoadingSuggestions = false;
        });
        return;
      }

      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeComponent(query)}'
        '&types=(cities)'
        '&key=$apiKey',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['predictions'] != null) {
          List<Map<String, dynamic>> suggestions = [];

          for (var prediction in data['predictions'].take(5)) {
            suggestions.add({
              'placeId': prediction['place_id'],
              'description': prediction['description'],
            });
          }

          setState(() {
            _searchSuggestions = suggestions;
            _isLoadingSuggestions = false;
          });
        } else {
          await _fallbackGeocodingSuggestions(query);
        }
      } else {
        await _fallbackGeocodingSuggestions(query);
      }
    } catch (e) {
      print('Error fetching suggestions: $e');
      await _fallbackGeocodingSuggestions(query);
    }
  }

  Future<void> _fallbackGeocodingSuggestions(String query) async {
    try {
      List<Location> locations = await locationFromAddress(query);
      List<Map<String, dynamic>> suggestions = [];

      for (var location in locations.take(5)) {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          location.latitude,
          location.longitude,
        );

        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final description = [
            place.locality,
            place.administrativeArea,
            place.country,
          ].where((e) => e != null && e.isNotEmpty).join(', ');

          suggestions.add({
            'latitude': location.latitude,
            'longitude': location.longitude,
            'description': description,
          });
        }
      }

      setState(() {
        _searchSuggestions = suggestions;
        _isLoadingSuggestions = false;
      });
    } catch (e) {
      print('Error in fallback geocoding: $e');
      setState(() {
        _searchSuggestions = [];
        _isLoadingSuggestions = false;
      });
    }
  }

  Future<void> _selectLocation(Map<String, dynamic> suggestion) async {
    setState(() {
      _isSearching = false;
      _searchSuggestions = [];
      _isUsingSearchedLocation = true;
      _isLoading = true;
    });

    try {
      if (suggestion.containsKey('placeId')) {
        final apiKey =
            widget.apiKey ??
            const String.fromEnvironment('GOOGLE_AIR_QUALITY_API_KEY');

        final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/details/json'
          '?place_id=${suggestion['placeId']}'
          '&fields=geometry,formatted_address'
          '&key=$apiKey',
        );

        final response = await http.get(url);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);

          if (data['status'] == 'OK' && data['result'] != null) {
            final geometry = data['result']['geometry']['location'];
            _latitude = geometry['lat'];
            _longitude = geometry['lng'];
            _location = suggestion['description'];

            _searchController.text = _location;
            await _fetchAirQuality(forceRefresh: true);
          }
        }
      } else {
        _latitude = suggestion['latitude'];
        _longitude = suggestion['longitude'];
        _location = suggestion['description'];

        _searchController.text = _location;
        await _fetchAirQuality(forceRefresh: true);
      }
    } catch (e) {
      print('Error selecting location: $e');
      setState(() {
        _error = 'Error loading location data';
        _isLoading = false;
      });
    }
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchSuggestions = [];
      _isSearching = false;
      _isUsingSearchedLocation = false;
    });

    _initialize();
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

  Future<void> _fetchAirQuality({bool forceRefresh = false}) async {
    if (_latitude == null || _longitude == null) {
      setState(() {
        _error = 'Location not available';
        _isLoading = false;
      });
      return;
    }

    if (!forceRefresh &&
        !_isUsingSearchedLocation &&
        _lastFetchTime != null &&
        _airQualityData != null) {
      final timeSinceLastFetch = DateTime.now().difference(_lastFetchTime!);
      if (timeSinceLastFetch < _cacheDuration) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _isUsingCachedData = _cachedAirQualityData != null;
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
          _isUsingCachedData = false;
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
        'universalAqi': false,
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

        await _saveCachedData(data);

        setState(() {
          _airQualityData = AirQualityData.fromGoogleJson(
            data,
            _currentPopulation,
            _getPopulationRecommendationKey(_currentPopulation),
            _applicablePopulations,
          );
          _isLoading = false;
          _isUsingCachedData = false;
        });

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
          _isUsingCachedData = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error fetching air quality data: ${e.toString()}';
        _isLoading = false;
        _isUsingCachedData = false;
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

    if (_applicablePopulations.contains(Population.pregnantWomen) ||
        _applicablePopulations.contains(Population.lungDiseasePopulation) ||
        _applicablePopulations.contains(Population.heartDiseasePopulation) ||
        _applicablePopulations.contains(Population.children)) {
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
        shouldSendNotification = true;
      } else {
        final lastAlert = recentAlerts.docs.first;
        final lastAlertTime = (lastAlert['timestamp'] as Timestamp).toDate();

        if (lastAlertTime.isBefore(sixHoursAgo)) {
          shouldSendNotification = true;
        }
      }

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

        await PushNotificationService().showEnvironmentalAlert(
          title: '⚠️ $alertLevel Air Quality Alert',
          body:
              'AQI: $aqi in $_location. ${_airQualityData!.healthRecommendation ?? "Take precautions."}',
          alertLevel: alertLevel,
          aqi: aqi,
        );
      }
    }
  }

  void _navigateToDetailScreen() {
    final dataToPass = _airQualityData ?? _cachedAirQualityData;
    if (dataToPass != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => AirQualityDetailScreen(
                airQualityData: dataToPass,
                location: _location,
                applicablePopulations: _applicablePopulations,
                showBackButton: true,
              ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // If we have real data, show the main content
    if (_airQualityData != null && !_isLoading) {
      return GestureDetector(
        onTap: _navigateToDetailScreen,
        child: _buildAirQualityContent(),
      );
    }

    // If we're loading but have cached data, show cached data in the main content style
    if (_isLoading && _cachedAirQualityData != null) {
      return GestureDetector(
        onTap: _navigateToDetailScreen,
        child: _buildAirQualityContentWithCachedData(),
      );
    }

    // Otherwise show loading/error states
    return Container(
      margin:
          widget.margin ??
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: widget.padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child:
          _isLoading
              ? _buildLoadingWidget()
              : _error != null
              ? _buildErrorWidget()
              : const Center(
                child: Text(
                  'No data available',
                  style: TextStyle(color: Color(0xFF666666)),
                ),
              ),
    );
  }

  Widget _buildLoadingWidget() {
    // If we have cached data, show a simplified version with cached data
    if (_cachedAirQualityData != null) {
      return _buildCachedDataPlaceholder();
    }

    // Otherwise show the original loading widget
    return Row(
      children: [
        SizedBox(
          width: widget.gaugeSize,
          height: widget.gaugeSize,
          child: CustomPaint(
            painter: LoadingGaugePainter(),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '--',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'AQI',
                    style: TextStyle(fontSize: 12, color: Color(0xFF999999)),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.showLocation) ...[
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 16,
                      color: Color(0xFF666666),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _location,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF666666),
                        ),
                        overflow:
                            widget.overflow
                                ? TextOverflow.ellipsis
                                : TextOverflow.visible,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              const Text(
                'Air Quality Index',
                style: TextStyle(fontSize: 12, color: Color(0xFF999999)),
              ),
              const SizedBox(height: 8),
              const Text(
                'Air quality Condition',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Dominant Pollutant: - - -',
                style: TextStyle(fontSize: 12, color: Color(0xFF999999)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCachedDataPlaceholder() {
    final cachedData = _cachedAirQualityData!;
    final aqi = cachedData.aqi;
    final quality = cachedData.qualityLevel;

    return Row(
      children: [
        SizedBox(
          width: widget.gaugeSize,
          height: widget.gaugeSize,
          child: CustomPaint(
            painter: AQIGaugePainter(
              aqi: aqi.toDouble(),
              color: cachedData.color,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$aqi',
                    style: TextStyle(
                      fontSize: widget.gaugeSize * 0.24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'AQI',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF999999),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.showLocation) ...[
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 16,
                      color: Color(0xFF666666),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _location,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF666666),
                        ),
                        overflow:
                            widget.overflow
                                ? TextOverflow.ellipsis
                                : TextOverflow.visible,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              const Text(
                'Air Quality Index',
                style: TextStyle(fontSize: 12, color: Color(0xFF999999)),
              ),
              const SizedBox(height: 8),
              Text(
                quality,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Dominant pollutant: ${cachedData.dominantPollutant}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF999999)),
              ),
              const SizedBox(height: 8),
              // Show loading indicator
              Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: const Color(0xFF2B9EB3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Updating...',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAirQualityContentWithCachedData() {
    final cachedData = _cachedAirQualityData!;
    final aqi = cachedData.aqi;
    final quality = cachedData.qualityLevel;
    final dominantPollutant = cachedData.dominantPollutant;

    return Container(
      margin:
          widget.margin ??
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: widget.padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Show "Using Cached Data" indicator
          // Container(
          //   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          //   decoration: BoxDecoration(
          //     color: Colors.orange[50],
          //     borderRadius: BorderRadius.circular(8),
          //     border: Border.all(color: Colors.orange[200]!),
          //   ),
          //   child: Row(
          //     mainAxisSize: MainAxisSize.min,
          //     children: [
          //       Icon(Icons.cached, size: 16, color: Colors.orange[700]),
          //       const SizedBox(width: 8),
          //       Text(
          //         'Using cached data • Updating...',
          //         style: TextStyle(
          //           fontSize: 12,
          //           color: Colors.orange[700],
          //           fontWeight: FontWeight.w500,
          //         ),
          //       ),
          //     ],
          //   ),
          // ),
          // const SizedBox(height: 12),

          // Search bar with location - only show if enabled
          if (widget.showSearch) ...[
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isSearching = true;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          if (widget.showLocation) ...[
                            const Icon(
                              Icons.location_on,
                              size: 18,
                              color: Color(0xFF666666),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child:
                                _isSearching
                                    ? TextField(
                                      controller: _searchController,
                                      autofocus: true,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        color: Color(0xFF333333),
                                      ),
                                      decoration: const InputDecoration(
                                        hintText: 'Search location...',
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      onChanged: _onSearchChanged,
                                    )
                                    : Text(
                                      _location,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        color: Color(0xFF666666),
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow:
                                          widget.overflow
                                              ? TextOverflow.ellipsis
                                              : TextOverflow.visible,
                                      maxLines: 1,
                                    ),
                          ),
                          if (_isUsingSearchedLocation)
                            GestureDetector(
                              onTap: _clearSearch,
                              child: const Icon(
                                Icons.close,
                                size: 18,
                                color: Color(0xFF666666),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isSearching = !_isSearching;
                      if (!_isSearching) {
                        _searchController.clear();
                        _searchSuggestions = [];
                      }
                    });
                  },
                  child: Icon(
                    _isSearching ? Icons.close : Icons.search,
                    size: 24,
                    color: const Color(0xFF333333),
                  ),
                ),
              ],
            ),

            // Search suggestions
            if (_searchSuggestions.isNotEmpty || _isLoadingSuggestions) ...[
              const SizedBox(height: 8),
              Container(
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child:
                    _isLoadingSuggestions
                        ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                        : Scrollbar(
                          child: ListView.separated(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: _searchSuggestions.length,
                            separatorBuilder:
                                (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final suggestion = _searchSuggestions[index];
                              return ListTile(
                                dense: true,
                                leading: const Icon(
                                  Icons.location_on,
                                  size: 20,
                                ),
                                title: Text(
                                  suggestion['description'] ??
                                      'Unknown location',
                                  style: const TextStyle(fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                onTap: () => _selectLocation(suggestion),
                              );
                            },
                          ),
                        ),
              ),
            ],
            const SizedBox(height: 16),
          ],

          // AQI gauge and info row (using cached data)
          Row(
            children: [
              // Circular gauge with cached data
              SizedBox(
                width: widget.gaugeSize,
                height: widget.gaugeSize,
                child: CustomPaint(
                  painter: AQIGaugePainter(
                    aqi: aqi.toDouble(),
                    color: cachedData.color,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$aqi',
                          style: TextStyle(
                            fontSize: widget.gaugeSize * 0.24,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF333333),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'AQI',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF999999),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Air quality info with cached data
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Air Quality Index',
                      style: TextStyle(fontSize: 13, color: Color(0xFF999999)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      quality,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Dominant pollutant: $dominantPollutant',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF999999),
                      ),
                      overflow:
                          widget.overflow
                              ? TextOverflow.ellipsis
                              : TextOverflow.visible,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Divider
          Container(height: 1, color: const Color(0xFFE0E0E0)),

          const SizedBox(height: 10),

          // Last updated info with loading indicator
          if (_lastFetchTime != null && widget.showRefresh)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 14,
                    color: Color(0xFF999999),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Updated ${_getTimeAgo(_lastFetchTime!)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF999999),
                    ),
                  ),
                  const Spacer(),
                  // Show loading indicator instead of refresh button
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: const Color(0xFF2B9EB3),
                    ),
                  ),
                ],
              ),
            ),

          // Suggestion section with cached data
          const Text(
  'Suggestion for you',
  style: TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: Color(0xFF333333),
  ),
),
const SizedBox(height: 12),
if (_airQualityData!.healthRecommendation != null)
  Text(
    _airQualityData!.healthRecommendation!,
    style: const TextStyle(
      fontSize: 13,
      color: Color(0xFF666666),
      height: 1.5,
    ),
    maxLines: widget.healthRecoOverflow ? 3 : null,
    overflow: widget.healthRecoOverflow ? TextOverflow.ellipsis : null,
  ),
        ],
      ),
    );
  }

  Widget _buildAirQualityContent() {
    final aqi = _airQualityData!.aqi;
    final quality = _airQualityData!.qualityLevel;
    final dominantPollutant = _airQualityData!.dominantPollutant;

    return Container(
      margin:
          widget.margin ??
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: widget.padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar with location
          if (widget.showSearch) ...[
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isSearching = true;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          if (widget.showLocation) ...[
                            const Icon(
                              Icons.location_on,
                              size: 18,
                              color: Color(0xFF666666),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child:
                                _isSearching
                                    ? TextField(
                                      controller: _searchController,
                                      autofocus: true,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        color: Color(0xFF333333),
                                      ),
                                      decoration: const InputDecoration(
                                        hintText: 'Search location...',
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      onChanged: _onSearchChanged,
                                    )
                                    : Text(
                                      _location,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        color: Color(0xFF666666),
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow:
                                          widget.overflow
                                              ? TextOverflow.ellipsis
                                              : TextOverflow.visible,
                                      maxLines: 1,
                                    ),
                          ),
                          if (_isUsingSearchedLocation)
                            GestureDetector(
                              onTap: _clearSearch,
                              child: const Icon(
                                Icons.close,
                                size: 18,
                                color: Color(0xFF666666),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isSearching = !_isSearching;
                      if (!_isSearching) {
                        _searchController.clear();
                        _searchSuggestions = [];
                      }
                    });
                  },
                  child: Icon(
                    _isSearching ? Icons.close : Icons.search,
                    size: 24,
                    color: const Color(0xFF333333),
                  ),
                ),
              ],
            ),

            // Search suggestions
            if (_searchSuggestions.isNotEmpty || _isLoadingSuggestions) ...[
              const SizedBox(height: 8),
              Container(
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child:
                    _isLoadingSuggestions
                        ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                        : Scrollbar(
                          child: ListView.separated(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: _searchSuggestions.length,
                            separatorBuilder:
                                (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final suggestion = _searchSuggestions[index];
                              return ListTile(
                                dense: true,
                                leading: const Icon(
                                  Icons.location_on,
                                  size: 20,
                                ),
                                title: Text(
                                  suggestion['description'] ??
                                      'Unknown location',
                                  style: const TextStyle(fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                onTap: () => _selectLocation(suggestion),
                              );
                            },
                          ),
                        ),
              ),
            ],
            const SizedBox(height: 16),
          ],

          // AQI gauge and info row
          Row(
            children: [
              // Circular gauge
              SizedBox(
                width: widget.gaugeSize,
                height: widget.gaugeSize,
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
                          style: TextStyle(
                            fontSize: widget.gaugeSize * 0.24,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF333333),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'AQI',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF999999),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Air quality info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Air Quality Index',
                      style: TextStyle(fontSize: 13, color: Color(0xFF999999)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      quality,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Dominant pollutant: $dominantPollutant',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF999999),
                      ),
                      overflow:
                          widget.overflow
                              ? TextOverflow.ellipsis
                              : TextOverflow.visible,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Divider
          Container(height: 1, color: const Color(0xFFE0E0E0)),

          const SizedBox(height: 10),

          // Last updated info
          if (_lastFetchTime != null && widget.showRefresh)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 14,
                    color: Color(0xFF999999),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Updated ${_getTimeAgo(_lastFetchTime!)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF999999),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _fetchAirQuality(forceRefresh: true),
                    child: const Icon(
                      Icons.refresh,
                      size: 18,
                      color: Color(0xFF2B9EB3),
                    ),
                  ),
                ],
              ),
            ),

          // Suggestion section
         const Text(
  'Suggestion for you',
  style: TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: Color(0xFF333333),
  ),
),
const SizedBox(height: 12),
if (_airQualityData!.healthRecommendation != null)
  Text(
    _airQualityData!.healthRecommendation!,
    style: const TextStyle(
      fontSize: 13,
      color: Color(0xFF666666),
      height: 1.5,
    ),
    maxLines: widget.healthRecoOverflow ? 2 : null,
    overflow: widget.healthRecoOverflow ? TextOverflow.ellipsis : null,
  ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, size: 48, color: Colors.red),
        const SizedBox(height: 12),
        Text(
          _error!,
          style: const TextStyle(color: Color(0xFF666666)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _initialize,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2B9EB3),
            foregroundColor: Colors.white,
          ),
          child: const Text('Retry'),
        ),
      ],
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

class LoadingGaugePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    // Background arc (light grey)
    final backgroundPaint =
        Paint()
          ..color = const Color(0xFFE0E0E0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12
          ..strokeCap = StrokeCap.round;

    final startAngle = math.pi * 0.65;
    final totalSweepAngle = math.pi * 1.7;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      totalSweepAngle,
      false,
      backgroundPaint,
    );

    // Gradient arc (full spectrum)
    final rect = Rect.fromCircle(center: center, radius: radius);
    final int segments = 100;
    final segmentAngle = totalSweepAngle / segments;

    for (int i = 0; i <= segments; i++) {
      final progress = i / segments;
      final aqiValue = progress * 500; // Full AQI range
      final segmentColor = _getColorForAqi(aqiValue);

      final segmentPaint =
          Paint()
            ..color = segmentColor.withOpacity(0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 12
            ..strokeCap =
                (i == 0 || i == segments) ? StrokeCap.round : StrokeCap.butt;

      canvas.drawArc(
        rect,
        startAngle + (i * segmentAngle),
        segmentAngle,
        false,
        segmentPaint,
      );
    }
  }

  Color _getColorForAqi(double aqiValue) {
    if (aqiValue <= 100) {
      return Color.lerp(
        const Color(0xFF00E400),
        const Color(0xFFA8D96E),
        aqiValue / 100,
      )!;
    } else if (aqiValue <= 150) {
      return Color.lerp(
        const Color(0xFFA8D96E),
        const Color(0xFFFFFF00),
        (aqiValue - 100) / 50,
      )!;
    } else if (aqiValue <= 200) {
      return Color.lerp(
        const Color(0xFFFFFF00),
        const Color(0xFFFF7E00),
        (aqiValue - 150) / 50,
      )!;
    } else if (aqiValue <= 300) {
      return Color.lerp(
        const Color(0xFFFF7E00),
        const Color(0xFFFF0000),
        (aqiValue - 200) / 100,
      )!;
    } else if (aqiValue <= 400) {
      return Color.lerp(
        const Color(0xFFFF0000),
        const Color(0xFF990000),
        (aqiValue - 300) / 100,
      )!;
    } else {
      return const Color(0xFF990000);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AQIGaugePainter extends CustomPainter {
  final double aqi;
  final Color color;

  AQIGaugePainter({required this.aqi, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    // Background arc (light grey)
    final backgroundPaint =
        Paint()
          ..color = const Color(0xFFE0E0E0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12
          ..strokeCap = StrokeCap.round;

    final startAngle = math.pi * 0.65;
    final totalSweepAngle = math.pi * 1.7;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      totalSweepAngle,
      false,
      backgroundPaint,
    );

    final normalizedAqi = (aqi / 500).clamp(0.0, 1.0);
    final sweepAngle = normalizedAqi * totalSweepAngle;

    final rect = Rect.fromCircle(center: center, radius: radius);
    final int segments = 100;
    final segmentAngle = sweepAngle / segments;

    for (int i = 0; i <= segments; i++) {
      final progress = i / segments;
      final aqiAtProgress = progress * aqi;
      final segmentColor = _getColorForAqi(aqiAtProgress);

      final segmentPaint =
          Paint()
            ..color = segmentColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 12
            ..strokeCap =
                (i == 0 || i == segments) ? StrokeCap.round : StrokeCap.butt;

      canvas.drawArc(
        rect,
        startAngle + (i * segmentAngle),
        segmentAngle,
        false,
        segmentPaint,
      );
    }
  }

  Color _getColorForAqi(double aqiValue) {
    if (aqiValue <= 100) {
      return Color.lerp(
        const Color(0xFF00E400),
        const Color(0xFFA8D96E),
        aqiValue / 100,
      )!;
    } else if (aqiValue <= 150) {
      return Color.lerp(
        const Color(0xFFA8D96E),
        const Color(0xFFFFFF00),
        (aqiValue - 100) / 50,
      )!;
    } else if (aqiValue <= 200) {
      return Color.lerp(
        const Color(0xFFFFFF00),
        const Color(0xFFFF7E00),
        (aqiValue - 150) / 50,
      )!;
    } else if (aqiValue <= 300) {
      return Color.lerp(
        const Color(0xFFFF7E00),
        const Color(0xFFFF0000),
        (aqiValue - 200) / 100,
      )!;
    } else if (aqiValue <= 400) {
      return Color.lerp(
        const Color(0xFFFF0000),
        const Color(0xFF990000),
        (aqiValue - 300) / 100,
      )!;
    } else {
      return const Color(0xFF990000);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
