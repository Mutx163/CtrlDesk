// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'control_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ControlMessage _$ControlMessageFromJson(Map<String, dynamic> json) =>
    ControlMessage(
      messageId: json['messageId'] as String,
      type: json['type'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      payload: json['payload'] as Map<String, dynamic>,
    );

Map<String, dynamic> _$ControlMessageToJson(ControlMessage instance) =>
    <String, dynamic>{
      'messageId': instance.messageId,
      'type': instance.type,
      'timestamp': instance.timestamp.toIso8601String(),
      'payload': instance.payload,
    };

