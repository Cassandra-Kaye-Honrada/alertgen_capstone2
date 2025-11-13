import 'package:allergen/screens/health_environment_analytics/models/weather_models.dart';
import 'package:allergen/screens/health_environment_analytics/widgets/AirQualityWidget.dart';
import 'package:flutter/material.dart';
import 'package:weather_icons/weather_icons.dart';

class AirQualityTab extends StatelessWidget {
  final AirQualityData airQualityData;
  final String location;
  final List<Population> applicablePopulations;
  final WeatherData? weatherData;

  const AirQualityTab({
    Key? key,
    required this.airQualityData,
    required this.location,
    required this.applicablePopulations,
    this.weatherData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAQIOverview(),
          const SizedBox(height: 16),
          buildEnvironmentalScore(),
          const SizedBox(height: 16),
          if (weatherData != null) buildWeatherCard(),
          if (weatherData != null) const SizedBox(height: 16),
          buildPollutantChart(),
          const SizedBox(height: 16),
          _buildAQITrendChart(),
          const SizedBox(height: 16),
          if (_hasHealthRecommendations) _buildHealthRecommendations(),
          if (_hasHealthRecommendations) const SizedBox(height: 16),
          _buildAQIReferenceGuide(),
        ],
      ),
    );
  }

 

  Widget _buildAQIOverview() {
    final naqiColor = _AQIColors.getColor(airQualityData.aqi);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [naqiColor.withOpacity(0.15), naqiColor.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: naqiColor.withOpacity(0.3), width: 2),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: naqiColor, size: 18),
              const SizedBox(width: 6),
              Text(
                location,
                style: TextStyle(
                  fontSize: 15,
                  color: naqiColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildAQIGauge(naqiColor),
              const SizedBox(width: 24),
              Expanded(child: _buildAQIInfo(naqiColor)),
            ],
          ),
          const SizedBox(height: 16),
          buildAQIStatusMessage(naqiColor),
        ],
      ),
    );
  }

  Widget _buildAQIGauge(Color naqiColor) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: naqiColor.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CustomPaint(
        painter: AQIGaugePainter(
          aqi: airQualityData.aqi.toDouble(),
          color: naqiColor,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${airQualityData.aqi}',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: naqiColor,
                ),
              ),
              Text(
                'AQI',
                style: TextStyle(
                  fontSize: 12,
                  color: naqiColor.withOpacity(0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAQIInfo(Color naqiColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          airQualityData.qualityLevel,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: naqiColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _getAQIDescription(airQualityData.aqi),
          style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.4),
        ),
        const SizedBox(height: 12),
        _buildInfoChip(
          Icons.eco_outlined,
          'Main: ${_PollutantHelper.getName(airQualityData.dominantPollutant)}',
          naqiColor,
        ),
      ],
    );
  }

  Widget buildAQIStatusMessage(Color naqiColor) {
    final message = getDetailedAQIMessage(airQualityData.aqi);
    final icon = getAQIStatusIcon(airQualityData.aqi);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: naqiColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: naqiColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: naqiColor,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildEnvironmentalScore() {
    final analysis = _EnvironmentalAnalyzer(
      airQualityData: airQualityData,
      weatherData: weatherData,
      applicablePopulations: applicablePopulations,
    );

    return _UniformCard(
      icon: Icons.analytics_outlined,
      title: 'Environmental Health',
      iconColor: _ScoreHelper.getColor(analysis.overallScore),
      child: Column(
        children: [
          buildOverallScore(analysis.overallScore),
          const SizedBox(height: 20),
          buildCategoryScore('Air Quality', analysis.airScore),
          buildCategoryScore('Weather', analysis.weatherScore),
          buildCategoryScore('Health Risk', analysis.healthScore),
          if (analysis.alerts.isNotEmpty) ...[
            const SizedBox(height: 16),
            buildAlertsSection(analysis.alerts),
          ],
        ],
      ),
    );
  }

  Widget buildOverallScore(double score) {
    final color = _ScoreHelper.getColor(score);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 3),
            ),
            child: Center(
              child: Text(
                '${score.toInt()}',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _ScoreHelper.getLabel(score),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getScoreExplanation(score),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildCategoryScore(String label, double score) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Text(
                '${score.toInt()}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _ScoreHelper.getColor(score),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 6,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                _ScoreHelper.getColor(score),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildAlertsSection(List<String> alerts) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[300]!, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: Colors.orange[800],
              ),
              const SizedBox(width: 8),
              Text(
                'Alerts',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...alerts.map(
            (alert) => Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.orange[800],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      alert,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[900],
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildWeatherCard() {
    return _UniformCard(
      icon: getWeatherIcon(weatherData!.icon),
      title: 'Weather',
      iconColor: Colors.blue[600]!,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: buildWeatherMainDisplay()),
              Container(width: 1, height: 100, color: Colors.grey[300]),
              Expanded(child: buildWeatherMetrics()),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    getWeatherImpact(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[900],
                      height: 1.3,
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
          getWeatherIcon(weatherData!.icon),
          size: 48,
          color: Colors.blue[600],
        ),
        const SizedBox(height: 8),
        Text(
          '${weatherData!.temperature.toStringAsFixed(1)}°C',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(
          weatherData!.description,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
          value: '${weatherData!.humidity}%',
        ),
        const SizedBox(height: 10),
        _WeatherMetricRow(
          icon: WeatherIcons.strong_wind,
          label: 'Wind',
          value: '${weatherData!.windSpeed.toStringAsFixed(1)} m/s',
        ),
        const SizedBox(height: 10),
        _WeatherMetricRow(
          icon: WeatherIcons.day_sunny,
          label: 'UV',
          value: _UVIndex.getLabel(weatherData!.uvIndex),
        ),
      ],
    );
  }

  Widget buildPollutantChart() {
    final sortedPollutants =
        airQualityData.components.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    final maxValue =
        sortedPollutants.isNotEmpty ? sortedPollutants.first.value : 100.0;

    return _UniformCard(
      icon: Icons.air,
      title: 'Air Pollutants',
      subtitle: 'Concentration (μg/m³)',
      iconColor: Colors.purple[600]!,
      child:
          sortedPollutants.isEmpty
              ? _buildEmptyState('No data available')
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
        airQualityData.dominantPollutant.toLowerCase() ==
        entry.key.toLowerCase();
    final barColor = isDominant ? Colors.orange[600]! : Colors.blue[600]!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    _PollutantHelper.getName(entry.key),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  if (isDominant) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Primary',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[800],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                '${entry.value.toStringAsFixed(1)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(
                  height: 20,
                  decoration: BoxDecoration(color: Colors.grey[200]),
                ),
                FractionallySizedBox(
                  widthFactor: percentage,
                  child: Container(
                    height: 20,
                    decoration: BoxDecoration(color: barColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAQITrendChart() {
    final historicalData = _generateHistoricalData();
    final stats = _calculateStats(historicalData);

    return _UniformCard(
      icon: Icons.show_chart,
      title: '7-Day Trend',
      iconColor: Colors.green[600]!,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatChip(
                'Current',
                '${airQualityData.aqi}',
                Colors.blue[600]!,
              ),
              _buildStatChip('High', '${stats['max']}', Colors.red[600]!),
              _buildStatChip('Low', '${stats['min']}', Colors.green[600]!),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: CustomPaint(
              painter: EnhancedLineChartPainter(
                data: historicalData,
                maxValue: 500,
                currentAqi: airQualityData.aqi,
              ),
              size: Size.infinite,
            ),
          ),
          const SizedBox(height: 12),
          _buildDateLabels(historicalData),
        ],
      ),
    );
  }

  Widget _buildDateLabels(List<MapEntry<DateTime, int>> data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children:
            data.map((entry) {
              final isToday = entry.key.day == DateTime.now().day;
              return Text(
                isToday ? 'Today' : '${entry.key.day}/${entry.key.month}',
                style: TextStyle(
                  fontSize: 11,
                  color: isToday ? Colors.blue[600] : Colors.grey[600],
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildHealthRecommendations() {
    return _UniformCard(
      icon: Icons.health_and_safety,
      title: 'Health Recommendations',
      iconColor: Colors.red[600]!,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (applicablePopulations.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  applicablePopulations
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue[200]!, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _PopulationHelper.getIcon(population),
            size: 14,
            color: Colors.blue[700],
          ),
          const SizedBox(width: 6),
          Text(
            _PopulationHelper.getLabel(population),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.blue[700],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRecommendationsList() {
    final recommendations = <Widget>[];

    for (var population in applicablePopulations) {
      final key = _PopulationHelper.getRecommendationKey(population);
      final recommendation = airQualityData.allHealthRecommendations[key];

      if (recommendation != null && recommendation.isNotEmpty) {
        if (recommendations.isNotEmpty) {
          recommendations.add(const SizedBox(height: 12));
        }

        recommendations.add(
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _PopulationHelper.getIcon(population),
                  size: 18,
                  color: Colors.blue[700],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    recommendation,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[800],
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
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green[600], size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Air quality is good. No special precautions needed.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
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
      title: 'AQI Reference',
      subtitle: 'Indian NAQI levels',
      iconColor: Colors.indigo[600]!,
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
        airQualityData.aqi >= level['min'] &&
        airQualityData.aqi <= level['max'];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            isCurrentLevel
                ? (level['color'] as Color).withOpacity(0.1)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCurrentLevel ? (level['color'] as Color) : Colors.grey[300]!,
          width: isCurrentLevel ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: level['color'],
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${level['min']}-${level['max']}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
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
                color: isCurrentLevel ? level['color'] : Colors.black87,
              ),
            ),
          ),
          if (isCurrentLevel)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: level['color'],
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Current',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================================
  // HELPER WIDGETS
  // ============================================================================

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.info_outline, size: 40, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  bool get _hasHealthRecommendations {
    return airQualityData.allHealthRecommendations != null &&
        airQualityData.allHealthRecommendations.isNotEmpty &&
        applicablePopulations.isNotEmpty;
  }

  String _getAQIDescription(int aqi) {
    if (aqi <= 50) return 'Perfect for outdoor activities';
    if (aqi <= 100) return 'Generally safe for everyone';
    if (aqi <= 200) return 'Sensitive groups may be affected';
    if (aqi <= 300) return 'Everyone may experience effects';
    if (aqi <= 400) return 'Health alert for everyone';
    return 'Emergency conditions';
  }

  IconData getAQIStatusIcon(int aqi) {
    if (aqi <= 50) return Icons.check_circle;
    if (aqi <= 100) return Icons.check_circle_outline;
    if (aqi <= 200) return Icons.warning_amber;
    if (aqi <= 300) return Icons.error_outline;
    return Icons.dangerous;
  }

  String getDetailedAQIMessage(int aqi) {
    if (aqi <= 50) return 'Excellent! Great day for outdoor activities';
    if (aqi <= 100) return 'Good air quality. Enjoy outdoor activities';
    if (aqi <= 200) return 'Moderate. Sensitive groups should limit exposure';
    if (aqi <= 300) return 'Poor. Reduce outdoor activities';
    if (aqi <= 400) return 'Very poor. Avoid outdoor activities';
    return 'Severe! Stay indoors with windows closed';
  }

  String _getScoreExplanation(double score) {
    if (score >= 80) return 'Excellent for outdoor activities';
    if (score >= 60) return 'Generally favorable conditions';
    if (score >= 40) return 'Consider limiting prolonged exposure';
    if (score >= 20) return 'Minimize outdoor activities';
    return 'Avoid outdoor exposure';
  }

  String getWeatherImpact() {
    if (weatherData == null) return 'Weather data not available';

    final wind = weatherData!.windSpeed;
    final humidity = weatherData!.humidity;
    final temp = weatherData!.temperature;

    if (wind > 10) return 'Strong winds help disperse pollutants';
    if (wind < 2 && humidity > 70)
      return 'Low wind and high humidity may trap pollutants';
    if (temp > 30) return 'High temperature can increase ozone levels';
    return 'Weather conditions are favorable';
  }

  List<MapEntry<DateTime, int>> _generateHistoricalData() {
    final now = DateTime.now();
    return List.generate(7, (index) {
      final date = now.subtract(Duration(days: 6 - index));
      final variation = (index - 3) * 10;
      final historicalAqi = (airQualityData.aqi + variation).clamp(0, 500);
      return MapEntry(date, historicalAqi);
    });
  }

  Map<String, int> _calculateStats(List<MapEntry<DateTime, int>> data) {
    final values = data.map((e) => e.value).toList();
    return {
      'max': values.reduce((a, b) => a > b ? a : b),
      'min': values.reduce((a, b) => a < b ? a : b),
    };
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

class _AQIColors {
  static Color getColor(int aqi) {
    if (aqi <= 50) return const Color(0xFF00E400);
    if (aqi <= 100) return const Color(0xFF92D050);
    if (aqi <= 200) return const Color(0xFFFFFF00);
    if (aqi <= 300) return const Color(0xFFFF7E00);
    if (aqi <= 400) return const Color(0xFFFF0000);
    return const Color(0xFF990000);
  }
}

class _AQILevels {
  static final List<Map<String, dynamic>> levels = [
    {'min': 0, 'max': 50, 'color': const Color(0xFF00E400), 'label': 'Good'},
    {
      'min': 51,
      'max': 100,
      'color': const Color(0xFF92D050),
      'label': 'Satisfactory',
    },
    {
      'min': 101,
      'max': 200,
      'color': const Color(0xFFFFFF00),
      'label': 'Moderate',
    },
    {'min': 201, 'max': 300, 'color': const Color(0xFFFF7E00), 'label': 'Poor'},
    {
      'min': 301,
      'max': 400,
      'color': const Color(0xFFFF0000),
      'label': 'Very Poor',
    },
    {
      'min': 401,
      'max': 500,
      'color': const Color(0xFF990000),
      'label': 'Severe',
    },
  ];
}

class _ScoreHelper {
  static Color getColor(double score) {
    if (score >= 80) return Colors.green[600]!;
    if (score >= 60) return Colors.lightGreen[600]!;
    if (score >= 40) return Colors.orange[600]!;
    if (score >= 20) return Colors.deepOrange[600]!;
    return Colors.red[600]!;
  }

  static String getLabel(double score) {
    if (score >= 80) return 'Excellent';
    if (score >= 60) return 'Good';
    if (score >= 40) return 'Fair';
    if (score >= 20) return 'Poor';
    return 'Very Poor';
  }
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
  static String getName(String code) {
    const names = {
      'pm25': 'PM2.5',
      'pm10': 'PM10',
      'o3': 'O₃',
      'no2': 'NO₂',
      'so2': 'SO₂',
      'co': 'CO',
    };
    return names[code.toLowerCase()] ?? code.toUpperCase();
  }

  static String getDescription(String code) {
    const descriptions = {
      'pm25': 'Fine particles',
      'pm10': 'Coarse particles',
      'o3': 'Ozone',
      'no2': 'Nitrogen Dioxide',
      'so2': 'Sulfur Dioxide',
      'co': 'Carbon Monoxide',
    };
    return descriptions[code.toLowerCase()] ?? 'Air pollutant';
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

class _EnvironmentalAnalyzer {
  final AirQualityData airQualityData;
  final WeatherData? weatherData;
  final List<Population> applicablePopulations;

  late final double airScore;
  late final double weatherScore;
  late final double healthScore;
  late final double overallScore;
  late final List<String> alerts;

  _EnvironmentalAnalyzer({
    required this.airQualityData,
    required this.weatherData,
    required this.applicablePopulations,
  }) {
    airScore = _calculateAirScore();
    weatherScore = _calculateWeatherScore();
    healthScore = _calculateHealthScore();
    overallScore = (airScore + weatherScore + healthScore) / 3;
    alerts = _generateAlerts();
  }

  double _calculateAirScore() {
    final aqi = airQualityData.aqi;
    if (aqi <= 50) return 100.0;
    if (aqi <= 100) return 80.0;
    if (aqi <= 200) return 60.0;
    if (aqi <= 300) return 40.0;
    if (aqi <= 400) return 20.0;
    return 10.0;
  }

  double _calculateWeatherScore() {
    if (weatherData == null) return 50.0;

    double score = 100.0;

    if (weatherData!.temperature < 10 || weatherData!.temperature > 35) {
      score -= 20;
    } else if (weatherData!.temperature < 15 || weatherData!.temperature > 30) {
      score -= 10;
    }

    if (weatherData!.humidity < 30 || weatherData!.humidity > 70) {
      score -= 15;
    }

    if (weatherData!.windSpeed > 10) score += 5;
    if (weatherData!.uvIndex > 8) score -= 10;

    return score.clamp(0, 100);
  }

  double _calculateHealthScore() {
    return 100 - airScore;
  }

  List<String> _generateAlerts() {
    final alerts = <String>[];
    final aqi = airQualityData.aqi;

    if (aqi > 400) {
      alerts.add('Severe air quality - avoid all outdoor activities');
    } else if (aqi > 300) {
      alerts.add('Very poor air quality - minimize outdoor exposure');
    } else if (aqi > 200) {
      alerts.add('Poor air quality - limit outdoor activities');
    } else if (aqi > 100 && _hasSensitivePopulations()) {
      alerts.add('Moderate - sensitive groups reduce outdoor exertion');
    }

    if (weatherData != null) {
      if (weatherData!.uvIndex > 8) {
        alerts.add('High UV index - use sun protection');
      }
      if (weatherData!.temperature > 35) {
        alerts.add('Extreme heat - stay hydrated');
      }
    }

    return alerts;
  }

  bool _hasSensitivePopulations() {
    return applicablePopulations.any(
      (p) =>
          p == Population.pregnantWomen ||
          p == Population.lungDiseasePopulation ||
          p == Population.heartDiseasePopulation ||
          p == Population.children,
    );
  }
}

// ============================================================================
// CUSTOM PAINTERS
// ============================================================================

class EnhancedLineChartPainter extends CustomPainter {
  final List<MapEntry<DateTime, int>> data;
  final int maxValue;
  final int currentAqi;

  EnhancedLineChartPainter({
    required this.data,
    required this.maxValue,
    required this.currentAqi,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    // Draw background zones
    _drawAQIZones(canvas, size);

    // Draw grid
    _drawGrid(canvas, size);

    // Draw line and area
    _drawLineAndArea(canvas, size);

    // Draw points
    _drawPoints(canvas, size);
  }

  void _drawAQIZones(Canvas canvas, Size size) {
    final zones = [
      {'max': 50, 'color': const Color(0xFF00E400)},
      {'max': 100, 'color': const Color(0xFF92D050)},
      {'max': 200, 'color': const Color(0xFFFFFF00)},
      {'max': 300, 'color': const Color(0xFFFF7E00)},
      {'max': 400, 'color': const Color(0xFFFF0000)},
      {'max': 500, 'color': const Color(0xFF990000)},
    ];

    double prevY = size.height;
    for (var zone in zones) {
      final normalizedValue = (zone['max'] as int) / maxValue;
      final y = size.height - (size.height * normalizedValue);

      final paint =
          Paint()
            ..color = (zone['color'] as Color).withOpacity(0.05)
            ..style = PaintingStyle.fill;

      canvas.drawRect(Rect.fromLTRB(0, y, size.width, prevY), paint);
      prevY = y;
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final gridPaint =
        Paint()
          ..color = Colors.grey[300]!
          ..strokeWidth = 0.5
          ..style = PaintingStyle.stroke;

    // Horizontal lines
    for (int i = 0; i <= 5; i++) {
      final y = (size.height / 5) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Vertical lines
    for (int i = 0; i < data.length; i++) {
      final x = (size.width / (data.length - 1)) * i;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        gridPaint..color = Colors.grey[200]!,
      );
    }
  }

  void _drawLineAndArea(Canvas canvas, Size size) {
    final points = _calculatePoints(size);

    // Draw fill area
    final fillPath =
        Path()
          ..moveTo(points.first.dx, size.height)
          ..lineTo(points.first.dx, points.first.dy);

    for (int i = 1; i < points.length; i++) {
      fillPath.lineTo(points[i].dx, points[i].dy);
    }

    fillPath
      ..lineTo(points.last.dx, size.height)
      ..close();

    final fillPaint =
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue[400]!.withOpacity(0.3),
              Colors.blue[200]!.withOpacity(0.1),
            ],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
          ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // Draw line
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }

    final linePaint =
        Paint()
          ..color = Colors.blue[600]!
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(linePath, linePaint);
  }

  void _drawPoints(Canvas canvas, Size size) {
    final points = _calculatePoints(size);

    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final isToday = i == points.length - 1;

      // Outer circle
      final outerPaint =
          Paint()
            ..color = isToday ? Colors.blue[600]! : Colors.blue[400]!
            ..style = PaintingStyle.fill;

      canvas.drawCircle(point, isToday ? 6 : 5, outerPaint);

      // Inner circle
      final innerPaint =
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.fill;

      canvas.drawCircle(point, isToday ? 3 : 2.5, innerPaint);

      // Draw value label for today
      if (isToday) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: '${data[i].value}',
            style: TextStyle(
              color: Colors.blue[600],
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(point.dx - textPainter.width / 2, point.dy - 24),
        );
      }
    }
  }

  List<Offset> _calculatePoints(Size size) {
    final points = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final x = (size.width / (data.length - 1)) * i;
      final normalizedValue = (data[i].value / maxValue).clamp(0.0, 1.0);
      final y = size.height - (size.height * normalizedValue);
      points.add(Offset(x, y));
    }
    return points;
  }

  @override
  bool shouldRepaint(EnhancedLineChartPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.currentAqi != currentAqi;
  }
}

class AQIGaugePainter extends CustomPainter {
  final double aqi;
  final Color color;

  AQIGaugePainter({required this.aqi, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeWidth = 6.0;

    // Background arc
    final backgroundPaint =
        Paint()
          ..color = Colors.grey[200]!
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14,
      3.14,
      false,
      backgroundPaint,
    );

    // Foreground arc
    final normalizedAqi = (aqi / 500).clamp(0.0, 1.0);
    final sweepAngle = 3.14 * normalizedAqi;

    final foregroundPaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14,
      sweepAngle,
      false,
      foregroundPaint,
    );
  }

  @override
  bool shouldRepaint(AQIGaugePainter oldDelegate) {
    return oldDelegate.aqi != aqi || oldDelegate.color != color;
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
        BoxedIcon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
