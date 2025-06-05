import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connection_provider.dart';
import '../models/connection_config.dart';
import 'log_service.dart';

class StartupService {
  static final StartupService _instance = StartupService._internal();
  factory StartupService() => _instance;
  StartupService._internal();

  // 应用启动时的自动连接
  Future<bool> performStartupConnection(WidgetRef ref) async {
    LogService.instance.info('开始启动时自动连接检�?, category: 'Startup');
    
    try {
      // 确保连接配置已加�?
      await ref.read(connectionConfigProvider.notifier).ensureLoaded();
      
      // 尝试连接到最近的服务�?
      final connectionManager = ref.read(connectionManagerProvider.notifier);
      final hasRecentConnection = await connectionManager.connectToRecentServer();
      
      if (hasRecentConnection) {
        LogService.instance.info('启动时自动连接成�?, category: 'Startup');
        return true;
      } else {
        LogService.instance.info('没有可用的历史连接配置，跳过自动连接', category: 'Startup');
        return false;
      }
    } catch (e) {
      LogService.instance.error('启动时自动连接失�? $e', category: 'Startup');
      return false;
    }
  }

  // 获取最近连接信息用于UI显示
  Future<ConnectionConfig?> getRecentConnection(WidgetRef ref) async {
    // 确保配置已加�?
    await ref.read(connectionConfigProvider.notifier).ensureLoaded();
    return ref.read(connectionConfigProvider.notifier).getRecentConnection();
  }
}

// StartupService Provider
final startupServiceProvider = Provider<StartupService>((ref) {
  return StartupService();
}); 
