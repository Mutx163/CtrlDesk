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

  void _sendKey(String keyCode, {List<String> modifiers = const []}) {
    final message = ControlMessage.keyboardControl(
      messageId: DateTime.now().millisecondsSinceEpoch.toString(),
      action: 'key_press',
      keyCode: keyCode,
      modifiers: modifiers,
    );
    _sendKeyboardMessage(message);
    
    // 提供触觉反馈
    HapticFeedback.lightImpact();
  }

  List<String> _getCurrentModifiers() {
    List<String> modifiers = [];
    if (_isCtrlPressed) modifiers.add('ctrl');
    if (_isShiftPressed) modifiers.add('shift');
    if (_isAltPressed) modifiers.add('alt');
    return modifiers;
  }

  @override
  Widget build(BuildContext context) {
    final connectionStatus = ref.watch(connectionStatusProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: _buildAppBar(context),
      body: SafeArea(
        child: connectionStatus == ConnectionStatus.connected
            ? _buildKeyboardInterface()
            : _buildNotConnectedView(),
      ),
    );
  }

  /// 现代化应用栏
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: Text(
        '键盘控制',
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_rounded,
          color: Theme.of(context).colorScheme.primary,
        ),
        onPressed: () => context.pop(),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '已连接',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKeyboardInterface() {
    return CustomScrollView(
      slivers: [
        // 顶部间距
        const SliverToBoxAdapter(
          child: SizedBox(height: 16),
        ),
        
        // 文本输入区域
        SliverToBoxAdapter(
          child: _buildTextInputSection(),
        ),
        
        // 修饰键区域
        SliverToBoxAdapter(
          child: _buildModifierKeysSection(),
        ),
        
        // 常用快捷键区域
        SliverToBoxAdapter(
          child: _buildShortcutsSection(),
        ),
        
        // 功能键区域
        SliverToBoxAdapter(
          child: _buildFunctionKeysSection(),
        ),
        
        // 方向键区域
        SliverToBoxAdapter(
          child: _buildDirectionKeysSection(),
        ),
        
        // 底部间距
        const SliverToBoxAdapter(
          child: SizedBox(height: 24),
        ),
      ],
    );
  }

  /// 文本输入区域
  Widget _buildTextInputSection() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.keyboard_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '文本输入',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // 输入框
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
              ),
            ),
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              maxLines: null,
              expands: true,
              decoration: InputDecoration(
                hintText: '在此输入文本内容...',
                hintStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 16),
          
          // 操作按钮
          Row(
            children: [
              Expanded(
                child: _buildPrimaryButton(
                  icon: Icons.send_rounded,
                  label: '发送文本',
                  onPressed: () {
                    _sendText(_textController.text);
                    _textController.clear();
                  },
                ),
              ),
              const SizedBox(width: 12),
              _buildSecondaryButton(
                icon: Icons.clear_rounded,
                label: '清空',
                onPressed: () => _textController.clear(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 修饰键区域
  Widget _buildModifierKeysSection() {
    return _buildSection(
      title: '修饰键',
      icon: Icons.alt_route_rounded,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _buildModifierChip(
            label: 'Ctrl',
            isSelected: _isCtrlPressed,
            onPressed: () {
              setState(() {
                _isCtrlPressed = !_isCtrlPressed;
              });
            },
          ),
          _buildModifierChip(
            label: 'Shift',
            isSelected: _isShiftPressed,
            onPressed: () {
              setState(() {
                _isShiftPressed = !_isShiftPressed;
              });
            },
          ),
          _buildModifierChip(
            label: 'Alt',
            isSelected: _isAltPressed,
            onPressed: () {
              setState(() {
                _isAltPressed = !_isAltPressed;
              });
            },
          ),
        ],
      ),
    );
  }

  /// 常用快捷键区域
  Widget _buildShortcutsSection() {
    final shortcuts = [
      {'label': '复制', 'keys': ['ctrl', 'c'], 'icon': Icons.copy_rounded},
      {'label': '粘贴', 'keys': ['ctrl', 'v'], 'icon': Icons.paste_rounded},
      {'label': '剪切', 'keys': ['ctrl', 'x'], 'icon': Icons.cut_rounded},
      {'label': '撤销', 'keys': ['ctrl', 'z'], 'icon': Icons.undo_rounded},
      {'label': '重做', 'keys': ['ctrl', 'y'], 'icon': Icons.redo_rounded},
      {'label': '全选', 'keys': ['ctrl', 'a'], 'icon': Icons.select_all_rounded},
      {'label': '保存', 'keys': ['ctrl', 's'], 'icon': Icons.save_rounded},
      {'label': '查找', 'keys': ['ctrl', 'f'], 'icon': Icons.search_rounded},
      {'label': '新建', 'keys': ['ctrl', 'n'], 'icon': Icons.add_rounded},
    ];

    return _buildSection(
      title: '常用快捷键',
      icon: Icons.flash_on_rounded,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.8,
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
    );
  }

  /// 功能键区域
  Widget _buildFunctionKeysSection() {
    final functionKeys = [
      {'label': 'Tab', 'key': 'VK_TAB', 'icon': Icons.keyboard_tab_rounded},
      {'label': 'Enter', 'key': 'VK_RETURN', 'icon': Icons.keyboard_return_rounded},
      {'label': 'Esc', 'key': 'VK_ESCAPE', 'icon': Icons.close_rounded},
      {'label': 'Space', 'key': 'VK_SPACE', 'icon': Icons.space_bar_rounded},
      {'label': 'Backspace', 'key': 'VK_BACK', 'icon': Icons.backspace_rounded},
      {'label': 'Delete', 'key': 'VK_DELETE', 'icon': Icons.delete_rounded},
      {'label': 'Home', 'key': 'VK_HOME', 'icon': Icons.home_rounded},
      {'label': 'End', 'key': 'VK_END', 'icon': Icons.last_page_rounded},
    ];

    return _buildSection(
      title: '功能按键',
      icon: Icons.keyboard_alt_rounded,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
        ),
        itemCount: functionKeys.length,
        itemBuilder: (context, index) {
          final key = functionKeys[index];
          return _buildFunctionKeyButton(
            icon: key['icon'] as IconData,
            label: key['label'] as String,
            onPressed: () => _sendKey(
              key['key'] as String,
              modifiers: _getCurrentModifiers(),
            ),
          );
        },
      ),
    );
  }

  /// 方向键区域
  Widget _buildDirectionKeysSection() {
    return _buildSection(
      title: '方向键',
      icon: Icons.keyboard_arrow_up_rounded,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 上方向键
            _buildDirectionButton(
              icon: Icons.keyboard_arrow_up_rounded,
              onPressed: () => _sendKey('VK_UP', modifiers: _getCurrentModifiers()),
            ),
            const SizedBox(height: 12),
            // 左、下、右方向键
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildDirectionButton(
                  icon: Icons.keyboard_arrow_left_rounded,
                  onPressed: () => _sendKey('VK_LEFT', modifiers: _getCurrentModifiers()),
                ),
                _buildDirectionButton(
                  icon: Icons.keyboard_arrow_down_rounded,
                  onPressed: () => _sendKey('VK_DOWN', modifiers: _getCurrentModifiers()),
                ),
                _buildDirectionButton(
                  icon: Icons.keyboard_arrow_right_rounded,
                  onPressed: () => _sendKey('VK_RIGHT', modifiers: _getCurrentModifiers()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 通用区域构建器
  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  /// 主要按钮
  Widget _buildPrimaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    );
  }

  /// 次要按钮
  Widget _buildSecondaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    );
  }

  /// 修饰键Chip
  Widget _buildModifierChip({
    required String label,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected 
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected 
                  ? Colors.white
                  : Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
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
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
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
  Widget _buildFunctionKeyButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 16,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 方向键按钮
  Widget _buildDirectionButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            ),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildNotConnectedView() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.keyboard_hide_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            '设备未连接',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            '请先连接到PC设备后再使用键盘功能',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.push('/connect'),
              icon: const Icon(Icons.wifi_rounded),
              label: const Text('连接设备'),
            ),
          ),
        ],
      ),
    );
  }
} 