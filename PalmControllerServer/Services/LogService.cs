using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using Serilog;
using Serilog.Context;
using Serilog.Core;
using Serilog.Events;

namespace PalmControllerServer.Services
{
    /// <summary>
    /// 日志级别枚举
    /// </summary>
    public enum LogLevel
    {
        Debug,
        Info,
        Warning,
        Error,
        Fatal
    }

    /// <summary>
    /// 日志条目数据模型
    /// </summary>
    public class LogEntry
    {
        public DateTime Timestamp { get; set; }
        public LogLevel Level { get; set; }
        public string Message { get; set; } = string.Empty;
        public string Category { get; set; } = string.Empty;
        public string? UserId { get; set; }
        public string? SessionId { get; set; }
        public Dictionary<string, object>? Metadata { get; set; }
        public string? StackTrace { get; set; }

        public override string ToString()
        {
            return $"[{Timestamp:yyyy-MM-dd HH:mm:ss.fff}] [{Level.ToString().ToUpper()}] [{Category}] {Message}";
        }
    }

    /// <summary>
    /// 统一日志服务
    /// </summary>
    public class LogService : IDisposable
    {
        private static LogService? _instance;
        private static readonly object _lock = new object();

        public static LogService Instance
        {
            get
            {
                if (_instance == null)
                {
                    lock (_lock)
                    {
                        _instance ??= new LogService();
                    }
                }
                return _instance;
            }
        }

        private readonly ILogger _logger;
        private readonly string _sessionId;
        private string? _userId;

        private LogService()
        {
            _sessionId = DateTimeOffset.Now.ToUnixTimeMilliseconds().ToString();
            _logger = CreateLogger();
            
            // 应用启动日志
            Info("PalmController Server started", "System", new Dictionary<string, object>
            {
                { "sessionId", _sessionId },
                { "version", "0.1.0" },
                { "environment", "Development" }
            });
        }

        private ILogger CreateLogger()
        {
            var logDir = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "logs");
            if (!Directory.Exists(logDir))
            {
                Directory.CreateDirectory(logDir);
            }

            return new LoggerConfiguration()
                .MinimumLevel.Debug()
                .MinimumLevel.Override("Microsoft", LogEventLevel.Warning)
                .MinimumLevel.Override("System", LogEventLevel.Warning)
                .Enrich.FromLogContext()
                .Enrich.WithProperty("Application", "PalmController")
                .Enrich.WithProperty("MachineName", Environment.MachineName)
                .Enrich.WithProperty("ProcessId", Environment.ProcessId)
                .WriteTo.Console(
                    outputTemplate: "[{Timestamp:HH:mm:ss} {Level:u3}] [{Category}] {Message:lj}{NewLine}{Exception}")
                .WriteTo.File(
                    path: Path.Combine(logDir, "app-.log"),
                    rollingInterval: RollingInterval.Day,
                    retainedFileCountLimit: 30,
                    fileSizeLimitBytes: 100 * 1024 * 1024, // 100MB
                    outputTemplate: "[{Timestamp:yyyy-MM-dd HH:mm:ss.fff} {Level:u3}] [{Category}] {Message:lj} {Properties:j}{NewLine}{Exception}")
                .WriteTo.File(
                    path: Path.Combine(logDir, "error-.log"),
                    rollingInterval: RollingInterval.Day,
                    retainedFileCountLimit: 30,
                    restrictedToMinimumLevel: LogEventLevel.Error,
                    outputTemplate: "[{Timestamp:yyyy-MM-dd HH:mm:ss.fff} {Level:u3}] [{Category}] {Message:lj} {Properties:j}{NewLine}{Exception}")
                .CreateLogger();
        }

        /// <summary>
        /// 设置用户ID
        /// </summary>
        public void SetUserId(string? userId)
        {
            _userId = userId;
        }

        /// <summary>
        /// Debug日志
        /// </summary>
        public void Debug(string message, string category = "App", Dictionary<string, object>? metadata = null)
        {
            LogInternal(LogLevel.Debug, message, category, metadata);
        }

        /// <summary>
        /// Info日志
        /// </summary>
        public void Info(string message, string category = "App", Dictionary<string, object>? metadata = null)
        {
            LogInternal(LogLevel.Info, message, category, metadata);
        }

