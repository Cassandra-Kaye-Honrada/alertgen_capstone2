// import 'package:flutter/material.dart';
// import 'dart:math' as math;

// // Use this version in pubspec.yaml:
// // fl_chart: ^0.66.2

// import 'package:fl_chart/fl_chart.dart';

// class AirQualityForecastScreen extends StatefulWidget {
//   final String location;
//   final int currentAQI;

//   const AirQualityForecastScreen({
//     Key? key,
//     required this.location,
//     this.currentAQI = 65,
//   }) : super(key: key);

//   @override
//   State<AirQualityForecastScreen> createState() =>
//       _AirQualityForecastScreenState();
// }

// class _AirQualityForecastScreenState extends State<AirQualityForecastScreen> {
//   String viewMode = '24h'; // '24h' or '7day'
//   late List<HourlyForecast> forecastData;
//   late List<DailyForecast> weeklyData;
//   late HourlyForecast currentData;

//   @override
//   void initState() {
//     super.initState();
//     forecastData = generateForecastData();
//     weeklyData = generateWeeklyData();
//     currentData = forecastData[8]; // Current time (08:00)
//   }

//   List<HourlyForecast> generateForecastData() {
//     List<HourlyForecast> hours = [];
//     final baseAQI = widget.currentAQI.toDouble();

//     for (int i = 0; i < 48; i++) {
//       final hour = (4 + i) % 24;
//       final time = '${hour.toString().padLeft(2, '0')}:00';

//       double aqi = baseAQI;
//       if (hour >= 7 && hour <= 9) aqi += 15;
//       if (hour >= 17 && hour <= 19) aqi += 20;
//       if (hour >= 0 && hour <= 5) aqi -= 10;

//       aqi += math.sin(i * 0.5) * 8 + math.Random().nextDouble() * 10;
//       aqi = math.max(20, math.min(150, aqi));

//       hours.add(
//         HourlyForecast(
//           time: time,
//           hour: i,
//           aqi: aqi.round(),
//           pm25: (aqi * 0.4 + math.Random().nextDouble() * 10).round(),
//           pm10: (aqi * 0.6 + math.Random().nextDouble() * 15).round(),
//           o3: (aqi * 0.3 + math.Random().nextDouble() * 8).round(),
//           no2: (aqi * 0.25 + math.Random().nextDouble() * 5).round(),
//           humidity: (65 + math.sin(i * 0.3) * 15).round(),
//           temp: (25 + math.sin(i * 0.2) * 5).round(),
//           wind: (8 + math.Random().nextDouble() * 7).round(),
//         ),
//       );
//     }
//     return hours;
//   }

//   List<DailyForecast> generateWeeklyData() {
//     final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
//     return List.generate(days.length, (i) {
//       return DailyForecast(
//         day: days[i],
//         avgAQI:
//             (65 + math.sin(i) * 20 + math.Random().nextDouble() * 10).round(),
//         maxAQI:
//             (85 + math.sin(i) * 25 + math.Random().nextDouble() * 15).round(),
//         minAQI:
//             (45 + math.sin(i) * 15 + math.Random().nextDouble() * 10).round(),
//       );
//     });
//   }

//   AQILevel getAQILevel(int aqi) {
//     if (aqi <= 50) {
//       return AQILevel('Good', const Color(0xFF10b981), const Color(0xFFd1fae5));
//     }
//     if (aqi <= 100) {
//       return AQILevel(
//         'Moderate',
//         const Color(0xFFf59e0b),
//         const Color(0xFFfef3c7),
//       );
//     }
//     if (aqi <= 150) {
//       return AQILevel(
//         'Unhealthy for Sensitive',
//         const Color(0xFFf97316),
//         const Color(0xFFfed7aa),
//       );
//     }
//     if (aqi <= 200) {
//       return AQILevel(
//         'Unhealthy',
//         const Color(0xFFef4444),
//         const Color(0xFFfecaca),
//       );
//     }
//     if (aqi <= 300) {
//       return AQILevel(
//         'Very Unhealthy',
//         const Color(0xFFa855f7),
//         const Color(0xFFe9d5ff),
//       );
//     }
//     return AQILevel(
//       'Hazardous',
//       const Color(0xFF7c3aed),
//       const Color(0xFFddd6fe),
//     );
//   }

//   double calculateTrend() {
//     final last6Hours = forecastData.sublist(2, 8);
//     final next6Hours = forecastData.sublist(8, 14);
//     final avgLast = last6Hours.fold<double>(0, (sum, d) => sum + d.aqi) / 6;
//     final avgNext = next6Hours.fold<double>(0, (sum, d) => sum + d.aqi) / 6;
//     return avgNext - avgLast;
//   }

//   @override
//   Widget build(BuildContext context) {
//     final currentLevel = getAQILevel(currentData.aqi);
//     final trend = calculateTrend();

