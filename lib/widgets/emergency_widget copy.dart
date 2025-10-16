// // widgets/emergency_widget.dart
// import 'package:allergen/services/emergency/emergency_service.dart';
// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';

// class EmergencyWidget extends StatefulWidget {
//   final EmergencyService emergencyService;
//   final bool showSettings;
//   final bool showStatus;

//   const EmergencyWidget({
//     Key? key,
//     required this.emergencyService,
//     this.showSettings = true,
//     this.showStatus = true,
//   }) : super(key: key);

//   @override
//   _EmergencyWidgetState createState() => _EmergencyWidgetState();
// }

// class _EmergencyWidgetState extends State<EmergencyWidget> {
//   bool _isLoading = false;

//   @override
//   void initState() {
//     super.initState();
//     _initializeService();
//   }

//   Future<void> _initializeService() async {
//     setState(() => _isLoading = true);
//     await widget.emergencyService.initialize();
//     setState(() => _isLoading = false);
//   }

//   // Refresh data when widget is rebuilt (when user returns to screen)
//   @override
//   void didUpdateWidget(EmergencyWidget oldWidget) {
//     super.didUpdateWidget(oldWidget);
//     _refreshData();
//   }

//   Future<void> _refreshData() async {
//     await widget.emergencyService.forceReload();
//     if (mounted) {
//       setState(() {});
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_isLoading) {
//       return Center(child: CircularProgressIndicator());
//     }

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.stretch,
//       children: [
//         // App Info
//         Card(
//           child: Padding(
//             padding: EdgeInsets.all(20),
//             child: Column(
//               children: [
//                 Icon(Icons.emergency, size: 60, color: Colors.red[600]),
//                 SizedBox(height: 16),
//                 Text(
//                   'Emergency Assistant',
//                   style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//                 ),
//                 SizedBox(height: 8),
//                 Text(
//                   'Quickly call emergency contacts or send alert messages',
//                   textAlign: TextAlign.center,
//                   style: TextStyle(color: Colors.grey[600], fontSize: 16),
//                 ),
//               ],
//             ),
//           ),
//         ),

//         SizedBox(height: 30),

//         // Emergency Call Button
//         Container(
//           height: 120,
//           child: ElevatedButton(
//             onPressed:
//                 () => widget.emergencyService.startEmergencyCallFromUI(context),
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.red[600],
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(20),
//               ),
//               elevation: 8,
//             ),
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Icon(Icons.phone, size: 40, color: Colors.white),
//                 SizedBox(height: 8),
//                 Text(
//                   'EMERGENCY CALL',
//                   style: TextStyle(
//                     fontSize: 20,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.white,
//                   ),
//                 ),
//                 Text(
//                   'Call contacts in priority order',
//                   style: TextStyle(fontSize: 12, color: Colors.white70),
//                 ),
//               ],
//             ),
//           ),
//         ),

//         SizedBox(height: 16),

//         // Emergency SMS Button
//         Container(
//           height: 80,
//           child: ElevatedButton(
//             onPressed:
//                 widget.emergencyService.hasContacts
//                     ? () => widget.emergencyService.sendEmergencyMessagesFromUI(
//                       context,
//                     )
//                     : null,
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.orange[600],
//               disabledBackgroundColor: Colors.grey[400],
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(16),
//               ),
//               elevation: 6,
//             ),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Icon(
//                   Icons.message,
//                   size: 28,
//                   color:
//                       widget.emergencyService.hasContacts
//                           ? Colors.white
//                           : Colors.grey[600],
//                 ),
//                 SizedBox(width: 12),
//                 Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       'SEND EMERGENCY SMS',
//                       style: TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.bold,
//                         color:
//                             widget.emergencyService.hasContacts
//                                 ? Colors.white
//                                 : Colors.grey[600],
//                       ),
//                     ),
//                     Text(
//                       'Send alert message to all contacts',
//                       style: TextStyle(
//                         fontSize: 11,
//                         color:
//                             widget.emergencyService.hasContacts
//                                 ? Colors.white70
//                                 : Colors.grey[500],
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ),

//         if (widget.showStatus) ...[SizedBox(height: 30), _buildStatusCard()],

