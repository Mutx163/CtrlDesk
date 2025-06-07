import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../screens/dashboard_screen.dart';
import '../screens/touchpad_screen.dart';
import '../screens/files_screen.dart';
import '../screens/control_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/connect_screen.dart';
import '../providers/connection_provider.dart';
import '../services/socket_service.dart';

// 简单实现一个新的BottomNavBar，后续可以替换为原来的文件
class BottomNavigationBarWidget extends ConsumerWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNavigationBarWidget({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final connectionStatus = ref.watch(connectionStatusProvider);

    final items = connectionStatus == ConnectionStatus.connected
        ? _buildConnectedItems(context)
        : _buildDisconnectedItems(context);

    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      backgroundColor: theme.colorScheme.surface,
      selectedItemColor: theme.colorScheme.primary,
      unselectedItemColor: Colors.grey,
      elevation: 0,
      items: items,
    );
  }

  List<BottomNavigationBarItem> _buildConnectedItems(BuildContext context) {
    return const [
      BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: '主页'),
      BottomNavigationBarItem(icon: FaIcon(FontAwesomeIcons.handPointer), label: '触控板'),
      BottomNavigationBarItem(icon: Icon(Icons.folder_open_rounded), label: '文件'),
      BottomNavigationBarItem(icon: Icon(Icons.music_note_rounded), label: '媒体'),
      BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: '设置'),
    ];
  }

  List<BottomNavigationBarItem> _buildDisconnectedItems(BuildContext context) {
    return const [
      BottomNavigationBarItem(icon: Icon(Icons.link_rounded), label: '连接'),
      BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: '设置'),
    ];
  }
}


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
    _updateAndInitializeController();
  }
  
  void _updateAndInitializeController() {
    final pages = _getPagesForConnectionStatus(ref.read(connectionStatusProvider));
    // 确保初始索引在合法范围内
    int initialPage = math.min(widget.pageIndex, pages.length - 1);
    
    // 如果当前索引也超出了范围（可能在状态改变后发生），重置它
    if (_currentPageIndex >= pages.length) {
       _currentPageIndex = 0;
       initialPage = 0;
    } else {
       _currentPageIndex = initialPage;
    }

    _pageController = PageController(initialPage: initialPage);
  }


  @override
  void didUpdateWidget(MainScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pageIndex != oldWidget.pageIndex) {
      final pages = _getPagesForConnectionStatus(ref.read(connectionStatusProvider));
      if (widget.pageIndex < pages.length) {
        _currentPageIndex = widget.pageIndex;
        _pageController.animateToPage(
          _currentPageIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    // 先检查索引是否有效
    final pages = _getPagesForConnectionStatus(ref.read(connectionStatusProvider));
    if (index >= 0 && index < pages.length) {
      _pageController.jumpToPage(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ConnectionStatus>(connectionStatusProvider, (previous, next) {
      if (previous != next) {
        // 连接状态发生变化，我们需要重新构建PageView并确保索引安全
        // 关键：在下一次build之前，就要准备好新的controller和索引
        setState(() {
          _updateAndInitializeController();
        });
        
        // 如果状态发生了变化，安全地导航到合适的页面
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            final newPages = _getPagesForConnectionStatus(next);
            if (_currentPageIndex >= newPages.length) {
              _currentPageIndex = 0;
              _pageController.jumpToPage(0);
            }
          }
        });
      }
    });

    final pages = _getPagesForConnectionStatus(ref.watch(connectionStatusProvider));
    
    // 再次进行安全检查，作为最后一道防线
    if (_currentPageIndex >= pages.length) {
      _currentPageIndex = 0;
    }

    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), // 禁用滑动手势，只允许通过底部导航切换
        onPageChanged: (index) {
          setState(() {
            _currentPageIndex = index;
          });
          // 可以在这里更新路由，如果需要的话
        },
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBarWidget(
        currentIndex: _currentPageIndex,
        onTap: _onItemTapped,
      ),
    );
  }

  List<Widget> _getPagesForConnectionStatus(ConnectionStatus connectionStatus) {
    if (connectionStatus == ConnectionStatus.connected) {
      return [
        const DashboardScreen(),    // 0 - 主页
        const TouchpadScreen(),     // 1 - 触控板
        const FilesScreen(),        // 2 - 文件
        const ControlScreen(),      // 3 - 媒体
        const SettingsScreen(),     // 4 - 设置
      ];
    } else {
      return [
        const ConnectScreen(),      // 0 - 连接
        const SettingsScreen(),     // 1 - 设置
      ];
    }
  }
} 
