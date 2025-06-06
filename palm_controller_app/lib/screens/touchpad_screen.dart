import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connection_provider.dart';
import '../widgets/touchpad_widget.dart';
import '../services/socket_service.dart';

class TouchpadScreen extends ConsumerWidget {
  const TouchpadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionStatus = ref.watch(connectionStatusProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: connectionStatus == ConnectionStatus.connected
            ? _buildTouchpadController(context, ref)
          : _buildNotConnectedView(context),
      ),
    );
  }

  // 使用我们原来优秀的TouchpadWidget + 保持设计风格
  Widget _buildTouchpadController(BuildContext context, WidgetRef ref) {
    // Colors from trackpad.html Tailwind CSS
    const bgColor = Color(0xFFF3F4F6); // bg-gray-100
    const buttonBgColor = Color(0xFFF9FAFB); // bg-gray-50
    const dividerColor = Color(0xFFE5E7EB); // bg-gray-200
    const headerTextColor = Color(0xFF111827); // text-gray-900

    return Column(
              children: [
        // Header - 我们原来的设计
        Container(
          padding: const EdgeInsets.only(top: 16.0, bottom: 16.0, left: 24.0, right: 24.0),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: dividerColor, width: 1)),
            ),
          child: const Center(
            child: Text(
              '触控板',
                  style: TextStyle(
                fontSize: 20, // text-xl
                fontWeight: FontWeight.w600, // font-semibold
                color: headerTextColor,
          ),
            ),
          ),
            ),
        
        // 使用我们原来优秀的TouchpadWidget
        const Expanded(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: TouchpadWidget(),
          ),
        ),
      ],
    );
  }

  Widget _buildNotConnectedView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.signal_wifi_off_rounded,
            size: 80,
            color: Theme.of(context).colorScheme.onSurface.withAlpha(128),
          ),
          const SizedBox(height: 24),
          Text(
            '未连接到任何设备',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            '请先从主页连接到您的PC',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(178),
            ),
          ),
        ],
      ),
    );
  }
} 



