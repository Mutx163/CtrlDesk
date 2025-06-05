import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auto_connect_service.dart';
import '../services/log_service.dart';

// AutoConnectService Provider
final autoConnectServiceProvider = Provider<AutoConnectService>((ref) {
  return AutoConnectService();
});

class AutoConnectWidget extends ConsumerStatefulWidget {
  final Widget child;
  
  const AutoConnectWidget({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<AutoConnectWidget> createState() => _AutoConnectWidgetState();
}

class _AutoConnectWidgetState extends ConsumerState<AutoConnectWidget> {
  bool _autoConnectStarted = false;

  @override
  void initState() {
    super.initState();
    // 使用最延迟的方式启动自动连接，确保UI完全加载
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _startAutoConnectInBackground();
      }
    });
  }

  void _startAutoConnectInBackground() {
    if (_autoConnectStarted) return;
    _autoConnectStarted = true;
    
    // 在独立的isolate中运行，完全不阻塞UI
    Future(() async {
      try {
        final autoConnectService = ref.read(autoConnectServiceProvider);
        LogService.instance.info('后台启动自动连接', category: 'App');
        
        // 设置超时，避免无限等�?
        final result = await autoConnectService.startAutoConnect()
            .timeout(const Duration(seconds: 30));
        
        LogService.instance.info('自动连接完成: $result', category: 'App');
      } catch (e) {
        LogService.instance.warning('自动连接超时或失�? $e', category: 'App');
      }
    });
  }

  @override
  void dispose() {
    // 清理资源，但不等�?
    if (_autoConnectStarted) {
      try {
        final autoConnectService = ref.read(autoConnectServiceProvider);
        autoConnectService.dispose();
      } catch (e) {
        // 忽略dispose错误
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 永远直接返回子组件，不添加任何可能阻塞的逻辑
    return widget.child;
  }
} 
