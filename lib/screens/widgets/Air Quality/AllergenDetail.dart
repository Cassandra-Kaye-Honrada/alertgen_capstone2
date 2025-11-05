// import 'package:flutter/material.dart';

// Widget _buildAllergenAnalyticsTab() {
//   if (_isLoadingHistory) {
//     return const Center(
//       child: CircularProgressIndicator(
//         valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0B8FAC)),
//       ),
//     );
//   }

//   if (_allergenHistory.isEmpty) {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(Icons.analytics_outlined, size: 80, color: Colors.grey[300]),
//           const SizedBox(height: 16),
//           Text(
//             'No allergen history available',
//             style: TextStyle(fontSize: 16, color: Colors.grey[600]),
//           ),
//           const SizedBox(height: 8),
//           Text(
//             'Start scanning food to build your allergen profile',
//             style: TextStyle(fontSize: 14, color: Colors.grey[500]),
//             textAlign: TextAlign.center,
//           ),
//         ],
//       ),
//     );
//   }

//   return SingleChildScrollView(
//     padding: const EdgeInsets.all(16),
//     child: Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         _buildAllergenSummaryCard(),
//         const SizedBox(height: 24),
//         _buildTopAllergensSection(),
//         const SizedBox(height: 24),
//         _buildRiskDistributionSection(),
//         const SizedBox(height: 24),
//         _buildRecentExposuresSection(),
//         const SizedBox(height: 24),
//         _buildAirQualityAllergenInsights(),
//       ],
//     ),
//   );
// }

// Widget _buildAllergenSummaryCard() {
//   final totalExposures = _allergenHistory.length;
//   final uniqueAllergens =
//       _allergenHistory.map((e) => e['allergenName'] as String).toSet().length;
//   final last7Days =
//       _allergenHistory
//           .where(
//             (e) => (e['timestamp'] as DateTime).isAfter(
//               DateTime.now().subtract(const Duration(days: 7)),
//             ),
//           )
//           .length;

//   return Container(
//     width: double.infinity,
//     padding: const EdgeInsets.all(20),
//     decoration: BoxDecoration(
//       gradient: const LinearGradient(
//         colors: [Color(0xFF0B8FAC), Color(0xFF0FA3C7)],
//         begin: Alignment.topLeft,
//         end: Alignment.bottomRight,
//       ),
//       borderRadius: BorderRadius.circular(16),
//       boxShadow: [
//         BoxShadow(
//           color: const Color(0xFF0B8FAC).withOpacity(0.3),
//           blurRadius: 10,
//           offset: const Offset(0, 4),
//         ),
//       ],
//     ),
//     child: Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const Text(
//           'Your Allergen Profile',
//           style: TextStyle(
//             fontSize: 20,
//             fontWeight: FontWeight.bold,
//             color: Colors.white,
//           ),
//         ),
//         const SizedBox(height: 20),
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceAround,
//           children: [
//             _buildSummaryItem('Total Exposures', '$totalExposures'),
//             _buildSummaryItem('Unique Allergens', '$uniqueAllergens'),
//             _buildSummaryItem('Last 7 Days', '$last7Days'),
//           ],
//         ),
//       ],
//     ),
//   );
// }

// Widget _buildSummaryItem(String label, String value) {
//   return Column(
//     children: [
//       Text(
//         value,
//         style: const TextStyle(
//           fontSize: 28,
//           fontWeight: FontWeight.bold,
//           color: Colors.white,
//         ),
//       ),
//       const SizedBox(height: 4),
//       Text(
//         label,
//         style: const TextStyle(fontSize: 12, color: Colors.white70),
//         textAlign: TextAlign.center,
//       ),
//     ],
//   );
// }

// Widget _buildTopAllergensSection() {
//   // Count allergen occurrences
//   final Map<String, int> allergenCounts = {};
//   final Map<String, String> allergenRiskLevels = {};

