import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/startup_service.dart';
import '../services/log_service.dart';

class StartupWidget extends ConsumerStatefulWidget {
  final Widget child;
  
  const StartupWidget({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<StartupWidget> createState() => _StartupWidgetState();
}

class _StartupWidgetState extends ConsumerState<StartupWidget> {
  bool _isInitializing = true;
  String _statusMessage = '正在启动...';
  bool _showStartupScreen = true;

  @override
  void initState() {
    super.initState();
    _performStartupSequence();
  }

  Future<void> _performStartupSequence() async {
    try {
      // 显示启动画面
      setState(() {
        _statusMessage = '正在启动应用...';
      });
      
      // 短暂延迟确保UI初始化完成
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 检查是否有历史连接配置
      final startupService = ref.read(startupServiceProvider);
      final recentConnection = await startupService.getRecentConnection(ref);
      
      if (recentConnection != null) {
        setState(() {
          _statusMessage = '正在连接到 ${recentConnection.name}...';
        });
        
        LogService.instance.info('发现历史连接配置: ${recentConnection.name} (${recentConnection.ipAddress})', category: 'Startup');
        
        // 尝试自动连接
        final connected = await startupService.performStartupConnection(ref);
        
        if (connected) {
          setState(() {
            _statusMessage = '连接成功！';
          });
          
          // 连接成功，短暂显示成功消息后进入应用
          await Future.delayed(const Duration(milliseconds: 800));
          setState(() {
            _showStartupScreen = false;
            _isInitializing = false;
          });
        } else {
          // 连接失败，显示失败消息后进入应用
          setState(() {
            _statusMessage = '自动连接失败，请手动连接';
          });
          await Future.delayed(const Duration(milliseconds: 1500));
          setState(() {
            _showStartupScreen = false;
            _isInitializing = false;
          });
        }
      } else {
        // 没有历史连接，直接进入应用
        LogService.instance.info('没有历史连接配置，直接进入应用', category: 'Startup');
        setState(() {
          _statusMessage = '欢迎使用掌控者';
        });
        await Future.delayed(const Duration(milliseconds: 800));
        setState(() {
          _showStartupScreen = false;
          _isInitializing = false;
        });
      }
    } catch (e) {
      LogService.instance.error('启动序列异常: $e', category: 'Startup');
      // 出现异常时直接进入应用
      setState(() {
        _showStartupScreen = false;
        _isInitializing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_showStartupScreen && !_isInitializing) {
      return widget.child;
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 应用图标/Logo
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.smartphone,
                size: 60,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 32),
            
            // 应用名称
            Text(
              '掌控者',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'PalmController',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            
            const SizedBox(height: 48),
            
            // 加载指示器
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 状态消息
            Text(
              _statusMessage,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: Colors.white.withValues(alpha: 0.9),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
} 