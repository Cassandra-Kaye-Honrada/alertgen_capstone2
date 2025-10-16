class EmergencyContact {
  final String id;
  final String name;
  final String phoneNumber;
  final int priority;
  final bool sendLocationSMS;

  EmergencyContact({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.priority,
    this.sendLocationSMS = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phoneNumber': phoneNumber,
      'priority': priority,
      'sendLocationSMS': sendLocationSMS,
    };
  }

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      id: json['id'],
      name: json['name'],
      phoneNumber: json['phoneNumber'],
      priority: json['priority'],
      sendLocationSMS: json['sendLocationSMS'] ?? true,
    );
  }

  EmergencyContact copyWith({
    String? id,
    String? name,
    String? phoneNumber,
    int? priority,
    bool? sendLocationSMS,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      priority: priority ?? this.priority,
      sendLocationSMS: sendLocationSMS ?? this.sendLocationSMS,
    );
  }
}
