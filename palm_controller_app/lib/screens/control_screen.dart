import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

  // 快速输入方法
  void _sendQuickInput() {
    if (_quickInputController.text.isNotEmpty) {
      final message = ControlMessage.keyboardControl(
        messageId: DateTime.now().millisecondsSinceEpoch.toString(),
        action: 'text_input',
        text: _quickInputController.text,
      );
      _sendControlMessage(message);
      _quickInputController.clear();
    }
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
  Widget _buildMediaControlCenter(BuildContext context, dynamic currentConnection) {
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
  Widget _buildConnectionHeader(BuildContext context, dynamic currentConnection) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFE91E63).withOpacity(0.1),
            const Color(0xFFE91E63).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE91E63).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // 媒体图标
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE91E63).withOpacity(0.1),
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
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE91E63).withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE91E63).withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // 专辑封面占位
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFFE91E63).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.music_note_rounded,
              color: Color(0xFFE91E63),
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          
          // 歌曲信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '当前播放',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Windows 媒体播放器',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '准备播放音乐或视频',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 媒体控制按钮
  Widget _buildMediaControls(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE91E63).withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE91E63).withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildMediaButton(
            context,
            icon: Icons.skip_previous_rounded,
            onPressed: () => _sendMediaControl('previous'),
            size: 48,
          ),
          _buildMediaButton(
            context,
            icon: Icons.play_arrow_rounded,
            onPressed: () => _sendMediaControl('play_pause'),
            size: 64,
            isPrimary: true,
          ),
          _buildMediaButton(
            context,
            icon: Icons.skip_next_rounded,
            onPressed: () => _sendMediaControl('next'),
            size: 48,
          ),
        ],
      ),
    );
  }

  /// 音量控制
  Widget _buildVolumeControl(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE91E63).withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE91E63).withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Consumer(
        builder: (context, ref, child) {
          final volumeState = ref.watch(volumeStateProvider);
          
          String volumeText;
          double volumeProgress;

          if (volumeState.volume == null) {
            volumeText = '获取中...';
            volumeProgress = 0.0;
          } else if (volumeState.isMuted) {
            volumeText = '静音';
            volumeProgress = 0.0;
          } else {
            final volumePercentage = (volumeState.volume! * 100).round();
            volumeText = '$volumePercentage%';
            volumeProgress = volumeState.volume!;
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.volume_up_rounded,
                    color: const Color(0xFFE91E63),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '音量控制',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFE91E63),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    volumeText,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: volumeState.isMuted ? Colors.red : const Color(0xFFE91E63),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildMediaButton(
                    context,
                    icon: Icons.volume_down_rounded,
                    onPressed: () => _sendMediaControl('volume_down'),
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: volumeState.isMuted 
                            ? Colors.red 
                            : const Color(0xFFE91E63),
                        inactiveTrackColor: const Color(0xFFE91E63).withOpacity(0.3),
                        thumbColor: volumeState.isMuted 
                            ? Colors.red 
                            : const Color(0xFFE91E63),
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                        trackHeight: 6,
                      ),
                      child: Slider(
                        value: volumeProgress,
                        min: 0.0,
                        max: 1.0,
                        onChanged: volumeState.volume == null ? null : (value) {
                          ref.read(volumeStateProvider.notifier).updateVolume(value);
                        },
                        onChangeEnd: volumeState.volume == null ? null : (value) {
                          _setSystemVolume(value);
                          _requestVolumeStatusDelayed();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildMediaButton(
                    context,
                    icon: Icons.volume_up_rounded,
                    onPressed: () => _sendMediaControl('volume_up'),
                    size: 32,
                  ),
                  const SizedBox(width: 8),
                  _buildMediaButton(
                    context,
                    icon: volumeState.isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    onPressed: () => _sendMediaControl('mute'),
                    size: 32,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  /// 快速操作面板
  Widget _buildQuickActionsPanel(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE91E63).withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE91E63).withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.flash_on_rounded,
                color: const Color(0xFFE91E63),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '快速操作',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFE91E63),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1,
            children: [
              _buildQuickActionButton('截图', Icons.camera_alt_rounded, const Color(0xFFFF5722), () => context.go('/tools')),
              _buildQuickActionButton('锁屏', Icons.lock_rounded, const Color(0xFF2196F3), () => _sendSystemControl('lock')),
              _buildQuickActionButton('显示', Icons.monitor_rounded, const Color(0xFF4CAF50), () => _sendSystemControl('display')),
              _buildQuickActionButton('休眠', Icons.bedtime_rounded, const Color(0xFF9C27B0), () => _sendSystemControl('sleep')),
            ],
          ),
        ],
      ),
    );
  }

  /// 系统状态概览
  Widget _buildSystemStatusOverview(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE91E63).withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE91E63).withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.computer_rounded,
                color: const Color(0xFFE91E63),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'PC状态',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFE91E63),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => context.go('/tools'),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('详细', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatusItem('CPU', '45%', Colors.green),
              ),
              Expanded(
                child: _buildStatusItem('内存', '8.2GB', Colors.orange),
              ),
              Expanded(
                child: _buildStatusItem('网络', '50M', Colors.green),
              ),
              Expanded(
                child: _buildStatusItem('温度', '42°C', Colors.green),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 媒体控制区域 - 直接操作，最高优先级
  Widget _buildMediaControlSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Row(
            children: [
              Icon(
                Icons.music_note_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '媒体控制',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 主要播放控制 - 大按钮设计
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMediaButton(
                context,
                icon: Icons.skip_previous_rounded,
                onPressed: () => _sendMediaControl('previous'),
                size: 48,
              ),
              const SizedBox(width: 20),
              _buildMediaButton(
                context,
                icon: Icons.play_arrow_rounded,
                onPressed: () => _sendMediaControl('play_pause'),
                size: 64, // 最大按钮
                isPrimary: true,
              ),
              const SizedBox(width: 20),
              _buildMediaButton(
                context,
                icon: Icons.skip_next_rounded,
                onPressed: () => _sendMediaControl('next'),
                size: 48,
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 音量控制 - 滑块设计
          Consumer(
            builder: (context, ref, child) {
              final volumeState = ref.watch(volumeStateProvider);
              
              String volumeText;
              double volumeProgress;

              // 🔧 修复：处理volume为null的情况（未知状态）
              if (volumeState.volume == null) {
                volumeText = '获取中...';
                volumeProgress = 0.0; // 显示为0，但不表示实际音量
              } else if (volumeState.isMuted) {
                volumeText = '静音';
                volumeProgress = 0.0;
              } else {
                final volumePercentage = (volumeState.volume! * 100).round();
                volumeText = '$volumePercentage%';
                volumeProgress = volumeState.volume!;
              }

              return Column(
                children: [
                  // 音量滑块控制
                  Row(
                    children: [
                      // 音量减按钮
                      _buildMediaButton(
                        context,
                        icon: Icons.volume_down_rounded,
                        onPressed: () => _sendMediaControl('volume_down'),
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      
                      // 音量滑块
                      Expanded(
                        child: Column(
                          children: [
                            // 音量滑块
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: volumeState.volume == null
                                    ? Colors.grey
                                    : (volumeState.isMuted 
                                        ? Colors.red 
                                        : Theme.of(context).colorScheme.primary),
                                inactiveTrackColor: volumeState.volume == null
                                    ? Colors.grey.withOpacity(0.3)
                                    : Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                thumbColor: volumeState.volume == null
                                    ? Colors.grey
                                    : (volumeState.isMuted 
                                        ? Colors.red 
                                        : Theme.of(context).colorScheme.primary),
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                                trackHeight: 4,
                              ),
                              child: Slider(
                                value: volumeProgress,
                                min: 0.0,
                                max: 1.0,
                                onChanged: volumeState.volume == null ? null : (value) {
                                  // 🔧 修复：onChanged只更新本地状态，不发送网络请求
                                  ref.read(volumeStateProvider.notifier).updateVolume(value);
                                },
                                onChangeEnd: volumeState.volume == null ? null : (value) {
                                  // 🔧 修复：onChangeEnd发送设置并延迟请求状态
                                  _setSystemVolume(value);
                                  _requestVolumeStatusDelayed();
                                },
                              ),
                            ),
                            const SizedBox(height: 4),
                            // 音量文字显示
                            Text(
                              volumeText,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: volumeState.volume == null 
                                    ? Colors.grey
                                    : (volumeState.isMuted ? Colors.red : null),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(width: 12),
                      // 音量加按钮
                      _buildMediaButton(
                        context,
                        icon: Icons.volume_up_rounded,
                        onPressed: () => _sendMediaControl('volume_up'),
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      // 静音按钮
                      _buildMediaButton(
                        context,
                        icon: volumeState.isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                        onPressed: () => _sendMediaControl('mute'),
                        size: 32,
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// 媒体控制按钮
  Widget _buildMediaButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onPressed,
    required double size,
    bool isPrimary = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isPrimary 
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
              width: 2,
            ),
            boxShadow: isPrimary ? [
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ] : null,
          ),
          child: Icon(
            icon,
            color: isPrimary 
                ? Colors.white
                : Theme.of(context).colorScheme.primary,
            size: size * 0.5,
          ),
        ),
      ),
    );
  }

  /// 系统快捷操作区域
  Widget _buildSystemShortcutsSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.computer_rounded,
                color: Theme.of(context).colorScheme.secondary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '系统快捷',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // 系统快捷按钮网格
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.0,
            children: [
              _buildSystemShortcutButton(
                context,
                icon: Icons.lock_rounded,
                label: '锁屏',
                onPressed: () => _sendSystemControl('lock'),
              ),
              _buildSystemShortcutButton(
                context,
                icon: Icons.bedtime_rounded,
                label: '睡眠',
                onPressed: () => _sendSystemControl('sleep'),
              ),
              _buildSystemShortcutButton(
                context,
                icon: Icons.volume_off_rounded,
                label: '静音',
                onPressed: () => _sendSystemControl('mute'),
              ),
              _buildSystemShortcutButton(
                context,
                icon: Icons.brightness_6_rounded,
                label: '亮度',
                onPressed: () => _sendSystemControl('brightness'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 系统快捷按钮
  Widget _buildSystemShortcutButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: Theme.of(context).colorScheme.secondary,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 常用快捷键区域
  Widget _buildCommonShortcutsSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.tertiary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.keyboard_rounded,
                color: Theme.of(context).colorScheme.tertiary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '常用快捷键',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // 快捷键按钮网格
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.8,
            children: [
              _buildShortcutButton(
                context,
                label: 'Ctrl+C',
                description: '复制',
                onPressed: () => _sendShortcut('c', modifiers: ['ctrl']),
              ),
              _buildShortcutButton(
                context,
                label: 'Ctrl+V',
                description: '粘贴',
                onPressed: () => _sendShortcut('v', modifiers: ['ctrl']),
              ),
              _buildShortcutButton(
                context,
                label: 'Ctrl+Z',
                description: '撤销',
                onPressed: () => _sendShortcut('z', modifiers: ['ctrl']),
              ),
              _buildShortcutButton(
                context,
                label: 'Alt+Tab',
                description: '切换',
                onPressed: () => _sendShortcut('VK_TAB', modifiers: ['alt']),
              ),
              _buildShortcutButton(
                context,
                label: 'Backspace',
                description: '退格',
                onPressed: () => _sendShortcut('VK_BACK'),
              ),
              _buildShortcutButton(
                context,
                label: 'Enter',
                description: '回车',
                onPressed: () => _sendShortcut('VK_RETURN'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 快捷键按钮
  Widget _buildShortcutButton(
    BuildContext context, {
    required String label,
    required String description,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.tertiary.withOpacity(0.2),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.tertiary,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 快速输入区域
  Widget _buildQuickInputSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.edit_rounded,
                color: Theme.of(context).colorScheme.onSurface,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '快速输入',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // 输入框和发送按钮
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _quickInputController,
                  decoration: InputDecoration(
                    hintText: '快速输入文本...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (_) => _sendQuickInput(),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _sendQuickInput,
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('发送'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotConnectedView(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.wifi_off_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            '设备未连接',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            '请先连接到PC设备后使用控制功能',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.push('/connect'),
              icon: const Icon(Icons.wifi_rounded),
              label: const Text('连接设备'),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建快速操作按钮
  Widget _buildQuickActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: color,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建状态项
  Widget _buildStatusItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: color.withOpacity(0.7),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}