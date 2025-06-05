import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 设置数据模型
class AppSettings {
  final bool hapticFeedback;
  final double mouseSensitivity;
  final bool autoReconnect;
  final ThemeMode themeMode;
  final bool showConnectionDialog;
  final int connectionTimeout;

  const AppSettings({
    this.hapticFeedback = true,
    this.mouseSensitivity = 1.0,
    this.autoReconnect = true,
    this.themeMode = ThemeMode.system,
    this.showConnectionDialog = true,
    this.connectionTimeout = 10,
  });

  AppSettings copyWith({
    bool? hapticFeedback,
    double? mouseSensitivity,
    bool? autoReconnect,
    ThemeMode? themeMode,
    bool? showConnectionDialog,
    int? connectionTimeout,
  }) {
    return AppSettings(
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
      mouseSensitivity: mouseSensitivity ?? this.mouseSensitivity,
      autoReconnect: autoReconnect ?? this.autoReconnect,
      themeMode: themeMode ?? this.themeMode,
      showConnectionDialog: showConnectionDialog ?? this.showConnectionDialog,
      connectionTimeout: connectionTimeout ?? this.connectionTimeout,
    );
  }
}

// 设置状态管理器
class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) {
    _loadSettings();
  }

  static const String _hapticFeedbackKey = 'haptic_feedback';
  static const String _mouseSensitivityKey = 'mouse_sensitivity';
  static const String _autoReconnectKey = 'auto_reconnect';
  static const String _themeModeKey = 'theme_mode';
  static const String _showConnectionDialogKey = 'show_connection_dialog';
  static const String _connectionTimeoutKey = 'connection_timeout';

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    state = AppSettings(
      hapticFeedback: prefs.getBool(_hapticFeedbackKey) ?? true,
      mouseSensitivity: prefs.getDouble(_mouseSensitivityKey) ?? 1.0,
      autoReconnect: prefs.getBool(_autoReconnectKey) ?? true,
      themeMode: ThemeMode.values[prefs.getInt(_themeModeKey) ?? 0],
      showConnectionDialog: prefs.getBool(_showConnectionDialogKey) ?? true,
      connectionTimeout: prefs.getInt(_connectionTimeoutKey) ?? 10,
    );
  }

  Future<void> updateHapticFeedback(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hapticFeedbackKey, enabled);
    state = state.copyWith(hapticFeedback: enabled);
    
    if (enabled) {
      HapticFeedback.lightImpact();
    }
  }

  Future<void> updateMouseSensitivity(double sensitivity) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_mouseSensitivityKey, sensitivity);
    state = state.copyWith(mouseSensitivity: sensitivity);
  }

  Future<void> updateAutoReconnect(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoReconnectKey, enabled);
    state = state.copyWith(autoReconnect: enabled);
  }

  Future<void> updateThemeMode(ThemeMode themeMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeModeKey, themeMode.index);
    state = state.copyWith(themeMode: themeMode);
  }

  Future<void> updateShowConnectionDialog(bool show) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showConnectionDialogKey, show);
    state = state.copyWith(showConnectionDialog: show);
  }

  Future<void> updateConnectionTimeout(int timeout) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_connectionTimeoutKey, timeout);
    state = state.copyWith(connectionTimeout: timeout);
  }

  Future<void> resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    state = const AppSettings();
    HapticFeedback.mediumImpact();
  }
}

// Provider定义
final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>(
  (ref) => SettingsNotifier(),
);

