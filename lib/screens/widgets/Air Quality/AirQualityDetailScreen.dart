import 'package:allergen/screens/widgets/AirQualityWidget.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AirQualityDetailScreen extends StatefulWidget {
  final AirQualityData airQualityData;
  final String location;
  final List<Population> applicablePopulations;

  const AirQualityDetailScreen({
    Key? key,
    required this.airQualityData,
    required this.location,
    required this.applicablePopulations,
  }) : super(key: key);

  @override
  State<AirQualityDetailScreen> createState() => _AirQualityDetailScreenState();
}

class _AirQualityDetailScreenState extends State<AirQualityDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _allergenHistory = [];
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAllergenHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllergenHistory() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Load food scan history
      final foodSnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('history')
              .orderBy('timestamp', descending: true)
              .limit(50)
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health & Environment Details'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF0B8FAC),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF0B8FAC),
          tabs: const [
            Tab(icon: Icon(Icons.air), text: 'Air Quality'),
            Tab(icon: Icon(Icons.analytics), text: 'Allergen Analytics'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildAirQualityTab(), _buildAllergenAnalyticsTab()],
      ),
    );
  }

  Widget _buildAirQualityTab() {
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

  Widget _buildAllergenAnalyticsTab() {
    if (_isLoadingHistory) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0B8FAC)),
        ),
      );
    }

    if (_allergenHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No allergen history available',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Start scanning food to build your allergen profile',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAllergenSummaryCard(),
          const SizedBox(height: 24),
          _buildTopAllergensSection(),
          const SizedBox(height: 24),
          _buildRiskDistributionSection(),
          const SizedBox(height: 24),
          _buildRecentExposuresSection(),
          const SizedBox(height: 24),
          _buildAirQualityAllergenInsights(),
        ],
      ),
    );
  }

  Widget _buildAllergenSummaryCard() {
    final totalExposures = _allergenHistory.length;
    final uniqueAllergens =
        _allergenHistory.map((e) => e['allergenName'] as String).toSet().length;
    final last7Days =
        _allergenHistory
            .where(
              (e) => (e['timestamp'] as DateTime).isAfter(
                DateTime.now().subtract(const Duration(days: 7)),
              ),
            )
            .length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B8FAC), Color(0xFF0FA3C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B8FAC).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Allergen Profile',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem('Total Exposures', '$totalExposures'),
              _buildSummaryItem('Unique Allergens', '$uniqueAllergens'),
              _buildSummaryItem('Last 7 Days', '$last7Days'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white70),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildTopAllergensSection() {
    // Count allergen occurrences
    final Map<String, int> allergenCounts = {};
    final Map<String, String> allergenRiskLevels = {};

    for (var entry in _allergenHistory) {
      final name = entry['allergenName'] as String;
      allergenCounts[name] = (allergenCounts[name] ?? 0) + 1;
      allergenRiskLevels[name] = entry['riskLevel'] as String;
    }

    // Sort by count
    final sortedAllergens =
        allergenCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    final topAllergens = sortedAllergens.take(5).toList();

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
              Icon(Icons.trending_up, color: Color(0xFF0B8FAC)),
              SizedBox(width: 8),
              Text(
                'Most Frequent Allergens',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...topAllergens.map((entry) {
            final percentage = (entry.value / _allergenHistory.length * 100);
            final riskColor = _getRiskColor(allergenRiskLevels[entry.key]!);
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
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
                      Text(
                        '${entry.value} times (${percentage.toStringAsFixed(1)}%)',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(riskColor),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildRiskDistributionSection() {
    final Map<String, int> riskCounts = {'severe': 0, 'moderate': 0, 'mild': 0};

    for (var entry in _allergenHistory) {
      final risk = (entry['riskLevel'] as String).toLowerCase();
      riskCounts[risk] = (riskCounts[risk] ?? 0) + 1;
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
          const Row(
            children: [
              Icon(Icons.pie_chart, color: Color(0xFF0B8FAC)),
              SizedBox(width: 8),
              Text(
                'Risk Level Distribution',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildRiskLevelCard(
            'Severe',
            riskCounts['severe']!,
            Colors.red,
            Icons.warning,
          ),
          const SizedBox(height: 12),
          _buildRiskLevelCard(
            'Moderate',
            riskCounts['moderate']!,
            Colors.orange,
            Icons.info,
          ),
          const SizedBox(height: 12),
          _buildRiskLevelCard(
            'Mild',
            riskCounts['mild']!,
            Colors.yellow[700]!,
            Icons.check_circle_outline,
          ),
        ],
      ),
    );
  }

  Widget _buildRiskLevelCard(
    String level,
    int count,
    Color color,
    IconData icon,
  ) {
    final percentage =
        _allergenHistory.isEmpty
            ? 0.0
            : (count / _allergenHistory.length * 100);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  level,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$count exposures (${percentage.toStringAsFixed(1)}%)',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentExposuresSection() {
    final recentExposures = _allergenHistory.take(5).toList();

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
              Icon(Icons.history, color: Color(0xFF0B8FAC)),
              SizedBox(width: 8),
              Text(
                'Recent Allergen Exposures',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...recentExposures.map((exposure) {
            final timestamp = exposure['timestamp'] as DateTime;
            final timeAgo = _getTimeAgo(timestamp);
            final riskColor = _getRiskColor(exposure['riskLevel'] as String);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 40,
                    decoration: BoxDecoration(
                      color: riskColor,
                      borderRadius: BorderRadius.circular(4),
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
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Found in: ${exposure['dishName']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          timeAgo,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildAirQualityAllergenInsights() {
    final aqi = widget.airQualityData.aqi;
    String insightTitle;
    String insightMessage;
    IconData insightIcon;
    Color insightColor;

    if (aqi <= 50) {
      insightTitle = 'Good Conditions for Allergen Management';
      insightMessage =
          'Current air quality is excellent. Your allergen symptoms are less likely to be aggravated by environmental factors.';
      insightIcon = Icons.wb_sunny;
      insightColor = Colors.green;
    } else if (aqi <= 100) {
      insightTitle = 'Moderate Impact on Allergen Sensitivity';
      insightMessage =
          'Air quality is acceptable, but sensitive individuals with allergens may experience mild discomfort.';
      insightIcon = Icons.cloud;
      insightColor = Colors.yellow[700]!;
    } else {
      insightTitle = 'High Alert: Enhanced Allergen Sensitivity';
      insightMessage =
          'Poor air quality can worsen allergen reactions. Take extra precautions and avoid trigger foods.';
      insightIcon = Icons.warning;
      insightColor = Colors.red;
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
          Row(
            children: [
              Icon(insightIcon, color: insightColor),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Air Quality & Allergen Insights',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: insightColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: insightColor.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insightTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: insightColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  insightMessage,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Recommendations:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          ..._getAllergenRecommendations(aqi).map((rec) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: const Color(0xFF0B8FAC),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      rec,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  List<String> _getAllergenRecommendations(int aqi) {
    if (aqi <= 50) {
      return [
        'Safe to engage in outdoor activities',
        'Normal allergen management routine',
        'Good time to introduce new foods cautiously',
      ];
    } else if (aqi <= 100) {
      return [
        'Monitor your allergen symptoms more closely',
        'Keep antihistamines accessible',
        'Avoid prolonged outdoor exposure',
        'Stay hydrated to help manage symptoms',
      ];
    } else {
      return [
        'Stay indoors as much as possible',
        'Use air purifiers in your home',
        'Strictly avoid known allergen triggers',
        'Keep emergency medications readily available',
        'Consider postponing introduction of new foods',
      ];
    }
  }

  // Helper getters
  bool get _hasHealthRecommendations {
    return widget.airQualityData.allHealthRecommendations != null &&
        widget.airQualityData.allHealthRecommendations.isNotEmpty;
  }

  bool get _hasPollutantData {
    return widget.airQualityData.components != null &&
        widget.airQualityData.components.isNotEmpty;
  }

  Color _getRiskColor(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'severe':
        return Colors.red;
      case 'moderate':
        return Colors.orange;
      case 'mild':
        return Colors.yellow[700]!;
      default:
        return Colors.grey;
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  // Air Quality Tab Widgets (keeping original implementations)
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
            widget.location,
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
                    aqi: widget.airQualityData.aqi.toDouble(),
                    color: widget.airQualityData.color,
                  ),
                ),
              ),
              Column(
                children: [
                  Text(
                    '${widget.airQualityData.aqi}',
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
              color: widget.airQualityData.color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: widget.airQualityData.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.airQualityData.qualityLevel,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: widget.airQualityData.color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Dominant pollutant: ${widget.airQualityData.dominantPollutant}',
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
          if (widget.applicablePopulations.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                const Text(
                  'For:',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                ...widget.applicablePopulations.map((pop) {
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

    for (var population in widget.applicablePopulations) {
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
      return widget.airQualityData.allHealthRecommendations[key];
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
                  widget.airQualityData.components.entries.map((entry) {
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
        widget.airQualityData.dominantPollutant.toLowerCase() ==
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