//     return Scaffold(
//       body: Container(
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//             colors: [Colors.blue[50]!, Colors.white, Colors.green[50]!],
//           ),
//         ),
//         child: SafeArea(
//           child: CustomScrollView(
//             slivers: [
//               _buildAppBar(),
//               SliverToBoxAdapter(
//                 child: Padding(
//                   padding: const EdgeInsets.all(16),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       _buildCurrentStatusCard(currentLevel, trend),
//                       const SizedBox(height: 16),
//                       _buildViewModeToggle(),
//                       const SizedBox(height: 16),
//                       viewMode == '24h'
//                           ? _build24HourChart()
//                           : _build7DayChart(),
//                       const SizedBox(height: 16),
//                       _buildPollutantTrends(),
//                       const SizedBox(height: 16),
//                       _buildHealthRecommendations(),
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildAppBar() {
//     return SliverAppBar(
//       expandedHeight: 120,
//       floating: false,
//       pinned: true,
//       backgroundColor: Colors.blue[600],
//       flexibleSpace: FlexibleSpaceBar(
//         title: Column(
//           mainAxisAlignment: MainAxisAlignment.end,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text(
//               'Air Quality Forecast',
//               style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
//             ),
//             Text(
//               widget.location,
//               style: const TextStyle(
//                 fontSize: 12,
//                 fontWeight: FontWeight.normal,
//               ),
//             ),
//           ],
//         ),
//         background: Container(
//           decoration: BoxDecoration(
//             gradient: LinearGradient(
//               colors: [Colors.blue[700]!, Colors.blue[500]!],
//             ),
//           ),
//           child: Stack(
//             children: [
//               Positioned(
//                 right: -20,
//                 top: -20,
//                 child: Icon(
//                   Icons.cloud,
//                   size: 150,
//                   color: Colors.white.withOpacity(0.1),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildCurrentStatusCard(AQILevel currentLevel, double trend) {
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(20),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.1),
//             blurRadius: 20,
//             offset: const Offset(0, 10),
//           ),
//         ],
//       ),
//       child: Column(
//         children: [
//           Container(
//             height: 4,
//             decoration: BoxDecoration(
//               color: currentLevel.color,
//               borderRadius: const BorderRadius.vertical(
//                 top: Radius.circular(20),
//               ),
//             ),
//           ),
//           Padding(
//             padding: const EdgeInsets.all(20),
//             child: Column(
//               children: [
//                 Row(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Expanded(child: _buildAQIGauge(currentLevel)),
//                     const SizedBox(width: 20),
//                     Expanded(child: _buildCurrentMetrics()),
//                   ],
//                 ),
//                 const Divider(height: 32),
//                 _buildForecastTrend(trend),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildAQIGauge(AQILevel level) {
//     return Column(
//       children: [
//         SizedBox(
//           width: 140,
//           height: 140,
//           child: Stack(
//             alignment: Alignment.center,
//             children: [
//               CustomPaint(
//                 size: const Size(140, 140),
//                 painter: AQIGaugePainter(
//                   aqi: currentData.aqi.toDouble(),
//                   color: level.color,
//                 ),
//               ),
//               Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Text(
//                     '${currentData.aqi}',
//                     style: TextStyle(
//                       fontSize: 48,
//                       fontWeight: FontWeight.bold,
//                       color: level.color,
//                     ),
//                   ),
//                   const Text(
//                     'AQI',
//                     style: TextStyle(
//                       fontSize: 14,
//                       color: Colors.grey,
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//         const SizedBox(height: 12),
//         Container(
//           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//           decoration: BoxDecoration(
//             color: level.bgColor,
//             borderRadius: BorderRadius.circular(20),
//           ),
//           child: Text(
//             level.label,
//             style: TextStyle(
//               fontSize: 14,
//               fontWeight: FontWeight.bold,
//               color: level.color,
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildCurrentMetrics() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const Text(
//           'Current Conditions',
//           style: TextStyle(
//             fontSize: 16,
//             fontWeight: FontWeight.bold,
//             color: Colors.black87,
//           ),
//         ),
//         const SizedBox(height: 16),
//         _buildMetricRow(
//           Icons.water_drop,
//           'PM2.5',
//           '${currentData.pm25} μg/m³',
//           Colors.red,
//         ),
//         const SizedBox(height: 12),
//         _buildMetricRow(
//           Icons.cloud,
//           'PM10',
//           '${currentData.pm10} μg/m³',
//           Colors.orange,
//         ),
//         const SizedBox(height: 12),
//         _buildMetricRow(
//           Icons.air,
//           'Wind',
//           '${currentData.wind} km/h',
//           Colors.blue,
//         ),
//         const SizedBox(height: 12),
//         _buildMetricRow(
//           Icons.thermostat,
//           'Temp',
//           '${currentData.temp}°C',
//           Colors.green,
//         ),
//       ],
//     );
//   }

//   Widget _buildMetricRow(
//     IconData icon,
//     String label,
//     String value,
//     Color color,
//   ) {
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: Colors.grey[50],
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Row(
//         children: [
//           Container(
//             padding: const EdgeInsets.all(8),
//             decoration: BoxDecoration(
//               color: color.withOpacity(0.1),
//               borderRadius: BorderRadius.circular(8),
//             ),
//             child: Icon(icon, size: 20, color: color),
//           ),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Text(
//               label,
//               style: const TextStyle(
//                 fontSize: 13,
//                 fontWeight: FontWeight.w500,
//                 color: Colors.black87,
//               ),
//             ),
//           ),
//           Text(
//             value,
//             style: const TextStyle(
//               fontSize: 14,
//               fontWeight: FontWeight.bold,
//               color: Colors.black87,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildForecastTrend(double trend) {
//     final isWorsening = trend > 0;
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: isWorsening ? Colors.red[50] : Colors.green[50],
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Row(
//         children: [
//           Icon(
//             isWorsening ? Icons.trending_up : Icons.trending_down,
//             color: isWorsening ? Colors.red[600] : Colors.green[600],
//             size: 32,
//           ),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   '6-Hour Forecast',
//                   style: TextStyle(
//                     fontSize: 12,
//                     color: Colors.grey[600],
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//                 Text(
//                   '${trend.abs().toStringAsFixed(0)} AQI ${isWorsening ? 'increase' : 'decrease'}',
//                   style: TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.bold,
//                     color: isWorsening ? Colors.red[700] : Colors.green[700],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildViewModeToggle() {
//     return Row(
//       children: [
//         _buildToggleButton('24 Hours', '24h'),
//         const SizedBox(width: 12),
//         _buildToggleButton('7 Days', '7day'),
//       ],
//     );
//   }

//   Widget _buildToggleButton(String label, String mode) {
//     final isActive = viewMode == mode;
//     return Expanded(
//       child: GestureDetector(
//         onTap: () => setState(() => viewMode = mode),
//         child: Container(
//           padding: const EdgeInsets.symmetric(vertical: 12),
//           decoration: BoxDecoration(
//             color: isActive ? Colors.blue[600] : Colors.white,
//             borderRadius: BorderRadius.circular(12),
//             boxShadow:
//                 isActive
//                     ? [
//                       BoxShadow(
//                         color: Colors.blue.withOpacity(0.3),
//                         blurRadius: 8,
//                         offset: const Offset(0, 4),
//                       ),
//                     ]
//                     : [],
//           ),
//           child: Text(
//             label,
//             textAlign: TextAlign.center,
//             style: TextStyle(
//               fontSize: 15,
//               fontWeight: FontWeight.bold,
//               color: isActive ? Colors.white : Colors.grey[600],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _build24HourChart() {
//     return Container(
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(20),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.05),
//             blurRadius: 15,
//             offset: const Offset(0, 5),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             '48-Hour AQI Forecast',
//             style: TextStyle(
//               fontSize: 18,
//               fontWeight: FontWeight.bold,
//               color: Colors.black87,
//             ),
//           ),
//           const SizedBox(height: 20),
//           SizedBox(
//             height: 250,
//             child: LineChart(
//               LineChartData(
//                 gridData: FlGridData(
//                   show: true,
//                   drawVerticalLine: false,
//                   horizontalInterval: 50,
//                   getDrawingHorizontalLine: (value) {
//                     return FlLine(color: Colors.grey[300]!, strokeWidth: 1);
//                   },
//                 ),
//                 titlesData: FlTitlesData(
//                   leftTitles: AxisTitles(
//                     sideTitles: SideTitles(
//                       showTitles: true,
//                       reservedSize: 40,
//                       getTitlesWidget: (value, meta) {
//                         return Text(
//                           value.toInt().toString(),
//                           style: const TextStyle(fontSize: 12),
//                         );
//                       },
//                     ),
//                   ),
//                   bottomTitles: AxisTitles(
//                     sideTitles: SideTitles(
//                       showTitles: true,
//                       interval: 4,
//                       getTitlesWidget: (value, meta) {
//                         if (value.toInt() >= 0 &&
//                             value.toInt() < forecastData.length) {
//                           return Padding(
//                             padding: const EdgeInsets.only(top: 8),
//                             child: Text(
//                               forecastData[value.toInt()].time,
//                               style: const TextStyle(fontSize: 10),
//                             ),
//                           );
//                         }
//                         return const Text('');
//                       },
//                     ),
//                   ),
//                   rightTitles: const AxisTitles(
//                     sideTitles: SideTitles(showTitles: false),
//                   ),
//                   topTitles: const AxisTitles(
//                     sideTitles: SideTitles(showTitles: false),
//                   ),
//                 ),
//                 borderData: FlBorderData(show: false),
//                 lineBarsData: [
//                   LineChartBarData(
//                     spots:
//                         forecastData.asMap().entries.map((entry) {
//                           return FlSpot(
//                             entry.key.toDouble(),
//                             entry.value.aqi.toDouble(),
//                           );
//                         }).toList(),
//                     isCurved: true,
//                     color: Colors.blue[600],
//                     barWidth: 3,
//                     dotData: const FlDotData(show: false),
//                     belowBarData: BarAreaData(
//                       show: true,
//                       color: Colors.blue[600]!.withOpacity(0.2),
//                     ),
//                   ),
//                 ],
//                 minY: 0,
//                 maxY: 200,
//               ),
//             ),
//           ),
//           const SizedBox(height: 16),
//           _buildAQILegend(),
//         ],
//       ),
//     );
//   }

//   Widget _build7DayChart() {
//     return Container(
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(20),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.05),
//             blurRadius: 15,
//             offset: const Offset(0, 5),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             '7-Day Forecast',
//             style: TextStyle(
//               fontSize: 18,
//               fontWeight: FontWeight.bold,
//               color: Colors.black87,
//             ),
//           ),
//           const SizedBox(height: 20),
//           SizedBox(
//             height: 250,
//             child: LineChart(
//               LineChartData(
//                 gridData: FlGridData(
//                   show: true,
//                   drawVerticalLine: false,
//                   getDrawingHorizontalLine: (value) {
//                     return FlLine(color: Colors.grey[300]!, strokeWidth: 1);
//                   },
//                 ),
//                 titlesData: FlTitlesData(
//                   leftTitles: AxisTitles(
//                     sideTitles: SideTitles(
//                       showTitles: true,
//                       reservedSize: 40,
//                       getTitlesWidget: (value, meta) {
//                         return Text(
//                           value.toInt().toString(),
//                           style: const TextStyle(fontSize: 12),
//                         );
//                       },
//                     ),
//                   ),
//                   bottomTitles: AxisTitles(
//                     sideTitles: SideTitles(
//                       showTitles: true,
//                       getTitlesWidget: (value, meta) {
//                         if (value.toInt() >= 0 &&
//                             value.toInt() < weeklyData.length) {
//                           return Padding(
//                             padding: const EdgeInsets.only(top: 8),
//                             child: Text(
//                               weeklyData[value.toInt()].day,
//                               style: const TextStyle(fontSize: 12),
//                             ),
//                           );
//                         }
//                         return const Text('');
//                       },
//                     ),
//                   ),
//                   rightTitles: const AxisTitles(
//                     sideTitles: SideTitles(showTitles: false),
//                   ),
//                   topTitles: const AxisTitles(
//                     sideTitles: SideTitles(showTitles: false),
//                   ),
//                 ),
//                 borderData: FlBorderData(show: false),
//                 lineBarsData: [
//                   LineChartBarData(
//                     spots:
//                         weeklyData
//                             .asMap()
//                             .entries
//                             .map(
//                               (e) => FlSpot(
//                                 e.key.toDouble(),
//                                 e.value.avgAQI.toDouble(),
//                               ),
//                             )
//                             .toList(),
//                     isCurved: true,
//                     color: Colors.blue[600],
//                     barWidth: 3,
//                     dotData: FlDotData(
//                       show: true,
//                       getDotPainter: (spot, percent, barData, index) {
//                         return FlDotCirclePainter(
//                           radius: 4,
//                           color: Colors.blue[600]!,
//                         );
//                       },
//                     ),
//                   ),
//                   LineChartBarData(
//                     spots:
//                         weeklyData
//                             .asMap()
//                             .entries
//                             .map(
//                               (e) => FlSpot(
//                                 e.key.toDouble(),
//                                 e.value.maxAQI.toDouble(),
//                               ),
//                             )
//                             .toList(),
//                     isCurved: true,
//                     color: Colors.red[600],
//                     barWidth: 2,
//                     dashArray: [5, 5],
//                     dotData: const FlDotData(show: false),
//                   ),
//                   LineChartBarData(
//                     spots:
//                         weeklyData
//                             .asMap()
//                             .entries
//                             .map(
//                               (e) => FlSpot(
//                                 e.key.toDouble(),
//                                 e.value.minAQI.toDouble(),
//                               ),
//                             )
//                             .toList(),
//                     isCurved: true,
//                     color: Colors.green[600],
//                     barWidth: 2,
//                     dashArray: [5, 5],
//                     dotData: const FlDotData(show: false),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildPollutantTrends() {
//     return Container(
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(20),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.05),
//             blurRadius: 15,
//             offset: const Offset(0, 5),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             'Pollutant Trends (Next 24h)',
//             style: TextStyle(
//               fontSize: 18,
//               fontWeight: FontWeight.bold,
//               color: Colors.black87,
//             ),
//           ),
//           const SizedBox(height: 20),
//           SizedBox(
//             height: 200,
//             child: LineChart(
//               LineChartData(
//                 gridData: FlGridData(show: true, drawVerticalLine: false),
//                 titlesData: FlTitlesData(
//                   leftTitles: AxisTitles(
//                     sideTitles: SideTitles(showTitles: true, reservedSize: 35),
//                   ),
//                   bottomTitles: AxisTitles(
//                     sideTitles: SideTitles(
//                       showTitles: true,
//                       interval: 3,
//                       getTitlesWidget: (value, meta) {
//                         if (value.toInt() < 24) {
//                           return Text(
//                             forecastData[value.toInt()].time,
//                             style: const TextStyle(fontSize: 9),
//                           );
//                         }
//                         return const Text('');
//                       },
//                     ),
//                   ),
//                   rightTitles: const AxisTitles(
//                     sideTitles: SideTitles(showTitles: false),
//                   ),
//                   topTitles: const AxisTitles(
//                     sideTitles: SideTitles(showTitles: false),
//                   ),
//                 ),
//                 borderData: FlBorderData(show: false),
//                 lineBarsData: [
//                   LineChartBarData(
//                     spots:
//                         forecastData
//                             .sublist(0, 24)
//                             .asMap()
//                             .entries
//                             .map(
//                               (e) => FlSpot(
//                                 e.key.toDouble(),
//                                 e.value.pm25.toDouble(),
//                               ),
//                             )
//                             .toList(),
//                     color: Colors.red,
//                     barWidth: 2,
//                     dotData: const FlDotData(show: false),
//                   ),
//                   LineChartBarData(
//                     spots:
//                         forecastData
//                             .sublist(0, 24)
//                             .asMap()
//                             .entries
//                             .map(
//                               (e) => FlSpot(
//                                 e.key.toDouble(),
//                                 e.value.pm10.toDouble(),
//                               ),
//                             )
//                             .toList(),
//                     color: Colors.orange,
//                     barWidth: 2,
//                     dotData: const FlDotData(show: false),
//                   ),
//                   LineChartBarData(
//                     spots:
//                         forecastData
//                             .sublist(0, 24)
//                             .asMap()
//                             .entries
//                             .map(
//                               (e) => FlSpot(
//                                 e.key.toDouble(),
//                                 e.value.o3.toDouble(),
//                               ),
//                             )
//                             .toList(),
//                     color: Colors.purple,
//                     barWidth: 2,
//                     dotData: const FlDotData(show: false),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           const SizedBox(height: 16),
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceAround,
//             children: [
//               _buildLegendItem('PM2.5', Colors.red),
//               _buildLegendItem('PM10', Colors.orange),
//               _buildLegendItem('O₃', Colors.purple),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildLegendItem(String label, Color color) {
//     return Row(
//       children: [
//         Container(width: 16, height: 3, color: color),
//         const SizedBox(width: 6),
//         Text(label, style: const TextStyle(fontSize: 12)),
//       ],
//     );
//   }

