import 'dart:async';
import '../models/connection_config.dart';
import '../services/discovery_service.dart';
import '../services/socket_service.dart';
import '../services/log_service.dart';

enum AutoConnectStatus {
  disabled,
  scanning,
  connecting,
  connected,
  failed,
}

class AutoConnectService {
  static final AutoConnectService _instance = AutoConnectService._internal();
  factory AutoConnectService() => _instance;
  AutoConnectService._internal();

  final DiscoveryService _discoveryService = DiscoveryService();
  final SocketService _socketService = SocketService();
  
  Timer? _autoConnectTimer;
  StreamSubscription? _devicesSubscription;
  StreamSubscription? _connectionStatusSubscription;
  
  AutoConnectStatus _status = AutoConnectStatus.disabled;
  String? _lastError;
  ConnectionConfig? _currentConnection;
  
  final StreamController<AutoConnectStatus> _statusController =
      StreamController<AutoConnectStatus>.broadcast();

  // 状态流
  Stream<AutoConnectStatus> get statusStream => _statusController.stream;
  AutoConnectStatus get status => _status;
  String? get lastError => _lastError;
  ConnectionConfig? get currentConnection => _currentConnection;

  // 应用启动时自动连接
  Future<bool> startAutoConnect() async {
    if (_status == AutoConnectStatus.scanning || _status == AutoConnectStatus.connecting) {
      return false;
    }

    LogService.instance.info('启动自动连接服务', category: 'AutoConnect');
    _updateStatus(AutoConnectStatus.scanning);
    
    try {
      // 启动设备发现
      final discoveryStarted = await _discoveryService.startDiscovery();
      if (!discoveryStarted) {
        LogService.instance.warning('设备发现服务启动失败（可能缺少权限），但继续尝试手动扫描', category: 'AutoConnect');
        
        // 即使设备发现服务启动失败，也尝试进行一次手动扫描
        try {
          final devices = await _discoveryService.scanOnce(timeout: const Duration(seconds: 8));
          if (devices.isNotEmpty) {
            LogService.instance.info('手动扫描发现 ${devices.length} 个设备', category: 'AutoConnect');
            _onDevicesDiscovered(devices);
            return true;
          }
        } catch (e) {
          LogService.instance.warning('手动扫描也失败: $e', category: 'AutoConnect');
        }
        
        // 所有尝试都失败时，才标记为失败
        _lastError = '设备发现需要位置权限，请使用手动连接';
        _updateStatus(AutoConnectStatus.disabled);
        return false;
      }

      // 监听发现的设备
      _devicesSubscription = _discoveryService.devicesStream.listen(_onDevicesDiscovered);
      
      // 监听连接状态变化
      _connectionStatusSubscription = _socketService.statusStream.listen(_onConnectionStatusChanged);

      // 设置自动连接超时
      _autoConnectTimer = Timer(const Duration(seconds: 15), () {
        if (_status == AutoConnectStatus.scanning) {
          LogService.instance.warning('自动连接超时，停用自动连接服务', category: 'AutoConnect');
          _lastError = '未发现可用设备，请使用手动连接';
          _updateStatus(AutoConnectStatus.disabled);
        }
      });

      return true;
    } catch (e) {
      LogService.instance.error('启动自动连接失败: $e', category: 'AutoConnect');
      _lastError = '自动连接失败，请使用手动连接';
      _updateStatus(AutoConnectStatus.disabled);
      return false;
    }
  }

  // 停止自动连接
  Future<void> stopAutoConnect() async {
    _autoConnectTimer?.cancel();
    await _devicesSubscription?.cancel();
    await _connectionStatusSubscription?.cancel();
    await _discoveryService.stopDiscovery();
    
    if (_status != AutoConnectStatus.connected) {
      _updateStatus(AutoConnectStatus.disabled);
    }
    
    LogService.instance.info('自动连接服务已停止', category: 'AutoConnect');
  }

  // 手动重试连接
  Future<bool> retryConnect() async {
    if (_status == AutoConnectStatus.connected) {
      return true;
    }

    await stopAutoConnect();
    await Future.delayed(const Duration(milliseconds: 500));
    return await startAutoConnect();
  }

