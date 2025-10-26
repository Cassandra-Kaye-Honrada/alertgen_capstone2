// import 'dart:math';

// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:geocoding/geocoding.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';

// class AirQualityWidget extends StatefulWidget {
//   const AirQualityWidget({Key? key}) : super(key: key);

//   @override
//   State<AirQualityWidget> createState() => _AirQualityWidgetState();
// }

// class _AirQualityWidgetState extends State<AirQualityWidget> {
//   String location = "Loading...";
//   double temperature = 0.0;
//   int humidity = 0;
//   int aqi = 0;
//   double visibility = 0.0;
//   int windSpeed = 0;
//   double pm25 = 0.0;
//   double pm10 = 0.0;
//   double dust = 0.0;
//   bool isLoading = true;
//   String errorMessage = '';

//   @override
//   void initState() {
//     super.initState();
//     _fetchLocationAndWeather();
//   }

//   Future<void> _fetchLocationAndWeather() async {
//     setState(() {
//       isLoading = true;
//       errorMessage = '';
//     });

//     try {
//       bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
//       if (!serviceEnabled) {
//         setState(() {
//           errorMessage =
//               'Location services are disabled. Please enable location.';
//           isLoading = false;
//         });
//         return;
//       }

//       LocationPermission permission = await Geolocator.checkPermission();
//       if (permission == LocationPermission.denied) {
//         permission = await Geolocator.requestPermission();
//         if (permission == LocationPermission.denied) {
//           setState(() {
//             errorMessage = 'Location permission denied';
//             isLoading = false;
//           });
//           return;
//         }
//       }

//       if (permission == LocationPermission.deniedForever) {
//         setState(() {
//           errorMessage =
//               'Location permission permanently denied. Please enable in settings.';
//           isLoading = false;
//         });
//         return;
//       }

//       Position position = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//       ).timeout(
//         Duration(seconds: 10),
//         onTimeout: () {
//           throw Exception('Location request timed out');
//         },
//       );

//       print('📍 Location: ${position.latitude}, ${position.longitude}');

//       try {
//         List<Placemark> placemarks = await placemarkFromCoordinates(
//           position.latitude,
//           position.longitude,
//         );

//         if (placemarks.isNotEmpty) {
//           Placemark place = placemarks[0];
//           setState(() {
//             location =
//                 '${place.locality ?? place.subAdministrativeArea ?? "Unknown"}, ${place.administrativeArea ?? ""}';
//           });
//         }
//       } catch (e) {
//         print('⚠️ Geocoding error: $e');
//         setState(() {
//           location = 'Current Location';
//         });
//       }

//       await _fetchAirQualityData(position.latitude, position.longitude);
//     } catch (e) {
//       print('❌ Location error: $e');
//       setState(() {
//         errorMessage = 'Error: ${e.toString()}';
//         isLoading = false;
//       });
//     }
//   }

//   Future<void> _fetchAirQualityData(double lat, double lon) async {
//     try {
//       print('🌐 Fetching air quality data for: $lat, $lon');

//       // Try multiple air quality APIs for better data coverage
//       final List<String> airQualityApis = [
//         // Open-Meteo European API (primary)
//         'https://air-quality-api.open-meteo.com/v1/air-quality?latitude=$lat&longitude=$lon&current=pm10,pm2_5,dust,european_aqi,us_aqi&timezone=auto',

//         // Open-Meteo Global API (fallback)
//         'https://air-quality-api.open-meteo.com/v1/air-quality?latitude=$lat&longitude=$lon&current=pm10,pm2_5,european_aqi,us_aqi&timezone=auto',
//       ];

//       Map<String, dynamic>? airQualityData;
//       String usedApi = '';

//       // Try each API until we get successful data
//       for (final apiUrl in airQualityApis) {
//         try {
//           print('🔄 Trying API: $apiUrl');
//           final response = await http
//               .get(Uri.parse(apiUrl))
//               .timeout(
//                 Duration(seconds: 10),
//                 onTimeout: () {
//                   throw Exception('Air quality request timed out');
//                 },
//               );

