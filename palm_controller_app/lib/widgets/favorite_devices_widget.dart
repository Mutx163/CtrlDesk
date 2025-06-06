import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/connection_config.dart';
import '../providers/connection_provider.dart';
import '../services/log_service.dart';

class FavoriteDevicesWidget extends ConsumerStatefulWidget {
  const FavoriteDevicesWidget({super.key});

  @override
  ConsumerState<FavoriteDevicesWidget> createState() => _FavoriteDevicesWidgetState();
}

class _FavoriteDevicesWidgetState extends ConsumerState<FavoriteDevicesWidget> {
  List<ConnectionConfig> _favoriteDevices = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadFavoriteDevices();
  }

  Future<void> _loadFavoriteDevices() async {
    setState(() => _isLoading = true);
    try {
      // 模拟从本地存储加载收藏设备
      // 这里可以使用SharedPreferences或其他持久化方案
      await Future.delayed(const Duration(milliseconds: 300));
      
      if (mounted) {
        setState(() {
          _favoriteDevices = [
            // 示例数据，实际应从存储中读取
          ];
          _isLoading = false;
        });
      }
    } catch (e) {
      LogService.instance.error('加载收藏设备失败: $e', category: 'FavoriteDevices');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _connectToDevice(ConnectionConfig config) async {
    try {
      LogService.instance.info('尝试连接到收藏设备: ${config.name}', category: 'FavoriteDevices');
      
      await ref.read(connectionManagerProvider.notifier).connect(config);
      final result = ref.read(connectionManagerProvider);
      
      if (result.value == true) {
        LogService.instance.info('连接成功: ${config.name}', category: 'FavoriteDevices');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已连接到 ${config.name}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('连接失败');
      }
    } catch (e) {
      LogService.instance.error('连接收藏设备失败: $e', category: 'FavoriteDevices');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('连接 ${config.name} 失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_isLoading) {
      return Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 8),
              Text('加载收藏设备...', style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      );
    }

    if (_favoriteDevices.isEmpty) {
      return Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.star_border,
                size: 48,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
              const SizedBox(height: 8),
              Text(
                '暂无收藏设备',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '连接设备后可以添加为收藏',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(
                  Icons.star,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '收藏设备',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _favoriteDevices.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: theme.dividerColor,
            ),
            itemBuilder: (context, index) {
              final device = _favoriteDevices[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(
                    Icons.computer,
                    color: theme.colorScheme.onPrimaryContainer,
                    size: 20,
                  ),
                ),
                title: Text(device.name),
                subtitle: Text('${device.ipAddress}:${device.port}'),
                trailing: IconButton(
                  icon: const Icon(Icons.play_arrow),
                  onPressed: () => _connectToDevice(device),
                  tooltip: '快速连接',
                ),
                onTap: () => _connectToDevice(device),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
} 