// 设置页面UI
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface, // 统一背景色
      body: _buildSettingsInterface(context, settings, settingsNotifier),
    );
  }

  /// 应用设置页面 - 完整的设置管理体验
  Widget _buildSettingsInterface(BuildContext context, AppSettings settings, SettingsNotifier settingsNotifier) {
    return CustomScrollView(
      slivers: [
        // 设置头部
        SliverToBoxAdapter(
          child: _buildSettingsHeader(context),
        ),
        
        // 原有设置内容
        SliverToBoxAdapter(
          child: _buildOldSettings(context, settings, settingsNotifier),
        ),
        
        // 底部间距
        const SliverToBoxAdapter(
          child: SizedBox(height: 100),
        ),
      ],
    );
  }

  /// 设置页面头部
  Widget _buildSettingsHeader(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF607D8B).withOpacity(0.1),
            const Color(0xFF455A64).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF607D8B).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // 设置图标
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF607D8B).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.settings_rounded,
              color: Color(0xFF607D8B),
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
                  '应用设置',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF607D8B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '个性化您的掌控者体验',
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

  Widget _buildOldSettings(BuildContext context, AppSettings settings, SettingsNotifier settingsNotifier) {
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        // 外观设置
        _buildSectionCard(
          context,
          title: '外观设置',
          icon: Icons.palette_outlined,
          children: [
            _buildThemeSelector(context, settings, settingsNotifier),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // 控制设置
        _buildSectionCard(
          context,
          title: '控制设置',
          icon: Icons.settings_input_component_outlined,
          children: [
            _buildSwitchTile(
              context,
              title: '触觉反馈',
              subtitle: '操作时提供振动反馈',
              value: settings.hapticFeedback,
              onChanged: settingsNotifier.updateHapticFeedback,
              icon: Icons.vibration,
            ),
            const Divider(height: 1),
            _buildSensitivitySlider(context, settings, settingsNotifier),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // 连接设置
        _buildSectionCard(
          context,
          title: '连接设置',
          icon: Icons.wifi_outlined,
          children: [
            _buildSwitchTile(
              context,
              title: '自动重连',
              subtitle: '连接断开时自动尝试重连',
              value: settings.autoReconnect,
              onChanged: settingsNotifier.updateAutoReconnect,
              icon: Icons.sync,
            ),
            const Divider(height: 1),
            _buildSwitchTile(
              context,
              title: '显示连接对话框',
              subtitle: '连接时显示进度对话框',
              value: settings.showConnectionDialog,
              onChanged: settingsNotifier.updateShowConnectionDialog,
              icon: Icons.chat_bubble_outline,
            ),
            const Divider(height: 1),
            _buildTimeoutSelector(context, settings, settingsNotifier),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // 关于和操作
        _buildSectionCard(
          context,
          title: '关于',
          icon: Icons.info_outline,
          children: [
            ListTile(
              leading: const Icon(Icons.apps),
              title: const Text('应用版本'),
              subtitle: const Text('v1.0.0-alpha'),
              onTap: () {
                _showAboutDialog(context);
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.refresh, color: Theme.of(context).colorScheme.primary),
              title: Text(
                '恢复默认设置',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
              subtitle: const Text('重置所有设置为默认值'),
              onTap: () => _showResetDialog(context, settingsNotifier),
            ),
          ],
        ),
        
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required IconData icon,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildThemeSelector(
    BuildContext context,
    AppSettings settings,
    SettingsNotifier notifier,
  ) {
    return ListTile(
      leading: const Icon(Icons.brightness_6),
      title: const Text('主题模式'),
      subtitle: Text(_getThemeModeText(settings.themeMode)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () => _showThemeModeDialog(context, settings, notifier),
    );
  }

  Widget _buildSensitivitySlider(
    BuildContext context,
    AppSettings settings,
    SettingsNotifier notifier,
  ) {
    return ListTile(
      leading: const Icon(Icons.tune),
      title: const Text('鼠标灵敏度'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${(settings.mouseSensitivity * 100).round()}%'),
          const SizedBox(height: 8),
          Slider(
            value: settings.mouseSensitivity,
            min: 0.1,
            max: 3.0,
            divisions: 29,
            onChanged: notifier.updateMouseSensitivity,
          ),
        ],
      ),
    );
  }

  Widget _buildTimeoutSelector(
    BuildContext context,
    AppSettings settings,
    SettingsNotifier notifier,
  ) {
    return ListTile(
      leading: const Icon(Icons.timer),
      title: const Text('连接超时'),
      subtitle: Text('${settings.connectionTimeout}秒'),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () => _showTimeoutDialog(context, settings, notifier),
    );
  }

  String _getThemeModeText(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.light:
        return '浅色模式';
      case ThemeMode.dark:
        return '深色模式';
      case ThemeMode.system:
        return '跟随系统';
    }
  }

  void _showThemeModeDialog(
    BuildContext context,
    AppSettings settings,
    SettingsNotifier notifier,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择主题模式'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ThemeMode.values.map((mode) {
            return RadioListTile<ThemeMode>(
              title: Text(_getThemeModeText(mode)),
              value: mode,
              groupValue: settings.themeMode,
              onChanged: (value) {
                if (value != null) {
                  notifier.updateThemeMode(value);
                  Navigator.of(context).pop();
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  void _showTimeoutDialog(
    BuildContext context,
    AppSettings settings,
    SettingsNotifier notifier,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择连接超时时间'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [5, 10, 15, 20, 30].map((timeout) {
            return RadioListTile<int>(
              title: Text('$timeout秒'),
              value: timeout,
              groupValue: settings.connectionTimeout,
              onChanged: (value) {
                if (value != null) {
                  notifier.updateConnectionTimeout(value);
                  Navigator.of(context).pop();
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context, SettingsNotifier notifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('恢复默认设置'),
        content: const Text('确定要重置所有设置为默认值吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              notifier.resetToDefaults();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('设置已重置为默认值')),
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: '掌控者',
      applicationVersion: 'v1.0.0-alpha',
      applicationIcon: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          Icons.touch_app,
          color: Theme.of(context).colorScheme.onPrimary,
          size: 32,
        ),
      ),
      children: [
        const Text('轻便快捷的手机端遥控PC工具'),
        const SizedBox(height: 16),
        const Text('功能特色：'),
        const Text('• 鼠标控制 - 触摸板手势操作'),
        const Text('• 键盘输入 - 虚拟键盘和快捷键'),
        const Text('• 媒体控制 - 播放、音量调节'),
        const Text('• 系统控制 - 电源管理、演示助手'),
      ],
    );
  }
} 