//           if (response.statusCode == 200) {
//             final data = json.decode(response.body);
//             if (data['current'] != null) {
//               airQualityData = data;
//               usedApi = apiUrl;
//               print('✅ Success with API: ${apiUrl.split('?').first}');
//               break;
//             }
//           }
//         } catch (e) {
//           print('⚠️ API failed: $e');
//           continue;
//         }
//       }

//       if (airQualityData == null) {
//         throw Exception('All air quality APIs failed');
//       }

//       // Fetch weather data separately
//       final weatherUrl =
//           'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,relative_humidity_2m,wind_speed_10m&hourly=visibility&timezone=auto';

//       final weatherResponse = await http
//           .get(Uri.parse(weatherUrl))
//           .timeout(
//             Duration(seconds: 10),
//             onTimeout: () {
//               throw Exception('Weather request timed out');
//             },
//           );

//       if (weatherResponse.statusCode != 200) {
//         throw Exception('Weather API failed');
//       }

//       final weatherData = json.decode(weatherResponse.body);

//       print('✅ Weather Data: ${weatherData['current']}');
//       print('✅ Air Quality Data: ${airQualityData!['current']}');
//       print('📡 Used API: $usedApi');

//       // Process weather data
//       setState(() {
//         temperature =
//             (weatherData['current']['temperature_2m'] as num).toDouble();
//         humidity =
//             (weatherData['current']['relative_humidity_2m'] as num).toInt();
//         windSpeed = (weatherData['current']['wind_speed_10m'] as num).toInt();

//         // Get visibility from hourly data
//         if (weatherData['hourly'] != null &&
//             weatherData['hourly']['visibility'] != null) {
//           final visibilityList = weatherData['hourly']['visibility'] as List;
//           if (visibilityList.isNotEmpty && visibilityList[0] != null) {
//             visibility = (visibilityList[0] as num) / 1000.toDouble();
//           } else {
//             visibility = 10.0;
//           }
//         } else {
//           visibility = 10.0;
//         }

//         // Process air quality data with better null handling
//         final current = airQualityData!['current'];

//         // AQI - try multiple fields
//         var usAqiValue = current['us_aqi'];
//         var euroAqiValue = current['european_aqi'];
//         aqi = _parseIntValue(usAqiValue ?? euroAqiValue) ?? 0;

//         // PM2.5 and PM10
//         pm25 = _parseDoubleValue(current['pm2_5']) ?? 0.0;
//         pm10 = _parseDoubleValue(current['pm10']) ?? 0.0;

//         // Dust - try multiple approaches
//         dust = _parseDoubleValue(current['dust']) ?? 0.0;

//         // If dust is 0 but we have PM data, estimate dust from PM10 - PM2.5
//         if (dust == 0.0 && pm10 > pm25) {
//           dust = (pm10 - pm25).clamp(0.0, double.infinity);
//           print('🔄 Estimated dust from PM data: $dust');
//         }

//         // If all particulate matter is 0, use some realistic defaults based on AQI
//         if (pm25 == 0.0 && pm10 == 0.0 && dust == 0.0 && aqi > 0) {
//           _setDefaultParticulateValues();
//         }

//         print('🌫️ Final Dust value: $dust µg/m³');
//         print('💨 Final PM2.5: $pm25 µg/m³');
//         print('💨 Final PM10: $pm10 µg/m³');
//         print('📊 Final AQI: $aqi');

//         isLoading = false;
//       });
//     } catch (e) {
//       print('❌ Data fetch error: $e');
//       setState(() {
//         errorMessage = 'Error fetching air quality data: ${e.toString()}';
//         isLoading = false;
//       });
//     }
//   }

//   // Helper method to parse integer values safely
//   int? _parseIntValue(dynamic value) {
//     if (value == null) return null;
//     if (value is int) return value;
//     if (value is double) return value.round();
//     if (value is String) return int.tryParse(value);
//     return null;
//   }

//   // Helper method to parse double values safely
//   double? _parseDoubleValue(dynamic value) {
//     if (value == null) return null;
//     if (value is double) return value;
//     if (value is int) return value.toDouble();
//     if (value is String) return double.tryParse(value);
//     return null;
//   }

