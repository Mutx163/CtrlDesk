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
    if (!mounted) return;
    
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
      if (!mounted) return;
      if (!mounted) return;
      setState(() {
        _discoveredDevices = devices;
        _isScanning = false;
      });

      if (devices.isEmpty) {
        if (!mounted) return;
        setState(() {
          _scanError = '未发现任何设备，请确保PC端程序正在运行';
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('发现 ${devices.length} 个设备'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
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





  @override
  Widget build(BuildContext context) {
    final connectionStatus = ref.watch(connectionStatusProvider);

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
      body: _buildSmartConnectionView(context),
    );
  }

  /// 智能连接界面
  Widget _buildSmartConnectionView(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // 头部标题
        SliverToBoxAdapter(
          child: _buildConnectionHeader(context),
        ),
        
        // 权限卡片
        SliverToBoxAdapter(
          child: _buildPermissionCard(),
        ),
        
        // 设备发现区域
        SliverToBoxAdapter(
          child: _buildDeviceDiscoverySection(context),
        ),
        
        // 手动连接表单
        SliverToBoxAdapter(
          child: _buildManualConnectionForm(context),
        ),
        
        // 连接历史
        SliverToBoxAdapter(
          child: _buildConnectionHistory(context),
        ),
        
        // 底部间距
        const SliverToBoxAdapter(
          child: SizedBox(height: 100),
        ),
      ],
    );
  }

  /// 连接头部
  Widget _buildConnectionHeader(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.green.withOpacity(0.1),
            Colors.orange.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.green.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // 连接图标
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.wifi_rounded,
              color: Colors.green,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          
          // 标题和描述
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '智能连接',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '自动发现和连接您的Windows PC',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 设备发现区域
  Widget _buildDeviceDiscoverySection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.green.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.radar_rounded,
                color: Colors.green,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '自动发现',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const Spacer(),
              if (_isScanning)
                Container(
                  width: 20,
                  height: 20,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              else
                FilledButton.icon(
                  onPressed: _scanForDevices,
                  icon: const Icon(Icons.search_rounded, size: 16),
                  label: const Text('扫描设备'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 发现的设备列表
          if (_discoveredDevices.isNotEmpty)
            ...(_discoveredDevices.map((device) => _buildDiscoveredDeviceCard(device)).toList())
          else if (_scanError != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _scanError!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            )
          else if (!_isScanning)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '点击"扫描设备"自动发现网络中的PC',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

    /// 手动连接表单
  Widget _buildManualConnectionForm(BuildContext context) {
    final connectionManager = ref.watch(connectionManagerProvider);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.orange.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.input_rounded,
                  color: Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '手动连接',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 连接名称
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: '连接名称',
                hintText: '例如：我的电脑',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入连接名称';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // IP地址
            TextFormField(
              controller: _ipController,
              decoration: InputDecoration(
                labelText: 'IP地址',
                hintText: '例如：192.168.1.100',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入IP地址';
                }
                final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
                if (!ipRegex.hasMatch(value.trim())) {
                  return '请输入有效的IP地址';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // 端口和密码
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _portController,
                    decoration: InputDecoration(
                      labelText: '端口',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                    decoration: InputDecoration(
                      labelText: '密码 (可选)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    obscureText: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // 连接按钮
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: connectionManager.isLoading ? null : () => _connectToServer(),
                icon: connectionManager.isLoading 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.link_rounded),
                label: Text(connectionManager.isLoading ? '连接中...' : '连接'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            
            // 连接错误显示
            if (connectionManager.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '连接失败: ${connectionManager.error}',
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 连接历史
  Widget _buildConnectionHistory(BuildContext context) {
    final connectionConfigs = ref.watch(connectionConfigProvider);
    final connectionManager = ref.watch(connectionManagerProvider);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.blue.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.history_rounded,
                color: Colors.blue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '连接历史',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 历史记录列表
          if (connectionConfigs.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '暂无连接历史，添加新连接开始使用',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: connectionConfigs.map((config) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.computer, color: Colors.blue, size: 20),
                  ),
                  title: Text(
                    config.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('${config.ipAddress}:${config.port}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
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
                      FilledButton.icon(
                        onPressed: connectionManager.isLoading ? null : () => _connectToServer(config),
                        icon: const Icon(Icons.link_rounded, size: 16),
                        label: const Text('连接'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ),
              )).toList(),
            ),
        ],
      ),
    );
  }

  /// 发现的设备卡片
  Widget _buildDiscoveredDeviceCard(DiscoveredDevice device) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.computer, color: Colors.green, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                   device.hostName,
                   style: const TextStyle(
                     fontWeight: FontWeight.bold,
                     color: Colors.green,
                   ),
                 ),
                Text(
                  '${device.ipAddress}:${device.port}',
                  style: TextStyle(
                    color: Colors.green.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: () => _connectToDiscoveredDevice(device),
            icon: const Icon(Icons.link_rounded, size: 16),
            label: const Text('连接'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
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

