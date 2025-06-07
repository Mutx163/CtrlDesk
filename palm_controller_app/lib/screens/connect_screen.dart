import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import '../models/connection_config.dart';
import '../providers/connection_provider.dart';
import '../services/socket_service.dart';
import '../services/discovery_service.dart';
import '../services/log_service.dart';

class ConnectScreen extends ConsumerStatefulWidget {
  const ConnectScreen({super.key});

  @override
  ConsumerState<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends ConsumerState<ConnectScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '8080');
  final _passwordController = TextEditingController();
  final _uuid = const Uuid();
  
  // 设备发现相关状态
  final DiscoveryService _discoveryService = DiscoveryService();
  List<DiscoveredDevice> _discoveredDevices = [];
  bool _isRealTimeScanning = false;
  bool _isConnecting = false;
  String? _scanError;
  String? _connectingToDevice;
  Timer? _realTimeScanTimer;
  
  // 权限和UI状态
  bool _showPermissionCard = true;
  bool _showManualForm = false;
  
  // 动画控制器
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    // 初始化动画
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    ));
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return; // 安全检查：Widget是否仍然mounted
      
      // 设置导航回调 - 使用安全的context访问模式
      ref.read(connectionManagerProvider.notifier).setNavigationCallback(() {
        // 双重安全检查：mounted状态和context有效性
        if (!mounted) return;
        if (!context.mounted) return;
        
        try {
          if (context.canPop()) {
            // 如果可以返回，说明是从其他页面进入的连接页面，直接返回
            context.pop();
          } else {
            // 否则导航到控制界面
            context.go('/');
          }
        } catch (e) {
          // 捕获context访问异常，记录但不中断程序
          LogService.instance.error('Navigation callback context access error: $e', category: 'Connect');
        }
      });
      
      // 检查权限状态，决定是否显示权限卡片
      _checkPermissionStatus();
      
      // 开始实时设备发现
      _startRealTimeDiscovery();
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _realTimeScanTimer?.cancel();
    _discoveryService.stopDiscovery();
    _nameController.dispose();
    _ipController.dispose();
    _portController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 检查权限状态
  Future<void> _checkPermissionStatus() async {
    final status = await Permission.locationWhenInUse.status;
    if (mounted) {
      setState(() {
        _showPermissionCard = status != PermissionStatus.granted;
      });
    }
  }

  // 请求权限
  Future<void> _requestPermissions() async {
    final status = await Permission.locationWhenInUse.request();
    if (!mounted) return;
    
    if (status == PermissionStatus.granted) {
      setState(() {
        _showPermissionCard = false;
      });
      // 安全的SnackBar显示
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('权限已授予，设备发现功能已启用'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
      // 权限获取后重新开始实时扫描
      _startRealTimeDiscovery();
    } else if (status == PermissionStatus.permanentlyDenied) {
      // 安全的权限拒绝提示
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('权限被永久拒绝，请在设置中手动开启位置权限'),
            action: SnackBarAction(
              label: '打开设置',
              onPressed: () => openAppSettings(),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  // 开始实时设备发现
  void _startRealTimeDiscovery() async {
    if (_isRealTimeScanning) return;
    
    setState(() {
      _isRealTimeScanning = true;
      _scanError = null;
    });

    LogService.instance.info('开始实时设备发现', category: 'Connect');
    
    // 立即进行一次扫描
    await _performSingleScan();
    
    // 启动定时器，每5秒扫描一次
    _realTimeScanTimer = Timer.periodic(const Duration(seconds: 8), (timer) async {
      if (mounted && _isRealTimeScanning) {
        await _performSingleScan();
      } else {
        timer.cancel();
      }
    });
  }

  // 停止实时发现
  void _stopRealTimeDiscovery() {
    setState(() {
      _isRealTimeScanning = false;
    });
    _realTimeScanTimer?.cancel();
    LogService.instance.info('停止实时设备发现', category: 'Connect');
  }

  // 执行单次扫描
  Future<void> _performSingleScan() async {
    try {
      final devices = await _discoveryService.scanOnce(timeout: const Duration(seconds: 4));
      if (!mounted) return;
      
      setState(() {
        _discoveredDevices = devices;
        _scanError = devices.isEmpty ? '未发现设备，请确保PC端程序正在运行' : null;
      });
      
      LogService.instance.info('发现 ${devices.length} 个设备', category: 'Connect');
    } catch (e) {
      if (!mounted) return;
      LogService.instance.warning('设备扫描失败: $e', category: 'Connect');
      setState(() {
        _scanError = '扫描失败: $e';
      });
    }
  }

  // 手动刷新设备列表
  Future<void> _refreshDevices() async {
    await _performSingleScan();
    // 安全的刷新结果提示
    if (mounted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('发现 ${_discoveredDevices.length} 个设备'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  // 连接到发现的设备
  Future<void> _connectToDiscoveredDevice(DiscoveredDevice device) async {
    if (_isConnecting || !mounted) return; // 增加mounted检查

    setState(() {
      _isConnecting = true;
      _connectingToDevice = device.hostName;
    });

    try {
      final config = device.toConnectionConfig();
      LogService.instance.info('尝试连接到发现的设备: ${device.hostName} (${device.ipAddress})', category: 'Connect');
      
      await ref.read(connectionManagerProvider.notifier).connect(config);
      
      // 等待连接结果，但添加超时保护
      final result = ref.read(connectionManagerProvider);
      
      if (result.value == true) {
        LogService.instance.info('连接成功: ${device.hostName}', category: 'Connect');
        // 安全的SnackBar显示 - 检查mounted和context状态
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已连接到 ${device.hostName}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // 安全的错误提示
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('连接失败: ${device.hostName}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      LogService.instance.error('连接异常: $e', category: 'Connect');
      // 安全的异常提示
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('连接异常: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // 最终清理状态时也要检查mounted
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _connectingToDevice = null;
        });
      }
    }
  }

  // 手动连接
  Future<void> _connectManually() async {
    if (!_formKey.currentState!.validate() || _isConnecting || !mounted) return; // 增加mounted检查

    setState(() {
      _isConnecting = true;
    });

    try {
      final config = ConnectionConfig(
        id: _uuid.v4(),
        name: _nameController.text.trim().isEmpty ? 
              '${_ipController.text}:${_portController.text}' : 
              _nameController.text.trim(),
        ipAddress: _ipController.text.trim(),
        port: int.parse(_portController.text.trim()),
        password: _passwordController.text.trim().isEmpty ? null : _passwordController.text.trim(),
        lastConnected: DateTime.now(),
        autoConnect: true,
      );

      LogService.instance.info('尝试手动连接到: ${config.ipAddress}:${config.port}', category: 'Connect');
      
      await ref.read(connectionManagerProvider.notifier).connect(config);
      final result = ref.read(connectionManagerProvider);
      
      if (result.value == true) {
        LogService.instance.info('手动连接成功: ${config.name}', category: 'Connect');
        // 安全的成功提示和界面操作
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已连接到 ${config.name}'),
              backgroundColor: Colors.green,
            ),
          );
          // 收起手动输入表单
          _toggleManualForm();
        }
      } else {
        // 安全的失败提示
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('连接失败: ${config.name}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      LogService.instance.error('手动连接异常: $e', category: 'Connect');
      // 安全的异常提示
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('连接异常: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // 安全的状态清理
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  // 断开当前连接
  Future<void> _disconnect() async {
    try {
      await ref.read(connectionManagerProvider.notifier).disconnect();
      // 安全的断开连接提示
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已断开连接'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      LogService.instance.error('断开连接失败: $e', category: 'Connect');
    }
  }

  // 切换手动输入表单显示状态
  void _toggleManualForm() {
    setState(() {
      _showManualForm = !_showManualForm;
    });
    
    if (_showManualForm) {
      _slideController.forward();
    } else {
      _slideController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectionStatus = ref.watch(connectionStatusProvider);
    final currentConnection = ref.watch(currentConnectionProvider);
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('连接管理'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // 实时扫描开关
          IconButton(
            icon: Icon(
              _isRealTimeScanning ? Icons.pause : Icons.play_arrow,
              color: _isRealTimeScanning ? Colors.green : null,
            ),
            onPressed: () {
              if (_isRealTimeScanning) {
                _stopRealTimeDiscovery();
              } else {
                _startRealTimeDiscovery();
              }
            },
            tooltip: _isRealTimeScanning ? '停止实时发现' : '开始实时发现',
          ),
          // 手动刷新
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshDevices,
            tooltip: '刷新设备列表',
          ),
        ],
      ),
      body: Column(
        children: [
          // 权限提示卡片
          if (_showPermissionCard) _buildPermissionCard(),
          
          // 当前连接状态
          if (connectionStatus == ConnectionStatus.connected) _buildCurrentConnectionCard(currentConnection),
          
          // 设备发现区域
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildDiscoverySection(),
                const SizedBox(height: 16),
                _buildHistorySection(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggleManualForm,
        icon: Icon(_showManualForm ? Icons.close : Icons.add),
        label: Text(_showManualForm ? '取消' : '手动添加'),
        backgroundColor: _showManualForm ? Colors.grey : theme.colorScheme.primary,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomSheet: _showManualForm ? _buildManualConnectSheet() : null,
    );
  }

  // 构建权限提示卡片
  Widget _buildPermissionCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        color: Colors.orange.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.location_on, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '需要位置权限以发现设备',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _showPermissionCard = false),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text('自动发现局域网设备需要位置权限。如果不授予权限，您仍可使用手动连接功能。'),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => setState(() => _showPermissionCard = false),
                    child: const Text('跳过'),
                  ),
                  FilledButton(
                    onPressed: _requestPermissions,
                    child: const Text('授予权限'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 构建当前连接状态卡片
  Widget _buildCurrentConnectionCard(ConnectionConfig? connection) {
    if (connection == null) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        color: Colors.green.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.computer, color: Colors.green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connection.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    Text(
                      '${connection.ipAddress}:${connection.port}',
                      style: TextStyle(
                        color: Colors.green.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _disconnect,
                child: const Text('断开'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 构建设备发现区域
  Widget _buildDiscoverySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.radar,
                  color: _isRealTimeScanning ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  '发现的设备',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_isRealTimeScanning)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (_discoveredDevices.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.devices_other,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _scanError ?? '正在搜索设备...',
                      style: TextStyle(color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ...(_discoveredDevices.map((device) => _buildDeviceCard(device)).toList()),
          ],
        ),
      ),
    );
  }

  // 构建设备卡片
  Widget _buildDeviceCard(DiscoveredDevice device) {
    final isConnecting = _isConnecting && _connectingToDevice == device.hostName;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: 0,
        color: Colors.blue.shade50,
        child: InkWell(
          onTap: isConnecting ? null : () => _connectToDiscoveredDevice(device),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.computer, color: Colors.blue),
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
                          color: Colors.blue,
                        ),
                      ),
                      Text(
                        '${device.ipAddress}:${device.port}',
                        style: TextStyle(
                          color: Colors.blue.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isConnecting)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.blue),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 构建历史连接区域
  Widget _buildHistorySection() {
    final configs = ref.watch(connectionConfigProvider);
    
    if (configs.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '历史连接',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...configs.take(5).map((config) => _buildHistoryCard(config)).toList(),
          ],
        ),
      ),
    );
  }

  // 构建历史连接卡片
  Widget _buildHistoryCard(ConnectionConfig config) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: 0,
        color: Colors.grey.shade50,
        child: InkWell(
          onTap: _isConnecting ? null : () => _connectToHistoryConfig(config),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.history, color: Colors.grey),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        config.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${config.ipAddress}:${config.port}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 连接到历史配置
  Future<void> _connectToHistoryConfig(ConnectionConfig config) async {
    if (_isConnecting) return;

    setState(() {
      _isConnecting = true;
    });

    try {
      LogService.instance.info('尝试连接到历史配置: ${config.name}', category: 'Connect');
      
      await ref.read(connectionManagerProvider.notifier).connect(config);
      final result = ref.read(connectionManagerProvider);
      
      if (result.value == true) {
        LogService.instance.info('连接成功: ${config.name}', category: 'Connect');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已连接到 ${config.name}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('连接失败: ${config.name}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      LogService.instance.error('连接历史配置异常: $e', category: 'Connect');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('连接异常: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  // 构建手动连接表单
  Widget _buildManualConnectSheet() {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.add_circle_outline),
                    const SizedBox(width: 8),
                    Text(
                      '手动添加设备',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '设备名称（可选）',
                    hintText: '例如：办公室电脑',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                ),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _ipController,
                        decoration: const InputDecoration(
                          labelText: 'IP地址',
                          hintText: '192.168.1.100',
                          prefixIcon: Icon(Icons.computer),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'IP地址不能为空';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _portController,
                        decoration: const InputDecoration(
                          labelText: '端口',
                          prefixIcon: Icon(Icons.numbers),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '端口不能为空';
                          }
                          final port = int.tryParse(value.trim());
                          if (port == null || port < 1 || port > 65535) {
                            return '无效端口';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: '密码（可选）',
                    hintText: '如果服务器设置了密码',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 32),
                
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isConnecting ? null : _connectManually,
                    child: _isConnecting
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 8),
                              Text('连接中...'),
                            ],
                          )
                        : const Text('连接'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 输入验证方法
  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName不能为空';
    }
    return null;
  }

  String? _validatePort(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '端口不能为空';
    }
    final port = int.tryParse(value.trim());
    if (port == null || port < 1 || port > 65535) {
      return '端口必须是1-65535之间的数字';
    }
    return null;
  }
} 

