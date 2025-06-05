import 'dart:io';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

/// 日志级别枚举
enum LogLevel {
  debug,
  info,
  warning,
  error,
  fatal,
}

/// 日志条目数据模型
class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final String category;
  final String? userId;
  final String? sessionId;
  final Map<String, dynamic>? metadata;
  final String? stackTrace;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    required this.category,
    this.userId,
    this.sessionId,
    this.metadata,
    this.stackTrace,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'level': level.name,
    'message': message,
    'category': category,
    if (userId != null) 'userId': userId,
    if (sessionId != null) 'sessionId': sessionId,
    if (metadata != null) 'metadata': metadata,
    if (stackTrace != null) 'stackTrace': stackTrace,
  };

  factory LogEntry.fromJson(Map<String, dynamic> json) => LogEntry(
    timestamp: DateTime.parse(json['timestamp']),
    level: LogLevel.values.byName(json['level']),
    message: json['message'],
    category: json['category'],
    userId: json['userId'],
    sessionId: json['sessionId'],
    metadata: json['metadata'] != null ? Map<String, dynamic>.from(json['metadata']) : null,
    stackTrace: json['stackTrace'],
  );

  @override
  String toString() {
    return '[${timestamp.toIso8601String()}] [${level.name.toUpperCase()}] [$category] $message';
  }
}

/// 自定义文件输出器
class FileOutput extends LogOutput {
  final File file;
  final int maxFileSize;
  final int maxFiles;

  FileOutput({
    required this.file,
    this.maxFileSize = 10 * 1024 * 1024, // 10MB
    this.maxFiles = 5,
  });

  @override
  void output(OutputEvent event) {
    try {
      _rotateFileIfNeeded();
      
      for (final line in event.lines) {
        file.writeAsStringSync('$line\n', mode: FileMode.append);
      }
    } catch (e) {
      // 静默处理文件写入错误，避免日志系统本身影响应用
    }
  }

  void _rotateFileIfNeeded() {
    if (!file.existsSync()) return;
    
    final fileSize = file.lengthSync();
    if (fileSize > maxFileSize) {
      _rotateFiles();
    }
  }

  void _rotateFiles() {
    final directory = file.parent;
    final baseName = file.path.split('/').last.split('.').first;
    final extension = file.path.split('/').last.split('.').last;

    // 删除最老的日志文件
    final oldestFile = File('${directory.path}/${baseName}_$maxFiles.$extension');
    if (oldestFile.existsSync()) {
      oldestFile.deleteSync();
    }

    // 重命名现有文件
    for (int i = maxFiles - 1; i >= 1; i--) {
      final currentFile = File('${directory.path}/${baseName}_$i.$extension');
      final nextFile = File('${directory.path}/${baseName}_${i + 1}.$extension');
      
      if (currentFile.existsSync()) {
        currentFile.renameSync(nextFile.path);
      }
    }

    // 重命名当前文件
    if (file.existsSync()) {
      final rotatedFile = File('${directory.path}/${baseName}_1.$extension');
      file.renameSync(rotatedFile.path);
    }
  }
}

/// 统一日志服务
class LogService {
  static LogService? _instance;
  static LogService get instance => _instance ??= LogService._internal();

  Logger? _logger;
  late String _sessionId;
  String? _userId;
  
  LogService._internal() {
    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    // 创建临时控制台logger
    _logger = Logger(
      printer: SimplePrinter(),
      output: ConsoleOutput(),
    );
    _initializeLogger();
  }

  Future<void> _initializeLogger() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logDir = Directory('${directory.path}/palm_controller_logs');
      if (!logDir.existsSync()) {
        logDir.createSync(recursive: true);
      }

      final logFile = File('${logDir.path}/app.log');
      
