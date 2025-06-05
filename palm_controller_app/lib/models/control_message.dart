import 'package:json_annotation/json_annotation.dart';

part 'control_message.g.dart';

@JsonSerializable()
class ControlMessage {
  final String messageId;
  final String type;
  final DateTime timestamp;
  final Map<String, dynamic> payload;

  const ControlMessage({
    required this.messageId,
    required this.type,
    required this.timestamp,
    required this.payload,
  });

  factory ControlMessage.fromJson(Map<String, dynamic> json) =>
      _$ControlMessageFromJson(json);

  Map<String, dynamic> toJson() => _$ControlMessageToJson(this);

  // 鼠标控制消息
  factory ControlMessage.mouseControl({
    required String messageId,
    required String action, // move|click|scroll
    double deltaX = 0,
    double deltaY = 0,
    String button = 'left', // left|right|middle
    int clicks = 1,
  }) {
    return ControlMessage(
      messageId: messageId,
      type: 'mouse_control',
      timestamp: DateTime.now(),
      payload: {
        'action': action,
        'deltaX': deltaX,
        'deltaY': deltaY,
        'button': button,
        'clicks': clicks,
      },
    );
  }

  // 键盘控制消息
  factory ControlMessage.keyboardControl({
    required String messageId,
    required String action, // key_press|key_release|text_input
    String? keyCode,
    String? text,
    List<String> modifiers = const [],
  }) {
    return ControlMessage(
      messageId: messageId,
      type: 'keyboard_control',
      timestamp: DateTime.now(),
      payload: {
        'action': action,
        if (keyCode != null) 'keyCode': keyCode,
        if (text != null) 'text': text,
        'modifiers': modifiers,
      },
    );
  }

  // 媒体控制消息
  factory ControlMessage.mediaControl({
    required String messageId,
    required String action, // play_pause|next|previous|volume_up|volume_down|mute|get_volume_status
  }) {
    return ControlMessage(
      messageId: messageId,
      type: 'media_control',
      timestamp: DateTime.now(),
      payload: {
        'action': action,
      },
    );
  }

  // 音量状态消息（从服务端接收�?
  factory ControlMessage.volumeStatus({
    required String messageId,
    required double volume,
    required bool muted,
  }) {
    return ControlMessage(
      messageId: messageId,
      type: 'volume_status',
      timestamp: DateTime.now(),
      payload: {
        'volume': volume,
        'muted': muted,
      },
    );
  }

  // 系统控制消息
  factory ControlMessage.systemControl({
    required String messageId,
    required String action, // shutdown|restart|sleep|lock|ppt_next|ppt_previous
  }) {
    return ControlMessage(
      messageId: messageId,
      type: 'system_control',
      timestamp: DateTime.now(),
      payload: {
        'action': action,
      },
    );
  }

  // 连接认证消息
  factory ControlMessage.authentication({
    required String messageId,
    String? password,
  }) {
    return ControlMessage(
      messageId: messageId,
      type: 'auth',
      timestamp: DateTime.now(),
      payload: {
        if (password != null) 'password': password,
      },
    );
  }

  // 心跳消息
  factory ControlMessage.heartbeat({
    required String messageId,
  }) {
    return ControlMessage(
      messageId: messageId,
      type: 'heartbeat',
      timestamp: DateTime.now(),
      payload: {},
    );
  }

  @override
  String toString() {
    return 'ControlMessage(messageId: $messageId, type: $type, timestamp: $timestamp)';
  }
} 
