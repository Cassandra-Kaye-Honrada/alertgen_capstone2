import 'package:allergen/screens/health_environment_analytics/air_quality_tab.dart';
import 'package:allergen/screens/health_environment_analytics/allergen_analytics_tab.dart';
import 'package:allergen/screens/health_environment_analytics/widgets/AirQualityWidget.dart';
import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
        children: [
          AirQualityTab(
            airQualityData: widget.airQualityData,
            location: widget.location,
            applicablePopulations: widget.applicablePopulations,
          ),
          AllergenAnalyticsTab(airQualityData: widget.airQualityData),
        ],
      ),
    );
  }
}
