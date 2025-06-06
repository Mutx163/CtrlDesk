import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../providers/monitor_provider.dart';

class ComputerStatusScreen extends ConsumerWidget {
  const ComputerStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final performanceData = ref.watch(performanceDataProvider);
    final hardwareInfo = ref.watch(hardwareInfoProvider);
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('电脑状态详情'),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
      ),
      backgroundColor: theme.colorScheme.surface,
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildPerformanceSection(context, performanceData, textTheme),
          const SizedBox(height: 24),
          _buildHardwareInfoSection(context, hardwareInfo, textTheme),
        ],
      ),
    );
  }

  Widget _buildPerformanceSection(BuildContext context, PerformanceData data, TextTheme textTheme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('实时性能', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildPerformanceRow(context, FontAwesomeIcons.microchip, 'CPU 使用率', '${data.cpuUsage.toStringAsFixed(1)}%', Colors.blue),
            _buildPerformanceRow(context, FontAwesomeIcons.memory, '内存 使用率', '${data.ramUsage.toStringAsFixed(1)}%', Colors.green),
            _buildPerformanceRow(context, FontAwesomeIcons.hardDrive, '磁盘 使用率', '${data.diskUsage.toStringAsFixed(1)}%', Colors.orange),
            _buildPerformanceRow(context, FontAwesomeIcons.networkWired, '网络', '↑ ${data.networkUpload.toStringAsFixed(1)} Mbps / ↓ ${data.networkDownload.toStringAsFixed(1)} Mbps', Colors.purple),
            const SizedBox(height: 8),
             _buildTemperatureRow(context, FontAwesomeIcons.temperatureHalf, '温度', 
              'CPU: ${data.cpuTemp.toStringAsFixed(1)}°C / 主板: ${data.motherboardTemp.toStringAsFixed(1)}°C',
              Colors.red
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHardwareInfoSection(BuildContext context, HardwareInfo info, TextTheme textTheme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('硬件信息', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildInfoTile(context, '操作系统', info.osVersion, FontAwesomeIcons.windows),
            _buildInfoTile(context, '处理器', '${info.cpuName} (${info.cpuCores})', FontAwesomeIcons.microchip),
            _buildInfoTile(context, '内存', info.ramTotal, FontAwesomeIcons.memory),
            _buildInfoTile(context, '显卡', info.gpuName, FontAwesomeIcons.desktop),
            _buildInfoTile(context, '主板', info.motherboard, FontAwesomeIcons.server),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceRow(BuildContext context, IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          FaIcon(icon, size: 20, color: color),
          const SizedBox(width: 16),
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTemperatureRow(BuildContext context, IconData icon, String label, String value, Color color) {
     return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          FaIcon(icon, size: 20, color: color),
          const SizedBox(width: 16),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const Spacer(),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildInfoTile(BuildContext context, String title, String subtitle, IconData icon) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: FaIcon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
    );
  }
} 