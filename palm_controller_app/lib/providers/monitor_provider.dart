import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/control_message.dart';
import '../services/socket_service.dart';
import 'connection_provider.dart';

// 硬件信息数据模型
class HardwareInfo {
  final String osVersion;
  final String cpuName;
  final String cpuCores;
  final String ramTotal;
  final String gpuName;
  final String motherboard;

  HardwareInfo({
    this.osVersion = 'N/A',
    this.cpuName = 'N/A',
    this.cpuCores = 'N/A',
    this.ramTotal = 'N/A',
    this.gpuName = 'N/A',
    this.motherboard = 'N/A',
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
    this.cpuUsage = 0.0,
    this.ramUsage = 0.0,
    this.gpuUsage = 0.0,
    this.diskUsage = 0.0,
    this.cpuTemp = 0.0,
    this.gpuTemp = 0.0,
    this.motherboardTemp = 0.0,
    this.fanSpeed = 0,
    this.networkUpload = 0.0,
    this.networkDownload = 0.0,
  });

  // Method to create a copy with new values from a map
  PerformanceData.fromJson(Map<String, dynamic> json)
      : cpuUsage = (json['cpu_usage'] as num?)?.toDouble() ?? 0.0,
        ramUsage = (json['ram_usage'] as num?)?.toDouble() ?? 0.0,
        diskUsage = (json['disk_usage'] as num?)?.toDouble() ?? 0.0,
        gpuUsage = (json['gpu_usage'] as num?)?.toDouble() ?? 0.0,
        cpuTemp = (json['cpu_temp'] as num?)?.toDouble() ?? 0.0,
        gpuTemp = (json['gpu_temp'] as num?)?.toDouble() ?? 0.0,
        motherboardTemp = (json['motherboard_temp'] as num?)?.toDouble() ?? 0.0,
        fanSpeed = (json['fan_speed'] as num?)?.toInt() ?? 0,
        networkUpload = (json['network_upload'] as num?)?.toDouble() ?? 0.0,
        networkDownload = (json['network_download'] as num?)?.toDouble() ?? 0.0;
}

// 硬件信息Provider
final hardwareInfoProvider = StateProvider<HardwareInfo>((ref) {
  // 在真实应用中，这里应该从Socket或API获取数据
  return HardwareInfo(
    osVersion: 'Windows 11 Pro',
    cpuName: 'Intel i7-12700K @ 3.6GHz',
    cpuCores: '12核心 20线程',
    ramTotal: '32GB DDR4 @ 3200MHz',
    gpuName: 'RTX 4070 Super 12GB',
    motherboard: 'ASUS ROG STRIX Z690-E',
  );
});

// Create a StateNotifier for PerformanceData
class PerformanceDataNotifier extends StateNotifier<PerformanceData> {
  final Ref _ref;
  StreamSubscription? _messageSubscription;

  PerformanceDataNotifier(this._ref) : super(PerformanceData()) {
    _listenToMessages();
  }

  void _listenToMessages() {
    _messageSubscription?.cancel(); // Ensure no multiple listeners
    _messageSubscription = _ref.read(socketServiceProvider).messageStream.listen((message) {
      if (message.type == 'system_status' && message.payload != null) {
        updateData(message.payload!);
      }
    });
  }

  // This method will be called by the socket service to update the state
  void updateData(Map<String, dynamic> jsonData) {
    state = PerformanceData.fromJson(jsonData);
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }
}

// Create the StateNotifierProvider
final performanceDataProvider = StateNotifierProvider<PerformanceDataNotifier, PerformanceData>((ref) {
  return PerformanceDataNotifier(ref);
}); 