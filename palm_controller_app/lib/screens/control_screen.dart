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
  double? _localVolume; // 添加本地音量存储

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
        
        // 当前播放信息卡片（包含快捷操作按钮）
        SliverToBoxAdapter(
          child: _buildNowPlayingCard(context),
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

  /// 当前播放信息卡片 - 增强版 Material Design 3风格
  Widget _buildNowPlayingCard(BuildContext context) {
    final mediaStatus = ref.watch(mediaStatusProvider);
    final connectionStatus = ref.watch(connectionStatusProvider);
    
    // MD3 主题色
    const primaryColor = Color(0xFF6750A4); // MD3 Primary
    const mediaColor = Color(0xFFE91E63); // 媒体主色调：玫红色

    // 连接状态检查
    if (connectionStatus != ConnectionStatus.connected) {
      return _buildNotConnectedMediaCard(context);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部标题行
            Row(
              children: [
                Icon(
                  Icons.music_note_rounded,
                  color: primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  '正在播放',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const Spacer(),
                // 播放状态指示器
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: mediaStatus.isPlaying 
                        ? mediaColor.withOpacity(0.15)
                        : Colors.grey.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        mediaStatus.isPlaying ? Icons.play_circle_filled : Icons.pause_circle_filled,
                        color: mediaStatus.isPlaying ? mediaColor : Colors.grey[600],
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        mediaStatus.isPlaying ? '播放中' : '已暂停',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: mediaStatus.isPlaying ? mediaColor : Colors.grey[600],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // 媒体内容区域
            Row(
              children: [
                // 专辑封面 - 增强版
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
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
                const SizedBox(width: 20),
                
                // 歌曲信息 - 增强版
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 歌曲标题
                      Text(
                        _getDisplayTitle(mediaStatus),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _getTitleColor(context, mediaStatus.state),
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      
                      // 艺术家
                      Text(
                        _getDisplayArtist(mediaStatus),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: _getSubtitleColor(context, mediaStatus.state),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      
                      // 快捷操作按钮
                      Row(
                        children: [
                          _buildQuickActionButton(
                            context,
                            Icons.skip_previous_rounded,
                            '上一首',
                            () => _sendMediaControl('previous'),
                            primaryColor,
                          ),
                          const SizedBox(width: 8),
                          _buildQuickActionButton(
                            context,
                            mediaStatus.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            mediaStatus.isPlaying ? '暂停' : '播放',
                            () => _sendMediaControl('play_pause'),
                            mediaColor,
                            isMain: true,
                          ),
                          const SizedBox(width: 8),
                          _buildQuickActionButton(
                            context,
                            Icons.skip_next_rounded,
                            '下一首',
                            () => _sendMediaControl('next'),
                            primaryColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            // 底部附加信息 - 根据状态显示不同内容
            const SizedBox(height: 16),
            Divider(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              height: 1,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  _getStatusIcon(mediaStatus.state),
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getStatusText(mediaStatus.state),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ),
                // 刷新按钮 - 始终显示
                TextButton.icon(
                  onPressed: () => _requestMediaStatus(),
                  icon: Icon(
                    Icons.refresh_rounded,
                    size: 16,
                    color: primaryColor,
                  ),
                  label: Text(
                    '刷新',
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 12,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 快捷操作按钮
  Widget _buildQuickActionButton(
    BuildContext context,
    IconData icon,
    String tooltip,
    VoidCallback onPressed,
    Color color, {
    bool isMain = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(isMain ? 16 : 12),
          child: Container(
            padding: EdgeInsets.all(isMain ? 16 : 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(isMain ? 16 : 12),
            ),
            child: Icon(
              icon,
              color: color,
              size: isMain ? 24 : 20,
            ),
          ),
        ),
      ),
    );
  }

  /// 未连接时的媒体卡片
  Widget _buildNotConnectedMediaCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.music_off_rounded,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              '未连接到设备',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '连接到电脑后即可查看当前播放信息',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// 请求媒体状态
  void _requestMediaStatus() {
    ref.read(mediaStatusProvider.notifier).refreshMediaStatus();
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

  /// 根据媒体状态获取状态图标
  IconData _getStatusIcon(MediaState state) {
    switch (state) {
      case MediaState.unknown:
        return Icons.help_outline_rounded;
      case MediaState.loading:
        return Icons.hourglass_empty_rounded;
      case MediaState.available:
        return Icons.library_music_rounded;
      case MediaState.unavailable:
        return Icons.music_off_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  /// 根据媒体状态获取状态文本
  String _getStatusText(MediaState state) {
    switch (state) {
      case MediaState.unknown:
        return '媒体状态未知，点击刷新按钮获取信息';
      case MediaState.loading:
        return '正在获取媒体信息...';
      case MediaState.available:
        return '点击上方按钮控制播放器';
      case MediaState.unavailable:
        return '当前没有媒体正在播放，请先打开播放器';
      default:
        return '媒体状态未知';
    }
  }

  /// 获取显示标题
  String _getDisplayTitle(MediaStatus mediaStatus) {
    switch (mediaStatus.state) {
      case MediaState.loading:
        return '正在获取歌曲信息...';
      case MediaState.unavailable:
        return '无媒体播放';
      case MediaState.available:
        return mediaStatus.title ?? '未知曲目';
      case MediaState.unknown:
      default:
        return '未知状态';
    }
  }

  /// 获取显示艺术家
  String _getDisplayArtist(MediaStatus mediaStatus) {
    switch (mediaStatus.state) {
      case MediaState.loading:
        return '请稍候...';
      case MediaState.unavailable:
        return '请打开播放器应用';
      case MediaState.available:
        return mediaStatus.artist ?? '未知艺术家';
      case MediaState.unknown:
      default:
        return '点击刷新获取信息';
    }
  }

  /// 获取标题颜色
  Color _getTitleColor(BuildContext context, MediaState state) {
    switch (state) {
      case MediaState.loading:
        return Theme.of(context).colorScheme.onSurface.withOpacity(0.6);
      case MediaState.unavailable:
        return Theme.of(context).colorScheme.onSurface.withOpacity(0.5);
      case MediaState.available:
        return Theme.of(context).colorScheme.onSurface;
      case MediaState.unknown:
      default:
        return Theme.of(context).colorScheme.onSurface.withOpacity(0.7);
    }
  }

  /// 获取副标题颜色
  Color _getSubtitleColor(BuildContext context, MediaState state) {
    switch (state) {
      case MediaState.loading:
        return Theme.of(context).colorScheme.onSurface.withOpacity(0.5);
      case MediaState.unavailable:
        return Theme.of(context).colorScheme.onSurface.withOpacity(0.4);
      case MediaState.available:
        return Theme.of(context).colorScheme.onSurface.withOpacity(0.7);
      case MediaState.unknown:
      default:
        return Theme.of(context).colorScheme.onSurface.withOpacity(0.6);
    }
  }

  /// 音量控制 - 集成自主页Dashboard的MD3风格设计
  Widget _buildVolumeControl(BuildContext context) {
    final volumeState = ref.watch(volumeStateProvider);
    
    // 优先使用用户正在拖动的本地值，否则使用来自Provider的权威值
    final displayVolume = _localVolume ?? volumeState.volume;

    // 当没有从PC获取到任何值时，控件处于禁用状态
    final bool isDisabled = volumeState.volume == null;

    // 连接状态监听
    final connectionStatus = ref.watch(connectionStatusProvider);

    // MD3 统一主题色
    const primaryColor = Color(0xFF6750A4); // MD3 Primary

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  volumeState.isMuted 
                    ? Icons.volume_off_rounded 
                    : Icons.volume_up_rounded,
                  color: primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  '系统音量',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    displayVolume != null 
                        ? '${displayVolume.round()}%'
                        : (connectionStatus == ConnectionStatus.connected ? '获取中...' : '--'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _buildVolumeButton(
                  context,
                  volumeState.isMuted ? Icons.volume_off_rounded : Icons.volume_down_rounded,
                  volumeState.isMuted ? '取消静音' : '音量减',
                  isDisabled ? null : () {
                    if (volumeState.isMuted) {
                      _sendMediaControl('mute'); // 取消静音
                    } else {
                      _adjustVolume(-10); // 音量减
                    }
                  },
                  primaryColor: primaryColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 8,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                      activeTrackColor: isDisabled ? Colors.grey : primaryColor,
                      inactiveTrackColor: isDisabled ? Colors.grey.withOpacity(0.2) : primaryColor.withOpacity(0.2),
                      thumbColor: isDisabled ? Colors.grey : primaryColor,
                      overlayColor: isDisabled ? Colors.grey.withOpacity(0.2) : primaryColor.withOpacity(0.2),
                    ),
                    child: Slider(
                      value: isDisabled ? 0.0 : (displayVolume ?? 0.0),
                      min: 0.0,
                      max: 100.0,
                      onChanged: isDisabled ? null : (value) {
                        setState(() {
                          _localVolume = value;
                        });
                        _adjustVolumeWithDebounce(value);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _buildVolumeButton(
                  context,
                  Icons.volume_up_rounded,
                  '音量加',
                  isDisabled ? null : () => _adjustVolume(10),
                  primaryColor: primaryColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// MD3风格的音量按钮
  Widget _buildVolumeButton(BuildContext context, IconData icon, String tooltip, VoidCallback? onPressed, {required Color primaryColor}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: onPressed != null 
              ? primaryColor.withOpacity(0.1)
              : Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: onPressed != null 
              ? primaryColor
              : Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            size: 20,
          ),
        ),
      ),
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

  /// 音量调节方法 - 从主页Dashboard复制
  void _adjustVolume(double delta) {
    final currentVolume = _localVolume ?? ref.read(volumeStateProvider).volume ?? 0.0;
    final newVolume = (currentVolume + delta).clamp(0.0, 100.0);
    
    setState(() {
      _localVolume = newVolume;
    });
    
    _adjustVolumeWithDebounce(newVolume);
  }

  void _adjustVolumeWithDebounce(double volume) {
    _volumeDebounceTimer?.cancel();
    _volumeDebounceTimer = Timer(const Duration(milliseconds: 200), () {
      final message = ControlMessage.mediaControl(
        messageId: DateTime.now().millisecondsSinceEpoch.toString(),
        action: 'set_volume:${(volume / 100).toStringAsFixed(2)}',
      );
      _sendControlMessage(message);
    });
  }
}

