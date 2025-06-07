import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../models/control_message.dart';
import '../providers/connection_provider.dart';
import '../providers/monitor_provider.dart';
import '../services/socket_service.dart';
import 'connect_screen.dart';
import '../widgets/connection_quality_indicator.dart';
import '../services/log_service.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Timer? _volumeDebounceTimer;
  double? _localVolume; // 本地状态，用于平滑处理用户交互

  // Material Design 3 统一主题色
  static const primaryColor = Color(0xFF6750A4); // MD3 Primary
  static const secondaryColor = Color(0xFF625B71); // MD3 Secondary
  static const successColor = Color(0xFF4CAF50); // 状态指示
  static const warningColor = Color(0xFFFF9800); // 警告状态
  static const errorColor = Color(0xFFF44336); // 错误状态

  @override
  void initState() {
    super.initState();
    // 界面加载时，如果已连接，立即请求初始数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestInitialData();
    });
  }

  void _requestInitialData() {
    // 连接时延迟一点时间再请求初始数据，确保连接稳定
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && ref.read(connectionStatusProvider) == ConnectionStatus.connected) {
        _requestSystemStatus(); // 重新启用系统状态请求
        // 🔧 修复：彻底移除Dashboard中的音量请求，交由VolumeStateNotifier统一管理
      }
    });
  }
  
  void _requestSystemStatus() {
    final message = ControlMessage.systemControl(
      messageId: DateTime.now().millisecondsSinceEpoch.toString(),
      action: 'get_system_status',
    );
    _sendControlMessage(message);
  }
  
  // 首页不再维护定时刷新，避免与电脑状态页面冲突

  @override
  void dispose() {
    _volumeDebounceTimer?.cancel();
    super.dispose();
  }
  
  void _sendControlMessage(ControlMessage message) {
    final connectionStatus = ref.read(connectionStatusProvider);
    
    if (connectionStatus == ConnectionStatus.connected) {
      ref.read(socketServiceProvider).sendMessage(message).then((success) {
        if (success && mounted) {
          HapticFeedback.lightImpact();
        }
      }).catchError((e) {
        LogService.instance.error('发送控制消息失败: $e, 消息类型: ${message.type}', category: 'Dashboard');
      });
    }
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

  // 🔧 修复：移除_requestVolumeStatus方法，音量状态由VolumeStateNotifier统一管理

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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            '确认操作', 
            style: TextStyle(
              fontWeight: FontWeight.bold, 
              color: primaryColor
            )
          ),
          content: Text('您确定要执行 " $actionName " 操作吗？'),
          actions: [
            TextButton(
              child: Text(
                '取消', 
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)
                )
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
              ),
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

  void _showScheduledTaskDialog() {
    final List<Map<String, dynamic>> tasks = [
      {'name': '5分钟后关机', 'action': 'shutdown_delayed', 'params': {'delay': 300}},
      {'name': '10分钟后关机', 'action': 'shutdown_delayed', 'params': {'delay': 600}},
      {'name': '30分钟后关机', 'action': 'shutdown_delayed', 'params': {'delay': 1800}},
      {'name': '1小时后关机', 'action': 'shutdown_delayed', 'params': {'delay': 3600}},
      {'name': '定时重启（10分钟）', 'action': 'restart_delayed', 'params': {'delay': 600}},
      {'name': '定时锁屏（5分钟）', 'action': 'lock_delayed', 'params': {'delay': 300}},
    ];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('定时任务', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: tasks.map((task) => ListTile(
                leading: Icon(Icons.schedule, color: Theme.of(context).colorScheme.primary),
                title: Text(task['name']),
                onTap: () {
                  Navigator.of(context).pop();
                  _executeScheduledTask(task);
                },
              )).toList(),
            ),
          ),
          actions: [
            TextButton(
              child: Text('取消', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(180))),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  void _showRunScriptDialog() {
    final List<Map<String, dynamic>> scripts = [
      {'name': '清理系统垃圾', 'command': 'cleanmgr /sagerun:1', 'description': '运行磁盘清理工具'},
      {'name': '系统文件检查', 'command': 'sfc /scannow', 'description': '检查并修复系统文件'},
      {'name': '网络诊断重置', 'command': 'netsh winsock reset', 'description': '重置网络设置'},
      {'name': '刷新DNS缓存', 'command': 'ipconfig /flushdns', 'description': '清理DNS缓存'},
      {'name': '查看系统信息', 'command': 'msinfo32', 'description': '打开系统信息窗口'},
      {'name': '任务管理器', 'command': 'taskmgr', 'description': '打开任务管理器'},
    ];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('运行脚本', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: scripts.map((script) => ListTile(
                leading: Icon(Icons.terminal, color: Theme.of(context).colorScheme.primary),
                title: Text(script['name']),
                subtitle: Text(script['description'], style: Theme.of(context).textTheme.bodySmall),
                onTap: () {
                  Navigator.of(context).pop();
                  _executeScript(script);
                },
              )).toList(),
            ),
          ),
          actions: [
            TextButton(
              child: Text('取消', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(180))),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  void _executeScheduledTask(Map<String, dynamic> task) {
    final message = ControlMessage(
      messageId: DateTime.now().millisecondsSinceEpoch.toString(),
      type: 'system_control',
      timestamp: DateTime.now(),
      payload: {
        'action': task['action'],
        ...task['params'],
      },
    );
    _sendControlMessage(message);
    
    // 显示确认消息
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('定时任务已设置：${task['name']}'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  void _executeScript(Map<String, dynamic> script) {
    final message = ControlMessage(
      messageId: DateTime.now().millisecondsSinceEpoch.toString(),
      type: 'system_control',
      timestamp: DateTime.now(),
      payload: {
        'action': 'run_command',
        'command': script['command'],
      },
    );
    _sendControlMessage(message);
    
    // 显示确认消息
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('正在执行：${script['name']}'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connectionStatus = ref.watch(connectionStatusProvider);
    final volumeState = ref.watch(volumeStateProvider);
    final theme = Theme.of(context);

    // 添加调试信息显示
    print('🏠 DashboardScreen build - 连接状态: $connectionStatus');

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

    // 首页不再监听刷新设置变化，电脑状态页面自己管理

    final performanceData = ref.watch(performanceDataProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('控制中心'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: const ConnectionQualityIndicator(),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: IconButton(
              icon: const Icon(Icons.settings_input_antenna_rounded),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ConnectScreen(),
                  ),
                );
              },
              tooltip: '连接管理',
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            if (connectionStatus == ConnectionStatus.connected) {
              _requestSystemStatus();
              // 🔧 修复：移除音量请求，由VolumeStateNotifier统一管理
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    print('点击电脑状态卡片，使用GoRouter导航...');
                    context.push('/computer-status');
                  },
                  child: _buildSystemStatusCard(context, performanceData),
                ),
                const SizedBox(height: 20),
                _buildVolumeControlCard(context, volumeState),
                const SizedBox(height: 20),
                _buildQuickActionsCard(context),
              ],
            ),
          ),
        ),
      ),
    );
  }



  /// MD3风格的系统状态卡片
  Widget _buildSystemStatusCard(BuildContext context, PerformanceData data) {
    return Container(
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
                  Icons.computer_rounded,
                  color: primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  '电脑状态',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.touch_app_rounded,
                        color: primaryColor,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '点击查看详情',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildStatusIndicator(context, '处理器', data.cpuUsage, const Color(0xFF2196F3)),
            const SizedBox(height: 16),
            _buildStatusIndicator(context, '内存', data.ramUsage, successColor),
            const SizedBox(height: 16),
            _buildStatusIndicator(context, '磁盘', data.diskUsage, warningColor),
          ],
        ),
      ),
    );
  }

  /// MD3风格的状态指示器
  Widget _buildStatusIndicator(BuildContext context, String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              '${value.toInt()}%',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value / 100,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color,
                    color.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// MD3风格的音量控制卡片
  Widget _buildVolumeControlCard(BuildContext context, VolumeState volumeState) {
    // 优先使用用户正在拖动的本地值，否则使用来自Provider的权威值
    final displayVolume = _localVolume ?? volumeState.volume;

    // 当没有从PC获取到任何值时，控件处于禁用状态
    final bool isDisabled = volumeState.volume == null;

    // 🔧 修复：简化连接状态监听，避免重复请求
    final connectionStatus = ref.watch(connectionStatusProvider);

    // 🔧 添加详细调试日志
    print('🎛️ Dashboard音量显示: displayVolume=$displayVolume, volumeState.volume=${volumeState.volume}, isDisabled=$isDisabled');

    // 只在异常状态时记录调试信息
    if (isDisabled && connectionStatus == ConnectionStatus.connected) {
      LogService.instance.debug('音量控件处于禁用状态: 未获取到PC音量数据', category: 'Dashboard');
    }

    return Container(
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
                  Icons.volume_down_rounded,
                  '音量减',
                  isDisabled ? null : () => _adjustVolume(-10),
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
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// MD3风格的音量按钮
  Widget _buildVolumeButton(BuildContext context, IconData icon, String tooltip, VoidCallback? onPressed) {
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

  /// MD3风格的快捷操作卡片
  Widget _buildQuickActionsCard(BuildContext context) {
    return Container(
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
                  Icons.flash_on_rounded,
                  color: primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  '快捷操作',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildActionItem(context, FontAwesomeIcons.cameraRetro, '截屏', const Color(0xFF2196F3), () => _sendSystemControl('screenshot_fullscreen')),
                _buildActionItem(context, FontAwesomeIcons.clock, '定时任务', const Color(0xFF9C27B0), () => _showScheduledTaskDialog()),
                _buildActionItem(context, FontAwesomeIcons.lock, '锁屏', const Color(0xFF3F51B5), () => _sendSystemControl('lock')),
                _buildActionItem(context, FontAwesomeIcons.bellSlash, '静音', const Color(0xFF607D8B), () => _sendControlMessage(ControlMessage.mediaControl(action: 'mute', messageId: ''))),
                _buildActionItem(context, FontAwesomeIcons.paste, '剪贴板', successColor, () => _sendShortcut('v', modifiers: ['ctrl'])),
                _buildActionItem(context, FontAwesomeIcons.scroll, '运行脚本', const Color(0xFF009688), () => _showRunScriptDialog()),
                _buildActionItem(context, FontAwesomeIcons.magnifyingGlassLocation, '找光标', const Color(0xFFFFC107), () => _sendSystemControl('find_cursor')),
                _buildActionItem(context, FontAwesomeIcons.powerOff, '关机', errorColor, () => _showConfirmationDialog('关机', () => _sendSystemControl('shutdown'))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// MD3风格的操作项
  Widget _buildActionItem(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
} 