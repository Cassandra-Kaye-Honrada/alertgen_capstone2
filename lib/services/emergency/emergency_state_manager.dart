import 'dart:async';
import 'package:allergen/screens/models/emergency_call_state.dart';
import 'package:allergen/screens/models/emergency_contact.dart';

class EmergencyStateManager {
  final StreamController<EmergencyCallState> _stateController =
      StreamController<EmergencyCallState>.broadcast();
  final StreamController<EmergencyContact?> _currentContactController =
      StreamController<EmergencyContact?>.broadcast();
  final StreamController<int> _countdownController =
      StreamController<int>.broadcast();

  EmergencyCallState _currentState = EmergencyCallState.idle;
  EmergencyContact? _currentContact;
  List<EmergencyContact> _remainingContacts = [];
  Timer? _callTimer;

  Stream<EmergencyCallState> get stateStream => _stateController.stream;
  Stream<EmergencyContact?> get currentContactStream =>
      _currentContactController.stream;
  Stream<int> get countdownStream => _countdownController.stream;
  EmergencyCallState get currentState => _currentState;
  EmergencyContact? get currentContact => _currentContact;
  List<EmergencyContact> get remainingContacts => _remainingContacts;

  void updateState(EmergencyCallState state) {
    _currentState = state;
    _stateController.add(state);
  }

  void setCurrentContact(EmergencyContact? contact) {
    _currentContact = contact;
    _currentContactController.add(contact);
  }

  void setRemainingContacts(List<EmergencyContact> contacts) {
    _remainingContacts = List.from(contacts);
  }

  void addCountdown(int count) {
    _countdownController.add(count);
  }

  void setCallTimer(Timer timer) {
    _callTimer?.cancel();
    _callTimer = timer;
  }

  void cancelTimer() {
    _callTimer?.cancel();
    _callTimer = null;
  }

  void resetState() {
    _callTimer?.cancel();
    _callTimer = null;
    _currentContact = null;
    _remainingContacts.clear();
    _currentState = EmergencyCallState.idle;
    _currentContactController.add(null);
  }

  void dispose() {
    _callTimer?.cancel();
    _stateController.close();
    _currentContactController.close();
    _countdownController.close();
  }
}