//         if (widget.showSettings) ...[
//           SizedBox(height: 20),
//           if (!widget.emergencyService.hasContacts)
//             Container(
//               padding: EdgeInsets.all(16),
//               decoration: BoxDecoration(
//                 color: Colors.blue.withOpacity(0.1),
//                 borderRadius: BorderRadius.circular(12),
//                 border: Border.all(color: Colors.blue.withOpacity(0.3)),
//               ),
//               child: Column(
//                 children: [
//                   Icon(Icons.info_outline, color: Colors.blue[700], size: 24),
//                   SizedBox(height: 8),
//                   Text(
//                     'No Emergency Contacts',
//                     style: TextStyle(
//                       fontWeight: FontWeight.bold,
//                       color: Colors.blue[700],
//                     ),
//                   ),
//                   SizedBox(height: 4),
//                   Text(
//                     'Add emergency contacts to enable emergency features',
//                     textAlign: TextAlign.center,
//                     style: TextStyle(color: Colors.blue[600], fontSize: 12),
//                   ),
//                   SizedBox(height: 12),
//                   ElevatedButton.icon(
//                     onPressed:
//                         () => widget.emergencyService.showSettings(context),
//                     icon: Icon(Icons.add, size: 18),
//                     label: Text('Set Up Emergency Contacts'),
//                     style: ElevatedButton.styleFrom(
//                       padding: EdgeInsets.symmetric(
//                         horizontal: 20,
//                         vertical: 10,
//                       ),
//                       backgroundColor: Colors.blue[600],
//                       foregroundColor: Colors.white,
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//         ],
//       ],
//     );
//   }

//   Widget _buildStatusCard() {
//     return Card(
//       child: Padding(
//         padding: EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Text(
//                   'Status',
//                   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                 ),
//                 if (widget.showSettings)
//                   IconButton(
//                     onPressed:
//                         () => widget.emergencyService.showSettings(context),
//                     icon: Icon(Icons.settings, size: 20),
//                   ),
//               ],
//             ),
//             SizedBox(height: 12),
//             _buildStatusRow(
//               'Emergency Contacts',
//               '${widget.emergencyService.emergencyContacts.length} contacts',
//               widget.emergencyService.hasContacts ? Colors.green : Colors.red,
//             ),
//             _buildStatusRow(
//               'SMS Permission',
//               widget.emergencyService.smsPermissionGranted
//                   ? 'Granted'
//                   : 'Required',
//               widget.emergencyService.smsPermissionGranted
//                   ? Colors.green
//                   : Colors.red,
//             ),
//             _buildStatusRow(
//               'Phone Permission',
//               widget.emergencyService.phonePermissionGranted
//                   ? 'Granted'
//                   : 'Required',
//               widget.emergencyService.phonePermissionGranted
//                   ? Colors.green
//                   : Colors.red,
//             ),
//             _buildStatusRow(
//               'Location Permission',
//               widget.emergencyService.locationPermissionGranted
//                   ? 'Granted'
//                   : 'Optional',
//               widget.emergencyService.locationPermissionGranted
//                   ? Colors.green
//                   : Colors.orange,
//             ),
//             _buildStatusRow(
//               'Location Sharing',
//               widget
//                       .emergencyService
//                       .emergencySettings
//                       .autoSendLocationToCurrentContact
//                   ? 'Enabled'
//                   : 'Disabled',
//               widget
//                       .emergencyService
//                       .emergencySettings
//                       .autoSendLocationToCurrentContact
//                   ? Colors.green
//                   : Colors.orange,
//             ),
//             _buildStatusRow(
//               'Auto Emergency Services',
//               widget
//                       .emergencyService
//                       .emergencySettings
//                       .autoCallEmergencyServices
//                   ? 'Enabled'
//                   : 'Disabled',
//               widget
//                       .emergencyService
//                       .emergencySettings
//                       .autoCallEmergencyServices
//                   ? Colors.green
//                   : Colors.orange,
//             ),
//             _buildStatusRow(
//               'Storage',
//               FirebaseAuth.instance.currentUser != null
//                   ? 'Cloud + Local'
//                   : 'Local Only',
//               FirebaseAuth.instance.currentUser != null
//                   ? Colors.green
//                   : Colors.blue,
//             ),

//             // Show permission warning if needed
//             if (!widget.emergencyService.smsPermissionGranted ||
//                 !widget.emergencyService.phonePermissionGranted) ...[
//               SizedBox(height: 12),
//               Container(
//                 padding: EdgeInsets.all(12),
//                 decoration: BoxDecoration(
//                   color: Colors.orange.withOpacity(0.1),
//                   borderRadius: BorderRadius.circular(8),
//                   border: Border.all(color: Colors.orange.withOpacity(0.3)),
//                 ),
//                 child: Row(
//                   children: [
//                     Icon(Icons.warning, color: Colors.orange, size: 20),
//                     SizedBox(width: 8),
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             'Permissions Required',
//                             style: TextStyle(
//                               color: Colors.orange[800],
//                               fontWeight: FontWeight.w600,
//                               fontSize: 13,
//                             ),
//                           ),
//                           SizedBox(height: 2),
//                           Text(
//                             'Some permissions are missing. Grant permissions for full emergency functionality.',
//                             style: TextStyle(
//                               color: Colors.orange[700],
//                               fontSize: 12,
//                             ),
//                           ),
//                           SizedBox(height: 8),
//                           ElevatedButton(
//                             onPressed: () async {
//                               await widget.emergencyService
//                                   .requestPermissionsManually();
//                               setState(
//                                 () {},
//                               ); // Refresh UI after permission request
//                             },
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor: Colors.orange[600],
//                               foregroundColor: Colors.white,
//                               padding: EdgeInsets.symmetric(
//                                 horizontal: 12,
//                                 vertical: 6,
//                               ),
//                               minimumSize: Size(0, 0),
//                               tapTargetSize: MaterialTapTargetSize.shrinkWrap,
//                             ),
//                             child: Text(
//                               'Grant Permissions',
//                               style: TextStyle(fontSize: 11),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],

