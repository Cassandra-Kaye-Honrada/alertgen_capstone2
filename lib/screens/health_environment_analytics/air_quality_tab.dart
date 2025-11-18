import 'package:allergen/screens/health_environment_analytics/models/air_quality_models.dart';
import 'package:allergen/screens/health_environment_analytics/models/weather_models.dart';
import 'package:allergen/screens/health_environment_analytics/widgets/AirQualityWidget.dart';
import 'package:allergen/screens/health_environment_analytics/widgets/AirQualityTrendWidget.dart';
import 'package:flutter/material.dart';
import 'package:weather_icons/weather_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

// Unified Color Palette
class AppColors {
  static const primary = Color(0xFF2563EB); // Blue
  static const secondary = Color(0xFF475569); // Slate
  static const success = Color(0xFF10B981); // Green
  static const warning = Color(0xFFF59E0B); // Amber
  static const danger = Color(0xFFEF4444); // Red
  static const background = Color(0xFFF8FAFC); // Light gray
  static const cardBackground = Colors.white;
  static const textPrimary = Color(0xFF1E293B);
  static const textSecondary = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);
}

class AirQualityTab extends StatefulWidget {
  final String? apiKey;
  final String location;
  final List<Population> applicablePopulations;
  final WeatherData? weatherData;

  const AirQualityTab({
    Key? key,
    this.apiKey,
    required this.location,
    required this.applicablePopulations,
    this.weatherData,
  }) : super(key: key);

  @override
  State<AirQualityTab> createState() => _AirQualityTabState();
}

class _AirQualityTabState extends State<AirQualityTab> {
  AirQualityData? _cachedAirQualityData;
  bool _isLoadingCachedData = true;
  List<int> _historicalAqiData = [];
  bool _isLoadingHistoricalData = false;

  @override
  void initState() {
    super.initState();
    _loadCachedData();
    _loadHistoricalData();
  }

  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('cached_aqi_data');

