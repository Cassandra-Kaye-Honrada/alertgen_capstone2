import 'dart:convert';

import 'package:allergen/screens/health_environment_analytics/AirQualityDetailScreen.dart';
import 'package:allergen/screens/health_environment_analytics/models/air_quality_models.dart';
import 'package:allergen/screens/health_environment_analytics/widgets/AirQualityWidget.dart';
import 'package:allergen/styleguide.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class AirQualityLoader extends StatefulWidget {
  @override
  State<AirQualityLoader> createState() => _AirQualityLoaderState();
}

class _AirQualityLoaderState extends State<AirQualityLoader> {
  bool isLoading = true;
  String? error;
  AirQualityData? airQualityData;
  String location = "Loading...";
  List<Population> applicablePopulations = [Population.generalPopulation];
  double? latitude;
  double? longitude;

  @override
  void initState() {
    super.initState();
    loadAirQualityData();
  }

  Future<void> loadAirQualityData() async {
    try {
      await getLocation();
      await determinePopulation();
      await fetchAirQuality();

      if (mounted && airQualityData != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AirQualityDetailScreen(
              airQualityData: airQualityData!,
              location: location,
              applicablePopulations: applicablePopulations,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          isLoading = false;
        });
      }
    }
  }

  Future<void> getLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services disabled');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission permanently denied');
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(Duration(seconds: 10));

      latitude = position.latitude;
      longitude = position.longitude;

      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude!,
        longitude!,
      );
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        location = '${place.locality ?? place.subAdministrativeArea ?? "Unknown"}';
      }
    } catch (e) {
      throw Exception('Failed to get location: $e');
    }
  }

  Future<void> determinePopulation() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        applicablePopulations = [Population.generalPopulation];
        return;
      }

      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        applicablePopulations = determinePopulations(data);
      }
    } catch (e) {
      applicablePopulations = [Population.generalPopulation];
    }
  }

  List<Population> determinePopulations(Map<String, dynamic> data) {
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
        if (age >= 65) populations.add(Population.elderly);
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

  Future<void> fetchAirQuality() async {
    try {
      final apiKey = 'AIzaSyCWva81wgqeq5qIShLvoO9hs20ejk73gCE';
      final url = Uri.parse(
        'https://airquality.googleapis.com/v1/currentConditions:lookup?key=$apiKey',
      );

      final requestBody = {
        'location': {'latitude': latitude, 'longitude': longitude},
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
          .timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        Population currentPopulation = getMostCriticalPopulation(applicablePopulations);
        String populationKey = getPopulationRecommendationKey(currentPopulation);

        airQualityData = AirQualityData.fromGoogleJson(
          data,
          currentPopulation,
          populationKey,
          applicablePopulations,
        );
      } else {
        throw Exception('API error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch air quality: $e');
    }
  }

  Population getMostCriticalPopulation(List<Population> populations) {
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
      if (populations.contains(pop)) return pop;
    }
    return Population.generalPopulation;
  }

  String getPopulationRecommendationKey(Population population) {
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

  Widget buildLoadingOverlay() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE8F4F8), Color(0xFFFFFFFF)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0B8FAC).withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const CircularProgressIndicator(
                color: Color(0xFF0B8FAC),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Loading air quality data...',
              style: TextStyle(
                color: Color(0xFF0B8FAC),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: error != null
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.white70,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Failed to load air quality data',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error!,
                      style: const TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          error = null;
                        });
                        loadAirQualityData();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : buildLoadingOverlay(),
    );
  }
}
