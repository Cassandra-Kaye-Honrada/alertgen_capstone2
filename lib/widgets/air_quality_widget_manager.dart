// lib/widgets/air_quality_widget_manager.dart

import 'package:home_widget/home_widget.dart';
import 'package:allergen/screens/health_environment_analytics/models/air_quality_models.dart';

class AirQualityWidgetManager {
  /// Initialize the widget manager
  /// Call this in your main.dart during app startup
  static Future<void> initialize() async {
    try {
      // Register the widget click callback
      await HomeWidget.registerBackgroundCallback(backgroundCallback);
      print('AirQualityWidgetManager initialized');
    } catch (e) {
      print('Error initializing AirQualityWidgetManager: $e');
    }
  }

  /// Background callback for widget interactions
  @pragma('vm:entry-point')
  static Future<void> backgroundCallback(Uri? uri) async {
    print('Widget background callback triggered: $uri');
    // Handle background widget updates here if needed
  }

  static Future<void> updateFromAirQualityData({
    required AirQualityData airQualityData,
    required String location,
  }) async {
    try {
      // Get AQI value
      final aqi = airQualityData.aqi ?? 0;

      // Get quality level text
      final qualityLevel =
          airQualityData.qualityLevel ?? _getQualityLevelText(aqi);

      // Get dominant pollutant
      final dominantPollutant = airQualityData.dominantPollutant ?? 'N/A';

      // Save data to widget
      await HomeWidget.saveWidgetData<int>('aqi', aqi);
      await HomeWidget.saveWidgetData<String>('quality_level', qualityLevel);
      await HomeWidget.saveWidgetData<String>(
        'dominant_pollutant',
        dominantPollutant,
      );
      await HomeWidget.saveWidgetData<String>('location', location);

      // Update the widget
      await HomeWidget.updateWidget(
        androidName: 'HomeWidgetProvider',
        iOSName: 'HomeWidgetProvider',
      );

      print(
        'Widget updated successfully: AQI=$aqi, Level=$qualityLevel, Pollutant=$dominantPollutant, Location=$location',
      );
    } catch (e) {
      print('Error updating widget: $e');
    }
  }

  static String _getQualityLevelText(int aqi) {
    if (aqi <= 50) {
      return 'Good';
    } else if (aqi <= 100) {
      return 'Satisfactory';
    } else if (aqi <= 200) {
      return 'Moderate';
    } else if (aqi <= 300) {
      return 'Poor';
    } else if (aqi <= 400) {
      return 'Very Poor';
    } else {
      return 'Severe';
    }
  }

  static Future<void> clearWidgetData() async {
    try {
      await HomeWidget.saveWidgetData<int>('aqi', 0);
      await HomeWidget.saveWidgetData<String>('quality_level', 'Loading...');
      await HomeWidget.saveWidgetData<String>('dominant_pollutant', 'N/A');
      await HomeWidget.saveWidgetData<String>('location', 'Unknown Location');

      await HomeWidget.updateWidget(
        androidName: 'HomeWidgetProvider',
        iOSName: 'HomeWidgetProvider',
      );
    } catch (e) {
      print('Error clearing widget data: $e');
    }
  }
}