      if (cachedData != null) {
        final data = json.decode(cachedData);
        final airQualityData = data['airQualityData'];

        setState(() {
          _cachedAirQualityData = AirQualityData.fromGoogleJson(
            airQualityData,
            _getMostCriticalPopulation(widget.applicablePopulations),
            _getPopulationRecommendationKey(
              _getMostCriticalPopulation(widget.applicablePopulations),
            ),
            widget.applicablePopulations,
          );
          _isLoadingCachedData = false;
        });
      } else {
        setState(() {
          _isLoadingCachedData = false;
        });
      }
    } catch (e) {
      print('Error loading cached data: $e');
      setState(() {
        _isLoadingCachedData = false;
      });
    }
  }

  Future<void> _loadHistoricalData() async {
    if (widget.apiKey == null) return;

    setState(() {
      _isLoadingHistoricalData = true;
    });

    try {
      final historicalData = await _fetchHistoricalAQIData();
      setState(() {
        _historicalAqiData = historicalData;
        _isLoadingHistoricalData = false;
      });
    } catch (e) {
      print('Error loading historical data: $e');
      // Fallback to generated data
      setState(() {
        _historicalAqiData = _generateFallbackHistoricalData();
        _isLoadingHistoricalData = false;
      });
    }
  }

  Future<List<int>> _fetchHistoricalAQIData() async {
    // Using OpenWeatherMap Air Pollution API for historical data
    // You can also use other services like AirVisual, WAQI, etc.
    final lat = '40.7128'; // Example coordinates - replace with actual location
    final lon = '-74.0060';

    final List<int> historicalData = [];
    final now = DateTime.now();

    // Fetch last 7 days of data
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      try {
        final aqi = await _fetchAQIForDate(date, lat, lon);
        historicalData.add(aqi);
      } catch (e) {
        // If API fails for a day, use fallback
        final fallbackValue = _generateFallbackValueForDate(date);
        historicalData.add(fallbackValue);
      }
    }

    return historicalData;
  }

  Future<int> _fetchAQIForDate(DateTime date, String lat, String lon) async {
    // OpenWeatherMap Historical Air Pollution API
    final timestamp = date.millisecondsSinceEpoch ~/ 1000;
    final url = Uri.parse(
      'http://api.openweathermap.org/data/2.5/air_pollution/history?'
      'lat=$lat&lon=$lon&start=$timestamp&end=$timestamp&appid=${widget.apiKey}',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['list'] != null && data['list'].isNotEmpty) {
        final aqiValue = data['list'][0]['main']['aqi']; // 1-5 scale
        // Convert 1-5 scale to 0-500 scale
        return _convertToUSAQI(aqiValue);
      }
    }

    throw Exception('Failed to fetch historical AQI data');
  }

  int _convertToUSAQI(int aqiScale) {
    // Convert 1-5 scale to approximate US AQI values
    const conversionMap = {
      1: 50, // Good
      2: 100, // Moderate
      3: 150, // Unhealthy for sensitive groups
      4: 200, // Unhealthy
      5: 300, // Very Unhealthy
    };
    return conversionMap[aqiScale] ?? 100;
  }

  List<int> _generateFallbackHistoricalData() {
    if (_cachedAirQualityData == null) return [50, 45, 60, 55, 48, 52, 49];

    final currentAqi = _cachedAirQualityData!.aqi;
    final random = Random();

    return List.generate(7, (index) {
      if (index == 6) return currentAqi; // Today's value

      // Create realistic variation for previous days
      final variation = (random.nextDouble() * 40 - 20).round();
      return (currentAqi + variation).clamp(0, 500);
    });
  }

  int _generateFallbackValueForDate(DateTime date) {
    final random = Random(date.day + date.month);
    final baseValue = _cachedAirQualityData?.aqi ?? 50;
    final variation = (random.nextDouble() * 40 - 20).round();
    return (baseValue + variation).clamp(0, 500);
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main Air Quality Widget
          AirQualityWidget(
            apiKey: widget.apiKey,
            overflow: true,
            showSearch: true,
            showRefresh: true,
            healthRecoOverflow: false,
          ),
          const SizedBox(height: 20),

          // Weather Card
          if (widget.weatherData != null) buildWeatherCard(),
          if (widget.weatherData != null) const SizedBox(height: 20),

          // Other components using cached data
          if (_cachedAirQualityData != null && !_isLoadingCachedData) ...[
            buildPollutantChart(),
            const SizedBox(height: 20),
            _buildTrendSection(),
            const SizedBox(height: 20),
            if (_hasHealthRecommendations) _buildHealthRecommendations(),
            if (_hasHealthRecommendations) const SizedBox(height: 20),
          ],

          _buildAQIReferenceGuide(),
        ],
      ),
    );
  }

  // ============================================================================
  // TREND SECTION WITH HISTORICAL DATA
  // ============================================================================

  Widget _buildTrendSection() {
    final trendMessage = _getTrendMessage();

    if (_isLoadingHistoricalData) {
      return _buildLoadingTrend();
    }

    return AirQualityTrendWidget(
      aqiValues:
          _historicalAqiData.isNotEmpty
              ? _historicalAqiData
              : _generateFallbackHistoricalData(),
      labels: AirQualityTrendWidget.generateDateLabels(7),
      trendMessage: trendMessage,
    );
  }

  Widget _buildLoadingTrend() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.trending_up,
                  color: Color(0xFF0B8FAC),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '7-Day Air Quality Trend',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Loading historical data...',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF666666),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _getTrendMessage() {
    if (_historicalAqiData.length < 2) {
      return 'Insufficient data to determine trend.';
    }

    final current = _historicalAqiData.last;
    final previous = _historicalAqiData[_historicalAqiData.length - 2];
    final difference = current - previous;

    if (difference > 15) {
      return 'Air quality is deteriorating rapidly. Consider limiting outdoor activities and using air purifiers.';
    } else if (difference > 5) {
      return 'Air quality is getting worse. Sensitive groups should take precautions.';
    } else if (difference < -15) {
      return 'Air quality is improving significantly. Good time for outdoor activities.';
    } else if (difference < -5) {
      return 'Air quality is improving. Conditions are becoming more favorable.';
    } else {
      return 'Air quality remains stable. No significant changes observed.';
    }
  }

  // ============================================================================
  // UI COMPONENTS
  // ============================================================================

  Widget buildWeatherCard() {
    return _UniformCard(
      icon: getWeatherIcon(widget.weatherData!.icon),
      title: 'Weather Conditions',
      iconColor: AppColors.primary,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: buildWeatherMainDisplay()),
              Container(width: 1, height: 100, color: AppColors.border),
              Expanded(child: buildWeatherMetrics()),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    getWeatherImpact(),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildWeatherMainDisplay() {
    return Column(
      children: [
        BoxedIcon(
          getWeatherIcon(widget.weatherData!.icon),
          size: 48,
          color: AppColors.primary,
        ),
        const SizedBox(height: 8),
        Text(
          '${widget.weatherData!.temperature.toStringAsFixed(1)}°C',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          widget.weatherData!.description,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget buildWeatherMetrics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WeatherMetricRow(
          icon: WeatherIcons.humidity,
          label: 'Humidity',
          value: '${widget.weatherData!.humidity}%',
        ),
        const SizedBox(height: 10),
        _WeatherMetricRow(
          icon: WeatherIcons.strong_wind,
          label: 'Wind Speed',
          value: '${widget.weatherData!.windSpeed.toStringAsFixed(1)} m/s',
        ),
        const SizedBox(height: 10),
        _WeatherMetricRow(
          icon: WeatherIcons.day_sunny,
          label: 'UV Index',
          value: _UVIndex.getLabel(widget.weatherData!.uvIndex),
        ),
      ],
    );
  }

  Widget buildPollutantChart() {
    final sortedPollutants =
        _cachedAirQualityData!.components.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    final maxValue =
        sortedPollutants.isNotEmpty ? sortedPollutants.first.value : 100.0;

    return _UniformCard(
      icon: Icons.air,
      title: 'Air Pollutants Analysis',
      subtitle: 'Concentration levels (μg/m³)',
      iconColor: AppColors.primary,
      child:
          sortedPollutants.isEmpty
              ? _buildEmptyState('No pollutant data available')
              : Column(
                children:
                    sortedPollutants
                        .map((entry) => buildPollutantBar(entry, maxValue))
                        .toList(),
              ),
    );
  }

  Widget buildPollutantBar(MapEntry<String, double> entry, double maxValue) {
    final percentage = (entry.value / maxValue).clamp(0.0, 1.0);
    final isDominant =
        _cachedAirQualityData!.dominantPollutant.toLowerCase() ==
        entry.key.toLowerCase();
    final barColor = isDominant ? AppColors.warning : AppColors.primary;
    final pollutantInfo = _PollutantHelper.getInfo(entry.key);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: barColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        pollutantInfo['icon'] as IconData,
                        size: 16,
                        color: barColor,
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
                                pollutantInfo['name'] as String,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (isDominant) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'PRIMARY',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.warning,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            pollutantInfo['description'] as String,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: barColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: barColor.withOpacity(0.2)),
                ),
                child: Text(
                  '${entry.value.toStringAsFixed(1)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: barColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: percentage,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthRecommendations() {
    return _UniformCard(
      icon: Icons.health_and_safety_outlined,
      title: 'Health Recommendations',
      subtitle: 'Personalized advice based on your profile',
      iconColor: AppColors.danger,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.applicablePopulations.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  widget.applicablePopulations
                      .map((pop) => _buildPopulationChip(pop))
                      .toList(),
            ),
            const SizedBox(height: 16),
          ],
          ..._buildRecommendationsList(),
        ],
      ),
    );
  }

  Widget _buildPopulationChip(Population population) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _PopulationHelper.getIcon(population),
            size: 14,
            color: AppColors.primary,
          ),
          const SizedBox(width: 6),
          Text(
            _PopulationHelper.getLabel(population),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRecommendationsList() {
    final recommendations = <Widget>[];

    for (var population in widget.applicablePopulations) {
      final key = _PopulationHelper.getRecommendationKey(population);
      final recommendation =
          _cachedAirQualityData!.allHealthRecommendations[key];

      if (recommendation != null && recommendation.isNotEmpty) {
        if (recommendations.isNotEmpty) {
          recommendations.add(const SizedBox(height: 12));
        }

        recommendations.add(
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    _PopulationHelper.getIcon(population),
                    size: 16,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    recommendation,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    if (recommendations.isEmpty) {
      recommendations.add(
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.success.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: AppColors.success,
                size: 20,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Air quality is good. No special precautions needed.',
                  style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return recommendations;
  }

  Widget _buildAQIReferenceGuide() {
    return _UniformCard(
      icon: Icons.info_outline,
      title: 'AQI Reference Guide',
      subtitle: 'Indian National Air Quality Index (NAQI)',
      iconColor: AppColors.secondary,
      child: Column(
        children:
            _AQILevels.levels
                .map((level) => _buildAQIScaleItem(level))
                .toList(),
      ),
    );
  }

  Widget _buildAQIScaleItem(Map<String, dynamic> level) {
    final isCurrentLevel =
        _cachedAirQualityData != null &&
        _cachedAirQualityData!.aqi >= level['min'] &&
        _cachedAirQualityData!.aqi <= level['max'];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            isCurrentLevel
                ? (level['color'] as Color).withOpacity(0.08)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCurrentLevel ? (level['color'] as Color) : AppColors.border,
          width: isCurrentLevel ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: level['color'],
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.border.withOpacity(0.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${level['min']}-${level['max']}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              level['label'],
              style: TextStyle(
                fontSize: 13,
                fontWeight: isCurrentLevel ? FontWeight.bold : FontWeight.w500,
                color: isCurrentLevel ? level['color'] : AppColors.textPrimary,
              ),
            ),
          ),
          if (isCurrentLevel)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: level['color'],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'CURRENT',
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.info_outline,
              size: 40,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  bool get _hasHealthRecommendations {
    return _cachedAirQualityData != null &&
        _cachedAirQualityData!.allHealthRecommendations != null &&
        _cachedAirQualityData!.allHealthRecommendations.isNotEmpty &&
        widget.applicablePopulations.isNotEmpty;
  }

  String getWeatherImpact() {
    if (widget.weatherData == null) return 'Weather data not available';

    final wind = widget.weatherData!.windSpeed;
    final humidity = widget.weatherData!.humidity;
    final temp = widget.weatherData!.temperature;

    if (wind > 10) return 'Strong winds help disperse pollutants effectively';
    if (wind < 2 && humidity > 70)
      return 'Low wind and high humidity may trap pollutants near ground level';
    if (temp > 30)
      return 'High temperature can increase ground-level ozone formation';
    return 'Weather conditions are favorable for air quality';
  }

  IconData getWeatherIcon(String iconCode) {
    const iconMap = {
      '01d': WeatherIcons.day_sunny,
      '01n': WeatherIcons.night_clear,
      '02d': WeatherIcons.day_cloudy,
      '02n': WeatherIcons.night_alt_cloudy,
      '03d': WeatherIcons.cloud,
      '03n': WeatherIcons.cloud,
      '04d': WeatherIcons.cloudy,
      '04n': WeatherIcons.cloudy,
      '09d': WeatherIcons.showers,
      '09n': WeatherIcons.showers,
      '10d': WeatherIcons.day_rain,
      '10n': WeatherIcons.night_alt_rain,
      '11d': WeatherIcons.thunderstorm,
      '11n': WeatherIcons.thunderstorm,
      '13d': WeatherIcons.snow,
      '13n': WeatherIcons.snow,
      '50d': WeatherIcons.day_fog,
      '50n': WeatherIcons.night_fog,
    };
    return iconMap[iconCode.toLowerCase()] ?? WeatherIcons.day_sunny;
  }
}

// ============================================================================
// HELPER CLASSES
// ============================================================================

class _AQILevels {
  static final List<Map<String, dynamic>> levels = [
    {'min': 0, 'max': 50, 'color': const Color(0xFF10B981), 'label': 'Good'},
    {
      'min': 51,
      'max': 100,
      'color': const Color(0xFF84CC16),
      'label': 'Satisfactory',
    },
    {
      'min': 101,
      'max': 200,
      'color': const Color(0xFFF59E0B),
      'label': 'Moderate',
    },
    {'min': 201, 'max': 300, 'color': const Color(0xFFF97316), 'label': 'Poor'},
    {
      'min': 301,
      'max': 400,
      'color': const Color(0xFFEF4444),
      'label': 'Very Poor',
    },
    {
      'min': 401,
      'max': 500,
      'color': const Color(0xFF991B1B),
      'label': 'Severe',
    },
  ];
}

class _UVIndex {
  static String getLabel(double uvIndex) {
    if (uvIndex < 3) return 'Low';
    if (uvIndex < 6) return 'Moderate';
    if (uvIndex < 8) return 'High';
    if (uvIndex < 11) return 'Very High';
    return 'Extreme';
  }
}

class _PollutantHelper {
  static Map<String, dynamic> getInfo(String code) {
    final codeKey = code.toLowerCase();

    const info = {
      'pm25': {
        'name': 'PM2.5',
        'description': 'Fine particulate matter',
        'icon': Icons.grain,
      },
      'pm10': {
        'name': 'PM10',
        'description': 'Coarse particulate matter',
        'icon': Icons.blur_circular,
      },
      'o3': {
        'name': 'O₃',
        'description': 'Ground-level ozone',
        'icon': Icons.cloud_outlined,
      },
      'no2': {
        'name': 'NO₂',
        'description': 'Nitrogen dioxide',
        'icon': Icons.local_shipping,
      },
      'so2': {
        'name': 'SO₂',
        'description': 'Sulfur dioxide',
        'icon': Icons.factory,
      },
      'co': {
        'name': 'CO',
        'description': 'Carbon monoxide',
        'icon': Icons.warning_amber_rounded,
      },
    };

    return info[codeKey] ??
        {
          'name': code.toUpperCase(),
          'description': 'Air pollutant',
          'icon': Icons.air,
        };
  }
}

class _PopulationHelper {
  static IconData getIcon(Population population) {
    const iconMap = {
      Population.generalPopulation: Icons.people,
      Population.elderly: Icons.elderly,
      Population.lungDiseasePopulation: Icons.air,
      Population.heartDiseasePopulation: Icons.favorite,
      Population.athletes: Icons.directions_run,
      Population.pregnantWomen: Icons.pregnant_woman,
      Population.children: Icons.child_care,
    };
    return iconMap[population] ?? Icons.person;
  }

  static String getLabel(Population population) {
    const labelMap = {
      Population.generalPopulation: 'General Public',
      Population.elderly: 'Elderly',
      Population.lungDiseasePopulation: 'Lung Disease',
      Population.heartDiseasePopulation: 'Heart Disease',
      Population.athletes: 'Athletes',
      Population.pregnantWomen: 'Pregnant Women',
      Population.children: 'Children',
    };
    return labelMap[population] ?? 'Unknown';
  }

  static String getRecommendationKey(Population population) {
    const keyMap = {
      Population.generalPopulation: 'generalPopulation',
      Population.elderly: 'elderly',
      Population.lungDiseasePopulation: 'lungDiseasePopulation',
      Population.heartDiseasePopulation: 'heartDiseasePopulation',
      Population.athletes: 'athletes',
      Population.pregnantWomen: 'pregnantWomen',
      Population.children: 'children',
    };
    return keyMap[population] ?? '';
  }
}

// ============================================================================
// REUSABLE COMPONENTS
// ============================================================================

class _UniformCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color iconColor;
  final Widget child;

  const _UniformCard({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.iconColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _WeatherMetricRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _WeatherMetricRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        BoxedIcon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
