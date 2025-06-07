import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  
  // 新增的丰富性能数据
  final int memoryUsedMB;
  final int memoryTotalMB;
  final int memoryAvailableMB;
  final int processCount;
  final int threadCount;
  final double systemUptime;
  final String cpuFrequency;
  final double diskReadSpeed;
  final double diskWriteSpeed;
  final double networkLatency;
  final int batteryLevel;
  final String powerStatus;
  final double gpuMemoryUsage;
  final String activeWindow;
  final int handleCount;
  final double pageFileUsage;

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
    // 新增字段的默认值
    this.memoryUsedMB = 0,
    this.memoryTotalMB = 0,
    this.memoryAvailableMB = 0,
    this.processCount = 0,
    this.threadCount = 0,
    this.systemUptime = 0.0,
    this.cpuFrequency = '',
    this.diskReadSpeed = 0.0,
    this.diskWriteSpeed = 0.0,
    this.networkLatency = 0.0,
    this.batteryLevel = -1,
    this.powerStatus = '',
    this.gpuMemoryUsage = 0.0,
    this.activeWindow = '',
    this.handleCount = 0,
    this.pageFileUsage = 0.0,
  });

  // Method to create a copy with new values from a map  
  PerformanceData.fromJson(Map<String, dynamic> json)
      : cpuUsage = (json['CpuUsage'] as num?)?.toDouble() ?? 0.0,  // 🔧 修复：使用Pascal命名
        ramUsage = (json['RamUsage'] as num?)?.toDouble() ?? 0.0,
        diskUsage = (json['DiskUsage'] as num?)?.toDouble() ?? 0.0,
        gpuUsage = (json['GpuUsage'] as num?)?.toDouble() ?? 0.0,
        cpuTemp = (json['CpuTemp'] as num?)?.toDouble() ?? 0.0,
        gpuTemp = (json['GpuTemp'] as num?)?.toDouble() ?? 0.0,
        motherboardTemp = (json['MotherboardTemp'] as num?)?.toDouble() ?? 0.0,
        fanSpeed = (json['FanSpeed'] as num?)?.toInt() ?? 0,
        networkUpload = (json['NetworkUpload'] as num?)?.toDouble() ?? 0.0,
        networkDownload = (json['NetworkDownload'] as num?)?.toDouble() ?? 0.0,
        // 新增字段的解析 - 使用Pascal命名
        memoryUsedMB = (json['MemoryUsedMB'] as num?)?.toInt() ?? 0,
        memoryTotalMB = (json['MemoryTotalMB'] as num?)?.toInt() ?? 0,
        memoryAvailableMB = (json['MemoryAvailableMB'] as num?)?.toInt() ?? 0,
        processCount = (json['ProcessCount'] as num?)?.toInt() ?? 0,
        threadCount = (json['ThreadCount'] as num?)?.toInt() ?? 0,
        systemUptime = (json['SystemUptime'] as num?)?.toDouble() ?? 0.0,
        cpuFrequency = json['CpuFrequency']?.toString() ?? '',
        diskReadSpeed = (json['DiskReadSpeed'] as num?)?.toDouble() ?? 0.0,
        diskWriteSpeed = (json['DiskWriteSpeed'] as num?)?.toDouble() ?? 0.0,
        networkLatency = (json['NetworkLatency'] as num?)?.toDouble() ?? 0.0,
        batteryLevel = (json['BatteryLevel'] as num?)?.toInt() ?? -1,
        powerStatus = json['PowerStatus']?.toString() ?? '',
        gpuMemoryUsage = (json['GpuMemoryUsage'] as num?)?.toDouble() ?? 0.0,
        activeWindow = json['ActiveWindow']?.toString() ?? '',
        handleCount = (json['HandleCount'] as num?)?.toInt() ?? 0,
        pageFileUsage = (json['PageFileUsage'] as num?)?.toDouble() ?? 0.0;
}

