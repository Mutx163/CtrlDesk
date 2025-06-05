// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connection_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConnectionConfig _$ConnectionConfigFromJson(Map<String, dynamic> json) =>
    ConnectionConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      ipAddress: json['ipAddress'] as String,
      port: (json['port'] as num).toInt(),
      password: json['password'] as String?,
      lastConnected: DateTime.parse(json['lastConnected'] as String),
      autoConnect: json['autoConnect'] as bool? ?? false,
    );

Map<String, dynamic> _$ConnectionConfigToJson(ConnectionConfig instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'ipAddress': instance.ipAddress,
      'port': instance.port,
      'password': instance.password,
      'lastConnected': instance.lastConnected.toIso8601String(),
      'autoConnect': instance.autoConnect,
    };
