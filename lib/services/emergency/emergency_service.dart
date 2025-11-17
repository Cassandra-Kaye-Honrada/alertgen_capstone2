import 'package:phone_state/phone_state.dart';
import 'dart:io' show Platform;

import 'dart:async';
import 'package:allergen/screens/models/emergency_call_state.dart';
import 'package:allergen/screens/models/emergency_contact.dart';
import 'package:allergen/screens/models/emergency_settings.dart';
import 'package:allergen/services/emergency/emergency_state_manager.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

import '../../../screens/emergency/emergency_screen.dart';
import '../../../screens/emergency/emergency_settings_screen.dart';
import '../../../widgets/emergency_widget.dart';
import 'emergency_permission_service.dart';
import 'emergency_location_service.dart';
import 'emergency_communication_service.dart';
import 'emergency_storage_service.dart';

class EmergencyService {
  static final EmergencyService _instance = EmergencyService._internal();
  factory EmergencyService() => _instance;
  EmergencyService._internal();

  final EmergencyStateManager _stateManager = EmergencyStateManager();
  final EmergencyPermissionService _permissionService =
      EmergencyPermissionService();
  final EmergencyLocationService _locationService = EmergencyLocationService();
  final EmergencyCommunicationService _communicationService =
      EmergencyCommunicationService();
  final EmergencyStorageService _storageService = EmergencyStorageService();

  List<EmergencyContact> _emergencyContacts = [];
  EmergencySettings _emergencySettings = EmergencySettings();
  bool _isInitialized = false;
  StreamSubscription<User?>? _authSubscription;

  Timer? _callTimeoutTimer;
  Timer? _postCallDelayTimer;
  bool _isCurrentlyInCall = false;
  bool _shouldContinueEmergencySequence = true;
  bool _isWaitingForCallTimeout = false;
  int _currentContactIndex = 0;

  int _currentSequenceId = 0;
  bool _isSequenceActive = false;

  Completer<void>? _callCompletionCompleter;

  Stream<EmergencyCallState> get stateStream => _stateManager.stateStream;
  Stream<EmergencyContact?> get currentContactStream =>
      _stateManager.currentContactStream;
  Stream<int> get countdownStream => _stateManager.countdownStream;
  List<EmergencyContact> get emergencyContacts => _emergencyContacts;
  EmergencySettings get emergencySettings => _emergencySettings;
  bool get isInitialized => _isInitialized;
  bool get hasContacts => _emergencyContacts.isNotEmpty;
  EmergencyCallState get currentState => _stateManager.currentState;
  bool get smsPermissionGranted => _permissionService.smsPermissionGranted;
  bool get phonePermissionGranted => _permissionService.phonePermissionGranted;
  bool get locationPermissionGranted =>
      _permissionService.locationPermissionGranted;

  StreamSubscription<PhoneState>? _phoneStateSubscription;
  bool _callStateMonitoringEnabled = false;
  String? _currentCallNumber;
  DateTime? _callStartTime;

  Future<bool> makeCallAndWaitForTimeout(
    EmergencyContact contact,
    EmergencySettings settings,
    int sequenceId,
  ) async {
    print(
      '[Seq #$sequenceId] Making call to ${contact.name} (${contact.phoneNumber})',
    );

    _isCurrentlyInCall = true;
    _isWaitingForCallTimeout = true;
    _currentCallNumber = contact.phoneNumber;
    _callStartTime = DateTime.now();

    _callCompletionCompleter = Completer<void>();

    await startCallStateMonitoring(contact.phoneNumber, sequenceId);

    await _communicationService.makeDirectCall(
      contact.phoneNumber,
      _permissionService.phonePermissionGranted,
    );

    print(
      '[Seq #$sequenceId] Call initiated, monitoring call state with 15-second max timeout',
    );

    bool timedOut = false;
    bool callEndedNaturally = false;

    _callTimeoutTimer?.cancel();

    _callTimeoutTimer = Timer(Duration(seconds: 15), () {
      print(
        '[Seq #$sequenceId] 15-second MAX timeout reached for ${contact.name}',
      );
      if (sequenceId == _currentSequenceId &&
          _isSequenceActive &&
          _isWaitingForCallTimeout) {
        timedOut = true;
        handleCallTimeout(sequenceId, isMaxTimeout: true);
      }
    });

    try {
      await _callCompletionCompleter!.future;
    } catch (e) {
      print('Call completion error: $e');
    }

    await stopCallStateMonitoring();

    _callTimeoutTimer?.cancel();
    _callTimeoutTimer = null;
    _isCurrentlyInCall = false;
    _isWaitingForCallTimeout = false;
    _callCompletionCompleter = null;
    _currentCallNumber = null;
    _callStartTime = null;

    print(
      '[Seq #$sequenceId] Call to ${contact.name} completed. Timed out: $timedOut, Natural end: $callEndedNaturally',
    );

    return timedOut;
  }