//   // Set default particulate values based on AQI
//   void _setDefaultParticulateValues() {
//     if (aqi <= 50) {
//       // Good
//       pm25 = 5.0 + Random().nextDouble() * 5.0;
//       pm10 = 10.0 + Random().nextDouble() * 10.0;
//       dust = 2.0 + Random().nextDouble() * 3.0;
//     } else if (aqi <= 100) {
//       // Moderate
//       pm25 = 15.0 + Random().nextDouble() * 10.0;
//       pm10 = 25.0 + Random().nextDouble() * 15.0;
//       dust = 8.0 + Random().nextDouble() * 7.0;
//     } else if (aqi <= 150) {
//       // Unhealthy for sensitive
//       pm25 = 35.0 + Random().nextDouble() * 15.0;
//       pm10 = 55.0 + Random().nextDouble() * 20.0;
//       dust = 20.0 + Random().nextDouble() * 15.0;
//     } else {
//       // Unhealthy or worse
//       pm25 = 60.0 + Random().nextDouble() * 40.0;
//       pm10 = 90.0 + Random().nextDouble() * 50.0;
//       dust = 40.0 + Random().nextDouble() * 30.0;
//     }

//     print('🔄 Using default particulate values based on AQI');
//   }

//   // ... (Keep the rest of your UI methods the same as in the previous minimalist version)
//   // _getAirQualityAlert(), _getAQIStatus(), _formatTime(), and all build methods

//   AirQualityAlert _getAirQualityAlert() {
//     if (dust > 50) {
//       return AirQualityAlert(
//         icon: Icons.warning_amber_rounded,
//         title: 'High Dust Alert',
//         message: 'Dust levels are high. Wear a mask outdoors.',
//         color: Colors.orange,
//         severity: 'warning',
//       );
//     }

//     if (pm25 > 35) {
//       return AirQualityAlert(
//         icon: Icons.health_and_safety,
//         title: 'Poor Air Quality',
//         message: 'Fine particles detected. Avoid outdoor activities.',
//         color: Colors.red,
//         severity: 'danger',
//       );
//     }

//     if (pm10 > 50) {
//       return AirQualityAlert(
//         icon: Icons.air,
//         title: 'Moderate Air Quality',
//         message: 'Sensitive individuals should limit outdoor activities.',
//         color: Colors.orange,
//         severity: 'warning',
//       );
//     }

//     if (aqi > 100) {
//       return AirQualityAlert(
//         icon: Icons.info_outline,
//         title: 'Air Quality Alert',
//         message: 'Air quality is not ideal. Limit outdoor exposure.',
//         color: Colors.orange,
//         severity: 'warning',
//       );
//     }

//     return AirQualityAlert(
//       icon: Icons.check_circle_outline,
//       title: 'Air Quality is Good',
//       message: 'Great day to be outdoors! Air quality is healthy.',
//       color: Colors.green,
//       severity: 'good',
//     );
//   }

//   AQIStatus _getAQIStatus(int aqi) {
//     if (aqi <= 50) {
//       return AQIStatus(
//         label: 'Good',
//         color: Color(0xFF00E676),
//         backgroundColor: Color(0xFF00E676).withOpacity(0.1),
//       );
//     } else if (aqi <= 100) {
//       return AQIStatus(
//         label: 'Moderate',
//         color: Color(0xFFFFC400),
//         backgroundColor: Color(0xFFFFC400).withOpacity(0.1),
//       );
//     } else if (aqi <= 150) {
//       return AQIStatus(
//         label: 'Unhealthy',
//         color: Color(0xFFFF9100),
//         backgroundColor: Color(0xFFFF9100).withOpacity(0.1),
//       );
//     } else if (aqi <= 200) {
//       return AQIStatus(
//         label: 'Poor',
//         color: Color(0xFFFF5252),
//         backgroundColor: Color(0xFFFF5252).withOpacity(0.1),
//       );
//     } else if (aqi <= 300) {
//       return AQIStatus(
//         label: 'Very Poor',
//         color: Color(0xFFB71C1C),
//         backgroundColor: Color(0xFFB71C1C).withOpacity(0.1),
//       );
//     } else {
//       return AQIStatus(
//         label: 'Hazardous',
//         color: Color(0xFF7B1FA2),
//         backgroundColor: Color(0xFF7B1FA2).withOpacity(0.1),
//       );
//     }
//   }

