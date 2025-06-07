import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
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
  
  // JSON消息缓冲区 - 处理TCP拆分传输
  final StringBuffer _messageBuffer = StringBuffer();

  // 连接到PC端
  Future<bool> connect(ConnectionConfig config) async {
    if (_currentStatus == ConnectionStatus.connecting) {
      LogService.instance.warning('已在连接中，跳过重复连接请求', category: 'Socket');
      return false;
    }

    if (_currentStatus == ConnectionStatus.connected) {
      LogService.instance.info('已连接，先断开现有连接', category: 'Socket');
      await disconnect();
    }

    final stopwatch = Stopwatch()..start();
    _updateStatus(ConnectionStatus.connecting);

    try {
      LogService.instance.socketConnection(
        action: 'connect', 
        host: config.ipAddress, 
        port: config.port
      );

      // 优化：增加连接超时时间，并使用分级超时策略
      const primaryTimeout = Duration(seconds: 15); // 主要超时
      const fallbackTimeout = Duration(seconds: 8);  // 备用快速超时
      
      Socket? socket;
      
      try {
        // 第一次尝试：使用较长超时适应慢速网络
        socket = await Socket.connect(
          config.ipAddress,
          config.port,
          timeout: primaryTimeout,
        );
      } on SocketException catch (e) {
        // 分析异常类型决定是否快速重试
        if (_isRetryableSocketError(e)) {
          LogService.instance.warning('首次连接失败，尝试快速重试: ${e.message}', category: 'Socket');
          
          // 等待短暂时间后快速重试
          await Future.delayed(const Duration(milliseconds: 500));
          
          socket = await Socket.connect(
            config.ipAddress,
            config.port,
            timeout: fallbackTimeout,
          );
        } else {
          // 不可重试的错误直接抛出
          rethrow;
        }
      }
      
      _socket = socket;

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
          'timeout_used': _socket!.port == config.port ? 'primary' : 'fallback',
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
    } on SocketException catch (e) {
      stopwatch.stop();
      _lastError = _categorizeSocketError(e);
      _updateStatus(ConnectionStatus.error);
      
      LogService.instance.socketConnection(
        action: 'connect',
        host: config.ipAddress,
        port: config.port,
        error: _lastError,
      );
      
      return false;
    } on TimeoutException catch (e) {
      stopwatch.stop();
      _lastError = '连接超时：请检查网络状况和目标设备状态';
      _updateStatus(ConnectionStatus.error);
      
      LogService.instance.socketConnection(
        action: 'connect',
        host: config.ipAddress,
        port: config.port,
        error: 'TimeoutException: ${e.message}',
      );
      
      return false;
    } catch (e) {
      stopwatch.stop();
      _lastError = '连接异常：$e';
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
      _lastError = 'Socket not connected';
      return false;
    }

    try {
      final jsonString = jsonEncode(message.toJson());
      final data = utf8.encode('$jsonString\n');
      
      // 优化发送日志：简化频繁操作的日志输出
      if (message.type == 'heartbeat') {
        // 心跳消息使用debug级别，减少日志噪音
        LogService.instance.debug('发送心跳消息', category: 'Socket');
      } else if (message.type == 'preview_image') {
        print('📤 发送图片预览请求: ${message.payload?['path'] ?? 'unknown'}');
      } else {
        print('📤 发送消息: ${message.type}');
      }
      
      LogService.instance.socketConnection(
        action: 'send',
        host: _socket!.remoteAddress.address,
        port: _socket!.remotePort,
        messageType: message.type,
        dataSize: data.length,
      );
      
      // 直接尝试写入，如果失败立即捕获
      try {
        _socket!.add(data);
        await _socket!.flush();
        
        // 优化成功日志：只有重要操作才显示成功消息
        if (message.type != 'heartbeat') {
          if (message.type == 'preview_image') {
            print('✅ 图片预览请求发送成功');
          } else {
            print('✅ 消息发送成功: ${message.type}');
          }
        }
      } catch (writeError) {
        // 写入失败，立即标记连接错误
        print('❌ 写入数据失败: $writeError');
        _updateStatus(ConnectionStatus.error);
        throw writeError; // 重新抛出让外层catch处理
      }
      
      if (_currentStatus == ConnectionStatus.error) {
        LogService.instance.info('消息发送成功，连接状态已恢复', category: 'Socket');
        _updateStatus(ConnectionStatus.connected);
      }
      
      return true;
    } catch (e) {
      _lastError = e.toString();
      print('❌ 发送消息异常: $e');
      
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

  // 数据接收处理 - 支持TCP拆分传输的JSON消息重组
  void _onDataReceived(List<int> data) {
    try {
      final newData = utf8.decode(data);
      
      // 将新接收的数据添加到缓冲区
      _messageBuffer.write(newData);
      
      // 尝试从缓冲区提取完整的JSON消息
      _processBufferedMessages();
      
    } catch (e) {
      _lastError = 'Failed to decode data: $e';
      print('❌ 数据解码失败: $e');
      LogService.instance.warning('数据解码异常: $e', category: 'Socket');
    }
  }
  
  // 处理缓冲区中的消息
  void _processBufferedMessages() {
    final bufferContent = _messageBuffer.toString();
    
    // 按换行符分割，寻找完整的JSON消息
    final lines = bufferContent.split('\n');
    int processedLines = 0;
    
    for (int i = 0; i < lines.length - 1; i++) { // 最后一行可能不完整，先不处理
      final line = lines[i].trim();
      if (line.isEmpty) {
        processedLines++;
        continue;
      }
      
      // 尝试解析JSON消息
      if (_tryProcessJsonMessage(line)) {
        processedLines++;
      } else {
        // 如果当前行无法解析，可能是多行JSON的一部分
        // 尝试与后续行组合解析
        final combined = _tryRecombineJson(lines, i);
        if (combined != null) {
          if (_tryProcessJsonMessage(combined.content)) {
            processedLines += combined.lineCount;
            i += combined.lineCount - 1; // 跳过已处理的行
          } else {
            // 组合后仍无法解析，跳过当前行
            print('⚠️ 跳过无效数据: [${line.length}字符] ${line.substring(0, math.min(50, line.length))}...');
            processedLines++;
          }
        } else {
          // 无法组合，跳过当前行
                     print('⚠️ 跳过无效数据: [${line.length}字符] ${line.substring(0, math.min(50, line.length))}...');
          processedLines++;
        }
      }
    }
    
    // 移除已处理的数据，保留可能不完整的最后一行
    if (processedLines > 0) {
      final remainingLines = lines.skip(processedLines).toList();
      _messageBuffer.clear();
      if (remainingLines.isNotEmpty) {
        _messageBuffer.write(remainingLines.join('\n'));
      }
    }
  }
  
  // 尝试处理单个JSON消息
  bool _tryProcessJsonMessage(String line) {
    try {
      // 检查JSON格式
      if (!line.startsWith('{') || !line.endsWith('}')) {
        return false;
      }
      
      final json = jsonDecode(line);
      
      // 验证JSON结构
      if (json is! Map<String, dynamic> || 
          !json.containsKey('type') || 
          !json.containsKey('messageId')) {
        return false;
      }
      
      final controlMessage = ControlMessage.fromJson(json);
      
      // 根据消息类型选择性输出日志
      _logReceivedMessage(controlMessage, line.length);
      
      _messageController.add(controlMessage);
      return true;
      
    } catch (e) {
      return false;
    }
  }
  
  // 尝试重新组合被拆分的JSON
  ({String content, int lineCount})? _tryRecombineJson(List<String> lines, int startIndex) {
    // 尝试组合最多10行来形成完整JSON
         for (int endIndex = startIndex + 1; endIndex < math.min(lines.length, startIndex + 10); endIndex++) {
      final combined = lines.sublist(startIndex, endIndex + 1).join('');
      
      // 检查是否形成了完整的JSON
      if (combined.startsWith('{') && combined.endsWith('}')) {
        try {
          jsonDecode(combined); // 验证JSON有效性
          return (content: combined, lineCount: endIndex - startIndex + 1);
        } catch (e) {
          continue; // JSON无效，继续尝试
        }
      }
    }
    
    return null;
  }
  
  // 智能日志输出
  void _logReceivedMessage(ControlMessage message, int dataSize) {
    switch (message.type) {
      case 'heartbeat':
        // 心跳消息静默处理
        break;
      case 'image_preview_response':
        print('🖼️ 图片预览响应: [${dataSize}字符]');
        break;
      case 'file_list_response':
        final fileCount = message.payload['files']?.length ?? 0;
        print('📁 文件列表响应: ${fileCount}个项目 [${dataSize}字符]');
        break;
      default:
        if (dataSize <= 200) {
          print('📨 收到消息: ${message.type}');
        } else {
          print('📨 收到消息: ${message.type} [${dataSize}字符]');
        }
        break;
    }
  }

  /// 检测是否是图片数据传输
  bool _isLikelyImageData(String message) {
    // 判断条件：
    // 1. 数据长度大于10KB，通常是大数据传输
    // 2. 包含Base64特征字符且比例较高
    // 3. 非JSON格式行占主导地位
    
    if (message.length < 10000) return false;
    
    final lines = message.split('\n');
    int nonJsonLines = 0;
    int base64LikeLines = 0;
    
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) {
        // 检查是否是JSON格式
        if (!trimmed.startsWith('{') || !trimmed.endsWith('}')) {
          nonJsonLines++;
          
          // 检查是否像Base64编码（主要由字母数字和少量特殊字符组成）
          if (trimmed.length > 50 && _isBase64Like(trimmed)) {
            base64LikeLines++;
          }
        }
      }
    }
    
    // 如果非JSON行数占80%以上，且大部分像Base64，认为是图片数据
    final totalLines = lines.where((l) => l.trim().isNotEmpty).length;
    return totalLines > 0 && 
           (nonJsonLines / totalLines) > 0.8 && 
           (base64LikeLines / nonJsonLines) > 0.6;
  }

  /// 检测字符串是否像Base64编码
  bool _isBase64Like(String text) {
    if (text.isEmpty) return false;
    
    // Base64字符集：A-Z, a-z, 0-9, +, /, =
    final base64Pattern = RegExp(r'^[A-Za-z0-9+/=]+$');
    return base64Pattern.hasMatch(text);
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

  // 判断是否为可重试的Socket错误
  bool _isRetryableSocketError(SocketException e) {
    final message = e.message.toLowerCase();
    
    // 可重试的错误类型
    return message.contains('network is unreachable') ||
           message.contains('connection refused') ||
           message.contains('host is down') ||
           message.contains('timeout') ||
           message.contains('no route to host');
  }

  // 分类Socket错误，提供用户友好的错误信息
  String _categorizeSocketError(SocketException e) {
    final message = e.message.toLowerCase();
    
    if (message.contains('network is unreachable') || message.contains('no route to host')) {
      return '网络不可达：请检查设备是否在同一网络中';
    } else if (message.contains('connection refused')) {
      return '连接被拒绝：请确保PC端服务正在运行';
    } else if (message.contains('host is down')) {
      return '目标设备离线：请检查PC端设备状态';
    } else if (message.contains('timeout')) {
      return '连接超时：网络较慢或设备响应延迟';
    } else if (message.contains('permission denied')) {
      return '权限被拒绝：请检查防火墙设置';
    } else {
      return '连接失败：${e.message}';
    }
  }
} 