        /// <summary>
        /// Warning日志
        /// </summary>
        public void Warning(string message, string category = "App", Dictionary<string, object>? metadata = null)
        {
            LogInternal(LogLevel.Warning, message, category, metadata);
        }

        /// <summary>
        /// Error日志
        /// </summary>
        public void Error(string message, Exception? exception = null, string category = "App", Dictionary<string, object>? metadata = null)
        {
            var errorMetadata = metadata ?? new Dictionary<string, object>();
            if (exception != null)
            {
                errorMetadata["error"] = exception.ToString();
            }

            LogInternal(LogLevel.Error, message, category, errorMetadata, exception?.StackTrace);
        }

        /// <summary>
        /// Fatal日志
        /// </summary>
        public void Fatal(string message, Exception? exception = null, string category = "App", Dictionary<string, object>? metadata = null)
        {
            var errorMetadata = metadata ?? new Dictionary<string, object>();
            if (exception != null)
            {
                errorMetadata["error"] = exception.ToString();
            }

            LogInternal(LogLevel.Fatal, message, category, errorMetadata, exception?.StackTrace);
        }

        /// <summary>
        /// Socket连接日志
        /// </summary>
        public void SocketConnection(string action, string clientId, string? remoteEndPoint = null, string? messageType = null, int? dataSize = null, string? error = null)
        {
            var metadata = new Dictionary<string, object>
            {
                ["action"] = action,
                ["clientId"] = SanitizeClientId(clientId)
            };

            if (remoteEndPoint != null) metadata["remoteEndPoint"] = remoteEndPoint;
            if (messageType != null) metadata["messageType"] = messageType;
            if (dataSize != null) metadata["dataSize"] = dataSize;
            if (error != null) metadata["error"] = error;

            var level = error != null ? LogLevel.Error : LogLevel.Info;
            LogInternal(level, $"Socket {action}: {SanitizeClientId(clientId)}", "Socket", metadata);
        }

        /// <summary>
        /// 系统控制日志
        /// </summary>
        public void SystemControl(string action, string clientId, bool success = true, string? error = null, int? duration = null)
        {
            var metadata = new Dictionary<string, object>
            {
                ["action"] = action,
                ["clientId"] = SanitizeClientId(clientId),
                ["success"] = success
            };

            if (error != null) metadata["error"] = error;
            if (duration != null) metadata["duration"] = $"{duration}ms";

            var level = success ? LogLevel.Info : LogLevel.Error;
            LogInternal(level, $"System control {action}: {(success ? "success" : "failed")}", "SystemControl", metadata);
        }

        /// <summary>
        /// 性能监控日志
        /// </summary>
        public void Performance(string operation, long duration, Dictionary<string, object>? metadata = null)
        {
            var perfMetadata = metadata ?? new Dictionary<string, object>();
            perfMetadata["operation"] = operation;
            perfMetadata["duration"] = $"{duration}ms";

            var level = duration > 1000 ? LogLevel.Warning : LogLevel.Info;
            LogInternal(level, $"Performance: {operation} took {duration}ms", "Performance", perfMetadata);
        }

        /// <summary>
        /// 安全事件日志
        /// </summary>
        public void Security(string action, string? clientId = null, string? ipAddress = null, bool success = true, string? reason = null)
        {
            var metadata = new Dictionary<string, object>
            {
                ["action"] = action,
                ["success"] = success
            };

            if (clientId != null) metadata["clientId"] = SanitizeClientId(clientId);
            if (ipAddress != null) metadata["ipAddress"] = ipAddress;
            if (reason != null) metadata["reason"] = reason;

            var level = success ? LogLevel.Info : LogLevel.Warning;
            LogInternal(level, $"Security: {action} {(success ? "allowed" : "denied")}", "Security", metadata);
        }

