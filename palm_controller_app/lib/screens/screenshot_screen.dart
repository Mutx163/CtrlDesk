import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connection_provider.dart';
import '../services/socket_service.dart';
import '../models/control_message.dart';

class ScreenshotScreen extends ConsumerStatefulWidget {
  const ScreenshotScreen({super.key});

  @override
  ConsumerState<ScreenshotScreen> createState() => _ScreenshotScreenState();
}

class _ScreenshotScreenState extends ConsumerState<ScreenshotScreen> {
  int _selectedMode = 0; // 0: 全屏, 1: 窗口, 2: 区域
  int _timerSeconds = 0; // 0表示立即截图
  bool _continuousMode = false;
  int _intervalSeconds = 3;
  final List<Map<String, String>> _screenshotHistory = [];

  // 发送截图控制消息
  void _sendScreenshotMessage(String action, {Map<String, dynamic>? params}) {
    final message = ControlMessage.systemControl(
      messageId: DateTime.now().millisecondsSinceEpoch.toString(),
      action: 'screenshot_$action',
    );
    
    final socketService = ref.read(socketServiceProvider);
    socketService.sendMessage(message);
    HapticFeedback.lightImpact();
  }

  // 执行截图
  void _takeScreenshot() {
    String action;
    Map<String, dynamic>? params;

    switch (_selectedMode) {
      case 0:
        action = 'fullscreen';
        break;
      case 1:
        action = 'window';
        break;
      case 2:
        action = 'region';
        break;
      default:
        action = 'fullscreen';
    }

    if (_timerSeconds > 0) {
      params = {'delay': _timerSeconds};
    }

    _sendScreenshotMessage(action, params: params);
    
    // 添加到历史记录（模拟）
    setState(() {
      _screenshotHistory.insert(0, {
        'time': DateTime.now().toString().substring(11, 19),
        'type': ['全屏', '窗口', '区域'][_selectedMode],
        'file': 'screenshot_${DateTime.now().millisecondsSinceEpoch}.png',
      });
    });

    // 显示提示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_timerSeconds > 0 ? '$_timerSeconds秒后开始截图' : '正在截图...'),
        duration: Duration(seconds: _timerSeconds > 0 ? _timerSeconds : 2),
      ),
    );
  }

  // 开始/停止连续截图
  void _toggleContinuousMode() {
    setState(() {
      _continuousMode = !_continuousMode;
    });

    if (_continuousMode) {
      _sendScreenshotMessage('start_continuous', params: {'interval': _intervalSeconds});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('开始连续截图，间隔$_intervalSeconds秒')),
      );
    } else {
      _sendScreenshotMessage('stop_continuous');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('停止连续截图')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectionStatus = ref.watch(connectionStatusProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: connectionStatus == ConnectionStatus.connected
            ? _buildScreenshotInterface(context)
            : _buildNotConnectedView(context),
      ),
    );
  }

  Widget _buildScreenshotInterface(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 页面标题
          _buildPageHeader(context),
          const SizedBox(height: 20),
          
          // 截图模式选择
          _buildModeSelection(context),
          const SizedBox(height: 20),
          
          // 定时设置
          _buildTimerSettings(context),
          const SizedBox(height: 20),
          
          // 连续截图设置
          _buildContinuousSettings(context),
          const SizedBox(height: 20),
          
          // 操作按钮
          _buildActionButtons(context),
          const SizedBox(height: 30),
          
          // 截图历史
          _buildScreenshotHistory(context),
          const SizedBox(height: 20),
          
          // 高级设置
          _buildAdvancedSettings(context),
        ],
      ),
    );
  }

  Widget _buildPageHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF57C00).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.camera_alt_rounded,
            color: Color(0xFFF57C00),
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '屏幕截图',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFF57C00),
                ),
              ),
              Text(
                '捕获PC屏幕内容',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModeSelection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF57C00).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF57C00).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '截图模式',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: const Color(0xFFF57C00),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildModeButton(
                  context,
                  icon: Icons.fullscreen_rounded,
                  label: '全屏截图',
                  description: '捕获完整桌面',
                  isSelected: _selectedMode == 0,
                  onPressed: () => setState(() => _selectedMode = 0),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildModeButton(
                  context,
                  icon: Icons.crop_free_rounded,
                  label: '窗口截图',
                  description: '捕获活动窗口',
                  isSelected: _selectedMode == 1,
                  onPressed: () => setState(() => _selectedMode = 1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildModeButton(
                  context,
                  icon: Icons.crop_rounded,
                  label: '区域截图',
                  description: '选择区域捕获',
                  isSelected: _selectedMode == 2,
                  onPressed: () => setState(() => _selectedMode = 2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String description,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected 
                ? const Color(0xFFF57C00).withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected 
                  ? const Color(0xFFF57C00)
                  : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected 
                    ? const Color(0xFFF57C00)
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                size: 24,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isSelected 
                      ? const Color(0xFFF57C00)
                      : Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimerSettings(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.timer_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '定时截图',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _timerSeconds,
                  decoration: const InputDecoration(
                    labelText: '延时设置',
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('立即截图')),
                    DropdownMenuItem(value: 3, child: Text('3秒后')),
                    DropdownMenuItem(value: 5, child: Text('5秒后')),
                    DropdownMenuItem(value: 10, child: Text('10秒后')),
                  ],
                  onChanged: (value) => setState(() => _timerSeconds = value ?? 0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContinuousSettings(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.repeat_rounded,
                color: Theme.of(context).colorScheme.secondary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '连续截图',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              const Spacer(),
              Switch(
                value: _continuousMode,
                onChanged: (value) => _toggleContinuousMode(),
              ),
            ],
          ),
          if (_continuousMode) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _intervalSeconds,
                    decoration: const InputDecoration(
                      labelText: '间隔时间',
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('1秒')),
                      DropdownMenuItem(value: 3, child: Text('3秒')),
                      DropdownMenuItem(value: 5, child: Text('5秒')),
                      DropdownMenuItem(value: 10, child: Text('10秒')),
                      DropdownMenuItem(value: 30, child: Text('30秒')),
                    ],
                    onChanged: (value) => setState(() => _intervalSeconds = value ?? 3),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: _takeScreenshot,
            icon: const Icon(Icons.camera_rounded),
            label: Text(_timerSeconds > 0 ? '定时截图' : '立即截图'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF57C00),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: () => _sendScreenshotMessage('refresh_preview'),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('刷新预览'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFF57C00),
            side: const BorderSide(color: Color(0xFFF57C00)),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildScreenshotHistory(BuildContext context) {
    if (_screenshotHistory.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              '暂无截图历史',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.history_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '截图历史',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => _screenshotHistory.clear()),
                child: const Text('清空'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _screenshotHistory.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = _screenshotHistory[index];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(
                        Icons.image_rounded,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item['type']}截图',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${item['time']} • ${item['file']}',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, size: 16),
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'view', child: Text('查看')),
                        const PopupMenuItem(value: 'share', child: Text('分享')),
                        const PopupMenuItem(value: 'delete', child: Text('删除')),
                      ],
                      onSelected: (value) {
                        switch (value) {
                          case 'view':
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('正在打开图片...')),
                            );
                            break;
                          case 'share':
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('正在分享...')),
                            );
                            break;
                          case 'delete':
                            setState(() => _screenshotHistory.removeAt(index));
                            break;
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedSettings(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.tune_rounded,
                color: Theme.of(context).colorScheme.tertiary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '高级设置',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: 'original',
                  decoration: const InputDecoration(
                    labelText: '分辨率',
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'original', child: Text('原始分辨率')),
                    DropdownMenuItem(value: '1080p', child: Text('1080p')),
                    DropdownMenuItem(value: '720p', child: Text('720p')),
                  ],
                  onChanged: (value) {},
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: 'png',
                  decoration: const InputDecoration(
                    labelText: '图像格式',
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'png', child: Text('PNG')),
                    DropdownMenuItem(value: 'jpg', child: Text('JPG')),
                    DropdownMenuItem(value: 'bmp', child: Text('BMP')),
                  ],
                  onChanged: (value) {},
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SwitchListTile(
                  title: const Text('声音提示'),
                  subtitle: const Text('截图时播放提示音'),
                  value: true,
                  onChanged: (value) {},
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              Expanded(
                child: SwitchListTile(
                  title: const Text('震动反馈'),
                  subtitle: const Text('截图完成后震动'),
                  value: true,
                  onChanged: (value) {},
                  contentPadding: EdgeInsets.zero,
                  dense: true,
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
              color: const Color(0xFFF57C00).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.camera_alt_outlined,
              size: 64,
              color: Color(0xFFF57C00),
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
            '请先连接到PC设备后使用截图功能',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).pushReplacementNamed('/connect'),
              icon: const Icon(Icons.wifi_rounded),
              label: const Text('连接设备'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF57C00),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 
