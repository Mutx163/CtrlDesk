import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/file_item.dart';
import '../models/control_message.dart';
import 'socket_service.dart';
import 'log_service.dart';

class FileService {
  static final FileService _instance = FileService._internal();
  factory FileService() => _instance;
  FileService._internal();

  static FileService get instance => _instance;

  final SocketService _socketService = SocketService();
  final LogService _logService = LogService.instance;

  /// 获取手机本地文件列表
  Future<List<FileItem>> getLocalFiles([String? directoryPath]) async {
    try {
      Directory directory;
      
      if (directoryPath != null) {
        directory = Directory(directoryPath);
      } else {
        // 获取外部存储目录 (Android)
        if (Platform.isAndroid) {
          directory = Directory('/storage/emulated/0');
        } else {
          // iOS 使用应用文档目录
          directory = await getApplicationDocumentsDirectory();
        }
      }

      if (!directory.existsSync()) {
        return [];
      }

      final entities = directory.listSync(followLinks: false);
      final files = <FileItem>[];

      for (final entity in entities) {
        try {
          final stat = entity.statSync();
          final name = entity.path.split('/').last;
          
          // 跳过隐藏文件 (以.开头)
          if (name.startsWith('.')) continue;

          final fileItem = FileItem(
            name: name,
            path: entity.path,
            type: entity is Directory ? FileItemType.directory : FileItemType.file,
            size: stat.size,
            lastModified: stat.modified,
            extension: entity is File ? _getFileExtension(name) : null,
            isHidden: name.startsWith('.'),
          );

          files.add(fileItem);
        } catch (e) {
          _logService.error('读取文件信息失败: ${entity.path}, 错误: $e', category: 'FileService');
        }
      }

      // 排序：文件夹在前，然后按名称排序
      files.sort((a, b) {
        if (a.type != b.type) {
          return a.type.isDirectory ? -1 : 1;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      return files;
    } catch (e) {
      _logService.error('获取本地文件列表失败: $e', category: 'FileService');
      return [];
    }
  }

  /// 获取PC端文件列表
  Future<List<FileItem>> getPCFiles(String? directoryPath) async {
        try {
      _logService.debug('开始获取PC文件列表: $directoryPath', category: 'FileService');
      
      // 检查连接状态
      if (_socketService.currentStatus != ConnectionStatus.connected) {
        _logService.warning('未连接到PC端，无法获取文件列表', category: 'FileService');
        return [];
      }
      
      final message = ControlMessage.fileOperation(
         operation: 'list_files',
         path: directoryPath ?? '',
         messageId: DateTime.now().millisecondsSinceEpoch.toString(),
       );

      print('🔥🔥🔥 [FILE_DEBUG] 准备发送PC文件列表请求: path=$directoryPath, messageId=${message.messageId}');
      
      // 发送消息
      final success = await _socketService.sendMessage(message);
      if (!success) {
        print('🔥🔥🔥 [FILE_DEBUG] 发送文件列表请求失败!!!');
        _logService.warning('无法发送PC文件列表请求，连接可能已断开', category: 'FileService');
        return [];
      }
      
      print('🔥🔥🔥 [FILE_DEBUG] 文件列表请求发送成功，开始等待响应...');

      // 等待文件列表响应，增加异常安全处理
      try {
        final response = await _waitForFileListResponse(message.messageId);
        if (response != null) {
          final files = _parseFileListResponse(response);
          _logService.info('成功获取PC文件列表: ${files.length}个项目', category: 'FileService');
          return files;
        } else {
          _logService.warning('PC端文件列表响应超时，请检查连接状态', category: 'FileService');
          return [];
        }
      } catch (e) {
        _logService.error('等待PC文件列表响应时发生异常: $e', category: 'FileService');
        return [];
      }
    } catch (e) {
      _logService.error('获取PC文件列表异常: $e', category: 'FileService');
      // 返回空列表而不是抛出异常，提供更好的用户体验
      return [];
    }
  }

  /// 等待文件列表响应 - 增强异常处理
  Future<Map<String, dynamic>?> _waitForFileListResponse(String messageId) async {
    try {
      print('🔥🔥🔥 [FILE_DEBUG] 开始等待文件列表响应 - messageId: $messageId');
      
      // 创建一个Completer来处理超时
      final completer = Completer<Map<String, dynamic>?>();
      
      // 创建超时计时器
      Timer? timeoutTimer = Timer(const Duration(seconds: 10), () {
        if (!completer.isCompleted) {
          print('🔥🔥🔥 [FILE_DEBUG] PC文件列表响应超时!!! - messageId: $messageId');
          completer.complete(null);
        }
      });

      // 监听消息流，增加异常安全处理
      late StreamSubscription debugSubscription;
      try {
        debugSubscription = _socketService.messageStream.listen(
          (message) {
            print('🔥🔥🔥 [FILE_DEBUG] 收到消息: type=${message.type}, messageId=${message.messageId}');
            
            // 如果是我们需要的响应
            if (message.type == 'file_list_response' && message.messageId == messageId) {
              if (!completer.isCompleted) {
                print('🔥🔥🔥 [FILE_DEBUG] 找到匹配的文件列表响应!!!');
                timeoutTimer.cancel();
                debugSubscription.cancel();
                completer.complete(message.toJson());
              }
            }
          }, 
          onError: (error) {
            if (!completer.isCompleted) {
              timeoutTimer.cancel();
              debugSubscription.cancel();
              print('🔥🔥🔥 [FILE_DEBUG] 消息流监听错误: $error');
              _logService.error('消息流监听错误: $error', category: 'FileService');
              completer.complete(null);
            }
          },
          cancelOnError: false, // 不要因为单个错误而取消整个流
        );
      } catch (e) {
        print('🔥🔥�� [FILE_DEBUG] 创建消息流监听器失败: $e');
                 timeoutTimer.cancel();
        _logService.error('创建消息流监听器失败: $e', category: 'FileService');
        return null;
      }

      return await completer.future;
    } catch (e) {
      print('🔥🔥🔥 [FILE_DEBUG] 等待PC文件列表响应失败: $e');
      _logService.error('等待PC文件列表响应失败: $e', category: 'FileService');
      return null;
    }
  }

  /// 解析文件列表响应
  List<FileItem> _parseFileListResponse(Map<String, dynamic> response) {
    try {
      final payload = response['payload'] as Map<String, dynamic>?;
      if (payload == null || payload['files'] == null) {
        return [];
      }

      final filesData = payload['files'] as List<dynamic>;
      final files = <FileItem>[];

      for (final fileData in filesData) {
        final data = fileData as Map<String, dynamic>;
        
        try {
          final fileName = data['name'] as String;
          final isDirectory = data['type'] == 'directory';
          
          final file = FileItem(
            name: fileName,
            path: data['path'] as String,
            size: (data['size'] as num).toInt(),
            lastModified: DateTime.parse(data['lastModified'] as String),
            type: isDirectory ? FileItemType.directory : _getFileTypeFromName(fileName),
            extension: isDirectory ? null : _getFileExtension(fileName),
            isHidden: data['isHidden'] as bool? ?? false,
          );
          files.add(file);
        } catch (e) {
          _logService.error('解析文件项失败: $fileData, 错误: $e', category: 'FileService');
        }
      }

      // 排序：文件夹在前，然后按名称排序
      files.sort((a, b) {
        if (a.type != b.type) {
          return a.type.isDirectory ? -1 : 1;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      _logService.info('成功解析PC文件列表: ${files.length}个项目', category: 'FileService');
      return files;
    } catch (e) {
      _logService.error('解析PC文件列表响应失败: $e', category: 'FileService');
      return [];
    }
  }

  /// 创建文件夹
  Future<bool> createDirectory(String path, String name, {bool isLocal = true}) async {
    try {
      if (isLocal) {
        final newDir = Directory('$path/$name');
        await newDir.create();
        _logService.info('创建本地文件夹成功: ${newDir.path}', category: 'FileService');
        return true;
      } else {
        final message = ControlMessage.fileOperation(
          operation: 'create_directory',
          path: path,
          name: name,
          messageId: DateTime.now().millisecondsSinceEpoch.toString(),
        );

        final success = await _socketService.sendMessage(message);
        
        if (success) {
          _logService.info('发送创建PC文件夹请求成功: $path/$name', category: 'FileService');
        } else {
          _logService.warning('发送创建PC文件夹请求失败', category: 'FileService');
        }
        
        return success;
      }
    } catch (e) {
      _logService.error('创建文件夹失败: $e', category: 'FileService');
      return false;
    }
  }

  /// 删除文件或文件夹
  Future<bool> deleteItem(String path, {bool isLocal = true}) async {
    try {
      if (isLocal) {
        final entity = FileSystemEntity.isDirectorySync(path)
            ? Directory(path)
            : File(path);
        
        await entity.delete(recursive: true);
        _logService.info('删除本地文件成功: $path', category: 'FileService');
        return true;
      } else {
        final message = ControlMessage.fileOperation(
          operation: 'delete',
          path: path,
          messageId: DateTime.now().millisecondsSinceEpoch.toString(),
        );

        final success = await _socketService.sendMessage(message);
        
        if (success) {
          _logService.info('发送删除PC文件请求成功: $path', category: 'FileService');
        } else {
          _logService.warning('发送删除PC文件请求失败', category: 'FileService');
        }
        
        return success;
      }
    } catch (e) {
      _logService.error('删除文件失败: $e', category: 'FileService');
      return false;
    }
  }

  /// 重命名文件或文件夹
  Future<bool> renameItem(String oldPath, String newName, {bool isLocal = true}) async {
    try {
      if (isLocal) {
        final entity = FileSystemEntity.isDirectorySync(oldPath)
            ? Directory(oldPath)
            : File(oldPath);
        
        final parentPath = oldPath.substring(0, oldPath.lastIndexOf('/'));
        final newPath = '$parentPath/$newName';
        
        await entity.rename(newPath);
        _logService.info('重命名本地文件成功: $oldPath -> $newPath', category: 'FileService');
        return true;
      } else {
        final message = ControlMessage.fileOperation(
          operation: 'rename',
          path: oldPath,
          name: newName,
          messageId: DateTime.now().millisecondsSinceEpoch.toString(),
        );

        final success = await _socketService.sendMessage(message);
        
        if (success) {
          _logService.info('发送重命名PC文件请求成功: $oldPath -> $newName', category: 'FileService');
        } else {
          _logService.warning('发送重命名PC文件请求失败', category: 'FileService');
        }
        
        return success;
      }
    } catch (e) {
      _logService.error('重命名文件失败: $e', category: 'FileService');
      return false;
    }
  }

  /// 上传文件到PC
  Future<bool> uploadFile(String localPath, String remotePath) async {
    try {
      final file = File(localPath);
      if (!file.existsSync()) {
        _logService.warning('本地文件不存在: $localPath', category: 'FileService');
        return false;
      }

      final bytes = await file.readAsBytes();
      final base64Data = base64Encode(bytes);

      final message = ControlMessage.fileOperation(
        operation: 'upload',
        path: remotePath,
        data: base64Data,
        messageId: DateTime.now().millisecondsSinceEpoch.toString(),
      );

      _logService.info('上传文件: $localPath -> $remotePath', category: 'FileService');
      
      final success = await _socketService.sendMessage(message);
      
      if (success) {
        _logService.info('发送文件上传请求成功', category: 'FileService');
      } else {
        _logService.warning('发送文件上传请求失败', category: 'FileService');
      }
      
      return success;
    } catch (e) {
      _logService.error('上传文件异常: $e', category: 'FileService');
      return false;
    }
  }

  /// 从PC下载文件
  Future<bool> downloadFile(String remotePath, String localPath) async {
    try {
      final message = ControlMessage.fileOperation(
        operation: 'download',
        path: remotePath,
        messageId: DateTime.now().millisecondsSinceEpoch.toString(),
      );

      _logService.info('下载文件: $remotePath -> $localPath', category: 'FileService');
      
      final success = await _socketService.sendMessage(message);
      
      if (success) {
        _logService.info('发送文件下载请求成功', category: 'FileService');
        // 实际实现中应该监听响应并保存文件
        return true;
      } else {
        _logService.warning('发送文件下载请求失败', category: 'FileService');
        return false;
      }
    } catch (e) {
      _logService.error('下载文件异常: $e', category: 'FileService');
      return false;
    }
  }

  /// 获取常用目录
  Future<List<FileItem>> getCommonDirectories() async {
    final directories = <FileItem>[];
    
    try {
      if (Platform.isAndroid) {
        // Android 常用目录
        final commonPaths = [
          '/storage/emulated/0/Download',
          '/storage/emulated/0/DCIM/Camera',
          '/storage/emulated/0/Pictures',
          '/storage/emulated/0/Music',
          '/storage/emulated/0/Movies',
          '/storage/emulated/0/Documents',
        ];

        for (final path in commonPaths) {
          final dir = Directory(path);
          if (dir.existsSync()) {
            final stat = dir.statSync();
            directories.add(FileItem(
              name: path.split('/').last,
              path: path,
              type: FileItemType.directory,
              size: 0,
              lastModified: stat.modified,
            ));
          }
        }
      } else if (Platform.isIOS) {
        // iOS 常用目录
        final documentsDir = await getApplicationDocumentsDirectory();
        final supportDir = await getApplicationSupportDirectory();
        
        directories.addAll([
          FileItem(
            name: 'Documents',
            path: documentsDir.path,
            type: FileItemType.directory,
            size: 0,
            lastModified: documentsDir.statSync().modified,
          ),
          FileItem(
            name: 'Application Support',
            path: supportDir.path,
            type: FileItemType.directory,
            size: 0,
            lastModified: supportDir.statSync().modified,
          ),
        ]);
      }
    } catch (e) {
      _logService.error('获取常用目录失败: $e', category: 'FileService');
    }

    return directories;
  }

  /// 获取文件扩展名
  String? _getFileExtension(String fileName) {
    final lastDotIndex = fileName.lastIndexOf('.');
    if (lastDotIndex != -1 && lastDotIndex < fileName.length - 1) {
      return fileName.substring(lastDotIndex);
    }
    return null;
  }

  /// 获取图片预览数据 (PC端)
  Future<String?> getImagePreview(String imagePath) async {
    try {
      final message = ControlMessage.fileOperation(
        operation: 'preview_image',
        path: imagePath,
        messageId: DateTime.now().millisecondsSinceEpoch.toString(),
      );

      print('🖼️🖼️🖼️ [IMAGE_DEBUG] 请求图片预览: $imagePath, messageId=${message.messageId}');
      
      // 发送消息
      final success = await _socketService.sendMessage(message);
      if (!success) {
        print('🖼️🖼️🖼️ [IMAGE_DEBUG] 发送图片预览请求失败!!!');
        return null;
      }

      print('🖼️🖼️🖼️ [IMAGE_DEBUG] 图片预览请求发送成功，等待响应...');

      // 等待图片预览响应
      final response = await _waitForImagePreviewResponse(message.messageId);
      if (response != null) {
        print('🖼️🖼️🖼️ [IMAGE_DEBUG] 收到图片预览响应，开始解析...');
        return _parseImagePreviewResponse(response);
      } else {
        print('🖼️🖼️🖼️ [IMAGE_DEBUG] 图片预览响应超时!!!');
        return null;
      }
    } catch (e) {
      print('🖼️🖼️🖼️ [IMAGE_DEBUG] 获取图片预览失败: $e');
      return null;
    }
  }

  /// 等待图片预览响应
  Future<Map<String, dynamic>?> _waitForImagePreviewResponse(String messageId) async {
    try {
      print('🖼️🖼️🖼️ [IMAGE_DEBUG] 开始等待图片预览响应 - messageId: $messageId');
      
      // 创建一个Completer来处理超时
      final completer = Completer<Map<String, dynamic>?>();
      
      // 创建超时计时器
      Timer? timeoutTimer = Timer(const Duration(seconds: 15), () {
        if (!completer.isCompleted) {
          print('🖼️🖼️🖼️ [IMAGE_DEBUG] 图片预览响应超时!!! - messageId: $messageId');
          completer.complete(null);
        }
      });

      // 监听所有消息进行调试
      late StreamSubscription debugSubscription;
      debugSubscription = _socketService.messageStream.listen((message) {
        print('🖼️🖼️🖼️ [IMAGE_DEBUG] 收到消息: type=${message.type}, messageId=${message.messageId}');
        
        // 如果是我们需要的响应
        if (message.type == 'image_preview_response' && message.messageId == messageId) {
          if (!completer.isCompleted) {
            print('🖼️🖼️🖼️ [IMAGE_DEBUG] 找到匹配的图片预览响应!!!');
            timeoutTimer?.cancel();
            debugSubscription.cancel();
            completer.complete(message.toJson());
          }
        }
      }, onError: (error) {
        if (!completer.isCompleted) {
          timeoutTimer?.cancel();
          debugSubscription.cancel();
          print('🖼️🖼️🖼️ [IMAGE_DEBUG] 图片预览消息流监听错误: $error');
          completer.complete(null);
        }
      });

      return await completer.future;
    } catch (e) {
      print('🖼️🖼️🖼️ [IMAGE_DEBUG] 等待图片预览响应失败: $e');
      return null;
    }
  }

  /// 解析图片预览响应
  String? _parseImagePreviewResponse(Map<String, dynamic> response) {
    try {
      print('🖼️🖼️🖼️ [IMAGE_DEBUG] 开始解析图片预览响应: $response');
      
      final payload = response['payload'] as Map<String, dynamic>?;
      if (payload == null) {
        print('🖼️🖼️🖼️ [IMAGE_DEBUG] 图片预览响应缺少payload!!!');
        return null;
      }

      print('🖼️🖼️🖼️ [IMAGE_DEBUG] payload内容: $payload');

      final success = payload['success'] as bool? ?? false;
      if (!success) {
        final error = payload['error'] as String? ?? '未知错误';
        print('🖼️🖼️🖼️ [IMAGE_DEBUG] 图片预览请求失败: $error');
        return null;
      }

      final imageData = payload['imageData'] as String?;
      if (imageData == null || imageData.isEmpty) {
        print('🖼️🖼️🖼️ [IMAGE_DEBUG] 图片预览响应缺少图片数据!!! imageData=$imageData');
        return null;
      }

      print('🖼️🖼️🖼️ [IMAGE_DEBUG] 成功获取图片预览数据，大小: ${imageData.length}字符');
      return imageData;
    } catch (e) {
      print('🖼️🖼️🖼️ [IMAGE_DEBUG] 解析图片预览响应失败: $e');
      return null;
    }
  }

  /// 检查是否为支持预览的图片格式
  bool isImageFile(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    const supportedExtensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'];
    return supportedExtensions.contains(extension);
  }

  /// 获取文件类型  
  FileItemType _getFileTypeFromName(String fileName) {
    // 目前FileItemType只有两种类型：directory 和 file
    // 所有非目录项都返回 file 类型
    return FileItemType.file;
  }
} 