  Future<void> startCallStateMonitoring(
    String phoneNumber,
    int sequenceId,
  ) async {
    if (!Platform.isAndroid) {
      print('Call state monitoring only available on Android');
      return;
    }

    try {
      await stopCallStateMonitoring();

      _callStateMonitoringEnabled = true;

      _phoneStateSubscription = PhoneState.stream.listen((PhoneState state) {
        handlePhoneStateChange(state, phoneNumber, sequenceId);
      });
    } catch (e) {
      print('Error starting call state monitoring: $e');
    }
  }

  void handlePhoneStateChange(
    PhoneState state,
    String phoneNumber,
    int sequenceId,
  ) {
    if (sequenceId != _currentSequenceId ||
        !_isSequenceActive ||
        !_callStateMonitoringEnabled) {
      return;
    }

    print(
      '[Seq #$sequenceId] Phone state changed: ${state.status} - ${state.number}',
    );

    switch (state.status) {
      case PhoneStateStatus.CALL_STARTED:
        if (isCurrentCallForContact(state.number, phoneNumber)) {
          print('[Seq #$sequenceId] Call STARTED detected for ${phoneNumber}');
        }
        break;

      case PhoneStateStatus.CALL_ENDED:
        if (isCurrentCallForContact(state.number, phoneNumber)) {
          print('[Seq #$sequenceId] Call ENDED detected for ${phoneNumber}');
          handleCallEndedNaturally(sequenceId);
        }
        break;

      case PhoneStateStatus.CALL_INCOMING:
        print('[Seq #$sequenceId] Incoming call detected: ${state.number}');
        break;

      case PhoneStateStatus.NOTHING:
        if (_isWaitingForCallTimeout && _callStartTime != null) {
          final elapsed = DateTime.now().difference(_callStartTime!);
          if (elapsed.inSeconds >= 2) {
            print(
              '[Seq #$sequenceId] Call likely ended/rejected for ${phoneNumber} (state: NOTHING after ${elapsed.inSeconds}s)',
            );
            handleCallEndedNaturally(sequenceId);
          }
        }
        break;
    }
  }

  bool isCurrentCallForContact(String? stateNumber, String targetNumber) {
    if (stateNumber == null || targetNumber.isEmpty) return false;

    String cleanStateNumber = cleanPhoneNumber(stateNumber);
    String cleanTargetNumber = cleanPhoneNumber(targetNumber);

    return cleanStateNumber == cleanTargetNumber ||
        (cleanStateNumber.length >= 7 &&
            cleanTargetNumber.length >= 7 &&
            cleanStateNumber.substring(cleanStateNumber.length - 7) ==
                cleanTargetNumber.substring(cleanTargetNumber.length - 7));
  }

  String cleanPhoneNumber(String phoneNumber) {
    return phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
  }

  void handleCallEndedNaturally(int sequenceId) {
    if (sequenceId != _currentSequenceId ||
        !_isSequenceActive ||
        !_isWaitingForCallTimeout) {
      return;
    }

    print(
      '[Seq #$sequenceId] Call ended naturally - NOT continuing to next contact',
    );

    _shouldContinueEmergencySequence = false;

    if (_callCompletionCompleter != null &&
        !_callCompletionCompleter!.isCompleted) {
      _callCompletionCompleter!.complete();
    }
  }

  Future<void> stopCallStateMonitoring() async {
    _callStateMonitoringEnabled = false;
    _phoneStateSubscription?.cancel();
    _phoneStateSubscription = null;
  }

  Future<void> initialize() async {
    if (_isInitialized) {
      await forceReload();
      return;
    }

    try {
      await loadSettings();
      await _permissionService.requestAllPermissions();
      listenToAuthChanges();
      _isInitialized = true;
    } catch (e) {
      print('Error initializing EmergencyService: $e');
      rethrow;
    }
  }

