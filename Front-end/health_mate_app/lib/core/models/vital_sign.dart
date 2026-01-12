/// Vital Sign Model
/// Represents blood pressure reading

class VitalSign {
  final String id;
  final String userId;
  final int systolic;
  final int diastolic;
  final int? heartRate;
  final String riskLevel;
  final String source;
  final double? confidence;
  final double? signalQuality;
  final DateTime measuredAt;
  final DateTime createdAt;

  VitalSign({
    required this.id,
    required this.userId,
    required this.systolic,
    required this.diastolic,
    this.heartRate,
    required this.riskLevel,
    required this.source,
    this.confidence,
    this.signalQuality,
    required this.measuredAt,
    required this.createdAt,
  });

  factory VitalSign.fromJson(Map<String, dynamic> json) {
    return VitalSign(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      systolic: json['systolic'] is int
          ? json['systolic']
          : int.tryParse(json['systolic']?.toString() ?? '0') ?? 0,
      diastolic: json['diastolic'] is int
          ? json['diastolic']
          : int.tryParse(json['diastolic']?.toString() ?? '0') ?? 0,
      heartRate: json['heart_rate'] is int
          ? json['heart_rate']
          : int.tryParse(json['heart_rate']?.toString() ?? ''),
      riskLevel: json['risk_level']?.toString() ?? 'normal',
      source: json['source']?.toString() ?? 'unknown',
      confidence: json['confidence'] != null
          ? double.tryParse(json['confidence'].toString())
          : null,
      signalQuality: json['signal_quality'] != null
          ? double.tryParse(json['signal_quality'].toString())
          : null,
      measuredAt: json['measured_at'] != null
          ? DateTime.parse(json['measured_at'])
          : DateTime.now(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'systolic': systolic,
      'diastolic': diastolic,
      'heart_rate': heartRate,
      'risk_level': riskLevel,
      'source': source,
      'confidence': confidence,
      'signal_quality': signalQuality,
      'measured_at': measuredAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  String get bpString => '$systolic/$diastolic';

  bool get isNormal => riskLevel == 'normal';
  bool get isLow => riskLevel == 'low';
  bool get isModerate => riskLevel == 'moderate';
  bool get isHigh => riskLevel == 'high';
  bool get isCritical => riskLevel == 'critical';
  bool get isEmergency => isHigh || isCritical;
}
