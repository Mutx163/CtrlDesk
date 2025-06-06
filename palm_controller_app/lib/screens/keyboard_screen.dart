import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/connection_provider.dart';
import '../services/socket_service.dart';
import '../models/control_message.dart';

class KeyboardScreen extends ConsumerStatefulWidget {
  const KeyboardScreen({super.key});

  @override
  ConsumerState<KeyboardScreen> createState() => _KeyboardScreenState();
}

class _KeyboardScreenState extends ConsumerState<KeyboardScreen> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  bool _isCtrlPressed = false;
  bool _isShiftPressed = false;
  bool _isAltPressed = false;

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendKeyboardMessage(ControlMessage message) {
    final socketService = ref.read(socketServiceProvider);
    socketService.sendMessage(message);
  }

  void _sendText(String text) {
    if (text.isNotEmpty) {
      final message = ControlMessage.keyboardControl(
        messageId: DateTime.now().millisecondsSinceEpoch.toString(),
        action: 'text_input',
        text: text,
      );
      _sendKeyboardMessage(message);
      
      // 提供触觉反馈
      HapticFeedback.lightImpact();
    }
  }

  void _sendKey(String keyCode, {List<String>? modifiers}) {
    final bool useCurrentModifiers = modifiers == null;
    modifiers ??= _getCurrentModifiers();
    final message = ControlMessage.keyboardControl(
      messageId: DateTime.now().millisecondsSinceEpoch.toString(),
      action: 'key_press',
      keyCode: keyCode,
      modifiers: modifiers,
    );
    _sendKeyboardMessage(message);
    
    // 提供触觉反馈
    HapticFeedback.lightImpact();
    
    // 只有在使用当前修饰键状态时才自动清除（模拟真实键盘行为）
    // 快捷键（显式传递修饰键）不会清除切换状态
    if (useCurrentModifiers && modifiers.isNotEmpty) {
      _clearModifierKeys();
    }
  }

  List<String> _getCurrentModifiers() {
    List<String> modifiers = [];
    if (_isCtrlPressed) modifiers.add('ctrl');
    if (_isShiftPressed) modifiers.add('shift');
    if (_isAltPressed) modifiers.add('alt');
    return modifiers;
  }

  void _clearModifierKeys() {
    setState(() {
      _isCtrlPressed = false;
      _isShiftPressed = false;
      _isAltPressed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final connectionStatus = ref.watch(connectionStatusProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface, // 统一背景色
      body: connectionStatus == ConnectionStatus.connected
          ? _buildKeyboardInputter(context)
          : _buildNotConnectedView(),
    );
  }

  /// 键盘输入器 - 完整的键盘控制体验
  Widget _buildKeyboardInputter(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // 头部标题
        SliverToBoxAdapter(
          child: _buildKeyboardHeader(context),
        ),
        
        // 主要文本输入区域
        SliverToBoxAdapter(
          child: _buildMainInputArea(context),
        ),
        
        // 修饰键控制面板
        SliverToBoxAdapter(
          child: _buildModifierPanel(context),
        ),
        
        // 快捷键网格
        SliverToBoxAdapter(
          child: _buildShortcutGrid(context),
        ),
        
        // 功能键面板
        SliverToBoxAdapter(
          child: _buildFunctionPanel(context),
        ),
        
        // 方向键控制
        SliverToBoxAdapter(
          child: _buildDirectionControl(context),
        ),
        
        // 底部间距
        const SliverToBoxAdapter(
          child: SizedBox(height: 100),
        ),
      ],
    );
  }

  /// 键盘头部
  Widget _buildKeyboardHeader(BuildContext context) {
    final currentConnection = ref.watch(currentConnectionProvider);
    
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF3F51B5).withAlpha((0.1 * 255).round()),
            const Color(0xFF303F9F).withAlpha((0.05 * 255).round()),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF3F51B5).withAlpha((0.2 * 255).round()),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // 键盘图标
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF3F51B5).withAlpha((0.1 * 255).round()),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.keyboard_rounded,
              color: Color(0xFF3F51B5),
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
                  '键盘输入器',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF3F51B5),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      currentConnection?.name ?? 'Windows PC',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withAlpha((0.7 * 255).round()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 主要输入区域
  Widget _buildMainInputArea(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF3F51B5).withAlpha((0.2 * 255).round()),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3F51B5).withAlpha((0.1 * 255).round()),
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
                Icons.edit_rounded,
                color: const Color(0xFF3F51B5),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '文本输入',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF3F51B5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 输入框
          TextField(
            controller: _textController,
            focusNode: _focusNode,
            decoration: InputDecoration(
              hintText: '在此输入文本，回车发送到PC...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: const Color(0xFF3F51B5).withAlpha((0.3 * 255).round())),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF3F51B5), width: 2),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
            maxLines: 3,
            onSubmitted: (text) {
              _sendText(text);
              _textController.clear();
            },
          ),
          const SizedBox(height: 16),
          
          // 发送按钮
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                final text = _textController.text;
                if (text.isNotEmpty) {
                  _sendText(text);
                  _textController.clear();
                }
              },
              icon: const Icon(Icons.send_rounded),
              label: const Text('发送文本'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF3F51B5).withAlpha((0.1 * 255).round()),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 修饰键面板
  Widget _buildModifierPanel(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF3F51B5).withAlpha((0.2 * 255).round()),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3F51B5).withAlpha((0.1 * 255).round()),
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
                Icons.keyboard_alt_rounded,
                color: const Color(0xFF3F51B5),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '修饰键',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF3F51B5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildModifierKey('Ctrl', _isCtrlPressed, () {
                  setState(() {
                    _isCtrlPressed = !_isCtrlPressed;
                  });
                }),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildModifierKey('Shift', _isShiftPressed, () {
                  setState(() {
                    _isShiftPressed = !_isShiftPressed;
                  });
                }),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildModifierKey('Alt', _isAltPressed, () {
                  setState(() {
                    _isAltPressed = !_isAltPressed;
                  });
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 修饰键按钮
  Widget _buildModifierKey(String label, bool isPressed, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isPressed ? const Color(0xFF3F51B5).withAlpha((0.1 * 255).round()) : const Color(0xFF3F51B5).withAlpha((0.1 * 255).round()),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF3F51B5).withAlpha((isPressed ? 0.3 : 0.1 * 255).round()),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isPressed ? Colors.white : const Color(0xFF3F51B5),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  /// 快捷键网格
  Widget _buildShortcutGrid(BuildContext context) {
    final shortcuts = [
      {'label': '复制', 'keys': ['ctrl', 'c'], 'icon': Icons.copy_rounded},
      {'label': '粘贴', 'keys': ['ctrl', 'v'], 'icon': Icons.paste_rounded},
      {'label': '剪切', 'keys': ['ctrl', 'x'], 'icon': Icons.cut_rounded},
      {'label': '撤销', 'keys': ['ctrl', 'z'], 'icon': Icons.undo_rounded},
      {'label': '全选', 'keys': ['ctrl', 'a'], 'icon': Icons.select_all_rounded},
      {'label': '保存', 'keys': ['ctrl', 's'], 'icon': Icons.save_rounded},
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF3F51B5).withAlpha((0.2 * 255).round()),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.flash_on_rounded,
                color: const Color(0xFF3F51B5),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '常用快捷键',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF3F51B5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.0,
            ),
            itemCount: shortcuts.length,
            itemBuilder: (context, index) {
              final shortcut = shortcuts[index];
              return _buildShortcutButton(
                icon: shortcut['icon'] as IconData,
                label: shortcut['label'] as String,
                onPressed: () => _sendKey(
                  (shortcut['keys'] as List<String>)[1],
                  modifiers: [(shortcut['keys'] as List<String>)[0]],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// 功能键面板
  Widget _buildFunctionPanel(BuildContext context) {
    final functionKeys = ['F1', 'F2', 'F3', 'F4', 'F5', 'F6', 'F7', 'F8', 'F9', 'F10', 'F11', 'F12'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF3F51B5).withAlpha((0.2 * 255).round()),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.functions_rounded,
                color: const Color(0xFF3F51B5),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '功能键',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF3F51B5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.5,
            ),
            itemCount: functionKeys.length,
            itemBuilder: (context, index) {
              return _buildFunctionKeyButton(functionKeys[index]);
            },
          ),
        ],
      ),
    );
  }

  /// 方向键控制
  Widget _buildDirectionControl(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF3F51B5).withAlpha((0.2 * 255).round()),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.keyboard_arrow_up_rounded,
                color: const Color(0xFF3F51B5),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '方向键 & 特殊键',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF3F51B5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            children: [
              // 上方向键
              _buildDirectionKey(Icons.keyboard_arrow_up_rounded, () => _sendKey('ArrowUp')),
              const SizedBox(height: 8),
              // 左右方向键
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildDirectionKey(Icons.keyboard_arrow_left_rounded, () => _sendKey('ArrowLeft')),
                  _buildDirectionKey(Icons.keyboard_arrow_down_rounded, () => _sendKey('ArrowDown')),
                  _buildDirectionKey(Icons.keyboard_arrow_right_rounded, () => _sendKey('ArrowRight')),
                ],
              ),
              const SizedBox(height: 16),
              // 特殊键
              Row(
                children: [
                  Expanded(child: _buildSpecialKey('Enter', () => _sendKey('Enter'))),
                  const SizedBox(width: 8),
                  Expanded(child: _buildSpecialKey('Space', () => _sendKey(' '))),
                  const SizedBox(width: 8),
                  Expanded(child: _buildSpecialKey('Backspace', () => _sendKey('Backspace'))),
                  const SizedBox(width: 8),
                  Expanded(child: _buildSpecialKey('Tab', () => _sendKey('Tab'))),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 快捷键按钮
  Widget _buildShortcutButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: const Color(0xFF3F51B5).withAlpha((0.1 * 255).round()),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xFF3F51B5), size: 16),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF3F51B5),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 功能键按钮
  Widget _buildFunctionKeyButton(String key) {
    return Material(
      color: const Color(0xFF3F51B5).withAlpha((0.1 * 255).round()),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => _sendKey(key),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Center(
            child: Text(
              key,
              style: const TextStyle(
                color: Color(0xFF3F51B5),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 方向键按钮
  Widget _buildDirectionKey(IconData icon, VoidCallback onPressed) {
    return Material(
      color: const Color(0xFF3F51B5).withAlpha((0.1 * 255).round()),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Icon(icon, color: const Color(0xFF3F51B5), size: 24),
          ),
        ),
      ),
    );
  }

  /// 特殊键按钮
  Widget _buildSpecialKey(String label, VoidCallback onPressed) {
    return Material(
      color: const Color(0xFF3F51B5).withAlpha((0.1 * 255).round()),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF3F51B5),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotConnectedView() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 靛蓝主题图标
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF3F51B5).withAlpha((0.1 * 255).round()),
                    const Color(0xFF303F9F).withAlpha((0.05 * 255).round()),
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF3F51B5).withAlpha((0.2 * 255).round()),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.keyboard_rounded,
                size: 64,
                color: Color(0xFF3F51B5),
              ),
            ),
            const SizedBox(height: 32),
            
            Text(
              '键盘输入器',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF3F51B5),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              '需要连接PC设备才能使用',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withAlpha((0.7 * 255).round()),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '连接后即可享受完整的键盘控制体验',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withAlpha((0.6 * 255).round()),
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 48),
            
            // 功能介绍卡片
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF3F51B5).withAlpha((0.05 * 255).round()),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF3F51B5).withAlpha((0.2 * 255).round()),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    '支持的输入功能',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF3F51B5),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildKeyboardFeature(Icons.edit_rounded, '文本\n输入'),
                      _buildKeyboardFeature(Icons.keyboard_alt_rounded, '修饰键\n组合'),
                      _buildKeyboardFeature(Icons.flash_on_rounded, '快捷键\n操作'),
                      _buildKeyboardFeature(Icons.functions_rounded, '功能键\n控制'),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // 连接按钮
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => context.go('/connect'),
                icon: const Icon(Icons.wifi_rounded),
                label: const Text('连接设备'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF3F51B5).withAlpha((0.1 * 255).round()),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 键盘功能项展示
  Widget _buildKeyboardFeature(IconData icon, String label) {
    return Column(
      children: [
        Icon(
          icon,
          color: const Color(0xFF3F51B5),
          size: 24,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF3F51B5),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
} 

