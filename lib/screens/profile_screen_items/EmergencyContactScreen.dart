// import 'package:allergen/styleguide.dart';
// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter_contacts/flutter_contacts.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:url_launcher/url_launcher.dart';

// class EmergencyContactScreen extends StatefulWidget {
//   const EmergencyContactScreen({Key? key}) : super(key: key);

//   @override
//   State<EmergencyContactScreen> createState() => _EmergencyContactScreenState();
// }

// class _EmergencyContactScreenState extends State<EmergencyContactScreen> {
//   List<EmergencyContact> emergencyContacts = [];
//   bool isLoading = true;
//   bool isEmergencyMode = false;

//   @override
//   void initState() {
//     super.initState();
//     loadEmergencyContacts();
//   }

//   Future<void> loadEmergencyContacts() async {
//     try {
//       User? user = FirebaseAuth.instance.currentUser;
//       if (user != null) {
//         QuerySnapshot snapshot =
//             await FirebaseFirestore.instance
//                 .collection('users')
//                 .doc(user.uid)
//                 .collection('emergency_contacts')
//                 .orderBy('priority')
//                 .get();

//         List<EmergencyContact> contacts = [];
//         for (var doc in snapshot.docs) {
//           contacts.add(
//             EmergencyContact.fromMap(
//               doc.data() as Map<String, dynamic>,
//               doc.id,
//             ),
//           );
//         }

//         setState(() {
//           emergencyContacts = contacts;
//           isLoading = false;
//         });
//       }
//     } catch (e) {
//       print('Error loading emergency contacts: $e');
//       setState(() {
//         isLoading = false;
//       });
//     }
//   }

//   Future<void> addEmergencyContact() async {
//     // Check contacts permission
//     PermissionStatus permission = await Permission.contacts.request();

//     if (permission.isGranted) {
//       try {
//         List<Contact> contacts = await FlutterContacts.getContacts(
//           withProperties: true,
//         );

//         if (contacts.isNotEmpty) {
//           showModalBottomSheet(
//             context: context,
//             isScrollControlled: true,
//             backgroundColor: Colors.transparent,
//             builder:
//                 (context) => ContactSelectionSheet(
//                   contacts: contacts,
//                   onContactSelected:
//                       (contact) => saveEmergencyContact(contact),
//                 ),
//           );
//         }
//       } catch (e) {
//         _showErrorSnackBar('Failed to load contacts: $e');
//       }
//     } else {
//       _showErrorSnackBar(
//         'Contact permission is required to add emergency contacts',
//       );
//     }
//   }

//   Future<void> saveEmergencyContact(Contact contact) async {
//     try {
//       User? user = FirebaseAuth.instance.currentUser;
//       if (user != null && contact.phones.isNotEmpty) {
//         // Determine priority (next in line)
//         int priority = emergencyContacts.length + 1;

//         String phoneNumber = contact.phones.first.number.replaceAll(
//           RegExp(r'[^\d+]'),
//           '',
//         );

//         EmergencyContact emergencyContact = EmergencyContact(
//           name: contact.displayName,
//           phoneNumber: phoneNumber,
//           priority: priority,
//           relationship: '',
//         );

//         String? relationship = await showRelationshipDialog();
//         if (relationship != null) {
//           emergencyContact.relationship = relationship;

//           DocumentReference docRef = await FirebaseFirestore.instance
//               .collection('users')
//               .doc(user.uid)
//               .collection('emergency_contacts')
//               .add(emergencyContact.toMap());

//           emergencyContact.id = docRef.id;

//           setState(() {
//             emergencyContacts.add(emergencyContact);
//           });

//           _showSuccessSnackBar('Emergency contact added successfully');
//         }
//       }
//     } catch (e) {
//       _showErrorSnackBar('Failed to save emergency contact: $e');
//     }
//   }

//   Future<String?> showRelationshipDialog() async {
//     String selectedRelationship = 'Family';
//     List<String> relationships = [
//       'Family',
//       'Friend',
//       'Doctor',
//       'Colleague',
//       'Other',
//     ];

//     return showDialog<String>(
//       context: context,
//       builder:
//           (context) => AlertDialog(
//             title: const Text('Select Relationship'),
//             content: StatefulBuilder(
//               builder:
//                   (context, setDialogState) => Column(
//                     mainAxisSize: MainAxisSize.min,
//                     children:
//                         relationships
//                             .map(
//                               (relationship) => RadioListTile<String>(
//                                 title: Text(relationship),
//                                 value: relationship,
//                                 groupValue: selectedRelationship,
//                                 onChanged: (value) {
//                                   setDialogState(() {
//                                     selectedRelationship = value!;
//                                   });
//                                 },
//                               ),
//                             )
//                             .toList(),
//                   ),
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.pop(context),
//                 child: const Text('Cancel'),
//               ),
//               ElevatedButton(
//                 onPressed: () => Navigator.pop(context, selectedRelationship),
//                 child: const Text('Save'),
//               ),
//             ],
//           ),
//     );
//   }

