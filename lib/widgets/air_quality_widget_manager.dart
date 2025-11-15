import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

class AirQualityWidgetManager {
  // Call this method whenever air quality data is updated
  static Future<void> updateWidget({
    required int aqi,
    required String qualityLevel,
    required String dominantPollutant,
    required String location,
  }) async {
    try {
      // Save data to shared preferences for widget access
      await HomeWidget.saveWidgetData<int>('aqi', aqi);
      await HomeWidget.saveWidgetData<String>('quality_level', qualityLevel);
      await HomeWidget.saveWidgetData<String>(
        'dominant_pollutant',
        dominantPollutant,
      );
      await HomeWidget.saveWidgetData<String>('location', location);

      // Determine background color based on AQI
      String bgColor = _getBackgroundColor(aqi);
      await HomeWidget.saveWidgetData<String>('bg_color', bgColor);

      // Update the widget
      await HomeWidget.updateWidget(
        name: 'HomeWidgetProvider',
        androidName: 'HomeWidgetProvider',
      );
    } catch (e) {
      debugPrint('Error updating widget: $e');
    }
  }

  // Convenient method to update from AirQualityData model
  // This works with any object that has these properties
  static Future<void> updateFromAirQualityData({
    required dynamic airQualityData,
    required String location,
  }) async {
    await updateWidget(
      aqi: airQualityData.aqi as int,
      qualityLevel: airQualityData.qualityLevel as String,
      dominantPollutant: airQualityData.dominantPollutant as String,
      location: location,
    );
  }

  static String _getBackgroundColor(int aqi) {
    if (aqi <= 50) return '#00E400';
    if (aqi <= 100) return '#FFFF00';
    if (aqi <= 150) return '#FF7E00';
    if (aqi <= 200) return '#FF0000';
    if (aqi <= 300) return '#8F3F97';
    return '#7E0023';
  }

  // Initialize widget on app start (Android doesn't need App Group ID)
  static Future<void> initialize() async {
    // No setup needed for Android-only widgets
    debugPrint('Widget manager initialized');
  }
}
