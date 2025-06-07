import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'screens/settings_screen.dart';

import 'services/log_service.dart';
import 'widgets/startup_widget.dart';
import 'screens/connect_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/touchpad_screen.dart';
import 'screens/files_screen.dart';
import 'screens/control_screen.dart';
import 'screens/computer_status_screen.dart';
import 'providers/connection_provider.dart';
import 'providers/file_provider.dart';
import 'services/socket_service.dart';

// 自定义转场页面类
class CustomTransitionPage<T> extends Page<T> {
  const CustomTransitionPage({
    required this.child,
    required this.transitionDuration,
    required this.transitionsBuilder,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  });

  final Widget child;
  final Duration transitionDuration;
  final Widget Function(BuildContext, Animation<double>, Animation<double>, Widget) transitionsBuilder;

  @override
  Route<T> createRoute(BuildContext context) {
    return PageRouteBuilder<T>(
      settings: this,
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionDuration: transitionDuration,
      transitionsBuilder: transitionsBuilder,
    );
  }
}

// 私有全局变量
final _rootNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // 确保Flutter绑定正确初始化
  WidgetsFlutterBinding.ensureInitialized();
  
  // 设置日志过滤器 - 默认隐藏UDP广播日志
  LogService.instance.enableQuietDiscoveryMode();
  LogService.instance.info('PalmController应用启动', category: 'App');
  
  runApp(
    const ProviderScope(
      child: PalmControllerApp(),
    ),
  );
}

class PalmControllerApp extends ConsumerWidget {
  const PalmControllerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Import settingsProvider from settings_screen.dart
    final settings = ref.watch(settingsProvider);
    
    return MaterialApp.router(
      title: '掌控者 - PalmController',
      debugShowCheckedModeBanner: false,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: settings.themeMode,
      routerConfig: _router,
      // 使用StartupWidget处理启动时的自动连接
      builder: (context, child) => StartupWidget(child: child ?? Container()),
    );
  }

  /// 构建浅色主题 - 现代化设计语言
  ThemeData _buildLightTheme() {
    const primaryColor = Color(0xFF1976D2); // 更温和的蓝色
    const surfaceColor = Color(0xFFFAFAFA); // 温和的背景色
    
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        surface: surfaceColor,
      ),
      useMaterial3: true,
      
      // AppBar 现代化设计
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: Colors.transparent,
        foregroundColor: primaryColor,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: primaryColor,
        ),
        iconTheme: const IconThemeData(
          color: primaryColor,
          size: 24,
        ),
      ),
      
      // Card 现代化设计
      cardTheme: CardTheme(
        elevation: 0,
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      ),
      
      // 按钮现代化设计
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // 文本按钮设计
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      
      // 输入框现代化设计
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      
      // Chip 现代化设计
      chipTheme: ChipThemeData(
        backgroundColor: surfaceColor,
        selectedColor: primaryColor.withAlpha((0.1 * 255).round()),
        side: BorderSide(color: Colors.grey.shade300),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      
      // 分割线设计
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade200,
        thickness: 1,
        space: 1,
      ),
    );
  }

  /// 构建深色主题 - 现代化设计语言
  ThemeData _buildDarkTheme() {
    const primaryColor = Color(0xFF64B5F6); // 适合深色的蓝色
    const surfaceColor = Color(0xFF1E1E1E); // 深色背景
    const cardColor = Color(0xFF2D2D2D); // 卡片背景
    
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
        surface: surfaceColor,
      ),
      useMaterial3: true,
      
      // AppBar 深色设计
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: Colors.transparent,
        foregroundColor: primaryColor,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: primaryColor,
        ),
        iconTheme: const IconThemeData(
          color: primaryColor,
          size: 24,
        ),
      ),
      
      // Card 深色设计
      cardTheme: CardTheme(
        elevation: 0,
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Colors.grey.shade700,
            width: 1,
          ),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      ),
      
      // 按钮深色设计
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // 文本按钮深色设计
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      
      // 输入框深色设计
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade600),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade600),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      
      // Chip 深色设计
      chipTheme: ChipThemeData(
        backgroundColor: cardColor,
        selectedColor: primaryColor.withAlpha((0.1 * 255).round()),
        side: BorderSide(color: Colors.grey.shade600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      
      // 分割线深色设计
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade700,
        thickness: 1,
        space: 1,
      ),
    );
  }
}

final GoRouter _router = GoRouter(
  initialLocation: '/dashboard',
  navigatorKey: _rootNavigatorKey,
  // 添加错误处理
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('路由错误: ${state.error}'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              if (context.mounted) {
                context.go('/dashboard');
              }
            },
            child: const Text('返回主页'),
          ),
        ],
      ),
    ),
  ),
  routes: [
    // 主应用路由 - 移除ShellRoute，使用简单的GoRoute架构
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const MainScaffoldWrapper(pageIndex: 0),
    ),
    GoRoute(
      path: '/touchpad',
      builder: (context, state) => const MainScaffoldWrapper(pageIndex: 1),
    ),
    GoRoute(
      path: '/files',
      builder: (context, state) => const MainScaffoldWrapper(pageIndex: 2),
    ),
    GoRoute(
      path: '/media',
      builder: (context, state) => const MainScaffoldWrapper(pageIndex: 3),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const MainScaffoldWrapper(pageIndex: 4),
    ),
    GoRoute(
      path: '/connect',
      builder: (context, state) => const MainScaffoldWrapper(pageIndex: 0, isConnected: false),
    ),
    // 独立全屏路由 - 电脑状态页面
    GoRoute(
      path: '/computer-status',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const ComputerStatusScreen(),
        transitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: animation.drive(
              Tween(begin: const Offset(1.0, 0.0), end: Offset.zero).chain(
                CurveTween(curve: Curves.easeInOut),
              ),
            ),
            child: child,
          );
        },
      ),
    ),
  ],
);

