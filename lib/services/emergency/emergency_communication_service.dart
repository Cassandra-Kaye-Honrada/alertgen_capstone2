import 'dart:async';
import 'package:allergen/screens/models/emergency_contact.dart';
import 'package:flutter/services.dart';
import 'package:telephony/telephony.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';

class EmergencyCommunicationService {
  final Telephony telephony = Telephony.instance;
  final AudioPlayer audioPlayer = AudioPlayer();
  Timer? soundTimer;
  bool isPlayingEmergencySound = false;
  bool isPlayingEmergencyServiceSound = false;

  Future<void> initializeTelephony() async {
    try {
      await requestAllSmsPermissions();

      final bool? isSmsCapable = await telephony.isSmsCapable;
      print('SMS capable: $isSmsCapable');

      if (isSmsCapable == true) {
        print('Telephony initialized successfully');
      } else {
        print('Device not SMS capable');
      }
    } catch (e) {
      print('Error initializing telephony: $e');
    }
  }

  Future<bool> requestAllSmsPermissions() async {
    try {
      Map<Permission, PermissionStatus> statuses =
          await [Permission.sms, Permission.phone].request();

      bool smsGranted = statuses[Permission.sms]?.isGranted ?? false;
      bool phoneGranted = statuses[Permission.phone]?.isGranted ?? false;

      print('SMS Permission: $smsGranted');
      print('Phone Permission: $phoneGranted');

      return smsGranted;
    } catch (e) {
      print('Error requesting permissions: $e');
      return false;
    }
  }

  Future<bool> sendDirectSMS(
    String phoneNumber,
    String message,
    bool smsPermissionGranted,
  ) async {
    print('Attempting to send direct SMS to: $phoneNumber');
    print('Permission granted: $smsPermissionGranted');

    if (!smsPermissionGranted) {
      print('SMS permission not granted, requesting...');

      bool permissionObtained = await requestAllSmsPermissions();
      if (!permissionObtained) {
        print('Could not obtain SMS permission');
        return false;
      }
    }

    bool success = await sendViaTelephonyDirect(phoneNumber, message);
    if (success) {
      print('SMS sent successfully via telephony');
      return true;
    }

    success = await sendViaPlatformChannel(phoneNumber, message);
    if (success) {
      print('SMS sent successfully via platform channel');
      return true;
    }

    print('All SMS sending methods failed');
    return false;
  }

  Future<bool> sendViaTelephonyDirect(
    String phoneNumber,
    String message,
  ) async {
    try {
      print('Attempting direct telephony send...');

      final bool? canSendSms = await telephony.isSmsCapable;
      if (canSendSms != true) {
        print('Device cannot send SMS');
        return false;
      }

      final Completer<bool> completer = Completer<bool>();
      bool statusReceived = false;

      await telephony.sendSms(
        to: phoneNumber,
        message: message,
        statusListener: (SendStatus status) {
          print('SMS Status received: $status');
          if (!statusReceived) {
            statusReceived = true;
            if (!completer.isCompleted) {
              bool success = (status == SendStatus.SENT);
              print('SMS Send Status: $success');
              completer.complete(success);
            }
          }
        },
      );

      try {
        bool result = await completer.future.timeout(
          Duration(seconds: 10),
          onTimeout: () {
            print('SMS send timeout - assuming success');
            return true;
          },
        );
        return result;
      } catch (e) {
        print('SMS status timeout: $e');
        return true;
      }
    } catch (e) {
      print('Error in direct telephony send: $e');
      return false;
    }
  }

  Future<bool> sendViaPlatformChannel(
    String phoneNumber,
    String message,
  ) async {
    try {
      print('Attempting platform channel SMS send...');

      const platform = MethodChannel('emergency_sms');

      final bool result = await platform.invokeMethod('sendDirectSMS', {
        'phoneNumber': phoneNumber,
        'message': message,
      });

      print('Platform channel SMS result: $result');
      return result;
    } catch (e) {
      print('Platform channel SMS failed: $e');
      return false;
    }
  }

