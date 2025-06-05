import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:go_router/go_router.dart';
import '../models/connection_config.dart';
import '../providers/connection_provider.dart';
import '../services/socket_service.dart';
import '../services/discovery_service.dart';

class ConnectScreen extends ConsumerStatefulWidget {
  const ConnectScreen({super.key});

  @override
  ConsumerState<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends ConsumerState<ConnectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '8080');
  final _passwordController = TextEditingController();
  final _uuid = const Uuid();
  bool _showPermissionCard = true;
  
  // 设备发现相关状态
  final DiscoveryService _discoveryService = DiscoveryService();
  List<DiscoveredDevice> _discoveredDevices = [];
  bool _isScanning = false;
  String? _scanError;

  @override
  void initState() {
    super.initState();
    // 设置连接成功后的导航回调
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(connectionManagerProvider.notifier).setNavigationCallback(() {
          if (mounted && context.canPop()) {
            // 如果可以返回，说明是从其他页面进入的连接页面，直接返回
            context.pop();
          } else {
            // 否则导航到控制界面
            context.go('/');
          }
        });
        // 检查权限状态，决定是否显示权限卡片
        _checkPermissionStatus();
      }
    });
  }

  // 检查权限状态，决定是否显示权限卡片
  Future<void> _checkPermissionStatus() async {
    final status = await Permission.locationWhenInUse.status;
    if (mounted) {
      setState(() {
        // 只有在权限被拒绝且用户没有手动关闭卡片时才显示
        _showPermissionCard = (status == PermissionStatus.denied || status == PermissionStatus.permanentlyDenied);
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ipController.dispose();
    _portController.dispose();
    _passwordController.dispose();
    _discoveryService.dispose();
    super.dispose();
  }

  Future<void> _connectToServer([ConnectionConfig? config]) async {
    ConnectionConfig connectionConfig;
    
    if (config != null) {
      // 使用已保存的配置连接
      connectionConfig = config;
    } else {
      // 使用表单输入创建新配置
      if (!_formKey.currentState!.validate()) return;
      
      connectionConfig = ConnectionConfig(
        id: _uuid.v4(),
        name: _nameController.text.trim(),
        ipAddress: _ipController.text.trim(),
        port: int.parse(_portController.text.trim()),
        password: _passwordController.text.trim().isEmpty ? null : _passwordController.text.trim(),
        lastConnected: DateTime.now(),
        autoConnect: false,
      );
      
      // 保存新配置
      await ref.read(connectionConfigProvider.notifier).addConfig(connectionConfig);
    }

    // 执行连接
    await ref.read(connectionManagerProvider.notifier).connect(connectionConfig);
  }

  Future<void> _requestPermissions() async {
    final status = await Permission.locationWhenInUse.request();
    if (status == PermissionStatus.granted) {
      setState(() {
        _showPermissionCard = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('权限已授予，自动发现功能已启用'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (status == PermissionStatus.permanentlyDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('权限被永久拒绝，请在设置中手动开启位置权限'),
          action: SnackBarAction(
            label: '打开设置',
            onPressed: () => openAppSettings(),
          ),
        ),
      );
    }
  }

  // 手动扫描设备
  Future<void> _scanForDevices() async {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
      _scanError = null;
      _discoveredDevices.clear();
    });

    try {
      final devices = await _discoveryService.scanOnce(timeout: const Duration(seconds: 8));
      setState(() {
        _discoveredDevices = devices;
        _isScanning = false;
      });

      if (devices.isEmpty) {
        setState(() {
          _scanError = '未发现任何设备，请确保PC端程序正在运行';
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('发现 ${devices.length} 个设备'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isScanning = false;
        _scanError = '扫描失败: $e';
      });
    }
  }

  // 连接到发现的设备
  Future<void> _connectToDiscoveredDevice(DiscoveredDevice device) async {
    final config = device.toConnectionConfig();
    await _connectToServer(config);
  }

  Widget _buildPermissionCard() {
    if (!_showPermissionCard) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '自动发现功能',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _showPermissionCard = false;
                    });
                  },
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '应用可以自动发现局域网内的PC设备。此功能需要位置权限来进行网络扫描。如果您不授予权限，仍可使用手动连接功能。',
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showPermissionCard = false;
                    });
                  },
                  child: const Text('稍后再说'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _requestPermissions,
                  child: const Text('授予权限'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceDiscoveryCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.radar,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '设备发现',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _isScanning ? null : _scanForDevices,
                  icon: _isScanning 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search, size: 18),
                  label: Text(_isScanning ? '扫描中...' : '扫描设备'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_scanError != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.error.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Theme.of(context).colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _scanError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_discoveredDevices.isNotEmpty) ...[
              Text(
                '发现的设备 (${_discoveredDevices.length})',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              ...(_discoveredDevices.map((device) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.computer,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    device.hostName,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${device.ipAddress}:${device.port}'),
                      Text(
                        '发现时间: ${_formatDiscoveryTime(device.discoveredAt)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  trailing: FilledButton(
                    onPressed: () => _connectToDiscoveredDevice(device),
                    child: const Text('连接'),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
              ))),
            ] else if (!_isScanning && _scanError == null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(
                      Icons.devices_other,
                      size: 48,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '点击"扫描设备"查找局域网内的PC',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDiscoveryTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inSeconds < 10) {
      return '刚刚';
    } else if (diff.inSeconds < 60) {
      return '${diff.inSeconds}秒前';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else {
      return '${diff.inHours}小时前';
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectionConfigs = ref.watch(connectionConfigProvider);
    final connectionStatus = ref.watch(connectionStatusProvider);
    final connectionManager = ref.watch(connectionManagerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('连接管理'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // 连接状态指示器
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getStatusIcon(connectionStatus),
                  color: _getStatusColor(connectionStatus),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _getStatusText(connectionStatus),
                  style: TextStyle(
                    color: _getStatusColor(connectionStatus),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 权限说明卡片
            _buildPermissionCard(),
            
            // 设备发现卡片
            _buildDeviceDiscoveryCard(),
            
            // 新连接表单
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '添加新连接',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: '连接名称',
                          hintText: '例如：我的电脑',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '请输入连接名称';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _ipController,
                        decoration: const InputDecoration(
                          labelText: 'IP地址',
                          hintText: '例如：192.168.1.100',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '请输入IP地址';
                          }
                          // 简单的IP地址格式验证
                          final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
                          if (!ipRegex.hasMatch(value.trim())) {
                            return '请输入有效的IP地址';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _portController,
                              decoration: const InputDecoration(
                                labelText: '端口',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return '请输入端口';
                                }
                                final port = int.tryParse(value.trim());
                                if (port == null || port < 1 || port > 65535) {
                                  return '请输入有效的端口 (1-65535)';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _passwordController,
                              decoration: const InputDecoration(
                                labelText: '密码 (可选)',
                                border: OutlineInputBorder(),
                              ),
                              obscureText: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: connectionManager.isLoading ? null : () => _connectToServer(),
                          child: connectionManager.isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('连接'),
                        ),
                      ),
                      // 显示连接错误
                      connectionManager.hasError
                          ? Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                '连接失败: ${connectionManager.error}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // 连接历史记录
            Text(
              '连接历史',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: connectionConfigs.isEmpty
                  ? const Center(
                      child: Text(
                        '暂无连接历史\n添加新连接开始使用',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: connectionConfigs.length,
                      itemBuilder: (context, index) {
                        final config = connectionConfigs[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.computer),
                            title: Text(config.name),
                            subtitle: Text('${config.ipAddress}:${config.port}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('删除连接'),
                                        content: Text('确定要删除连接 "${config.name}" 吗？'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(false),
                                            child: const Text('取消'),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(true),
                                            child: const Text('删除'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed == true) {
                                      await ref.read(connectionConfigProvider.notifier).removeConfig(config.id);
                                    }
                                  },
                                ),
                                FilledButton(
                                  onPressed: connectionManager.isLoading ? null : () => _connectToServer(config),
                                  child: const Text('连接'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return Icons.wifi;
      case ConnectionStatus.connecting:
        return Icons.wifi_tethering;
      case ConnectionStatus.disconnected:
        return Icons.wifi_off;
      case ConnectionStatus.error:
        return Icons.wifi_off;
    }
  }

  Color _getStatusColor(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return Colors.green;
      case ConnectionStatus.connecting:
        return Colors.orange;
      case ConnectionStatus.disconnected:
        return Colors.grey;
      case ConnectionStatus.error:
        return Colors.red;
    }
  }

  String _getStatusText(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return '已连接';
      case ConnectionStatus.connecting:
        return '连接中';
      case ConnectionStatus.disconnected:
        return '未连接';
      case ConnectionStatus.error:
        return '连接错误';
    }
  }
} 