//   Widget _buildAQILegend() {
//     final items = [
//       {'range': '0-50', 'label': 'Good', 'color': const Color(0xFF10b981)},
//       {
//         'range': '51-100',
//         'label': 'Moderate',
//         'color': const Color(0xFFf59e0b),
//       },
//       {
//         'range': '101-150',
//         'label': 'Unhealthy',
//         'color': const Color(0xFFf97316),
//       },
//       {
//         'range': '151+',
//         'label': 'Very Unhealthy',
//         'color': const Color(0xFFef4444),
//       },
//     ];

//     return Wrap(
//       spacing: 12,
//       runSpacing: 8,
//       children:
//           items.map((item) {
//             return Row(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Container(
//                   width: 16,
//                   height: 16,
//                   decoration: BoxDecoration(
//                     color: item['color'] as Color,
//                     borderRadius: BorderRadius.circular(4),
//                   ),
//                 ),
//                 const SizedBox(width: 6),
//                 Text(
//                   '${item['range']}: ${item['label']}',
//                   style: const TextStyle(fontSize: 11, color: Colors.black87),
//                 ),
//               ],
//             );
//           }).toList(),
//     );
//   }

//   Widget _buildHealthRecommendations() {
//     return Column(
//       children: [
//         Container(
//           padding: const EdgeInsets.all(20),
//           decoration: BoxDecoration(
//             gradient: LinearGradient(
//               colors: [Colors.blue[500]!, Colors.blue[600]!],
//             ),
//             borderRadius: BorderRadius.circular(20),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.blue.withOpacity(0.3),
//                 blurRadius: 15,
//                 offset: const Offset(0, 5),
//               ),
//             ],
//           ),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const Row(
//                 children: [
//                   Icon(Icons.directions_run, color: Colors.white),
//                   SizedBox(width: 12),
//                   Text(
//                     'Outdoor Activities',
//                     style: TextStyle(
//                       fontSize: 18,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.white,
//                     ),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 12),
//               Text(
//                 currentData.aqi < 50
//                     ? 'Perfect conditions for outdoor activities'
//                     : currentData.aqi < 100
//                     ? 'Good for most outdoor activities'
//                     : currentData.aqi < 150
//                     ? 'Limit prolonged outdoor exertion for sensitive groups'
//                     : 'Avoid outdoor activities, especially for sensitive groups',
//                 style: TextStyle(fontSize: 14, color: Colors.blue[50]),
//               ),
//               const SizedBox(height: 12),
//               Row(
//                 children: [
//                   Icon(Icons.schedule, size: 16, color: Colors.blue[50]),
//                   const SizedBox(width: 8),
//                   Text(
//                     'Best time: 05:00 - 07:00 AM',
//                     style: TextStyle(fontSize: 13, color: Colors.blue[50]),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//         const SizedBox(height: 16),
//         Container(
//           padding: const EdgeInsets.all(20),
//           decoration: BoxDecoration(
//             gradient: LinearGradient(
//               colors: [Colors.green[500]!, Colors.green[600]!],
//             ),
//             borderRadius: BorderRadius.circular(20),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.green.withOpacity(0.3),
//                 blurRadius: 15,
//                 offset: const Offset(0, 5),
//               ),
//             ],
//           ),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const Row(
//                 children: [
//                   Icon(Icons.health_and_safety, color: Colors.white),
//                   SizedBox(width: 12),
//                   Text(
//                     'Protection Tips',
//                     style: TextStyle(
//                       fontSize: 18,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.white,
//                     ),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 12),
//               Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   _buildTipItem(
//                     currentData.aqi > 100
//                         ? 'Consider wearing a mask outdoors'
//                         : 'No mask needed for healthy individuals',
//                   ),
//                   _buildTipItem(
//                     currentData.aqi > 100
//                         ? 'Keep windows closed'
//                         : 'Ventilate indoor spaces regularly',
//                   ),
//                   _buildTipItem(
//                     currentData.aqi > 100
//                         ? 'Use air purifiers indoors'
//                         : 'Monitor air quality regularly',
//                   ),
//                   _buildTipItem('Stay hydrated and avoid strenuous activities'),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildTipItem(String text) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 8),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text('• ', style: TextStyle(color: Colors.green[50], fontSize: 14)),
//           Expanded(
//             child: Text(
//               text,
//               style: TextStyle(fontSize: 13, color: Colors.green[50]),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // Data Models
// class HourlyForecast {
//   final String time;
//   final int hour;
//   final int aqi;
//   final int pm25;
//   final int pm10;
//   final int o3;
//   final int no2;
//   final int humidity;
//   final int temp;
//   final int wind;

