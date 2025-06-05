import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connection_provider.dart';
import '../services/socket_service.dart';
import '../models/control_message.dart';
import 'dart:math' as math;

// 硬件信息数据模型
class HardwareInfo {
  final String osVersion;
  final String cpuName;
  final String cpuCores;
  final String ramTotal;
  final String gpuName;
  final String motherboard;

  HardwareInfo({
    required this.osVersion,
    required this.cpuName,
    required this.cpuCores,
    required this.ramTotal,
    required this.gpuName,
    required this.motherboard,
  });
}

// 性能监控数据模型
class PerformanceData {
  final double cpuUsage;
  final double ramUsage;
  final double gpuUsage;
  final double diskUsage;
  final double cpuTemp;
  final double gpuTemp;
  final double motherboardTemp;
  final int fanSpeed;
  final double networkUpload;
  final double networkDownload;

  PerformanceData({
    required this.cpuUsage,
    required this.ramUsage,
    required this.gpuUsage,
    required this.diskUsage,
    required this.cpuTemp,
    required this.gpuTemp,
    required this.motherboardTemp,
    required this.fanSpeed,
    required this.networkUpload,
    required this.networkDownload,
  });
}

// 硬件信息Provider（模拟数据）
final hardwareInfoProvider = StateProvider<HardwareInfo>((ref) {
  return HardwareInfo(
    osVersion: 'Windows 11 Pro',
    cpuName: 'Intel i7-12700K @ 3.6GHz',
    cpuCores: '12核心 20线程',
    ramTotal: '32GB DDR4 @ 3200MHz',
    gpuName: 'RTX 4070 Super 12GB',
    motherboard: 'ASUS ROG STRIX Z690-E',
  );
});

// 性能数据Provider（模拟动态数据）
final performanceDataProvider = StateProvider<PerformanceData>((ref) {
  return PerformanceData(
    cpuUsage: 45 + (math.Random().nextDouble() * 30), // 45-75%
    ramUsage: 60 + (math.Random().nextDouble() * 15), // 60-75%
    gpuUsage: 25 + (math.Random().nextDouble() * 50), // 25-75%
    diskUsage: 20 + (math.Random().nextDouble() * 30), // 20-50%
    cpuTemp: 65 + (math.Random().nextDouble() * 10), // 65-75°C
    gpuTemp: 70 + (math.Random().nextDouble() * 10), // 70-80°C
    motherboardTemp: 40 + (math.Random().nextDouble() * 10), // 40-50°C
    fanSpeed: 1500 + (math.Random().nextInt(500)), // 1500-2000 RPM
    networkUpload: math.Random().nextDouble() * 50, // 0-50 MB/s
    networkDownload: math.Random().nextDouble() * 200, // 0-200 MB/s
  );
});

class MonitorScreen extends ConsumerStatefulWidget {
  const MonitorScreen({super.key});