  Future<void> loadSettings() async {
    try {
      final data = await _storageService.loadSettings();
      _emergencyContacts = data['contacts'] ?? [];
      _emergencySettings = data['settings'] ?? EmergencySettings();
    } catch (e) {
      print('Error loading settings: $e');
      _emergencyContacts = [];
      _emergencySettings = EmergencySettings();
    }
  }

  void listenToAuthChanges() {
    _authSubscription?.cancel();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((
      User? user,
    ) {
      if (user != null) {
        _storageService.syncOnLogin().catchError((e) {
          print('Error syncing on login: $e');
        });
      }
    });
  }

  Future<bool> requestPermissionsManually() async {
    try {
      await _permissionService.requestAllPermissions();
      return _permissionService.allPermissionsGranted;
    } catch (e) {
      print('Error requesting permissions: $e');
      return false;
    }
  }

  Future<void> forceReload() async {
    await loadSettings();
  }

  Future<void> saveSettings(
    List<EmergencyContact> contacts,
    EmergencySettings settings,
  ) async {
    try {
      _emergencyContacts = contacts;
      _emergencySettings = settings;
      await _storageService.saveSettings(contacts, settings);
    } catch (e) {
      print('Error saving settings: $e');
      rethrow;
    }
  }

  Future<void> syncOnLogin() async {
    try {
      await _storageService.syncOnLogin();
      await forceReload();
    } catch (e) {
      print('Error syncing on login: $e');
    }
  }

  Future<Map<String, bool>> sendEmergencyMessagesDirectly({
    String? customMessage,
    bool includeLocation = true,
  }) async {
    print('EMERGENCY: Sending direct emergency messages');

    try {
      await forceReload();

      if (_emergencyContacts.isEmpty) {
        print('No emergency contacts available');
        return {};
      }

      bool smsGranted =
          await _communicationService.checkAndRequestSmsPermission();
      if (!smsGranted) {
        print('SMS permission not granted');
        return {};
      }

      if (includeLocation && _permissionService.locationPermissionGranted) {
        await _locationService.getCurrentLocationAndAddress();
      }

      String message = customMessage ?? createEmergencyMessage(includeLocation);

      Map<String, bool> results = await _communicationService
          .sendEmergencyMessages(_emergencyContacts, message, smsGranted);

      int successCount = results.values.where((success) => success).length;
      print(
        'Emergency messages sent: $successCount/${results.length} successful',
      );

      return results;
    } catch (e) {
      print('Error sending emergency messages: $e');
      return {};
    }
  }

  String createEmergencyMessage(bool includeLocation) {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final dateStr = '${now.day}/${now.month}/${now.year}';

    if (includeLocation && _locationService.currentPosition != null) {
      return _locationService.createLocationMessage();
    } else {
      return ' EMERGENCY: I need help!\n\nPlease call me immediately!\n\n🕐 Time: $timeStr on $dateStr';
    }
  }

  Future<void> startEmergencyCall({
    List<EmergencyContact>? contacts,
    EmergencySettings? settings,
  }) async {
    if (_stateManager.currentState != EmergencyCallState.idle) {
      print('Emergency call already in progress');
      return;
    }

    try {
      cleanupCurrentSequence();

      _shouldContinueEmergencySequence = true;
      _isCurrentlyInCall = false;
      _isWaitingForCallTimeout = false;
      _currentContactIndex = 0;
      _currentSequenceId++;
      _isSequenceActive = true;

      _stateManager.resetState();

      final contactsToUse = contacts ?? _emergencyContacts;
      final settingsToUse = settings ?? _emergencySettings;

      if (contactsToUse.isEmpty) {
        print('No emergency contacts available');
        _stateManager.updateState(EmergencyCallState.error);
        _isSequenceActive = false;
        return;
      }

      final sortedContacts = List<EmergencyContact>.from(contactsToUse)
        ..sort((a, b) => a.priority.compareTo(b.priority));
      _stateManager.setRemainingContacts(sortedContacts);

      _stateManager.updateState(EmergencyCallState.initializing);

      print(
        'Starting emergency sequence #$_currentSequenceId with ${sortedContacts.length} contacts',
      );

      if (_permissionService.locationPermissionGranted) {
        await _locationService.getCurrentLocationAndAddress();
      }

      if (settingsToUse.autoSendLocationToAll &&
          _locationService.currentPosition != null) {
        Map<String, bool> results = await _communicationService
            .sendLocationToAllContacts(
              sortedContacts,
              _locationService.createLocationMessage(),
              _permissionService.smsPermissionGranted,
            );

        int successCount = results.values.where((success) => success).length;
        print(
          'Location messages sent: $successCount/${results.length} successful',
        );
      }

      await startCallingSequence(settingsToUse);
    } catch (e) {
      print('Emergency service error: $e');
      _stateManager.updateState(EmergencyCallState.error);
      _isSequenceActive = false;
    }
  }

