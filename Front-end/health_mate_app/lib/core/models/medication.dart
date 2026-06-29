/// Medication Model

class Medication {
  final String id;
  final String userId;
  final String name;
  final String
      dosage; // Refactored from dose (which was refactored from dosage)
  final String? instructions;
  final int timesPerDay; // Refactored from frequency
  final List<String> scheduledTimes; // Refactored from timeSlots (HH:MM)
  final bool useSmartBox; // New field
  final int? drawerNumber;
  final bool isActive;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  Medication({
    required this.id,
    required this.userId,
    required this.name,
    required this.dosage,
    this.instructions,
    required this.timesPerDay,
    required this.scheduledTimes,
    required this.useSmartBox,
    this.drawerNumber,
    required this.isActive,
    this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Medication.fromJson(Map<String, dynamic> json) {
    return Medication(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      dosage: json['dosage']?.toString() ?? json['dose']?.toString() ?? '',
      instructions: json['instructions']?.toString(),
      timesPerDay: json['times_per_day'] is int
          ? json['times_per_day']
          : int.tryParse(json['times_per_day']?.toString() ?? '') ?? 1,
      scheduledTimes: json['scheduled_times'] != null
          ? List<String>.from(
              (json['scheduled_times'] as Iterable).map((e) => e.toString()))
          : [],
      useSmartBox: json['use_smart_box'] == true,
      drawerNumber: json['drawer_number'] is int
          ? json['drawer_number']
          : int.tryParse(json['drawer_number']?.toString() ?? ''),
      isActive: json['is_active'] != false, // default true if absent
      imageUrl: json['image_url']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
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
      'times_per_day': timesPerDay,
      'scheduled_times': scheduledTimes,
      'use_smart_box': useSmartBox,
      'drawer_number': drawerNumber,
      'is_active': isActive,
      'image_url': imageUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool hasDrawer() => drawerNumber != null;
}
