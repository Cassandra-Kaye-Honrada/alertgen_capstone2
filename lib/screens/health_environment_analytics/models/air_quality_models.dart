// lib/screens/health_environment_analytics/models/air_quality_models.dart

import 'package:flutter/material.dart';

/// Population types for health recommendations
enum Population {
  generalPopulation,
  elderly,
  lungDiseasePopulation,
  heartDiseasePopulation,
  athletes,
  pregnantWomen,
  children,
}

/// Air Quality Data model
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