// 硬件信息Provider  
class HardwareInfoNotifier extends StateNotifier<HardwareInfo> {
  final Ref _ref;
  StreamSubscription? _messageSubscription;

  HardwareInfoNotifier(this._ref) : super(HardwareInfo()) {
    _listenToHardwareMessages();
  }

  void _listenToHardwareMessages() {
    _messageSubscription?.cancel();
    _messageSubscription = _ref.read(socketServiceProvider).messageStream.listen((message) {
      print('🔧 HardwareInfoNotifier收到消息: 类型=${message.type}');
      if (message.type == 'hardware_info') {
        print('🔧 处理硬件信息消息: ${message.payload}');
        updateHardwareInfo(message.payload['data']); // 🔧 修复：取data字段
      }
    });
  }

  void updateHardwareInfo(Map<String, dynamic> jsonData) {
    print('🔧 更新硬件信息: $jsonData');
    state = HardwareInfo(
      osVersion: jsonData['OsVersion']?.toString() ?? 'N/A',  // 🔧 修复：使用Pascal命名
      cpuName: jsonData['CpuName']?.toString() ?? 'N/A',
      cpuCores: jsonData['CpuCores']?.toString() ?? 'N/A',
      ramTotal: jsonData['RamTotal']?.toString() ?? 'N/A',
      gpuName: jsonData['GpuName']?.toString() ?? 'N/A',
      motherboard: jsonData['Motherboard']?.toString() ?? 'N/A',
    );
    print('🔧 硬件信息已更新: $state');
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }
}

final hardwareInfoProvider = StateNotifierProvider<HardwareInfoNotifier, HardwareInfo>((ref) {
  return HardwareInfoNotifier(ref);
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
      print('📊 PerformanceDataNotifier收到消息: 类型=${message.type}');
      if (message.type == 'performance_data') {  // 🔧 修复：监听正确的消息类型
        print('📊 处理性能数据消息: ${message.payload}');
        updateData(message.payload['data']); // 🔧 修复：取data字段
      } else {
        print('📊 忽略非性能数据消息: ${message.type}');
      }
    });
  }

  // This method will be called by the socket service to update the state
  void updateData(Map<String, dynamic> jsonData) {
    print('📊 更新性能数据: $jsonData');
    state = PerformanceData.fromJson(jsonData);
    print('📊 性能数据已更新: CPU=${state.cpuUsage}%, RAM=${state.ramUsage}%');
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

// 刷新设置数据模型
class RefreshSettings {
  final bool isAutoRefreshEnabled;
  final int refreshIntervalSeconds;
  
  const RefreshSettings({
    this.isAutoRefreshEnabled = true,
    this.refreshIntervalSeconds = 3,
  });
  
  RefreshSettings copyWith({
    bool? isAutoRefreshEnabled,
    int? refreshIntervalSeconds,
  }) {
    return RefreshSettings(
      isAutoRefreshEnabled: isAutoRefreshEnabled ?? this.isAutoRefreshEnabled,
      refreshIntervalSeconds: refreshIntervalSeconds ?? this.refreshIntervalSeconds,
    );
  }
}

// 刷新设置Provider
class RefreshSettingsNotifier extends StateNotifier<RefreshSettings> {
  RefreshSettingsNotifier() : super(const RefreshSettings());
  
  void toggleAutoRefresh() {
    state = state.copyWith(isAutoRefreshEnabled: !state.isAutoRefreshEnabled);
  }
  
  void setRefreshInterval(int seconds) {
    state = state.copyWith(refreshIntervalSeconds: seconds);
  }
  
  void setAutoRefreshEnabled(bool enabled) {
    state = state.copyWith(isAutoRefreshEnabled: enabled);
  }
}

final refreshSettingsProvider = StateNotifierProvider<RefreshSettingsNotifier, RefreshSettings>((ref) {
  return RefreshSettingsNotifier();
}); 