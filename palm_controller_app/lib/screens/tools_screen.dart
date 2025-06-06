import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/connection_provider.dart';
import '../services/socket_service.dart';
import '../models/control_message.dart';

class ToolsScreen extends ConsumerStatefulWidget {
  const ToolsScreen({super.key});

  @override
  ConsumerState<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends ConsumerState<ToolsScreen> {
  bool _isScreenshotLoading = false;

  @override
  Widget build(BuildContext context) {
    final connectionStatus = ref.watch(connectionStatusProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface, // 统一背景色
      body: connectionStatus == ConnectionStatus.connected
          ? _buildToolsCollection(context)
          : _buildNotConnectedView(),
    );
  }

  /// 工具集合 - 完整的工具箱体验
  Widget _buildToolsCollection(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // 工具箱头部
        SliverToBoxAdapter(
          child: _buildToolsHeader(context),
        ),
        
        // 截图工具区域
        SliverToBoxAdapter(
          child: _buildScreenshotTools(context),
        ),
        
        // 系统控制区域
        SliverToBoxAdapter(
          child: _buildSystemControlSection(),
        ),
        
        // 监控工具区域
        SliverToBoxAdapter(
          child: _buildSystemMonitorSection(),
        ),
        
        // 连接管理区域
        SliverToBoxAdapter(
          child: _buildConnectionManagementSection(),
        ),
        
        // 底部间距
        const SliverToBoxAdapter(
          child: SizedBox(height: 100),
        ),
      ],
    );
  }

  /// 工具箱头部
  Widget _buildToolsHeader(BuildContext context) {
    final currentConnection = ref.watch(currentConnectionProvider);
    
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFF9800).withAlpha(((0.1) * 255).round()),
            const Color(0xFFF57C00).withAlpha(((0.05) * 255).round()),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFF9800).withAlpha(((0.2) * 255).round()),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // 工具箱图标
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9800).withAlpha(((0.1) * 255).round()),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.build_circle_rounded,
              color: Color(0xFFFF9800),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          
          // 标题和描述
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '工具集合',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFF9800),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      currentConnection?.name ?? 'Windows PC',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withAlpha(((0.7) * 255).round()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 截图工具区域
  Widget _buildScreenshotTools(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFF9800).withAlpha(((0.2) * 255).round()),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF9800).withAlpha(((0.1) * 255).round()),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.camera_alt_rounded,
                color: const Color(0xFFFF9800),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '屏幕截图工具',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFFF9800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.5,
            children: [
              _buildScreenshotButton(
                '全屏截图',
                Icons.fullscreen_rounded,
                () => _takeScreenshot('fullscreen'),
              ),
              _buildScreenshotButton(
                '窗口截图',
                Icons.web_asset_rounded,
                () => _takeScreenshot('window'),
              ),
              _buildScreenshotButton(
                '区域截图',
                Icons.crop_free_rounded,
                () => _takeScreenshot('region'),
              ),
              _buildScreenshotButton(
                '延迟3秒',
                Icons.timer_3_rounded,
                () => _takeScreenshot('delayed'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 系统控制区域
  Widget _buildSystemControlSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF795548).withAlpha(((0.2) * 255).round()),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF795548).withAlpha(((0.1) * 255).round()),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.settings_power_rounded,
                color: const Color(0xFF795548),
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                '系统控制',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF795548),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.5,
            children: [
              _buildSystemControlButton(
                '锁定屏幕',
                Icons.lock_rounded,
                const Color(0xFF2196F3),
                () => _sendSystemControl('lock'),
              ),
              _buildSystemControlButton(
                '休眠模式',
                Icons.bedtime_rounded,
                const Color(0xFF9C27B0),
                () => _sendSystemControl('sleep'),
              ),
              _buildSystemControlButton(
                '重启系统',
                Icons.refresh_rounded,
                const Color(0xFFFF9800),
                () => _showConfirmDialog('重启系统', () => _sendSystemControl('restart')),
              ),
              _buildSystemControlButton(
                '关闭电脑',
                Icons.power_settings_new_rounded,
                const Color(0xFFF44336),
                () => _showConfirmDialog('关闭电脑', () => _sendSystemControl('shutdown')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 系统监控区域
  Widget _buildSystemMonitorSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF4CAF50).withAlpha(((0.2) * 255).round()),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CAF50).withAlpha(((0.1) * 255).round()),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.monitor_heart_rounded,
                color: const Color(0xFF4CAF50),
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                '系统监控',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF4CAF50),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => context.go('/monitor'),
                icon: Icon(
                  Icons.open_in_new_rounded,
                  size: 16,
                  color: const Color(0xFF4CAF50),
                ),
                label: Text(
                  '详细',
                  style: TextStyle(
                    color: const Color(0xFF4CAF50),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSystemStatusCard(),
        ],
      ),
    );
  }

  /// 连接管理区域
  Widget _buildConnectionManagementSection() {
    final currentConnection = ref.watch(currentConnectionProvider);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF00BCD4).withAlpha(((0.2) * 255).round()),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00BCD4).withAlpha(((0.1) * 255).round()),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.wifi_rounded,
                color: const Color(0xFF00BCD4),
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                '连接管理',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF00BCD4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (currentConnection != null) ...[
            _buildConnectionInfoRow('设备名称', currentConnection.name),
            _buildConnectionInfoRow('IP地址', '${currentConnection.ipAddress}:${currentConnection.port}'),
            _buildConnectionInfoRow('连接状态', '已连接 ✅'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _disconnectFromServer(),
                icon: const Icon(Icons.power_off_rounded, size: 18),
                label: const Text('断开连接'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFF44336),
                  side: const BorderSide(color: Color(0xFFF44336)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 截图按钮构建器
  Widget _buildScreenshotButton(String label, IconData icon, VoidCallback onPressed) {
    return Material(
      color: const Color(0xFFFF5722).withAlpha(((0.1) * 255).round()),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: _isScreenshotLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(
                icon,
                color: const Color(0xFFFF5722),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFFFF5722),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 系统控制按钮构建器
  Widget _buildSystemControlButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return Material(
      color: color.withAlpha(((0.1) * 255).round()),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(
                icon,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 系统状态卡片
  Widget _buildSystemStatusCard() {
    // 这里应该从实际的监控数据provider获取数据
    // 暂时使用模拟数据
    return Column(
      children: [
        _buildStatusRow('CPU使用率', '45%', Colors.green, 0.45),
        _buildStatusRow('内存使用', '8.2/16GB', Colors.orange, 0.51),
        _buildStatusRow('磁盘活动', '正常', Colors.green, null),
        _buildStatusRow('网络速度', '50 Mbps', Colors.green, null),
      ],
    );
  }

  /// 状态行构建器
  Widget _buildStatusRow(String label, String value, Color color, double? progress) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (progress != null) ...[
            Expanded(
              flex: 2,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: color.withAlpha(((0.2) * 255).round()),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// 连接信息行构建器
  Widget _buildConnectionInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withAlpha(((0.7) * 255).round()),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotConnectedView() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 橙色主题图标
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFFF9800).withAlpha(((0.1) * 255).round()),
                    const Color(0xFFF57C00).withAlpha(((0.05) * 255).round()),
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFF9800).withAlpha(((0.2) * 255).round()),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.build_circle_rounded,
                size: 64,
                color: Color(0xFFFF9800),
              ),
            ),
            const SizedBox(height: 32),
            
            Text(
              '工具集合',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFFFF9800),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              '需要连接PC设备才能使用',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withAlpha(((0.7) * 255).round()),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '连接后即可使用截图、控制和监控工具',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withAlpha(((0.6) * 255).round()),
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 48),
            
            // 功能介绍卡片
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9800).withAlpha(((0.05) * 255).round()),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFFF9800).withAlpha(((0.2) * 255).round()),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    '工具集合功能',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFFF9800),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildToolsFeature(Icons.camera_alt_rounded, '屏幕\n截图'),
                      _buildToolsFeature(Icons.settings_power_rounded, '系统\n控制'),
                      _buildToolsFeature(Icons.monitor_rounded, '性能\n监控'),
                      _buildToolsFeature(Icons.wifi_rounded, '连接\n管理'),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // 连接按钮
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => context.go('/connect'),
                icon: const Icon(Icons.wifi_rounded),
                label: const Text('连接设备'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9800),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 工具功能项展示
  Widget _buildToolsFeature(IconData icon, String label) {
    return Column(
      children: [
        Icon(
          icon,
          color: const Color(0xFFFF9800),
          size: 24,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFFF9800),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// 截图功能
  Future<void> _takeScreenshot(String type) async {
    setState(() => _isScreenshotLoading = true);
    
    try {
      final message = ControlMessage.systemControl(
        messageId: DateTime.now().millisecondsSinceEpoch.toString(),
        action: 'screenshot_$type',
      );
      final socketService = ref.read(socketServiceProvider);
      await socketService.sendMessage(message);
      
      HapticFeedback.lightImpact();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('正在进行${type == 'fullscreen' ? '全屏' : type == 'window' ? '窗口' : type == 'region' ? '区域' : '延迟'}截图...'),
            backgroundColor: const Color(0xFFFF5722),
          ),
        );
      }
    } catch (e) {
      // 处理发送失败的情况
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('截图指令发送失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // 确保在组件未销毁时才更新状态
      if (mounted) {
        setState(() {
          _isScreenshotLoading = false;
        });
      }
    }
  }

  /// 系统控制
  Future<void> _sendSystemControl(String action) async {
    final message = ControlMessage.systemControl(
      messageId: DateTime.now().millisecondsSinceEpoch.toString(),
      action: action,
    );
    
    final actionMap = {
      'lock': '锁定屏幕',
      'sleep': '休眠',
      'restart': '重启',
      'shutdown': '关机',
    };
    
    try {
      final socketService = ref.read(socketServiceProvider);
      await socketService.sendMessage(message);
      
      HapticFeedback.lightImpact();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已发送${actionMap[action]}指令'),
            backgroundColor: const Color(0xFF795548),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${actionMap[action]}指令发送失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 断开连接
  void _disconnectFromServer() {
    ref.read(connectionManagerProvider.notifier).disconnect();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已断开连接'),
        backgroundColor: Color(0xFFF44336),
      ),
    );
  }

  /// 确认对话框
  void _showConfirmDialog(String action, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('确认$action'),
        content: Text('您确定要$action吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              onConfirm();
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF44336),
            ),
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }
} 


