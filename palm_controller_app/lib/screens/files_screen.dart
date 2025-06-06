import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/file_item.dart';
import '../providers/file_provider.dart';
import '../widgets/file_widgets.dart';

class FilesScreen extends ConsumerStatefulWidget {
  const FilesScreen({super.key});

  @override
  ConsumerState<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends ConsumerState<FilesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // 初始化时加载本地文件
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(fileListProvider.notifier).refreshFiles();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fileListState = ref.watch(fileListProvider);
    final filteredFiles = ref.watch(filteredFilesProvider);
    final browseMode = ref.watch(fileBrowseModeProvider);
    final currentDirectory = ref.watch(currentDirectoryProvider);
    final directoryHistory = ref.watch(directoryHistoryProvider);
    final selectedFiles = ref.watch(selectedFilesProvider);
    final viewMode = ref.watch(fileViewModeProvider);
    final searchQuery = ref.watch(fileSearchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('文件管理'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        
        // 顶部标签页
        bottom: TabBar(
          controller: _tabController,
          onTap: (index) {
            final newMode = index == 0 ? FileBrowseMode.local : FileBrowseMode.pc;
            ref.read(fileListProvider.notifier).switchMode(newMode);
          },
          tabs: const [
            Tab(
              icon: Icon(Icons.phone_android),
              text: '本地文件',
            ),
            Tab(
              icon: Icon(Icons.computer),
              text: 'PC文件',
            ),
          ],
        ),

        // 导航栏
        flexibleSpace: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // 路径导航栏
            if (currentDirectory != null || directoryHistory.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    // 返回按钮
                    if (directoryHistory.isNotEmpty || currentDirectory != null)
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () {
                          ref.read(fileListProvider.notifier).goBack();
                        },
                      ),
                    
                    // 路径显示
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Text(
                          currentDirectory ?? (browseMode == FileBrowseMode.local ? '本地存储' : 'PC根目录'),
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),

        // 操作按钮
        actions: [
          // 搜索按钮
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearchDialog(context, ref),
          ),
          
          // 视图切换
          IconButton(
            icon: Icon(
              viewMode == FileViewMode.list ? Icons.grid_view : Icons.list,
            ),
            onPressed: () {
              final newMode = viewMode == FileViewMode.list 
                  ? FileViewMode.grid 
                  : FileViewMode.list;
              ref.read(fileViewModeProvider.notifier).state = newMode;
            },
          ),
          
          // 更多选项
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenuAction(context, ref, value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'sort',
                child: Row(
                  children: [
                    Icon(Icons.sort),
                    SizedBox(width: 8),
                    Text('排序'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 8),
                    Text('刷新'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'select_all',
                child: Row(
                  children: [
                    Icon(Icons.select_all),
                    SizedBox(width: 8),
                    Text('全选'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),

      // 主体内容
      body: Column(
        children: [
          // 选中文件操作栏
          if (selectedFiles.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Row(
                children: [
                  Text(
                    '已选中 ${selectedFiles.length} 个项目',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const Spacer(),
                  
                  // 删除按钮
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _deleteSelectedFiles(context, ref),
                  ),
                  
                  // 取消选择
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      ref.read(selectedFilesProvider.notifier).state = {};
                    },
                  ),
                ],
              ),
            ),

          // 文件列表
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 本地文件
                _buildFileList(context, ref, filteredFiles, fileListState),
                
                // PC文件
                _buildFileList(context, ref, filteredFiles, fileListState),
              ],
            ),
          ),
        ],
      ),

      // 浮动操作按钮
      floatingActionButton: selectedFiles.isEmpty 
          ? const FileFloatingActionButton()
          : null,
    );
  }

  Widget _buildFileList(
    BuildContext context,
    WidgetRef ref,
    List<FileItem> files,
    FileListState state,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(fileListProvider.notifier).refreshFiles();
      },
      child: _buildFileListView(context, ref, files, state),
    );
  }

  Widget _buildFileListView(
    BuildContext context,
    WidgetRef ref,
    List<FileItem> files,
    FileListState state,
  ) {
    final viewMode = ref.watch(fileViewModeProvider);
    final selectedFiles = ref.watch(selectedFilesProvider);

    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (state.error != null) {
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
              state.error!,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(fileListProvider.notifier).refreshFiles();
              },
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
      return GridView.builder(
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
      );
    } else {
      return ListView.builder(
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
      // 显示文件选项
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
      builder: (context) => _buildFileOptionsSheet(context, ref, file),
    );
  }

  Widget _buildFileOptionsSheet(BuildContext context, WidgetRef ref, FileItem file) {
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

          // 重命名
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('重命名'),
            onTap: () {
              Navigator.pop(context);
              _showRenameDialog(context, ref, file, operations);
            },
          ),

          // 删除
          ListTile(
            leading: Icon(Icons.delete, color: theme.colorScheme.error),
            title: Text(
              '删除',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            onTap: () {
              Navigator.pop(context);
              _showDeleteDialog(context, ref, file, operations);
            },
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showSearchDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: ref.read(fileSearchQueryProvider));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('搜索文件'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '输入文件名',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.search),
          ),
          autofocus: true,
          onChanged: (value) {
            ref.read(fileSearchQueryProvider.notifier).state = value;
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(fileSearchQueryProvider.notifier).state = '';
              Navigator.pop(context);
            },
            child: const Text('清除'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
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

  void _deleteSelectedFiles(BuildContext context, WidgetRef ref) {
    final selectedFiles = ref.read(selectedFilesProvider);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除选中的 ${selectedFiles.length} 个项目吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final operations = ref.read(fileOperationsProvider);
              
              int successCount = 0;
              for (final path in selectedFiles) {
                final success = await operations.deleteItem(path);
                if (success) successCount++;
              }
              
              // 清除选择
              ref.read(selectedFilesProvider.notifier).state = {};
              
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('成功删除 $successCount 个项目'),
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

  void _handleMenuAction(BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case 'sort':
        _showSortDialog(context, ref);
        break;
      case 'refresh':
        ref.read(fileListProvider.notifier).refreshFiles();
        break;
      case 'select_all':
        final files = ref.read(filteredFilesProvider);
        final allPaths = files.map((f) => f.path).toSet();
        ref.read(selectedFilesProvider.notifier).state = allPaths;
        break;
    }
  }

  void _showSortDialog(BuildContext context, WidgetRef ref) {
    final currentSort = ref.read(fileSortTypeProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('排序方式'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: FileSortType.values.map((type) {
            String name;
            switch (type) {
              case FileSortType.name:
                name = '名称';
                break;
              case FileSortType.size:
                name = '大小';
                break;
              case FileSortType.date:
                name = '修改时间';
                break;
              case FileSortType.type:
                name = '类型';
                break;
            }

            return RadioListTile<FileSortType>(
              title: Text(name),
              value: type,
              groupValue: currentSort,
              onChanged: (value) {
                if (value != null) {
                  ref.read(fileSortTypeProvider.notifier).state = value;
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }
} 