//   Future<void> reorderContacts(int oldIndex, int newIndex) async {
//     if (newIndex > oldIndex) newIndex--;

//     setState(() {
//       final item = emergencyContacts.removeAt(oldIndex);
//       emergencyContacts.insert(newIndex, item);

//       for (int i = 0; i < emergencyContacts.length; i++) {
//         emergencyContacts[i].priority = i + 1;
//       }
//     });

//     User? user = FirebaseAuth.instance.currentUser;
//     if (user != null) {
//       WriteBatch batch = FirebaseFirestore.instance.batch();

//       for (var contact in emergencyContacts) {
//         DocumentReference docRef = FirebaseFirestore.instance
//             .collection('users')
//             .doc(user.uid)
//             .collection('emergency_contacts')
//             .doc(contact.id);
//         batch.update(docRef, {'priority': contact.priority});
//       }

//       await batch.commit();
//     }
//   }

//   Future<void> deleteEmergencyContact(EmergencyContact contact) async {
//     try {
//       User? user = FirebaseAuth.instance.currentUser;
//       if (user != null) {
//         await FirebaseFirestore.instance
//             .collection('users')
//             .doc(user.uid)
//             .collection('emergency_contacts')
//             .doc(contact.id)
//             .delete();

//         setState(() {
//           emergencyContacts.remove(contact);
//           for (int i = 0; i < emergencyContacts.length; i++) {
//             emergencyContacts[i].priority = i + 1;
//           }
//         });

//         _showSuccessSnackBar('Emergency contact deleted');
//       }
//     } catch (e) {
//       _showErrorSnackBar('Failed to delete emergency contact: $e');
//     }
//   }

//   Future<void> triggerEmergencyAlert() async {
//     if (emergencyContacts.isEmpty) {
//       _showErrorSnackBar('No emergency contacts available');
//       return;
//     }

//     setState(() {
//       isEmergencyMode = true;
//     });

//     try {
//       LocationPermission locationPermission =
//           await Geolocator.checkPermission();
//       if (locationPermission == LocationPermission.denied) {
//         locationPermission = await Geolocator.requestPermission();
//       }

//       Position? position;
//       if (locationPermission == LocationPermission.whileInUse ||
//           locationPermission == LocationPermission.always) {
//         try {
//           position = await Geolocator.getCurrentPosition(
//             desiredAccuracy: LocationAccuracy.high,
//             timeLimit: const Duration(seconds: 10),
//           );
//         } catch (e) {
//           print('Error getting location: $e');
//         }
//       }

//       String locationText =
//           position != null
//               ? 'My current location: https://maps.google.com/?q=${position.latitude},${position.longitude}'
//               : 'Location: Unable to determine current location';

//       String emergencyMessage =
//           '🚨 EMERGENCY ALERT 🚨\n\nI am having a severe allergic reaction and need immediate help!\n\n$locationText\n\nPlease call me or come to my location immediately.';

//       bool anySent = false;
//       for (var contact in emergencyContacts) {
//         try {
//           await _sendSMS(contact.phoneNumber, emergencyMessage);
//           anySent = true;
//           print('SMS intent opened successfully for ${contact.name}');
//         } catch (e) {
//           print('Error opening SMS for ${contact.name}: $e');
//         }
//       }

//       if (anySent) {
//         _showSuccessSnackBar(
//           'Emergency SMS opened for ${emergencyContacts.length} contacts',
//         );
//       } else {
//         _showErrorSnackBar(
//           'Failed to open SMS app. Please try calling manually.',
//         );
//       }

//       _showEmergencyActionsDialog(position);
//     } catch (e) {
//       print('Emergency alert error: $e');
//       _showErrorSnackBar('Failed to trigger emergency alert: $e');
//     } finally {
//       setState(() {
//         isEmergencyMode = false;
//       });
//     }
//   }

//   Future<void> _sendSMS(String phoneNumber, String message) async {
//     try {
//       final Uri smsUri = Uri(
//         scheme: 'sms',
//         path: phoneNumber,
//         queryParameters: {'body': message},
//       );

//       if (await canLaunchUrl(smsUri)) {
//         await launchUrl(smsUri);
//       } else {
//         throw Exception('Could not launch SMS app');
//       }
//     } catch (e) {
//       print('SMS error to $phoneNumber: $e');
//       rethrow;
//     }
//   }

