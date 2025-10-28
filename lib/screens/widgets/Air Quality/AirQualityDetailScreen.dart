import 'package:allergen/screens/widgets/AirQualityWidget.dart';
import 'package:flutter/material.dart';

class AirQualityDetailScreen extends StatelessWidget {
  final AirQualityData airQualityData;
  final String location;
  final Population population;

  const AirQualityDetailScreen({
    Key? key,
    required this.airQualityData,
    required this.location,
    required this.population,
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Air Quality Details'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Location and AQI Overview
            _buildOverviewSection(),
            const SizedBox(height: 24),

            // Health Recommendations
            _buildHealthRecommendationsSection(),
            const SizedBox(height: 24),

            // Pollutant Details
            _buildPollutantsSection(),
            const SizedBox(height: 24),

            // AQI Scale Information
            _buildAQIScaleSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            location,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          // AQI Circle with value
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 180,
                height: 180,
                child: CustomPaint(
                  painter: AQIGaugePainter(
                    aqi: airQualityData.aqi.toDouble(),
                    color: airQualityData.color,
                  ),
                ),
              ),
              Column(
                children: [
                  Text(
                    '${airQualityData.aqi}',
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'AQI',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Air Quality Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: airQualityData.color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: airQualityData.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  airQualityData.qualityLevel,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: airQualityData.color,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Text(
            'Dominant pollutant: ${airQualityData.dominantPollutant}',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthRecommendationsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Health Recommendations',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getPopulationLabel(population),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (airQualityData.healthRecommendation != null)
            Text(
              airQualityData.healthRecommendation!,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
                height: 1.5,
              ),
            )
          else
            const Text(
              'No specific health recommendations available for current air quality conditions.',
              style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.5),
            ),

          const SizedBox(height: 16),

          // Additional general recommendations based on AQI
          _buildAdditionalRecommendations(),
        ],
      ),
    );
  }

  Widget _buildAdditionalRecommendations() {
    List<String> recommendations = [];

    if (airQualityData.aqi <= 50) {
      recommendations.addAll([
        '• Air quality is satisfactory',
        '• No health risks expected',
        '• Ideal for outdoor activities',
      ]);
    } else if (airQualityData.aqi <= 100) {
      recommendations.addAll([
        '• Air quality is acceptable',
        '• Consider reducing prolonged outdoor exertion if unusually sensitive',
        '• Generally okay for most activities',
      ]);
    } else if (airQualityData.aqi <= 150) {
      recommendations.addAll([
        '• Members of sensitive groups may experience health effects',
        '• General public is less likely to be affected',
        '• Consider reducing intense outdoor activities',
      ]);
    } else if (airQualityData.aqi <= 200) {
      recommendations.addAll([
        '• Everyone may begin to experience health effects',
        '• Members of sensitive groups may experience more serious effects',
        '• Avoid prolonged outdoor exertion',
      ]);
    } else if (airQualityData.aqi <= 300) {
      recommendations.addAll([
        '• Health alert: everyone may experience more serious effects',
        '• Avoid all outdoor physical activities',
        '• Keep windows and doors closed',
      ]);
    } else {
      recommendations.addAll([
        '• Health warning of emergency conditions',
        '• Entire population is likely to be affected',
        '• Stay indoors with air purification if possible',
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'General Guidelines:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        ...recommendations
            .map(
              (rec) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  rec,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
              ),
            )
            .toList(),
      ],
    );
  }

  Widget _buildPollutantsSection() {
    if (airQualityData.components.isEmpty) {
      return const SizedBox();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pollutant Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            children:
                airQualityData.components.entries.map((entry) {
                  return _buildPollutantCard(
                    _getPollutantName(entry.key),
                    entry.value,
                    'μg/m³',
                    _getPollutantDescription(entry.key),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPollutantCard(
    String name,
    double value,
    String unit,
    String description,
  ) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value.toStringAsFixed(1),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Text(unit, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildAQIScaleSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AQI Scale',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          _buildAQIScaleItem(0, 50, Colors.green, 'Good'),
          _buildAQIScaleItem(51, 100, Colors.yellow, 'Moderate'),
          _buildAQIScaleItem(
            101,
            150,
            Colors.orange,
            'Unhealthy for Sensitive Groups',
          ),
          _buildAQIScaleItem(151, 200, Colors.red, 'Unhealthy'),
          _buildAQIScaleItem(201, 300, Colors.purple, 'Very Unhealthy'),
          _buildAQIScaleItem(301, 500, Colors.deepPurple, 'Hazardous'),
        ],
      ),
    );
  }

  Widget _buildAQIScaleItem(int min, int max, Color color, String level) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$min - $max',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  level,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
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
>>>>>>> becffe0e8c9396748a0b5f1748a5897f9aeaebb6