//   HourlyForecast({
//     required this.time,
//     required this.hour,
//     required this.aqi,
//     required this.pm25,
//     required this.pm10,
//     required this.o3,
//     required this.no2,
//     required this.humidity,
//     required this.temp,
//     required this.wind,
//   });
// }

// class DailyForecast {
//   final String day;
//   final int avgAQI;
//   final int maxAQI;
//   final int minAQI;

//   DailyForecast({
//     required this.day,
//     required this.avgAQI,
//     required this.maxAQI,
//     required this.minAQI,
//   });
// }

// class AQILevel {
//   final String label;
//   final Color color;
//   final Color bgColor;

//   AQILevel(this.label, this.color, this.bgColor);
// }

// // Custom Painter for AQI Gauge
// class AQIGaugePainter extends CustomPainter {
//   final double aqi;
//   final Color color;

//   AQIGaugePainter({required this.aqi, required this.color});

//   @override
//   void paint(Canvas canvas, Size size) {
//     final center = Offset(size.width / 2, size.height / 2);
//     final radius = math.min(size.width, size.height) / 2 - 10;

//     // Background circle
//     final backgroundPaint =
//         Paint()
//           ..color = Colors.grey[200]!
//           ..style = PaintingStyle.stroke
//           ..strokeWidth = 12;

