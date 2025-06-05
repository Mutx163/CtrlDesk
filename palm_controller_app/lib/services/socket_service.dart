import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:uuid/uuid.dart';
import '../models/control_message.dart';
import '../models/connection_config.dart';
import 'log_service.dart';

enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  error,
}

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal() {
    // 发送初始状态
    _updateStatus(_currentStatus);
    LogService.instance.info('SocketService初始化完成，当前状态: ${_currentStatus.name}', category: 'Socket');
  }

  Socket? _socket;
  StreamSubscription? _socketSubscription;
  Timer? _heartbeatTimer;
  final Uuid _uuid = const Uuid();

  // 状态流
  final StreamController<ConnectionStatus> _statusController =
      StreamController<ConnectionStatus>.broadcast();
  Stream<ConnectionStatus> get statusStream => _statusController.stream;

  // 消息流
  final StreamController<ControlMessage> _messageController =
      StreamController<ControlMessage>.broadcast();
  Stream<ControlMessage> get messageStream => _messageController.stream;

  ConnectionStatus _currentStatus = ConnectionStatus.disconnected;
  ConnectionStatus get currentStatus => _currentStatus;

  String? _lastError;
  String? get lastError => _lastError;

  // 连接到服务器
  Future<bool> connect(ConnectionConfig config) async {
    if (_currentStatus == ConnectionStatus.connected) {
      return true;
    }

    if (_currentStatus == ConnectionStatus.connecting) {
      return false;
    }

    final stopwatch = Stopwatch()..start();

    try {
      _updateStatus(ConnectionStatus.connecting);
      _lastError = null;

      LogService.instance.socketConnection(
        action: 'connect', 
        host: config.ipAddress, 
        port: config.port
      );

      // 创建Socket连接
      _socket = await Socket.connect(
        config.ipAddress,
        config.port,
        timeout: const Duration(seconds: 10),
      );

      // 监听数据接收
      _socketSubscription = _socket!.listen(
        _onDataReceived,
        onError: _onError,
        onDone: _onDisconnected,
      );

      _updateStatus(ConnectionStatus.connected);
      
      stopwatch.stop();
      LogService.instance.performance(
        operation: 'Socket Connect',
        duration: stopwatch.elapsedMilliseconds,
        metadata: {
          'host': config.ipAddress,
          'port': config.port,
        }
      );

      // 发送认证消息
      if (config.password != null && config.password!.isNotEmpty) {
        await sendMessage(ControlMessage.authentication(
          messageId: _uuid.v4(),
          password: config.password,
        ));
      }

      // 启动心跳
      _startHeartbeat();

      return true;
    } catch (e) {
      stopwatch.stop();
      _lastError = e.toString();
      _updateStatus(ConnectionStatus.error);
      
      LogService.instance.socketConnection(
        action: 'connect',
        host: config.ipAddress,
        port: config.port,
        error: e.toString(),
      );
      
      return false;
    }
  }

  // 断开连接
  Future<void> disconnect() async {
    LogService.instance.socketConnection(
      action: 'disconnect',
      host: _socket?.remoteAddress.address ?? 'unknown',
      port: _socket?.remotePort ?? 0,
    );
    
    _stopHeartbeat();
    await _socketSubscription?.cancel();
    _socketSubscription = null;
    await _socket?.close();
    _socket = null;
    _updateStatus(ConnectionStatus.disconnected);
  }

  // 发送消息
  Future<bool> sendMessage(ControlMessage message) async {
    if (_socket == null || _currentStatus != ConnectionStatus.connected) {
      return false;
    }

    try {
      final jsonString = jsonEncode(message.toJson());
      final data = utf8.encode('$jsonString\n');
      
      LogService.instance.socketConnection(
        action: 'send',
        host: _socket!.remoteAddress.address,
        port: _socket!.remotePort,
        messageType: message.type,
        dataSize: data.length,
      );
      
      _socket!.add(data);
      await _socket!.flush();
      
      if (_currentStatus == ConnectionStatus.error) {
        LogService.instance.info('消息发送成功，连接状态已恢复', category: 'Socket');
        _updateStatus(ConnectionStatus.connected);
      }
      
      return true;
    } catch (e) {
      _lastError = e.toString();
      
      if (_socket == null || 
          e.toString().contains('Broken pipe') || 
          e.toString().contains('Connection refused') ||
          e.toString().contains('Connection reset') ||
          e.toString().contains('Socket is closed')) {
        _updateStatus(ConnectionStatus.error);
      }
      
      LogService.instance.socketConnection(
        action: 'send',
        host: _socket?.remoteAddress.address ?? 'unknown',
        port: _socket?.remotePort ?? 0,
        messageType: message.type,
        error: e.toString(),
      );
      
      return false;
    }
  }

  // 发送鼠标控制指令
  Future<bool> sendMouseControl({
    required String action,
    double deltaX = 0,
    double deltaY = 0,
    String button = 'left',
    int clicks = 1,
  }) async {
    final message = ControlMessage.mouseControl(
      messageId: _uuid.v4(),
      action: action,
      deltaX: deltaX,
      deltaY: deltaY,
      button: button,
      clicks: clicks,
    );
    return await sendMessage(message);
  }

  // 发送键盘控制指令
  Future<bool> sendKeyboardControl({
    required String action,
    String? keyCode,
    String? text,
    List<String> modifiers = const [],
  }) async {
    final message = ControlMessage.keyboardControl(
      messageId: _uuid.v4(),
      action: action,
      keyCode: keyCode,
      text: text,
      modifiers: modifiers,
    );
    return await sendMessage(message);
  }

  // 发送媒体控制指令
  Future<bool> sendMediaControl(String action) async {
    final message = ControlMessage.mediaControl(
      messageId: _uuid.v4(),
      action: action,
    );
    return await sendMessage(message);
  }

  // 发送系统控制指令
  Future<bool> sendSystemControl(String action) async {
    final message = ControlMessage.systemControl(
      messageId: _uuid.v4(),
      action: action,
    );
    return await sendMessage(message);
  }

  // 数据接收处理
  void _onDataReceived(List<int> data) {
    try {
      final message = utf8.decode(data);
      final lines = message.split('\n');
      for (final line in lines) {
        if (line.trim().isNotEmpty) {
          final json = jsonDecode(line);
          final controlMessage = ControlMessage.fromJson(json);
          _messageController.add(controlMessage);
        }
      }
    } catch (e) {
      _lastError = 'Failed to parse message: $e';
    }
  }

  // 错误处理
  void _onError(dynamic error) {
    _lastError = error.toString();
    _updateStatus(ConnectionStatus.error);
  }

  // 连接断开处理
  void _onDisconnected() {
    _updateStatus(ConnectionStatus.disconnected);
  }

  // 启动心跳
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      sendMessage(ControlMessage.heartbeat(messageId: _uuid.v4())).then((success) {
        if (!success) {
          LogService.instance.warning('心跳消息发送失败，但保持连接状态', category: 'Socket');
        }
      });
    });
  }

  // 停止心跳
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  // 更新状态
  void _updateStatus(ConnectionStatus status) {
    _currentStatus = status;
    _statusController.add(status);
  }

  // 释放资源
  Future<void> dispose() async {
    await disconnect();
    await _statusController.close();
    await _messageController.close();
  }
} 