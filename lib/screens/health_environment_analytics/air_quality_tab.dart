import 'package:allergen/screens/health_environment_analytics/widgets/AirQualityWidget.dart';
import 'package:flutter/material.dart';

class AirQualityTab extends StatelessWidget {
  final AirQualityData airQualityData;
  final String location;
  final List<Population> applicablePopulations;

  const AirQualityTab({
    Key? key,
    required this.airQualityData,
    required this.location,
    required this.applicablePopulations,
  }) : super(key: key);

  bool get _hasHealthRecommendations {
    return airQualityData.allHealthRecommendations != null &&
        airQualityData.allHealthRecommendations.isNotEmpty;
  }

  bool get _hasPollutantData {
    return airQualityData.components != null &&
        airQualityData.components.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOverviewSection(),
          const SizedBox(height: 24),
          if (_hasHealthRecommendations) _buildHealthRecommendationsSection(),
          const SizedBox(height: 24),
          if (_hasPollutantData) _buildPollutantsSection(),
          const SizedBox(height: 24),
          _buildAQIScaleSection(),
        ],
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
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
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
          const Row(
            children: [
              Icon(Icons.health_and_safety, size: 20, color: Colors.green),
              SizedBox(width: 8),
              Text(
                'Health Recommendations',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (applicablePopulations.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                const Text(
                  'For:',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                ...applicablePopulations.map((pop) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getPopulationIcon(pop),
                          size: 14,
                          color: Colors.blue[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getPopulationLabel(pop),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          const SizedBox(height: 16),
          ..._buildPopulationRecommendations(),
        ],
      ),
    );
  }

  List<Widget> _buildPopulationRecommendations() {
    List<Widget> widgets = [];

    for (var population in applicablePopulations) {
      final recommendationKey = _getPopulationRecommendationKey(population);
      final recommendation = _getHealthRecommendation(recommendationKey);

      if (recommendation != null && recommendation.isNotEmpty) {
        if (widgets.isNotEmpty) {
          widgets.add(const SizedBox(height: 16));
          widgets.add(Divider(color: Colors.grey[300], height: 1));
          widgets.add(const SizedBox(height: 16));
        }

        widgets.add(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _getPopulationIcon(population),
                    size: 18,
                    color: Colors.blue[700],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getPopulationLabel(population),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  recommendation,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }

    if (widgets.isEmpty) {
      widgets.add(
        const Column(
          children: [
            Icon(Icons.info_outline, size: 40, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'No specific health recommendations available for current air quality conditions.',
              style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return widgets;
  }

  String? _getHealthRecommendation(String key) {
    try {
      return airQualityData.allHealthRecommendations[key];
    } catch (e) {
      return null;
    }
  }

  Widget _buildPollutantsSection() {
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
          const Row(
            children: [
              Icon(Icons.science, size: 20, color: Colors.orange),
              SizedBox(width: 8),
              Text(
                'Pollutant Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_hasPollutantData)
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
                      entry.key,
                    );
                  }).toList(),
            )
          else
            const Center(
              child: Text(
                'No pollutant data available',
                style: TextStyle(color: Colors.grey),
              ),
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
    String pollutantCode,
  ) {
    final isDominant =
        airQualityData.dominantPollutant.toLowerCase() ==
        pollutantCode.toLowerCase();

    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (isDominant)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Dominant',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
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
          const Row(
            children: [
              Icon(Icons.legend_toggle, size: 20, color: Colors.purple),
              SizedBox(width: 8),
              Text(
                'AQI Scale Reference',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildAQIScaleItem(
            0,
            50,
            Colors.green,
            'Good',
            'Air quality is satisfactory',
          ),
          _buildAQIScaleItem(
            51,
            100,
            Colors.yellow,
            'Moderate',
            'Acceptable air quality',
          ),
          _buildAQIScaleItem(
            101,
            150,
            Colors.orange,
            'Unhealthy for Sensitive Groups',
            'General public less likely affected',
          ),
          _buildAQIScaleItem(
            151,
            200,
            Colors.red,
            'Unhealthy',
            'Everyone may experience effects',
          ),
          _buildAQIScaleItem(
            201,
            300,
            Colors.purple,
            'Very Unhealthy',
            'Health warnings',
          ),
          _buildAQIScaleItem(
            301,
            500,
            Colors.deepPurple,
            'Hazardous',
            'Emergency conditions',
          ),
        ],
      ),
    );
  }

  Widget _buildAQIScaleItem(
    int min,
    int max,
    Color color,
    String level,
    String description,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 2),
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
                Row(
                  children: [
                    Text(
                      '$min - $max',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        level,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  IconData _getPopulationIcon(Population population) {
    switch (population) {
      case Population.generalPopulation:
        return Icons.people;
      case Population.elderly:
        return Icons.elderly;
      case Population.lungDiseasePopulation:
        return Icons.air;
      case Population.heartDiseasePopulation:
        return Icons.favorite;
      case Population.athletes:
        return Icons.directions_run;
      case Population.pregnantWomen:
        return Icons.pregnant_woman;
      case Population.children:
        return Icons.child_care;
    }
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
        return 'Fine inhalable particles';
      case 'pm10':
        return 'Inhalable particles';
      case 'o3':
        return 'Ground-level ozone';
      case 'no2':
        return 'Nitrogen dioxide';
      case 'so2':
        return 'Sulfur dioxide';
      case 'co':
        return 'Carbon monoxide';
      default:
        return 'Air pollutant';
    }
  }

  String _getPopulationLabel(Population population) {
    switch (population) {
      case Population.generalPopulation:
        return 'General Public';
      case Population.elderly:
        return 'Elderly';
      case Population.lungDiseasePopulation:
        return 'Lung Conditions';
      case Population.heartDiseasePopulation:
        return 'Heart Conditions';
      case Population.athletes:
        return 'Athletes';
      case Population.pregnantWomen:
        return 'Pregnant Women';
      case Population.children:
        return 'Children';
    }
  }
}
