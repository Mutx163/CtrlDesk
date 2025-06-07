import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/connection_config.dart';
import '../providers/connection_provider.dart';
import '../services/socket_service.dart';
import '../services/log_service.dart'; // 添加日志服务
import '../models/control_message.dart';
import 'dart:async'; // 添加Timer支持

class ControlScreen extends ConsumerStatefulWidget {
  const ControlScreen({super.key});

  @override
  ConsumerState<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends ConsumerState<ControlScreen> {
  final TextEditingController _quickInputController = TextEditingController();
  Timer? _volumeDebounceTimer; // 添加防抖计时器

  @override
  void initState() {
    super.initState();
    // 🔧 界面加载时延迟请求音量状态，确保连接稳定
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 延迟1秒再请求，确保连接完全建立
      Timer(const Duration(seconds: 1), () {
        if (mounted) {
          final connectionStatus = ref.read(connectionStatusProvider);
          if (connectionStatus == ConnectionStatus.connected) {
            _requestVolumeStatus();
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _quickInputController.dispose();
    _volumeDebounceTimer?.cancel(); // 清理计时器
    super.dispose();
  }

  // 发送控制消息的通用方法
  void _sendControlMessage(ControlMessage message) async {
    // 首先检查连接状态
    final connectionStatus = ref.read(connectionStatusProvider);
    if (connectionStatus != ConnectionStatus.connected) {
      print('连接未建立，无法发送消息: ${message.type}');
      return;
    }

    final socketService = ref.read(socketServiceProvider);
    final success = await socketService.sendMessage(message);
    
    if (success) {
      HapticFeedback.lightImpact(); // 触觉反馈
    } else {
      print('消息发送失败: ${message.type}');
    }
  }

  // 媒体控制方法
  void _sendMediaControl(String action) {
    final message = ControlMessage.mediaControl(
      messageId: DateTime.now().millisecondsSinceEpoch.toString(),
      action: action,
    );
    _sendControlMessage(message);
  }

  // 系统控制方法
  void _sendSystemControl(String action) {
    final message = ControlMessage.systemControl(
      messageId: DateTime.now().millisecondsSinceEpoch.toString(),
      action: action,
    );
    _sendControlMessage(message);
  }

  // 快捷键方法
  void _sendShortcut(String keyCode, {List<String> modifiers = const []}) {
    final message = ControlMessage.keyboardControl(
      messageId: DateTime.now().millisecondsSinceEpoch.toString(),
      action: 'key_press',
      keyCode: keyCode,
      modifiers: modifiers,
    );
    _sendControlMessage(message);
  }

  // 设置系统音量 - 优化版本
  void _setSystemVolume(double volume) {
    // 立即更新本地状态，提供即时反馈
    ref.read(volumeStateProvider.notifier).updateVolume(volume);
    
    // 防抖机制：避免过于频繁的网络请求
    _volumeDebounceTimer?.cancel();
    _volumeDebounceTimer = Timer(const Duration(milliseconds: 100), () {
      final message = ControlMessage.mediaControl(
        messageId: DateTime.now().millisecondsSinceEpoch.toString(),
        action: 'set_volume:${volume.toStringAsFixed(2)}',
      );
      _sendControlMessage(message);
    });
  }

  // 请求音量状态 - 延迟版本
  void _requestVolumeStatusDelayed() {
    // 延迟请求状态，避免与本地状态更新冲突
    Timer(const Duration(milliseconds: 500), () {
      final message = ControlMessage.mediaControl(
        messageId: DateTime.now().millisecondsSinceEpoch.toString(),
        action: 'get_volume_status',
      );
      _sendControlMessage(message);
    });
  }

  // 保留原有的立即请求方法，供其他地方使用
  void _requestVolumeStatus() {
    final message = ControlMessage.mediaControl(
      messageId: DateTime.now().millisecondsSinceEpoch.toString(),
      action: 'get_volume_status',
    );
    _sendControlMessage(message);
  }

  @override
  Widget build(BuildContext context) {
    final connectionStatus = ref.watch(connectionStatusProvider);
    final currentConnection = ref.watch(currentConnectionProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('媒体控制'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: connectionStatus == ConnectionStatus.connected
            ? _buildMediaControlCenter(context, currentConnection)
            : _buildNotConnectedView(context),
      ),
    );
  }

  /// 媒体控制中心界面 - 专注核心媒体控制功能
  Widget _buildMediaControlCenter(BuildContext context, ConnectionConfig? currentConnection) {
    return CustomScrollView(
      slivers: [
        
        // 当前播放信息卡片
        SliverToBoxAdapter(
          child: _buildNowPlayingCard(context),
        ),
        
        // 媒体控制按钮
        SliverToBoxAdapter(
          child: _buildMediaControls(context),
        ),
        
        // 音量控制
        SliverToBoxAdapter(
          child: _buildVolumeControl(context),
        ),
        
        // 媒体快捷键面板
        SliverToBoxAdapter(
          child: _buildMediaShortcutsPanel(context),
        ),
        
        // 底部间距
        const SliverToBoxAdapter(
          child: SizedBox(height: 100),
        ),
      ],
    );
  }



  /// 当前播放信息卡片 - Material Design 3风格
  Widget _buildNowPlayingCard(BuildContext context) {
    final mediaStatus = ref.watch(mediaStatusProvider);
    const mediaColor = Color(0xFFE91E63); // 媒体主色调：玫红色

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            mediaColor.withOpacity(0.15),
            mediaColor.withOpacity(0.08),
            mediaColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24), // MD3标准圆角
        border: Border.all(
          color: mediaColor.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: mediaColor.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 6),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24), // 增加内边距
        child: Row(
          children: [
            // 专辑封面 - 增强版
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16), // 更大圆角
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: mediaStatus.artworkUrl != null
                    ? Image.network(
                        mediaStatus.artworkUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _buildDefaultArtwork(context),
                      )
                    : _buildDefaultArtwork(context),
              ),
            ),
            const SizedBox(width: 24), // 增加间距
            
            // 歌曲信息 - 增强版
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 歌曲标题
                  Text(
                    mediaStatus.title ?? '未知曲目',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  
                  // 艺术家
                  Text(
                    mediaStatus.artist ?? '未知艺术家',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  
                  // 播放状态指示器
                  Row(
                    children: [
                      Icon(
                        mediaStatus.isPlaying ? Icons.play_circle_filled : Icons.pause_circle_filled,
                        color: mediaColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        mediaStatus.isPlaying ? '正在播放' : '已暂停',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: mediaColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 默认专辑封面
  Widget _buildDefaultArtwork(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFE91E63).withOpacity(0.3),
            const Color(0xFF9C27B0).withOpacity(0.3),
          ],
        ),
      ),
      child: Icon(
        Icons.music_note_rounded,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        size: 40,
      ),
    );
  }

  /// 媒体控制按钮区域 - Material Design 3风格
  Widget _buildMediaControls(BuildContext context) {
    final mediaStatus = ref.watch(mediaStatusProvider);
    const mediaColor = Color(0xFFE91E63); // 媒体主色调

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildMediaButton(
            context, 
            Icons.skip_previous_rounded, 
            '上一首', 
            () => _sendMediaControl('previous'),
            isSecondary: true,
          ),
          _buildMediaButton(
            context,
            mediaStatus.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
            mediaStatus.isPlaying ? '暂停' : '播放',
            () => _sendMediaControl('play_pause'),
            isPrimary: true,
          ),
          _buildMediaButton(
            context, 
            Icons.skip_next_rounded, 
            '下一首', 
            () => _sendMediaControl('next'),
            isSecondary: true,
          ),
        ],
      ),
    );
  }

