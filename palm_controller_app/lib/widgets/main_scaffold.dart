import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/control_screen.dart';
import '../screens/touchpad_screen.dart';
import '../screens/keyboard_screen.dart';
import '../screens/screenshot_screen.dart';
import '../screens/monitor_screen.dart';
import '../screens/system_screen.dart';
import '../screens/connect_screen.dart';
import 'bottom_navigation_bar.dart';

class MainScaffold extends ConsumerWidget {
  final int pageIndex;

  const MainScaffold({
    super.key,
    required this.pageIndex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 同步导航索引
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(navigationIndexProvider.notifier).state = pageIndex;
    });

    return Scaffold(
      body: _getPageForIndex(pageIndex),
      bottomNavigationBar: const BottomNavigationBarWidget(),
    );
  }

  Widget _getPageForIndex(int index) {
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
        return const SystemScreen();
      case 6:
        return const ConnectScreen();
      default:
        return const ControlScreen();
    }
  }
} 