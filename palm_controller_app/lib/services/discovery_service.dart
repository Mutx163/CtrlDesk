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

  // 转换为连接配�?  ConnectionConfig toConnectionConfig() {
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

  // 当前发现的设备列�?  List<DiscoveredDevice> get discoveredDevices => _discoveredDevices.toList();

  // 检查是否有必要的权�?  Future<bool> _checkAndRequestPermissions() async {
    if (_permissionCheckCompleted) {
      return _hasRequiredPermissions;
    }

    try {
      LogService.instance.info('开始检查UDP广播所需权限...', category: 'Discovery');
      
      // 检查位置权�?(Android 6.0+需要位置权限进行UDP广播)
      var locationStatus = await Permission.locationWhenInUse.status;
      LogService.instance.info('当前位置权限状�? $locationStatus', category: 'Discovery');
      
      if (locationStatus == PermissionStatus.denied) {
        LogService.instance.info('位置权限被拒绝，跳过自动权限请求（用户可在设置中手动授权�?, category: 'Discovery');
        // 不再自动请求权限，避免每次启动都弹出权限对话�?        // 用户可以通过UI主动授权
      }

      // 优化权限处理逻辑 - 更宽容的权限检�?      if (locationStatus == PermissionStatus.granted) {
        LogService.instance.info('位置权限已授予，UDP设备发现功能完全启用', category: 'Discovery');
        _hasRequiredPermissions = true;
      } else if (locationStatus == PermissionStatus.permanentlyDenied) {
        LogService.instance.warning('位置权限被永久拒绝，将尝试受限的发现功能', category: 'Discovery');
        _hasRequiredPermissions = false; // 仍然尝试，只是标记为受限
      } else {
        LogService.instance.info('位置权限状�? $locationStatus，将尝试使用发现功能', category: 'Discovery');
        // 即使权限状态不明确，我们也尝试进行UDP广播
        // 很多设备即使没有明确授权也能进行局域网UDP广播
        _hasRequiredPermissions = true;
      }

      _permissionCheckCompleted = true;
      
      LogService.instance.info('权限检查完成，将尝试启用UDP发现功能', category: 'Discovery');
      return true; // 总是返回true，让系统尝试启动发现功能
    } catch (e) {
      LogService.instance.error('权限检查失�? $e，将尝试继续启动发现功能', category: 'Discovery');
      _hasRequiredPermissions = false;
      _permissionCheckCompleted = true;
      return true; // 即使权限检查失败，也尝试启动发现功�?    }
  }

  // 开始局域网设备发现
  Future<bool> startDiscovery() async {
    try {
      // 检查权�?      final hasPermissions = await _checkAndRequestPermissions();
      if (!hasPermissions) {
        LogService.instance.warning('权限不足，设备发现功能受限，但将继续尝试', category: 'Discovery');
        // 即使权限不足，也尝试启动发现服务
      }

      // 创建UDP socket监听响应
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      
      // 配置socket选项
      try {
        _socket!.broadcastEnabled = true;
        LogService.instance.debug('UDP广播已启�?, category: 'Discovery');
      } catch (e) {
        LogService.instance.warning('无法启用UDP广播: $e', category: 'Discovery');
      }
      
      _socket!.listen(_onDataReceived);

      LogService.instance.info('设备发现服务已启动，监听端口: ${_socket!.port}', category: 'Discovery');

      // 启动定期发现
      _startPeriodicDiscovery();

      // 启动清理任务
      _startCleanupTask();

      // 立即进行一次发�?      await _sendDiscoveryRequest();

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
    LogService.instance.info('设备发现服务已停�?, category: 'Discovery');
  }

  // 手动扫描一�?  Future<List<DiscoveredDevice>> scanOnce({Duration timeout = scanTimeout}) async {
    // 清空之前的设备列�?    _discoveredDevices.clear();
    
    final completer = Completer<List<DiscoveredDevice>>();
    RawDatagramSocket? scanSocket;
    
    // 设置超时
    Timer(timeout, () {
      if (!completer.isCompleted) {
        LogService.instance.info('设备扫描超时，发�?${_discoveredDevices.length} 个设�?, category: 'Discovery');
        completer.complete(_discoveredDevices.toList());
      }
    });

    try {
      LogService.instance.info('开始手动设备扫描，超时时间: ${timeout.inSeconds}�?, category: 'Discovery');
      
      // 检查权限（但不强制要求�?      await _checkAndRequestPermissions();
      
      // 为扫描创建临时socket
      scanSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      scanSocket.broadcastEnabled = true;
      
      LogService.instance.info('扫描socket创建成功，端�? ${scanSocket.port}', category: 'Discovery');
      
      // 监听响应
      scanSocket.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = scanSocket!.receive();
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
                
                // 通知监听�?                _devicesController.add(_discoveredDevices.toList());
              }
            } catch (e) {
              LogService.instance.debug('解析发现响应失败: $e', category: 'Discovery');
            }
          }
        }
      });
      
      // 发送发现请�?      await _sendDiscoveryRequestWithSocket(scanSocket);
      
      // 等待指定时间收集响应
      await Future.delayed(const Duration(milliseconds: 3000)); // 增加等待时间�?�?      
      if (!completer.isCompleted) {
        LogService.instance.info('设备扫描完成，发�?${_discoveredDevices.length} 个设�?, category: 'Discovery');
        completer.complete(_discoveredDevices.toList());
      }
    } catch (e) {
      if (!completer.isCompleted) {
        LogService.instance.error('设备扫描失败: $e', category: 'Discovery');
        completer.completeError(e);
      }
    } finally {
      // 清理临时socket
      scanSocket?.close();
    }

    return completer.future;
  }

  // 获取最佳设备（信号最强或最近发现的�?  DiscoveredDevice? getBestDevice() {
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
      if (_socket != null) {
        _sendDiscoveryRequest();
      } else {
        LogService.instance.warning('定期发现: Socket已关闭，停止定期发现', category: 'Discovery');
        timer.cancel();
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

  // 发送设备发现请�?  Future<void> _sendDiscoveryRequest() async {
    if (_socket == null) {
      LogService.instance.warning('UDP socket未就绪，跳过发现请求', category: 'Discovery');
      return;
    }

    await _sendDiscoveryRequestWithSocket(_socket!);
  }

  // 使用指定socket发送设备发现请�?  Future<void> _sendDiscoveryRequestWithSocket(RawDatagramSocket socket) async {
    try {
      // 发送广播请�?      final message = "PALM_CONTROLLER_DISCOVERY";
      final data = utf8.encode(message);
      
      // 广播到所有可能的局域网�?      final networkPrefixes = await _getNetworkPrefixes();
      
      int successCount = 0;
      int failureCount = 0;
      
      LogService.instance.info('开始UDP广播�?${networkPrefixes.length} 个网�?..', category: 'Discovery');
      
      for (final prefix in networkPrefixes) {
        await _sendToSpecificNetworkWithSocket(socket, prefix, data, (success) {
          if (success) {
            successCount++;
          } else {
            failureCount++;
          }
        });
        
        // 在网段之间添加小延迟，避免网络拥�?        await Future.delayed(const Duration(milliseconds: 50));
      }
      
      LogService.instance.info('UDP广播完成: 成功 $successCount 个网�? 失败 $failureCount 个网�?, category: 'Discovery');
      
      if (successCount == 0 && failureCount > 0) {
        LogService.instance.warning('所有UDP广播都失败了，可能存在网络或权限问题', category: 'Discovery');
        // 不再直接禁用权限，而是继续尝试
      }
    } catch (e) {
      LogService.instance.error('UDP广播发送失�? $e', category: 'Discovery');
      
      // 检查是否是权限错误
      if (e.toString().contains('Permission denied') || e.toString().contains('errno = 13')) {
        LogService.instance.error('UDP权限被拒绝，设备发现功能将受�?, category: 'Discovery');
        _hasRequiredPermissions = false;
      }
    }
  }
  
  // 向特定网段发送UDP广播
  Future<void> _sendToSpecificNetwork(String prefix, List<int> data, Function(bool) onResult) async {
    await _sendToSpecificNetworkWithSocket(_socket!, prefix, data, onResult);
  }

  // 使用指定socket向特定网段发送UDP广播
  Future<void> _sendToSpecificNetworkWithSocket(RawDatagramSocket socket, String prefix, List<int> data, Function(bool) onResult) async {
    var success = false;
    
    try {
      final broadcastAddress = '$prefix.255';
      final address = InternetAddress(broadcastAddress);
      
      // 尝试发送UDP广播，最多重�?�?      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          final bytesSent = socket.send(data, address, discoveryPort);
          
          if (bytesSent > 0) {
            LogService.instance.debug('UDP广播发送成�?(尝试 $attempt/3): $broadcastAddress:$discoveryPort ($bytesSent bytes)', category: 'Discovery');
            success = true;
            break;
          } else {
            LogService.instance.debug('UDP广播发送失�?(尝试 $attempt/3): $broadcastAddress:$discoveryPort (0 bytes sent)', category: 'Discovery');
            if (attempt < 3) {
              await Future.delayed(Duration(milliseconds: 100 * attempt)); // 递增延迟
            }
          }
        } catch (e) {
          LogService.instance.debug('UDP发送异�?(尝试 $attempt/3): $prefix.255 - $e', category: 'Discovery');
          
          // 如果是权限错误，记录但继续尝试其他网�?          if (e.toString().contains('Permission denied') || e.toString().contains('errno = 13')) {
            LogService.instance.warning('检测到权限被拒�? $prefix.255', category: 'Discovery');
            break; // 权限错误不需要重�?          }
          
          if (attempt < 3) {
            await Future.delayed(Duration(milliseconds: 100 * attempt));
          }
        }
      }
    } catch (e) {
      LogService.instance.warning('UDP广播到网�?$prefix 完全失败: $e', category: 'Discovery');
    }
    
    onResult(success);
  }

  // 获取当前网络前缀（用于广播）
  Future<List<String>> _getNetworkPrefixes() async {
    final prefixes = <String>[];
    
    try {
      // 1. 尝试获取当前设备的网络接口信�?      final interfaces = await NetworkInterface.list(includeLoopback: false, type: InternetAddressType.IPv4);
      
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4) {
            final ip = addr.address;
            final parts = ip.split('.');
            if (parts.length == 4) {
              final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';
              if (!prefixes.contains(prefix)) {
                prefixes.add(prefix);
                LogService.instance.info('发现网络接口: ${interface.name} -> $ip (网段: $prefix)', category: 'Discovery');
              }
            }
          }
        }
      }
    } catch (e) {
      LogService.instance.warning('无法获取网络接口信息: $e，使用默认网�?, category: 'Discovery');
    }
    
    // 2. 添加常见的局域网网段 - 确保覆盖大部分情�?    final commonPrefixes = [
      '192.168.123',  // 当前已知的网�?- 优先级最�?      '192.168.1',    // 最常见的网�?      '192.168.0',    // 第二常见的网�?      '10.0.0',       // 企业网络常用
      '172.16.0',     // 另一个私有网�?      '192.168.100',  // 一些路由器的默认网�?      '192.168.10',
      '192.168.2',
      '192.168.11',
      '192.168.50',
    ];
    
    for (final prefix in commonPrefixes) {
      if (!prefixes.contains(prefix)) {
        prefixes.add(prefix);
      }
    }
    
    // 确保至少有一些网段用于扫�?    if (prefixes.isEmpty) {
      prefixes.addAll(['192.168.123', '192.168.1', '192.168.0', '10.0.0']);
      LogService.instance.warning('使用后备默认网段进行扫描', category: 'Discovery');
    }
    
    LogService.instance.info('UDP广播网段列表 (${prefixes.length}�?: ${prefixes.take(5).join(", ")}${prefixes.length > 5 ? "..." : ""}', category: 'Discovery');
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
            
            // 通知监听�?            _devicesController.add(_discoveredDevices.toList());
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