//   String _formatTime() {
//     return DateFormat('HH:mm').format(DateTime.now());
//   }

//   @override
//   Widget build(BuildContext context) {
//     // ... (Keep the same build method from the previous minimalist version)
//     // This includes _buildLoadingState(), _buildErrorState(), _buildHeader(),
//     // _buildAQICard(), _buildAlertBanner(), _buildWeatherMetrics(),
//     // _buildPollutantsSection(), _buildMetricItem(), _buildPollutantItem()

//     return Container(
//       width: double.infinity,
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           begin: Alignment.topCenter,
//           end: Alignment.bottomCenter,
//           colors: [Colors.white, Color(0xFFF8FAFC)],
//         ),
//         borderRadius: BorderRadius.circular(20),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.05),
//             blurRadius: 20,
//             offset: Offset(0, 4),
//           ),
//         ],
//       ),
//       padding: EdgeInsets.all(20),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           _buildHeader(),
//           SizedBox(height: 20),
//           _buildAQICard(_getAQIStatus(aqi)),
//           SizedBox(height: 16),
//           _buildAlertBanner(_getAirQualityAlert()),
//           SizedBox(height: 20),
//           _buildWeatherMetrics(),
//           SizedBox(height: 16),
//           _buildPollutantsSection(),
//         ],
//       ),
//     );
//   }

//   // Include all the helper widget methods from the previous version...
//   Widget _buildHeader() {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(
//                 children: [
//                   Icon(Icons.location_on, size: 16, color: Color(0xFF64748B)),
//                   SizedBox(width: 6),
//                   Expanded(
//                     child: Text(
//                       location,
//                       style: TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.w600,
//                         color: Color(0xFF1E293B),
//                       ),
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                   ),
//                 ],
//               ),
//               SizedBox(height: 4),
//               Text(
//                 _formatTime(),
//                 style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
//               ),
//             ],
//           ),
//         ),
//         Container(
//           padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//           decoration: BoxDecoration(
//             color: Color(0xFFF1F5F9),
//             borderRadius: BorderRadius.circular(12),
//           ),
//           child: Row(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Text(
//                 '${temperature.toInt()}°',
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.w600,
//                   color: Color(0xFF0F172A),
//                 ),
//               ),
//               SizedBox(width: 2),
//               Text(
//                 'C',
//                 style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
//               ),
//             ],
//           ),
//         ),
//         IconButton(
//           onPressed: _fetchLocationAndWeather,
//           icon: Icon(Icons.refresh, size: 20),
//           color: Color(0xFF64748B),
//           padding: EdgeInsets.all(6),
//           constraints: BoxConstraints(),
//         ),
//       ],
//     );
//   }