  void cleanupCurrentSequence() {
    _callTimeoutTimer?.cancel();
    _postCallDelayTimer?.cancel();
    _callTimeoutTimer = null;
    _postCallDelayTimer = null;
    _callCompletionCompleter?.complete();
    _callCompletionCompleter = null;
    _communicationService.stopEmergencySound();
    _communicationService.stopEmergencyServiceSound();
    _stateManager.cancelTimer();

    stopCallStateMonitoring();
  }

  Future<void> startCallingSequence(EmergencySettings settings) async {
    final sortedContacts = List<EmergencyContact>.from(_emergencyContacts)
      ..sort((a, b) => a.priority.compareTo(b.priority));

    final sequenceId = _currentSequenceId;

    print(
      '[Seq #$sequenceId] Starting calling sequence with ${sortedContacts.length} contacts',
    );

    for (
      int contactIndex = 0;
      contactIndex < sortedContacts.length;
      contactIndex++
    ) {
      if (!_shouldContinueEmergencySequence ||
          !_isSequenceActive ||
          sequenceId != _currentSequenceId) {
        print(
          '[Seq #$sequenceId] Sequence stopped or cancelled at contact $contactIndex',
        );
        break;
      }

      _currentContactIndex = contactIndex;
      final currentContact = sortedContacts[contactIndex];
      _stateManager.setCurrentContact(currentContact);
      _stateManager.updateState(EmergencyCallState.calling);

      print(
        '[Seq #$sequenceId] Starting call sequence for: ${currentContact.name} (${contactIndex + 1}/${sortedContacts.length})',
      );

      if (settings.autoSendLocationToCurrentContact &&
          currentContact.sendLocationSMS &&
          _locationService.currentPosition != null) {
        bool success = await _communicationService.sendDirectSMS(
          currentContact.phoneNumber,
          _locationService.createLocationMessage(),
          _permissionService.smsPermissionGranted,
        );

        if (success) {
          print('Location SMS sent to ${currentContact.name}');
        } else {
          print('Failed to send location SMS to ${currentContact.name}');
        }
      }

      if (settings.playAlertSound) {
        await _communicationService.startEmergencyAlertSound();
      }

      await startCountdown(5, sequenceId);

      if (!_shouldContinueEmergencySequence ||
          !_isSequenceActive ||
          sequenceId != _currentSequenceId) {
        print('[Seq #$sequenceId] Sequence invalidated after countdown');
        break;
      }

      _communicationService.stopEmergencySound();

      bool callCompleted = await makeCallAndWaitForTimeout(
        currentContact,
        settings,
        sequenceId,
      );

      if (!_shouldContinueEmergencySequence ||
          !_isSequenceActive ||
          sequenceId != _currentSequenceId) {
        print('[Seq #$sequenceId] Sequence invalidated after call');
        break;
      }

      if (!callCompleted) {
        print('[Seq #$sequenceId] Call sequence ended by user action');
        break;
      }

      print(
        '[Seq #$sequenceId] Call to ${currentContact.name} timed out, moving to next contact',
      );

      if (contactIndex < sortedContacts.length - 1) {
        await Future.delayed(Duration(milliseconds: 500));
      }
    }

    if (_shouldContinueEmergencySequence &&
        _isSequenceActive &&
        sequenceId == _currentSequenceId) {
      print(
        '[Seq #$sequenceId] All contacts exhausted, proceeding to emergency services',
      );
      await callEmergencyServices(settings, sequenceId);
    } else {
      print(
        '[Seq #$sequenceId] Sequence ended without calling emergency services',
      );
      _isSequenceActive = false;
    }
  }

