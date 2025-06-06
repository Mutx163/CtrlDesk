import 'package:flutter/material.dart';

class FileItem {
  final String name;
  final String path;
  final FileItemType type;
  final int size;
  final DateTime lastModified;
  final String? extension;
  final String? mimeType;
  final bool isHidden;

  const FileItem({
    required this.name,
    required this.path,
    required this.type,
    required this.size,
    required this.lastModified,
    this.extension,
    this.mimeType,
    this.isHidden = false,
  });

  factory FileItem.fromJson(Map<String, dynamic> json) {
    return FileItem(
      name: json['name'] as String,
      path: json['path'] as String,
      type: FileItemType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => FileItemType.file,
      ),
      size: json['size'] as int,
      lastModified: DateTime.parse(json['lastModified'] as String),
      extension: json['extension'] as String?,
      mimeType: json['mimeType'] as String?,
      isHidden: json['isHidden'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'path': path,
      'type': type.name,
      'size': size,
      'lastModified': lastModified.toIso8601String(),
      'extension': extension,
      'mimeType': mimeType,
      'isHidden': isHidden,
    };
  }

  FileItem copyWith({
    String? name,
    String? path,
    FileItemType? type,
    int? size,
    DateTime? lastModified,
    String? extension,
    String? mimeType,
    bool? isHidden,
  }) {
    return FileItem(
      name: name ?? this.name,
      path: path ?? this.path,
      type: type ?? this.type,
      size: size ?? this.size,
      lastModified: lastModified ?? this.lastModified,
      extension: extension ?? this.extension,
      mimeType: mimeType ?? this.mimeType,
      isHidden: isHidden ?? this.isHidden,
    );
  }
}

enum FileItemType {
  directory,
  file,
}

extension FileItemTypeExtension on FileItemType {
  bool get isDirectory => this == FileItemType.directory;
  bool get isFile => this == FileItemType.file;
}

extension FileItemExtension on FileItem {
  String get displayName => name;
  
  String get displaySize {
    if (type.isDirectory) return '';
    
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    int unitIndex = 0;
    double fileSize = size.toDouble();
    
    while (fileSize >= 1024 && unitIndex < units.length - 1) {
      fileSize /= 1024;
      unitIndex++;
    }
    
    return '${fileSize.toStringAsFixed(unitIndex == 0 ? 0 : 1)} ${units[unitIndex]}';
  }
  
  IconData get icon {
    if (type.isDirectory) {
      return Icons.folder;
    }
    
    switch (extension?.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.gif':
      case '.bmp':
      case '.webp':
        return Icons.image;
      case '.mp4':
      case '.avi':
      case '.mkv':
      case '.mov':
      case '.wmv':
      case '.flv':
        return Icons.video_file;
      case '.mp3':
      case '.wav':
      case '.flac':
      case '.aac':
      case '.ogg':
        return Icons.audio_file;
      case '.pdf':
        return Icons.picture_as_pdf;
      case '.doc':
      case '.docx':
        return Icons.description;
      case '.xls':
      case '.xlsx':
        return Icons.table_chart;
      case '.ppt':
      case '.pptx':
        return Icons.slideshow;
      case '.zip':
      case '.rar':
      case '.7z':
      case '.tar':
      case '.gz':
        return Icons.archive;
      case '.txt':
        return Icons.text_snippet;
      case '.apk':
        return Icons.android;
      default:
        return Icons.insert_drive_file;
    }
  }
  
  Color get iconColor {
    if (type.isDirectory) {
      return const Color(0xFF2196F3); // Blue for folders
    }
    
    switch (extension?.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.gif':
      case '.bmp':
      case '.webp':
        return const Color(0xFF4CAF50); // Green for images
      case '.mp4':
      case '.avi':
      case '.mkv':
      case '.mov':
      case '.wmv':
      case '.flv':
        return const Color(0xFFE91E63); // Pink for videos
      case '.mp3':
      case '.wav':
      case '.flac':
      case '.aac':
      case '.ogg':
        return const Color(0xFF9C27B0); // Purple for audio
      case '.pdf':
        return const Color(0xFFF44336); // Red for PDF
      case '.doc':
      case '.docx':
        return const Color(0xFF2196F3); // Blue for documents
      case '.xls':
      case '.xlsx':
        return const Color(0xFF4CAF50); // Green for spreadsheets
      case '.zip':
      case '.rar':
      case '.7z':
      case '.tar':
      case '.gz':
        return const Color(0xFF795548); // Brown for archives
      case '.apk':
        return const Color(0xFF4CAF50); // Green for APK
      default:
        return const Color(0xFF616161); // Grey for others
    }
  }
} 