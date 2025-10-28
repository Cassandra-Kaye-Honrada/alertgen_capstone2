import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AirQualityDetailScreen extends StatelessWidget {
  final String location;
  final double temperature;
  final int humidity;
  final int aqi;
  final double visibility;
  final int windSpeed;
  final double pm25;
  final double pm10;
  final double dust;
  final VoidCallback onRefresh;

  const AirQualityDetailScreen({
    Key? key,
    required this.location,
    required this.temperature,
    required this.humidity,
    required this.aqi,
    required this.visibility,
    required this.windSpeed,
    required this.pm25,
    required this.pm10,
    required this.dust,
    required this.onRefresh,
  }) : super(key: key);

  AirQualityAlert _getAirQualityAlert() {
    if (dust > 50) {
      return AirQualityAlert(
        icon: Icons.warning_amber_rounded,
        title: 'High Dust Alert',
        message: 'Dust levels are high. Wear a mask outdoors.',
        color: Colors.orange,
        severity: 'warning',
      );
    }

    if (pm25 > 35) {
      return AirQualityAlert(
        icon: Icons.health_and_safety,
        title: 'Poor Air Quality',
        message: 'Fine particles detected. Avoid outdoor activities.',
        color: Colors.red,
        severity: 'danger',
      );
    }

    if (pm10 > 50) {
      return AirQualityAlert(
        icon: Icons.air,
        title: 'Moderate Air Quality',
        message: 'Sensitive individuals should limit outdoor activities.',
        color: Colors.orange,
        severity: 'warning',
      );
    }

    if (aqi > 100) {
      return AirQualityAlert(
        icon: Icons.info_outline,
        title: 'Air Quality Alert',
        message: 'Air quality is not ideal. Limit outdoor exposure.',
        color: Colors.orange,
        severity: 'warning',
      );
    }

    return AirQualityAlert(
      icon: Icons.check_circle_outline,
      title: 'Air Quality is Good',
      message: 'Great day to be outdoors! Air quality is healthy.',
      color: Colors.green,
      severity: 'good',
    );
  }

  AQIStatus _getAQIStatus(int aqi) {
    if (aqi <= 50) {
      return AQIStatus(
        label: 'Good',
        color: Color(0xFF00E676),
        backgroundColor: Color(0xFF00E676).withOpacity(0.1),
      );
    } else if (aqi <= 100) {
      return AQIStatus(
        label: 'Moderate',
        color: Color(0xFFFFC400),
        backgroundColor: Color(0xFFFFC400).withOpacity(0.1),
      );
    } else if (aqi <= 150) {
      return AQIStatus(
        label: 'Unhealthy',
        color: Color(0xFFFF9100),
        backgroundColor: Color(0xFFFF9100).withOpacity(0.1),
      );
    } else if (aqi <= 200) {
      return AQIStatus(
        label: 'Poor',
        color: Color(0xFFFF5252),
        backgroundColor: Color(0xFFFF5252).withOpacity(0.1),
      );
    } else if (aqi <= 300) {
      return AQIStatus(
        label: 'Very Poor',
        color: Color(0xFFB71C1C),
        backgroundColor: Color(0xFFB71C1C).withOpacity(0.1),
      );
    } else {
      return AQIStatus(
        label: 'Hazardous',
        color: Color(0xFF7B1FA2),
        backgroundColor: Color(0xFF7B1FA2).withOpacity(0.1),
      );
    }
  }

  String _formatTime() {
    return DateFormat('HH:mm').format(DateTime.now());
  }

  // Enhanced method to get personalized recommendations based on detailed user profile
  Future<List<PersonalizedRecommendation>>
  _getPersonalizedRecommendations() async {
    final List<PersonalizedRecommendation> recommendations = [];

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return recommendations;

      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;

        // Health conditions
        final bool foodAllergies = data['foodAllergies'] ?? false;
        final bool drugAllergies = data['drugAllergies'] ?? false;
        final bool asthmaRespiratory = data['asthmaRespiratory'] ?? false;
        final bool skinSensitivity = data['skinSensitivity'] ?? false;
        final bool otherHealth = data['otherHealth'] ?? false;
        final String otherHealthDetails = data['otherHealthDetails'] ?? '';

        // Medical background
        final bool lungDisease = data['lungDisease'] ?? false;
        final bool heartDisease = data['heartDisease'] ?? false;
        final bool sportsActivities = data['sportsActivities'] ?? false;
        final bool isPregnant = data['isPregnant'] ?? false;

        // Care responsibilities
        final bool caresForChildren = data['caresForChildren'] ?? false;
        final bool caresForToddlers = data['caresForToddlers'] ?? false;
        final bool caresForBabies = data['caresForBabies'] ?? false;

        final String? userGroup = data['userGroup'];

        // High AQI conditions (Poor air quality)
        if (aqi > 100) {
          // Respiratory conditions - most sensitive to air quality
          if (asthmaRespiratory) {
            recommendations.add(
              PersonalizedRecommendation(
                icon: Icons.air,
                title: 'Asthma Alert',
                description:
                    'High AQI may trigger asthma symptoms. Carry your rescue inhaler and limit outdoor exposure to under 30 minutes.',
                color: Colors.red,
              ),
            );
          }

          if (lungDisease) {
            recommendations.add(
              PersonalizedRecommendation(
                icon: Icons.health_and_safety,
                title: 'Lung Condition Precautions',
                description:
                    'Poor air quality can exacerbate lung conditions. Stay indoors with windows closed and use air purifiers.',
                color: Colors.red,
              ),
            );
          }

          // Heart conditions
          if (heartDisease) {
            recommendations.add(
              PersonalizedRecommendation(
                icon: Icons.favorite,
                title: 'Heart Health Warning',
                description:
                    'Air pollution strains cardiovascular system. Avoid strenuous activities and monitor for chest discomfort.',
                color: Colors.red,
              ),
            );
          }

          // Allergies and sensitivities
          if (foodAllergies) {
            recommendations.add(
              PersonalizedRecommendation(
                icon: Icons.restaurant,
                title: 'Allergy Cross-Reactivity',
                description:
                    'High pollen and pollution can worsen food allergy symptoms. Be extra cautious with known allergens.',
                color: Colors.orange,
              ),
            );
          }

          if (skinSensitivity) {
            recommendations.add(
              PersonalizedRecommendation(
                icon: Icons.masks,
                title: 'Skin Protection Needed',
                description:
                    'Pollutants can irritate sensitive skin. Use barrier creams and shower after being outdoors.',
                color: Colors.orange,
              ),
            );
          }

          if (drugAllergies) {
            recommendations.add(
              PersonalizedRecommendation(
                icon: Icons.medical_services,
                title: 'Medication Alert',
                description:
                    'Keep allergy medications accessible. Consider wearing a medical alert bracelet if you have severe drug allergies.',
                color: Colors.orange,
              ),
            );
          }

          // Lifestyle and activities
          if (sportsActivities) {
            recommendations.add(
              PersonalizedRecommendation(
                icon: Icons.sports,
                title: 'Indoor Exercise Recommended',
                description:
                    'Move your workout indoors. If exercising outside, reduce intensity by 50% and take frequent breaks.',
                color: Colors.orange,
              ),
            );
          }

          // Pregnancy
          if (isPregnant) {
            recommendations.add(
              PersonalizedRecommendation(
                icon: Icons.pregnant_woman,
                title: 'Pregnancy Precautions',
                description:
                    'Limit outdoor time to essential activities only. Use N95 masks and maintain indoor air purification.',
                color: Colors.red,
              ),
            );
          }

          // User group specific
          if (userGroup == 'elderly') {
            recommendations.add(
              PersonalizedRecommendation(
                icon: Icons.accessible_forward,
                title: 'Elderly Health Protection',
                description:
                    'Stay indoors during peak pollution hours (10 AM - 4 PM). Keep medications and emergency contacts handy.',
                color: Colors.red,
              ),
            );
          }

          if (userGroup == 'child') {
            recommendations.add(
              PersonalizedRecommendation(
                icon: Icons.child_care,
                title: 'Child Safety Measures',
                description:
                    'Children are more vulnerable to air pollution. Keep indoor play areas well-ventilated with purifiers.',
                color: Colors.red,
              ),
            );
          }

          // Care responsibilities
          if (caresForChildren) {
            recommendations.add(
              PersonalizedRecommendation(
                icon: Icons.school,
                title: 'School-Age Children',
                description:
                    'Limit outdoor playtime. Ensure children wear masks to school and change clothes after coming home.',
                color: Colors.orange,
              ),
            );
          }

          if (caresForToddlers) {
            recommendations.add(
              PersonalizedRecommendation(
                icon: Icons.child_friendly,
                title: 'Toddler Care',
                description:
                    'Toddlers are highly sensitive. Use stroller covers outdoors and maintain clean indoor air.',
                color: Colors.orange,
              ),
            );
          }

          if (caresForBabies) {
            recommendations.add(
              PersonalizedRecommendation(
                icon: Icons.baby_changing_station,
                title: 'Infant Protection',
                description:
                    'Babies should stay indoors completely. Use HEPA air purifiers in nursery and avoid taking baby outside.',
                color: Colors.red,
              ),
            );
          }

          // Other health conditions
          if (otherHealth && otherHealthDetails.isNotEmpty) {
            final String details = otherHealthDetails.toLowerCase();
            if (details.contains('migraine') || details.contains('headache')) {
              recommendations.add(
                PersonalizedRecommendation(
                  icon: Icons.health_and_safety,
                  title: 'Migraine Prevention',
                  description:
                      'Air pollution can trigger migraines. Stay in well-ventilated areas and stay hydrated.',
                  color: Colors.orange,
                ),
              );
            }

            if (details.contains('diabetes') ||
                details.contains('blood sugar')) {
              recommendations.add(
                PersonalizedRecommendation(
                  icon: Icons.monitor_heart,
                  title: 'Diabetes Management',
                  description:
                      'Monitor blood sugar closely as pollution can affect glucose levels. Stay indoors during high pollution.',
                  color: Colors.orange,
                ),
              );
            }

            if (details.contains('blood pressure') ||
                details.contains('hypertension')) {
              recommendations.add(
                PersonalizedRecommendation(
                  icon: Icons.monitor_heart,
                  title: 'Blood Pressure Alert',
                  description:
                      'Check blood pressure regularly. Air pollution can cause temporary increases in blood pressure.',
                  color: Colors.orange,
                ),
              );
            }
          }
        }

        // Dust-specific recommendations (regardless of AQI)
        if (dust > 50) {
          if (asthmaRespiratory || lungDisease) {
            recommendations.add(
              PersonalizedRecommendation(
                icon: Icons.grain,
                title: 'High Dust Alert for Respiratory Conditions',
                description:
                    'Dust levels are very high. Use your preventer inhaler as prescribed and avoid dusty areas completely.',
                color: Colors.red,
              ),
            );
          }

          if (skinSensitivity) {
            recommendations.add(
              PersonalizedRecommendation(
                icon: Icons.masks,
                title: 'Dust Protection for Skin',
                description:
                    'Wear long sleeves and pants. Shower immediately after coming indoors to remove dust particles.',
                color: Colors.orange,
              ),
            );
          }

          if (caresForChildren || caresForToddlers || caresForBabies) {
            recommendations.add(
              PersonalizedRecommendation(
                icon: Icons.family_restroom,
                title: 'Child Dust Protection',
                description:
                    'Children should wear masks outdoors. Wash hands and face frequently to remove dust.',
                color: Colors.orange,
              ),
            );
          }
        }

        // PM2.5 specific recommendations
        if (pm25 > 35) {
          if (isPregnant) {
            recommendations.add(
              PersonalizedRecommendation(
                icon: Icons.pregnant_woman,
                title: 'PM2.5 Pregnancy Warning',
                description:
                    'Fine particles can affect fetal development. Use high-quality air purifiers and limit all outdoor exposure.',
                color: Colors.red,
              ),
            );
          }

          if (heartDisease) {
            recommendations.add(
              PersonalizedRecommendation(
                icon: Icons.favorite,
                title: 'PM2.5 Heart Risk',
                description:
                    'Fine particles increase heart attack risk. Avoid all strenuous activity and stay in filtered environments.',
                color: Colors.red,
              ),
            );
          }
        }

        // Good air quality recommendations (AQI <= 50)
        if (aqi <= 50) {
          if (asthmaRespiratory || lungDisease) {
            recommendations.add(
              PersonalizedRecommendation(
                icon: Icons.air,
                title: 'Ideal Conditions for Respiratory Health',
                description:
                    'Perfect day for gentle outdoor activities. Great opportunity for respiratory therapy exercises outdoors.',
                color: Colors.green,
              ),
            );
          }

          if (sportsActivities) {
            recommendations.add(
              PersonalizedRecommendation(
                icon: Icons.directions_run,
                title: 'Optimal Exercise Conditions',
                description:
                    'Excellent air quality for outdoor training. Ideal for running, cycling, or sports activities.',
                color: Colors.green,
              ),
            );
          }

          if (isPregnant) {
            recommendations.add(
              PersonalizedRecommendation(
                icon: Icons.park,
                title: 'Safe Outdoor Time',
                description:
                    'Perfect conditions for gentle walks. Great for both maternal and fetal health.',
                color: Colors.green,
              ),
            );
          }

          if (userGroup == 'elderly') {
            recommendations.add(
              PersonalizedRecommendation(
                icon: Icons.accessible,
                title: 'Excellent for Outdoor Mobility',
                description:
                    'Ideal conditions for walking, gardening, or social outdoor activities.',
                color: Colors.green,
              ),
            );
          }

          if (caresForChildren || caresForToddlers || caresForBabies) {
            recommendations.add(
              PersonalizedRecommendation(
                icon: Icons.park,
                title: 'Perfect Play Day',
                description:
                    'Wonderful conditions for children to play outdoors. Great for physical development and vitamin D.',
                color: Colors.green,
              ),
            );
          }
        }

        // Moderate air quality (AQI 51-100)
        if (aqi > 50 && aqi <= 100) {
          if (asthmaRespiratory) {
            recommendations.add(
              PersonalizedRecommendation(
                icon: Icons.air,
                title: 'Moderate Conditions - Respiratory Caution',
                description:
                    'Air quality is acceptable but monitor for symptoms. Limit intense outdoor activities to 1-2 hours.',
                color: Colors.blue,
              ),
            );
          }

          if (heartDisease) {
            recommendations.add(
              PersonalizedRecommendation(
                icon: Icons.favorite,
                title: 'Moderate Activity Level',
                description:
                    'Suitable for light activities. Avoid strenuous exercise and take frequent breaks.',
                color: Colors.blue,
              ),
            );
          }
        }

        // Temperature and humidity based recommendations
        if (temperature > 30 && humidity > 70) {
          if (asthmaRespiratory) {
            recommendations.add(
              PersonalizedRecommendation(
                icon: Icons.thermostat,
                title: 'Hot & Humid Weather Alert',
                description:
                    'High heat and humidity may trigger asthma. Stay in air-conditioned spaces and keep inhaler accessible.',
                color: Colors.orange,
              ),
            );
          }

          if (heartDisease) {
            recommendations.add(
              PersonalizedRecommendation(
                icon: Icons.thermostat,
                title: 'Heat Stress Warning',
                description:
                    'Hot, humid conditions strain the heart. Stay hydrated and avoid being outdoors during peak heat.',
                color: Colors.orange,
              ),
            );
          }

          if (isPregnant) {
            recommendations.add(
              PersonalizedRecommendation(
                icon: Icons.thermostat,
                title: 'Pregnancy Heat Precautions',
                description:
                    'Stay cool and hydrated. Avoid prolonged outdoor exposure in this heat and humidity.',
                color: Colors.orange,
              ),
            );
          }
        }

        if (temperature < 5) {
          if (asthmaRespiratory) {
            recommendations.add(
              PersonalizedRecommendation(
                icon: Icons.ac_unit,
                title: 'Cold Air Asthma Alert',
                description:
                    'Cold air can trigger asthma. Wear a scarf over your nose and mouth to warm the air you breathe.',
                color: Colors.blue,
              ),
            );
          }

          if (heartDisease) {
            recommendations.add(
              PersonalizedRecommendation(
                icon: Icons.ac_unit,
                title: 'Cold Weather Heart Care',
                description:
                    'Cold weather increases heart strain. Dress warmly and avoid sudden physical exertion outdoors.',
                color: Colors.blue,
              ),
            );
          }
        }
      }
    } catch (e) {
      print('Error fetching user profile for recommendations: $e');
    }

    final uniqueRecommendations = recommendations.toSet().toList();
    uniqueRecommendations.sort(
      (a, b) =>
          _getSeverityLevel(b.color).compareTo(_getSeverityLevel(a.color)),
    );

    return uniqueRecommendations.take(5).toList();
  }

  int _getSeverityLevel(Color color) {
    if (color == Colors.red) return 3;
    if (color == Colors.orange) return 2;
    if (color == Colors.blue) return 1;
    return 0; // green
  }

  @override
  Widget build(BuildContext context) {
    final aqiStatus = _getAQIStatus(aqi);
    final alert = _getAirQualityAlert();

    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 120,
              floating: false,
              pinned: true,
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.refresh, color: Color(0xFF1E293B)),
                  onPressed: () {
                    onRefresh();
                    Navigator.pop(context);
                  },
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                title: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      _formatTime(),
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                titlePadding: EdgeInsets.only(left: 16, bottom: 16),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAQICard(aqiStatus),
                    SizedBox(height: 16),
                    _buildAlertBanner(alert),
                    SizedBox(height: 24),
                    _buildSectionTitle('Weather Conditions'),
                    SizedBox(height: 12),
                    _buildWeatherGrid(),
                    SizedBox(height: 24),
                    _buildSectionTitle('Air Pollutants'),
                    SizedBox(height: 12),
                    _buildPollutantsGrid(),

                    // New Personalized Recommendations Section
                    SizedBox(height: 24),
                    _buildSectionTitle('Personalized Recommendations'),
                    SizedBox(height: 12),
                    FutureBuilder<List<PersonalizedRecommendation>>(
                      future: _getPersonalizedRecommendations(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return _buildRecommendationCard(
                            PersonalizedRecommendation(
                              icon: Icons.hourglass_empty,
                              title: 'Loading Recommendations',
                              description:
                                  'Getting personalized suggestions based on your profile...',
                              color: Colors.grey,
                            ),
                          );
                        }

                        if (snapshot.hasError) {
                          return _buildRecommendationCard(
                            PersonalizedRecommendation(
                              icon: Icons.error_outline,
                              title: 'General Recommendations',
                              description:
                                  'Based on current air quality conditions, consider limiting prolonged outdoor exposure.',
                              color: Colors.blue,
                            ),
                          );
                        }

                        final recommendations = snapshot.data ?? [];
                        return Column(
                          children:
                              recommendations
                                  .map(
                                    (rec) => Padding(
                                      padding: EdgeInsets.only(bottom: 12),
                                      child: _buildRecommendationCard(rec),
                                    ),
                                  )
                                  .toList(),
                        );
                      },
                    ),

                    SizedBox(height: 24),
                    _buildSectionTitle('Health Recommendations'),
                    SizedBox(height: 12),
                    _buildHealthRecommendations(aqiStatus),
                    SizedBox(height: 24),
                    _buildSectionTitle('AQI Scale Reference'),
                    SizedBox(height: 12),
                    _buildAQIScaleReference(),
                    SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Color(0xFF64748B),
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildAQICard(AQIStatus aqiStatus) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            aqiStatus.color.withOpacity(0.15),
            aqiStatus.color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: aqiStatus.color.withOpacity(0.3), width: 2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'AIR QUALITY INDEX',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                  letterSpacing: 1,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: aqiStatus.color,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: aqiStatus.color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  aqiStatus.label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$aqi',
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                  color: aqiStatus.color,
                  height: 1,
                ),
              ),
              SizedBox(width: 12),
              Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'AQI',
                  style: TextStyle(
                    fontSize: 18,
                    color: aqiStatus.color.withOpacity(0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: (aqi / 300).clamp(0.0, 1.0),
              backgroundColor: Colors.white.withOpacity(0.5),
              valueColor: AlwaysStoppedAnimation<Color>(aqiStatus.color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertBanner(AirQualityAlert alert) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: alert.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: alert.color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: alert.color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(alert.icon, color: alert.color, size: 24),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  alert.message,
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherGrid() {
    return Row(
      children: [
        Expanded(
          child: _buildWeatherCard(
            icon: Icons.thermostat,
            label: 'Temperature',
            value: '${temperature.toInt()}°C',
            color: Color(0xFFEF4444),
            subtitle: 'Current temp',
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _buildWeatherCard(
            icon: Icons.water_drop,
            label: 'Humidity',
            value: '$humidity%',
            color: Color(0xFF0EA5E9),
            subtitle: 'Moisture',
          ),
        ),
      ],
    );
  }

  Widget _buildWeatherCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildPollutantsGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildPollutantCard(
                label: 'PM2.5',
                value: pm25.toStringAsFixed(1),
                unit: 'µg/m³',
                color: Color(0xFFEF4444),
                description: 'Fine particles',
                icon: Icons.grain,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildPollutantCard(
                label: 'PM10',
                value: pm10.toStringAsFixed(1),
                unit: 'µg/m³',
                color: Color(0xFF8B5CF6),
                description: 'Coarse particles',
                icon: Icons.blur_on,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildPollutantCard(
                label: 'Dust',
                value: dust.toStringAsFixed(1),
                unit: 'µg/m³',
                color: Color(0xFFF59E0B),
                description: 'Dust particles',
                icon: Icons.cloud,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildWeatherCard(
                icon: Icons.air,
                label: 'Wind Speed',
                value: '${windSpeed}km/h',
                color: Color(0xFF06B6D4),
                subtitle: 'Current wind',
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        _buildVisibilityCard(),
      ],
    );
  }

  Widget _buildPollutantCard({
    required String label,
    required String value,
    required String unit,
    required Color color,
    required String description,
    required IconData icon,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Container(
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(unit, style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
          SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildVisibilityCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Color(0xFF8B5CF6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.visibility, color: Color(0xFF8B5CF6), size: 28),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Visibility',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '${visibility.toStringAsFixed(1)} km',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthRecommendations(AQIStatus aqiStatus) {
    List<HealthRecommendation> recommendations = [];

    if (aqi <= 50) {
      recommendations = [
        HealthRecommendation(
          icon: Icons.directions_run,
          title: 'Exercise Outdoors',
          description: 'Perfect conditions for outdoor activities',
          color: Colors.green,
        ),
        HealthRecommendation(
          icon: Icons.sunny,
          title: 'Enjoy the Day',
          description: 'Air quality is excellent',
          color: Colors.green,
        ),
      ];
    } else if (aqi <= 100) {
      recommendations = [
        HealthRecommendation(
          icon: Icons.nature_people,
          title: 'Generally Safe',
          description:
              'Unusually sensitive people should consider limiting prolonged outdoor exertion',
          color: Colors.yellow[700]!,
        ),
      ];
    } else if (aqi <= 150) {
      recommendations = [
        HealthRecommendation(
          icon: Icons.groups,
          title: 'Sensitive Groups',
          description:
              'Children, elderly, and people with respiratory conditions should limit outdoor activities',
          color: Colors.orange,
        ),
        HealthRecommendation(
          icon: Icons.masks,
          title: 'Consider Mask',
          description:
              'Wear a mask if you need to be outdoors for extended periods',
          color: Colors.orange,
        ),
      ];
    } else {
      recommendations = [
        HealthRecommendation(
          icon: Icons.home,
          title: 'Stay Indoors',
          description: 'Everyone should avoid outdoor activities',
          color: Colors.red,
        ),
        HealthRecommendation(
          icon: Icons.masks,
          title: 'Wear Mask',
          description: 'Use N95 masks if you must go outside',
          color: Colors.red,
        ),
        HealthRecommendation(
          icon: Icons.medical_services,
          title: 'Health Alert',
          description: 'Seek medical attention if you experience symptoms',
          color: Colors.red,
        ),
      ];
    }

    return Column(
      children:
          recommendations
              .map(
                (rec) => Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: _buildRecommendationCard(rec),
                ),
              )
              .toList(),
    );
  }

  Widget _buildRecommendationCard(dynamic rec) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: rec.color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: rec.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(rec.icon, color: rec.color, size: 24),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rec.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  rec.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAQIScaleReference() {
    final scales = [
      {'range': '0-50', 'label': 'Good', 'color': Color(0xFF00E676)},
      {'range': '51-100', 'label': 'Moderate', 'color': Color(0xFFFFC400)},
      {
        'range': '101-150',
        'label': 'Unhealthy for Sensitive',
        'color': Color(0xFFFF9100),
      },
      {'range': '151-200', 'label': 'Unhealthy', 'color': Color(0xFFFF5252)},
      {
        'range': '201-300',
        'label': 'Very Unhealthy',
        'color': Color(0xFFB71C1C),
      },
      {'range': '301+', 'label': 'Hazardous', 'color': Color(0xFF7B1FA2)},
    ];

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children:
            scales.map((scale) {
              return Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      padding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      decoration: BoxDecoration(
                        color: (scale['color'] as Color).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        scale['range'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: scale['color'] as Color,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(width: 12),
                    Container(
                      width: 4,
                      height: 24,
                      decoration: BoxDecoration(
                        color: scale['color'] as Color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        scale['label'] as String,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
      ),
    );
  }
}

class AQIStatus {
  final String label;
  final Color color;
  final Color backgroundColor;

  AQIStatus({
    required this.label,
    required this.color,
    required this.backgroundColor,
  });
}

class AirQualityAlert {
  final IconData icon;
  final String title;
  final String message;
  final Color color;
  final String severity;

  AirQualityAlert({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
    required this.severity,
  });
}

class HealthRecommendation {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  HealthRecommendation({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}

class PersonalizedRecommendation {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  PersonalizedRecommendation({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}