        private void LogInternal(LogLevel level, string message, string category, Dictionary<string, object>? metadata = null, string? stackTrace = null)
        {
            var entry = new LogEntry
            {
                Timestamp = DateTime.Now,
                Level = level,
                Message = message,
                Category = category,
                UserId = _userId,
                SessionId = _sessionId,
                Metadata = metadata,
                StackTrace = stackTrace
            };

            // 添加上下文属性
            using (LogContext.PushProperty("Category", category))
            using (LogContext.PushProperty("SessionId", _sessionId))
            using (LogContext.PushProperty("UserId", _userId))
            {
                if (metadata != null)
                {
                    foreach (var kvp in metadata)
                    {
                        LogContext.PushProperty(kvp.Key, kvp.Value);
                    }
                }

                // 使用Serilog输出
                switch (level)
                {
                    case LogLevel.Debug:
                        _logger.Debug(message);
                        break;
                    case LogLevel.Info:
                        _logger.Information(message);
                        break;
                    case LogLevel.Warning:
                        _logger.Warning(message);
                        break;
                    case LogLevel.Error:
                        if (stackTrace != null)
                        {
                            _logger.Error(message + Environment.NewLine + "StackTrace: " + stackTrace);
                        }
                        else
                        {
                            _logger.Error(message);
                        }
                        break;
                    case LogLevel.Fatal:
                        if (stackTrace != null)
                        {
                            _logger.Fatal(message + Environment.NewLine + "StackTrace: " + stackTrace);
                        }
                        else
                        {
                            _logger.Fatal(message);
                        }
                        break;
                }
            }
        }

        /// <summary>
        /// 脱敏处理客户端ID（只显示前8位）
        /// </summary>
        private string SanitizeClientId(string clientId)
        {
            if (string.IsNullOrEmpty(clientId) || clientId.Length <= 8)
                return clientId;
            
            return clientId.Substring(0, 8) + "...";
        }

        /// <summary>
        /// 获取日志文件列表
        /// </summary>
        public List<FileInfo> GetLogFiles()
        {
            var logDir = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "logs");
            if (!Directory.Exists(logDir))
                return new List<FileInfo>();

            var directory = new DirectoryInfo(logDir);
            return directory.GetFiles("*.log")
                .OrderByDescending(f => f.LastWriteTime)
                .ToList();
        }

        /// <summary>
        /// 清理过期日志
        /// </summary>
        public void CleanupOldLogs(int keepDays = 30)
        {
            try
            {
                var files = GetLogFiles();
                var cutoffTime = DateTime.Now.AddDays(-keepDays);

                foreach (var file in files)
                {
                    if (file.LastWriteTime < cutoffTime)
                    {
                        file.Delete();
                        Info($"Deleted old log file: {file.Name}", "LogService");
                    }
                }
            }
            catch (Exception ex)
            {
                Error("Failed to cleanup old logs", ex, "LogService");
            }
        }

        /// <summary>
        /// 导出日志
        /// </summary>
        public string? ExportLogs()
        {
            try
            {
                var files = GetLogFiles();
                if (!files.Any()) return null;

                var exportDir = Path.Combine(Path.GetTempPath(), "PalmControllerLogs");
                if (!Directory.Exists(exportDir))
                {
                    Directory.CreateDirectory(exportDir);
                }

                var exportFile = Path.Combine(exportDir, $"palm_controller_logs_{DateTimeOffset.Now.ToUnixTimeMilliseconds()}.txt");
                
                using (var writer = new StreamWriter(exportFile))
                {
                    writer.WriteLine("PalmController服务端日志导出");
                    writer.WriteLine($"导出时间: {DateTime.Now:yyyy-MM-dd HH:mm:ss}");
                    writer.WriteLine($"Session ID: {_sessionId}");
                    if (_userId != null) writer.WriteLine($"User ID: {_userId}");
                    writer.WriteLine(new string('=', 50));
                    writer.WriteLine();

                    foreach (var file in files)
                    {
                        writer.WriteLine($"=== {file.Name} ===");
                        writer.WriteLine(File.ReadAllText(file.FullName));
                        writer.WriteLine();
                    }
                }

                return exportFile;
            }
            catch (Exception ex)
            {
                Error("Failed to export logs", ex, "LogService");
                return null;
            }
        }

        public void Dispose()
        {
            try
            {
                Info("PalmController Server shutting down", "System");
                Log.CloseAndFlush();
            }
            catch
            {
                // 忽略释放时的错误
            }
        }
    }
} 