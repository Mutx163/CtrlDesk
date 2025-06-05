import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'screens/settings_screen.dart';
import 'widgets/main_scaffold.dart';
import 'services/log_service.dart';
import 'widgets/startup_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 应用启动日志（日志服务会自动处理初始化状态）
  LogService.instance.info('PalmController App启动', category: 'App');
  
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
      title: '掌控�?- PalmController',
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
      
      // AppBar 现代化设�?      appBarTheme: AppBarTheme(
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
      
      // Card 现代化设�?      cardTheme: CardTheme(
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
      
      // 按钮现代化设�?      filledButtonTheme: FilledButtonThemeData(
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
      
      // Chip 现代化设�?      chipTheme: ChipThemeData(
        backgroundColor: surfaceColor,
        selectedColor: primaryColor.withValues(alpha: 0.1),
        side: BorderSide(color: Colors.grey.shade300),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      
      // 分割线设�?      dividerTheme: DividerThemeData(
        color: Colors.grey.shade200,
        thickness: 1,
        space: 1,
      ),
    );
  }

  /// 构建深色主题 - 现代化设计语言
  ThemeData _buildDarkTheme() {
    const primaryColor = Color(0xFF64B5F6); // 适合深色的蓝�?    const surfaceColor = Color(0xFF1E1E1E); // 深色背景
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
      
      // 输入框深色设�?      inputDecorationTheme: InputDecorationTheme(
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
        selectedColor: primaryColor.withValues(alpha: 0.2),
        side: BorderSide(color: Colors.grey.shade600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      
      // 分割线深色设�?      dividerTheme: DividerThemeData(
        color: Colors.grey.shade700,
        thickness: 1,
        space: 1,
      ),
    );
  }
}

// 路由配置
final GoRouter _router = GoRouter(
  initialLocation: '/control',
  routes: [
    GoRoute(
      path: '/control',
      name: 'control',
      builder: (context, state) => const MainScaffold(pageIndex: 0),
    ),
    GoRoute(
      path: '/touchpad',
      name: 'touchpad', 
      builder: (context, state) => const MainScaffold(pageIndex: 1),
    ),
    GoRoute(
      path: '/keyboard',
      name: 'keyboard',
      builder: (context, state) => const MainScaffold(pageIndex: 2),
    ),
    GoRoute(
      path: '/screenshot',
      name: 'screenshot',
      builder: (context, state) => const MainScaffold(pageIndex: 3),
    ),
    GoRoute(
      path: '/monitor',
      name: 'monitor',
      builder: (context, state) => const MainScaffold(pageIndex: 4),
    ),
    GoRoute(
      path: '/tools',
      name: 'tools',
      builder: (context, state) => const MainScaffold(pageIndex: 5),
    ),
    GoRoute(
      path: '/connect',
      name: 'connect',
      builder: (context, state) => const MainScaffold(pageIndex: 0),
    ),
    // 设置页面独立，不包含底部导航�?    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(
      title: const Text('页面未找�?),
    ),
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            '页面未找�?,
            style: TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            '无法找到路径: ${state.uri}',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.go('/control'),
            child: const Text('返回主页'),
          ),
        ],
      ),
    ),
  ),
);
