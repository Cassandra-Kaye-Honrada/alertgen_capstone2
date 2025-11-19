import 'package:allergen/screens/health_environment_analytics/air_quality_tab.dart';
import 'package:allergen/screens/health_environment_analytics/widgets/AirQualityWidget.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'models/air_quality_models.dart';

class AllergenAnalyticsTab extends StatefulWidget {
  const AllergenAnalyticsTab({Key? key}) : super(key: key);

  @override
  State<AllergenAnalyticsTab> createState() => _AllergenAnalyticsTabState();
}

class _AllergenAnalyticsTabState extends State<AllergenAnalyticsTab> {
  List<Map<String, dynamic>> _allergenHistory = [];
  bool _isLoadingHistory = true;
  String _selectedTimeRange = 'week'; // 'week' or 'month'
  DateTime _selectedMonth = DateTime.now(); // For month navigation
  bool _mounted = true;

  @override
  void initState() {
    super.initState();
    _loadAllergenHistory();
  }

  @override
  void dispose() {
    _mounted = false;
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (_mounted && mounted) {
      setState(fn);
    }
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

      _safeSetState(() {
        _allergenHistory = history;
        _isLoadingHistory = false;
      });
    } catch (e) {
      _safeSetState(() => _isLoadingHistory = false);
    }
  }

  void _changeMonth(int delta) {
    _safeSetState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + delta,
        1,
      );
    });
  }

  bool _canGoToNextMonth() {
    final now = DateTime.now();
    final nextMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      1,
    );
    return nextMonth.isBefore(DateTime(now.year, now.month + 1, 1));
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
          if (_selectedTimeRange == 'month') ...[
            const SizedBox(height: 12),
            _buildMonthNavigator(),
          ],
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
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildQuickStatsSection() {
    final stats = _calculateStats();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header with subtle styling
        Padding(
          padding: const EdgeInsets.only(bottom: 12, left: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.dashboard_outlined,
                  size: 18,
                  color: Colors.blue[700],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Quick Overview',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ),

        // Stats Grid
        Row(
          children: [
            Expanded(
              child: _EnhancedStatCard(
                icon: Icons.fastfood_rounded,
                value: '${stats['total']}',
                label: 'Total Exposures',
                color: Colors.blue[600]!,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.blue[400]!, Colors.blue[700]!],
                ),
                trend: stats['trend'] as String?,
                trendUp: stats['trendUp'] as bool?,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _EnhancedStatCard(
                icon: Icons.category_rounded,
                value: '${stats['unique']}',
                label: 'Unique Types',
                color: Colors.orange[600]!,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.orange[400]!, Colors.orange[700]!],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _EnhancedStatCard(
                icon: Icons.trending_up_rounded,
                value: stats['average'],
                label: 'Daily Average',
                color: Colors.green[600]!,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.green[400]!, Colors.green[700]!],
                ),
                subtitle: 'per day',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _EnhancedStatCard(
                icon: Icons.warning_rounded,
                value: '${stats['severe']}',
                label: 'High Risk',
                color: Colors.red[600]!,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.red[400]!, Colors.red[700]!],
                ),
                isPulse: (stats['severe'] as int) > 0,
              ),
            ),
          ],
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
          Expanded(child: _buildTimeRangeButton('week', 'Week')),
          Expanded(child: _buildTimeRangeButton('month', 'Month')),
        ],
      ),
    );
  }

  Widget _buildTimeRangeButton(String value, String label) {
    final isSelected = _selectedTimeRange == value;
    return GestureDetector(
      onTap:
          () => _safeSetState(() {
            _selectedTimeRange = value;
            if (value == 'month') {
              _selectedMonth = DateTime.now();
            }
          }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFF0B8FAC) : Colors.transparent,
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

  Widget _buildMonthNavigator() {
    final monthName = _getMonthName(_selectedMonth.month);
    final year = _selectedMonth.year;
    final canGoNext = _canGoToNextMonth();

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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left, color: Color(0xFF0B8FAC)),
            onPressed: () => _changeMonth(-1),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          Text(
            '$monthName $year',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.chevron_right,
              color: canGoNext ? Color(0xFF0B8FAC) : Colors.grey[300],
            ),
            onPressed: canGoNext ? () => _changeMonth(1) : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildExposureTrendChart() {
    final trendData = _calculateTrendData();

    return _UniformCard(
      icon: Icons.show_chart,
      title: 'Exposure Trend',
      iconColor: Color(0xFF0B8FAC),
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
                isWeekView: _selectedTimeRange == 'week',
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
        crossAxisAlignment: CrossAxisAlignment.start, // Add this line
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
    DateTime startDate;
    DateTime endDate = DateTime.now();

    if (_selectedTimeRange == 'week') {
      startDate = endDate.subtract(const Duration(days: 7));
    } else {
      startDate = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      endDate = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
        0,
        23,
        59,
        59,
      );
    }

    final filtered =
        _allergenHistory.where((e) {
          final timestamp = e['timestamp'] as DateTime;
          return timestamp.isAfter(startDate) && timestamp.isBefore(endDate);
        }).toList();

    final total = filtered.length;
    final unique =
        filtered.map((e) => e['allergenName'] as String).toSet().length;
    final days = _selectedTimeRange == 'week' ? 7 : endDate.day;
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
    DateTime startDate;
    DateTime endDate = DateTime.now();
    List<DateTime> dateBuckets;

    if (_selectedTimeRange == 'week') {
      startDate = endDate.subtract(const Duration(days: 6));
      dateBuckets = List.generate(7, (i) => startDate.add(Duration(days: i)));
    } else {
      startDate = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      endDate = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
      final daysInMonth = endDate.day;
      dateBuckets = List.generate(
        daysInMonth,
        (i) => DateTime(_selectedMonth.year, _selectedMonth.month, i + 1),
      );
    }

    final bucketCount = dateBuckets.length;
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
        if (timestamp.year == bucket.year &&
            timestamp.month == bucket.month &&
            timestamp.day == bucket.day) {
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
    DateTime startDate;
    DateTime endDate = DateTime.now();

    if (_selectedTimeRange == 'week') {
      startDate = endDate.subtract(const Duration(days: 7));
    } else {
      startDate = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      endDate = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
        0,
        23,
        59,
        59,
      );
    }

    final filtered =
        _allergenHistory.where((e) {
          final timestamp = e['timestamp'] as DateTime;
          return timestamp.isAfter(startDate) && timestamp.isBefore(endDate);
        }).toList();

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
          'percentage': total > 0 ? (e.value / total * 100) : 0.0,
          'color': _getRiskColor(risks[e.key]!),
        }),
      ),
    );
  }

  Map<String, Map<String, dynamic>> _calculateRiskDistribution() {
    DateTime startDate;
    DateTime endDate = DateTime.now();

    if (_selectedTimeRange == 'week') {
      startDate = endDate.subtract(const Duration(days: 7));
    } else {
      startDate = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      endDate = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
        0,
        23,
        59,
        59,
      );
    }

    final filtered =
        _allergenHistory.where((e) {
          final timestamp = e['timestamp'] as DateTime;
          return timestamp.isAfter(startDate) && timestamp.isBefore(endDate);
        }).toList();

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
    DateTime startDate;
    DateTime endDate = DateTime.now();

    if (_selectedTimeRange == 'week') {
      startDate = endDate.subtract(const Duration(days: 7));
    } else {
      startDate = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      endDate = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
        0,
        23,
        59,
        59,
      );
    }

    final filtered =
        _allergenHistory.where((e) {
          final timestamp = e['timestamp'] as DateTime;
          return timestamp.isAfter(startDate) && timestamp.isBefore(endDate);
        }).toList();

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
    DateTime startDate;
    DateTime endDate = DateTime.now();

    if (_selectedTimeRange == 'week') {
      startDate = endDate.subtract(const Duration(days: 7));
    } else {
      startDate = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      endDate = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
        0,
        23,
        59,
        59,
      );
    }

    final filtered =
        _allergenHistory.where((e) {
          final timestamp = e['timestamp'] as DateTime;
          return timestamp.isAfter(startDate) && timestamp.isBefore(endDate);
        }).toList();

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
    DateTime startDate;
    DateTime endDate = DateTime.now();

    if (_selectedTimeRange == 'week') {
      startDate = endDate.subtract(const Duration(days: 7));
    } else {
      startDate = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      endDate = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
        0,
        23,
        59,
        59,
      );
    }

    final filtered =
        _allergenHistory.where((e) {
          final timestamp = e['timestamp'] as DateTime;
          return timestamp.isAfter(startDate) && timestamp.isBefore(endDate);
        }).toList();

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

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
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
// ENHANCED BAR CHART PAINTER WITH PREMIUM CALENDAR
// ============================================================================

