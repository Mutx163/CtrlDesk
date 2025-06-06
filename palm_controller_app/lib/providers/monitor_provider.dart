import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

// 性能数据Provider
final performanceDataProvider = StateProvider<PerformanceData>((ref) {
  // 这里使用随机数据模拟实时更新的效果
  // 在真实应用中，这些数据应由Socket推送更新
  return PerformanceData(
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
}); 