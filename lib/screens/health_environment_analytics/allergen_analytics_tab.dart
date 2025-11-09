import 'package:allergen/screens/health_environment_analytics/widgets/AirQualityWidget.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AllergenAnalyticsTab extends StatefulWidget {
  final AirQualityData airQualityData;

  const AllergenAnalyticsTab({Key? key, required this.airQualityData})
    : super(key: key);

  @override
  State<AllergenAnalyticsTab> createState() => _AllergenAnalyticsTabState();
}

class _AllergenAnalyticsTabState extends State<AllergenAnalyticsTab> {
  List<Map<String, dynamic>> _allergenHistory = [];
  bool _isLoadingHistory = true;
  String _selectedTimeRange = '7';

  @override
  void initState() {
    super.initState();
    _loadAllergenHistory();
  }

  Future<void> _loadAllergenHistory() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final foodSnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('history')
              .orderBy('timestamp', descending: true)
              .limit(100)
              .get();

      List<Map<String, dynamic>> history = [];

      for (var doc in foodSnapshot.docs) {
        final data = doc.data();
        final timestamp = data['timestamp'] as Timestamp?;
        final allergens = data['allergens'] as List<dynamic>? ?? [];

        if (timestamp != null && allergens.isNotEmpty) {
          for (var allergen in allergens) {
            if (allergen is Map<String, dynamic> &&
                allergen['isUserAllergen'] == true) {
              history.add({
                'allergenName': allergen['name'] ?? 'Unknown',
                'riskLevel': allergen['riskLevel'] ?? 'moderate',
                'dishName': data['dishName'] ?? 'Unknown Dish',
                'timestamp': timestamp.toDate(),
                'symptoms': List<String>.from(allergen['symptoms'] ?? []),
              });
            }
          }
        }
      }