  @override
  ConsumerState<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends ConsumerState<MonitorScreen> {
  // 发送监控控制消�?
  void _sendMonitorMessage(String action) {
    final message = ControlMessage.systemControl(
      messageId: DateTime.now().millisecondsSinceEpoch.toString(),
      action: 'monitor_$action',
    );
    
    final socketService = ref.read(socketServiceProvider);
    socketService.sendMessage(message);
    HapticFeedback.lightImpact();
  }

  // 刷新性能数据
  void _refreshPerformanceData() {
    _sendMonitorMessage('refresh_performance');
    
    // 模拟数据更新
    ref.read(performanceDataProvider.notifier).state = PerformanceData(
      cpuUsage: 45 + (math.Random().nextDouble() * 30),
      ramUsage: 60 + (math.Random().nextDouble() * 15),
      gpuUsage: 25 + (math.Random().nextDouble() * 50),
      diskUsage: 20 + (math.Random().nextDouble() * 30),
      cpuTemp: 65 + (math.Random().nextDouble() * 10),
      gpuTemp: 70 + (math.Random().nextDouble() * 10),
      motherboardTemp: 40 + (math.Random().nextDouble() * 10),
      fanSpeed: 1500 + (math.Random().nextInt(500)),
      networkUpload: math.Random().nextDouble() * 50,
      networkDownload: math.Random().nextDouble() * 200,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('性能数据已刷�?)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connectionStatus = ref.watch(connectionStatusProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: connectionStatus == ConnectionStatus.connected
            ? _buildMonitorInterface(context)
            : _buildNotConnectedView(context),
      ),
    );
  }

  Widget _buildMonitorInterface(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _refreshPerformanceData(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 页面标题
            _buildPageHeader(context),
            const SizedBox(height: 20),
            
            // PC概览信息
            _buildSystemOverview(context),
            const SizedBox(height: 20),
            
            // 实时性能监控
            _buildPerformanceMonitor(context),
            const SizedBox(height: 20),
            
            // 温度监控
            _buildTemperatureMonitor(context),
            const SizedBox(height: 20),
            
            // 网络与存�?
            _buildNetworkStorage(context),
            const SizedBox(height: 20),
            
            // 进程管理
            _buildProcessManager(context),
          ],
        ),
      ),
    );
  }

  Widget _buildPageHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFD32F2F).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.monitor_heart_rounded,
            color: Color(0xFFD32F2F),
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '硬件监控',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFD32F2F),
                ),
              ),
              Text(
                '实时监控PC硬件状�?,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _refreshPerformanceData,
          icon: const Icon(Icons.refresh_rounded),
          tooltip: '刷新数据',
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFD32F2F).withValues(alpha: 0.1),
            foregroundColor: const Color(0xFFD32F2F),
          ),
        ),
      ],
    );
  }

  Widget _buildSystemOverview(BuildContext context) {
    final hardwareInfo = ref.watch(hardwareInfoProvider);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFD32F2F).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFD32F2F).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.computer_rounded,
                color: const Color(0xFFD32F2F),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'PC概览信息',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFD32F2F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(context, Icons.dns_rounded, '操作系统', hardwareInfo.osVersion),
          _buildInfoRow(context, Icons.memory_rounded, '处理�?, hardwareInfo.cpuName),
          _buildInfoRow(context, Icons.grain_rounded, '核心�?, hardwareInfo.cpuCores),
          _buildInfoRow(context, Icons.storage_rounded, '内存', hardwareInfo.ramTotal),
          _buildInfoRow(context, Icons.videogame_asset_rounded, '显卡', hardwareInfo.gpuName),
          _buildInfoRow(context, Icons.developer_board_rounded, '主板', hardwareInfo.motherboard),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceMonitor(BuildContext context) {
    final performance = ref.watch(performanceDataProvider);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.speed_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '实时性能监控',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 2.5,
            children: [
              _buildPerformanceCard(
                context,
                'CPU使用�?,
                performance.cpuUsage,
                Icons.memory_rounded,
                Colors.blue,
              ),
              _buildPerformanceCard(
                context,
                '内存使用�?,
                performance.ramUsage,
                Icons.storage_rounded,
                Colors.green,
              ),
              _buildPerformanceCard(
                context,
                'GPU使用�?,
                performance.gpuUsage,
                Icons.videogame_asset_rounded,
                Colors.purple,
              ),
              _buildPerformanceCard(
                context,
                '磁盘活动',
                performance.diskUsage,
                Icons.sd_storage_rounded,
                Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceCard(
    BuildContext context,
    String title,
    double percentage,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${percentage.toInt()}%',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }

  Widget _buildTemperatureMonitor(BuildContext context) {
    final performance = ref.watch(performanceDataProvider);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.thermostat_rounded,
                color: Theme.of(context).colorScheme.secondary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '温度监控',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTemperatureCard(
                  context,
                  'CPU温度',
                  performance.cpuTemp,
                  Icons.memory_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTemperatureCard(
                  context,
                  'GPU温度',
                  performance.gpuTemp,
                  Icons.videogame_asset_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTemperatureCard(
                  context,
                  '主板温度',
                  performance.motherboardTemp,
                  Icons.developer_board_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.air_rounded,
                  color: Theme.of(context).colorScheme.secondary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  '风扇转�?,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  '${performance.fanSpeed} RPM',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemperatureCard(
    BuildContext context,
    String title,
    double temperature,
    IconData icon,
  ) {
    Color tempColor = Colors.green;
    if (temperature > 80) {
      tempColor = Colors.red;
    } else if (temperature > 70) {
      tempColor = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: tempColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: tempColor),
          const SizedBox(height: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '${temperature.toInt()}°C',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: tempColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            temperature > 80 ? '过热' : temperature > 70 ? '偏高' : '正常',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: tempColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkStorage(BuildContext context) {
    final performance = ref.watch(performanceDataProvider);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.network_check_rounded,
                color: Theme.of(context).colorScheme.tertiary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '网络与存�?,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildNetworkCard(
                  context,
                  '上传速度',
                  performance.networkUpload,
                  Icons.upload_rounded,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildNetworkCard(
                  context,
                  '下载速度',
                  performance.networkDownload,
                  Icons.download_rounded,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildStorageInfo(context),
        ],
      ),
    );
  }

  Widget _buildNetworkCard(
    BuildContext context,
    String title,
    double speed,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.labelMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '${speed.toStringAsFixed(1)} MB/s',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageInfo(BuildContext context) {
    return Column(
      children: [
        _buildStorageRow(context, 'C�?(系统)', 256, 512, Icons.storage_rounded),
        const SizedBox(height: 8),
        _buildStorageRow(context, 'D�?(数据)', 1200, 2000, Icons.sd_storage_rounded),
      ],
    );
  }

  Widget _buildStorageRow(
    BuildContext context,
    String label,
    int used,
    int total,
    IconData icon,
  ) {
    final percentage = used / total;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Theme.of(context).colorScheme.tertiary),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                '${used}GB / ${total}GB',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: percentage,
            backgroundColor: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(
              percentage > 0.8 ? Colors.red : Theme.of(context).colorScheme.tertiary,
            ),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessManager(BuildContext context) {
    final processes = [
      {'name': 'Chrome.exe', 'cpu': 15.2, 'memory': 2048},
      {'name': 'Discord.exe', 'cpu': 8.5, 'memory': 800},
      {'name': 'Steam.exe', 'cpu': 5.1, 'memory': 600},
      {'name': 'Code.exe', 'cpu': 12.3, 'memory': 1200},
      {'name': 'explorer.exe', 'cpu': 2.1, 'memory': 150},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.list_alt_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '进程管理�?,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _sendMonitorMessage('refresh_processes'),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('刷新'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '高占用进�?Top 5',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: processes.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final process = processes[index];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.apps_rounded,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        process['name'] as String,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      'CPU: ${(process['cpu'] as double).toStringAsFixed(1)}%',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '内存: ${process['memory']}MB',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, size: 16),
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'details', child: Text('详情')),
                        const PopupMenuItem(value: 'terminate', child: Text('结束进程')),
                      ],
                      onSelected: (value) {
                        switch (value) {
                          case 'details':
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('查看 ${process['name']} 详情')),
                            );
                            break;
                          case 'terminate':
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('结束进程 ${process['name']}')),
                            );
                            break;
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNotConnectedView(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFFD32F2F).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.monitor_heart_outlined,
              size: 64,
              color: Color(0xFFD32F2F),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            '设备未连�?,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            '请先连接到PC设备后使用硬件监控功�?,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).pushReplacementNamed('/connect'),
              icon: const Icon(Icons.wifi_rounded),
              label: const Text('连接设备'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 