//   for (var entry in _allergenHistory) {
//     final name = entry['allergenName'] as String;
//     allergenCounts[name] = (allergenCounts[name] ?? 0) + 1;
//     allergenRiskLevels[name] = entry['riskLevel'] as String;
//   }

//   // Sort by count
//   final sortedAllergens =
//       allergenCounts.entries.toList()
//         ..sort((a, b) => b.value.compareTo(a.value));

//   final topAllergens = sortedAllergens.take(5).toList();

//   return Container(
//     width: double.infinity,
//     padding: const EdgeInsets.all(20),
//     decoration: BoxDecoration(
//       color: Colors.white,
//       borderRadius: BorderRadius.circular(16),
//       boxShadow: [
//         BoxShadow(
//           color: Colors.black.withOpacity(0.1),
//           blurRadius: 10,
//           offset: const Offset(0, 2),
//         ),
//       ],
//     ),
//     child: Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const Row(
//           children: [
//             Icon(Icons.trending_up, color: Color(0xFF0B8FAC)),
//             SizedBox(width: 8),
//             Text(
//               'Most Frequent Allergens',
//               style: TextStyle(
//                 fontSize: 18,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.black87,
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 16),
//         ...topAllergens.map((entry) {
//           final percentage = (entry.value / _allergenHistory.length * 100);
//           final riskColor = _getRiskColor(allergenRiskLevels[entry.key]!);
//           return Padding(
//             padding: const EdgeInsets.only(bottom: 16),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Expanded(
//                       child: Text(
//                         entry.key,
//                         style: const TextStyle(
//                           fontSize: 14,
//                           fontWeight: FontWeight.w600,
//                           color: Colors.black87,
//                         ),
//                       ),
//                     ),
//                     Text(
//                       '${entry.value} times (${percentage.toStringAsFixed(1)}%)',
//                       style: TextStyle(fontSize: 12, color: Colors.grey[600]),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 8),
//                 ClipRRect(
//                   borderRadius: BorderRadius.circular(4),
//                   child: LinearProgressIndicator(
//                     value: percentage / 100,
//                     backgroundColor: Colors.grey[200],
//                     valueColor: AlwaysStoppedAnimation<Color>(riskColor),
//                     minHeight: 8,
//                   ),
//                 ),
//               ],
//             ),
//           );
//         }).toList(),
//       ],
//     ),
//   );
// }

// Widget _buildRiskDistributionSection() {
//   final Map<String, int> riskCounts = {'severe': 0, 'moderate': 0, 'mild': 0};

//   for (var entry in _allergenHistory) {
//     final risk = (entry['riskLevel'] as String).toLowerCase();
//     riskCounts[risk] = (riskCounts[risk] ?? 0) + 1;
//   }

//   return Container(
//     width: double.infinity,
//     padding: const EdgeInsets.all(20),
//     decoration: BoxDecoration(
//       color: Colors.white,
//       borderRadius: BorderRadius.circular(16),
//       boxShadow: [
//         BoxShadow(
//           color: Colors.black.withOpacity(0.1),
//           blurRadius: 10,
//           offset: const Offset(0, 2),
//         ),
//       ],
//     ),
//     child: Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const Row(
//           children: [
//             Icon(Icons.pie_chart, color: Color(0xFF0B8FAC)),
//             SizedBox(width: 8),
//             Text(
//               'Risk Level Distribution',
//               style: TextStyle(
//                 fontSize: 18,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.black87,
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 20),
//         _buildRiskLevelCard(
//           'Severe',
//           riskCounts['severe']!,
//           Colors.red,
//           Icons.warning,
//         ),
//         const SizedBox(height: 12),
//         _buildRiskLevelCard(
//           'Moderate',
//           riskCounts['moderate']!,
//           Colors.orange,
//           Icons.info,
//         ),
//         const SizedBox(height: 12),
//         _buildRiskLevelCard(
//           'Mild',
//           riskCounts['mild']!,
//           Colors.yellow[700]!,
//           Icons.check_circle_outline,
//         ),
//       ],
//     ),
//   );
// }

