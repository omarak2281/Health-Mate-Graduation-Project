/// Medical Contact Model
/// Represents a health professional or emergency contact
class MedicalContact {
  final String id;
  final String userId;
  final String name;
  final String phone;
  final String type; // doctor, pharmacy, emergency, clinic, family
  final DateTime createdAt;

  MedicalContact({
    required this.id,
    required this.userId,
    required this.name,
    required this.phone,
    required this.type,
    required this.createdAt,
  });

  factory MedicalContact.fromJson(Map<String, dynamic> json) {
    return MedicalContact(
      id: json['id'],
      userId: json['user_id'],
      name: json['name'],
      phone: json['phone'],
      type: json['type'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'phone': phone,
      'type': type,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
