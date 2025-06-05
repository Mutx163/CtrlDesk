import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/control_screen.dart';
import '../screens/touchpad_screen.dart';
import '../screens/keyboard_screen.dart';
import '../screens/screenshot_screen.dart';
import '../screens/monitor_screen.dart';
import '../screens/tools_screen.dart';

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
    // 验证 initialPage 不超过当前页面列表长度，防止深链接时的 RangeError
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

  /// 根据连接状态获取页面列表
  List<Widget> _getPagesForConnectionStatus(ConnectionStatus connectionStatus) {
    if (connectionStatus == ConnectionStatus.connected) {
      // 已连接状态：6个页面（媒体、触摸、键盘、截图、监控、工具）
      return [
        const ControlScreen(),      // 0 - 媒体控制
        const TouchpadScreen(),     // 1 - 触摸板
        const KeyboardScreen(),     // 2 - 键盘
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

  /// 更新路由以保持URL同步（暂时禁用以避免重复构建）
  void _updateRouteForIndex(int index, ConnectionStatus connectionStatus) {
    // TODO: 路由历史记录更新功能
    // 暂时注释掉以避免重复构建页面
    // 可以在未来版本中根据需要启用
  }


} 