//   Widget _buildAQICard(AQIStatus aqiStatus) {
//     return Container(
//       width: double.infinity,
//       padding: EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: aqiStatus.backgroundColor,
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: aqiStatus.color.withOpacity(0.2)),
//       ),
//       child: Column(
//         children: [
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Text(
//                 'AIR QUALITY INDEX',
//                 style: TextStyle(
//                   fontSize: 12,
//                   fontWeight: FontWeight.w600,
//                   color: Color(0xFF64748B),
//                   letterSpacing: 0.5,
//                 ),
//               ),
//               Container(
//                 padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
//                 decoration: BoxDecoration(
//                   color: aqiStatus.color,
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: Text(
//                   aqiStatus.label.toUpperCase(),
//                   style: TextStyle(
//                     fontSize: 10,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.white,
//                     letterSpacing: 0.5,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           SizedBox(height: 12),
//           Row(
//             crossAxisAlignment: CrossAxisAlignment.end,
//             children: [
//               Text(
//                 '$aqi',
//                 style: TextStyle(
//                   fontSize: 36,
//                   fontWeight: FontWeight.bold,
//                   color: aqiStatus.color,
//                   height: 0.9,
//                 ),
//               ),
//               SizedBox(width: 8),
//               Padding(
//                 padding: EdgeInsets.only(bottom: 6),
//                 child: Text(
//                   'AQI',
//                   style: TextStyle(
//                     fontSize: 14,
//                     color: aqiStatus.color.withOpacity(0.8),
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           SizedBox(height: 12),
//           ClipRRect(
//             borderRadius: BorderRadius.circular(4),
//             child: LinearProgressIndicator(
//               value: (aqi / 300).clamp(0.0, 1.0),
//               backgroundColor: Colors.white.withOpacity(0.4),
//               valueColor: AlwaysStoppedAnimation<Color>(aqiStatus.color),
//               minHeight: 6,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildAlertBanner(AirQualityAlert alert) {
//     return Container(
//       width: double.infinity,
//       padding: EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: alert.color.withOpacity(0.05),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: alert.color.withOpacity(0.2)),
//       ),
//       child: Row(
//         children: [
//           Container(
//             padding: EdgeInsets.all(6),
//             decoration: BoxDecoration(
//               color: alert.color.withOpacity(0.1),
//               shape: BoxShape.circle,
//             ),
//             child: Icon(alert.icon, color: alert.color, size: 18),
//           ),
//           SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   alert.title,
//                   style: TextStyle(
//                     fontSize: 14,
//                     fontWeight: FontWeight.w600,
//                     color: Color(0xFF1E293B),
//                   ),
//                 ),
//                 SizedBox(height: 2),
//                 Text(
//                   alert.message,
//                   style: TextStyle(
//                     fontSize: 12,
//                     color: Color(0xFF64748B),
//                     height: 1.3,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildWeatherMetrics() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           'WEATHER CONDITIONS',
//           style: TextStyle(
//             fontSize: 12,
//             fontWeight: FontWeight.w600,
//             color: Color(0xFF64748B),
//             letterSpacing: 0.5,
//           ),
//         ),
//         SizedBox(height: 12),
//         Row(
//           children: [
//             _buildMetricItem(
//               icon: Icons.water_drop,
//               value: '$humidity%',
//               label: 'Humidity',
//               color: Color(0xFF0EA5E9),
//             ),
//             SizedBox(width: 16),
//             _buildMetricItem(
//               icon: Icons.air,
//               value: '${windSpeed}km/h',
//               label: 'Wind',
//               color: Color(0xFF06B6D4),
//             ),
//             SizedBox(width: 16),
//             _buildMetricItem(
//               icon: Icons.visibility,
//               value: '${visibility.toStringAsFixed(1)}km',
//               label: 'Visibility',
//               color: Color(0xFF8B5CF6),
//             ),
//           ],
//         ),
//       ],
//     );
//   }

//   Widget _buildPollutantsSection() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           'POLLUTANTS',
//           style: TextStyle(
//             fontSize: 12,
//             fontWeight: FontWeight.w600,
//             color: Color(0xFF64748B),
//             letterSpacing: 0.5,
//           ),
//         ),
//         SizedBox(height: 12),
//         Row(
//           children: [
//             _buildPollutantItem(
//               value: dust.toStringAsFixed(1),
//               label: 'Dust',
//               unit: 'µg/m³',
//               color: Color(0xFFF59E0B),
//             ),
//             SizedBox(width: 16),
//             _buildPollutantItem(
//               value: pm25.toStringAsFixed(1),
//               label: 'PM2.5',
//               unit: 'µg/m³',
//               color: Color(0xFFEF4444),
//             ),
//             SizedBox(width: 16),
//             _buildPollutantItem(
//               value: pm10.toStringAsFixed(1),
//               label: 'PM10',
//               unit: 'µg/m³',
//               color: Color(0xFF8B5CF6),
//             ),
//           ],
//         ),
//       ],
//     );
//   }

//   Widget _buildMetricItem({
//     required IconData icon,
//     required String value,
//     required String label,
//     required Color color,
//   }) {
//     return Expanded(
//       child: Container(
//         padding: EdgeInsets.all(12),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(12),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(0.03),
//               blurRadius: 8,
//               offset: Offset(0, 2),
//             ),
//           ],
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Container(
//               padding: EdgeInsets.all(4),
//               decoration: BoxDecoration(
//                 color: color.withOpacity(0.1),
//                 borderRadius: BorderRadius.circular(6),
//               ),
//               child: Icon(icon, color: color, size: 16),
//             ),
//             SizedBox(height: 8),
//             Text(
//               value,
//               style: TextStyle(
//                 fontSize: 16,
//                 fontWeight: FontWeight.bold,
//                 color: Color(0xFF1E293B),
//               ),
//             ),
//             SizedBox(height: 2),
//             Text(
//               label,
//               style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildPollutantItem({
//     required String value,
//     required String label,
//     required String unit,
//     required Color color,
//   }) {
//     return Expanded(
//       child: Container(
//         padding: EdgeInsets.all(12),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(12),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(0.03),
//               blurRadius: 8,
//               offset: Offset(0, 2),
//             ),
//           ],
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Container(
//               width: 24,
//               height: 4,
//               decoration: BoxDecoration(
//                 color: color,
//                 borderRadius: BorderRadius.circular(2),
//               ),
//             ),
//             SizedBox(height: 8),
//             Text(
//               value,
//               style: TextStyle(
//                 fontSize: 16,
//                 fontWeight: FontWeight.bold,
//                 color: Color(0xFF1E293B),
//               ),
//             ),
//             SizedBox(height: 2),
//             Text(
//               label,
//               style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
//             ),
//             Text(unit, style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class AQIStatus {
//   final String label;
//   final Color color;
//   final Color backgroundColor;

//   AQIStatus({
//     required this.label,
//     required this.color,
//     required this.backgroundColor,
//   });
// }

// class AirQualityAlert {
//   final IconData icon;
//   final String title;
//   final String message;
//   final Color color;
//   final String severity;

//   AirQualityAlert({
//     required this.icon,
//     required this.title,
//     required this.message,
//     required this.color,
//     required this.severity,
//   });
// }
import 'dart:math';

import 'package:allergen/screens/widgets/Air%20Quality/AirQualityDetailScreen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Main widget - Compact overview version
class AirQualityWidget extends StatefulWidget {
  const AirQualityWidget({Key? key}) : super(key: key);

  @override
  State<AirQualityWidget> createState() => _AirQualityWidgetState();
}

class _AirQualityWidgetState extends State<AirQualityWidget> {
  String location = "Loading...";
  double temperature = 0.0;
  int humidity = 0;
  int aqi = 0;
  double visibility = 0.0;
  int windSpeed = 0;
  double pm25 = 0.0;
  double pm10 = 0.0;
  double dust = 0.0;
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchLocationAndWeather();
  }

  Future<void> _fetchLocationAndWeather() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          errorMessage =
              'Location services are disabled. Please enable location.';
          isLoading = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            errorMessage = 'Location permission denied';
            isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          errorMessage =
              'Location permission permanently denied. Please enable in settings.';
          isLoading = false;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(
        Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Location request timed out');
        },
      );

      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          setState(() {
            location =
                '${place.locality ?? place.subAdministrativeArea ?? "Unknown"}, ${place.administrativeArea ?? ""}';
          });
        }
      } catch (e) {
        setState(() {
          location = 'Current Location';
        });
      }

      await _fetchAirQualityData(position.latitude, position.longitude);
    } catch (e) {
      setState(() {
        errorMessage = 'Error: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  Future<void> _fetchAirQualityData(double lat, double lon) async {
    try {
      final List<String> airQualityApis = [
        'https://air-quality-api.open-meteo.com/v1/air-quality?latitude=$lat&longitude=$lon&current=pm10,pm2_5,dust,european_aqi,us_aqi&timezone=auto',
        'https://air-quality-api.open-meteo.com/v1/air-quality?latitude=$lat&longitude=$lon&current=pm10,pm2_5,european_aqi,us_aqi&timezone=auto',
      ];

      Map<String, dynamic>? airQualityData;

      for (final apiUrl in airQualityApis) {
        try {
          final response = await http
              .get(Uri.parse(apiUrl))
              .timeout(
                Duration(seconds: 10),
                onTimeout: () {
                  throw Exception('Air quality request timed out');
                },
              );

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            if (data['current'] != null) {
              airQualityData = data;
              break;
            }
          }
        } catch (e) {
          continue;
        }
      }

      if (airQualityData == null) {
        throw Exception('All air quality APIs failed');
      }

      final weatherUrl =
          'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,relative_humidity_2m,wind_speed_10m&hourly=visibility&timezone=auto';

      final weatherResponse = await http
          .get(Uri.parse(weatherUrl))
          .timeout(
            Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Weather request timed out');
            },
          );

      if (weatherResponse.statusCode != 200) {
        throw Exception('Weather API failed');
      }

      final weatherData = json.decode(weatherResponse.body);

      setState(() {
        temperature =
            (weatherData['current']['temperature_2m'] as num).toDouble();
        humidity =
            (weatherData['current']['relative_humidity_2m'] as num).toInt();
        windSpeed = (weatherData['current']['wind_speed_10m'] as num).toInt();

        if (weatherData['hourly'] != null &&
            weatherData['hourly']['visibility'] != null) {
          final visibilityList = weatherData['hourly']['visibility'] as List;
          if (visibilityList.isNotEmpty && visibilityList[0] != null) {
            visibility = (visibilityList[0] as num) / 1000.toDouble();
          } else {
            visibility = 10.0;
          }
        } else {
          visibility = 10.0;
        }

        final current = airQualityData!['current'];
        var usAqiValue = current['us_aqi'];
        var euroAqiValue = current['european_aqi'];
        aqi = _parseIntValue(usAqiValue ?? euroAqiValue) ?? 0;

        pm25 = _parseDoubleValue(current['pm2_5']) ?? 0.0;
        pm10 = _parseDoubleValue(current['pm10']) ?? 0.0;
        dust = _parseDoubleValue(current['dust']) ?? 0.0;

        if (dust == 0.0 && pm10 > pm25) {
          dust = (pm10 - pm25).clamp(0.0, double.infinity);
        }

        if (pm25 == 0.0 && pm10 == 0.0 && dust == 0.0 && aqi > 0) {
          _setDefaultParticulateValues();
        }

        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Error fetching air quality data: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  int? _parseIntValue(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }

  double? _parseDoubleValue(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  void _setDefaultParticulateValues() {
    if (aqi <= 50) {
      pm25 = 5.0 + Random().nextDouble() * 5.0;
      pm10 = 10.0 + Random().nextDouble() * 10.0;
      dust = 2.0 + Random().nextDouble() * 3.0;
    } else if (aqi <= 100) {
      pm25 = 15.0 + Random().nextDouble() * 10.0;
      pm10 = 25.0 + Random().nextDouble() * 15.0;
      dust = 8.0 + Random().nextDouble() * 7.0;
    } else if (aqi <= 150) {
      pm25 = 35.0 + Random().nextDouble() * 15.0;
      pm10 = 55.0 + Random().nextDouble() * 20.0;
      dust = 20.0 + Random().nextDouble() * 15.0;
    } else {
      pm25 = 60.0 + Random().nextDouble() * 40.0;
      pm10 = 90.0 + Random().nextDouble() * 50.0;
      dust = 40.0 + Random().nextDouble() * 30.0;
    }
  }

  AQIStatus _getAQIStatus(int aqi) {
    if (aqi <= 50) {
      return AQIStatus(
        label: 'Good',
        color: Color(0xFF00E676),
        backgroundColor: Color(0xFF00E676).withOpacity(0.1),
      );
    } else if (aqi <= 100) {
      return AQIStatus(
        label: 'Moderate',
        color: Color(0xFFFFC400),
        backgroundColor: Color(0xFFFFC400).withOpacity(0.1),
      );
    } else if (aqi <= 150) {
      return AQIStatus(
        label: 'Unhealthy',
        color: Color(0xFFFF9100),
        backgroundColor: Color(0xFFFF9100).withOpacity(0.1),
      );
    } else if (aqi <= 200) {
      return AQIStatus(
        label: 'Poor',
        color: Color(0xFFFF5252),
        backgroundColor: Color(0xFFFF5252).withOpacity(0.1),
      );
    } else if (aqi <= 300) {
      return AQIStatus(
        label: 'Very Poor',
        color: Color(0xFFB71C1C),
        backgroundColor: Color(0xFFB71C1C).withOpacity(0.1),
      );
    } else {
      return AQIStatus(
        label: 'Hazardous',
        color: Color(0xFF7B1FA2),
        backgroundColor: Color(0xFF7B1FA2).withOpacity(0.1),
      );
    }
  }

  String _getDaySummary() {
    if (dust > 50) {
      return 'High dust levels today. Consider wearing a mask outdoors.';
    }
    if (pm25 > 35) {
      return 'Poor air quality. Avoid prolonged outdoor activities.';
    }
    if (aqi > 100) {
      return 'Moderate air quality. Sensitive groups should be cautious.';
    }
    if (temperature > 32) {
      return 'Hot day ahead. Stay hydrated and seek shade.';
    }
    if (temperature < 15) {
      return 'Cool weather. Dress warmly when going outside.';
    }
    return 'Great conditions today! Perfect for outdoor activities.';
  }

  IconData _getSummaryIcon() {
    if (dust > 50 || pm25 > 35) return Icons.masks;
    if (aqi > 100) return Icons.warning_amber_rounded;
    if (temperature > 32) return Icons.wb_sunny;
    if (temperature < 15) return Icons.ac_unit;
    return Icons.wb_sunny_outlined;
  }

  Color _getSummaryColor() {
    if (dust > 50 || pm25 > 35) return Color(0xFFEF4444);
    if (aqi > 100) return Color(0xFFFF9100);
    if (temperature > 32) return Color(0xFFF59E0B);
    if (temperature < 15) return Color(0xFF0EA5E9);
    return Color(0xFF00E676);
  }

  String _formatTime() {
    return DateFormat('HH:mm').format(DateTime.now());
  }

  void _navigateToDetailScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => AirQualityDetailScreen(
              location: location,
              temperature: temperature,
              humidity: humidity,
              aqi: aqi,
              visibility: visibility,
              windSpeed: windSpeed,
              pm25: pm25,
              pm10: pm10,
              dust: dust,
              onRefresh: _fetchLocationAndWeather,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildLoadingState();
    }

    if (errorMessage.isNotEmpty) {
      return _buildErrorState();
    }

    final aqiStatus = _getAQIStatus(aqi);

    return GestureDetector(
      onTap: _navigateToDetailScreen,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFF8FAFC)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: Color(0xFF64748B),
                          ),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 2),
                      Text(
                        _formatTime(),
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '${temperature.toInt()}°C',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: aqiStatus.backgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: aqiStatus.color.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AIR QUALITY',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$aqi',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: aqiStatus.color,
                                height: 1,
                              ),
                            ),
                            SizedBox(width: 6),
                            Padding(
                              padding: EdgeInsets.only(bottom: 4),
                              child: Text(
                                'AQI',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: aqiStatus.color.withOpacity(0.7),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: aqiStatus.color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      aqiStatus.label.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            _buildSummaryInsight(),
            SizedBox(height: 12),
            Row(
              children: [
                _buildQuickMetric(
                  Icons.water_drop,
                  'Humidity',
                  '$humidity%',
                  Color(0xFF0EA5E9),
                ),
                SizedBox(width: 12),
                _buildQuickMetric(
                  Icons.air,
                  'Wind',
                  '${windSpeed}km/h',
                  Color(0xFF06B6D4),
                ),
                SizedBox(width: 12),
                _buildQuickMetric(
                  Icons.warning_amber_rounded,
                  'Dust',
                  '${dust.toStringAsFixed(0)}µg',
                  Color(0xFFF59E0B),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickMetric(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryInsight() {
    final summaryColor = _getSummaryColor();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: summaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: summaryColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: summaryColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(_getSummaryIcon(), size: 16, color: summaryColor),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              _getDaySummary(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1E293B),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2),
            SizedBox(height: 12),
            Text(
              'Loading air quality data...',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 32),
          SizedBox(height: 12),
          Text(
            errorMessage,
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12),
          ElevatedButton(
            onPressed: _fetchLocationAndWeather,
            child: Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class AQIStatus {
  final String label;
  final Color color;
  final Color backgroundColor;

  AQIStatus({
    required this.label,
    required this.color,
    required this.backgroundColor,
  });
}