  void handleCallTimeout(int sequenceId, {bool isMaxTimeout = false}) {
    if (sequenceId != _currentSequenceId || !_isSequenceActive) {
      print(
        '[Seq #$sequenceId] Ignoring stale timeout - current sequence is #$_currentSequenceId',
      );
      return;
    }

    if (_isWaitingForCallTimeout && _shouldContinueEmergencySequence) {
      if (isMaxTimeout) {
        print(
          '[Seq #$sequenceId] Maximum timeout reached - will continue to next contact',
        );
      } else {
        print(
          '[Seq #$sequenceId] Handling call timeout - will continue to next contact',
        );
      }

      if (_callCompletionCompleter != null &&
          !_callCompletionCompleter!.isCompleted) {
        _callCompletionCompleter!.complete();
      }
    }
  }

  Future<void> startCountdown(int countdownSeconds, int sequenceId) async {
    print('[Seq #$sequenceId] Starting ${countdownSeconds}-second countdown');

    for (int i = countdownSeconds; i > 0; i--) {
      if (!_shouldContinueEmergencySequence ||
          _stateManager.currentState == EmergencyCallState.cancelled ||
          sequenceId != _currentSequenceId ||
          !_isSequenceActive) {
        print('[Seq #$sequenceId] Countdown cancelled');
        break;
      }

      _stateManager.addCountdown(i);
      print('[Seq #$sequenceId] Countdown: $i');

      if (i <= 3) {
        await _communicationService.playFinalCountdownSound();
      } else {
        await _communicationService.playCountdownBeep();
      }

      await Future.delayed(Duration(seconds: 1));
    }

    if (_shouldContinueEmergencySequence &&
        _stateManager.currentState != EmergencyCallState.cancelled &&
        sequenceId == _currentSequenceId &&
        _isSequenceActive) {
      _stateManager.addCountdown(0);
      print('[Seq #$sequenceId] Countdown complete');
    }
  }

  Future<void> callEmergencyServices(
    EmergencySettings settings,
    int sequenceId,
  ) async {
    if (!_shouldContinueEmergencySequence ||
        sequenceId != _currentSequenceId ||
        !_isSequenceActive) {
      print(
        '[Seq #$sequenceId] Emergency sequence completed - not calling emergency services',
      );
      _stateManager.updateState(EmergencyCallState.completed);
      _isSequenceActive = false;
      return;
    }

    _stateManager.setCurrentContact(null);
    _stateManager.updateState(EmergencyCallState.callingEmergencyServices);

    print(
      '[Seq #$sequenceId] All contacts exhausted - calling emergency services',
    );

    if (settings.playAlertSound) {
      await _communicationService.startEmergencyServiceSound();
    }
    print(
      '[Seq #$sequenceId] Starting 5-second countdown before calling emergency services',
    );

    for (int i = 5; i > 0; i--) {
      if (_stateManager.currentState !=
              EmergencyCallState.callingEmergencyServices ||
          !_shouldContinueEmergencySequence ||
          sequenceId != _currentSequenceId ||
          !_isSequenceActive) {
        _communicationService.stopEmergencyServiceSound();
        return;
      }

      _stateManager.addCountdown(i);
      print('[Seq #$sequenceId] Emergency services countdown: $i');

      if (i <= 3) {
        await _communicationService.playFinalCountdownSound();
      } else {
        await _communicationService.playCountdownBeep();
      }

      await Future.delayed(Duration(seconds: 1));
    }

    if (_stateManager.currentState ==
            EmergencyCallState.callingEmergencyServices &&
        _shouldContinueEmergencySequence &&
        sequenceId == _currentSequenceId &&
        _isSequenceActive) {
      _stateManager.addCountdown(0);

      _communicationService.stopEmergencyServiceSound();

      print(
        '[Seq #$sequenceId] Calling emergency services: ${settings.emergencyServiceNumber}',
      );

      await _communicationService.makeDirectCall(
        settings.emergencyServiceNumber,
        _permissionService.phonePermissionGranted,
      );

      Timer(Duration(seconds: 30), () {
        if (_stateManager.currentState ==
                EmergencyCallState.callingEmergencyServices &&
            sequenceId == _currentSequenceId) {
          print('[Seq #$sequenceId] Emergency services call completed');
          _stateManager.updateState(EmergencyCallState.completed);
          _isSequenceActive = false;
        }
      });
    }
  }