  Future<bool> sendViaUrlLauncher(String phoneNumber, String message) async {
    try {
      final Uri smsUri = Uri(
        scheme: 'sms',
        path: phoneNumber,
        queryParameters: {'body': message},
      );

      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri, mode: LaunchMode.externalApplication);
        print('SMS app opened - manual send required');
        return false;
      }
      return false;
    } catch (e) {
      print('Error with URL launcher SMS: $e');
      return false;
    }
  }

  Future<bool> checkAndRequestSmsPermission() async {
    try {
      var smsStatus = await Permission.sms.status;
      print('Current SMS permission status: $smsStatus');

      if (smsStatus.isGranted) {
        return true;
      }

      if (smsStatus.isDenied || smsStatus.isRestricted) {
        print('Requesting SMS permission...');
        smsStatus = await Permission.sms.request();
        print('SMS permission after request: $smsStatus');
        return smsStatus.isGranted;
      }

      if (smsStatus.isPermanentlyDenied) {
        print('SMS permission permanently denied');
        return false;
      }

      return false;
    } catch (e) {
      print('Error checking SMS permission: $e');
      return false;
    }
  }

  Future<Map<String, bool>> sendEmergencyMessages(
    List<EmergencyContact> contacts,
    String emergencyMessage,
    bool smsPermissionGranted,
  ) async {
    print(
      'Starting emergency message broadcast to ${contacts.length} contacts',
    );

    Map<String, bool> results = {};

    final sortedContacts = List<EmergencyContact>.from(contacts)
      ..sort((a, b) => a.priority.compareTo(b.priority));

    await initializeTelephony();

    for (var contact in sortedContacts) {
      print(
        'Sending emergency SMS to ${contact.name} (${contact.phoneNumber})',
      );

      try {
        bool success = await sendDirectSMS(
          contact.phoneNumber,
          emergencyMessage,
          smsPermissionGranted,
        );

        results[contact.phoneNumber] = success;

        if (success) {
          print('Emergency SMS sent to ${contact.name}');
        } else {
          print('Failed to send emergency SMS to ${contact.name}');
        }

        await Future.delayed(Duration(milliseconds: 1000));
      } catch (e) {
        print('Error sending to ${contact.name}: $e');
        results[contact.phoneNumber] = false;
      }
    }

    int successCount = results.values.where((success) => success).length;
    int totalCount = results.length;
    print('Emergency SMS Results: $successCount/$totalCount sent successfully');

    return results;
  }

  Future<Map<String, bool>> sendLocationToAllContacts(
    List<EmergencyContact> contacts,
    String locationMessage,
    bool smsPermissionGranted,
  ) async {
    Map<String, bool> results = {};

    print('Sending location to ${contacts.length} contacts');

    await initializeTelephony();

    for (var contact in contacts) {
      if (contact.sendLocationSMS) {
        print(
          'Sending location SMS to ${contact.name} (${contact.phoneNumber})',
        );

        try {
          bool success = await sendDirectSMS(
            contact.phoneNumber,
            locationMessage,
            smsPermissionGranted,
          );

          results[contact.phoneNumber] = success;

          if (success) {
            print('Location SMS sent successfully to ${contact.name}');
          } else {
            print('Failed to send location SMS to ${contact.name}');
          }

          await Future.delayed(Duration(milliseconds: 1500));
        } catch (e) {
          print('Error sending location to ${contact.name}: $e');
          results[contact.phoneNumber] = false;
        }
      } else {
        print(
          'Skipping location SMS for ${contact.name} (disabled in settings)',
        );
      }
    }

    return results;
  }

  Future<void> startEmergencyServiceSound() async {
    if (isPlayingEmergencyServiceSound) {
      print('Emergency service sound already playing');
      return;
    }

    isPlayingEmergencyServiceSound = true;
    print('Starting EMERGENCY SERVICE sound');

    try {
      stopEmergencySound();
      await playCustomEmergencyServiceSound();

      if (!await isAudioPlaying()) {
        await playEmergencyServiceAlertPattern();
      }

      await performEmergencyServiceHaptics();
    } catch (e) {
      print('Error starting emergency service sound: $e');
      await playBasicEmergencyServiceSound();
    }
  }

  Future<void> playCustomEmergencyServiceSound() async {
    try {
      await audioPlayer.setSource(
        AssetSource('sounds/emergency_service_alert.mp3'),
      );
      await audioPlayer.setReleaseMode(ReleaseMode.loop);
      await audioPlayer.setVolume(1.0);
      await audioPlayer.resume();

      print('Custom emergency service sound started');

      soundTimer = Timer(Duration(seconds: 20), () {
        stopEmergencyServiceSound();
      });
    } catch (e) {
      print('Custom emergency service sound failed: $e');
      await createSyntheticEmergencyServiceSound();
    }
  }

  Future<void> createSyntheticEmergencyServiceSound() async {
    try {
      print('Creating synthetic emergency service sound pattern');

      soundTimer = Timer.periodic(Duration(milliseconds: 300), (timer) async {
        if (!isPlayingEmergencyServiceSound) {
          timer.cancel();
          return;
        }

        try {
          await SystemSound.play(SystemSoundType.alert);
          await Future.delayed(Duration(milliseconds: 100));
          await SystemSound.play(SystemSoundType.alert);
          await HapticFeedback.heavyImpact();
        } catch (e) {
          print('Error in emergency service beep: $e');
        }
      });

      Timer(Duration(seconds: 20), () {
        stopEmergencyServiceSound();
      });
    } catch (e) {
      print('Error creating synthetic emergency service sound: $e');
    }
  }

  Future<void> playEmergencyServiceAlertPattern() async {
    try {
      for (int i = 0; i < 8; i++) {
        if (!isPlayingEmergencyServiceSound) break;

        await SystemSound.play(SystemSoundType.alert);
        await Future.delayed(Duration(milliseconds: 150));
        await SystemSound.play(SystemSoundType.alert);
        await Future.delayed(Duration(milliseconds: 150));
        await SystemSound.play(SystemSoundType.alert);
        await Future.delayed(Duration(milliseconds: 500));
      }
    } catch (e) {
      print('Error playing emergency service alert pattern: $e');
    }
  }

  Future<void> performEmergencyServiceHaptics() async {
    try {
      for (int i = 0; i < 5; i++) {
        if (!isPlayingEmergencyServiceSound) break;

        await HapticFeedback.heavyImpact();
        await Future.delayed(Duration(milliseconds: 100));
        await HapticFeedback.heavyImpact();
        await Future.delayed(Duration(milliseconds: 100));
        await HapticFeedback.mediumImpact();
        await Future.delayed(Duration(milliseconds: 300));
      }
    } catch (e) {
      print('Error with emergency service haptics: $e');
    }
  }

  Future<void> playBasicEmergencyServiceSound() async {
    try {
      for (int i = 0; i < 3; i++) {
        await SystemSound.play(SystemSoundType.alert);
        await Future.delayed(Duration(milliseconds: 200));
      }
      await HapticFeedback.vibrate();
    } catch (e) {
      print('Error with basic emergency service sound: $e');
    }
  }

  void stopEmergencyServiceSound() {
    print('Stopping emergency service sound');
    isPlayingEmergencyServiceSound = false;

    try {
      soundTimer?.cancel();
      soundTimer = null;
      audioPlayer.stop();
    } catch (e) {
      print('Error stopping emergency service sound: $e');
    }
  }

  Future<void> startEmergencyAlertSound() async {
    if (isPlayingEmergencySound) {
      print('Emergency sound already playing');
      return;
    }

    isPlayingEmergencySound = true;
    print('Starting emergency alert sound');

    try {
      await playCustomEmergencySound();
      if (!await isAudioPlaying()) {
        await playSystemEmergencyAlerts();
      }
      await performEmergencyHaptics();
    } catch (e) {
      print('Error starting emergency sound: $e');
      await playBasicSystemSounds();
    }
  }

  Future<void> playCustomEmergencySound() async {
    try {
      await audioPlayer.setSource(AssetSource('sounds/emergency_alert.mp3'));
      await audioPlayer.setReleaseMode(ReleaseMode.loop);
      await audioPlayer.setVolume(1.0);
      await audioPlayer.resume();

      print('Custom emergency sound started');

      soundTimer = Timer(Duration(seconds: 15), () {
        stopEmergencySound();
      });
    } catch (e) {
      print('Custom emergency sound failed: $e');
      await createSyntheticEmergencySound();
    }
  }

  Future<void> createSyntheticEmergencySound() async {
    try {
      print('Creating synthetic emergency beeping');

      soundTimer = Timer.periodic(Duration(milliseconds: 500), (timer) async {
        if (!isPlayingEmergencySound) {
          timer.cancel();
          return;
        }

        try {
          await SystemSound.play(SystemSoundType.alert);
          await HapticFeedback.heavyImpact();
        } catch (e) {
          print('Error in synthetic beep: $e');
        }
      });

      Timer(Duration(seconds: 15), () {
        stopEmergencySound();
      });
    } catch (e) {
      print('Error creating synthetic sound: $e');
    }
  }

  Future<void> playSystemEmergencyAlerts() async {
    try {
      for (int i = 0; i < 5; i++) {
        if (!isPlayingEmergencySound) break;
        await SystemSound.play(SystemSoundType.alert);
        await Future.delayed(Duration(milliseconds: 300));
        await SystemSound.play(SystemSoundType.click);
        await Future.delayed(Duration(milliseconds: 300));
      }
    } catch (e) {
      print('Error playing system emergency alerts: $e');
    }
  }

  Future<void> performEmergencyHaptics() async {
    try {
      for (int i = 0; i < 3; i++) {
        if (!isPlayingEmergencySound) break;
        await HapticFeedback.heavyImpact();
        await Future.delayed(Duration(milliseconds: 200));
        await HapticFeedback.mediumImpact();
        await Future.delayed(Duration(milliseconds: 200));
        await HapticFeedback.lightImpact();
        await Future.delayed(Duration(milliseconds: 400));
      }
    } catch (e) {
      print('Error with emergency haptics: $e');
    }
  }

  Future<void> playBasicSystemSounds() async {
    try {
      await SystemSound.play(SystemSoundType.alert);
      await HapticFeedback.vibrate();
    } catch (e) {
      print('Error with basic system sounds: $e');
    }
  }

  Future<bool> isAudioPlaying() async {
    try {
      return audioPlayer.state == PlayerState.playing;
    } catch (e) {
      return false;
    }
  }

  void stopEmergencySound() {
    print('Stopping emergency alert sound');
    isPlayingEmergencySound = false;

    try {
      soundTimer?.cancel();
      soundTimer = null;
      audioPlayer.stop();
    } catch (e) {
      print('Error stopping emergency sound: $e');
    }
  }

  Future<void> playCountdownBeep() async {
    try {
      await SystemSound.play(SystemSoundType.click);
      await HapticFeedback.lightImpact();
    } catch (e) {
      print('Error playing countdown beep: $e');
    }
  }

  Future<void> playFinalCountdownSound() async {
    try {
      await SystemSound.play(SystemSoundType.alert);
      await HapticFeedback.heavyImpact();
    } catch (e) {
      print('Error playing final countdown sound: $e');
    }
  }

  Future<void> makeDirectCall(
    String phoneNumber,
    bool phonePermissionGranted,
  ) async {
    try {
      if (!phonePermissionGranted) {
        await makeCallViaApp(phoneNumber);
        return;
      }

      bool? canCall = await FlutterPhoneDirectCaller.callNumber(phoneNumber);
      if (canCall != true) {
        await makeCallViaApp(phoneNumber);
      }
    } catch (e) {
      print('Error making direct call: $e');
      await makeCallViaApp(phoneNumber);
    }
  }

  Future<void> makeCallViaApp(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('Error opening phone app: $e');
    }
  }

  void dispose() {
    stopEmergencySound();
    stopEmergencyServiceSound();
    audioPlayer.dispose();
  }
}