//     canvas.drawCircle(center, radius, backgroundPaint);

//     // Progress arc
//     final progressPaint =
//         Paint()
//           ..color = color
//           ..style = PaintingStyle.stroke
//           ..strokeWidth = 12
//           ..strokeCap = StrokeCap.round;

//     final sweepAngle = (aqi / 500) * 2 * math.pi;
//     canvas.drawArc(
//       Rect.fromCircle(center: center, radius: radius),
//       -math.pi / 2,
//       sweepAngle,
//       false,
//       progressPaint,
//     );
//   }

//   @override
//   bool shouldRepaint(AQIGaugePainter oldDelegate) {
//     return oldDelegate.aqi != aqi || oldDelegate.color != color;
//   }
// }
import 'package:allergen/screens/widgets/AirQualityWidget.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';

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

class _AirQualityDetailScreenState extends State<AirQualityDetailScreen> {
  String viewMode = '24h'; // '24h' or '7day'
  late List<HourlyForecast> forecastData;
  late List<DailyForecast> weeklyData;

  @override
  void initState() {
    super.initState();
    forecastData = generateForecastData();
    weeklyData = generateWeeklyData();
  }

  List<HourlyForecast> generateForecastData() {
    List<HourlyForecast> hours = [];
    final baseAQI = widget.airQualityData.aqi.toDouble();

    for (int i = 0; i < 48; i++) {
      final hour = (DateTime.now().hour + i) % 24;
      final time = '${hour.toString().padLeft(2, '0')}:00';

      double aqi = baseAQI;
      if (hour >= 7 && hour <= 9) aqi += 15;
      if (hour >= 17 && hour <= 19) aqi += 20;
      if (hour >= 0 && hour <= 5) aqi -= 10;

      aqi += math.sin(i * 0.5) * 8 + math.Random().nextDouble() * 10;
      aqi = math.max(20, math.min(150, aqi));

      hours.add(
        HourlyForecast(
          time: time,
          hour: i,
          aqi: aqi.round(),
          pm25: (aqi * 0.4 + math.Random().nextDouble() * 10).round(),
          pm10: (aqi * 0.6 + math.Random().nextDouble() * 15).round(),
          o3: (aqi * 0.3 + math.Random().nextDouble() * 8).round(),
          no2: (aqi * 0.25 + math.Random().nextDouble() * 5).round(),
        ),
      );
    }
    return hours;
  }

