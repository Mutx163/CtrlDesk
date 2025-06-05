import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/connection_provider.dart';
import '../services/socket_service.dart';

// 当前导航索引Provider
final navigationIndexProvider = StateProvider<int>((ref) => 0);

// 更多菜单展开状态Provider
final moreMenuExpandedProvider = StateProvider<bool>((ref) => false);

class BottomNavigationBarWidget extends ConsumerWidget {
  const BottomNavigationBarWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(navigationIndexProvider);
    final connectionStatus = ref.watch(connectionStatusProvider);
    final isMoreExpanded = ref.watch(moreMenuExpandedProvider);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 主导航栏
            SizedBox(
              height: 80,
              child: Row(
                children: [
                  // 主页
                  _buildNavItem(
                    context,
                    ref,
                    0,
                    Icons.home_rounded,
                    '主页',
                    '/control',
                    hasIndicator: connectionStatus == ConnectionStatus.connected,
                  ),
                  // 触摸板
                  _buildNavItem(
                    context,
                    ref,
                    1,
                    Icons.touch_app_rounded,
                    '触摸板',
                    '/touchpad',
                  ),
                  // 键盘
                  _buildNavItem(
                    context,
                    ref,
                    2,
                    Icons.keyboard_rounded,
                    '键盘',
                    '/keyboard',
                  ),
                  // 截图
                  _buildNavItem(
                    context,
                    ref,
                    3,
                    Icons.camera_alt_rounded,
                    '截图',
                    '/screenshot',
                  ),
                  // 监控
                  _buildNavItem(
                    context,
                    ref,
                    4,
                    Icons.monitor_heart_rounded,
                    '监控',
                    '/monitor',
                  ),
                  // 更多按钮
                  _buildMoreButton(context, ref),
                ],
              ),
            ),
            
            // 展开的更多菜单
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: isMoreExpanded ? 80 : 0,
              child: isMoreExpanded
                  ? Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        border: Border(
                          top: BorderSide(
                            color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          // 系统
                          _buildNavItem(
                            context,
                            ref,
                            5,
                            Icons.settings_power_rounded,
                            '系统',
                            '/system',
                          ),
                          // 连接
                          _buildNavItem(
                            context,
                            ref,
                            6,
                            connectionStatus == ConnectionStatus.connected 
                                ? Icons.wifi_rounded 
                                : Icons.wifi_off_rounded,
                            '连接',
                            '/connect',
                            hasIndicator: connectionStatus == ConnectionStatus.connecting,
                          ),
                          // 空白占位
                          Expanded(child: Container()),
                          Expanded(child: Container()),
                          // 关闭按钮
                          _buildCloseButton(context, ref),
                        ],
                      ),
                    )
                  : Container(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    WidgetRef ref,
    int index,
    IconData icon,
    String label,
    String route, {
    bool hasIndicator = false,
  }) {
    final currentIndex = ref.watch(navigationIndexProvider);
    final isSelected = currentIndex == index;
    final colorScheme = Theme.of(context).colorScheme;

    // 根据功能模块定义颜色
    Color getItemColor() {
      switch (index) {
        case 0: return const Color(0xFF1976D2); // 主页 - 蓝色
        case 1: return const Color(0xFF7B1FA2); // 触摸板 - 紫色
        case 2: return const Color(0xFF388E3C); // 键盘 - 绿色
        case 3: return const Color(0xFFF57C00); // 截图 - 橙色
        case 4: return const Color(0xFFD32F2F); // 监控 - 红色
        case 5: return const Color(0xFF5D4037); // 系统 - 灰色
        case 6: return const Color(0xFF00796B); // 连接 - 青色
        default: return colorScheme.primary;
      }
    }

    final itemColor = getItemColor();

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            ref.read(navigationIndexProvider.notifier).state = index;
            ref.read(moreMenuExpandedProvider.notifier).state = false;
            context.go(route);
          },
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? itemColor.withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 24,
                    color: isSelected 
                        ? itemColor
                        : colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                // 状态指示器
                if (hasIndicator)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: index == 0 ? Colors.green : Colors.orange,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.surface,
                          width: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMoreButton(BuildContext context, WidgetRef ref) {
    final isExpanded = ref.watch(moreMenuExpandedProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            ref.read(moreMenuExpandedProvider.notifier).state = !isExpanded;
          },
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isExpanded 
                    ? colorScheme.primary.withOpacity(0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: AnimatedRotation(
                turns: isExpanded ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.more_horiz_rounded,
                  size: 24,
                  color: isExpanded 
                      ? colorScheme.primary
                      : colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCloseButton(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            ref.read(moreMenuExpandedProvider.notifier).state = false;
          },
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.close_rounded,
                size: 24,
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
        ),
      ),
    );
  }
} 