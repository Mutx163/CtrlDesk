import 'package:json_annotation/json_annotation.dart';

part 'connection_config.g.dart';

@JsonSerializable()
class ConnectionConfig {
  final String id;
  final String name;
  final String ipAddress;
  final int port;
  final String? password;
  final DateTime lastConnected;
  final bool autoConnect;

  const ConnectionConfig({
    required this.id,
    required this.name,
    required this.ipAddress,
    required this.port,
    this.password,
    required this.lastConnected,
    this.autoConnect = false,
  });

  factory ConnectionConfig.fromJson(Map<String, dynamic> json) =>
      _$ConnectionConfigFromJson(json);

  Map<String, dynamic> toJson() => _$ConnectionConfigToJson(this);

  ConnectionConfig copyWith({
    String? id,
    String? name,
    String? ipAddress,
    int? port,
    String? password,
    DateTime? lastConnected,
    bool? autoConnect,
  }) {
    return ConnectionConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      password: password ?? this.password,
      lastConnected: lastConnected ?? this.lastConnected,
      autoConnect: autoConnect ?? this.autoConnect,
    );
  }

  @override
  String toString() {
    return 'ConnectionConfig(id: $id, name: $name, ipAddress: $ipAddress, port: $port)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConnectionConfig && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
} 
