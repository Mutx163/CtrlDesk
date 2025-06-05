import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/connection_provider.dart';
import '../models/control_message.dart';
import '../services/socket_service.dart';

class SystemScreen extends ConsumerWidget {
  const SystemScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionStatus = ref.watch(connectionStatusProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('系统控制'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: connectionStatus == ConnectionStatus.connected
          ? _buildSystemControlView(context, ref)
          : _buildNotConnectedView(context),
    );
  }

  Widget _buildSystemControlView(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 电源管理部分
          _buildSectionCard(
            context: context,
            title: '电源管理',
            icon: Icons.power_settings_new,
            iconColor: Colors.red,
            children: [
              _buildSystemButton(
                context: context,
                ref: ref,
                title: '锁定屏幕',
                subtitle: '锁定PC屏幕',
                icon: Icons.lock,
                iconColor: Colors.orange,
                action: 'lock',
                requireConfirm: false,
              ),
              const SizedBox(height: 12),
              _buildSystemButton(
                context: context,
                ref: ref,
                title: '睡眠',
                subtitle: '让PC进入睡眠状�?,
                icon: Icons.bedtime,
                iconColor: Colors.blue,
                action: 'sleep',
                requireConfirm: true,
                confirmTitle: '确认睡眠',
                confirmMessage: '确定要让PC进入睡眠状态吗�?,
              ),
              const SizedBox(height: 12),
              _buildSystemButton(
                context: context,
                ref: ref,
                title: '重启',
                subtitle: '重启PC系统',
                icon: Icons.restart_alt,
                iconColor: Colors.orange,
                action: 'restart',
                requireConfirm: true,
                confirmTitle: '确认重启',
                confirmMessage: '确定要重启PC吗？请确保已保存所有工作�?,
              ),
              const SizedBox(height: 12),
              _buildSystemButton(
                context: context,
                ref: ref,
                title: '关机',
                subtitle: '关闭PC电源',
                icon: Icons.power_off,
                iconColor: Colors.red,
                action: 'shutdown',
                requireConfirm: true,
                confirmTitle: '确认关机',
                confirmMessage: '确定要关闭PC吗？请确保已保存所有工作�?,
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // 演示控制部分
          _buildSectionCard(
            context: context,
            title: '演示控制',
            icon: Icons.slideshow,
            iconColor: Colors.green,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildSystemButton(
                      context: context,
                      ref: ref,
                      title: '上一�?,
                      subtitle: 'PPT上一�?,
                      icon: Icons.navigate_before,
                      iconColor: Colors.blue,
                      action: 'ppt_previous',
                      requireConfirm: false,
                      isCompact: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSystemButton(
                      context: context,
                      ref: ref,
                      title: '下一�?,
                      subtitle: 'PPT下一�?,
                      icon: Icons.navigate_next,
                      iconColor: Colors.blue,
                      action: 'ppt_next',
                      requireConfirm: false,
                      isCompact: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildSystemButton(
                context: context,
                ref: ref,
                title: '开始放�?,
                subtitle: '按F5开始幻灯片放映',
                icon: Icons.play_arrow,
                iconColor: Colors.green,
                action: 'presentation_start',
                requireConfirm: false,
              ),
              const SizedBox(height: 12),
              _buildSystemButton(
                context: context,
                ref: ref,
                title: '退出放�?,
                subtitle: '按Esc退出幻灯片放映',
                icon: Icons.stop,
                iconColor: Colors.red,
                action: 'presentation_end',
                requireConfirm: false,
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // 系统信息部分
          _buildSectionCard(
            context: context,
            title: '系统信息',
            icon: Icons.info,
            iconColor: Colors.purple,
            children: [
              _buildInfoTile(
                title: '连接状�?,
                value: '已连�?,
                icon: Icons.wifi,
                valueColor: Colors.green,
              ),
              const SizedBox(height: 8),
                             _buildInfoTile(
                 title: 'PC地址',
                 value: ref.watch(currentConnectionProvider)?.ipAddress ?? '未知',
                 icon: Icons.computer,
               ),
               const SizedBox(height: 8),
               _buildInfoTile(
                 title: '连接端口',
                 value: '${ref.watch(currentConnectionProvider)?.port ?? '未知'}',
                 icon: Icons.settings_ethernet,
               ),
            ],
          ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildNotConnectedView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.wifi_off,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 24),
            Text(
              '未连�?,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              '请先连接到PC端才能使用系统控制功�?,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => context.push('/connect'),
              icon: const Icon(Icons.settings),
              label: const Text('管理连接'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSystemButton({
    required BuildContext context,
    required WidgetRef ref,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required String action,
    required bool requireConfirm,
    String? confirmTitle,
    String? confirmMessage,
    bool isCompact = false,
  }) {
    return Card(
      child: InkWell(
        onTap: () => _handleSystemAction(
          context: context,
          ref: ref,
          action: action,
          requireConfirm: requireConfirm,
          confirmTitle: confirmTitle,
          confirmMessage: confirmMessage,
        ),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(isCompact ? 12 : 16),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: isCompact ? 20 : 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (!isCompact) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required String title,
    required String value,
    required IconData icon,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Future<void> _handleSystemAction({
    required BuildContext context,
    required WidgetRef ref,
    required String action,
    required bool requireConfirm,
    String? confirmTitle,
    String? confirmMessage,
  }) async {
    // 如果需要确认，显示确认对话�?    if (requireConfirm) {
      final confirmed = await _showConfirmDialog(
        context: context,
        title: confirmTitle ?? '确认操作',
        message: confirmMessage ?? '确定要执行此操作吗？',
      );
      
      if (!confirmed) return;
    }

    // 执行系统控制操作
    await _sendSystemCommand(ref, action);
    
    // 触觉反馈
    HapticFeedback.lightImpact();
    
    // 显示成功提示
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_getActionSuccessMessage(action)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<bool> _showConfirmDialog({
    required BuildContext context,
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 12),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  Future<void> _sendSystemCommand(WidgetRef ref, String action) async {
    final socketService = ref.read(socketServiceProvider);
    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    
    final message = ControlMessage.systemControl(
      messageId: messageId,
      action: action,
    );
    
    await socketService.sendMessage(message);
  }

  String _getActionSuccessMessage(String action) {
    switch (action) {
      case 'lock':
        return '已发送锁定屏幕指�?;
      case 'sleep':
        return '已发送睡眠指�?;
      case 'restart':
        return '已发送重启指�?;
      case 'shutdown':
        return '已发送关机指�?;
      case 'ppt_next':
        return '已切换到下一�?;
      case 'ppt_previous':
        return '已切换到上一�?;
      case 'presentation_start':
        return '已发送开始放映指�?;
      case 'presentation_end':
        return '已发送退出放映指�?;
      default:
        return '指令已发�?;
    }
  }
} 
