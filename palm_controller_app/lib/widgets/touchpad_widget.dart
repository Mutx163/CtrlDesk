import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/settings_screen.dart';
import '../providers/connection_provider.dart';
import 'dart:async';

class TouchpadWidget extends ConsumerStatefulWidget {
  const TouchpadWidget({super.key});

  @override
  ConsumerState<TouchpadWidget> createState() => _TouchpadWidgetState();
}

class _TouchpadWidgetState extends ConsumerState<TouchpadWidget> {
  // 防抖定时器
  Timer? _mouseMoveDebounce;
  
  // 事件节流
  DateTime _lastMouseSendTime = DateTime.now();
  static const int _mouseThrottleMs = 16; // 约60fps
  
  bool _isDragging = false;
  double _lastPanDeltaX = 0;
  double _lastPanDeltaY = 0;
  
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _mouseMoveDebounce?.cancel();
    super.dispose();
  }

  // Socket 通信方法 - 带节流的发送
  void _sendMouseMove(double deltaX, double deltaY) {
    final now = DateTime.now();
    final timeDiff = now.difference(_lastMouseSendTime).inMilliseconds;
    
    // 节流：限制发送频率
    if (timeDiff < _mouseThrottleMs) {
      return;
    }
    
    _lastMouseSendTime = now;
    
    // 发送鼠标移动指令
    final socketService = ref.read(socketServiceProvider);
    socketService.sendMouseControl(
      action: 'move',
      deltaX: deltaX,
      deltaY: deltaY,
    );
  }

  void _sendMouseClick(String button, bool hapticFeedback) {
    if (hapticFeedback) {
      HapticFeedback.lightImpact();
    }
    final socketService = ref.read(socketServiceProvider);
    socketService.sendMouseControl(
      action: 'click',
      button: button,
      clicks: 1,
    );
  }

  void _sendMouseDoubleClick() {
    final socketService = ref.read(socketServiceProvider);
    socketService.sendMouseControl(
      action: 'click',
      button: 'left',
      clicks: 2,
    );
  }

  void _sendMouseScroll(double deltaX, double deltaY, bool hapticFeedback) {
    if (hapticFeedback) {
      HapticFeedback.lightImpact();
    }
    
    // 防抖处理滚动事件
    _mouseMoveDebounce?.cancel();
    _mouseMoveDebounce = Timer(const Duration(milliseconds: 8), () {
      final socketService = ref.read(socketServiceProvider);
      socketService.sendMouseControl(
        action: 'scroll',
        deltaX: deltaX,
        deltaY: deltaY,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 精简的顶部控制栏 - 人因工程学：最小化非主要功能占用空间
          _buildCompactHeader(context, settings),
          
          // 主触摸板区域 - 最大化设计 (占用约85%的空间)
          Expanded(
            flex: 85, 
            child: _buildMaximizedTouchpadArea(context, settings),
          ),
          
          // 精简的底部按钮栏 - 人因工程学：必要控制的紧凑布局
          _buildCompactButtonBar(context, settings),
        ],
      ),
    );
  }

  /// 精简的顶部控制栏 - 人因工程学：减少垂直空间占用
  Widget _buildCompactHeader(BuildContext context, AppSettings settings) {
    return Container(
      height: 48, // 大幅减少高度，从原来的约80px减少到48px
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          // 触摸板图标 - 小型化
          Icon(
            Icons.touch_app_rounded,
            color: Theme.of(context).colorScheme.primary,
            size: 16,
          ),
          const SizedBox(width: 8),
          
          // 标题和灵敏度信息 - 单行显示
          Expanded(
            child: Text(
              '触摸板 · 灵敏度 ${(settings.mouseSensitivity * 100).round()}%',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          // 精简设置按钮
          IconButton(
            onPressed: () => _showSensitivityDialog(settings),
            icon: Icon(
              Icons.tune_rounded,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            tooltip: '调节灵敏度',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  /// 最大化触摸板区域 - 人因工程学核心：触摸区域优先
  Widget _buildMaximizedTouchpadArea(BuildContext context, AppSettings settings) {
    return Container(
      margin: const EdgeInsets.all(8), // 减少边距，最大化触摸区域
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: _handlePanStart,
        onPanUpdate: (details) => _handlePanUpdate(details, settings.mouseSensitivity),
        onPanEnd: _handlePanEnd,
        onTap: () => _handleTap(settings.hapticFeedback),
        onDoubleTap: () => _handleDoubleTap(settings.hapticFeedback),
        onLongPress: () => _handleLongPress(settings.hapticFeedback),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          child: Stack(
            children: [
              // 边缘引导线 - 增强边界感知
              Positioned.fill(
                child: Container(
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              
              // 中心指示器 - 优化尺寸和位置
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.mouse_rounded,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '触摸移动',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          Text(
                            '单击·双击·长按',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              // 角落触摸提示 - 人因工程学：增强边界识别
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 紧凑型底部按钮栏 - 人因工程学：44dp最小触摸目标，合理布局
  Widget _buildCompactButtonBar(BuildContext context, AppSettings settings) {
    return Container(
      height: 64, // 固定高度，确保符合44dp最小触摸目标
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          // 左键按钮 - 44dp最小触摸目标
          Expanded(
            child: _buildTouchTargetButton(
              context,
              icon: Icons.mouse_rounded,
              label: '左键',
              onPressed: () => _sendMouseClick('left', settings.hapticFeedback),
            ),
          ),
          const SizedBox(width: 8),
          
          // 滚轮区域 - 紧凑设计
          SizedBox(
            width: 72, // 减少宽度，给主按钮更多空间
            child: Column(
              children: [
                Expanded(
                  child: _buildScrollButton(
                    context,
                    icon: Icons.keyboard_arrow_up_rounded,
                    onPressed: () => _sendMouseScroll(0, -1, settings.hapticFeedback),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '滚轮',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 2),
                Expanded(
                  child: _buildScrollButton(
                    context,
                    icon: Icons.keyboard_arrow_down_rounded,
                    onPressed: () => _sendMouseScroll(0, 1, settings.hapticFeedback),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 8),
          // 右键按钮 - 44dp最小触摸目标
          Expanded(
            child: _buildTouchTargetButton(
              context,
              icon: Icons.more_vert_rounded,
              label: '右键',
              onPressed: () => _sendMouseClick('right', settings.hapticFeedback),
            ),
          ),
        ],
      ),
    );
  }

  /// 符合44dp最小触摸目标的按钮 - 人因工程学标准
  Widget _buildTouchTargetButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 48, // 确保48dp高度，符合人因工程学标准
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 18,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 紧凑型滚轮按钮
  Widget _buildScrollButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: double.infinity,
          height: 20, // 精简高度
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            ),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
            size: 14,
          ),
        ),
      ),
    );
  }

  // 手势处理方法
  void _handlePanStart(DragStartDetails details) {
    _isDragging = true;
    _lastPanDeltaX = 0;
    _lastPanDeltaY = 0;
  }

  void _handlePanUpdate(DragUpdateDetails details, double sensitivity) {
    if (!_isDragging) return;

    double deltaX = details.delta.dx;
    double deltaY = details.delta.dy;

    // 应用基础灵敏度放大和用户设置
    double amplifiedDeltaX = deltaX * 2.0 * sensitivity;
    double amplifiedDeltaY = deltaY * 2.0 * sensitivity;

    _sendMouseMove(amplifiedDeltaX, amplifiedDeltaY);

    _lastPanDeltaX = amplifiedDeltaX;
    _lastPanDeltaY = amplifiedDeltaY;
  }

  void _handlePanEnd(DragEndDetails details) {
    _isDragging = false;
  }

  void _handleTap(bool hapticFeedback) {
    _sendMouseClick('left', hapticFeedback);
  }

  void _handleDoubleTap(bool hapticFeedback) {
    if (hapticFeedback) {
      HapticFeedback.lightImpact();
    }
    _sendMouseDoubleClick();
  }

  void _handleLongPress(bool hapticFeedback) {
    _sendMouseClick('right', hapticFeedback);
  }

  void _handleSettingsMenu(String value, AppSettings settings) {
    if (value == 'sensitivity') {
      _showSensitivityDialog(settings);
    } else if (value == 'haptic') {
      final settingsNotifier = ref.read(settingsProvider.notifier);
      settingsNotifier.updateHapticFeedback(!settings.hapticFeedback);
    }
  }

  void _showSensitivityDialog(AppSettings settings) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('调节鼠标灵敏度'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('当前灵敏度: ${(settings.mouseSensitivity * 100).round()}%'),
                const SizedBox(height: 16),
                Slider(
                  value: settings.mouseSensitivity,
                  min: 0.1,
                  max: 3.0,
                  divisions: 29,
                  label: '${(settings.mouseSensitivity * 100).round()}%',
                                     onChanged: (value) {
                     setState(() {
                       final settingsNotifier = ref.read(settingsProvider.notifier);
                       settingsNotifier.updateMouseSensitivity(value);
                     });
                   },
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('完成'),
          ),
        ],
      ),
    );
  }
} 