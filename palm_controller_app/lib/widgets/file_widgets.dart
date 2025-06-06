import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/file_item.dart';
import '../providers/file_provider.dart';

/// 文件项组件
class FileItemWidget extends ConsumerWidget {
  final FileItem file;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;

  const FileItemWidget({
    super.key,
    required this.file,
    this.onTap,
    this.onLongPress,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final viewMode = ref.watch(fileViewModeProvider);

    if (viewMode == FileViewMode.grid) {
      return _buildGridItem(context, theme);
    } else {
      return _buildListItem(context, theme);
    }
  }

  Widget _buildListItem(BuildContext context, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: isSelected ? 4 : 1,
      color: isSelected ? theme.colorScheme.primaryContainer : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: file.iconColor.withOpacity(0.1),
          child: Icon(
            file.icon,
            color: file.iconColor,
            size: 24,
          ),
        ),
        title: Text(
          file.displayName,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: file.type.isDirectory ? FontWeight.w600 : FontWeight.normal,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (file.displaySize.isNotEmpty)
              Text(
                file.displaySize,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            Text(
              _formatDate(file.lastModified),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        trailing: file.type.isDirectory 
            ? Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              )
            : null,
        onTap: () {
          HapticFeedback.lightImpact();
          onTap?.call();
        },
        onLongPress: () {
          HapticFeedback.mediumImpact();
          onLongPress?.call();
        },
      ),
    );
  }

  Widget _buildGridItem(BuildContext context, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.all(4),
      elevation: isSelected ? 4 : 1,
      color: isSelected ? theme.colorScheme.primaryContainer : null,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap?.call();
        },
        onLongPress: () {
          HapticFeedback.mediumImpact();
          onLongPress?.call();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                flex: 3,
                child: Icon(
                  file.icon,
                  color: file.iconColor,
                  size: 40,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    Text(
                      file.displayName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: file.type.isDirectory ? FontWeight.w600 : FontWeight.normal,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    if (file.displaySize.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        file.displaySize,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return '今天 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return '昨天';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return '${date.year}/${date.month}/${date.day}';
    }
  }
}

/// 文件列表组件
class FileListView extends ConsumerWidget {
  final List<FileItem> files;
  final bool isLoading;
  final String? error;
  final VoidCallback? onRefresh;

  const FileListView({
    super.key,
    required this.files,
    this.isLoading = false,
    this.error,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewMode = ref.watch(fileViewModeProvider);
    final selectedFiles = ref.watch(selectedFilesProvider);

    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              error!,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRefresh,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (files.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              '文件夹为空',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (viewMode == FileViewMode.grid) {
      return RefreshIndicator(
        onRefresh: () async => onRefresh?.call(),
        child: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.8,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: files.length,
          itemBuilder: (context, index) {
            final file = files[index];
            final isSelected = selectedFiles.contains(file.path);

            return FileItemWidget(
              file: file,
              isSelected: isSelected,
              onTap: () => _handleFileTap(context, ref, file),
              onLongPress: () => _handleFileLongPress(context, ref, file),
            );
          },
        ),
      );
    } else {
      return RefreshIndicator(
        onRefresh: () async => onRefresh?.call(),
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: files.length,
          itemBuilder: (context, index) {
            final file = files[index];
            final isSelected = selectedFiles.contains(file.path);

            return FileItemWidget(
              file: file,
              isSelected: isSelected,
              onTap: () => _handleFileTap(context, ref, file),
              onLongPress: () => _handleFileLongPress(context, ref, file),
            );
          },
        ),
      );
    }
  }

  void _handleFileTap(BuildContext context, WidgetRef ref, FileItem file) {
    final selectedFiles = ref.read(selectedFilesProvider);

    // 如果已有选中的文件，继续选择模式
    if (selectedFiles.isNotEmpty) {
      _toggleFileSelection(ref, file);
      return;
    }

    // 普通点击行为
    if (file.type.isDirectory) {
      // 进入目录
      ref.read(fileListProvider.notifier).enterDirectory(file.path);
    } else {
      // 打开文件 (暂未实现)
      _showFileOptions(context, ref, file);
    }
  }

  void _handleFileLongPress(BuildContext context, WidgetRef ref, FileItem file) {
    _toggleFileSelection(ref, file);
  }

  void _toggleFileSelection(WidgetRef ref, FileItem file) {
    final selectedFiles = ref.read(selectedFilesProvider);
    final newSelection = Set<String>.from(selectedFiles);

    if (newSelection.contains(file.path)) {
      newSelection.remove(file.path);
    } else {
      newSelection.add(file.path);
    }

    ref.read(selectedFilesProvider.notifier).state = newSelection;
  }

  void _showFileOptions(BuildContext context, WidgetRef ref, FileItem file) {
    showModalBottomSheet(
      context: context,
      builder: (context) => FileOptionsSheet(file: file),
    );
  }
}

/// 文件操作选项表单
class FileOptionsSheet extends ConsumerWidget {
  final FileItem file;

  const FileOptionsSheet({
    super.key,
    required this.file,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final operations = ref.read(fileOperationsProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 文件信息
          Row(
            children: [
              Icon(
                file.icon,
                color: file.iconColor,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.displayName,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (file.displaySize.isNotEmpty)
                      Text(
                        file.displaySize,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 操作选项
          ...buildFileActions(context, ref, file, operations),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  List<Widget> buildFileActions(
    BuildContext context,
    WidgetRef ref,
    FileItem file,
    FileOperations operations,
  ) {
    final actions = <Widget>[];

    // 重命名
    actions.add(
      ListTile(
        leading: const Icon(Icons.edit),
        title: const Text('重命名'),
        onTap: () {
          Navigator.pop(context);
          _showRenameDialog(context, ref, file, operations);
        },
      ),
    );

    // 删除
    actions.add(
      ListTile(
        leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
        title: Text(
          '删除',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        onTap: () {
          Navigator.pop(context);
          _showDeleteDialog(context, ref, file, operations);
        },
      ),
    );

    return actions;
  }

  void _showRenameDialog(
    BuildContext context,
    WidgetRef ref,
    FileItem file,
    FileOperations operations,
  ) {
    final controller = TextEditingController(text: file.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '新名称',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != file.name) {
                Navigator.pop(context);
                final success = await operations.renameItem(file.path, newName);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? '重命名成功' : '重命名失败'),
                    ),
                  );
                }
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    FileItem file,
    FileOperations operations,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除 "${file.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await operations.deleteItem(file.path);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? '删除成功' : '删除失败'),
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

/// 浮动操作按钮菜单
class FileFloatingActionButton extends ConsumerWidget {
  const FileFloatingActionButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton(
      onPressed: () => _showCreateMenu(context, ref),
      child: const Icon(Icons.add),
    );
  }

  void _showCreateMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.create_new_folder),
              title: const Text('新建文件夹'),
              onTap: () {
                Navigator.pop(context);
                _showCreateFolderDialog(context, ref);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showCreateFolderDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建文件夹'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '文件夹名称',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context);
                final operations = ref.read(fileOperationsProvider);
                final success = await operations.createDirectory(name);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? '创建成功' : '创建失败'),
                    ),
                  );
                }
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }
} 