//   void _showEmergencyActionsDialog(Position? position) {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder:
//           (context) => AlertDialog(
//             backgroundColor: Colors.red.shade50,
//             title: Row(
//               children: [
//                 Icon(Icons.emergency, color: Colors.red.shade700),
//                 const SizedBox(width: 8),
//                 const Text('Emergency Mode'),
//               ],
//             ),
//             content: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 const Text(
//                   'Emergency SMS app has been opened for your contacts.',
//                 ),
//                 const SizedBox(height: 16),
//                 const Text(
//                   'Additional Actions:',
//                   style: TextStyle(fontWeight: FontWeight.bold),
//                 ),
//                 const SizedBox(height: 8),
//                 ElevatedButton.icon(
//                   onPressed: () {
//                     Navigator.pop(context);
//                     _callEmergencyServices();
//                   },
//                   icon: const Icon(Icons.phone),
//                   label: const Text('Call 911'),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.red,
//                     foregroundColor: Colors.white,
//                     minimumSize: const Size(double.infinity, 45),
//                   ),
//                 ),
//                 const SizedBox(height: 8),
//                 ElevatedButton.icon(
//                   onPressed: () {
//                     // Call first emergency contact
//                     if (emergencyContacts.isNotEmpty) {
//                       _callContact(emergencyContacts.first.phoneNumber);
//                     }
//                   },
//                   icon: const Icon(Icons.contact_phone),
//                   label: Text(
//                     'Call ${emergencyContacts.isNotEmpty ? emergencyContacts.first.name : 'Emergency Contact'}',
//                   ),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: const Color(0xFF1AA2CC),
//                     foregroundColor: Colors.white,
//                     minimumSize: const Size(double.infinity, 45),
//                   ),
//                 ),
//                 if (position != null) ...[
//                   const SizedBox(height: 8),
//                   ElevatedButton.icon(
//                     onPressed: () => _openMapsLocation(position),
//                     icon: const Icon(Icons.map),
//                     label: const Text('Open Location in Maps'),
//                     style: ElevatedButton.styleFrom(
//                       minimumSize: const Size(double.infinity, 45),
//                     ),
//                   ),
//                 ],
//               ],
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.pop(context),
//                 child: const Text('Close'),
//               ),
//             ],
//           ),
//     );
//   }

//   Future<void> _callContact(String phoneNumber) async {
//     try {
//       final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
//       if (await canLaunchUrl(phoneUri)) {
//         await launchUrl(phoneUri);
//       }
//     } catch (e) {
//       print('Error calling $phoneNumber: $e');
//     }
//   }

//   Future<void> _callEmergencyServices() async {
//     final Uri phoneUri = Uri(scheme: 'tel', path: '911');
//     if (await canLaunchUrl(phoneUri)) {
//       await launchUrl(phoneUri);
//     }
//   }

//   Future<void> _openMapsLocation(Position position) async {
//     final Uri mapsUri = Uri.parse(
//       'https://maps.google.com/?q=${position.latitude},${position.longitude}',
//     );
//     if (await canLaunchUrl(mapsUri)) {
//       await launchUrl(mapsUri);
//     }
//   }

//   void _showSuccessSnackBar(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text(message), backgroundColor: Colors.green),
//     );
//   }

//   void _showErrorSnackBar(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text(message), backgroundColor: Colors.red),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.defaultbackground,
//       appBar: AppBar(
//         backgroundColor: AppColors.primary,
//         elevation: 0,
//         title: const Text(
//           'Emergency Contacts',
//           style: TextStyle(
//             fontFamily: 'Poppins',
//             color: Colors.white,
//             fontSize: 20,
//             fontWeight: FontWeight.w600,
//           ),
//         ),
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: Colors.white),
//           onPressed: () => Navigator.pop(context),
//         ),
//       ),
//       body: Column(
//         children: [
//           Container(
//             width: double.infinity,
//             margin: const EdgeInsets.all(20),
//             child: ElevatedButton(
//               onPressed: isEmergencyMode ? null : triggerEmergencyAlert,
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.red,
//                 foregroundColor: Colors.white,
//                 padding: const EdgeInsets.symmetric(vertical: 16),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//               ),
//               child:
//                   isEmergencyMode
//                       ? const Row(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           SizedBox(
//                             width: 20,
//                             height: 20,
//                             child: CircularProgressIndicator(
//                               strokeWidth: 2,
//                               valueColor: AlwaysStoppedAnimation<Color>(
//                                 Colors.white,
//                               ),
//                             ),
//                           ),
//                           SizedBox(width: 12),
//                           Text(
//                             'Opening SMS Apps...',
//                             style: TextStyle(
//                               fontSize: 16,
//                               fontWeight: FontWeight.w600,
//                               fontFamily: 'Poppins',
//                             ),
//                           ),
//                         ],
//                       )
//                       : const Row(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           Icon(Icons.emergency, size: 24),
//                           SizedBox(width: 8),
//                           Text(
//                             'EMERGENCY ALERT',
//                             style: TextStyle(
//                               fontSize: 16,
//                               fontWeight: FontWeight.w600,
//                               fontFamily: 'Poppins',
//                             ),
//                           ),
//                         ],
//                       ),
//             ),
//           ),

