/// User Model
/// Represents authenticated user (Patient or Caregiver)

class User {
  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final String role; // 'patient' or 'caregiver'
  final String? profileImage;
  final String? birthDate;
  final String? gender;
  final bool isActive;
  final bool isVerified;
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    required this.role,
    this.profileImage,
    this.birthDate,
    this.gender,
    required this.isActive,
    required this.isVerified,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      phone: json['phone']?.toString(),
      role: json['role']?.toString() ?? 'patient',
      profileImage: json['profile_image_url']?.toString(),
      birthDate: json['birth_date']?.toString(),
      gender: json['gender']?.toString(),
      isActive: json['is_active'] == true,
      isVerified: json['is_verified'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'phone': phone,
      'role': role,
      'profile_image_url': profileImage,
      'birth_date': birthDate,
      'gender': gender,
      'is_active': isActive,
      'is_verified': isVerified,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isPatient => role == 'patient';
  bool get isCaregiver => role == 'caregiver';
}