// Widget _buildRiskLevelCard(
//   String level,
//   int count,
//   Color color,
//   IconData icon,
// ) {
//   final percentage =
//       _allergenHistory.isEmpty ? 0.0 : (count / _allergenHistory.length * 100);

//   return Container(
//     padding: const EdgeInsets.all(16),
//     decoration: BoxDecoration(
//       color: color.withOpacity(0.1),
//       borderRadius: BorderRadius.circular(12),
//       border: Border.all(color: color.withOpacity(0.3)),
//     ),
//     child: Row(
//       children: [
//         Container(
//           padding: const EdgeInsets.all(8),
//           decoration: BoxDecoration(
//             color: color.withOpacity(0.2),
//             shape: BoxShape.circle,
//           ),
//           child: Icon(icon, color: color, size: 24),
//         ),
//         const SizedBox(width: 16),
//         Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 level,
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.w600,
//                   color: color,
//                 ),
//               ),
//               const SizedBox(height: 4),
//               Text(
//                 '$count exposures (${percentage.toStringAsFixed(1)}%)',
//                 style: TextStyle(fontSize: 12, color: Colors.grey[600]),
//               ),
//             ],
//           ),
//         ),
//       ],
//     ),
//   );
// }

// Widget _buildRecentExposuresSection() {
//   final recentExposures = _allergenHistory.take(5).toList();

//   return Container(
//     width: double.infinity,
//     padding: const EdgeInsets.all(20),
//     decoration: BoxDecoration(
//       color: Colors.white,
//       borderRadius: BorderRadius.circular(16),
//       boxShadow: [
//         BoxShadow(
//           color: Colors.black.withOpacity(0.1),
//           blurRadius: 10,
//           offset: const Offset(0, 2),
//         ),
//       ],
//     ),
//     child: Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const Row(
//           children: [
//             Icon(Icons.history, color: Color(0xFF0B8FAC)),
//             SizedBox(width: 8),
//             Text(
//               'Recent Allergen Exposures',
//               style: TextStyle(
//                 fontSize: 18,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.black87,
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 16),
//         ...recentExposures.map((exposure) {
//           final timestamp = exposure['timestamp'] as DateTime;
//           final timeAgo = _getTimeAgo(timestamp);
//           final riskColor = _getRiskColor(exposure['riskLevel'] as String);

//           return Container(
//             margin: const EdgeInsets.only(bottom: 12),
//             padding: const EdgeInsets.all(12),
//             decoration: BoxDecoration(
//               color: Colors.grey[50],
//               borderRadius: BorderRadius.circular(8),
//               border: Border.all(color: Colors.grey[200]!),
//             ),
//             child: Row(
//               children: [
//                 Container(
//                   width: 8,
//                   height: 40,
//                   decoration: BoxDecoration(
//                     color: riskColor,
//                     borderRadius: BorderRadius.circular(4),
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         exposure['allergenName'] as String,
//                         style: const TextStyle(
//                           fontSize: 14,
//                           fontWeight: FontWeight.w600,
//                           color: Colors.black87,
//                         ),
//                       ),
//                       const SizedBox(height: 4),
//                       Text(
//                         'Found in: ${exposure['dishName']}',
//                         style: TextStyle(fontSize: 12, color: Colors.grey[600]),
//                       ),
//                       const SizedBox(height: 2),
//                       Text(
//                         timeAgo,
//                         style: TextStyle(fontSize: 11, color: Colors.grey[500]),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           );
//         }).toList(),
//       ],
//     ),
//   );
// }

// Widget _buildAirQualityAllergenInsights() {
//   final aqi = widget.airQualityData.aqi;
//   String insightTitle;
//   String insightMessage;
//   IconData insightIcon;
//   Color insightColor;