//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 20),
//             child: Container(
//               padding: const EdgeInsets.all(16),
//               decoration: BoxDecoration(
//                 color: Colors.orange.shade50,
//                 borderRadius: BorderRadius.circular(12),
//                 border: Border.all(color: Colors.orange.shade200),
//               ),
//               child: Row(
//                 children: [
//                   Icon(Icons.info_outline, color: Colors.orange.shade700),
//                   const SizedBox(width: 12),
//                   const Expanded(
//                     child: Text(
//                       'In case of emergency, press the button above to open SMS apps with your location for all emergency contacts',
//                       style: TextStyle(fontSize: 12, fontFamily: 'Poppins'),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),

//           const SizedBox(height: 20),

//           Expanded(
//             child:
//                 isLoading
//                     ? const Center(child: CircularProgressIndicator())
//                     : emergencyContacts.isEmpty
//                     ? const Center(
//                       child: Column(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           Icon(
//                             Icons.contacts_outlined,
//                             size: 64,
//                             color: Colors.grey,
//                           ),
//                           SizedBox(height: 16),
//                           Text(
//                             'No Emergency Contacts',
//                             style: TextStyle(
//                               fontSize: 18,
//                               fontWeight: FontWeight.w600,
//                               color: Colors.grey,
//                               fontFamily: 'Poppins',
//                             ),
//                           ),
//                           SizedBox(height: 8),
//                           Text(
//                             'Add emergency contacts to get help quickly',
//                             style: TextStyle(
//                               fontSize: 14,
//                               color: Colors.grey,
//                               fontFamily: 'Poppins',
//                             ),
//                           ),
//                         ],
//                       ),
//                     )
//                     : ReorderableListView.builder(
//                       padding: const EdgeInsets.symmetric(horizontal: 20),
//                       itemCount: emergencyContacts.length,
//                       onReorder: reorderContacts,
//                       itemBuilder: (context, index) {
//                         final contact = emergencyContacts[index];
//                         return EmergencyContactCard(
//                           key: ValueKey(contact.id),
//                           contact: contact,
//                           onDelete: () => deleteEmergencyContact(contact),
//                         );
//                       },
//                     ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class EmergencyContact {
//   String id;
//   String name;
//   String phoneNumber;
//   String relationship;
//   int priority;

//   EmergencyContact({
//     this.id = '',
//     required this.name,
//     required this.phoneNumber,
//     required this.relationship,
//     required this.priority,
//   });

//   Map<String, dynamic> toMap() {
//     return {
//       'name': name,
//       'phoneNumber': phoneNumber,
//       'relationship': relationship,
//       'priority': priority,
//     };
//   }

//   factory EmergencyContact.fromMap(Map<String, dynamic> map, String id) {
//     return EmergencyContact(
//       id: id,
//       name: map['name'] ?? '',
//       phoneNumber: map['phoneNumber'] ?? '',
//       relationship: map['relationship'] ?? '',
//       priority: map['priority'] ?? 0,
//     );
//   }
// }

// class EmergencyContactCard extends StatelessWidget {
//   final EmergencyContact contact;
//   final VoidCallback onDelete;