//             // Show quick action buttons if contacts exist
//             if (widget.emergencyService.hasContacts) ...[
//               SizedBox(height: 16),
//               Row(
//                 children: [
//                   Expanded(
//                     child: OutlinedButton.icon(
//                       onPressed: () => _showQuickSMSOptions(context),
//                       icon: Icon(Icons.message, size: 16),
//                       label: Text('Quick SMS'),
//                       style: OutlinedButton.styleFrom(
//                         padding: EdgeInsets.symmetric(vertical: 8),
//                         side: BorderSide(color: Colors.orange[300]!),
//                         foregroundColor: Colors.orange[700],
//                       ),
//                     ),
//                   ),
//                   SizedBox(width: 12),
//                   Expanded(
//                     child: OutlinedButton.icon(
//                       onPressed:
//                           () => widget.emergencyService.showSettings(context),
//                       icon: Icon(Icons.settings, size: 16),
//                       label: Text('Settings'),
//                       style: OutlinedButton.styleFrom(
//                         padding: EdgeInsets.symmetric(vertical: 8),
//                         side: BorderSide(color: Colors.blue[300]!),
//                         foregroundColor: Colors.blue[700],
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildStatusRow(String label, String value, Color color) {
//     return Padding(
//       padding: EdgeInsets.symmetric(vertical: 4),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(label),
//           Container(
//             padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//             decoration: BoxDecoration(
//               color: color.withOpacity(0.1),
//               borderRadius: BorderRadius.circular(12),
//               border: Border.all(color: color.withOpacity(0.3)),
//             ),
//             child: Text(
//               value,
//               style: TextStyle(
//                 color: color,
//                 fontWeight: FontWeight.w600,
//                 fontSize: 12,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   void _showQuickSMSOptions(BuildContext context) {
//     showModalBottomSheet(
//       context: context,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//       ),
//       builder:
//           (context) => Container(
//             padding: EdgeInsets.all(20),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               crossAxisAlignment: CrossAxisAlignment.stretch,
//               children: [
//                 Text(
//                   'Quick Emergency SMS',
//                   style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//                   textAlign: TextAlign.center,
//                 ),
//                 SizedBox(height: 8),
//                 Text(
//                   'Send emergency messages to your contacts',
//                   style: TextStyle(color: Colors.grey[600]),
//                   textAlign: TextAlign.center,
//                 ),
//                 SizedBox(height: 24),

//                 ElevatedButton.icon(
//                   onPressed: () {
//                     Navigator.pop(context);
//                     widget.emergencyService.sendEmergencyMessagesFromUI(
//                       context,
//                     );
//                   },
//                   icon: Icon(Icons.emergency),
//                   label: Text('Send Emergency Alert'),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.red[600],
//                     foregroundColor: Colors.white,
//                     padding: EdgeInsets.symmetric(vertical: 16),
//                   ),
//                 ),

//                 SizedBox(height: 12),

//                 OutlinedButton.icon(
//                   onPressed: () async {
//                     Navigator.pop(context);
//                     // Send location only
//                     await widget.emergencyService.sendEmergencyMessagesDirectly(
//                       customMessage: null,
//                       includeLocation: true,
//                     );
//                   },
//                   icon: Icon(Icons.location_on),
//                   label: Text('Send Location Only'),
//                   style: OutlinedButton.styleFrom(
//                     padding: EdgeInsets.symmetric(vertical: 16),
//                     side: BorderSide(color: Colors.blue[300]!),
//                     foregroundColor: Colors.blue[700],
//                   ),
//                 ),

//                 SizedBox(height: 12),

//                 TextButton(
//                   onPressed: () => Navigator.pop(context),
//                   child: Text('Cancel'),
//                 ),

//                 SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
//               ],
//             ),
//           ),
//     );
//   }
// }
