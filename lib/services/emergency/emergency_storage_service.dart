import 'dart:convert';
import 'package:allergen/screens/models/emergency_contact.dart';
import 'package:allergen/screens/models/emergency_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EmergencyStorageService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  void dispose() {
  
  }

  Future<Map<String, dynamic>> loadSettings() async {
    try {
      if (auth.currentUser != null) {
        return await loadFromFirebase();
      } else {
        return await loadFromSharedPreferences();
      }
    } catch (e) {
      print('Error loading settings: $e');
      return await loadFromSharedPreferences();
    }
  }

  Future<Map<String, dynamic>> loadFromFirebase() async {
    final userId = auth.currentUser?.uid;
    if (userId == null) {
      return {
        'contacts': <EmergencyContact>[],
        'settings': EmergencySettings(),
      };
    }

    try {
      final contactsSnapshot =
          await firestore
              .collection('users')
              .doc(userId)
              .collection('emergency_contacts')
              .orderBy('priority')
              .get();

      List<EmergencyContact> contacts =
          contactsSnapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id; 
            return EmergencyContact.fromJson(data);
          }).toList();

      final settingsDoc =
          await firestore.collection('users').doc(userId).get();

      EmergencySettings settings = EmergencySettings();

      if (settingsDoc.exists) {
        final data = settingsDoc.data();
        if (data != null && data.containsKey('emergency_settings')) {
          settings = EmergencySettings.fromJson(data['emergency_settings']);
        }
      }

      await saveToSharedPreferences(contacts, settings);

      return {'contacts': contacts, 'settings': settings};
    } catch (e) {
      print('Error loading from Firebase: $e');
      return await loadFromSharedPreferences();
    }
  }

  Future<Map<String, dynamic>> loadFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      List<EmergencyContact> contacts = [];
      EmergencySettings settings = EmergencySettings();

      final contactsJson = prefs.getString('emergency_contacts');
      if (contactsJson != null) {
        final contactsList = jsonDecode(contactsJson) as List;
        contacts =
            contactsList
                .map((json) => EmergencyContact.fromJson(json))
                .toList();
      }

      final settingsJson = prefs.getString('emergency_settings');
      if (settingsJson != null) {
        settings = EmergencySettings.fromJson(jsonDecode(settingsJson));
      }

      return {'contacts': contacts, 'settings': settings};
    } catch (e) {
      print('Error loading from SharedPreferences: $e');
      return {
        'contacts': <EmergencyContact>[],
        'settings': EmergencySettings(),
      };
    }
  }

  Future<void> saveSettings(
    List<EmergencyContact> contacts,
    EmergencySettings settings,
  ) async {
    try {
      await saveToSharedPreferences(contacts, settings);
      print('Settings saved to SharedPreferences');

      if (auth.currentUser != null) {
        await saveToFirebase(contacts, settings);
        print('Settings saved to Firebase');
      }

      print('Settings saved successfully to both locations');
    } catch (e) {
      print('Error saving settings: $e');
      try {
        await saveToSharedPreferences(contacts, settings);
        print('Fallback: Settings saved to SharedPreferences only');
      } catch (localError) {
        print('Critical error: Could not save to any storage: $localError');
        throw localError;
      }
    }
  }

  Future<void> saveToFirebase(
    List<EmergencyContact> contacts,
    EmergencySettings settings,
  ) async {
    final userId = auth.currentUser?.uid;
    if (userId == null) {
      print('No user logged in, skipping Firebase save');
      return;
    }

    try {
      final userRef = firestore.collection('users').doc(userId);
      final contactsRef = userRef.collection('emergency_contacts');

      await firestore.runTransaction((transaction) async {
        transaction.set(userRef, {
          'emergency_settings': settings.toJson(),
          'last_updated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        final existingContacts = await contactsRef.get();

        for (final doc in existingContacts.docs) {
          transaction.delete(doc.reference);
        }

        for (int i = 0; i < contacts.length; i++) {
          final contact = contacts[i];
          final contactData = contact.toJson();
          contactData.remove('id');
          contactData['priority'] = i + 1;

          final newDocRef = contactsRef.doc();
          transaction.set(newDocRef, contactData);
        }
      });

      print('Successfully saved to Firebase using transaction');
    } catch (e) {
      print('Error saving to Firebase: $e');
      throw e; 
    }
  }

  Future<void> saveToSharedPreferences(
    List<EmergencyContact> contacts,
    EmergencySettings settings,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final contactsJson = jsonEncode(
        contacts.map((contact) => contact.toJson()).toList(),
      );
      await prefs.setString('emergency_contacts', contactsJson);

      final settingsJson = jsonEncode(settings.toJson());
      await prefs.setString('emergency_settings', settingsJson);

      print('Successfully saved to SharedPreferences');
    } catch (e) {
      print('Error saving to SharedPreferences: $e');
      throw e; 
    }
  }

  Future<void> syncOnLogin() async {
    if (auth.currentUser != null) {
      try {
        await loadFromFirebase();
        print('Sync completed successfully');
      } catch (e) {
        print('Error during sync: $e');
      }
    }
  }

  Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('emergency_contacts');
      await prefs.remove('emergency_settings');

      final userId = auth.currentUser?.uid;
      if (userId != null) {
        final userRef = firestore.collection('users').doc(userId);
        final contactsRef = userRef.collection('emergency_contacts');

        final existingContacts = await contactsRef.get();
        final batch = firestore.batch();

        for (final doc in existingContacts.docs) {
          batch.delete(doc.reference);
        }

        batch.update(userRef, {'emergency_settings': FieldValue.delete()});
        await batch.commit();
      }

      print('All data cleared successfully');
    } catch (e) {
      print('Error clearing data: $e');
    }
  }
}
