/// Vital Sign Model
/// Represents blood pressure reading

class VitalSign {
  final String id;
  final String userId;
  final int? systolic;
  final int? diastolic;
  final int? heartRate;
  final int? spo2;
  final String riskLevel;
  final String source;
  final double? confidence;
  final double? signalQuality;
  final String? measurementStatus;
  final String? rejectionReason;
  final double? modelSystolic;
  final double? modelDiastolic;
  final double? calibratedSystolic;
  final double? calibratedDiastolic;
  final String? calibrationStatus;
  final String? deviceId;
  final DateTime measuredAt;
  final DateTime createdAt;

  VitalSign({
    required this.id,
    required this.userId,
    this.systolic,
    this.diastolic,
    this.heartRate,
    this.spo2,
    required this.riskLevel,
    required this.source,
    this.confidence,
    this.signalQuality,
    this.measurementStatus,
    this.rejectionReason,
    this.modelSystolic,
    this.modelDiastolic,
    this.calibratedSystolic,
    this.calibratedDiastolic,
    this.calibrationStatus,
    this.deviceId,
    required this.measuredAt,
    required this.createdAt,
  });

  static DateTime _parseUtcDateTime(String? dateStr) {
    if (dateStr == null) return DateTime.now();
    final normalised = dateStr.endsWith('Z') || dateStr.contains('+')
        ? dateStr
        : '${dateStr}Z';
    return DateTime.parse(normalised).toLocal();
  }

  factory VitalSign.fromJson(Map<String, dynamic> json) {
    return VitalSign(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      systolic: json['systolic'] != null
          ? (json['systolic'] is int
              ? json['systolic']
              : int.tryParse(json['systolic'].toString()))
          : null,
      diastolic: json['diastolic'] != null
          ? (json['diastolic'] is int
              ? json['diastolic']
              : int.tryParse(json['diastolic'].toString()))
          : null,
      heartRate: json['heart_rate'] is int
          ? json['heart_rate']
          : int.tryParse(json['heart_rate']?.toString() ?? ''),
      spo2: json['spo2'] is int
          ? json['spo2']
          : int.tryParse(json['spo2']?.toString() ?? ''),
      riskLevel: json['risk_level']?.toString() ?? 'normal',
      source: json['source']?.toString() ?? 'unknown',
      confidence: json['confidence'] != null
          ? double.tryParse(json['confidence'].toString())
          : null,
      signalQuality: json['signal_quality'] != null
          ? double.tryParse(json['signal_quality'].toString())
          : null,
      measurementStatus: json['measurement_status']?.toString(),
      rejectionReason: json['rejection_reason']?.toString(),
      modelSystolic: json['model_systolic'] != null
          ? double.tryParse(json['model_systolic'].toString())
          : null,
      modelDiastolic: json['model_diastolic'] != null
          ? double.tryParse(json['model_diastolic'].toString())
          : null,
      calibratedSystolic: json['calibrated_systolic'] != null
          ? double.tryParse(json['calibrated_systolic'].toString())
          : null,
      calibratedDiastolic: json['calibrated_diastolic'] != null
          ? double.tryParse(json['calibrated_diastolic'].toString())
          : null,
      calibrationStatus: json['calibration_status']?.toString(),
      deviceId: json['device_id']?.toString(),
      measuredAt: json['measured_at'] != null
          ? _parseUtcDateTime(json['measured_at'].toString())
          : DateTime.now(),
      createdAt: json['created_at'] != null
          ? _parseUtcDateTime(json['created_at'].toString())
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
      'spo2': spo2,
      'risk_level': riskLevel,
      'source': source,
      'confidence': confidence,
      'signal_quality': signalQuality,
      'measurement_status': measurementStatus,
      'rejection_reason': rejectionReason,
      'model_systolic': modelSystolic,
      'model_diastolic': modelDiastolic,
      'calibrated_systolic': calibratedSystolic,
      'calibrated_diastolic': calibratedDiastolic,
      'calibration_status': calibrationStatus,
      'device_id': deviceId,
      'measured_at': measuredAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  String get bpString => (systolic != null && diastolic != null)
      ? '$systolic/$diastolic'
      : 'Waiting...';

  bool get isPending => measurementStatus == 'completed_pending_bp';
  bool get isRejected => measurementStatus == 'rejected';

  String? get effectiveCalibrationStatus {
    if (calibrationStatus == 'not_calibrated' &&
        !isPending &&
        systolic != null &&
        diastolic != null &&
        modelSystolic != null &&
        modelDiastolic != null) {
      return 'cold_start';
    }
    return calibrationStatus;
  }

  /// Best available systolic/diastolic for display: the cuff-confirmed value
  /// when present, otherwise the calibrated model estimate.
  int? get displaySystolic => systolic ?? calibratedSystolic?.round();
  int? get displayDiastolic => diastolic ?? calibratedDiastolic?.round();

  /// Whether the displayed BP is a calibrated estimate rather than a
  /// cuff-confirmed measurement.
  bool get isEstimatedBP => systolic == null && calibratedSystolic != null;

  bool get hasGoodSignal => (signalQuality ?? 0) >= 0.8;

  bool get isNormal => riskLevel == 'normal';
  bool get isLow => riskLevel == 'low';
  bool get isModerate => riskLevel == 'moderate';
  bool get isHigh => riskLevel == 'high';
  bool get isCritical => riskLevel == 'critical';
  bool get isEmergency => isHigh || isCritical;

  /// Heart-rate risk tier for adult resting HR (bpm). Mirrors the
  /// low/high boundaries already defined but unused in the backend's
  /// bp_rules.py (HR_LOW=50, HR_HIGH=100); critical tiers added on top
  /// since that file only covered a "moderate" band.
  String? get heartRateRiskLevel {
    final hr = heartRate;
    if (hr == null) return null;
    if (hr < 40 || hr > 150) return 'critical';
    if (hr < 50 || hr > 120) return 'high';
    if (hr < 60 || hr > 100) return 'moderate';
    return 'normal';
  }

  bool get isHeartRateNormal => heartRateRiskLevel == 'normal';
  bool get isHeartRateModerate => heartRateRiskLevel == 'moderate';
  bool get isHeartRateHigh => heartRateRiskLevel == 'high';
  bool get isHeartRateCritical => heartRateRiskLevel == 'critical';

  /// SpO2 risk tier using standard clinical thresholds: >=95% normal,
  /// 90-94% mild hypoxemia, <90% severe hypoxemia (medical emergency).
  String? get spo2RiskLevel {
    final o2 = spo2;
    if (o2 == null) return null;
    if (o2 < 90) return 'critical';
    if (o2 < 95) return 'moderate';
    return 'normal';
  }

  bool get isSpo2Normal => spo2RiskLevel == 'normal';
  bool get isSpo2Moderate => spo2RiskLevel == 'moderate';
  bool get isSpo2Critical => spo2RiskLevel == 'critical';
}
