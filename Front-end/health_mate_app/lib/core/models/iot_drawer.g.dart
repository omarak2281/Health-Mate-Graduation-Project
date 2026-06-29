// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'iot_drawer.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IoTDrawer _$IoTDrawerFromJson(Map<String, dynamic> json) => IoTDrawer(
      drawerNumber: (json['drawer_number'] as num).toInt(),
      isActive: json['is_active'] as bool? ?? false,
      medicationId: json['medication_id'] as String?,
    );

Map<String, dynamic> _$IoTDrawerToJson(IoTDrawer instance) => <String, dynamic>{
      'drawer_number': instance.drawerNumber,
      'is_active': instance.isActive,
      'medication_id': instance.medicationId,
    };
