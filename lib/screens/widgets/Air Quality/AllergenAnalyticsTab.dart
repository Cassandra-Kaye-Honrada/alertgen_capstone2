// import 'package:allergen/screens/health_environment_analytics/widgets/AirQualityWidget.dart';
// import 'package:flutter/material.dart';
// import 'dart:math' as math;

// class AllergenAnalyticsTab extends StatelessWidget {
//   final List<Map<String, dynamic>> allergenHistory;
//   final bool isLoadingHistory;
//   final AirQualityData airQualityData;

//   const AllergenAnalyticsTab({
//     Key? key,
//     required this.allergenHistory,
//     required this.isLoadingHistory,
//     required this.airQualityData,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     if (isLoadingHistory) {
//       return const Center(
//         child: CircularProgressIndicator(
//           valueColor: AlwaysStoppedAnimation<Color>(AppConstants.primaryColor),
//         ),
//       );
//     }

//     if (allergenHistory.isEmpty) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(Icons.analytics_outlined, size: 80, color: Colors.grey[300]),
//             const SizedBox(height: 16),
//             Text(
//               AppConstants.emptyHistoryMessage,
//               style: TextStyle(fontSize: 16, color: Colors.grey[600]),
//             ),
//             const SizedBox(height: 8),
//             Text(
//               AppConstants.emptyHistorySubMessage,
//               style: TextStyle(fontSize: 14, color: Colors.grey[500]),
//               textAlign: TextAlign.center,
//             ),
//           ],
//         ),
//       );
//     }

//     return SingleChildScrollView(
//       padding: const EdgeInsets.all(16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           _buildAllergenSummaryCard(),
//           const SizedBox(height: 16),
//           _buildWeeklyTrendCard(),
//           const SizedBox(height: 16),
//           _buildRiskDistributionVisual(),
//           const SizedBox(height: 24),
//           _buildTopAllergensSection(),
//           const SizedBox(height: 24),
//           _buildRecentExposuresSection(),
//           const SizedBox(height: 24),
//           _buildAirQualityAllergenInsights(),
//         ],
//       ),
//     );
//   }

//   Widget _buildAllergenSummaryCard() {
//     final totalExposures = allergenHistory.length;
//     final uniqueAllergens =
//         AllergenStatsHelper.getUniqueAllergens(allergenHistory).length;
//     final last7Days = AllergenStatsHelper.getRecentExposureCount(
//       allergenHistory,
//       7,
//     );

//     // Calculate severity breakdown using helper
//     final riskCounts = AllergenStatsHelper.calculateRiskDistribution(
//       allergenHistory,
//     );