      setState(() {
        _allergenHistory = history;
        _isLoadingHistory = false;
      });
    } catch (e) {
      setState(() => _isLoadingHistory = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingHistory) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
        ),
      );
    }

    if (_allergenHistory.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.analytics_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No Allergen Data Yet',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Start scanning food items to track your allergen exposure patterns.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildQuickStatsSection(),
          const SizedBox(height: 16),
          _buildTimeRangeSelector(),
          const SizedBox(height: 16),
          _buildExposureTrendChart(),
          const SizedBox(height: 16),
          _buildAllergenBreakdown(),
          const SizedBox(height: 16),
          _buildRiskAnalysis(),
          const SizedBox(height: 16),
          if (_hasSymptomData()) _buildSymptomTracker(),
          if (_hasSymptomData()) const SizedBox(height: 16),
          _buildCommonSourcesSection(),
          const SizedBox(height: 16),
          _buildRecentExposures(),
          const SizedBox(height: 16),
          _buildInsightsAndTips(),
        ],
      ),
    );
  }

  Widget _buildQuickStatsSection() {
    final stats = _calculateStats();

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.fastfood,
            value: '${stats['total']}',
            label: 'Total',
            color: Colors.blue[600]!,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.category,
            value: '${stats['unique']}',
            label: 'Unique',
            color: Colors.orange[600]!,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.trending_up,
            value: stats['average'],
            label: 'Daily Avg',
            color: Colors.green[600]!,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.warning,
            value: '${stats['severe']}',
            label: 'High Risk',
            color: Colors.red[600]!,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeRangeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(child: _buildTimeRangeButton('7', 'Week')),
          Expanded(child: _buildTimeRangeButton('30', 'Month')),
          Expanded(child: _buildTimeRangeButton('90', '3 Months')),
          Expanded(child: _buildTimeRangeButton('365', 'Year')),
        ],
      ),
    );
  }

  Widget _buildTimeRangeButton(String days, String label) {
    final isSelected = _selectedTimeRange == days;
    return GestureDetector(
      onTap: () => setState(() => _selectedTimeRange = days),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[600] : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildExposureTrendChart() {
    final trendData = _calculateTrendData();

    return _UniformCard(
      icon: Icons.show_chart,
      title: 'Exposure Trend',
      iconColor: Colors.blue[600]!,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendItem(color: Colors.red[600]!, label: 'Severe'),
              const SizedBox(width: 16),
              _LegendItem(color: Colors.orange[600]!, label: 'Moderate'),
              const SizedBox(width: 16),
              _LegendItem(color: Colors.amber[600]!, label: 'Mild'),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: CustomPaint(
              size: const Size(double.infinity, 200),
              painter: EnhancedTrendChartPainter(
                severeData: trendData['severe'] as List<int>,
                moderateData: trendData['moderate'] as List<int>,
                mildData: trendData['mild'] as List<int>,
                dates: trendData['dates'] as List<DateTime>,
                timeRange: int.parse(_selectedTimeRange),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllergenBreakdown() {
    final allergenData = _calculateAllergenFrequency();

    return _UniformCard(
      icon: Icons.pie_chart,
      title: 'Allergen Frequency',
      iconColor: Colors.purple[600]!,
      child: Column(
        children:
            allergenData.entries.take(8).map((entry) {
              final percentage = entry.value['percentage'] as double;
              final count = entry.value['count'] as int;
              final color = entry.value['color'] as Color;

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
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
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  entry.key,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '$count× (${percentage.toStringAsFixed(0)}%)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percentage / 100,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildRiskAnalysis() {
    final riskData = _calculateRiskDistribution();

    return _UniformCard(
      icon: Icons.analytics_outlined,
      title: 'Risk Distribution',
      iconColor: Colors.red[600]!,
      child: Column(
        children: [
          _RiskBar(
            label: 'Severe Risk',
            count: riskData['severe']!['count'] as int,
            percentage: riskData['severe']!['percentage'] as double,
            color: Colors.red[600]!,
            icon: Icons.error,
          ),
          const SizedBox(height: 14),
          _RiskBar(
            label: 'Moderate Risk',
            count: riskData['moderate']!['count'] as int,
            percentage: riskData['moderate']!['percentage'] as double,
            color: Colors.orange[600]!,
            icon: Icons.warning,
          ),
          const SizedBox(height: 14),
          _RiskBar(
            label: 'Mild Risk',
            count: riskData['mild']!['count'] as int,
            percentage: riskData['mild']!['percentage'] as double,
            color: Colors.amber[600]!,
            icon: Icons.info,
          ),
        ],
      ),
    );
  }

  Widget _buildSymptomTracker() {
    final symptomData = _calculateSymptomFrequency();
    if (symptomData.isEmpty) return const SizedBox.shrink();

    return _UniformCard(
      icon: Icons.medical_services,
      title: 'Common Symptoms',
      iconColor: Colors.red[600]!,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children:
            symptomData.entries.take(10).map((entry) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red[200]!, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.key,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.red[700],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${entry.value}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[900],
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

  Widget _buildCommonSourcesSection() {
    final sourcesData = _calculateCommonSources();

    return _UniformCard(
      icon: Icons.restaurant,
      title: 'Common Food Sources',
      iconColor: Colors.orange[600]!,
      child: Column(
        children:
            sourcesData.entries.take(3).map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children:
                          (entry.value as List<String>).take(5).map((source) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.orange[200]!),
                              ),
                              child: Text(
                                source,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.orange[900],
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                  ],
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildRecentExposures() {
    final recentExposures = _allergenHistory.take(5).toList();

    return _UniformCard(
      icon: Icons.history,
      title: 'Recent Exposures',
      iconColor: Colors.indigo[600]!,
      child: Column(
        children:
            recentExposures.map((exposure) {
              final timestamp = exposure['timestamp'] as DateTime;
              final timeAgo = _getTimeAgo(timestamp);
              final riskColor = _getRiskColor(exposure['riskLevel'] as String);

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 44,
                      decoration: BoxDecoration(
                        color: riskColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            exposure['allergenName'] as String,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            exposure['dishName'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        timeAgo,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
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

  Widget _buildInsightsAndTips() {
    final insights = _generateInsights();

    return _UniformCard(
      icon: Icons.lightbulb_outline,
      title: 'Insights & Tips',
      iconColor: Colors.green[600]!,
      child: Column(
        children: [
          ...insights.map((insight) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: (insight['color'] as Color).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (insight['color'] as Color).withOpacity(0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    insight['icon'] as IconData,
                    color: insight['color'] as Color,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          insight['title'] as String,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: insight['color'] as Color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          insight['message'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.tips_and_updates,
                      size: 18,
                      color: Colors.blue[700],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Safety Tips',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...[
                  'Always carry emergency medication',
                  'Inform restaurant staff about allergens',
                  'Read labels carefully every time',
                  'Keep a food diary to track reactions',
                ].map((tip) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 14,
                          color: Colors.blue[600],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tip,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[900],
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  bool _hasSymptomData() {
    return _calculateSymptomFrequency().isNotEmpty;
  }

  Map<String, dynamic> _calculateStats() {
    final days = int.parse(_selectedTimeRange);
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    final filtered =
        _allergenHistory
            .where((e) => (e['timestamp'] as DateTime).isAfter(cutoffDate))
            .toList();

    final total = filtered.length;
    final unique =
        filtered.map((e) => e['allergenName'] as String).toSet().length;
    final average = days > 0 ? (total / days).toStringAsFixed(1) : '0';
    final severe =
        filtered
            .where((e) => (e['riskLevel'] as String).toLowerCase() == 'severe')
            .length;

    return {
      'total': total,
      'unique': unique,
      'average': average,
      'severe': severe,
    };
  }

  Map<String, dynamic> _calculateTrendData() {
    final days = int.parse(_selectedTimeRange);
    final now = DateTime.now();

    List<DateTime> dateBuckets;
    int bucketCount;

    if (days <= 7) {
      bucketCount = 7;
      dateBuckets = List.generate(
        7,
        (i) => now.subtract(Duration(days: 6 - i)),
      );
    } else if (days <= 30) {
      bucketCount = 30;
      dateBuckets = List.generate(
        30,
        (i) => now.subtract(Duration(days: 29 - i)),
      );
    } else {
      bucketCount = (days / 7).ceil();
      dateBuckets = List.generate(
        bucketCount,
        (i) => now.subtract(Duration(days: (bucketCount - 1 - i) * 7)),
      );
    }

    Map<String, List<int>> riskData = {
      'severe': List.filled(bucketCount, 0),
      'moderate': List.filled(bucketCount, 0),
      'mild': List.filled(bucketCount, 0),
    };

    for (var exposure in _allergenHistory) {
      final timestamp = exposure['timestamp'] as DateTime;
      final risk = (exposure['riskLevel'] as String).toLowerCase();

      for (int i = 0; i < bucketCount; i++) {
        final bucket = dateBuckets[i];
        bool matches = false;

        if (days <= 30) {
          matches =
              timestamp.year == bucket.year &&
              timestamp.month == bucket.month &&
              timestamp.day == bucket.day;
        } else {
          final nextBucket =
              i < bucketCount - 1
                  ? dateBuckets[i + 1]
                  : now.add(const Duration(days: 7));
          matches =
              timestamp.isAfter(bucket.subtract(const Duration(seconds: 1))) &&
              timestamp.isBefore(nextBucket);
        }

        if (matches) {
          riskData[risk]![i]++;
          break;
        }
      }
    }

    return {
      'severe': riskData['severe']!,
      'moderate': riskData['moderate']!,
      'mild': riskData['mild']!,
      'dates': dateBuckets,
    };
  }

  Map<String, Map<String, dynamic>> _calculateAllergenFrequency() {
    final days = int.parse(_selectedTimeRange);
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    final filtered =
        _allergenHistory
            .where((e) => (e['timestamp'] as DateTime).isAfter(cutoffDate))
            .toList();

    final Map<String, int> counts = {};
    final Map<String, String> risks = {};

    for (var entry in filtered) {
      final name = entry['allergenName'] as String;
      counts[name] = (counts[name] ?? 0) + 1;
      risks[name] = entry['riskLevel'] as String;
    }

    final sorted =
        counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = filtered.length;

    return Map.fromEntries(
      sorted.map(
        (e) => MapEntry(e.key, {
          'count': e.value,
          'percentage': (e.value / total * 100),
          'color': _getRiskColor(risks[e.key]!),
        }),
      ),
    );
  }

  Map<String, Map<String, dynamic>> _calculateRiskDistribution() {
    final days = int.parse(_selectedTimeRange);
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    final filtered =
        _allergenHistory
            .where((e) => (e['timestamp'] as DateTime).isAfter(cutoffDate))
            .toList();

    final Map<String, int> counts = {'severe': 0, 'moderate': 0, 'mild': 0};

    for (var entry in filtered) {
      final risk = (entry['riskLevel'] as String).toLowerCase();
      counts[risk] = (counts[risk] ?? 0) + 1;
    }

    final total = filtered.length;

    return {
      'severe': {
        'count': counts['severe']!,
        'percentage': total > 0 ? (counts['severe']! / total * 100) : 0.0,
      },
      'moderate': {
        'count': counts['moderate']!,
        'percentage': total > 0 ? (counts['moderate']! / total * 100) : 0.0,
      },
      'mild': {
        'count': counts['mild']!,
        'percentage': total > 0 ? (counts['mild']! / total * 100) : 0.0,
      },
    };
  }

  Map<String, int> _calculateSymptomFrequency() {
    final days = int.parse(_selectedTimeRange);
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    final filtered =
        _allergenHistory
            .where((e) => (e['timestamp'] as DateTime).isAfter(cutoffDate))
            .toList();

    final Map<String, int> symptoms = {};

    for (var entry in filtered) {
      final symptomList = entry['symptoms'] as List<String>;
      for (var symptom in symptomList) {
        symptoms[symptom] = (symptoms[symptom] ?? 0) + 1;
      }
    }

    final sorted =
        symptoms.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Map.fromEntries(sorted);
  }

  Map<String, List<String>> _calculateCommonSources() {
    final days = int.parse(_selectedTimeRange);
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    final filtered =
        _allergenHistory
            .where((e) => (e['timestamp'] as DateTime).isAfter(cutoffDate))
            .toList();

    final Map<String, Set<String>> sources = {};
    final Map<String, int> counts = {};

    for (var entry in filtered) {
      final allergen = entry['allergenName'] as String;
      final dish = entry['dishName'] as String;

      sources.putIfAbsent(allergen, () => {});
      sources[allergen]!.add(dish);
      counts[allergen] = (counts[allergen] ?? 0) + 1;
    }

    final sorted =
        counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Map.fromEntries(
      sorted.map((e) => MapEntry(e.key, sources[e.key]!.toList())),
    );
  }

  List<Map<String, dynamic>> _generateInsights() {
    final days = int.parse(_selectedTimeRange);
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    final filtered =
        _allergenHistory
            .where((e) => (e['timestamp'] as DateTime).isAfter(cutoffDate))
            .toList();

    final insights = <Map<String, dynamic>>[];

    // Most frequent allergen
    final counts = <String, int>{};
    for (var entry in filtered) {
      final name = entry['allergenName'] as String;
      counts[name] = (counts[name] ?? 0) + 1;
    }

    if (counts.isNotEmpty) {
      final top = counts.entries.reduce((a, b) => a.value > b.value ? a : b);
      insights.add({
        'icon': Icons.trending_up,
        'color': Colors.orange[600],
        'title': 'Most Frequent',
        'message':
            '${top.key} appears most often (${top.value}×). Consider alternatives.',
      });
    }

    // Severe risk warning
    final severe =
        filtered
            .where((e) => (e['riskLevel'] as String).toLowerCase() == 'severe')
            .length;

    if (severe > 0) {
      insights.add({
        'icon': Icons.warning_amber,
        'color': Colors.red[600],
        'title': 'High-Risk Alert',
        'message': '$severe severe exposures detected. Exercise extra caution.',
      });
    }

    // General advice
    if (filtered.length >= 5) {
      insights.add({
        'icon': Icons.lightbulb,
        'color': Colors.blue[600],
        'title': 'Stay Vigilant',
        'message':
            'Always review ingredients and inform restaurants about allergens.',
      });
    }

    return insights;
  }

  Color _getRiskColor(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'severe':
        return Colors.red[600]!;
      case 'moderate':
        return Colors.orange[600]!;
      case 'mild':
        return Colors.amber[600]!;
      default:
        return Colors.grey[600]!;
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

// ============================================================================
// REUSABLE COMPONENTS
// ============================================================================

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _UniformCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color iconColor;
  final Widget child;

  const _UniformCard({
    required this.icon,
    required this.title,
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
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
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

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _RiskBar extends StatelessWidget {
  final String label;
  final int count;
  final double percentage;
  final Color color;
  final IconData icon;

  const _RiskBar({
    required this.label,
    required this.count,
    required this.percentage,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            Text(
              '$count (${percentage.toStringAsFixed(0)}%)',
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
          child: LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// ENHANCED CHART PAINTER
// ============================================================================

class EnhancedTrendChartPainter extends CustomPainter {
  final List<int> severeData;
  final List<int> moderateData;
  final List<int> mildData;
  final List<DateTime> dates;
  final int timeRange;

  EnhancedTrendChartPainter({
    required this.severeData,
    required this.moderateData,
    required this.mildData,
    required this.dates,
    required this.timeRange,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final chartHeight = size.height - 40;
    final chartWidth = size.width - 20;
    final dataPoints = severeData.length;

    if (dataPoints < 2) return;

    final segmentWidth = chartWidth / (dataPoints - 1);

    // Find max value
    int maxValue = 0;
    for (int i = 0; i < dataPoints; i++) {
      int total = severeData[i] + moderateData[i] + mildData[i];
      if (total > maxValue) maxValue = total;
    }
    if (maxValue == 0) maxValue = 1;

    // Draw background zones
    _drawBackgroundZones(canvas, Size(chartWidth, chartHeight), maxValue);

    // Draw grid
    _drawGrid(canvas, Size(chartWidth, chartHeight));

    // Draw lines and areas
    _drawLineWithArea(
      canvas,
      Size(chartWidth, chartHeight),
      mildData,
      Colors.amber[600]!,
      maxValue,
      segmentWidth,
    );
    _drawLineWithArea(
      canvas,
      Size(chartWidth, chartHeight),
      moderateData,
      Colors.orange[600]!,
      maxValue,
      segmentWidth,
    );
    _drawLineWithArea(
      canvas,
      Size(chartWidth, chartHeight),
      severeData,
      Colors.red[600]!,
      maxValue,
      segmentWidth,
    );

    // Draw date labels
    _drawDateLabels(canvas, Size(chartWidth, chartHeight), segmentWidth);

    // Draw value labels
    _drawValueLabels(canvas, chartHeight, maxValue);
  }

  void _drawBackgroundZones(Canvas canvas, Size size, int maxValue) {
    final zones = [
      {'threshold': maxValue * 0.7, 'color': Colors.red[50]!},
      {'threshold': maxValue * 0.4, 'color': Colors.orange[50]!},
      {'threshold': 0.0, 'color': Colors.green[50]!},
    ];

    double prevY = 0;
    for (var zone in zones) {
      final y =
          size.height -
          (size.height * (zone['threshold'] as double) / maxValue);
      canvas.drawRect(
        Rect.fromLTRB(0, prevY, size.width, y),
        Paint()..color = (zone['color'] as Color).withOpacity(0.3),
      );
      prevY = y;
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final gridPaint =
        Paint()
          ..color = Colors.grey[300]!
          ..strokeWidth = 0.5;

    // Horizontal lines
    for (int i = 0; i <= 5; i++) {
      final y = (size.height / 5) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  void _drawLineWithArea(
    Canvas canvas,
    Size size,
    List<int> data,
    Color color,
    int maxValue,
    double segmentWidth,
  ) {
    final linePaint =
        Paint()
          ..color = color
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < data.length; i++) {
      final x = segmentWidth * i;
      final normalizedValue = data[i] / maxValue;
      final y = size.height - (normalizedValue * size.height);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }

      // Draw point
      canvas.drawCircle(Offset(x, y), 3.5, Paint()..color = color);
      canvas.drawCircle(Offset(x, y), 2, Paint()..color = Colors.white);
    }

    // Complete fill path
    fillPath.lineTo(segmentWidth * (data.length - 1), size.height);
    fillPath.close();

    // Draw fill
    canvas.drawPath(
      fillPath,
      Paint()
        ..color = color.withOpacity(0.15)
        ..style = PaintingStyle.fill,
    );

    // Draw line
    canvas.drawPath(path, linePaint);
  }

  void _drawDateLabels(Canvas canvas, Size size, double segmentWidth) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    int labelInterval = 1;
    if (timeRange > 30) labelInterval = 7;
    if (timeRange > 90) labelInterval = 14;

    for (int i = 0; i < dates.length; i += labelInterval) {
      final x = segmentWidth * i;
      final date = dates[i];
      String dateStr;

      if (timeRange <= 7) {
        dateStr = _getDayName(date.weekday);
      } else if (timeRange <= 30) {
        dateStr = '${date.day}';
      } else {
        dateStr = '${date.day}/${date.month}';
      }

      textPainter.text = TextSpan(
        text: dateStr,
        style: TextStyle(
          fontSize: 10,
          color: Colors.grey[600],
          fontWeight: FontWeight.w500,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, size.height + 10),
      );
    }
  }

  void _drawValueLabels(Canvas canvas, double chartHeight, int maxValue) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.right,
    );

    for (int i = 0; i <= 2; i++) {
      final value = (maxValue / 2 * i).toInt();
      final y = chartHeight - (chartHeight / 2 * i);

      textPainter.text = TextSpan(
        text: '$value',
        style: TextStyle(
          fontSize: 10,
          color: Colors.grey[600],
          fontWeight: FontWeight.w500,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(-textPainter.width - 8, y - 6));
    }
  }

  String _getDayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  @override
  bool shouldRepaint(EnhancedTrendChartPainter oldDelegate) => true;
}
