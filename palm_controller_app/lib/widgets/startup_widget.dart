import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/startup_service.dart';
import '../services/log_service.dart';
import '../services/auto_connect_service.dart';

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
      
      // 启动自动设备发现服务（无论是否有历史连接都启动）
      final autoConnectService = AutoConnectService();
      
      setState(() {
        _statusMessage = '正在搜索设备...';
      });
      
      LogService.instance.info('启动时开始自动设备发现', category: 'Startup');
      
      // 开始自动连接服务（包含设备发现）
      final autoConnectStarted = await autoConnectService.startAutoConnect();
      
      if (autoConnectStarted) {
        // 监听自动连接状态，等待连接或超时
        bool connectionAttempted = false;
        int waitTime = 0;
        const maxWaitTime = 12000; // 最多等待12秒
        const checkInterval = 500; // 每500ms检查一次状态
        
        while (waitTime < maxWaitTime && !connectionAttempted) {
          await Future.delayed(const Duration(milliseconds: checkInterval));
          waitTime += checkInterval;
          
          final status = autoConnectService.status;
          
          if (status == AutoConnectStatus.connected) {
            setState(() {
              _statusMessage = '设备连接成功！';
            });
            connectionAttempted = true;
            
            // 连接成功，短暂显示成功消息后进入应用
            await Future.delayed(const Duration(milliseconds: 800));
            break;
          } else if (status == AutoConnectStatus.failed || status == AutoConnectStatus.disabled) {
            setState(() {
              _statusMessage = '未发现设备，进入手动连接模式';
            });
            connectionAttempted = true;
            
            // 连接失败，显示失败消息后进入应用
            await Future.delayed(const Duration(milliseconds: 1000));
            break;
          } else if (status == AutoConnectStatus.connecting) {
            setState(() {
              _statusMessage = '正在连接到发现的设备...';
            });
          }
          
          // 如果仍在扫描，更新进度提示
          if (status == AutoConnectStatus.scanning && waitTime % 2000 == 0) {
            setState(() {
              final dots = '.' * ((waitTime ~/ 2000) % 4);
              _statusMessage = '正在搜索设备$dots';
            });
          }
        }
        
        // 如果超时还没有连接成功，直接进入应用
        if (!connectionAttempted) {
          setState(() {
            _statusMessage = '搜索超时，进入手动连接模式';
          });
          await Future.delayed(const Duration(milliseconds: 1000));
        }
      } else {
        // 自动连接服务启动失败（通常是权限问题）
        LogService.instance.info('自动连接服务启动失败，直接进入应用', category: 'Startup');
        setState(() {
          _statusMessage = '进入手动连接模式';
        });
        await Future.delayed(const Duration(milliseconds: 800));
      }
      
      // 最后进入主应用界面
      setState(() {
        _showStartupScreen = false;
        _isInitializing = false;
      });
      
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
                    color: Colors.black.withAlpha(((0.2) * 255).round()),
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
                                    color: Colors.white.withAlpha(((0.8) * 255).round()),
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
                                      color: Colors.white.withAlpha(((0.9) * 255).round()),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
} 

