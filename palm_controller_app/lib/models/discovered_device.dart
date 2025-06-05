import 'connection_config.dart';

/// 发现的设备信息模�?
class DiscoveredDevice {
  final String serviceName;
  final String serviceType;
  final String hostName;
  final String ipAddress;
  final int port;
  final String version;
  final DateTime discoveredAt;
  final int rssi; // 信号强度 (模拟)

  const DiscoveredDevice({
    required this.serviceName,
    required this.serviceType,
    required this.hostName,
    required this.ipAddress,
    required this.port,
    required this.version,
    required this.discoveredAt,
    this.rssi = 0,
  });

  factory DiscoveredDevice.fromJson(Map<String, dynamic> json) {
    return DiscoveredDevice(
      serviceName: json['serviceName'] ?? '',
      serviceType: json['serviceType'] ?? '',
      hostName: json['hostName'] ?? '',
      ipAddress: json['ipAddress'] ?? '',
      port: json['port'] ?? 8080,
      version: json['version'] ?? '1.0.0',
      discoveredAt: DateTime.now(),
    );
  }

  /// 转换为连接配�?
  ConnectionConfig toConnectionConfig() {
    return ConnectionConfig(
      id: '${ipAddress}_${port}_${DateTime.now().millisecondsSinceEpoch}',
      name: '$hostName ($serviceName)',
      ipAddress: ipAddress,
      port: port,
      password: null,
      lastConnected: DateTime.now(),
      autoConnect: true,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DiscoveredDevice &&
        other.ipAddress == ipAddress &&
        other.port == port;
  }

  @override
  int get hashCode => ipAddress.hashCode ^ port.hashCode;

  @override
  String toString() {
    return 'DiscoveredDevice(serviceName: $serviceName, hostName: $hostName, ipAddress: $ipAddress:$port)';
  }
 