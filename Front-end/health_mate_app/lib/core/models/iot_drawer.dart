import 'package:json_annotation/json_annotation.dart';

part 'iot_drawer.g.dart';

@JsonSerializable()
class IoTDrawer {
  @JsonKey(name: 'drawer_number')
  final int drawerNumber;

  @JsonKey(name: 'is_active')
  final bool isActive;

  @JsonKey(name: 'medication_id')
  final String? medicationId;

  const IoTDrawer({
    required this.drawerNumber,
    this.isActive = false,
    this.medicationId,
  });

  factory IoTDrawer.fromJson(Map<String, dynamic> json) =>
      _$IoTDrawerFromJson(json);

  Map<String, dynamic> toJson() => _$IoTDrawerToJson(this);

  IoTDrawer copyWith({
    int? drawerNumber,
    bool? isActive,
    String? medicationId,
  }) {
    return IoTDrawer(
      drawerNumber: drawerNumber ?? this.drawerNumber,
      isActive: isActive ?? this.isActive,
      medicationId: medicationId ?? this.medicationId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IoTDrawer &&
          runtimeType == other.runtimeType &&
          drawerNumber == other.drawerNumber &&
          isActive == other.isActive &&
          medicationId == other.medicationId;

  @override
  int get hashCode =>
      drawerNumber.hashCode ^ isActive.hashCode ^ medicationId.hashCode;
}