//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.all(AppConstants.cardPadding),
//       decoration: CardDecorationHelper.getGradientCardDecoration(
//         AppConstants.primaryColor,
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               const Icon(Icons.analytics, color: Colors.white, size: 24),
//               const SizedBox(width: 8),
//               const Expanded(
//                 child: Text(
//                   'Your Allergen Profile',
//                   style: TextStyle(
//                     fontSize: 20,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.white,
//                   ),
//                 ),
//               ),
//               Container(
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 12,
//                   vertical: 6,
//                 ),
//                 decoration: BoxDecoration(
//                   color: Colors.white.withOpacity(0.2),
//                   borderRadius: BorderRadius.circular(20),
//                 ),
//                 child: Text(
//                   'Last ${AppConstants.maxHistoryItems} scans',
//                   style: const TextStyle(fontSize: 11, color: Colors.white),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 20),
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceAround,
//             children: [
//               _buildSummaryItem(
//                 'Total\nExposures',
//                 '$totalExposures',
//                 Icons.coronavirus,
//               ),
//               _buildSummaryItem(
//                 'Unique\nAllergens',
//                 '$uniqueAllergens',
//                 Icons.restaurant,
//               ),
//               _buildSummaryItem(
//                 'Last\n7 Days',
//                 '$last7Days',
//                 Icons.calendar_today,
//               ),
//             ],
//           ),
//           const SizedBox(height: 20),
//           Container(
//             padding: const EdgeInsets.all(12),
//             decoration: BoxDecoration(
//               color: Colors.white.withOpacity(0.15),
//               borderRadius: BorderRadius.circular(
//                 AppConstants.smallCardBorderRadius,
//               ),
//             ),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceAround,
//               children: [
//                 _buildMiniRiskIndicator(
//                   'Severe',
//                   riskCounts['severe']!,
//                   Colors.red[300]!,
//                 ),
//                 _buildMiniRiskIndicator(
//                   'Moderate',
//                   riskCounts['moderate']!,
//                   Colors.orange[300]!,
//                 ),
//                 _buildMiniRiskIndicator(
//                   'Mild',
//                   riskCounts['mild']!,
//                   Colors.yellow[300]!,
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildSummaryItem(String label, String value, IconData icon) {
//     return Column(
//       children: [
//         Icon(icon, color: Colors.white70, size: 20),
//         const SizedBox(height: 8),
//         Text(
//           value,
//           style: const TextStyle(
//             fontSize: 28,
//             fontWeight: FontWeight.bold,
//             color: Colors.white,
//           ),
//         ),
//         const SizedBox(height: 4),
//         Text(
//           label,
//           style: const TextStyle(fontSize: 11, color: Colors.white70),
//           textAlign: TextAlign.center,
//         ),
//       ],
//     );
//   }

//   Widget _buildMiniRiskIndicator(String label, int count, Color color) {
//     return Column(
//       children: [
//         Text(
//           '$count',
//           style: TextStyle(
//             fontSize: 18,
//             fontWeight: FontWeight.bold,
//             color: color,
//           ),
//         ),
//         Text(
//           label,
//           style: const TextStyle(fontSize: 10, color: Colors.white70),
//         ),
//       ],
//     );
//   }

//   Widget _buildWeeklyTrendCard() {
//     // Use helper to calculate daily counts
//     final dailyCounts = AllergenStatsHelper.calculateDailyCounts(
//       allergenHistory,
//       7,
//     );
//     final maxCount =
//         dailyCounts.values.isEmpty ? 1 : dailyCounts.values.reduce(math.max);
//     final avgDaily =
//         dailyCounts.values.isEmpty
//             ? 0
//             : dailyCounts.values.reduce((a, b) => a + b) / dailyCounts.length;

//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.all(AppConstants.cardPadding),
//       decoration: CardDecorationHelper.getWhiteCardDecoration(),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               const Row(
//                 children: [
//                   Icon(Icons.show_chart, color: AppConstants.primaryColor),
//                   SizedBox(width: 8),
//                   Text(
//                     '7-Day Exposure Trend',
//                     style: TextStyle(
//                       fontSize: 18,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.black87,
//                     ),
//                   ),
//                 ],
//               ),
//               Container(
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 12,
//                   vertical: 6,
//                 ),
//                 decoration: BoxDecoration(
//                   color: AppConstants.primaryColor.withOpacity(0.1),
//                   borderRadius: BorderRadius.circular(20),
//                 ),
//                 child: Text(
//                   'Avg: ${avgDaily.toStringAsFixed(1)}/day',
//                   style: const TextStyle(
//                     fontSize: 12,
//                     fontWeight: FontWeight.w600,
//                     color: AppConstants.primaryColor,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 20),
//           SizedBox(
//             height: 120,
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceAround,
//               crossAxisAlignment: CrossAxisAlignment.end,
//               children:
//                   dailyCounts.entries.map((entry) {
//                     final height =
//                         maxCount == 0 ? 0.0 : (entry.value / maxCount) * 100;
//                     final date = DateTime.now().subtract(
//                       Duration(days: DateTime.now().day - entry.key),
//                     );
//                     final dayName = TimeHelper.getDayName(date);

//                     return Expanded(
//                       child: Padding(
//                         padding: const EdgeInsets.symmetric(horizontal: 4),
//                         child: Column(
//                           mainAxisAlignment: MainAxisAlignment.end,
//                           children: [
//                             if (entry.value > 0)
//                               Container(
//                                 margin: const EdgeInsets.only(bottom: 4),
//                                 padding: const EdgeInsets.symmetric(
//                                   horizontal: 6,
//                                   vertical: 2,
//                                 ),
//                                 decoration: BoxDecoration(
//                                   color: AppConstants.primaryColor,
//                                   borderRadius: BorderRadius.circular(8),
//                                 ),
//                                 child: Text(
//                                   '${entry.value}',
//                                   style: const TextStyle(
//                                     fontSize: 10,
//                                     color: Colors.white,
//                                     fontWeight: FontWeight.bold,
//                                   ),
//                                 ),
//                               ),
//                             Container(
//                               height: height.clamp(10, 100),
//                               decoration: BoxDecoration(
//                                 gradient: LinearGradient(
//                                   colors: [
//                                     AppConstants.primaryColor,
//                                     AppConstants.primaryColor.withOpacity(0.6),
//                                   ],
//                                   begin: Alignment.topCenter,
//                                   end: Alignment.bottomCenter,
//                                 ),
//                                 borderRadius: BorderRadius.circular(6),
//                               ),
//                             ),
//                             const SizedBox(height: 8),
//                             Text(
//                               dayName,
//                               style: TextStyle(
//                                 fontSize: 12,
//                                 color: Colors.grey[600],
//                                 fontWeight: FontWeight.w500,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     );
//                   }).toList(),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildRiskDistributionVisual() {
//     final riskCounts = AllergenStatsHelper.calculateRiskDistribution(
//       allergenHistory,
//     );
//     final total = allergenHistory.length;

//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.all(AppConstants.cardPadding),
//       decoration: CardDecorationHelper.getWhiteCardDecoration(),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Row(
//             children: [
//               Icon(Icons.donut_small, color: AppConstants.primaryColor),
//               SizedBox(width: 8),
//               Text(
//                 'Risk Distribution',
//                 style: TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.black87,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 20),
//           Row(
//             children: [
//               SizedBox(
//                 width: 120,
//                 height: 120,
//                 child: Stack(
//                   alignment: Alignment.center,
//                   children: [
//                     CustomPaint(
//                       size: const Size(120, 120),
//                       painter: RiskDonutChartPainter(
//                         severeCount: riskCounts['severe']!,
//                         moderateCount: riskCounts['moderate']!,
//                         mildCount: riskCounts['mild']!,
//                         total: total,
//                       ),
//                     ),
//                     Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         const Text(
//                           'Total',
//                           style: TextStyle(fontSize: 12, color: Colors.grey),
//                         ),
//                         Text(
//                           '$total',
//                           style: const TextStyle(
//                             fontSize: 24,
//                             fontWeight: FontWeight.bold,
//                             color: Colors.black87,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(width: 24),
//               Expanded(
//                 child: Column(
//                   children: [
//                     _buildRiskLegendItem(
//                       'Severe',
//                       riskCounts['severe']!,
//                       total,
//                       RiskHelper.getRiskColor('severe'),
//                     ),
//                     const SizedBox(height: 12),
//                     _buildRiskLegendItem(
//                       'Moderate',
//                       riskCounts['moderate']!,
//                       total,
//                       RiskHelper.getRiskColor('moderate'),
//                     ),
//                     const SizedBox(height: 12),
//                     _buildRiskLegendItem(
//                       'Mild',
//                       riskCounts['mild']!,
//                       total,
//                       RiskHelper.getRiskColor('mild'),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildRiskLegendItem(String label, int count, int total, Color color) {
//     final percentage = total == 0 ? 0.0 : (count / total * 100);

//     return Row(
//       children: [
//         Container(
//           width: 16,
//           height: 16,
//           decoration: BoxDecoration(color: color, shape: BoxShape.circle),
//         ),
//         const SizedBox(width: 8),
//         Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 label,
//                 style: TextStyle(
//                   fontSize: 14,
//                   fontWeight: FontWeight.w600,
//                   color: color,
//                 ),
//               ),
//               Text(
//                 '$count (${percentage.toStringAsFixed(1)}%)',
//                 style: TextStyle(fontSize: 11, color: Colors.grey[600]),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildTopAllergensSection() {
//     final allergenCounts = AllergenStatsHelper.calculateAllergenCounts(
//       allergenHistory,
//     );
//     final Map<String, String> allergenRiskLevels = {};

//     for (var entry in allergenHistory) {
//       final name = entry['allergenName'] as String;
//       allergenRiskLevels[name] = entry['riskLevel'] as String;
//     }

//     final sortedAllergens =
//         allergenCounts.entries.toList()
//           ..sort((a, b) => b.value.compareTo(a.value));

//     final topAllergens =
//         sortedAllergens.take(AppConstants.topAllergensCount).toList();

//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.all(AppConstants.cardPadding),
//       decoration: CardDecorationHelper.getWhiteCardDecoration(),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Row(
//             children: [
//               Icon(Icons.trending_up, color: AppConstants.primaryColor),
//               SizedBox(width: 8),
//               Text(
//                 'Top 5 Allergens',
//                 style: TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.black87,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),
//           ...topAllergens.asMap().entries.map((mapEntry) {
//             final index = mapEntry.key;
//             final entry = mapEntry.value;
//             final percentage = (entry.value / allergenHistory.length * 100);
//             final riskColor = RiskHelper.getRiskColor(
//               allergenRiskLevels[entry.key]!,
//             );

//             return Container(
//               margin: const EdgeInsets.only(bottom: 12),
//               padding: const EdgeInsets.all(16),
//               decoration: BoxDecoration(
//                 gradient: LinearGradient(
//                   colors: [
//                     riskColor.withOpacity(0.1),
//                     riskColor.withOpacity(0.05),
//                   ],
//                   begin: Alignment.centerLeft,
//                   end: Alignment.centerRight,
//                 ),
//                 borderRadius: BorderRadius.circular(
//                   AppConstants.smallCardBorderRadius,
//                 ),
//                 border: Border.all(color: riskColor.withOpacity(0.3)),
//               ),
//               child: Row(
//                 children: [
//                   Container(
//                     width: 32,
//                     height: 32,
//                     decoration: BoxDecoration(
//                       color: riskColor,
//                       shape: BoxShape.circle,
//                     ),
//                     child: Center(
//                       child: Text(
//                         '${index + 1}',
//                         style: const TextStyle(
//                           color: Colors.white,
//                           fontWeight: FontWeight.bold,
//                           fontSize: 14,
//                         ),
//                       ),
//                     ),
//                   ),
//                   const SizedBox(width: 12),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           entry.key,
//                           style: const TextStyle(
//                             fontSize: 15,
//                             fontWeight: FontWeight.w600,
//                             color: Colors.black87,
//                           ),
//                         ),
//                         const SizedBox(height: 4),
//                         Row(
//                           children: [
//                             Expanded(
//                               child: ClipRRect(
//                                 borderRadius: BorderRadius.circular(4),
//                                 child: LinearProgressIndicator(
//                                   value: percentage / 100,
//                                   backgroundColor: Colors.grey[200],
//                                   valueColor: AlwaysStoppedAnimation<Color>(
//                                     riskColor,
//                                   ),
//                                   minHeight: 6,
//                                 ),
//                               ),
//                             ),
//                             const SizedBox(width: 8),
//                             Text(
//                               '${entry.value}x',
//                               style: TextStyle(
//                                 fontSize: 12,
//                                 fontWeight: FontWeight.bold,
//                                 color: Colors.grey[700],
//                               ),
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             );
//           }).toList(),
//         ],
//       ),
//     );
//   }

