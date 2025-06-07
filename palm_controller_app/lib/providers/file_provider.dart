import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/file_item.dart';
import '../services/file_service.dart';

// 文件服务提供者
final fileServiceProvider = Provider<FileService>((ref) {
  return FileService.instance;
});

// 当前浏览模式 (本地/PC)
enum FileBrowseMode { local, pc }

final fileBrowseModeProvider = StateProvider<FileBrowseMode>((ref) {
  return FileBrowseMode.local;
});

// 当前目录路径
final currentDirectoryProvider = StateProvider<String?>((ref) {
  return null;
});

// 目录历史栈 (用于返回导航)
final directoryHistoryProvider = StateProvider<List<String>>((ref) {
  return [];
});

// 文件列表状态
class FileListState {
  final List<FileItem> files;
  final bool isLoading;
  final String? error;

  const FileListState({
    this.files = const [],
    this.isLoading = false,
    this.error,
  });

  FileListState copyWith({
    List<FileItem>? files,
    bool? isLoading,
    String? error,
  }) {
    return FileListState(
      files: files ?? this.files,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// 文件列表Provider
class FileListNotifier extends StateNotifier<FileListState> {
  FileListNotifier(this._fileService, this._ref) : super(const FileListState());

  final FileService _fileService;
  final Ref _ref;

  /// 刷新文件列表
  Future<void> refreshFiles() async {
    final mode = _ref.read(fileBrowseModeProvider);
    final currentPath = _ref.read(currentDirectoryProvider);

    state = state.copyWith(isLoading: true, error: null);

    try {
      final files = mode == FileBrowseMode.local
          ? await _fileService.getLocalFiles(currentPath)
          : await _fileService.getPCFiles(currentPath);

      // FileService现在返回空列表而不是抛出异常，无需特殊处理
      state = state.copyWith(files: files, isLoading: false);
      
      // 记录成功日志
      if (mode == FileBrowseMode.pc && files.isEmpty && currentPath != null) {
        // PC模式下如果返回空列表且不是根目录，可能是连接问题
        state = state.copyWith(
          error: '无法获取PC文件列表，请检查连接状态',
        );
      }
    } catch (e) {
      // 虽然FileService不再抛出异常，但保留此处理以防万一
      state = state.copyWith(
        isLoading: false,
        error: '加载文件列表失败: $e',
      );
    }
  }

  /// 进入目录
  Future<void> enterDirectory(String directoryPath) async {
    final currentPath = _ref.read(currentDirectoryProvider);
    final history = _ref.read(directoryHistoryProvider);

    // 添加当前路径到历史
    if (currentPath != null) {
      _ref.read(directoryHistoryProvider.notifier).state = [...history, currentPath];
    }

    // 设置新路径
    _ref.read(currentDirectoryProvider.notifier).state = directoryPath;

    // 刷新文件列表
    await refreshFiles();
  }

  /// 返回上级目录
  Future<void> goBack() async {
    final history = _ref.read(directoryHistoryProvider);

    if (history.isNotEmpty) {
      // 从历史中恢复路径
      final previousPath = history.last;
      _ref.read(currentDirectoryProvider.notifier).state = previousPath;
      _ref.read(directoryHistoryProvider.notifier).state = 
          history.sublist(0, history.length - 1);
    } else {
      // 回到根目录
      _ref.read(currentDirectoryProvider.notifier).state = null;
    }

    await refreshFiles();
  }

  /// 切换浏览模式
  Future<void> switchMode(FileBrowseMode mode) async {
    _ref.read(fileBrowseModeProvider.notifier).state = mode;
    _ref.read(currentDirectoryProvider.notifier).state = null;
    _ref.read(directoryHistoryProvider.notifier).state = [];
    await refreshFiles();
  }
}

final fileListProvider = StateNotifierProvider<FileListNotifier, FileListState>((ref) {
  final fileService = ref.watch(fileServiceProvider);
  return FileListNotifier(fileService, ref);
});

// 选中的文件列表
final selectedFilesProvider = StateProvider<Set<String>>((ref) {
  return <String>{};
});

// 是否显示隐藏文件
final showHiddenFilesProvider = StateProvider<bool>((ref) {
  return false;
});

// 文件排序方式
enum FileSortType { name, size, date, type }

final fileSortTypeProvider = StateProvider<FileSortType>((ref) {
  return FileSortType.name;
});

// 文件视图模式
enum FileViewMode { list, grid }

final fileViewModeProvider = StateProvider<FileViewMode>((ref) {
  return FileViewMode.list;
});

// 搜索关键词
final fileSearchQueryProvider = StateProvider<String>((ref) {
  return '';
});

// 过滤后的文件列表
final filteredFilesProvider = Provider<List<FileItem>>((ref) {
  final fileList = ref.watch(fileListProvider);
  final searchQuery = ref.watch(fileSearchQueryProvider);
  final showHidden = ref.watch(showHiddenFilesProvider);
  final sortType = ref.watch(fileSortTypeProvider);

  var files = fileList.files;

  // 搜索过滤
  if (searchQuery.isNotEmpty) {
    files = files.where((file) => 
        file.name.toLowerCase().contains(searchQuery.toLowerCase())).toList();
  }

  // 隐藏文件过滤
  if (!showHidden) {
    files = files.where((file) => !file.isHidden).toList();
  }

  // 排序
  files.sort((a, b) {
    // 文件夹总是在前面
    if (a.type != b.type) {
      return a.type.isDirectory ? -1 : 1;
    }

    switch (sortType) {
      case FileSortType.name:
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      case FileSortType.size:
        return a.size.compareTo(b.size);
      case FileSortType.date:
        return b.lastModified.compareTo(a.lastModified);
      case FileSortType.type:
        final aExt = a.extension ?? '';
        final bExt = b.extension ?? '';
        return aExt.compareTo(bExt);
    }
  });

  return files;
});

// 常用目录Provider
final commonDirectoriesProvider = FutureProvider<List<FileItem>>((ref) async {
  final fileService = ref.watch(fileServiceProvider);
  return await fileService.getCommonDirectories();
});

// 文件操作Provider
final fileOperationsProvider = Provider<FileOperations>((ref) {
  final fileService = ref.watch(fileServiceProvider);
  return FileOperations(fileService, ref);
});

class FileOperations {
  final FileService _fileService;
  final Ref _ref;

  FileOperations(this._fileService, this._ref);

  /// 创建文件夹
  Future<bool> createDirectory(String name) async {
    final mode = _ref.read(fileBrowseModeProvider);
    final currentPath = _ref.read(currentDirectoryProvider) ?? '';
    
    final success = await _fileService.createDirectory(
      currentPath,
      name,
      isLocal: mode == FileBrowseMode.local,
    );

    if (success) {
      await _ref.read(fileListProvider.notifier).refreshFiles();
    }

    return success;
  }

  /// 删除文件或文件夹
  Future<bool> deleteItem(String path) async {
    final mode = _ref.read(fileBrowseModeProvider);
    
    final success = await _fileService.deleteItem(
      path,
      isLocal: mode == FileBrowseMode.local,
    );

    if (success) {
      await _ref.read(fileListProvider.notifier).refreshFiles();
    }

    return success;
  }

  /// 重命名文件或文件夹
  Future<bool> renameItem(String path, String newName) async {
    final mode = _ref.read(fileBrowseModeProvider);
    
    final success = await _fileService.renameItem(
      path,
      newName,
      isLocal: mode == FileBrowseMode.local,
    );

    if (success) {
      await _ref.read(fileListProvider.notifier).refreshFiles();
    }

    return success;
  }

  /// 上传文件
  Future<bool> uploadFile(String localPath, String? remotePath) async {
    final currentPath = _ref.read(currentDirectoryProvider) ?? '';
    final targetPath = remotePath ?? '$currentPath/${localPath.split('/').last}';
    
    return await _fileService.uploadFile(localPath, targetPath);
  }

  /// 下载文件
  Future<bool> downloadFile(String remotePath, String? localPath) async {
    final targetPath = localPath ?? '/storage/emulated/0/Download/${remotePath.split('/').last}';
    
    return await _fileService.downloadFile(remotePath, targetPath);
  }
} 