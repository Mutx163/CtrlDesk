import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/monitor_provider.dart';
import '../providers/connection_provider.dart';
import '../models/control_message.dart';
import '../services/socket_service.dart';

class ComputerStatusScreen extends ConsumerStatefulWidget {
  const ComputerStatusScreen({super.key});

  @override
  ConsumerState<ComputerStatusScreen> createState() => _ComputerStatusScreenState();
}

class _ComputerStatusScreenState extends ConsumerState<ComputerStatusScreen> {
  Timer? _refreshTimer;
  DateTime? _lastRefreshTime;
  final List<int> _refreshIntervals = [1, 2, 3, 5, 10, 30];
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestSystemStatus();
      _startAutoRefresh();
    });
  }
  
  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
  
  void _startAutoRefresh() {
    final settings = ref.read(refreshSettingsProvider);
    if (!settings.isAutoRefreshEnabled) return;
    
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(Duration(seconds: settings.refreshIntervalSeconds), (timer) {
      final currentSettings = ref.read(refreshSettingsProvider);
      if (mounted && currentSettings.isAutoRefreshEnabled) {
        _requestSystemStatus();
      }
    });
  }
  
  void _toggleAutoRefresh() {
    ref.read(refreshSettingsProvider.notifier).toggleAutoRefresh();
    final settings = ref.read(refreshSettingsProvider);
    if (settings.isAutoRefreshEnabled) {
      _startAutoRefresh();
    } else {
      _refreshTimer?.cancel();
    }
  }
  
  void _changeRefreshInterval(int? seconds) {
    if (seconds != null) {
      ref.read(refreshSettingsProvider.notifier).setRefreshInterval(seconds);
      _startAutoRefresh();
    }
  }
  
  void _requestSystemStatus() {
    if (ref.read(connectionStatusProvider) == ConnectionStatus.connected) {
      final message = ControlMessage.systemControl(
        messageId: DateTime.now().millisecondsSinceEpoch.toString(),
        action: 'get_system_status',
      );
      ref.read(socketServiceProvider).sendMessage(message);
      setState(() {
        _lastRefreshTime = DateTime.now();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final performanceData = ref.watch(performanceDataProvider);
    final hardwareInfo = ref.watch(hardwareInfoProvider);
    final connectionStatus = ref.watch(connectionStatusProvider);
    final theme = Theme.of(context);

        return Scaffold(
        appBar: AppBar(
        title: const Text('电脑状态详情'),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _refreshTimer?.cancel();
            // GoRouter自动处理返回导航
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          // 自动刷新开关
          Consumer(
            builder: (context, ref, child) {
              final settings = ref.watch(refreshSettingsProvider);
              return IconButton(
                icon: Icon(
                  settings.isAutoRefreshEnabled ? Icons.pause : Icons.play_arrow,
                  color: settings.isAutoRefreshEnabled ? Colors.green : Colors.grey,
                ),
                onPressed: _toggleAutoRefresh,
                tooltip: settings.isAutoRefreshEnabled ? '暂停自动刷新' : '开启自动刷新',
              );
            },
          ),
          // 刷新间隔设置
          Consumer(
            builder: (context, ref, child) {
              final settings = ref.watch(refreshSettingsProvider);
              return PopupMenuButton<int>(
                icon: const Icon(Icons.timer),
                tooltip: '设置刷新间隔',
                onSelected: _changeRefreshInterval,
                itemBuilder: (context) => _refreshIntervals.map((interval) {
                  return PopupMenuItem<int>(
                    value: interval,
                    child: Row(
                      children: [
                        if (interval == settings.refreshIntervalSeconds) 
                          const Icon(Icons.check, size: 16, color: Colors.green),
                        if (interval != settings.refreshIntervalSeconds) 
                          const SizedBox(width: 16),
                        const SizedBox(width: 8),
                        Text('${interval}秒'),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
          // 手动刷新
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _requestSystemStatus,
            tooltip: '立即刷新',
          ),
        ],
      ),
      backgroundColor: theme.colorScheme.surface,
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildConnectionCard(context, connectionStatus),
          const SizedBox(height: 16),
          _buildPerformanceCard(context, performanceData),
          const SizedBox(height: 16),
          _buildHardwareCard(context, hardwareInfo),
        ],
      ),
    );
  }

  Widget _buildConnectionCard(BuildContext context, ConnectionStatus status) {
    final isConnected = status == ConnectionStatus.connected;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: isConnected ? Colors.green : Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isConnected ? '已连接' : '未连接',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isConnected ? Colors.green : Colors.red,
                    ),
                  ),
                  if (_lastRefreshTime != null && isConnected)
                    Text(
                      '最后更新：${_formatTime(_lastRefreshTime!)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            Consumer(
              builder: (context, ref, child) {
                final settings = ref.watch(refreshSettingsProvider);
                if (settings.isAutoRefreshEnabled && isConnected) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Text(
                      '${settings.refreshIntervalSeconds}s自动刷新',
                      style: const TextStyle(fontSize: 12, color: Colors.green),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceCard(BuildContext context, PerformanceData data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('实时性能', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _buildMetricRow('CPU 使用率', '${data.cpuUsage.toStringAsFixed(1)}%', Icons.memory, Colors.blue),
            _buildMetricRow('内存使用率', '${data.ramUsage.toStringAsFixed(1)}%', Icons.storage, Colors.green),
            _buildMetricRow('磁盘使用率', '${data.diskUsage.toStringAsFixed(1)}%', Icons.storage, Colors.orange),
            _buildMetricRow('网络', '↑${data.networkUpload.toStringAsFixed(1)} ↓${data.networkDownload.toStringAsFixed(1)} Mbps', Icons.wifi, Colors.purple),
            _buildMetricRow('温度', 'CPU:${data.cpuTemp.toStringAsFixed(1)}°C 主板:${data.motherboardTemp.toStringAsFixed(1)}°C', Icons.thermostat, Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _buildHardwareCard(BuildContext context, HardwareInfo info) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('硬件信息', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _buildInfoRow('操作系统', info.osVersion, Icons.computer),
            _buildInfoRow('处理器', '${info.cpuName} (${info.cpuCores}核)', Icons.memory),
            _buildInfoRow('内存', info.ramTotal, Icons.storage),
            _buildInfoRow('显卡', info.gpuName, Icons.monitor),
            _buildInfoRow('主板', info.motherboard, Icons.developer_board),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Expanded(child: Text(value, textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}秒前';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分钟前';
    } else {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
} 