/// Notification Model

class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String type; // emergency_alert, medication_reminder, etc.
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    this.data = const {},
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      type: json['notification_type']?.toString() ??
          json['type']?.toString() ??
          'info',
      data: json['data'] is Map
          ? Map<String, dynamic>.from(json['data'] as Map)
          : const {},
      isRead: json['is_read'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'message': message,
      'type': type,
      'data': data,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isEmergency =>
      type == 'emergency_alert' ||
      type == 'emergency_bp_alert' ||
      type == 'EMERGENCY_BP_ALERT' ||
      type == 'symptom_assessment_alert' ||
      type == 'SYMPTOM_ASSESSMENT_ALERT';
  bool get isMedication => type == 'medication_reminder';
}