  List<DailyForecast> generateWeeklyData() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return List.generate(days.length, (i) {
      return DailyForecast(
        day: days[i],
        avgAQI:
            (widget.airQualityData.aqi +
                    math.sin(i) * 20 +
                    math.Random().nextDouble() * 10)
                .round(),
        maxAQI:
            (widget.airQualityData.aqi +
                    20 +
                    math.sin(i) * 25 +
                    math.Random().nextDouble() * 15)
                .round(),
        minAQI:
            (widget.airQualityData.aqi -
                    20 +
                    math.sin(i) * 15 +
                    math.Random().nextDouble() * 10)
                .round(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Air Quality Details'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
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
            _buildViewModeToggle(),
            const SizedBox(height: 16),
            viewMode == '24h' ? _build24HourChart() : _build7DayChart(),
            const SizedBox(height: 24),
            _buildPollutantTrends(),
            const SizedBox(height: 24),
            _buildAQIScaleSection(),
          ],
        ),
      ),
    );
  }

  bool get _hasHealthRecommendations {
    return widget.airQualityData.allHealthRecommendations != null &&
        widget.airQualityData.allHealthRecommendations.isNotEmpty;
  }

  bool get _hasPollutantData {
    return widget.airQualityData.components != null &&
        widget.airQualityData.components.isNotEmpty;
  }

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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              children: [
                const Icon(Icons.science, size: 20, color: Colors.orange),
                const SizedBox(width: 8),
                const Text(
                  'Pollutant Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          if (_hasPollutantData)
            SizedBox(
              height: 160,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: widget.airQualityData.components.length,
                itemBuilder: (context, index) {
                  final entry = widget.airQualityData.components.entries
                      .elementAt(index);
                  return Padding(
                    padding: EdgeInsets.only(
                      right:
                          index < widget.airQualityData.components.length - 1
                              ? 12
                              : 0,
                    ),
                    child: _buildPollutantCard(
                      _getPollutantName(entry.key),
                      entry.value,
                      'μg/m³',
                      _getPollutantDescription(entry.key),
                      entry.key,
                    ),
                  );
                },
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: Center(
                child: Text(
                  'No pollutant data available',
                  style: TextStyle(color: Colors.grey),
                ),
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
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.grey[50]!, Colors.grey[100]!],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isDominant ? Colors.orange.withOpacity(0.5) : Colors.grey[300]!,
          width: isDominant ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (isDominant)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Dominant',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  height: 1,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildViewModeToggle() {
    return Row(
      children: [
        _buildToggleButton('24 Hours', '24h'),
        const SizedBox(width: 12),
        _buildToggleButton('7 Days', '7day'),
      ],
    );
  }

  Widget _buildToggleButton(String label, String mode) {
    final isActive = viewMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => viewMode = mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? Colors.blue[600] : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow:
                isActive
                    ? [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ]
                    : [],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isActive ? Colors.white : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }

  Widget _build24HourChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '48-Hour AQI Forecast',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 250,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 50,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(color: Colors.grey[300]!, strokeWidth: 1);
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 12),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 4,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 &&
                            value.toInt() < forecastData.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              forecastData[value.toInt()].time,
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots:
                        forecastData.asMap().entries.map((entry) {
                          return FlSpot(
                            entry.key.toDouble(),
                            entry.value.aqi.toDouble(),
                          );
                        }).toList(),
                    isCurved: true,
                    color: Colors.blue[600],
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.blue[600]!.withOpacity(0.2),
                    ),
                  ),
                ],
                minY: 0,
                maxY: 200,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildAQILegend(),
        ],
      ),
    );
  }

  Widget _build7DayChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '7-Day Forecast',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 250,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(color: Colors.grey[300]!, strokeWidth: 1);
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 12),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 &&
                            value.toInt() < weeklyData.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              weeklyData[value.toInt()].day,
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots:
                        weeklyData
                            .asMap()
                            .entries
                            .map(
                              (e) => FlSpot(
                                e.key.toDouble(),
                                e.value.avgAQI.toDouble(),
                              ),
                            )
                            .toList(),
                    isCurved: true,
                    color: Colors.blue[600],
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: Colors.blue[600]!,
                        );
                      },
                    ),
                  ),
                  LineChartBarData(
                    spots:
                        weeklyData
                            .asMap()
                            .entries
                            .map(
                              (e) => FlSpot(
                                e.key.toDouble(),
                                e.value.maxAQI.toDouble(),
                              ),
                            )
                            .toList(),
                    isCurved: true,
                    color: Colors.red[600],
                    barWidth: 2,
                    dashArray: [5, 5],
                    dotData: const FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots:
                        weeklyData
                            .asMap()
                            .entries
                            .map(
                              (e) => FlSpot(
                                e.key.toDouble(),
                                e.value.minAQI.toDouble(),
                              ),
                            )
                            .toList(),
                    isCurved: true,
                    color: Colors.green[600],
                    barWidth: 2,
                    dashArray: [5, 5],
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPollutantTrends() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pollutant Trends (Next 24h)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 35),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 3,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() < 24) {
                          return Text(
                            forecastData[value.toInt()].time,
                            style: const TextStyle(fontSize: 9),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots:
                        forecastData
                            .sublist(0, 24)
                            .asMap()
                            .entries
                            .map(
                              (e) => FlSpot(
                                e.key.toDouble(),
                                e.value.pm25.toDouble(),
                              ),
                            )
                            .toList(),
                    color: Colors.red,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots:
                        forecastData
                            .sublist(0, 24)
                            .asMap()
                            .entries
                            .map(
                              (e) => FlSpot(
                                e.key.toDouble(),
                                e.value.pm10.toDouble(),
                              ),
                            )
                            .toList(),
                    color: Colors.orange,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots:
                        forecastData
                            .sublist(0, 24)
                            .asMap()
                            .entries
                            .map(
                              (e) => FlSpot(
                                e.key.toDouble(),
                                e.value.o3.toDouble(),
                              ),
                            )
                            .toList(),
                    color: Colors.purple,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegendItem('PM2.5', Colors.red),
              _buildLegendItem('PM10', Colors.orange),
              _buildLegendItem('O₃', Colors.purple),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 16, height: 3, color: color),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildAQILegend() {
    final items = [
      {'range': '0-50', 'label': 'Good', 'color': const Color(0xFF10b981)},
      {
        'range': '51-100',
        'label': 'Moderate',
        'color': const Color(0xFFf59e0b),
      },
      {
        'range': '101-150',
        'label': 'Unhealthy',
        'color': const Color(0xFFf97316),
      },
      {
        'range': '151+',
        'label': 'Very Unhealthy',
        'color': const Color(0xFFef4444),
      },
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children:
          items.map((item) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: item['color'] as Color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${item['range']}: ${item['label']}',
                  style: const TextStyle(fontSize: 11, color: Colors.black87),
                ),
              ],
            );
          }).toList(),
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

// Data Models
class HourlyForecast {
  final String time;
  final int hour;
  final int aqi;
  final int pm25;
  final int pm10;
  final int o3;
  final int no2;

  HourlyForecast({
    required this.time,
    required this.hour,
    required this.aqi,
    required this.pm25,
    required this.pm10,
    required this.o3,
    required this.no2,
  });
}

class DailyForecast {
  final String day;
  final int avgAQI;
  final int maxAQI;
  final int minAQI;

  DailyForecast({
    required this.day,
    required this.avgAQI,
    required this.maxAQI,
    required this.minAQI,
  });
}