// 简化的包装器，用于适配新的路由架构
class MainScaffoldWrapper extends ConsumerWidget {
  final int pageIndex;
  final bool isConnected;

  const MainScaffoldWrapper({
    super.key,
    required this.pageIndex,
    this.isConnected = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionStatus = ref.watch(connectionStatusProvider);
    
    // 根据实际连接状态决定显示哪个页面
    final actuallyConnected = connectionStatus == ConnectionStatus.connected;
    
    // 添加返回键处理，防止意外退出应用
    return PopScope(
      canPop: false, // 禁止默认的返回行为
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        
        // 特殊处理文件管理页面的返回逻辑
        if (actuallyConnected && pageIndex == 2) { // 文件管理页面
          _handleFilesPageBack(context, ref);
          return;
        }
        
        // 其他页面的返回逻辑：导航到主页
        if (actuallyConnected) {
          if (pageIndex != 0) {
            // 如果不在主页，返回到主页
            context.go('/dashboard');
          } else {
            // 如果已经在主页，显示退出确认
            _showExitConfirmation(context);
          }
        } else {
          // 未连接状态，如果不在连接页面，返回连接页面
          if (pageIndex != 0) {
            context.go('/connect');
          } else {
            // 如果已经在连接页面，显示退出确认
            _showExitConfirmation(context);
          }
        }
      },
      child: _buildScaffold(context, ref, actuallyConnected),
    );
  }

  Widget _buildScaffold(BuildContext context, WidgetRef ref, bool actuallyConnected) {
    if (actuallyConnected) {
      // 已连接状态的页面
      final pages = [
        const DashboardScreen(),    // 0
        const TouchpadScreen(),     // 1
        const FilesScreen(),        // 2
        const ControlScreen(),      // 3
        const SettingsScreen(),     // 4
      ];
      
      final safeIndex = pageIndex < pages.length ? pageIndex : 0;
      return Scaffold(
        body: pages[safeIndex],
        bottomNavigationBar: _ConnectedBottomNavBar(currentIndex: safeIndex),
      );
    } else {
      // 未连接状态的页面
      final pages = [
        const ConnectScreen(),      // 0
        const SettingsScreen(),     // 1
      ];
      
      final safeIndex = pageIndex < pages.length ? pageIndex : 0;
      return Scaffold(
        body: pages[safeIndex],
        bottomNavigationBar: _DisconnectedBottomNavBar(currentIndex: safeIndex),
      );
    }
  }

  void _showExitConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出应用'),
        content: const Text('确定要退出掌控者吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // 退出应用 - 使用系统的退出方法
              // 在Android上，这会将应用移到后台
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }

  // 处理文件管理页面的返回逻辑
  void _handleFilesPageBack(BuildContext context, WidgetRef ref) {
    // 检查是否有目录历史可以返回
    final directoryHistory = ref.read(directoryHistoryProvider);
    final currentDirectory = ref.read(currentDirectoryProvider);
    
    // 如果在子目录中，先返回上一级文件夹
    if (directoryHistory.isNotEmpty || currentDirectory != null) {
      ref.read(fileListProvider.notifier).goBack();
    } else {
      // 如果已经在根目录，返回到主页
      context.go('/dashboard');
    }
  }
}

// 已连接状态的底部导航栏
class _ConnectedBottomNavBar extends StatelessWidget {
  final int currentIndex;

  const _ConnectedBottomNavBar({required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) {
        switch (index) {
          case 0:
            context.go('/dashboard');
            break;
          case 1:
            context.go('/touchpad');
            break;
          case 2:
            context.go('/files');
            break;
          case 3:
            context.go('/media');
            break;
          case 4:
            context.go('/settings');
            break;
        }
      },
      type: BottomNavigationBarType.fixed,
      backgroundColor: Theme.of(context).colorScheme.surface,
      selectedItemColor: Theme.of(context).colorScheme.primary,
      unselectedItemColor: Colors.grey,
      elevation: 0,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: '主页'),
        BottomNavigationBarItem(icon: Icon(Icons.touch_app_rounded), label: '触控板'),
        BottomNavigationBarItem(icon: Icon(Icons.folder_open_rounded), label: '文件'),
        BottomNavigationBarItem(icon: Icon(Icons.music_note_rounded), label: '媒体'),
        BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: '设置'),
      ],
    );
  }
}

// 未连接状态的底部导航栏
class _DisconnectedBottomNavBar extends StatelessWidget {
  final int currentIndex;

  const _DisconnectedBottomNavBar({required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) {
        switch (index) {
          case 0:
            context.go('/connect');
            break;
          case 1:
            context.go('/settings');
            break;
        }
      },
      backgroundColor: Theme.of(context).colorScheme.surface,
      selectedItemColor: Theme.of(context).colorScheme.primary,
      unselectedItemColor: Colors.grey,
      elevation: 0,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.link_rounded), label: '连接'),
        BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: '设置'),
      ],
    );
  }
}

