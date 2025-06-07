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
    // 使用更安全的查找方式，避免firstWhere抛出异常
    final existingConfigIndex = state.indexWhere((c) => c.id == config.id);
    
    if (existingConfigIndex != -1) {
      // 配置存在，更新连接时间
      final existingConfig = state[existingConfigIndex];
      final updatedConfig = existingConfig.copyWith(lastConnected: DateTime.now());
      await updateConfig(updatedConfig);
    } else {
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

// 新增：媒体状态枚举
enum MediaState {
  unknown,    // 未知状态（初始状态）
  loading,    // 正在加载媒体状态
  available,  // 有媒体信息可用
  unavailable // 无媒体信息（没有播放器活动）
}

// 新增：媒体状态数据模型
class MediaStatus {
  final String? title;
  final String? artist;
  final bool isPlaying;
  final String? artworkUrl; // 专辑封面URL
  final MediaState state; // 媒体状态

  MediaStatus({
    this.title,
    this.artist,
    this.isPlaying = false,
    this.artworkUrl,
    this.state = MediaState.unknown,
  });

  MediaStatus copyWith({
    String? title,
    String? artist,
    bool? isPlaying,
    String? artworkUrl,
    MediaState? state,
  }) {
    return MediaStatus(
      title: title ?? this.title,
      artist: artist ?? this.artist,
      isPlaying: isPlaying ?? this.isPlaying,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      state: state ?? this.state,
    );
  }

  @override
  String toString() {
    return 'MediaStatus(title: $title, artist: $artist, isPlaying: $isPlaying, state: $state)';
  }
}

// 新增：系统信息数据模型
class SystemInfo {
  final double cpuUsage;
  final double memoryUsage;

  SystemInfo({this.cpuUsage = 0.0, this.memoryUsage = 0.0});

  SystemInfo copyWith({
    double? cpuUsage,
    double? memoryUsage,
  }) {
    return SystemInfo(
      cpuUsage: cpuUsage ?? this.cpuUsage,
      memoryUsage: memoryUsage ?? this.memoryUsage,
    );
  }

  @override
  String toString() {
    return 'SystemInfo(cpuUsage: $cpuUsage, memoryUsage: $memoryUsage)';
  }
}

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
        // 🔧 修复：简化为单次请求，避免多重异步操作冲突
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted && _ref.read(socketServiceProvider).currentStatus == ConnectionStatus.connected) {
            _requestVolumeStatus();
          }
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
      // 移除冗余的调试日志，只在错误时记录
    });
  }

  void _handleVolumeStatusMessage(ControlMessage message) {
    try {
      // 🔧 添加详细调试日志
      print('🎵 VolumeStateNotifier收到音量状态消息: ${message.payload}');
      
      if (message.payload['volume'] != null) {
        final newVolume = (message.payload['volume'] as num).toDouble() * 100; // 🔧 修复：PC端发送0-1范围，需要转换为0-100
        final newMuteState = message.payload['muted'] as bool? ?? false;
        
        print('🎵 解析音量数据: volume=${newVolume}%, muted=$newMuteState');
        
        if (mounted) {
          state = state.copyWith(volume: newVolume, isMuted: newMuteState);
          print('🎵 音量状态已更新: ${state.toString()}');
        }
      }
    } catch (e) {
      LogService.instance.error('Error parsing volume_status: $e', category: 'VolumeState');
      print('❌ 音量状态解析失败: $e');
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

// 新增：媒体状态Provider
final mediaStatusProvider = StateNotifierProvider<MediaStatusNotifier, MediaStatus>((ref) {
  return MediaStatusNotifier(ref);
});

// 新增：系统信息Provider
final systemInfoProvider = StateNotifierProvider<SystemInfoNotifier, SystemInfo>((ref) {
  return SystemInfoNotifier(ref);
});

// 新增：媒体状态管理器
class MediaStatusNotifier extends StateNotifier<MediaStatus> {
  final Ref _ref;
  StreamSubscription? _messageSubscription;
  StreamSubscription<ConnectionStatus>? _connectionStatusSubscription;
  ConnectionStatus? _lastConnectionStatus;
  Timer? _requestTimeout;

  MediaStatusNotifier(this._ref) : super(MediaStatus()) {
    _subscribeToMessages();
    _listenToConnectionStatus();
  }

  void _listenToConnectionStatus() {
    final socketService = _ref.read(socketServiceProvider);
    _connectionStatusSubscription = socketService.statusStream.listen((status) {
      // 连接成功时主动请求媒体状态
      if (status == ConnectionStatus.connected && _lastConnectionStatus != ConnectionStatus.connected) {
        // 设置为加载状态
        if (mounted) {
          state = state.copyWith(state: MediaState.loading);
        }
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && _ref.read(socketServiceProvider).currentStatus == ConnectionStatus.connected) {
            _requestMediaStatus();
          }
        });
      }
      // 连接断开时重置媒体状态
      if (status == ConnectionStatus.disconnected) {
        _cancelRequestTimeout();
        if (mounted) {
          state = MediaStatus(state: MediaState.unknown); // 重置为未知状态
        }
      }
      _lastConnectionStatus = status;
    });
  }

  void _subscribeToMessages() {
    final socketService = _ref.read(socketServiceProvider);
    _messageSubscription = socketService.messageStream.listen((message) {
      if (message.type == 'media_status') {
        _cancelRequestTimeout(); // 收到响应，取消超时
        _handleMediaStatusMessage(message);
      }
    });
  }

  void _handleMediaStatusMessage(ControlMessage message) {
    try {
      print('🎵 收到媒体状态响应: ${message.payload}');
      
      if (mounted) {
        final title = message.payload['title'];
        final artist = message.payload['artist'];
        final isPlaying = message.payload['isPlaying'] as bool? ?? false;
        final artworkUrl = message.payload['artworkUrl'];
        
        // 根据返回的数据判断媒体状态
        MediaState newState;
        if (title != null && title.toString().isNotEmpty) {
          newState = MediaState.available;
        } else {
          newState = MediaState.unavailable;
        }
        
        state = state.copyWith(
          title: title,
          artist: artist,
          isPlaying: isPlaying,
          artworkUrl: artworkUrl,
          state: newState,
        );
        
        print('🎵 MediaStatusNotifier更新媒体状态: ${state.toString()}');
      }
    } catch (e) {
      LogService.instance.error('Error parsing media_status: $e', category: 'MediaState');
      // 解析失败时设置为不可用状态
      if (mounted) {
        state = state.copyWith(state: MediaState.unavailable);
      }
    }
  }

  Future<void> _requestMediaStatus() async {
    final socketService = _ref.read(socketServiceProvider);
    if (socketService.currentStatus == ConnectionStatus.connected) {
      final requestMessage = ControlMessage.mediaControl(
        messageId: DateTime.now().millisecondsSinceEpoch.toString(),
        action: 'get_media_status',
      );
      
      print('🎵 发送媒体状态请求: ${requestMessage.toJson()}');
      await socketService.sendMessage(requestMessage);
      print('🎵 MediaStatusNotifier请求媒体状态');
      
      // 设置5秒超时
      _startRequestTimeout();
    }
  }

  void _startRequestTimeout() {
    _cancelRequestTimeout();
    _requestTimeout = Timer(const Duration(seconds: 5), () {
      print('🎵 媒体状态请求超时，可能没有活动的播放器');
      if (mounted) {
        state = state.copyWith(state: MediaState.unavailable);
      }
    });
  }

  void _cancelRequestTimeout() {
    _requestTimeout?.cancel();
    _requestTimeout = null;
  }

  // 外部调用刷新媒体状态
  Future<void> refreshMediaStatus() async {
    if (mounted) {
      state = state.copyWith(state: MediaState.loading);
    }
    await _requestMediaStatus();
  }

  @override
  void dispose() {
    _cancelRequestTimeout();
    _messageSubscription?.cancel();
    _connectionStatusSubscription?.cancel();
    super.dispose();
  }
}

