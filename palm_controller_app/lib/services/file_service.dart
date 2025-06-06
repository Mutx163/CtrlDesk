import 'dart:io';
import 'dart:convert';
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
  Future<List<FileItem>> getPCFiles([String? directoryPath]) async {
    try {
      final message = ControlMessage.fileOperation(
        operation: 'list_files',
        path: directoryPath ?? '',
        messageId: DateTime.now().millisecondsSinceEpoch.toString(),
      );

      _logService.info('请求PC文件列表: $directoryPath', category: 'FileService');
      
      // 发送消息
      final success = await _socketService.sendMessage(message);
      if (!success) {
        _logService.warning('发送文件列表请求失败', category: 'FileService');
        return [];
      }

      // 简化版本：返回模拟数据，实际版本需要等待服务器响应
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 这里应该监听socketService的messageStream来获取响应
      // 为了简化，返回空列表
      return [];
    } catch (e) {
      _logService.error('获取PC文件列表异常: $e', category: 'FileService');
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
} 