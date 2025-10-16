class EmergencySettings {
  final bool autoSendLocationToAll;
  final bool autoSendLocationToCurrentContact;
  final bool playAlertSound;
  final bool autoCallEmergencyServices;
  final int callTimeoutSeconds;
  final String emergencyServiceNumber;
  final bool enableDragToCancel;
  final int countdownDuration;

  EmergencySettings({
    this.autoSendLocationToAll = false,
    this.autoSendLocationToCurrentContact = true,
    this.playAlertSound = true,
    this.autoCallEmergencyServices = true,
    this.callTimeoutSeconds = 30,
    this.emergencyServiceNumber = '911',
    this.enableDragToCancel = true,
    this.countdownDuration = 5,
  });

  Map<String, dynamic> toJson() {
    return {
      'autoSendLocationToAll': autoSendLocationToAll,
      'autoSendLocationToCurrentContact': autoSendLocationToCurrentContact,
      'playAlertSound': playAlertSound,
      'autoCallEmergencyServices': autoCallEmergencyServices,
      'callTimeoutSeconds': callTimeoutSeconds,
      'emergencyServiceNumber': emergencyServiceNumber,
      'enableDragToCancel': enableDragToCancel,
      'countdownDuration': countdownDuration, 
    };
  }

  factory EmergencySettings.fromJson(Map<String, dynamic> json) {
    return EmergencySettings(
      autoSendLocationToAll: json['autoSendLocationToAll'] ?? false,
      autoSendLocationToCurrentContact:
          json['autoSendLocationToCurrentContact'] ?? true,
      playAlertSound: json['playAlertSound'] ?? true,
      autoCallEmergencyServices: json['autoCallEmergencyServices'] ?? true,
      callTimeoutSeconds: json['callTimeoutSeconds'] ?? 30,
      emergencyServiceNumber: json['emergencyServiceNumber'] ?? '911',
      enableDragToCancel: json['enableDragToCancel'] ?? true,
      countdownDuration: json['countdownDuration'] ?? 5,
    );
  }

  EmergencySettings copyWith({
    bool? autoSendLocationToAll,
    bool? autoSendLocationToCurrentContact,
    bool? playAlertSound,
    bool? autoCallEmergencyServices,
    int? callTimeoutSeconds,
    String? emergencyServiceNumber,
    bool? enableDragToCancel,
    int? countdownDuration,
  }) {
    return EmergencySettings(
      autoSendLocationToAll:
          autoSendLocationToAll ?? this.autoSendLocationToAll,
      autoSendLocationToCurrentContact:
          autoSendLocationToCurrentContact ??
          this.autoSendLocationToCurrentContact,
      playAlertSound: playAlertSound ?? this.playAlertSound,
      autoCallEmergencyServices:
          autoCallEmergencyServices ?? this.autoCallEmergencyServices,
      callTimeoutSeconds: callTimeoutSeconds ?? this.callTimeoutSeconds,
      emergencyServiceNumber:
          emergencyServiceNumber ?? this.emergencyServiceNumber,
      enableDragToCancel: enableDragToCancel ?? this.enableDragToCancel,
      countdownDuration: countdownDuration ?? this.countdownDuration,
    );
  }
}