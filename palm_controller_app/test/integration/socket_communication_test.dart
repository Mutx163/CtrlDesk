import 'package:flutter_test/flutter_test.dart';
import 'package:palm_controller_app/services/socket_service.dart';
import 'package:palm_controller_app/models/connection_config.dart';
import 'package:palm_controller_app/models/control_message.dart';
import 'dart:async';


void main() {
  group('端到端Socket通信测试', () {
    late SocketService socketService;
    
    setUpAll(() {
      socketService = SocketService();
    });

    tearDownAll(() async {
      await socketService.dispose();
    });

    test('测试本地连接建立', () async {
      // 获取测试IP地址（环境变量或默认localhost）
      final testIp = const String.fromEnvironment('TEST_SERVER_IP', defaultValue: '127.0.0.1');
      final testPort = const int.fromEnvironment('TEST_SERVER_PORT', defaultValue: 8080);
      
      // 创建连接配置 - 连接到测试服务器
      final config = ConnectionConfig(
        id: 'test-connection',
        name: '测试服务器',
        ipAddress: testIp, // 使用环境变量或localhost
        port: testPort, // 使用环境变量或默认端口
        lastConnected: DateTime.now(),
        autoConnect: false,
      );
      
      // 检查是否应该跳过集成测试
      final skipIntegrationTests = const bool.fromEnvironment('SKIP_INTEGRATION_TESTS', defaultValue: false);
      if (skipIntegrationTests) {
        // print('⏭️ 跳过集成测试（SKIP_INTEGRATION_TESTS=true）'); // 移除生产环境print
        return;
      }

      // print('正在尝试连接到 ${config.ipAddress}:${config.port}...'); // 移除生产环境print

      // 监听连接状态
      final statusCompleter = Completer<ConnectionStatus>();
      late StreamSubscription statusSubscription;
      
      statusSubscription = socketService.statusStream.listen((status) {
        // print('连接状态变化: $status'); // 移除生产环境print
        if (status == ConnectionStatus.connected || 
            status == ConnectionStatus.error) {
          if (!statusCompleter.isCompleted) {
            statusCompleter.complete(status);
          }
        }
      });

      try {
        // 尝试连接
        final connectResult = await socketService.connect(config);
        // print('连接方法返回结果: $connectResult'); // 移除生产环境print

        // 等待状态更新
        final finalStatus = await statusCompleter.future.timeout(
          const Duration(seconds: 15),
          onTimeout: () => ConnectionStatus.error,
        );

        await statusSubscription.cancel();

        if (finalStatus == ConnectionStatus.connected) {
          // print('✅ 连接成功建立'); // 移除生产环境print
          expect(socketService.currentStatus, equals(ConnectionStatus.connected));
        } else {
          // print('❌ 连接失败'); // 移除生产环境print
          // print('错误信息: ${socketService.lastError}'); // 移除生产环境print
          fail('连接建立失败: ${socketService.lastError}');
        }
      } catch (e) {
        await statusSubscription.cancel();
        // print('❌ 连接过程中发生异常: $e'); // 移除生产环境print
        fail('连接异常: $e');
      }
    });

    test('测试消息发送和接收', () async {
      // 确保已连接
      if (socketService.currentStatus != ConnectionStatus.connected) {
        fail('测试前置条件失败：Socket未连接');
      }

      // print('开始测试消息发送...'); // 移除生产环境print

      // 监听收到的消息
      final messageCompleter = Completer<ControlMessage>();
      late StreamSubscription messageSubscription;
      
      messageSubscription = socketService.messageStream.listen((message) {
        // print('收到消息: ${message.type} - ${message.messageId}'); // 移除生产环境print
        if (message.type == 'response' && !messageCompleter.isCompleted) {
          messageCompleter.complete(message);
        }
      });

      try {
        // 发送心跳消息
        final heartbeatResult = await socketService.sendMessage(
          ControlMessage.heartbeat(messageId: 'test-heartbeat-001')
        );
        
        // print('心跳消息发送结果: $heartbeatResult'); // 移除生产环境print
        expect(heartbeatResult, isTrue);

        // 等待服务端响应
        final response = await messageCompleter.future.timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw TimeoutException('等待响应超时', const Duration(seconds: 10)),
        );

        await messageSubscription.cancel();

        // print('✅ 收到服务端响应: ${response.payload}'); // 移除生产环境print
        expect(response.type, equals('response'));
        
      } catch (e) {
        await messageSubscription.cancel();
        // print('❌ 消息测试失败: $e'); // 移除生产环境print
        fail('消息发送/接收测试失败: $e');
      }
    });

    test('测试鼠标控制指令', () async {
      if (socketService.currentStatus != ConnectionStatus.connected) {
        fail('测试前置条件失败：Socket未连接');
      }

      // print('开始测试鼠标控制指令...'); // 移除生产环境print

      try {
        // 发送鼠标移动指令
        final mouseMoveResult = await socketService.sendMouseControl(
          action: 'move',
          deltaX: 10,
          deltaY: 10,
        );
        
        expect(mouseMoveResult, isTrue);
        // print('✅ 鼠标移动指令发送成功'); // 移除生产环境print

        // 发送鼠标点击指令
        final mouseClickResult = await socketService.sendMouseControl(
          action: 'click',
          button: 'left',
          clicks: 1,
        );
        
        expect(mouseClickResult, isTrue);
        // print('✅ 鼠标点击指令发送成功'); // 移除生产环境print

      } catch (e) {
        // print('❌ 鼠标控制测试失败: $e'); // 移除生产环境print
        fail('鼠标控制测试失败: $e');
      }
    });

    test('测试键盘控制指令', () async {
      if (socketService.currentStatus != ConnectionStatus.connected) {
        fail('测试前置条件失败：Socket未连接');
      }

      // print('开始测试键盘控制指令...'); // 移除生产环境print

      try {
        // 发送文本输入指令
        final textInputResult = await socketService.sendKeyboardControl(
          action: 'text_input',
          text: 'Hello PalmController!',
        );
        
        expect(textInputResult, isTrue);
        // print('✅ 文本输入指令发送成功'); // 移除生产环境print

        // 发送按键指令
        final keyPressResult = await socketService.sendKeyboardControl(
          action: 'key_press',
          keyCode: 'VK_ENTER',
        );
        
        expect(keyPressResult, isTrue);
        // print('✅ 按键指令发送成功'); // 移除生产环境print

      } catch (e) {
        // print('❌ 键盘控制测试失败: $e'); // 移除生产环境print
        fail('键盘控制测试失败: $e');
      }
    });

    test('测试媒体控制指令', () async {
      if (socketService.currentStatus != ConnectionStatus.connected) {
        fail('测试前置条件失败：Socket未连接');
      }

      // print('开始测试媒体控制指令...'); // 移除生产环境print

      try {
        // 发送播放/暂停指令
        final playPauseResult = await socketService.sendMediaControl('play_pause');
        expect(playPauseResult, isTrue);
        // print('✅ 播放/暂停指令发送成功'); // 移除生产环境print

        // 发送音量控制指令
        final volumeUpResult = await socketService.sendMediaControl('volume_up');
        expect(volumeUpResult, isTrue);
        // print('✅ 音量增加指令发送成功'); // 移除生产环境print

      } catch (e) {
        // print('❌ 媒体控制测试失败: $e'); // 移除生产环境print
        fail('媒体控制测试失败: $e');
      }
    });

    test('测试系统控制指令', () async {
      if (socketService.currentStatus != ConnectionStatus.connected) {
        fail('测试前置条件失败：Socket未连接');
      }

      // print('开始测试系统控制指令...'); // 移除生产环境print

      try {
        // 发送锁屏指令（相对安全的系统指令）
        final lockResult = await socketService.sendSystemControl('lock');
        expect(lockResult, isTrue);
        // print('✅ 锁屏指令发送成功'); // 移除生产环境print

        // 注意：不测试关机/重启等危险指令

      } catch (e) {
        // print('❌ 系统控制测试失败: $e'); // 移除生产环境print
        fail('系统控制测试失败: $e');
      }
    });

    test('测试断开连接', () async {
      if (socketService.currentStatus != ConnectionStatus.connected) {
        fail('测试前置条件失败：Socket未连接');
      }

      // print('开始测试连接断开...'); // 移除生产环境print

      // 监听断开状态
      final statusCompleter = Completer<ConnectionStatus>();
      late StreamSubscription statusSubscription;
      
      statusSubscription = socketService.statusStream.listen((status) {
        // print('断开过程中状态变化: $status'); // 移除生产环境print
        if (status == ConnectionStatus.disconnected && !statusCompleter.isCompleted) {
          statusCompleter.complete(status);
        }
      });

      try {
        await socketService.disconnect();

        final finalStatus = await statusCompleter.future.timeout(
          const Duration(seconds: 5),
          onTimeout: () => ConnectionStatus.error,
        );

        await statusSubscription.cancel();

        expect(finalStatus, equals(ConnectionStatus.disconnected));
        expect(socketService.currentStatus, equals(ConnectionStatus.disconnected));
        
        // print('✅ 连接断开成功'); // 移除生产环境print

      } catch (e) {
        await statusSubscription.cancel();
        // print('❌ 断开连接测试失败: $e'); // 移除生产环境print
        fail('断开连接测试失败: $e');
      }
    });
  });
} 
