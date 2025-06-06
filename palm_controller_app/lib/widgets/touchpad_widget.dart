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

class _TouchpadWidgetState extends ConsumerState<TouchpadWidget> with TickerProviderStateMixin {
  // 防抖定时器
  Timer? _mouseMoveDebounce;
  
  // 事件节流
  DateTime _lastMouseSendTime = DateTime.now();
  static const int _mouseThrottleMs = 16; // 60fps
  
  bool _isDragging = false;
  
  // 动画控制器
  late AnimationController _pulseController;
  late AnimationController _touchController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _touchAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // 初始化动画控制器
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _touchController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _touchAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _touchController,
      curve: Curves.easeInOut,
    ));
    
    // 开始轻微的脉冲动画
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _mouseMoveDebounce?.cancel();
    _pulseController.dispose();
    _touchController.dispose();
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
    
    // 触摸动画
    _touchController.forward().then((_) {
      _touchController.reverse();
    });
    
    final socketService = ref.read(socketServiceProvider);
    socketService.sendMouseControl(
      action: 'click',
      button: button,
      clicks: 1,
    );
  }

  void _sendMouseDoubleClick() {
    // 触摸动画
    _touchController.forward().then((_) {
      _touchController.reverse();
    });
    
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
    
    return AnimatedBuilder(
      animation: _touchAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _touchAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                // 简化的顶部栏
                _buildHeader(context, settings),
                
                // 主触摸板区域
                Expanded(
                  child: _buildTouchpadArea(context, settings),
                ),
                
                // 四个大按钮的底部区域
                _buildButtonArea(context, settings),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 简化的顶部栏
  Widget _buildHeader(BuildContext context, AppSettings settings) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer.withOpacity(0.5),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.mouse_rounded,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '触控板',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '灵敏度 ${(settings.mouseSensitivity * 100).round()}%',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _showSensitivityDialog(settings),
            icon: Icon(
              Icons.tune_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 18,
            ),
            iconSize: 18,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }

  /// 简化的触摸板区域
  Widget _buildTouchpadArea(BuildContext context, AppSettings settings) {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _handlePointerDown,
          onPointerMove: (event) => _handlePointerMove(event, settings.mouseSensitivity),
          onPointerUp: _handlePointerUp,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _handleTap(settings.hapticFeedback),
            onDoubleTap: () => _handleDoubleTap(settings.hapticFeedback),
            onLongPress: () => _handleLongPress(settings.hapticFeedback),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              child: Center(
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _pulseAnimation.value * 0.6 + 0.4,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.touch_app_rounded,
                            size: 48,
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '触摸移动光标',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '单击 • 双击 • 长按右键',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 三区域按钮布局：左键 | 滚轮(上下) | 右键
  Widget _buildButtonArea(BuildContext context, AppSettings settings) {
    return Container(
      height: 70,
      child: Row(
        children: [
          // 左键按钮
          Expanded(
            flex: 2,
            child: _buildButton(
              context,
              icon: Icons.mouse_rounded,
              label: '左键',
              isPrimary: true,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
              ),
              onPressed: () => _sendMouseClick('left', settings.hapticFeedback),
            ),
          ),
          
          // 滚轮区域 - 上下布局
          Expanded(
            flex: 1,
            child: Column(
              children: [
                // 上滚轮按钮
                Expanded(
                  child: _buildButton(
                    context,
                    icon: Icons.keyboard_arrow_up_rounded,
                    label: '上滚',
                    isPrimary: false,
                    borderRadius: BorderRadius.zero,
                    onPressed: () => _sendMouseScroll(0, -1, settings.hapticFeedback),
                  ),
                ),
                // 下滚轮按钮  
                Expanded(
                  child: _buildButton(
                    context,
                    icon: Icons.keyboard_arrow_down_rounded,
                    label: '下滚',
                    isPrimary: false,
                    borderRadius: BorderRadius.zero,
                    onPressed: () => _sendMouseScroll(0, 1, settings.hapticFeedback),
                  ),
                ),
              ],
            ),
          ),
          
          // 右键按钮
          Expanded(
            flex: 2,
            child: _buildButton(
              context,
              icon: Icons.more_vert_rounded,
              label: '右键',
              isPrimary: false,
              borderRadius: const BorderRadius.only(
                bottomRight: Radius.circular(20),
              ),
              onPressed: () => _sendMouseClick('right', settings.hapticFeedback),
            ),
          ),
        ],
      ),
    );
  }

  /// 直接分割空间的按钮样式
  Widget _buildButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isPrimary,
    required BorderRadius borderRadius,
    required VoidCallback onPressed,
  }) {
    // 滚轮按钮只显示图标，不显示文字
    bool isScrollButton = label.contains('滚');
    
    return Material(
      color: isPrimary 
        ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
        : Theme.of(context).colorScheme.surfaceContainer.withOpacity(0.5),
      borderRadius: borderRadius,
      child: InkWell(
        onTap: onPressed,
        borderRadius: borderRadius,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
              width: 0.5,
            ),
            borderRadius: borderRadius,
          ),
          child: isScrollButton 
            ? Center(
                // 滚轮按钮：只显示图标，居中
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                  size: 24,
                ),
              )
            : Column(
                // 左右键按钮：图标+文字
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    color: isPrimary 
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isPrimary 
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
        ),
      ),
    );
  }

  // 手势处理方法 - 使用指针事件以避免手势冲突
  void _handlePointerDown(PointerDownEvent event) {
    _isDragging = true;
  }

  void _handlePointerMove(PointerMoveEvent event, double sensitivity) {
    if (!_isDragging) return;

    double deltaX = event.delta.dx;
    double deltaY = event.delta.dy;

    // 应用基础灵敏度放大和用户设置
    double amplifiedDeltaX = deltaX * 2.0 * sensitivity;
    double amplifiedDeltaY = deltaY * 2.0 * sensitivity;

    _sendMouseMove(amplifiedDeltaX, amplifiedDeltaY);
  }

  void _handlePointerUp(PointerUpEvent event) {
    _isDragging = false;
  }

  // 保持原有的手势处理方法（兼容性）
  void _handlePanStart(DragStartDetails details) {
    _isDragging = true;
  }

  void _handlePanUpdate(DragUpdateDetails details, double sensitivity) {
    if (!_isDragging) return;

    double deltaX = details.delta.dx;
    double deltaY = details.delta.dy;

    // 应用基础灵敏度放大和用户设置
    double amplifiedDeltaX = deltaX * 2.0 * sensitivity;
    double amplifiedDeltaY = deltaY * 2.0 * sensitivity;

    _sendMouseMove(amplifiedDeltaX, amplifiedDeltaY);
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

  void _showSensitivityDialog(AppSettings settings) {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final currentSettings = ref.watch(settingsProvider);
          final settingsNotifier = ref.read(settingsProvider.notifier);
          
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text('灵敏度调节'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.speed_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${(currentSettings.mouseSensitivity * 100).round()}%',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Theme.of(context).colorScheme.primary,
                    inactiveTrackColor: Theme.of(context).colorScheme.surfaceContainer,
                    thumbColor: Theme.of(context).colorScheme.primary,
                    overlayColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    trackHeight: 6,
                  ),
                  child: Slider(
                    value: currentSettings.mouseSensitivity,
                    min: 0.1,
                    max: 2.0,
                    divisions: 19,
                    label: '${(currentSettings.mouseSensitivity * 100).round()}%',
                    onChanged: (value) {
                      settingsNotifier.updateMouseSensitivity(value);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '慢速 (10%)',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    Text(
                      '快速 (200%)',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('完成'),
              ),
            ],
          );
        },
      ),
    );
  }
}