  void cancelEmergencyCall() {
    print('[Seq #$_currentSequenceId] Cancelling emergency call sequence');

    _shouldContinueEmergencySequence = false;
    _isCurrentlyInCall = false;
    _isWaitingForCallTimeout = false;
    _isSequenceActive = false;

    if (_callCompletionCompleter != null &&
        !_callCompletionCompleter!.isCompleted) {
      _callCompletionCompleter!.complete();
    }

    cleanupCurrentSequence();
    _stateManager.updateState(EmergencyCallState.cancelled);

    Timer(Duration(seconds: 2), () {
      _stateManager.resetState();
      _currentContactIndex = 0;
    });
  }

  void markContactResponded() {
    print(
      '[Seq #$_currentSequenceId] Contact responded - ending emergency sequence',
    );

    _shouldContinueEmergencySequence = false;
    _isCurrentlyInCall = false;
    _isWaitingForCallTimeout = false;
    _isSequenceActive = false;

    if (_callCompletionCompleter != null &&
        !_callCompletionCompleter!.isCompleted) {
      _callCompletionCompleter!.complete();
    }

    cleanupCurrentSequence();
    _stateManager.updateState(EmergencyCallState.completed);

    Timer(Duration(seconds: 2), () {
      _stateManager.resetState();
      _currentContactIndex = 0;
    });
  }

  void skipToNextContact() {
    if (_isWaitingForCallTimeout &&
        _shouldContinueEmergencySequence &&
        _isSequenceActive) {
      print('⏭️ [Seq #$_currentSequenceId] Manually skipping to next contact');

      _callTimeoutTimer?.cancel();
      _isCurrentlyInCall = false;
      _isWaitingForCallTimeout = false;

      if (_callCompletionCompleter != null &&
          !_callCompletionCompleter!.isCompleted) {
        _callCompletionCompleter!.complete();
      }
    }
  }

  String getCurrentLocationInfo() {
    return _locationService.getCurrentLocationInfo();
  }