class EnhancedTrendChartPainter extends CustomPainter {
  final List<int> severeData;
  final List<int> moderateData;
  final List<int> mildData;
  final List<DateTime> dates;
  final bool isWeekView;

  EnhancedTrendChartPainter({
    required this.severeData,
    required this.moderateData,
    required this.mildData,
    required this.dates,
    required this.isWeekView,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final chartHeight = size.height - 60; // Increased space for enhanced labels
    final chartWidth = size.width - 20;
    final dataPoints = severeData.length;

    if (dataPoints < 1) return;

    // Calculate bar dimensions
    final totalPadding = chartWidth * 0.2;
    final availableWidth = chartWidth - totalPadding;
    final barWidth = availableWidth / dataPoints;
    final spacing = totalPadding / (dataPoints + 1);

    // Find max value for scaling
    int maxValue = 0;
    for (int i = 0; i < dataPoints; i++) {
      int total = severeData[i] + moderateData[i] + mildData[i];
      if (total > maxValue) maxValue = total;
    }
    if (maxValue == 0) maxValue = 1;

    // Draw background zones with gradient
    _drawBackgroundZones(canvas, Size(chartWidth, chartHeight), maxValue);

    // Draw grid with enhanced styling
    _drawGrid(canvas, Size(chartWidth, chartHeight), maxValue);

    // Draw stacked bars with animations
    for (int i = 0; i < dataPoints; i++) {
      final x = spacing + (i * (barWidth + spacing));
      final date = dates[i];
      final isToday = _isToday(date);
      final hasData = (severeData[i] + moderateData[i] + mildData[i]) > 0;

      _drawStackedBar(
        canvas,
        x,
        barWidth,
        chartHeight,
        severeData[i],
        moderateData[i],
        mildData[i],
        maxValue,
        isToday,
        hasData,
      );
    }

    // Draw enhanced date labels
    _drawDateLabels(canvas, Size(chartWidth, chartHeight), barWidth, spacing);

    // Draw value labels with better formatting
    _drawValueLabels(canvas, chartHeight, maxValue);

    // Draw max value indicator
    _drawMaxValueIndicator(canvas, chartWidth, maxValue);
  }

  void _drawBackgroundZones(Canvas canvas, Size size, int maxValue) {
    final zones = [
      {
        'start': 0.7,
        'end': 1.0,
        'color': Colors.red[50]!,
        'label': 'High Risk',
      },
      {
        'start': 0.4,
        'end': 0.7,
        'color': Colors.orange[50]!,
        'label': 'Medium Risk',
      },
      {
        'start': 0.0,
        'end': 0.4,
        'color': Colors.green[50]!,
        'label': 'Low Risk',
      },
    ];

    for (var zone in zones) {
      final startY = size.height - (size.height * (zone['end'] as double));
      final endY = size.height - (size.height * (zone['start'] as double));

      // Gradient background
      final rect = Rect.fromLTRB(0, startY, size.width, endY);
      final gradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          (zone['color'] as Color).withOpacity(0.15),
          (zone['color'] as Color).withOpacity(0.05),
        ],
      );

      canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
    }
  }

  void _drawGrid(Canvas canvas, Size size, int maxValue) {
    final gridPaint =
        Paint()
          ..color = Colors.grey[300]!
          ..strokeWidth = 0.5;

    final dashedPaint =
        Paint()
          ..color = Colors.grey[400]!
          ..strokeWidth = 1;

    // Horizontal lines with labels
    for (int i = 0; i <= 4; i++) {
      final y = (size.height / 4) * i;

      // Dashed line for major gridlines
      if (i % 2 == 0) {
        _drawDashedLine(
          canvas,
          Offset(0, y),
          Offset(size.width, y),
          dashedPaint,
        );
      } else {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashWidth = 5;
    const dashSpace = 3;
    double distance = (end - start).distance;

    for (double i = 0; i < distance; i += dashWidth + dashSpace) {
      final startX = start.dx + (end.dx - start.dx) * i / distance;
      final startY = start.dy + (end.dy - start.dy) * i / distance;
      final endX = start.dx + (end.dx - start.dx) * (i + dashWidth) / distance;
      final endY = start.dy + (end.dy - start.dy) * (i + dashWidth) / distance;
      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);
    }
  }

  void _drawStackedBar(
    Canvas canvas,
    double x,
    double width,
    double chartHeight,
    int severe,
    int moderate,
    int mild,
    int maxValue,
    bool isToday,
    bool hasData,
  ) {
    final total = severe + moderate + mild;

    // Draw shadow for bars with data
    if (hasData) {
      final shadowRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x + 2, 2, width, chartHeight),
        const Radius.circular(6),
      );
      canvas.drawRRect(
        shadowRect,
        Paint()
          ..color = Colors.black.withOpacity(0.08)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    // Highlight today's bar with glow effect
    if (isToday && hasData) {
      final glowRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 2, 0, width + 4, chartHeight),
        const Radius.circular(8),
      );
      canvas.drawRRect(
        glowRect,
        Paint()
          ..color = Colors.blue[200]!.withOpacity(0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    if (total == 0) {
      // Draw empty state with dashed outline
      final emptyRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, chartHeight - 8, width, 8),
        const Radius.circular(4),
      );
      canvas.drawRRect(
        emptyRect,
        Paint()
          ..color = Colors.grey[200]!
          ..style = PaintingStyle.fill,
      );
      return;
    }

    double currentY = chartHeight;

    // Draw mild (bottom)
    if (mild > 0) {
      final height = (mild / maxValue) * chartHeight;
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, currentY - height, width, height),
        bottomLeft: const Radius.circular(6),
        bottomRight: const Radius.circular(6),
      );

      // Gradient fill
      final gradient = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [Colors.amber[600]!, Colors.amber[400]!],
      );
      canvas.drawRRect(
        rect,
        Paint()..shader = gradient.createShader(rect.outerRect),
      );

      // Border
      canvas.drawRRect(
        rect,
        Paint()
          ..color = Colors.amber[800]!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      currentY -= height;
    }

    // Draw moderate (middle)
    if (moderate > 0) {
      final height = (moderate / maxValue) * chartHeight;
      final hasTopCorners = severe == 0;
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, currentY - height, width, height),
        topLeft: hasTopCorners ? const Radius.circular(6) : Radius.zero,
        topRight: hasTopCorners ? const Radius.circular(6) : Radius.zero,
      );

      final gradient = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [Colors.orange[600]!, Colors.orange[400]!],
      );
      canvas.drawRRect(
        rect,
        Paint()..shader = gradient.createShader(rect.outerRect),
      );

      canvas.drawRRect(
        rect,
        Paint()
          ..color = Colors.orange[800]!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      currentY -= height;
    }

    // Draw severe (top)
    if (severe > 0) {
      final height = (severe / maxValue) * chartHeight;
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, currentY - height, width, height),
        topLeft: const Radius.circular(6),
        topRight: const Radius.circular(6),
      );

      final gradient = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [Colors.red[600]!, Colors.red[400]!],
      );
      canvas.drawRRect(
        rect,
        Paint()..shader = gradient.createShader(rect.outerRect),
      );

      canvas.drawRRect(
        rect,
        Paint()
          ..color = Colors.red[800]!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // Draw total count label with background
    if (total > 0 && chartHeight > 50) {
      final labelY = chartHeight - (total / maxValue) * chartHeight - 20;
      if (labelY > 0) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: '$total',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        );
        textPainter.layout();

        // Background bubble
        final bubbleRect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x + width / 2, labelY),
            width: textPainter.width + 12,
            height: textPainter.height + 6,
          ),
          const Radius.circular(10),
        );

        canvas.drawRRect(
          bubbleRect,
          Paint()..color = Colors.grey[800]!.withOpacity(0.85),
        );

        textPainter.paint(
          canvas,
          Offset(
            x + (width - textPainter.width) / 2,
            labelY - textPainter.height / 2,
          ),
        );
      }
    }
  }

  void _drawDateLabels(
    Canvas canvas,
    Size size,
    double barWidth,
    double spacing,
  ) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    if (isWeekView) {
      _drawWeekLabels(canvas, size, barWidth, spacing, textPainter);
    } else {
      _drawMonthLabels(canvas, size, barWidth, spacing, textPainter);
    }
  }

  void _drawWeekLabels(
    Canvas canvas,
    Size size,
    double barWidth,
    double spacing,
    TextPainter textPainter,
  ) {
    for (int i = 0; i < dates.length; i++) {
      final x = spacing + (i * (barWidth + spacing)) + (barWidth / 2);
      final date = dates[i];
      final isToday = _isToday(date);
      final isWeekend = date.weekday == 6 || date.weekday == 7;

      // Background for today
      if (isToday) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(x, size.height + 25),
              width: barWidth + 8,
              height: 42,
            ),
            const Radius.circular(8),
          ),
          Paint()..color = Colors.blue[50]!,
        );
      }

      // Day name
      textPainter.text = TextSpan(
        text: _getDayName(date.weekday),
        style: TextStyle(
          fontSize: 12,
          color:
              isToday
                  ? Colors.blue[700]
                  : isWeekend
                  ? Colors.orange[700]
                  : Colors.grey[700],
          fontWeight: isToday ? FontWeight.bold : FontWeight.w600,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, size.height + 8),
      );

      // Date number
      textPainter.text = TextSpan(
        text: '${date.day}',
        style: TextStyle(
          fontSize: 13,
          color: isToday ? Colors.blue[900] : Colors.grey[600],
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, size.height + 24),
      );

      // Today indicator dot
      if (isToday) {
        canvas.drawCircle(
          Offset(x, size.height + 42),
          4,
          Paint()..color = Colors.blue[600]!,
        );
      }
    }
  }

  void _drawMonthLabels(
    Canvas canvas,
    Size size,
    double barWidth,
    double spacing,
    TextPainter textPainter,
  ) {
    final totalDays = dates.length;

    // Smart labeling based on density
    int labelInterval;
    if (totalDays <= 10) {
      labelInterval = 1;
    } else if (totalDays <= 20) {
      labelInterval = 2;
    } else if (totalDays <= 25) {
      labelInterval = 3;
    } else {
      labelInterval = 4;
    }

    // Draw dates
    for (int i = 0; i < dates.length; i++) {
      final x = spacing + (i * (barWidth + spacing)) + (barWidth / 2);
      final date = dates[i];
      final isToday = _isToday(date);
      final isWeekend = date.weekday == 6 || date.weekday == 7;
      final isFirstOfMonth = date.day == 1;
      final isImportant = i % 5 == 0 || isFirstOfMonth || isToday;
      final shouldShowLabel =
          i % labelInterval == 0 || isToday || isFirstOfMonth;

      // Background highlight
      if (isToday) {
        canvas.drawCircle(
          Offset(x, size.height + 22),
          barWidth / 2 + 4,
          Paint()..color = Colors.blue[100]!,
        );
      }

      if (shouldShowLabel) {
        // Date number
        textPainter.text = TextSpan(
          text: '${date.day}',
          style: TextStyle(
            fontSize: isToday || isFirstOfMonth ? 12 : 10,
            color:
                isToday
                    ? Colors.blue[900]
                    : isWeekend
                    ? Colors.orange[700]
                    : isFirstOfMonth
                    ? Colors.purple[700]
                    : Colors.grey[700],
            fontWeight:
                isToday || isFirstOfMonth ? FontWeight.bold : FontWeight.w600,
          ),
        );
        textPainter.layout();

        final labelY = size.height + 14;
        textPainter.paint(canvas, Offset(x - textPainter.width / 2, labelY));

        // Special indicators
        if (isToday) {
          canvas.drawCircle(
            Offset(x, labelY - 6),
            5,
            Paint()..color = Colors.blue[600]!,
          );
          canvas.drawCircle(
            Offset(x, labelY - 6),
            3,
            Paint()..color = Colors.white,
          );
        } else if (isFirstOfMonth) {
          _drawStar(canvas, Offset(x, labelY - 5), 4, Colors.purple[600]!);
        } else if (isImportant && !shouldShowLabel) {
          canvas.drawCircle(
            Offset(x, labelY + 12),
            2,
            Paint()..color = Colors.grey[400]!,
          );
        }
      } else {
        // Subtle dot for unlabeled dates
        canvas.drawCircle(
          Offset(x, size.height + 22),
          1.5,
          Paint()..color = Colors.grey[300]!,
        );
      }

      // Week separators (Sundays)
      if (date.weekday == 7 && i > 0 && i < dates.length - 1) {
        final separatorX = x + (barWidth + spacing) / 2;
        _drawDashedLine(
          canvas,
          Offset(separatorX, 0),
          Offset(separatorX, size.height),
          Paint()
            ..color = Colors.grey[300]!
            ..strokeWidth = 1,
        );
      }
    }
  }

  void _drawValueLabels(Canvas canvas, double chartHeight, int maxValue) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.right,
    );

    for (int i = 0; i <= 4; i++) {
      final value = (maxValue / 4 * i).toInt();
      final y = chartHeight - (chartHeight / 4 * i);

      textPainter.text = TextSpan(
        text: '$value',
        style: TextStyle(
          fontSize: 11,
          color: Colors.grey[700],
          fontWeight: FontWeight.w600,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(-textPainter.width - 10, y - 6));
    }
  }

  void _drawMaxValueIndicator(Canvas canvas, double chartWidth, int maxValue) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Max: $maxValue',
        style: TextStyle(
          fontSize: 10,
          color: Colors.grey[600],
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(chartWidth - textPainter.width, -20));
  }

  void _drawStar(Canvas canvas, Offset center, double size, Color color) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;

    final path = Path();
    for (int i = 0; i < 5; i++) {
      final angle = (i * 4 * 3.14159) / 5 - 3.14159 / 2;
      final x = center.dx + size * (i % 2 == 0 ? 1 : 0.4) * _cos(angle);
      final y = center.dy + size * (i % 2 == 0 ? 1 : 0.4) * _sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  String _getDayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  double _cos(double x) {
    x = x % (2 * 3.14159);
    double result = 1;
    double term = 1;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((2 * i - 1) * (2 * i));
      result += term;
    }
    return result;
  }

  double _sin(double x) {
    x = x % (2 * 3.14159);
    double result = x;
    double term = x;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }

  @override
  bool shouldRepaint(EnhancedTrendChartPainter oldDelegate) => true;
}