//   Widget _buildRecentExposuresSection() {
//     final recentExposures =
//         allergenHistory.take(AppConstants.recentExposuresCount).toList();

//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.all(AppConstants.cardPadding),
//       decoration: CardDecorationHelper.getWhiteCardDecoration(),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Row(
//             children: [
//               Icon(Icons.history, color: AppConstants.primaryColor),
//               SizedBox(width: 8),
//               Text(
//                 'Recent Exposures',
//                 style: TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.black87,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),
//           ...recentExposures.map((exposure) {
//             final timestamp = exposure['timestamp'] as DateTime;
//             final timeAgo = TimeHelper.getTimeAgo(timestamp);
//             final riskColor = RiskHelper.getRiskColor(
//               exposure['riskLevel'] as String,
//             );

//             return Container(
//               margin: const EdgeInsets.only(bottom: 12),
//               padding: const EdgeInsets.all(14),
//               decoration: BoxDecoration(
//                 color: Colors.grey[50],
//                 borderRadius: BorderRadius.circular(
//                   AppConstants.smallCardBorderRadius,
//                 ),
//                 border: Border.all(color: Colors.grey[200]!),
//               ),
//               child: Row(
//                 children: [
//                   Container(
//                     width: 6,
//                     height: 50,
//                     decoration: BoxDecoration(
//                       color: riskColor,
//                       borderRadius: BorderRadius.circular(3),
//                     ),
//                   ),
//                   const SizedBox(width: 14),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Row(
//                           children: [
//                             Expanded(
//                               child: Text(
//                                 exposure['allergenName'] as String,
//                                 style: const TextStyle(
//                                   fontSize: 15,
//                                   fontWeight: FontWeight.w600,
//                                   color: Colors.black87,
//                                 ),
//                               ),
//                             ),
//                             Container(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 8,
//                                 vertical: 4,
//                               ),
//                               decoration: BoxDecoration(
//                                 color: riskColor.withOpacity(0.2),
//                                 borderRadius: BorderRadius.circular(8),
//                               ),
//                               child: Text(
//                                 (exposure['riskLevel'] as String).toUpperCase(),
//                                 style: TextStyle(
//                                   fontSize: 10,
//                                   fontWeight: FontWeight.bold,
//                                   color: riskColor,
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                         const SizedBox(height: 6),
//                         Row(
//                           children: [
//                             Icon(
//                               Icons.restaurant,
//                               size: 14,
//                               color: Colors.grey[600],
//                             ),
//                             const SizedBox(width: 4),
//                             Expanded(
//                               child: Text(
//                                 exposure['dishName'] as String,
//                                 style: TextStyle(
//                                   fontSize: 13,
//                                   color: Colors.grey[600],
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                         const SizedBox(height: 4),
//                         Row(
//                           children: [
//                             Icon(
//                               Icons.access_time,
//                               size: 12,
//                               color: Colors.grey[500],
//                             ),
//                             const SizedBox(width: 4),
//                             Text(
//                               timeAgo,
//                               style: TextStyle(
//                                 fontSize: 11,
//                                 color: Colors.grey[500],
//                               ),
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             );
//           }).toList(),
//         ],
//       ),
//     );
//   }

