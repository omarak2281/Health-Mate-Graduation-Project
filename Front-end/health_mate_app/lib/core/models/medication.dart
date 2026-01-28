/// Medication Model

class Medication {
  final String id;
  final String userId;
  final String name;
  final String dosage;
  final String? instructions;
  final String frequency;
  final List<String> timeSlots;
  final int? drawerNumber;
  final bool isActive;
  final bool enableLed;
  final bool enableBuzzer;
  final bool enableNotification;
  final String? imageUrl;
  final String? formFactor;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime createdAt;

  Medication({
    required this.id,
    required this.userId,
    required this.name,
    required this.dosage,
    this.instructions,
    required this.frequency,
    required this.timeSlots,
    this.drawerNumber,
    required this.isActive,
    required this.enableLed,
    required this.enableBuzzer,
    required this.enableNotification,
    this.imageUrl,
    this.formFactor,
    required this.startDate,
    this.endDate,
    required this.createdAt,
  });

  factory Medication.fromJson(Map<String, dynamic> json) {
    return Medication(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      dosage: json['dosage']?.toString() ?? '',
      instructions: json['instructions']?.toString(),
      frequency: json['frequency']?.toString() ?? 'daily',
      timeSlots: json['time_slots'] != null
          ? List<String>.from(json['time_slots'].map((e) => e.toString()))
          : [],
      drawerNumber: json['drawer_number'] is int
          ? json['drawer_number']
          : int.tryParse(json['drawer_number']?.toString() ?? ''),
      isActive: json['is_active'] == true,
      enableLed: json['enable_led'] == true,
      enableBuzzer: json['enable_buzzer'] == true,
      enableNotification: json['enable_notification'] == true,
      imageUrl: json['image_url']?.toString(),
      formFactor: json['form_factor']?.toString(),
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'])
          : DateTime.now(),
      endDate:
          json['end_date'] != null ? DateTime.parse(json['end_date']) : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'dosage': dosage,
      'instructions': instructions,
      'frequency': frequency,
      'time_slots': timeSlots,
      'drawer_number': drawerNumber,
      'is_active': isActive,
      'enable_led': enableLed,
      'enable_buzzer': enableBuzzer,
      'enable_notification': enableNotification,
      'image_url': imageUrl,
      'form_factor': formFactor,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool hasDrawer() => drawerNumber != null;
}