  /// 媒体控制按钮 - Material Design 3风格
  Widget _buildMediaButton(
    BuildContext context, 
    IconData icon, 
    String tooltip, 
    VoidCallback onPressed, {
    bool isPrimary = false,
    bool isSecondary = false,
  }) {
    const mediaColor = Color(0xFFE91E63);
    
    // 根据按钮类型设置样式
    Color iconColor;
    Color backgroundColor;
    double iconSize;
    double containerSize;
    
    if (isPrimary) {
      // 主要播放按钮
      iconColor = Colors.white;
      backgroundColor = mediaColor;
      iconSize = 32.0;
      containerSize = 64.0;
    } else if (isSecondary) {
      // 次要控制按钮
      iconColor = mediaColor;
      backgroundColor = mediaColor.withOpacity(0.12);
      iconSize = 28.0;
      containerSize = 56.0;
    } else {
      // 默认按钮
      iconColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.7);
      backgroundColor = Colors.transparent;
      iconSize = 24.0;
      containerSize = 48.0;
    }

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(containerSize / 2),
          child: Container(
            width: containerSize,
            height: containerSize,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
              boxShadow: isPrimary ? [
                BoxShadow(
                  color: mediaColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ] : null,
            ),
            child: Icon(
              icon, 
              color: iconColor, 
              size: iconSize,
            ),
          ),
        ),
      ),
    );
  }

  /// 音量控制
  Widget _buildVolumeControl(BuildContext context) {
    final volumeState = ref.watch(volumeStateProvider);
    
    // 添加严格的数值验证和异常安全保护
    double volume = 0.0; // 默认值
    
    if (volumeState.volume != null) {
      final rawVolume = volumeState.volume!;
      
      // 检查是否为有效的有限数值
      if (rawVolume.isFinite && !rawVolume.isNaN) {
        // 确保值在有效范围内 (0.0 - 1.0)
        volume = rawVolume.clamp(0.0, 1.0);
      } else {
        // 无效数值时使用默认值并记录警告
        LogService.instance.warning('音量值无效: $rawVolume，使用默认值0.0', category: 'UI');
      }
    }

    // 移除冗余调试信息

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Theme.of(context).colorScheme.onSurface.withAlpha((0.12 * 255).round()),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                _buildVolumeButton(
                  context,
                  volumeState.isMuted ? Icons.volume_off : Icons.volume_down,
                  '静音/取消静音',
                  () => _sendMediaControl('mute'),
                  color: volumeState.isMuted
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.onSurface.withAlpha((0.6 * 255).round()),
                ),
                Expanded(
                  child: Slider(
                    value: volume, // 使用经过验证的安全数值
                    min: 0.0,
                    max: 1.0,
                    divisions: 20,
                    onChanged: (value) {
                      // 再次验证用户输入的值
                      if (value.isFinite && !value.isNaN) {
                        final safeValue = value.clamp(0.0, 1.0);
                        _setSystemVolume(safeValue);
                      }
                    },
                    onChangeEnd: (value) {
                      if (value.isFinite && !value.isNaN) {
                        _requestVolumeStatusDelayed();
                      }
                    },
                  ),
                ),
                _buildVolumeButton(
                  context,
                  Icons.volume_up,
                  '音量+',
                  () {
                    // 安全的音量增加操作
                    final safeCurrentVolume = volume.clamp(0.0, 1.0);
                    final newVolume = (safeCurrentVolume + 0.05).clamp(0.0, 1.0);
                    _setSystemVolume(newVolume);
                    _requestVolumeStatusDelayed();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 音量调节按钮
  Widget _buildVolumeButton(BuildContext context, IconData icon, String tooltip, VoidCallback onPressed, {Color? color}) {
    return IconButton(
      icon: Icon(icon, color: color ?? Theme.of(context).colorScheme.onSurface.withAlpha((0.6 * 255).round())),
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: 28,
    );
  }

  /// 媒体快捷键面板 - 专注媒体相关功能
  Widget _buildMediaShortcutsPanel(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 12),
            child: Text(
              '媒体快捷键',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface.withAlpha((0.8 * 255).round()),
              ),
            ),
          ),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: [
              _buildActionCard(context, '播放/暂停', Icons.play_arrow, () => _sendMediaControl('play_pause'), color: const Color(0xFFE91E63)),
              _buildActionCard(context, '停止', Icons.stop, () => _sendMediaControl('stop'), color: const Color(0xFFD32F2F)),
              _buildActionCard(context, '随机播放', Icons.shuffle, () => _sendMediaControl('shuffle'), color: const Color(0xFF9C27B0)),
              _buildActionCard(context, '重复播放', Icons.repeat, () => _sendMediaControl('repeat'), color: const Color(0xFF3F51B5)),
              _buildActionCard(context, '快进', Icons.fast_forward, () => _sendMediaControl('fast_forward'), color: const Color(0xFF1976D2)),
              _buildActionCard(context, '快退', Icons.fast_rewind, () => _sendMediaControl('fast_rewind'), color: const Color(0xFF1976D2)),
              _buildActionCard(context, '全屏', Icons.fullscreen, () => _sendShortcut('F11'), color: const Color(0xFF388E3C)),
              _buildActionCard(context, '收藏', Icons.favorite, () => _sendShortcut('F'), color: const Color(0xFFFF5722)),
            ],
          ),
        ],
      ),
    );
  }

  /// 操作卡片
  Widget _buildActionCard(BuildContext context, String title, IconData icon, VoidCallback onTap, {required Color color}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: color.withAlpha((0.1 * 255).round()),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withAlpha((0.2 * 255).round()),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: color.withAlpha((0.9 * 255).round()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 未连接时的界面
  Widget _buildNotConnectedView(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).colorScheme.error.withAlpha((0.2 * 255).round()),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.error.withAlpha((0.1 * 255).round()),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          color: Theme.of(context).colorScheme.surface,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error.withAlpha((0.1 * 255).round()),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).colorScheme.error.withAlpha((0.2 * 255).round())),
              ),
              child: Icon(
                Icons.power_off,
                color: Theme.of(context).colorScheme.error,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '未连接到任何设备',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '请先建立连接以使用媒体控制功能',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withAlpha((0.7 * 255).round()),
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              icon: const Icon(Icons.link),
              label: const Text('前往连接'),
              onPressed: () {
                context.go('/connect');
              },
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