      _logger = Logger(
        printer: PrettyPrinter(
          methodCount: 2,
          errorMethodCount: 8,
          lineLength: 120,
          colors: false, // 文件日志不需要颜色
          printEmojis: false,
          dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
        ),
        output: MultiOutput([
          ConsoleOutput(), // 控制台输出（调试时可见）
          FileOutput(file: logFile), // 文件输出
        ]),
        level: Level.debug,
      );
    } catch (e) {
      // 如果日志系统初始化失败，创建一个最小化的logger
      _logger = Logger(
        printer: SimplePrinter(),
        output: ConsoleOutput(),
      );
    }
  }

  /// 设置用户ID
  void setUserId(String? userId) {
    _userId = userId;
  }

  /// Debug日志
  void debug(String message, {
    String category = 'App',
    Map<String, dynamic>? metadata,
  }) {
    _log(LogLevel.debug, message, category, metadata: metadata);
  }

  /// Info日志
  void info(String message, {
    String category = 'App',
    Map<String, dynamic>? metadata,
  }) {
    _log(LogLevel.info, message, category, metadata: metadata);
  }

  /// Warning日志
  void warning(String message, {
    String category = 'App',
    Map<String, dynamic>? metadata,
  }) {
    _log(LogLevel.warning, message, category, metadata: metadata);
  }

  /// Error日志
  void error(String message, {
    String category = 'App',
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
  }) {
    final errorMetadata = <String, dynamic>{
      if (metadata != null) ...metadata,
      if (error != null) 'error': error.toString(),
    };
    
    _log(LogLevel.error, message, category, 
      metadata: errorMetadata, 
      stackTrace: stackTrace?.toString());
  }

  /// Fatal日志
  void fatal(String message, {
    String category = 'App',
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
  }) {
    final errorMetadata = <String, dynamic>{
      if (metadata != null) ...metadata,
      if (error != null) 'error': error.toString(),
    };
    
    _log(LogLevel.fatal, message, category, 
      metadata: errorMetadata, 
      stackTrace: stackTrace?.toString());
  }

  /// 网络请求日志
  void networkRequest({
    required String method,
    required String url,
    Map<String, String>? headers,
    dynamic body,
    int? statusCode,
    int? duration,
  }) {
    final metadata = <String, dynamic>{
      'method': method,
      'url': _sanitizeUrl(url),
      if (headers != null) 'headers': _sanitizeHeaders(headers),
      if (body != null) 'bodySize': body.toString().length,
      if (statusCode != null) 'statusCode': statusCode,
      if (duration != null) 'duration': '${duration}ms',
    };

    final level = (statusCode != null && statusCode >= 400) ? LogLevel.error : LogLevel.info;
    _log(level, 'Network $method $url', 'Network', metadata: metadata);
  }

  /// Socket连接日志
  void socketConnection({
    required String action, // connect, disconnect, send, receive
    required String host,
    required int port,
    String? messageType,
    int? dataSize,
    String? error,
  }) {
    final metadata = <String, dynamic>{
      'action': action,
      'host': host,
      'port': port,
      if (messageType != null) 'messageType': messageType,
      if (dataSize != null) 'dataSize': dataSize,
      if (error != null) 'error': error,
    };

    final level = error != null ? LogLevel.error : LogLevel.info;
    _log(level, 'Socket $action $host:$port', 'Socket', metadata: metadata);
  }

  /// 用户操作日志
  void userAction({
    required String action,
    String? screen,
    Map<String, dynamic>? parameters,
  }) {
    final metadata = <String, dynamic>{
      'action': action,
      if (screen != null) 'screen': screen,
      if (parameters != null) 'parameters': parameters,
    };

    _log(LogLevel.info, 'User action: $action', 'UserAction', metadata: metadata);
  }

  /// 性能监控日志
  void performance({
    required String operation,
    required int duration,
    Map<String, dynamic>? metadata,
  }) {
    final perfMetadata = <String, dynamic>{
      'operation': operation,
      'duration': '${duration}ms',
      if (metadata != null) ...metadata,
    };

    final level = duration > 1000 ? LogLevel.warning : LogLevel.info;
    _log(level, 'Performance: $operation took ${duration}ms', 'Performance', metadata: perfMetadata);
  }

  void _log(LogLevel level, String message, String category, {
    Map<String, dynamic>? metadata,
    String? stackTrace,
  }) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      category: category,
      userId: _userId,
      sessionId: _sessionId,
      metadata: metadata,
      stackTrace: stackTrace,
    );

    // 使用Logger输出，如果还未初始化则降级到控制台输出
    final logger = _logger;
    if (logger != null) {
      switch (level) {
        case LogLevel.debug:
          logger.d(entry.toString());
          break;
        case LogLevel.info:
          logger.i(entry.toString());
          break;
        case LogLevel.warning:
          logger.w(entry.toString());
          break;
        case LogLevel.error:
          logger.e(entry.toString());
          break;
        case LogLevel.fatal:
          logger.f(entry.toString());
          break;
      }
    }
  }

  /// URL脱敏处理
  String _sanitizeUrl(String url) {
    // 移除查询参数中的敏感信息
    final uri = Uri.parse(url);
    final sanitizedQuery = uri.queryParameters.map((key, value) {
      if (key.toLowerCase().contains('password') || 
          key.toLowerCase().contains('token') ||
          key.toLowerCase().contains('key')) {
        return MapEntry(key, '***');
      }
      return MapEntry(key, value);
    });

    return uri.replace(queryParameters: sanitizedQuery.isEmpty ? null : sanitizedQuery).toString();
  }

  /// Header脱敏处理
  Map<String, String> _sanitizeHeaders(Map<String, String> headers) {
    return headers.map((key, value) {
      if (key.toLowerCase().contains('authorization') ||
          key.toLowerCase().contains('token') ||
          key.toLowerCase().contains('key')) {
        return MapEntry(key, '***');
      }
      return MapEntry(key, value);
    });
  }

  /// 获取日志文件列表
  Future<List<File>> getLogFiles() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logDir = Directory('${directory.path}/palm_controller_logs');
      
      if (!logDir.existsSync()) {
        return [];
      }

      return logDir
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.log'))
          .toList()
        ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    } catch (e) {
      return [];
    }
  }

  /// 清理过期日志
  Future<void> cleanupOldLogs({int keepDays = 7}) async {
    try {
      final files = await getLogFiles();
      final cutoffTime = DateTime.now().subtract(Duration(days: keepDays));

      for (final file in files) {
        if (file.lastModifiedSync().isBefore(cutoffTime)) {
          file.deleteSync();
        }
      }
    } catch (e) {
      error('Failed to cleanup old logs', error: e, category: 'LogService');
    }
  }

  /// 导出日志
  Future<String?> exportLogs() async {
    try {
      final files = await getLogFiles();
      if (files.isEmpty) return null;

      final exportDir = await getTemporaryDirectory();
      final exportFile = File('${exportDir.path}/palm_controller_logs_${DateTime.now().millisecondsSinceEpoch}.txt');

      final buffer = StringBuffer();
      buffer.writeln('PalmController日志导出');
      buffer.writeln('导出时间: ${DateTime.now().toIso8601String()}');
      buffer.writeln('Session ID: $_sessionId');
      if (_userId != null) buffer.writeln('User ID: $_userId');
      buffer.writeln('=' * 50);
      buffer.writeln();

      for (final file in files) {
        buffer.writeln('=== ${file.path.split('/').last} ===');
        buffer.writeln(file.readAsStringSync());
        buffer.writeln();
      }

      exportFile.writeAsStringSync(buffer.toString());
      return exportFile.path;
    } catch (e) {
      error('Failed to export logs', error: e, category: 'LogService');
      return null;
    }
  }

  /// 释放资源
  void dispose() {
    _logger?.close();
  }
} 