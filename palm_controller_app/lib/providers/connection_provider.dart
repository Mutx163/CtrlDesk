import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/connection_config.dart';
import '../services/socket_service.dart';
import '../models/control_message.dart';
import 'dart:async'; // Added for StreamSubscription
import '../services/log_service.dart'; // Re-added LogService import

// Socket服务Provider
final socketServiceProvider = Provider<SocketService>((ref) {
  return SocketService(); // SocketService本身是单例，每次调用SocketService()都返回同一个实例
});

// 音量状态数据模型
class VolumeState {
  final double? volume; // Changed to nullable double
  final bool isMuted;

  VolumeState({this.volume, this.isMuted = false});

  VolumeState copyWith({
    double? volume,
    bool? isMuted,
  }) {
    return VolumeState(
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
    );
  }

  @override
  String toString() => 'VolumeState(volume: $volume, isMuted: $isMuted)';
}

// 连接状态Provider
class ConnectionStatusNotifier extends StateNotifier<ConnectionStatus> {
  ConnectionStatusNotifier(this._socketService) : super(ConnectionStatus.disconnected) {
    // 监听SocketService的状态变化
    _socketService.statusStream.listen((status) {
      state = status;
    });
    // 设置初始状态
    state = _socketService.currentStatus;
  }

  final SocketService _socketService;
}

final connectionStatusProvider = StateNotifierProvider<ConnectionStatusNotifier, ConnectionStatus>((ref) {
  final socketService = ref.watch(socketServiceProvider);
  return ConnectionStatusNotifier(socketService);
});

// 连接配置管理Provider
class ConnectionConfigNotifier extends StateNotifier<List<ConnectionConfig>> {
  ConnectionConfigNotifier() : super([]) {
    _loadConfigs();
  }

  static const String _storageKey = 'connection_configs';
  bool _isLoaded = false;

  // 加载保存的连接配置
  Future<void> _loadConfigs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configsJson = prefs.getStringList(_storageKey) ?? [];
      final configs = configsJson
          .map((json) => ConnectionConfig.fromJson(jsonDecode(json)))
          .toList();
      
      // 按最后连接时间排序，最近的在前
      configs.sort((a, b) => b.lastConnected.compareTo(a.lastConnected));
      state = configs;
      _isLoaded = true;
      
      // 记录加载结果
      LogService.instance.info('连接配置加载完成，共 ${configs.length} 个配置', category: 'Config');
    } catch (e) {
      LogService.instance.error('连接配置加载失败: $e', category: 'Config');
      _isLoaded = true; // 即使失败也标记为已加载
    }
  }

  // 确保配置已加载
  Future<void> ensureLoaded() async {
    if (!_isLoaded) {
      await _loadConfigs();
    }
  }

  // 保存连接配置到本地存储
  Future<void> _saveConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    final configsJson = state
        .map((config) => jsonEncode(config.toJson()))
        .toList();
    await prefs.setStringList(_storageKey, configsJson);
  }

  // 添加新的连接配置
  Future<void> addConfig(ConnectionConfig config) async {
    state = [...state, config];
    await _saveConfigs();
  }

  // 更新连接配置
  Future<void> updateConfig(ConnectionConfig updatedConfig) async {
    state = [
      for (final config in state)
        if (config.id == updatedConfig.id) updatedConfig else config,
    ];
    await _saveConfigs();
  }

  // 删除连接配置
  Future<void> removeConfig(String configId) async {
    state = state.where((config) => config.id != configId).toList();
    await _saveConfigs();
  }

  // 更新最后连接时间
  Future<void> updateLastConnected(String configId) async {
    try {
      final updatedConfig = state.firstWhere((config) => config.id == configId);
      final newConfig = updatedConfig.copyWith(lastConnected: DateTime.now());
      await updateConfig(newConfig);
    } catch (e) {
      // 配置不存在时（比如通过设备发现临时连接），忽略更新操作
      // 这是正常情况，不需要记录错误
    }
  }

  // 更新连接时间或添加新配置（解决设备发现连接的BadStateNoElement问题）
  Future<void> updateOrAddConfig(ConnectionConfig config) async {
    try {
      // 尝试找到现有配置并更新时间
      final existingConfig = state.firstWhere((c) => c.id == config.id);
      final updatedConfig = existingConfig.copyWith(lastConnected: DateTime.now());
      await updateConfig(updatedConfig);
    } catch (e) {
      // 配置不存在，添加新配置（常见于设备发现连接）
      await addConfig(config.copyWith(lastConnected: DateTime.now()));
    }
  }

  // 获取最近连接的配置（用于自动重连）
  ConnectionConfig? getRecentConnection() {
    if (state.isEmpty) return null;
    // 配置已按最后连接时间排序，返回第一个
    return state.first;
  }
}

final connectionConfigProvider = StateNotifierProvider<ConnectionConfigNotifier, List<ConnectionConfig>>((ref) {
  return ConnectionConfigNotifier();
});

// 当前连接配置Provider
final currentConnectionProvider = StateProvider<ConnectionConfig?>((ref) => null);

// 音量状态提供者
final volumeStateProvider =
    StateNotifierProvider<VolumeStateNotifier, VolumeState>((ref) {
  return VolumeStateNotifier(ref); // Pass the Ref object directly
});

// 音量状态管理器
class VolumeStateNotifier extends StateNotifier<VolumeState> {
  final Ref _ref; // Store the Ref object
  StreamSubscription? _messageSubscription;
  StreamSubscription<ConnectionStatus>? _connectionStatusSubscription; // Typed StreamSubscription
  ConnectionStatus? _lastConnectionStatus; // 记录上一次的连接状态

