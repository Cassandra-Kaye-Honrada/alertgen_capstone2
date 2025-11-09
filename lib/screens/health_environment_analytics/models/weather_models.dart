// Create this file at: lib/models/weather_models.dart
// OR: lib/screens/health_environment_analytics/models/weather_models.dart

class WeatherData {
  final double temperature;
  final double feelsLike;
  final int humidity;
  final double windSpeed;
  final String description;
  final String icon;
  final int pressure;
  final double uvIndex;
  final double visibility;
  final int cloudCover;

  WeatherData({
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.description,
    required this.icon,
    required this.pressure,
    required this.uvIndex,
    this.visibility = 10.0,
    this.cloudCover = 0,
  });

  // Helper factory for mock data
  factory WeatherData.mock() {
    final hour = DateTime.now().hour;
    final isDay = hour >= 6 && hour < 18;

    return WeatherData(
      temperature: 28.5,
      feelsLike: 30.2,
      humidity: 70,
      windSpeed: 3.5,
      description: isDay ? 'Partly cloudy' : 'Clear',
      icon: isDay ? '02d' : '01n',
      pressure: 1013,
      uvIndex: isDay ? 8.0 : 0.0,
      visibility: 10.0,
      cloudCover: 40,
    );
  }
}

class EnvironmentalAnalytics {
  final double overallScore;
  final Map<String, double> categoryScores;
  final List<String> alerts;
  final List<String> recommendations;
  final String trend;

  EnvironmentalAnalytics({
    required this.overallScore,
    required this.categoryScores,
    required this.alerts,
    required this.recommendations,
    required this.trend,
  });

  // Helper factory to calculate from AQI
  factory EnvironmentalAnalytics.fromAqi(int aqi) {
    // Calculate scores
    final airScore =
        aqi <= 50
            ? 100.0
            : aqi <= 100
            ? 80.0
            : aqi <= 150
            ? 60.0
            : 40.0;
    final weatherScore = 85.0;
    final healthScore =
        aqi <= 50
            ? 95.0
            : aqi <= 100
            ? 75.0
            : aqi <= 150
            ? 55.0
            : 35.0;
    final overallScore = (airScore + weatherScore + healthScore) / 3;

    // Determine trend
    String trend =
        aqi < 50
            ? 'improving'
            : aqi > 150
            ? 'worsening'
            : 'stable';

    // Generate alerts
    List<String> alerts = [];
    if (aqi > 100) alerts.add('Air quality is unhealthy for sensitive groups');
    if (aqi > 150) alerts.add('Everyone may experience health effects');

    // Generate recommendations
    List<String> recommendations = [];
    if (aqi <= 50) {
      recommendations.add('Excellent conditions for outdoor activities');
    } else if (aqi <= 100) {
      recommendations.add('Air quality is acceptable for most people');
      recommendations.add('Sensitive individuals should monitor symptoms');
    } else {
      recommendations.add('Consider limiting prolonged outdoor activities');
      recommendations.add('Keep windows closed when possible');
    }

    return EnvironmentalAnalytics(
      overallScore: overallScore,
      categoryScores: {
        'air': airScore,
        'weather': weatherScore,
        'health': healthScore,
      },
      alerts: alerts,
      recommendations: recommendations,
      trend: trend,
    );
  }
}