//   const EmergencyContactCard({
//     Key? key,
//     required this.contact,
//     required this.onDelete,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 12),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.grey.shade200),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.05),
//             blurRadius: 4,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: ListTile(
//         contentPadding: const EdgeInsets.all(16),
//         leading: CircleAvatar(
//           backgroundColor: const Color(0xFF1AA2CC),
//           child: Text(
//             '${contact.priority}',
//             style: const TextStyle(
//               color: Colors.white,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//         ),
//         title: Text(
//           contact.name,
//           style: const TextStyle(
//             fontWeight: FontWeight.w600,
//             fontFamily: 'Poppins',
//           ),
//         ),
//         subtitle: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               contact.phoneNumber,
//               style: const TextStyle(color: Colors.grey, fontFamily: 'Poppins'),
//             ),
//             Text(
//               contact.relationship,
//               style: TextStyle(
//                 color: Colors.blue.shade600,
//                 fontSize: 12,
//                 fontFamily: 'Poppins',
//               ),
//             ),
//           ],
//         ),
//         trailing: Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             // Call button
//             IconButton(
//               icon: Icon(Icons.phone, color: Colors.green.shade600),
//               onPressed: () async {
//                 final Uri phoneUri = Uri(
//                   scheme: 'tel',
//                   path: contact.phoneNumber,
//                 );
//                 if (await canLaunchUrl(phoneUri)) {
//                   await launchUrl(phoneUri);
//                 }
//               },
//             ),
//             Icon(Icons.drag_handle, color: Colors.grey.shade400),
//             IconButton(
//               icon: const Icon(Icons.delete, color: Colors.red),
//               onPressed: () {
//                 showDialog(
//                   context: context,
//                   builder:
//                       (context) => AlertDialog(
//                         title: const Text('Delete Contact'),
//                         content: Text(
//                           'Are you sure you want to delete ${contact.name}?',
//                         ),
//                         actions: [
//                           TextButton(
//                             onPressed: () => Navigator.pop(context),
//                             child: const Text('Cancel'),
//                           ),
//                           ElevatedButton(
//                             onPressed: () {
//                               Navigator.pop(context);
//                               onDelete();
//                             },
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor: Colors.red,
//                             ),
//                             child: const Text('Delete'),
//                           ),
//                         ],
//                       ),
//                 );
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class ContactSelectionSheet extends StatefulWidget {
//   final List<Contact> contacts;
//   final Function(Contact) onContactSelected;

//   const ContactSelectionSheet({
//     Key? key,
//     required this.contacts,
//     required this.onContactSelected,
//   }) : super(key: key);

//   @override
//   State<ContactSelectionSheet> createState() => _ContactSelectionSheetState();
// }

// class _ContactSelectionSheetState extends State<ContactSelectionSheet> {
//   List<Contact> filteredContacts = [];
//   TextEditingController searchController = TextEditingController();

//   @override
//   void initState() {
//     super.initState();
//     filteredContacts = widget.contacts;
//   }

//   void _filterContacts(String query) {
//     setState(() {
//       filteredContacts =
//           widget.contacts
//               .where(
//                 (contact) => contact.displayName.toLowerCase().contains(
//                   query.toLowerCase(),
//                 ),
//               )
//               .toList();
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       height: MediaQuery.of(context).size.height * 0.8,
//       decoration: const BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.only(
//           topLeft: Radius.circular(20),
//           topRight: Radius.circular(20),
//         ),
//       ),
//       child: Column(
//         children: [
//           // Handle
//           Container(
//             margin: const EdgeInsets.only(top: 12),
//             width: 40,
//             height: 4,
//             decoration: BoxDecoration(
//               color: Colors.grey.shade300,
//               borderRadius: BorderRadius.circular(2),
//             ),
//           ),

//           // Header
//           Padding(
//             padding: const EdgeInsets.all(20),
//             child: Row(
//               children: [
//                 const Text(
//                   'Select Contact',
//                   style: TextStyle(
//                     fontSize: 20,
//                     fontWeight: FontWeight.w600,
//                     fontFamily: 'Poppins',
//                   ),
//                 ),
//                 const Spacer(),
//                 IconButton(
//                   onPressed: () => Navigator.pop(context),
//                   icon: const Icon(Icons.close),
//                 ),
//               ],
//             ),
//           ),

//           // Search
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 20),
//             child: TextField(
//               controller: searchController,
//               onChanged: _filterContacts,
//               decoration: InputDecoration(
//                 hintText: 'Search contacts...',
//                 prefixIcon: const Icon(Icons.search),
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//               ),
//             ),
//           ),

//           // Contacts List
//           Expanded(
//             child: ListView.builder(
//               padding: const EdgeInsets.all(20),
//               itemCount: filteredContacts.length,
//               itemBuilder: (context, index) {
//                 final contact = filteredContacts[index];
//                 return ListTile(
//                   leading: CircleAvatar(
//                     child: Text(
//                       contact.displayName.isNotEmpty
//                           ? contact.displayName[0].toUpperCase()
//                           : '?',
//                     ),
//                   ),
//                   title: Text(contact.displayName),
//                   subtitle:
//                       contact.phones.isNotEmpty
//                           ? Text(contact.phones.first.number)
//                           : const Text('No phone number'),
//                   onTap:
//                       contact.phones.isNotEmpty
//                           ? () {
//                             Navigator.pop(context);
//                             widget.onContactSelected(contact);
//                           }
//                           : null,
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