//   if (aqi <= 50) {
//     insightTitle = 'Good Conditions for Allergen Management';
//     insightMessage =
//         'Current air quality is excellent. Your allergen symptoms are less likely to be aggravated by environmental factors.';
//     insightIcon = Icons.wb_sunny;
//     insightColor = Colors.green;
//   } else if (aqi <= 100) {
//     insightTitle = 'Moderate Impact on Allergen Sensitivity';
//     insightMessage =
//         'Air quality is acceptable, but sensitive individuals with allergens may experience mild discomfort.';
//     insightIcon = Icons.cloud;
//     insightColor = Colors.yellow[700]!;
//   } else {
//     insightTitle = 'High Alert: Enhanced Allergen Sensitivity';
//     insightMessage =
//         'Poor air quality can worsen allergen reactions. Take extra precautions and avoid trigger foods.';
//     insightIcon = Icons.warning;
//     insightColor = Colors.red;
//   }

//   return Container(
//     width: double.infinity,
//     padding: const EdgeInsets.all(20),
//     decoration: BoxDecoration(
//       color: Colors.white,
//       borderRadius: BorderRadius.circular(16),
//       boxShadow: [
//         BoxShadow(
//           color: Colors.black.withOpacity(0.1),
//           blurRadius: 10,
//           offset: const Offset(0, 2),
//         ),
//       ],
//     ),
//     child: Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           children: [
//             Icon(insightIcon, color: insightColor),
//             const SizedBox(width: 8),
//             const Expanded(
//               child: Text(
//                 'Air Quality & Allergen Insights',
//                 style: TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.black87,
//                 ),
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 16),
//         Container(
//           padding: const EdgeInsets.all(16),
//           decoration: BoxDecoration(
//             color: insightColor.withOpacity(0.1),
//             borderRadius: BorderRadius.circular(12),
//             border: Border.all(color: insightColor.withOpacity(0.3)),
//           ),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 insightTitle,
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.w600,
//                   color: insightColor,
//                 ),
//               ),
//               const SizedBox(height: 8),
//               Text(
//                 insightMessage,
//                 style: const TextStyle(
//                   fontSize: 14,
//                   color: Colors.black87,
//                   height: 1.5,
//                 ),
//               ),
//             ],
//           ),
//         ),
//         const SizedBox(height: 16),
//         const Text(
//           'Recommendations:',
//           style: TextStyle(
//             fontSize: 14,
//             fontWeight: FontWeight.w600,
//             color: Colors.black87,
//           ),
//         ),
//         const SizedBox(height: 8),
//         ..._getAllergenRecommendations(aqi).map((rec) {
//           return Padding(
//             padding: const EdgeInsets.only(bottom: 8),
//             child: Row(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Icon(
//                   Icons.check_circle,
//                   size: 16,
//                   color: const Color(0xFF0B8FAC),
//                 ),
//                 const SizedBox(width: 8),
//                 Expanded(
//                   child: Text(
//                     rec,
//                     style: TextStyle(
//                       fontSize: 13,
//                       color: Colors.grey[700],
//                       height: 1.4,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           );
//         }).toList(),
//       ],
//     ),
//   );
// }

// Widget _buildAirQualityAllergenInsights() {
//   final aqi = widget.airQualityData.aqi;
//   String insightTitle;
//   String insightMessage;
//   IconData insightIcon;
//   Color insightColor;

//   if (aqi <= 50) {
//     insightTitle = 'Good Conditions for Allergen Management';
//     insightMessage =
//         'Current air quality is excellent. Your allergen symptoms are less likely to be aggravated by environmental factors.';
//     insightIcon = Icons.wb_sunny;
//     insightColor = Colors.green;
//   } else if (aqi <= 100) {
//     insightTitle = 'Moderate Impact on Allergen Sensitivity';
//     insightMessage =
//         'Air quality is acceptable, but sensitive individuals with allergens may experience mild discomfort.';
//     insightIcon = Icons.cloud;
//     insightColor = Colors.yellow[700]!;
//   } else {
//     insightTitle = 'High Alert: Enhanced Allergen Sensitivity';
//     insightMessage =
//         'Poor air quality can worsen allergen reactions. Take extra precautions and avoid trigger foods.';
//     insightIcon = Icons.warning;
//     insightColor = Colors.red;
//   }