  VolumeStateNotifier(this._ref) : super(VolumeState(volume: null, isMuted: false)) {
    _subscribeToMessages();
    _listenToConnectionStatus();
  }

  void _listenToConnectionStatus() {
    // 直接监听SocketService的状态流
    final socketService = _ref.read(socketServiceProvider);
    _connectionStatusSubscription = socketService.statusStream.listen((status) {
      // 只在从非连接状态变为连接状态时请求音量状态
      if (status == ConnectionStatus.connected && _lastConnectionStatus != ConnectionStatus.connected) {
        // 延迟500ms再请求音量状态，确保连接完全建立
        Future.delayed(const Duration(milliseconds: 500), () {
          _requestVolumeStatus();
        });
      }
      // 连接断开时重置音量状态为未知状态
      if (status == ConnectionStatus.disconnected) {
        if (mounted) {
          state = VolumeState(volume: null, isMuted: false); // 🔧 修复：重置为null，表示未知状态
        }
      }
      _lastConnectionStatus = status;
    });
  }

  void _subscribeToMessages() {
    // Use _ref.read to get SocketService instance
    final socketService = _ref.read(socketServiceProvider);
    _messageSubscription = socketService.messageStream.listen((message) {
      if (message.type == 'volume_status') {
        _handleVolumeStatusMessage(message);
      }
    });
  }

  void _handleVolumeStatusMessage(ControlMessage message) {
    // LogService.instance.debug('Handling volume_status message: ${message.payload}', category: 'VolumeState'); // Kept commented
    try {
      // 确保从消息中获取到有效的音量值
      if (message.payload['volume'] != null) {
        final newVolume = (message.payload['volume'] as num).toDouble();
        final newMuteState = message.payload['muted'] as bool? ?? false;
        if (mounted) {
          state = state.copyWith(volume: newVolume, isMuted: newMuteState);
          // LogService.instance.info('Volume state updated: ${newVolume * 100}%, Muted: $newMuteState', category: 'VolumeState');
        }
      } else {
        // LogService.instance.warning('Received volume_status with null volume. Ignoring.', category: 'VolumeState'); // Kept commented
      }
    } catch (e) {
      // LogService.instance.error('Error parsing volume_status: $e', category: 'VolumeState'); // Kept commented
      // 解析失败时不改变当前状态，保持用户可以继续操作
    }
  }

  Future<void> _requestVolumeStatus() async {
    final socketService = _ref.read(socketServiceProvider);
    if (socketService.currentStatus == ConnectionStatus.connected) {
      final requestMessage = ControlMessage.mediaControl( // Use factory constructor
        messageId: DateTime.now().millisecondsSinceEpoch.toString(), // Provide messageId
        action: 'get_volume_status',
      );
      await socketService.sendMessage(requestMessage);
      // LogService.instance.debug('Requested volume status from server', category: 'VolumeState');
    } else {
      // 未连接时保持未知状态
      if (mounted) {
        state = VolumeState(volume: null, isMuted: false);
      }
    }
  }

  Future<void> updateVolume(double newVolume) async {
    if (mounted) {
      state = state.copyWith(volume: newVolume);
    }
  }

  Future<void> updateMuteState(bool newMuteState) async {
    if (mounted) {
      state = state.copyWith(isMuted: newMuteState);
    }
  }

  Future<void> refreshVolumeStatus() async {
    await _requestVolumeStatus();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _connectionStatusSubscription?.cancel();
    super.dispose();
  }
}

// 连接管理Provider
class ConnectionManagerNotifier extends StateNotifier<AsyncValue<bool>> {
  ConnectionManagerNotifier(this.ref) : super(const AsyncValue.data(false));

  final Ref ref;

  // 连接到服务器
  Future<void> connect(ConnectionConfig config, {bool autoNavigate = true}) async {
    state = const AsyncValue.loading();
    
    try {
      final socketService = ref.read(socketServiceProvider);
      final success = await socketService.connect(config);
      
      if (success) {
        // 更新当前连接配置
        ref.read(currentConnectionProvider.notifier).state = config;
        
        // 尝试更新最后连接时间，如果配置不存在（比如设备发现连接），则自动添加
        final configNotifier = ref.read(connectionConfigProvider.notifier);
        await configNotifier.updateOrAddConfig(config);
        
        state = const AsyncValue.data(true);
        
        // 连接成功后自动导航到控制界面
        if (autoNavigate) {
          _navigateToControlScreen();
        }
      } else {
        final error = socketService.lastError ?? '连接失败';
        state = AsyncValue.error(error, StackTrace.current);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  // 使用最近连接的配置自动连接
  Future<bool> connectToRecentServer() async {
    final recentConfig = ref.read(connectionConfigProvider.notifier).getRecentConnection();
    if (recentConfig == null) {
      return false;
    }

    await connect(recentConfig, autoNavigate: false); // 启动时不自动跳转，让用户看到连接过程
    return state.value == true;
  }

  // 断开连接
  Future<void> disconnect() async {
    try {
      final socketService = ref.read(socketServiceProvider);
      await socketService.disconnect();
      ref.read(currentConnectionProvider.notifier).state = null;
      state = const AsyncValue.data(false);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  // 导航到控制界面的回调
  void Function()? _onNavigateToControl;
  
  // 设置导航回调
  void setNavigationCallback(void Function() callback) {
    _onNavigateToControl = callback;
  }

  // 执行导航
  void _navigateToControlScreen() {
    if (_onNavigateToControl != null) {
      _onNavigateToControl!();
    }
  }
}

final connectionManagerProvider = StateNotifierProvider<ConnectionManagerNotifier, AsyncValue<bool>>((ref) {
  return ConnectionManagerNotifier(ref);
}); 