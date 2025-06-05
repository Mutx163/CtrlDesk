import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/connection_provider.dart';
import '../services/socket_service.dart';

// 当前导航索引Provider
final navigationIndexProvider = StateProvider<int>((ref) => 0);

// PageController Provider - 用于页面滑动控制
final pageControllerProvider = Provider<PageController?>((ref) => null);

// 动态智能导航栏组件
class BottomNavigationBarWidget extends ConsumerWidget {
  const BottomNavigationBarWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionStatus = ref.watch(connectionStatusProvider);
    final currentIndex = ref.watch(navigationIndexProvider);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.elasticOut,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: connectionStatus == ConnectionStatus.connected
              ? _buildConnectedNavigation(context, ref, currentIndex)
              : _buildDisconnectedNavigation(context, ref, currentIndex),
        ),
      ),
    );
  }

  /// 已连接状态：4栏导航 (媒体、触摸、键盘、工具)
  Widget _buildConnectedNavigation(BuildContext context, WidgetRef ref, int currentIndex) {
    final navItems = [
      _NavItem(
        icon: Icons.music_note_rounded,
        activeIcon: Icons.music_note,
        label: '媒体',
        route: '/control',
        color: const Color(0xFFE91E63), // 媒体-玫红
      ),
      _NavItem(
        icon: Icons.touch_app_outlined,
        activeIcon: Icons.touch_app_rounded,
        label: '触摸',
        route: '/touchpad',
        color: const Color(0xFF9C27B0), // 触摸-紫色
      ),
      _NavItem(
        icon: Icons.keyboard_outlined,
        activeIcon: Icons.keyboard_rounded,
        label: '键盘',
        route: '/keyboard',
        color: const Color(0xFF3F51B5), // 键盘-靛蓝
      ),
      _NavItem(
        icon: Icons.build_outlined,
        activeIcon: Icons.build_rounded,
        label: '工具',
        route: '/tools',
        color: const Color(0xFFFF9800), // 工具-橙色
      ),
    ];

    return Row(
      children: navItems.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final isSelected = currentIndex == index;

        return Expanded(
          child: _buildNavItemWidget(
            context,
            ref,
            index,
            item,
            isSelected,
          ),
        );
      }).toList(),
    );
  }

  /// 未连接状态：2栏导航 (连接、设置)
  Widget _buildDisconnectedNavigation(BuildContext context, WidgetRef ref, int currentIndex) {
    final connectionStatus = ref.watch(connectionStatusProvider);
    
    final navItems = [
      _NavItem(
        icon: connectionStatus == ConnectionStatus.connecting 
            ? Icons.wifi_find_outlined 
            : Icons.wifi_off_outlined,
        activeIcon: connectionStatus == ConnectionStatus.connecting
            ? Icons.wifi_find_rounded
            : Icons.wifi_outlined,
        label: connectionStatus == ConnectionStatus.connecting ? '连接中' : '智能连接',
        route: '/connect',
        color: connectionStatus == ConnectionStatus.connecting 
            ? const Color(0xFFFF9800) // 连接中-橙色
            : const Color(0xFF4CAF50), // 连接-绿色
        hasIndicator: connectionStatus == ConnectionStatus.connecting,
      ),
      _NavItem(
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings_rounded,
        label: '应用设置',
        route: '/settings',
        color: const Color(0xFF607D8B), // 设置-蓝灰
      ),
    ];

    return Row(
      children: navItems.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final isSelected = currentIndex == index;

        return Expanded(
          child: _buildNavItemWidget(
            context,
            ref,
            index,
            item,
            isSelected,
          ),
        );
      }).toList(),
    );
  }

     /// 构建导航项组件
   Widget _buildNavItemWidget(
     BuildContext context,
     WidgetRef ref,
     int index,
     _NavItem item,
     bool isSelected,
   ) {
     return Material(
       color: Colors.transparent,
       child: InkWell(
         onTap: () {
           // 尝试使用PageController进行滑动切换
           final pageController = ref.read(pageControllerProvider);
           if (pageController != null) {
             // 使用路由到页面索引的映射，而不是导航数组索引
             final pageIndex = _routeToPageIndex(item.route);
             pageController.animateToPage(
               pageIndex,
               duration: const Duration(milliseconds: 300),
               curve: Curves.easeInOut,
             );
             // 更新导航索引以保持UI高亮正确
             ref.read(navigationIndexProvider.notifier).state = index;
           } else {
             // 回退到路由切换（兼容性）
             final routeToIndexMap = {
               '/control': 0,
               '/touchpad': 1,  
               '/keyboard': 2,
               '/screenshot': 3,
               '/monitor': 4,
               '/tools': 5,
               '/connect': 0, // 未连接状态的连接页面
               '/settings': 1, // 未连接状态的设置页面
             };
             final navIndex = routeToIndexMap[item.route] ?? 0;
             ref.read(navigationIndexProvider.notifier).state = navIndex;
             context.go(item.route);
           }
         },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected 
                ? item.color.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 图标区域
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      isSelected ? item.activeIcon : item.icon,
                      size: isSelected ? 28 : 24,
                      color: isSelected 
                          ? item.color
                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // 标签文字
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected 
                          ? item.color
                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              
              // 状态指示器 (连接中动画)
              if (item.hasIndicator)
                Positioned(
                  right: 8,
                  top: 8,
                  child: _buildPulsingIndicator(item.color),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建脉冲指示器 (连接中状态)
  Widget _buildPulsingIndicator(Color color) {
    return _PulsingDot(color: color);
  }

  /// 将路由转换为实际的页面索引
  int _routeToPageIndex(String route) {
    // 这个映射应该与MainScaffold中的_getPagesForConnectionStatus保持一致
    const routeToPageIndexMap = {
      // 连接状态下的页面映射
      '/control': 0,       // ControlScreen
      '/touchpad': 1,      // TouchpadScreen  
      '/keyboard': 2,      // KeyboardScreen
      '/screenshot': 3,    // ScreenshotScreen
      '/monitor': 4,       // MonitorScreen
      '/tools': 5,         // ToolsScreen
      
      // 未连接状态下的页面映射
      '/connect': 0,       // ConnectScreen
      '/settings': 1,      // SettingsScreen
    };
    
    return routeToPageIndexMap[route] ?? 0;
  }
}

/// 脉冲动画组件
class _PulsingDot extends StatefulWidget {
  final Color color;

  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.8 + (_animation.value * 0.4),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.4),
                  blurRadius: 4 * _animation.value,
                  spreadRadius: 2 * _animation.value,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 导航项数据模型
class _NavItem {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
    required this.color,
    this.hasIndicator = false,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;
  final Color color;
  final bool hasIndicator;
} 