  // 设备发现回调
  void _onDevicesDiscovered(List<DiscoveredDevice> devices) {
    if (_status != AutoConnectStatus.scanning || devices.isEmpty) {
      return;
    }

    LogService.instance.info('发现 ${devices.length} 个设备，开始自动连接', category: 'AutoConnect');
    
    // 获取最佳设备（最近发现的）
    final bestDevice = devices.first;
    _attemptConnection(bestDevice);
  }

  // 尝试连接设备
  Future<void> _attemptConnection(DiscoveredDevice device) async {
    if (_status == AutoConnectStatus.connecting) {
      return; // 避免重复连接
    }

    _updateStatus(AutoConnectStatus.connecting);
    LogService.instance.info('尝试连接到: ${device.hostName} (${device.ipAddress}:${device.port})', category: 'AutoConnect');

    try {
      // 停止设备发现以节省资源
      _autoConnectTimer?.cancel();
      
      // 创建连接配置
      final config = device.toConnectionConfig();
      _currentConnection = config;
      
      // 尝试连接
      final success = await _socketService.connect(config);
      
      if (success) {
        LogService.instance.info('自动连接成功: ${device.hostName}', category: 'AutoConnect');
        _updateStatus(AutoConnectStatus.connected);
        
        // 连接成功后停止发现服务
        await _discoveryService.stopDiscovery();
      } else {
        _lastError = _socketService.lastError ?? '连接失败';
        LogService.instance.warning('自动连接失败: $_lastError', category: 'AutoConnect');
        
        // 连接失败，继续扫描其他设备
        _updateStatus(AutoConnectStatus.scanning);
        _startFallbackScan();
      }
    } catch (e) {
      _lastError = '连接异常: $e';
      _updateStatus(AutoConnectStatus.failed);
      LogService.instance.error('自动连接异常: $e', category: 'AutoConnect');
    }
  }

  // 连接状态变化回调
  void _onConnectionStatusChanged(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        if (_status != AutoConnectStatus.connected) {
          _updateStatus(AutoConnectStatus.connected);
        }
        break;
      case ConnectionStatus.disconnected:
      case ConnectionStatus.error:
        if (_status == AutoConnectStatus.connected) {
          LogService.instance.warning('连接丢失，尝试重新连接', category: 'AutoConnect');
          // 自动重连
          _attemptReconnect();
        }
        break;
      default:
        break;
    }
  }

  // 尝试重新连接
  Future<void> _attemptReconnect() async {
    // 延迟2秒后重试，避免频繁重连
    await Future.delayed(const Duration(seconds: 2));
    
    if (_currentConnection != null) {
      LogService.instance.info('尝试重新连接到: ${_currentConnection!.name}', category: 'AutoConnect');
      
      final success = await _socketService.connect(_currentConnection!);
      if (!success) {
        // 重连失败，不再自动扫描，改为等待用户手动操作
        LogService.instance.warning('重连失败，请使用手动连接', category: 'AutoConnect');
        _updateStatus(AutoConnectStatus.disabled);
        _lastError = '连接丢失，请重新手动连接';
      }
    }
  }

  // 备用扫描（连接失败后继续寻找其他设备）
  void _startFallbackScan() {
    _autoConnectTimer = Timer(const Duration(seconds: 5), () {
      if (_status == AutoConnectStatus.scanning) {
        final devices = _discoveryService.discoveredDevices;
        if (devices.length > 1) {
          // 尝试连接下一个设备
          final nextDevice = devices.skip(1).first;
          _attemptConnection(nextDevice);
        } else {
          _lastError = '未发现其他可用设备，请使用手动连接';
          _updateStatus(AutoConnectStatus.disabled);
        }
      }
    });
  }

  // 更新状态
  void _updateStatus(AutoConnectStatus status) {
    _status = status;
    _statusController.add(status);
  }

  // 释放资源
  Future<void> dispose() async {
    await stopAutoConnect();
    await _statusController.close();
  }

  // Fallback连接到常见IP地址（移除此功能，权限问题不再尝试fallback）
} 
