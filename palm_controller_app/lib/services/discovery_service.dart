import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/connection_config.dart';
import 'log_service.dart';

class DiscoveredDevice {
  final String serviceName;
  final String serviceType;
  final String hostName;
  final String ipAddress;
  final int port;
  final String version;
  final DateTime discoveredAt;
  final int rssi; // 信号强度 (模拟)

  DiscoveredDevice({
    required this.serviceName,
    required this.serviceType,
    required this.hostName,
    required this.ipAddress,
    required this.port,
    required this.version,
    required this.discoveredAt,
    this.rssi = 0,
  });

  factory DiscoveredDevice.fromJson(Map<String, dynamic> json) {
    return DiscoveredDevice(
      serviceName: json['serviceName'] ?? '',
      serviceType: json['serviceType'] ?? '',
      hostName: json['hostName'] ?? '',
      ipAddress: json['ipAddress'] ?? '',
      port: json['port'] ?? 8080,
      version: json['version'] ?? '1.0.0',
      discoveredAt: DateTime.now(),
    );
  }

  // 转换为连接配置
  ConnectionConfig toConnectionConfig() {
    return ConnectionConfig(
      id: '${ipAddress}_${port}_${DateTime.now().millisecondsSinceEpoch}',
      name: '$hostName ($serviceName)',
      ipAddress: ipAddress,
      port: port,
      password: null,
      lastConnected: DateTime.now(),
      autoConnect: true,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DiscoveredDevice &&
        other.ipAddress == ipAddress &&
        other.port == port;
  }

  @override
  int get hashCode => ipAddress.hashCode ^ port.hashCode;

  @override
  String toString() {
    return 'DiscoveredDevice(serviceName: $serviceName, hostName: $hostName, ipAddress: $ipAddress:$port)';
  }
}

class DiscoveryService {
  static final DiscoveryService _instance = DiscoveryService._internal();
  factory DiscoveryService() => _instance;
  DiscoveryService._internal();

  static const int discoveryPort = 8079;
  static const Duration scanTimeout = Duration(seconds: 10);
  static const Duration discoveryInterval = Duration(seconds: 3);

  RawDatagramSocket? _socket;
  Timer? _discoveryTimer;
  Timer? _cleanupTimer;
  final Set<DiscoveredDevice> _discoveredDevices = {};
  final StreamController<List<DiscoveredDevice>> _devicesController = 
      StreamController<List<DiscoveredDevice>>.broadcast();
  
  bool _hasRequiredPermissions = false;
  bool _permissionCheckCompleted = false;

  // 发现的设备流
  Stream<List<DiscoveredDevice>> get devicesStream => _devicesController.stream;

  // 当前发现的设备列表
  List<DiscoveredDevice> get discoveredDevices => _discoveredDevices.toList();

  // 检查是否有必要的权限
  Future<bool> _checkAndRequestPermissions() async {
    if (_permissionCheckCompleted) {
      return _hasRequiredPermissions;
    }

    try {
      LogService.instance.info('开始检查UDP广播所需权限...', category: 'Discovery');
      
      // 检查位置权限 (Android 6.0+需要位置权限进行UDP广播)
      var locationStatus = await Permission.locationWhenInUse.status;
      LogService.instance.debug('位置权限状态: $locationStatus', category: 'Discovery');
      
      if (locationStatus == PermissionStatus.denied) {
        LogService.instance.info('正在请求位置权限...', category: 'Discovery');
        locationStatus = await Permission.locationWhenInUse.request();
        LogService.instance.info('位置权限请求结果: $locationStatus', category: 'Discovery');
      }

      if (locationStatus == PermissionStatus.permanentlyDenied) {
        LogService.instance.error('位置权限被永久拒绝，无法进行UDP设备发现', category: 'Discovery');
        _hasRequiredPermissions = false;
      } else if (locationStatus == PermissionStatus.granted) {
        LogService.instance.info('位置权限已授予', category: 'Discovery');
        _hasRequiredPermissions = true;
      } else {
        LogService.instance.warning('位置权限未授予: $locationStatus，将尝试不使用权限的发现方式', category: 'Discovery');
        _hasRequiredPermissions = false;
      }

      _permissionCheckCompleted = true;
      return _hasRequiredPermissions;
    } catch (e) {
      LogService.instance.error('权限检查失败: $e', category: 'Discovery');
      _hasRequiredPermissions = false;
      _permissionCheckCompleted = true;
      return false;
    }
  }