// ============================================================================
// ENHANCED STAT CARD WITH ANIMATIONS
// ============================================================================

class _EnhancedStatCard extends StatefulWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final LinearGradient gradient;
  final String? subtitle;
  final String? trend;
  final bool? trendUp;
  final bool isPulse;

  const _EnhancedStatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.gradient,
    this.subtitle,
    this.trend,
    this.trendUp,
    this.isPulse = false,
  });

  @override
  State<_EnhancedStatCard> createState() => _EnhancedStatCardState();
}

class _EnhancedStatCardState extends State<_EnhancedStatCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward();

    // Pulse animation for high risk
    if (widget.isPulse) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale:
              widget.isPulse
                  ? 1.0 + (_controller.value * 0.03)
                  : _scaleAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                gradient: widget.gradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(-2, -2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    // Decorative pattern
                    Positioned(
                      right: -20,
                      top: -20,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    Positioned(
                      right: -10,
                      bottom: -10,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                    ),

                    // Content
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Icon with background
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              widget.icon,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Value with animation
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Flexible(
                                child: Text(
                                  widget.value,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (widget.subtitle != null) ...[
                                const SizedBox(width: 4),
                                Text(
                                  widget.subtitle!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withOpacity(0.8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Label
                          Text(
                            widget.label,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.95),
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),

                          // Trend indicator
                          if (widget.trend != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    widget.trendUp == true
                                        ? Icons.arrow_upward_rounded
                                        : Icons.arrow_downward_rounded,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.trend!,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Pulse indicator for high risk
                          if (widget.isPulse) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withOpacity(0.5),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Attention',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white.withOpacity(0.9),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