//   return Container(
//     width: double.infinity,
//     padding: const EdgeInsets.all(20),
//     decoration: BoxDecoration(
//       color: Colors.white,
//       borderRadius: BorderRadius.circular(16),
//       boxShadow: [
//         BoxShadow(
//           color: Colors.black.withOpacity(0.1),
//           blurRadius: 10,
//           offset: const Offset(0, 2),
//         ),
//       ],
//     ),
//     child: Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           children: [
//             Icon(insightIcon, color: insightColor),
//             const SizedBox(width: 8),
//             const Expanded(
//               child: Text(
//                 'Air Quality & Allergen Insights',
//                 style: TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.black87,
//                 ),
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 16),
//         Container(
//           padding: const EdgeInsets.all(16),
//           decoration: BoxDecoration(
//             color: insightColor.withOpacity(0.1),
//             borderRadius: BorderRadius.circular(12),
//             border: Border.all(color: insightColor.withOpacity(0.3)),
//           ),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 insightTitle,
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.w600,
//                   color: insightColor,
//                 ),
//               ),
//               const SizedBox(height: 8),
//               Text(
//                 insightMessage,
//                 style: const TextStyle(
//                   fontSize: 14,
//                   color: Colors.black87,
//                   height: 1.5,
//                 ),
//               ),
//             ],
//           ),
//         ),
//         const SizedBox(height: 16),
//         const Text(
//           'Recommendations:',
//           style: TextStyle(
//             fontSize: 14,
//             fontWeight: FontWeight.w600,
//             color: Colors.black87,
//           ),
//         ),
//         const SizedBox(height: 8),
//         ..._getAllergenRecommendations(aqi).map((rec) {
//           return Padding(
//             padding: const EdgeInsets.only(bottom: 8),
//             child: Row(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Icon(
//                   Icons.check_circle,
//                   size: 16,
//                   color: const Color(0xFF0B8FAC),
//                 ),
//                 const SizedBox(width: 8),
//                 Expanded(
//                   child: Text(
//                     rec,
//                     style: TextStyle(
//                       fontSize: 13,
//                       color: Colors.grey[700],
//                       height: 1.4,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           );
//         }).toList(),
//       ],
//     ),
//   );
// }

// List<String> _getAllergenRecommendations(int aqi) {
//   if (aqi <= 50) {
//     return [
//       'Safe to engage in outdoor activities',
//       'Normal allergen management routine',
//       'Good time to introduce new foods cautiously',
//     ];
//   } else if (aqi <= 100) {
//     return [
//       'Monitor your allergen symptoms more closely',
//       'Keep antihistamines accessible',
//       'Avoid prolonged outdoor exposure',
//       'Stay hydrated to help manage symptoms',
//     ];
//   } else {
//     return [
//       'Stay indoors as much as possible',
//       'Use air purifiers in your home',
//       'Strictly avoid known allergen triggers',
//       'Keep emergency medications readily available',
//       'Consider postponing introduction of new foods',
//     ];
//   }
// }

// Color _getRiskColor(String riskLevel) {
//   switch (riskLevel.toLowerCase()) {
//     case 'severe':
//       return Colors.red;
//     case 'moderate':
//       return Colors.orange;
//     case 'mild':
//       return Colors.yellow[700]!;
//     default:
//       return Colors.grey;
//   }
// }

// String _getTimeAgo(DateTime dateTime) {
//   final difference = DateTime.now().difference(dateTime);
//   if (difference.inDays > 0) {
//     return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
//   } else if (difference.inHours > 0) {
//     return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
//   } else if (difference.inMinutes > 0) {
//     return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
//   } else {
//     return 'Just now';
//   }
// }