// 新增：系统信息管理器
class SystemInfoNotifier extends StateNotifier<SystemInfo> {
  final Ref _ref;
  StreamSubscription? _messageSubscription;

  SystemInfoNotifier(this._ref) : super(SystemInfo()) {
    _subscribeToMessages();
    _requestSystemInfo(); // 初始请求
  }

  void _subscribeToMessages() {
    final socketService = _ref.read(socketServiceProvider);
    _messageSubscription = socketService.messageStream.listen((message) {
      if (message.type == 'system_info') {
        _handleSystemInfoMessage(message);
      }
    });
  }

  void _handleSystemInfoMessage(ControlMessage message) {
    try {
      if (mounted) {
        state = state.copyWith(
          cpuUsage: (message.payload['cpuUsage'] as num?)?.toDouble() ?? 0.0,
          memoryUsage: (message.payload['memoryUsage'] as num?)?.toDouble() ?? 0.0,
        );
      }
    } catch (e) {
      LogService.instance.error('Error parsing system_info: $e', category: 'SystemInfoState');
    }
  }

  void _requestSystemInfo() {
    // This could be sent periodically or on demand
    final socketService = _ref.read(socketServiceProvider);
    if (socketService.currentStatus == ConnectionStatus.connected) {
      final requestMessage = ControlMessage.systemControl(
        messageId: DateTime.now().millisecondsSinceEpoch.toString(),
        action: 'get_system_info',
      );
      socketService.sendMessage(requestMessage);
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
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

  // 执行导航 - 增强安全性
  void _navigateToControlScreen() {
    if (_onNavigateToControl != null) {
      try {
        // 使用microtask延迟执行，确保在下一个事件循环中执行
        // 这样可以避免在Widget dispose过程中访问context
        Future.microtask(() {
          if (_onNavigateToControl != null) {
            _onNavigateToControl!();
          }
        });
      } catch (e) {
        // 记录导航回调执行异常，但不中断连接流程
        LogService.instance.error('Navigation callback execution error: $e', category: 'ConnectionManager');
      }
    }
  }
}

final connectionManagerProvider = StateNotifierProvider<ConnectionManagerNotifier, AsyncValue<bool>>((ref) {
  return ConnectionManagerNotifier(ref);
}); 
