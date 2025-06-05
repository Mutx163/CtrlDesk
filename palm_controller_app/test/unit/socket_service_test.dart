import 'package:flutter_test/flutter_test.dart';
import 'package:palm_controller_app/models/connection_config.dart';
import 'package:palm_controller_app/models/control_message.dart';
import 'package:palm_controller_app/services/socket_service.dart';

void main() {
  group('SocketService单元测试', () {
    late SocketService socketService;

    setUp(() {
      socketService = SocketService();
    });

    tearDown(() async {
      try {
        await socketService.dispose();
      } catch (e) {
        // 忽略dispose时的异常，这在测试中是正常的
        // 测试清理时的异常（可忽略）: $e
      }
    });

    test('创建SocketService实例', () {
      expect(socketService, isNotNull);
      expect(socketService.currentStatus, equals(ConnectionStatus.disconnected));
    });

    test('创建有效的连接配置', () {
      final config = ConnectionConfig(
        id: 'test-config',
        name: '测试服务器',
        ipAddress: '192.168.1.100',
        port: 8080,
        lastConnected: DateTime.now(),
        autoConnect: false,
      );

      expect(config.id, equals('test-config'));
      expect(config.name, equals('测试服务器'));
      expect(config.ipAddress, equals('192.168.1.100'));
      expect(config.port, equals(8080));
      expect(config.autoConnect, isFalse);
    });

    test('创建控制消息', () {
      final mouseMessage = ControlMessage.mouseControl(
        messageId: 'test-mouse',
        action: 'click',
        deltaX: 10,
        deltaY: 20,
      );

      expect(mouseMessage.type, equals('mouse_control'));
      expect(mouseMessage.messageId, equals('test-mouse'));
      expect(mouseMessage.payload['action'], equals('click'));
      expect(mouseMessage.payload['deltaX'], equals(10));
      expect(mouseMessage.payload['deltaY'], equals(20));
    });

    test('创建键盘控制消息', () {
      final keyboardMessage = ControlMessage.keyboardControl(
        messageId: 'test-keyboard',
        action: 'text_input',
        text: 'Hello World',
      );

      expect(keyboardMessage.type, equals('keyboard_control'));
      expect(keyboardMessage.messageId, equals('test-keyboard'));
      expect(keyboardMessage.payload['action'], equals('text_input'));
      expect(keyboardMessage.payload['text'], equals('Hello World'));
    });

    test('创建媒体控制消息', () {
      final mediaMessage = ControlMessage.mediaControl(
        messageId: 'test-media',
        action: 'play_pause',
      );

      expect(mediaMessage.type, equals('media_control'));
      expect(mediaMessage.messageId, equals('test-media'));
      expect(mediaMessage.payload['action'], equals('play_pause'));
    });

    test('创建系统控制消息', () {
      final systemMessage = ControlMessage.systemControl(
        messageId: 'test-system',
        action: 'shutdown',
      );

      expect(systemMessage.type, equals('system_control'));
      expect(systemMessage.messageId, equals('test-system'));
      expect(systemMessage.payload['action'], equals('shutdown'));
    });

    test('消息JSON序列化和反序列化', () {
      final originalMessage = ControlMessage.heartbeat(
        messageId: 'test-heartbeat',
      );

      final json = originalMessage.toJson();
      final deserializedMessage = ControlMessage.fromJson(json);

      expect(deserializedMessage.type, equals(originalMessage.type));
      expect(deserializedMessage.messageId, equals(originalMessage.messageId));
      expect(deserializedMessage.timestamp, equals(originalMessage.timestamp));
    });
  });
} 