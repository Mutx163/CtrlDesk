import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/control_message.dart';
import '../providers/connection_provider.dart';
import '../providers/monitor_provider.dart';
import '../services/socket_service.dart';
import 'computer_status_screen.dart';
import 'connect_screen.dart';
import '../widgets/connection_quality_indicator.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Timer? _volumeDebounceTimer;
  double? _localVolume; // 本地状态，用于平滑处理用户交互

  @override
  void initState() {
    super.initState();
    // 界面加载时，如果已连接，立即请求初始数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestInitialData();
    });
  }

  void _requestInitialData() {
    if (ref.read(connectionStatusProvider) == ConnectionStatus.connected) {
      _requestVolumeStatus();
      // 未来可以添加请求其他初始数据的逻辑
    }
  }

  @override
  void dispose() {
    _volumeDebounceTimer?.cancel();
    super.dispose();
  }
  
  void _sendControlMessage(ControlMessage message) {
    ref.read(socketServiceProvider).sendMessage(message);
    HapticFeedback.lightImpact();
  }

  void _setSystemVolume(double volume) {
    // 立即更新本地UI，实现乐观更新
    setState(() {
      _localVolume = volume;
    });

    _volumeDebounceTimer?.cancel();
    _volumeDebounceTimer = Timer(const Duration(milliseconds: 100), () {
      final message = ControlMessage.mediaControl(
        messageId: DateTime.now().millisecondsSinceEpoch.toString(),
        action: 'set_volume:${volume.toStringAsFixed(2)}',
      );
      _sendControlMessage(message);
    });
  }

  void _requestVolumeStatus() {
    final message = ControlMessage.mediaControl(
      messageId: DateTime.now().millisecondsSinceEpoch.toString(),
      action: 'get_volume_status',
    );
    _sendControlMessage(message);
  }

  void _sendSystemControl(String action) {
    final message = ControlMessage.systemControl(
      messageId: DateTime.now().millisecondsSinceEpoch.toString(),
      action: action,
    );
    _sendControlMessage(message);
  }
  
  void _sendShortcut(String keyCode, {List<String> modifiers = const []}) {
    final message = ControlMessage.keyboardControl(
      messageId: DateTime.now().millisecondsSinceEpoch.toString(),
      action: 'key_press',
      keyCode: keyCode,
      modifiers: modifiers,
    );
    _sendControlMessage(message);
  }

  void _showConfirmationDialog(String actionName, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('确认操作', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
          content: Text('您确定要执行 " $actionName " 操作吗？'),
          actions: [
            TextButton(
              child: Text('取消', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(180))),
              onPressed: () => Navigator.of(context).pop(),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
              onPressed: () {
                Navigator.of(context).pop();
                onConfirm();
              },
              child: const Text('确认'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 监听来自服务器的音量状态更新。
    // 根据Riverpod规则，必须在build方法中调用ref.listen。
    ref.listen<VolumeState>(volumeStateProvider, (previous, next) {
      if (next.volume == null) return; // 忽略初始的空状态

      // 如果我们有一个本地（乐观）的音量值，
      // 并且来自Provider的新状态已经追上了它，
      // 那么我们就可以停止使用本地值，并再次信任Provider。
      // 这就"解锁"了滑块。
      if (_localVolume != null && (next.volume! - _localVolume!).abs() < 0.01) {
        if (mounted) {
          setState(() {
            _localVolume = null;
          });
        }
      }
    });

    final connectionStatus = ref.watch(connectionStatusProvider);
    final performanceData = ref.watch(performanceDataProvider);
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final volumeState = ref.watch(volumeStateProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('仪表盘'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: const ConnectionQualityIndicator(),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () {
                // 点击连接状态，进入连接管理界面
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ConnectScreen(),
                  ),
                );
              },
              child: Chip(
                avatar: const Icon(Icons.circle, color: Colors.green, size: 12),
                label: Text(
                  '已连接',
                  style: textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface),
                ),
                backgroundColor: theme.cardColor,
                side: BorderSide(color: theme.dividerColor),
              ),
            ),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ComputerStatusScreen()),
              );
            },
            child: _buildSystemStatusCard(context, performanceData),
          ),
          const SizedBox(height: 16),
          _buildVolumeControlCard(context, volumeState),
          const SizedBox(height: 16),
          _buildQuickActionsCard(context),
        ],
      ),
    );
  }

  Widget _buildSystemStatusCard(BuildContext context, PerformanceData data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('电脑状态', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _buildStatusIndicator(context, 'CPU', data.cpuUsage, Colors.blue),
            const SizedBox(height: 12),
            _buildStatusIndicator(context, '内存', data.ramUsage, Colors.green),
            const SizedBox(height: 12),
            _buildStatusIndicator(context, '磁盘', data.diskUsage, Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(BuildContext context, String label, double value, Color color) {
    return Row(
      children: [
        SizedBox(width: 50, child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
        const SizedBox(width: 16),
        Expanded(
          child: LinearProgressIndicator(
            value: value / 100,
            backgroundColor: color.withAlpha(50),
            color: color,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(width: 40, child: Text('${value.toInt()}%', style: Theme.of(context).textTheme.bodyMedium)),
      ],
    );
  }

  Widget _buildVolumeControlCard(BuildContext context, VolumeState volumeState) {
    // 优先使用用户正在拖动的本地值，否则使用来自Provider的权威值
    final displayVolume = _localVolume ?? volumeState.volume;

    // 当没有从PC获取到任何值时，控件处于禁用状态
    final bool isDisabled = volumeState.volume == null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('音量控制', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: FaIcon(volumeState.isMuted ? FontAwesomeIcons.volumeXmark : FontAwesomeIcons.volumeLow),
                  onPressed: isDisabled ? null : () => _sendSystemControl('mute'),
                ),
                Expanded(
                  child: Slider(
                    value: displayVolume ?? 0.0,
                    min: 0,
                    max: 1.0,
                    onChanged: isDisabled ? null : _setSystemVolume,
                    onChangeEnd: isDisabled
                        ? null
                        : (value) {
                            // 用户结束拖动，取消可能存在的延迟任务
                            _volumeDebounceTimer?.cancel();
                            // 确保发送最终确定的值
                            final message = ControlMessage.mediaControl(
                              messageId: DateTime.now()
                                  .millisecondsSinceEpoch
                                  .toString(),
                              action: 'set_volume:${value.toStringAsFixed(2)}',
                            );
                            _sendControlMessage(message);

                            // 保持本地状态，等待服务器确认
                            // `ref.listen` 会在收到确认后处理 `_localVolume` 的重置
                            setState(() {
                              _localVolume = value;
                            });
                          },
                  ),
                ),
                const FaIcon(FontAwesomeIcons.volumeHigh),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('快捷操作中心', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildActionItem(context, FontAwesomeIcons.cameraRetro, '截屏', Colors.blue, () => _sendSystemControl('screenshot')),
                _buildActionItem(context, FontAwesomeIcons.clock, '定时任务', Colors.purple, () {}), // Placeholder
                _buildActionItem(context, FontAwesomeIcons.lock, '锁屏', Colors.indigo, () => _sendSystemControl('lock')),
                _buildActionItem(context, FontAwesomeIcons.bellSlash, '静音', Colors.grey, () => _sendControlMessage(ControlMessage.mediaControl(action: 'mute', messageId: ''))),
                _buildActionItem(context, FontAwesomeIcons.paste, '剪贴板', Colors.green, () => _sendShortcut('v', modifiers: ['ctrl'])),
                _buildActionItem(context, FontAwesomeIcons.scroll, '运行脚本', Colors.teal, () {}), // Placeholder
                _buildActionItem(context, FontAwesomeIcons.magnifyingGlassLocation, '找光标', Colors.amber, () => _sendSystemControl('find_cursor')),
                _buildActionItem(context, FontAwesomeIcons.powerOff, '关机', Colors.red, () => _showConfirmationDialog('关机', () => _sendSystemControl('shutdown'))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
} 