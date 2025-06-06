import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/connection_config.dart';
import '../providers/connection_provider.dart';
import '../services/socket_service.dart';
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
    // 🔧 界面加载时立即请求音量状态
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final connectionStatus = ref.read(connectionStatusProvider);
      if (connectionStatus == ConnectionStatus.connected) {
        _requestVolumeStatus();
      }
    });
  }

  @override
  void dispose() {
    _quickInputController.dispose();
    _volumeDebounceTimer?.cancel(); // 清理计时器
    super.dispose();
  }

  // 发送控制消息的通用方法
  void _sendControlMessage(ControlMessage message) {
    final socketService = ref.read(socketServiceProvider);
    socketService.sendMessage(message);
    HapticFeedback.lightImpact(); // 触觉反馈
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
      body: SafeArea(
        child: connectionStatus == ConnectionStatus.connected
            ? _buildMediaControlCenter(context, currentConnection)
            : _buildNotConnectedView(context),
      ),
    );
  }

  /// 媒体控制中心界面 - 优化的媒体控制体验
  Widget _buildMediaControlCenter(BuildContext context, ConnectionConfig? currentConnection) {
    return CustomScrollView(
      slivers: [
        // 顶部连接状态
        SliverToBoxAdapter(
          child: _buildConnectionHeader(context, currentConnection),
        ),
        
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
        
        // 快速操作面板
        SliverToBoxAdapter(
          child: _buildQuickActionsPanel(context),
        ),
        
        // 系统状态概览
        SliverToBoxAdapter(
          child: _buildSystemStatusOverview(context),
        ),
        
        // 底部间距
        const SliverToBoxAdapter(
          child: SizedBox(height: 100),
        ),
      ],
    );
  }

  /// 连接状态头部
  Widget _buildConnectionHeader(BuildContext context, ConnectionConfig? currentConnection) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFE91E63).withAlpha((0.1 * 255).round()),
            const Color(0xFFE91E63).withAlpha((0.05 * 255).round()),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE91E63).withAlpha((0.2 * 255).round()),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // 媒体图标
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE91E63).withAlpha((0.1 * 255).round()),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.music_note_rounded,
              color: Color(0xFFE91E63),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          
          // 标题和连接信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '媒体控制中心',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFE91E63),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      currentConnection?.name ?? 'Windows PC',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withAlpha((0.7 * 255).round()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 当前播放信息卡片
  Widget _buildNowPlayingCard(BuildContext context) {
    final mediaStatus = ref.watch(mediaStatusProvider);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      shadowColor: Theme.of(context).colorScheme.primary.withAlpha((0.2 * 255).round()),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary.withAlpha((0.1 * 255).round()),
              Theme.of(context).colorScheme.primary.withAlpha((0.05 * 255).round()),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withAlpha((0.2 * 255).round()),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withAlpha((0.1 * 255).round()),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // 专辑封面
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha((0.3 * 255).round()),
                  borderRadius: BorderRadius.circular(12),
                  image: mediaStatus.artworkUrl != null
                      ? DecorationImage(
                          image: NetworkImage(mediaStatus.artworkUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: mediaStatus.artworkUrl == null
                    ? Icon(
                        Icons.music_note,
                        color: Theme.of(context).colorScheme.onSurface.withAlpha((0.5 * 255).round()),
                        size: 40,
                      )
                    : null,
              ),
              const SizedBox(width: 20),
              
              // 歌曲信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mediaStatus.title ?? '未知曲目',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      mediaStatus.artist ?? '未知艺术家',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withAlpha((0.7 * 255).round()),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 媒体控制按钮区域
  Widget _buildMediaControls(BuildContext context) {
    final mediaStatus = ref.watch(mediaStatusProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMediaButton(context, Icons.skip_previous, '上一首', () => _sendMediaControl('previous')),
          _buildMediaButton(
            context,
            mediaStatus.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
            mediaStatus.isPlaying ? '暂停' : '播放',
            () => _sendMediaControl('play_pause'),
            isPrimary: true,
          ),
          _buildMediaButton(context, Icons.skip_next, '下一首', () => _sendMediaControl('next')),
        ],
      ),
    );
  }

  /// 媒体控制按钮
  Widget _buildMediaButton(BuildContext context, IconData icon, String tooltip, VoidCallback onPressed, {bool isPrimary = false}) {
    final color = isPrimary
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurface.withAlpha((0.7 * 255).round());
    final bgColor = isPrimary
        ? Theme.of(context).colorScheme.primary.withAlpha((0.1 * 255).round())
        : Colors.transparent;
    final iconSize = isPrimary ? 56.0 : 32.0;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(isPrimary ? 30 : 20),
        child: Container(
          padding: EdgeInsets.all(isPrimary ? 16 : 12),
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: iconSize),
        ),
      ),
    );
  }

  /// 音量控制
  Widget _buildVolumeControl(BuildContext context) {
    final volumeState = ref.watch(volumeStateProvider);
    final volume = volumeState.volume ?? 0.0;

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
                    value: volume,
                    min: 0.0,
                    max: 1.0,
                    divisions: 20,
                    onChanged: (value) {
                      _setSystemVolume(value);
                    },
                    onChangeEnd: (value) {
                      _requestVolumeStatusDelayed();
                    },
                  ),
                ),
                _buildVolumeButton(
                  context,
                  Icons.volume_up,
                  '音量+',
                  () {
                    final newVolume = (volume + 0.05).clamp(0.0, 1.0);
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

  /// 快速操作面板
  Widget _buildQuickActionsPanel(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 12),
            child: Text(
              '快速操作',
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
              _buildActionCard(context, '关机', Icons.power_settings_new, () => _showConfirmationDialog('关机', () => _sendSystemControl('shutdown')), color: const Color(0xFFD32F2F)),
              _buildActionCard(context, '重启', Icons.restart_alt, () => _showConfirmationDialog('重启', () => _sendSystemControl('restart')), color: const Color(0xFFF57C00)),
              _buildActionCard(context, '睡眠', Icons.bedtime, () => _sendSystemControl('sleep'), color: const Color(0xFF1976D2)),
              _buildActionCard(context, '锁屏', Icons.lock, () => _sendSystemControl('lock'), color: const Color(0xFF388E3C)),
              _buildActionCard(context, 'PPT下一页', Icons.arrow_forward_ios, () => _sendSystemControl('ppt_next'), color: const Color(0xFF7B1FA2)),
              _buildActionCard(context, 'PPT上一页', Icons.arrow_back_ios, () => _sendSystemControl('ppt_previous'), color: const Color(0xFF7B1FA2)),
              _buildActionCard(context, '复制', Icons.copy, () => _sendShortcut('c', modifiers: ['ctrl']), color: const Color(0xFF0288D1)),
              _buildActionCard(context, '粘贴', Icons.paste, () => _sendShortcut('v', modifiers: ['ctrl']), color: const Color(0xFF0288D1)),
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

  /// 系统状态概览
  Widget _buildSystemStatusOverview(BuildContext context) {
    final systemInfo = ref.watch(systemInfoProvider);

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '系统状态概览',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface.withAlpha((0.8 * 255).round()),
              ),
            ),
            const SizedBox(height: 16),
            _buildStatusRow(context, Icons.memory, 'CPU 使用率', '${systemInfo.cpuUsage.toStringAsFixed(1)} %'),
            const SizedBox(height: 12),
            _buildStatusRow(context, Icons.storage, '内存使用率', '${systemInfo.memoryUsage.toStringAsFixed(1)} %'),
          ],
        ),
      ),
    );
  }

  /// 状态行
  Widget _buildStatusRow(BuildContext context, IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
        const SizedBox(width: 16),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withAlpha((0.8 * 255).round()),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
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

  // 确认对话框
  void _showConfirmationDialog(String actionName, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            '确认操作',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          content: Text('您确定要执行 “$actionName” 操作吗？'),
          actions: [
            TextButton(
              child: Text(
                '取消',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha((0.7 * 255).round())),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
              onPressed: () {
                Navigator.of(context).pop();
                onConfirm();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('已发送 “$actionName” 指令'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text('确认'),
            ),
          ],
        );
      },
    );
  }
}