  // 开始局域网设备发现
  Future<bool> startDiscovery() async {
    try {
      // 检查权限
      final hasPermissions = await _checkAndRequestPermissions();
      if (!hasPermissions) {
        LogService.instance.warning('缺少UDP广播权限，设备发现功能受限', category: 'Discovery');
        return false;
      }

      // 创建UDP socket监听响应
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _socket!.listen(_onDataReceived);

      LogService.instance.info('设备发现服务已启动，监听端口: ${_socket!.port}', category: 'Discovery');

      // 启动定期发现
      _startPeriodicDiscovery();

      // 启动清理任务
      _startCleanupTask();

      // 立即进行一次发现
      await _sendDiscoveryRequest();

      return true;
    } catch (e) {
      LogService.instance.error('启动设备发现失败: $e', category: 'Discovery');
      return false;
    }
  }

  // 停止设备发现
  Future<void> stopDiscovery() async {
    _discoveryTimer?.cancel();
    _cleanupTimer?.cancel();
    _socket?.close();
    _socket = null;
    _discoveredDevices.clear();
    _devicesController.add([]);
    LogService.instance.info('设备发现服务已停止', category: 'Discovery');
  }

  // 手动扫描一次
  Future<List<DiscoveredDevice>> scanOnce({Duration timeout = scanTimeout}) async {
    // 如果没有权限，直接返回空列表
    if (!_hasRequiredPermissions) {
      LogService.instance.warning('缺少UDP权限，跳过设备扫描', category: 'Discovery');
      return [];
    }

    _discoveredDevices.clear();
    
    final completer = Completer<List<DiscoveredDevice>>();
    
    // 设置超时
    Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.complete(_discoveredDevices.toList());
      }
    });

    try {
      await _sendDiscoveryRequest();
      
      // 等待指定时间收集响应
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (!completer.isCompleted) {
        completer.complete(_discoveredDevices.toList());
      }
    } catch (e) {
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
    }

    return completer.future;
  }

  // 获取最佳设备（信号最强或最近发现的）
  DiscoveredDevice? getBestDevice() {
    if (_discoveredDevices.isEmpty) return null;
    
    // 按发现时间排序，返回最近发现的
    var sortedDevices = _discoveredDevices.toList()
      ..sort((a, b) => b.discoveredAt.compareTo(a.discoveredAt));
    
    return sortedDevices.first;
  }

  // 启动定期发现
  void _startPeriodicDiscovery() {
    _discoveryTimer?.cancel();
    _discoveryTimer = Timer.periodic(discoveryInterval, (timer) {
      if (_hasRequiredPermissions && _socket != null) {
        _sendDiscoveryRequest();
      }
    });
  }

  // 启动清理任务 - 移除过期设备
  void _startCleanupTask() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      final now = DateTime.now();
      _discoveredDevices.removeWhere((device) {
        final age = now.difference(device.discoveredAt);
        return age.inSeconds > 60; // 60秒后移除
      });
      _devicesController.add(_discoveredDevices.toList());
    });
  }

  // 发送设备发现请求
  Future<void> _sendDiscoveryRequest() async {
    if (_socket == null || !_hasRequiredPermissions) {
      LogService.instance.warning('UDP socket未就绪或缺少权限，跳过发现请求', category: 'Discovery');
      return;
    }

    try {
      // 发送广播请求
      final message = "PALM_CONTROLLER_DISCOVERY";
      final data = utf8.encode(message);
      
      // 广播到所有可能的局域网段
      final networkPrefixes = await _getNetworkPrefixes();
      
      int successCount = 0;
      int failureCount = 0;
      
      for (final prefix in networkPrefixes) {
        try {
          final broadcastAddress = '$prefix.255';
          final address = InternetAddress(broadcastAddress);
          
          _socket!.send(data, address, discoveryPort);
          successCount++;
          LogService.instance.debug('发送发现请求到: $broadcastAddress:$discoveryPort', category: 'Discovery');
        } catch (e) {
          failureCount++;
          // 单个地址发送失败不影响其他地址，但记录错误
          LogService.instance.debug('发送到 $prefix.255 失败: $e', category: 'Discovery');
          
          // 如果是权限错误，停止后续尝试
          if (e.toString().contains('Permission denied') || e.toString().contains('errno = 13')) {
            LogService.instance.error('检测到权限被拒绝错误，停止UDP广播', category: 'Discovery');
            _hasRequiredPermissions = false;
            break;
          }
        }
      }
      
      if (successCount > 0) {
        LogService.instance.info('UDP广播发送完成: 成功 $successCount, 失败 $failureCount', category: 'Discovery');
      } else if (failureCount > 0) {
        LogService.instance.error('所有UDP广播都失败了，总计尝试: ${networkPrefixes.length}, 失败: $failureCount', category: 'Discovery');
        // 不再抛出异常，而是优雅地标记权限失效
        _hasRequiredPermissions = false;
      }
    } catch (e) {
      LogService.instance.error('UDP广播发送失败: $e', category: 'Discovery');
      
      // 检查是否是权限错误
      if (e.toString().contains('Permission denied') || e.toString().contains('errno = 13')) {
        LogService.instance.error('UDP权限被拒绝，将禁用设备发现功能', category: 'Discovery');
        _hasRequiredPermissions = false;
        await stopDiscovery(); // 停止发现服务
      }
      // 不再抛出异常，让服务优雅降级
    }
  }

  // 获取当前网络前缀（用于广播）
  Future<List<String>> _getNetworkPrefixes() async {
    final prefixes = <String>['192.168.123']; // 直接使用当前已知的网段
    
    // 不使用NetworkInterface.list()避免阻塞UI，直接使用常见网段
    // 这样更快速且稳定
    prefixes.addAll([
      '192.168.1', 
      '192.168.0', 
      '10.0.0', 
      '172.16.0',
      '192.168.100'
    ]);
    
    LogService.instance.debug('使用网段: ${prefixes.join(", ")}', category: 'Discovery');
    return prefixes;
  }

  // 处理接收到的数据
  void _onDataReceived(RawSocketEvent event) {
    if (event == RawSocketEvent.read) {
      final datagram = _socket!.receive();
      if (datagram != null) {
        try {
          final message = utf8.decode(datagram.data);
          final json = jsonDecode(message) as Map<String, dynamic>;
          
          // 验证是否是PalmController服务
          if (json['serviceType'] == 'palm_controller') {
            final device = DiscoveredDevice.fromJson(json);
            
            LogService.instance.info(
              '发现设备: ${device.hostName} (${device.ipAddress}:${device.port})',
              category: 'Discovery'
            );
            
            // 更新设备列表
            _discoveredDevices.removeWhere((d) => d.ipAddress == device.ipAddress && d.port == device.port);
            _discoveredDevices.add(device);
            
            // 通知监听者
            _devicesController.add(_discoveredDevices.toList());
          }
        } catch (e) {
          LogService.instance.debug('解析发现响应失败: $e', category: 'Discovery');
        }
      }
    }
  }

  // 释放资源
  Future<void> dispose() async {
    await stopDiscovery();
    await _devicesController.close();
  }
} 