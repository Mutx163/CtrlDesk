import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/control_screen.dart';
import '../screens/touchpad_screen.dart';
import '../screens/keyboard_screen.dart';
import '../screens/screenshot_screen.dart';
import '../screens/monitor_screen.dart';
import '../screens/tools_screen.dart';
import '../screens/system_screen.dart';
import '../screens/connect_screen.dart';
import '../screens/settings_screen.dart';
import '../providers/connection_provider.dart';
import '../services/socket_service.dart';
import 'bottom_navigation_bar.dart';

class MainScaffold extends ConsumerStatefulWidget {
  final int pageIndex;

  const MainScaffold({
    super.key,
    required this.pageIndex,
  });

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  late PageController _pageController;
  int _currentPageIndex = 0;

  @override
  void initState() {
    super.initState();
    // 验证 initialPage 不超过当前页面列表长度，防止深链接时�?RangeError
    _currentPageIndex = math.min(
      widget.pageIndex,
      _getPagesForConnectionStatus(ref.read(connectionStatusProvider)).length - 1,
    );
    _pageController = PageController(initialPage: _currentPageIndex);
  }

  @override
  void didUpdateWidget(MainScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当外部传入的pageIndex发生变化时，更新PageView
    if (widget.pageIndex != oldWidget.pageIndex) {
      _currentPageIndex = widget.pageIndex;
      _pageController.animateToPage(
        _currentPageIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectionStatus = ref.watch(connectionStatusProvider);
    
    // 同步导航索引
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(navigationIndexProvider.notifier).state = _currentPageIndex;
    });

    return ProviderScope(
      overrides: [
        pageControllerProvider.overrideWithValue(_pageController),
      ],
      child: Scaffold(
        body: PageView(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() {
              _currentPageIndex = index;
            });
            
            // 更新导航索引
            ref.read(navigationIndexProvider.notifier).state = index;
            
            // 更新路由（但不影响当前页面显示）
            _updateRouteForIndex(index, connectionStatus);
          },
          children: _getPagesForConnectionStatus(connectionStatus),
        ),
        bottomNavigationBar: const BottomNavigationBarWidget(),
      ),
    );
  }

  /// 根据连接状态获取页面列�?  List<Widget> _getPagesForConnectionStatus(ConnectionStatus connectionStatus) {
    if (connectionStatus == ConnectionStatus.connected) {
      // 已连接状态：6个页面（媒体、触摸、键盘、截图、监控、工具）
      return [
        const ControlScreen(),      // 0 - 媒体控制
        const TouchpadScreen(),     // 1 - 触摸�?        const KeyboardScreen(),     // 2 - 键盘
        const ScreenshotScreen(),   // 3 - 截图
        const MonitorScreen(),      // 4 - 监控
        const ToolsScreen(),        // 5 - 工具
      ];
    } else {
      // 未连接状态：2个页面（连接、设置）
      return [
        const ConnectScreen(),      // 0 - 智能连接
        const SettingsScreen(),     // 1 - 应用设置
      ];
    }
  }

  /// 更新路由以保持URL同步
  void _updateRouteForIndex(int index, ConnectionStatus connectionStatus) {
    // 这里不直接使用context.go()避免重新构建整个页面
    // 仅在需要时更新浏览器URL
    String newRoute;
    
    if (connectionStatus == ConnectionStatus.connected) {
      switch (index) {
        case 0:
          newRoute = '/control';
          break;
        case 1:
          newRoute = '/touchpad';
          break;
        case 2:
          newRoute = '/keyboard';
          break;
        case 3:
          newRoute = '/screenshot';
          break;
        case 4:
          newRoute = '/monitor';
          break;
        case 5:
          newRoute = '/tools';
          break;
        default:
          newRoute = '/control';
      }
    } else {
      switch (index) {
        case 0:
          newRoute = '/connect';
          break;
        case 1:
          newRoute = '/settings';
          break;
        default:
          newRoute = '/connect';
      }
    }
    
    // 可以在这里添加路由历史记录更新逻辑
    // 但为了避免重复构建，暂时注释�?    // context.go(newRoute);
  }

  /// 兼容性方法：根据索引获取页面（保留原有逻辑�?  Widget _getPageForIndex(int index) {
    switch (index) {
      case 0:
        return const ControlScreen();
      case 1:
        return const TouchpadScreen();
      case 2:
        return const KeyboardScreen();
      case 3:
        return const ScreenshotScreen();
      case 4:
        return const MonitorScreen();
      case 5:
        return const ToolsScreen();
      case 6:
        return const SystemScreen();
      case 7:
        return const ConnectScreen();
      default:
        return const ControlScreen();
    }
  }
} 