//   Widget _buildAirQualityAllergenInsights() {
//     final aqi = airQualityData.aqi;
//     final qualityLevel = AQIHelper.getQualityLevel(aqi);
//     final aqiColor = AQIHelper.getAQIColor(aqi);
//     final aqiIcon = AQIHelper.getAQIIcon(aqi);

//     String insightTitle;
//     String insightMessage;

//     if (aqi <= 50) {
//       insightTitle = 'Excellent Conditions';
//       insightMessage =
//           'Air quality is optimal. Your allergen symptoms are less likely to be aggravated by environmental factors.';
//     } else if (aqi <= 100) {
//       insightTitle = 'Moderate Conditions';
//       insightMessage =
//           'Air quality is acceptable, but sensitive individuals may experience mild discomfort with allergens.';
//     } else if (aqi <= 150) {
//       insightTitle = 'Increased Sensitivity';
//       insightMessage =
//           'Poor air quality can worsen allergen reactions. Take extra precautions with known triggers.';
//     } else {
//       insightTitle = 'High Alert';
//       insightMessage =
//           'Very poor air quality significantly increases allergen sensitivity. Strictly avoid all triggers.';
//     }

//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.all(AppConstants.cardPadding),
//       decoration: CardDecorationHelper.getWhiteCardDecoration(),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Row(
//             children: [
//               Icon(Icons.insights, color: AppConstants.primaryColor),
//               SizedBox(width: 8),
//               Text(
//                 'Air Quality Impact',
//                 style: TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.black87,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),
//           Container(
//             padding: const EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               gradient: LinearGradient(
//                 colors: [
//                   aqiColor.withOpacity(0.15),
//                   aqiColor.withOpacity(0.05),
//                 ],
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//               ),
//               borderRadius: BorderRadius.circular(
//                 AppConstants.smallCardBorderRadius,
//               ),
//               border: Border.all(color: aqiColor.withOpacity(0.4), width: 2),
//             ),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   children: [
//                     Container(
//                       padding: const EdgeInsets.all(8),
//                       decoration: BoxDecoration(
//                         color: aqiColor.withOpacity(0.2),
//                         shape: BoxShape.circle,
//                       ),
//                       child: Icon(aqiIcon, color: aqiColor, size: 24),
//                     ),
//                     const SizedBox(width: 12),
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             insightTitle,
//                             style: TextStyle(
//                               fontSize: 16,
//                               fontWeight: FontWeight.bold,
//                               color: aqiColor,
//                             ),
//                           ),
//                           Text(
//                             'AQI: ${airQualityData.aqi} - $qualityLevel',
//                             style: TextStyle(
//                               fontSize: 12,
//                               color: Colors.grey[600],
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 12),
//                 Text(
//                   insightMessage,
//                   style: const TextStyle(
//                     fontSize: 14,
//                     color: Colors.black87,
//                     height: 1.5,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           const SizedBox(height: 16),
//           const Text(
//             'Recommendations:',
//             style: TextStyle(
//               fontSize: 15,
//               fontWeight: FontWeight.w600,
//               color: Colors.black87,
//             ),
//           ),
//           const SizedBox(height: 12),
//           ..._getAllergenRecommendations(aqi).map((rec) {
//             return Container(
//               margin: const EdgeInsets.only(bottom: 8),
//               padding: const EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 color: Colors.grey[50],
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: Row(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Container(
//                     margin: const EdgeInsets.only(top: 2),
//                     padding: const EdgeInsets.all(4),
//                     decoration: const BoxDecoration(
//                       color: AppConstants.primaryColor,
//                       shape: BoxShape.circle,
//                     ),
//                     child: const Icon(
//                       Icons.check,
//                       size: 12,
//                       color: Colors.white,
//                     ),
//                   ),
//                   const SizedBox(width: 10),
//                   Expanded(
//                     child: Text(
//                       rec,
//                       style: TextStyle(
//                         fontSize: 13,
//                         color: Colors.grey[700],
//                         height: 1.4,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             );
//           }).toList(),
//         ],
//       ),
//     );
//   }

//   List<String> _getAllergenRecommendations(int aqi) {
//     if (aqi <= 50) {
//       return [
//         'Safe to engage in outdoor activities',
//         'Normal allergen management routine',
//         'Good time to introduce new foods cautiously',
//         'Maintain regular exercise schedule',
//       ];
//     } else if (aqi <= 100) {
//       return [
//         'Monitor your allergen symptoms more closely',
//         'Keep antihistamines accessible',
//         'Limit prolonged outdoor exposure',
//         'Stay hydrated to help manage symptoms',
//       ];
//     } else if (aqi <= 150) {
//       return [
//         'Reduce outdoor activities significantly',
//         'Keep windows closed indoors',
//         'Strictly avoid known allergen triggers',
//         'Have emergency medications ready',
//         'Consider using air purifiers',
//       ];
//     } else {
//       return [
//         'Stay indoors as much as possible',
//         'Use HEPA air purifiers in your home',
//         'Strictly avoid all allergen triggers',
//         'Keep emergency medications immediately accessible',
//         'Postpone introduction of new foods',
//         'Contact healthcare provider if symptoms worsen',
//       ];
//     }
//   }
// }

// // Custom Painter for Risk Donut Chart
// class RiskDonutChartPainter extends CustomPainter {
//   final int severeCount;
//   final int moderateCount;
//   final int mildCount;
//   final int total;

//   RiskDonutChartPainter({
//     required this.severeCount,
//     required this.moderateCount,
//     required this.mildCount,
//     required this.total,
//   });

//   @override
//   void paint(Canvas canvas, Size size) {
//     if (total == 0) return;

//     final center = Offset(size.width / 2, size.height / 2);
//     final radius = size.width / 2;
//     final strokeWidth = 20.0;

//     final paint =
//         Paint()
//           ..style = PaintingStyle.stroke
//           ..strokeWidth = strokeWidth
//           ..strokeCap = StrokeCap.round;

//     double startAngle = -math.pi / 2;

//     // Draw severe segment
//     if (severeCount > 0) {
//       final sweepAngle = (severeCount / total) * 2 * math.pi;
//       paint.color = RiskHelper.getRiskColor('severe');
//       canvas.drawArc(
//         Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
//         startAngle,
//         sweepAngle,
//         false,
//         paint,
//       );
//       startAngle += sweepAngle;
//     }

//     // Draw moderate segment
//     if (moderateCount > 0) {
//       final sweepAngle = (moderateCount / total) * 2 * math.pi;
//       paint.color = RiskHelper.getRiskColor('moderate');
//       canvas.drawArc(
//         Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
//         startAngle,
//         sweepAngle,
//         false,
//         paint,
//       );
//       startAngle += sweepAngle;
//     }

//     // Draw mild segment
//     if (mildCount > 0) {
//       final sweepAngle = (mildCount / total) * 2 * math.pi;
//       paint.color = RiskHelper.getRiskColor('mild');
//       canvas.drawArc(
//         Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
//         startAngle,
//         sweepAngle,
//         false,
//         paint,
//       );
//     }
//   }

//   @override
//   bool shouldRepaint(RiskDonutChartPainter oldDelegate) {
//     return severeCount != oldDelegate.severeCount ||
//         moderateCount != oldDelegate.moderateCount ||
//         mildCount != oldDelegate.mildCount ||
//         total != oldDelegate.total;
//   }
// }
