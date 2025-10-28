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

  String _getPollutantName(String code) {
    switch (code.toLowerCase()) {
      case 'pm25':
        return 'PM2.5';
      case 'pm10':
        return 'PM10';
      case 'o3':
        return 'Ozone';
      case 'no2':
        return 'Nitrogen Dioxide';
      case 'so2':
        return 'Sulfur Dioxide';
      case 'co':
        return 'Carbon Monoxide';
      default:
        return code.toUpperCase();
    }
  }

  String _getPollutantDescription(String code) {
    switch (code.toLowerCase()) {
      case 'pm25':
        return 'Fine particles';
      case 'pm10':
        return 'Coarse particles';
      case 'o3':
        return 'Ozone gas';
      case 'no2':
        return 'Nitrogen oxide';
      case 'so2':
        return 'Sulfur oxide';
      case 'co':
        return 'Carbon monoxide';
      default:
        return 'Air pollutant';
    }
  }

  String _getPopulationLabel(Population population) {
    switch (population) {
      case Population.generalPopulation:
        return 'General';
      case Population.elderly:
        return 'Elderly';
      case Population.lungDiseasePopulation:
        return 'Lung Diseases';
      case Population.heartDiseasePopulation:
        return 'Heart Diseases';
      case Population.athletes:
        return 'Athletes';
      case Population.pregnantWomen:
        return 'Pregnant Women';
      case Population.children:
        return 'Children';
    }
  }
}