  Future<void> startEmergencyCallFromUI(BuildContext context) async {
    try {
      await forceReload();

      if (_emergencyContacts.isEmpty) {
        if (context.mounted) {
          showNoContactsDialog(context);
        }
        return;
      }
      if (!_permissionService.smsPermissionGranted ||
          !_permissionService.phonePermissionGranted) {
        if (context.mounted) {
          bool granted = await showPermissionDialog(context);
          if (!granted) return;
        }
      }

      if (context.mounted) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => EmergencyScreen(
                  emergencyContacts: _emergencyContacts,
                  emergencySettings: _emergencySettings,
                ),
          ),
        );
        _stateManager.resetState();
      }
    } catch (e) {
      print('Error starting emergency call from UI: $e');
      if (context.mounted) {
        showErrorDialog(context, e.toString());
      }
    }
  }

  Future<void> sendEmergencyMessagesFromUI(BuildContext context) async {
    try {
      await forceReload();

      if (_emergencyContacts.isEmpty) {
        if (context.mounted) {
          showNoContactsDialog(context);
        }
        return;
      }

      bool isDialogShown = false;

      if (context.mounted) {
        isDialogShown = true;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (dialogContext) => AlertDialog(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Sending emergency messages...'),
                  ],
                ),
              ),
        );
      }

      Map<String, bool> results = await sendEmergencyMessagesDirectly();

      if (isDialogShown && context.mounted) {
        Navigator.of(context).pop();
      }
      if (context.mounted) {
        showResultsDialog(context, results);
      }
    } catch (e) {
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      if (context.mounted) {
        showErrorDialog(context, e.toString());
      }
    }
  }

  void showResultsDialog(BuildContext context, Map<String, bool> results) {
    if (!context.mounted) return;

    int successCount = results.values.where((success) => success).length;
    int totalCount = results.length;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Emergency Messages Sent'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Successfully sent: $successCount/$totalCount'),
                SizedBox(height: 12),
                ...results.entries.map((entry) {
                  String phoneNumber = entry.key;
                  bool success = entry.value;

                  String contactName =
                      _emergencyContacts
                          .firstWhere(
                            (contact) => contact.phoneNumber == phoneNumber,
                            orElse:
                                () => EmergencyContact(
                                  id: '',
                                  name: phoneNumber,
                                  phoneNumber: phoneNumber,
                                  priority: 0,
                                  sendLocationSMS: false,
                                ),
                          )
                          .name;

                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Icon(
                          success ? Icons.check_circle : Icons.error,
                          color: success ? Colors.green : Colors.red,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Expanded(child: Text(contactName)),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK'),
              ),
            ],
          ),
    );
  }

  void showErrorDialog(BuildContext context, String error) {
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Error'),
            content: Text('An error occurred: $error'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK'),
              ),
            ],
          ),
    );
  }

  Future<void> showSettings(BuildContext context) async {
    try {
      await forceReload();

      if (context.mounted) {
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder:
                (context) => EmergencySettingsScreen(
                  emergencyContacts: _emergencyContacts,
                  emergencySettings: _emergencySettings,
                  onSave: saveSettings,
                  emergencyService: this,
                ),
          ),
        );

        if (result == true) {
          await forceReload();
        }
      }
    } catch (e) {
      print('Error showing settings: $e');
      if (context.mounted) {
        showErrorDialog(context, e.toString());
      }
    }
  }

  Widget buildEmergencyWidget(
    BuildContext context, {
    bool showSettings = true,
    bool showStatus = true,
  }) {
    return EmergencyWidget(
      emergencyService: this,
      showSettings: showSettings,
      showStatus: showStatus,
    );
  }

  Future<bool> showPermissionDialog(BuildContext context) async {
    if (!context.mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Text('Permissions Required'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Emergency services require phone and SMS permissions to function properly.',
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      _permissionService.phonePermissionGranted
                          ? Icons.check_circle
                          : Icons.error,
                      color:
                          _permissionService.phonePermissionGranted
                              ? Colors.green
                              : Colors.red,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Text('Phone Permission'),
                  ],
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      _permissionService.smsPermissionGranted
                          ? Icons.check_circle
                          : Icons.error,
                      color:
                          _permissionService.smsPermissionGranted
                              ? Colors.green
                              : Colors.red,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Text('SMS Permission'),
                  ],
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      _permissionService.locationPermissionGranted
                          ? Icons.check_circle
                          : Icons.warning,
                      color:
                          _permissionService.locationPermissionGranted
                              ? Colors.green
                              : Colors.orange,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Text('Location Permission (optional)'),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop(true);
                  await requestPermissionsManually();
                },
                child: Text('Grant Permissions'),
              ),
            ],
          ),
    );

    return result ?? false;
  }

  void showNoContactsDialog(BuildContext context) {
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text('No Emergency Contacts'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.contacts_outlined, size: 48, color: Colors.orange),
                SizedBox(height: 16),
                Text(
                  'You need to add emergency contacts before using this feature.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  showSettings(context);
                },
                child: Text('Add Contacts'),
              ),
            ],
          ),
    );
  }

  Stream<bool> get isEmergencyActiveStream {
    return _stateManager.stateStream.map(
      (state) =>
          state != EmergencyCallState.idle &&
          state != EmergencyCallState.completed &&
          state != EmergencyCallState.cancelled,
    );
  }

  bool get isEmergencyActive {
    final state = _stateManager.currentState;
    return state != EmergencyCallState.idle &&
        state != EmergencyCallState.completed &&
        state != EmergencyCallState.cancelled;
  }

  // void debugPrintState() {
  //   print('Current State: ${_stateManager.currentState}');
  //   print('Is Initialized: $_isInitialized');
  //   print('Contacts Count: ${_emergencyContacts.length}');
  //   print('Current Contact Index: $_currentContactIndex');
  //   print('Is Currently In Call: $_isCurrentlyInCall');
  //   print('Is Waiting For Call Timeout: $_isWaitingForCallTimeout');
  //   print(
  //     'Should Continue Emergency Sequence: $_shouldContinueEmergencySequence',
  //   );
  //   print('Current Sequence ID: $_currentSequenceId');
  //   print('Is Sequence Active: $_isSequenceActive');
  //   print('SMS Permission: ${_permissionService.smsPermissionGranted}');
  //   print('Phone Permission: ${_permissionService.phonePermissionGranted}');
  //   print(
  //     'Location Permission: ${_permissionService.locationPermissionGranted}',
  //   );
  // }

  // void dispose() {
  //   print('Disposing EmergencyService');

  //   _shouldContinueEmergencySequence = false;
  //   _isSequenceActive = false;

  //   cleanupCurrentSequence();
  //   stopCallStateMonitoring();
  //   _authSubscription?.cancel();
  //   _stateManager.dispose();
  //   _locationService.dispose();
  //   _communicationService.dispose();

  //   _isInitialized = false;

  //   print('EmergencyService disposed');
  // }
  void dispose() {
    print('🧹 Disposing EmergencyService (Sequence #$_currentSequenceId)');

    // Stop all active sequences immediately
    _shouldContinueEmergencySequence = false;
    _isSequenceActive = false;
    _isCurrentlyInCall = false;
    _isWaitingForCallTimeout = false;

    // Complete any pending completers to prevent hanging futures
    if (_callCompletionCompleter != null &&
        !_callCompletionCompleter!.isCompleted) {
      try {
        _callCompletionCompleter!.complete();
      } catch (e) {
        print('Error completing call completer during dispose: $e');
      }
    }
    _callCompletionCompleter = null;

    // Cancel all timers
    _callTimeoutTimer?.cancel();
    _postCallDelayTimer?.cancel();
    _callTimeoutTimer = null;
    _postCallDelayTimer = null;

    // Stop phone state monitoring
    _callStateMonitoringEnabled = false;
    _phoneStateSubscription?.cancel();
    _phoneStateSubscription = null;

    // Clean up current call state
    _currentCallNumber = null;
    _callStartTime = null;
    _currentContactIndex = 0;

    // Cancel auth subscription
    _authSubscription?.cancel();
    _authSubscription = null;

    // Dispose all service managers
    try {
      _stateManager.dispose();
    } catch (e) {
      print('Error disposing state manager: $e');
    }

    try {
      _locationService.dispose();
    } catch (e) {
      print('Error disposing location service: $e');
    }

    try {
      _communicationService.dispose();
    } catch (e) {
      print('Error disposing communication service: $e');
    }

    // Stop any playing sounds
    _communicationService.stopEmergencySound();
    _communicationService.stopEmergencyServiceSound();

    // Clear data
    _emergencyContacts.clear();
    _isInitialized = false;

    print('✅ EmergencyService disposed successfully');
  }

  Future<Map<String, dynamic>> getHealthStatus() async {
    return {
      'isInitialized': _isInitialized,
      'contactsCount': _emergencyContacts.length,
      'hasPermissions': {
        'sms': _permissionService.smsPermissionGranted,
        'phone': _permissionService.phonePermissionGranted,
        'location': _permissionService.locationPermissionGranted,
      },
      'currentState': _stateManager.currentState.toString(),
      'isActive': isEmergencyActive,
      'sequenceId': _currentSequenceId,
      'locationAvailable': _locationService.currentPosition != null,
    };
  }

  Future<List<String>> validateEmergencySetup() async {
    List<String> issues = [];

    if (!_isInitialized) {
      issues.add('Emergency service not initialized');
    }

    if (_emergencyContacts.isEmpty) {
      issues.add('No emergency contacts configured');
    }

    if (!_permissionService.phonePermissionGranted) {
      issues.add('Phone permission not granted');
    }

    if (!_permissionService.smsPermissionGranted) {
      issues.add('SMS permission not granted');
    }

    Set<String> phoneNumbers = {};
    for (var contact in _emergencyContacts) {
      if (phoneNumbers.contains(contact.phoneNumber)) {
        issues.add('Duplicate phone number found: ${contact.phoneNumber}');
      }
      phoneNumbers.add(contact.phoneNumber);
    }

    for (var contact in _emergencyContacts) {
      if (contact.phoneNumber.isEmpty) {
        issues.add('Empty phone number for contact: ${contact.name}');
      }
    }

    return issues;
  }

  Map<String, dynamic> getEmergencySummary() {
    return {
      'totalContacts': _emergencyContacts.length,
      'priorityContacts':
          _emergencyContacts.where((c) => c.priority <= 2).length,
      'locationEnabledContacts':
          _emergencyContacts.where((c) => c.sendLocationSMS).length,
      'autoCallEmergencyServices': _emergencySettings.autoCallEmergencyServices,
      'emergencyServiceNumber': _emergencySettings.emergencyServiceNumber,
      'playAlertSound': _emergencySettings.playAlertSound,
      'autoSendLocationToAll': _emergencySettings.autoSendLocationToAll,
      'autoSendLocationToCurrentContact':
          _emergencySettings.autoSendLocationToCurrentContact,
    };
  }
}
