using Newtonsoft.Json;
using System;
using System.Collections.Generic;

namespace PalmControllerServer.Models
{
    public class ControlMessage
    {
        [JsonProperty("messageId")]
        public string MessageId { get; set; } = string.Empty;

        [JsonProperty("type")]
        public string Type { get; set; } = string.Empty;

        [JsonProperty("timestamp")]
        public DateTime Timestamp { get; set; }

        [JsonProperty("payload")]
        public Dictionary<string, object> Payload { get; set; } = new();

        // 构造函数
        public ControlMessage() { }

        public ControlMessage(string messageId, string type, DateTime timestamp, Dictionary<string, object> payload)
        {
            MessageId = messageId;
            Type = type;
            Timestamp = timestamp;
            Payload = payload;
        }

        // 创建鼠标控制消息
        public static ControlMessage CreateMouseControl(string messageId, string action, 
            double deltaX = 0, double deltaY = 0, string button = "left", int clicks = 1)
        {
            return new ControlMessage(messageId, "mouse_control", DateTime.Now, new Dictionary<string, object>
            {
                ["action"] = action,
                ["deltaX"] = deltaX,
                ["deltaY"] = deltaY,
                ["button"] = button,
                ["clicks"] = clicks
            });
        }

        // 创建键盘控制消息
        public static ControlMessage CreateKeyboardControl(string messageId, string action, 
            string? keyCode = null, string? text = null, List<string>? modifiers = null)
        {
            var payload = new Dictionary<string, object>
            {
                ["action"] = action,
                ["modifiers"] = modifiers ?? new List<string>()
            };

            if (keyCode != null)
                payload["keyCode"] = keyCode;
            if (text != null)
                payload["text"] = text;

            return new ControlMessage(messageId, "keyboard_control", DateTime.Now, payload);
        }

        // 创建媒体控制消息
        public static ControlMessage CreateMediaControl(string messageId, string action)
        {
            return new ControlMessage(messageId, "media_control", DateTime.Now, new Dictionary<string, object>
            {
                ["action"] = action
            });
        }

        // 创建系统控制消息
        public static ControlMessage CreateSystemControl(string messageId, string action)
        {
            return new ControlMessage(messageId, "system_control", DateTime.Now, new Dictionary<string, object>
            {
                ["action"] = action
            });
        }

        // 创建音量状态消息
        public static ControlMessage CreateVolumeStatus(string messageId, float volume, bool isMuted)
        {
            return new ControlMessage(messageId, "volume_status", DateTime.Now, new Dictionary<string, object>
            {
                ["volume"] = volume,
                ["muted"] = isMuted,
                ["timestamp"] = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss")
            });
        }

        // 创建认证消息
        public static ControlMessage CreateAuthentication(string messageId, string? password = null)
        {
            var payload = new Dictionary<string, object>();
            if (password != null)
                payload["password"] = password;

            return new ControlMessage(messageId, "auth", DateTime.Now, payload);
        }

        // 创建心跳消息
        public static ControlMessage CreateHeartbeat(string messageId)
        {
            return new ControlMessage(messageId, "heartbeat", DateTime.Now, new Dictionary<string, object>());
        }

        // 创建硬件信息消息
        public static ControlMessage CreateHardwareInfo(string messageId, string osVersion, string cpuName, 
            string cpuCores, string ramTotal, string gpuName, string motherboard)
        {
            return new ControlMessage(messageId, "hardware_info", DateTime.Now, new Dictionary<string, object>
            {
                ["os_version"] = osVersion,
                ["cpu_name"] = cpuName,
                ["cpu_cores"] = cpuCores,
                ["ram_total"] = ramTotal,
                ["gpu_name"] = gpuName,
                ["motherboard"] = motherboard
            });
        }

        // 创建系统状态消息（增强版本，包含更多性能数据）
        public static ControlMessage CreateSystemStatus(string messageId, double cpuUsage, double ramUsage, 
            double gpuUsage, double diskUsage, double cpuTemp, double gpuTemp, double motherboardTemp, 
            int fanSpeed, double networkUpload, double networkDownload, long memoryUsedMB = 0, 
            long memoryTotalMB = 0, long memoryAvailableMB = 0, int processCount = 0, int threadCount = 0, 
            double systemUptime = 0, string cpuFrequency = "", double diskReadSpeed = 0, 
            double diskWriteSpeed = 0, double networkLatency = 0, int batteryLevel = -1, 
            string powerStatus = "", double gpuMemoryUsage = 0, string activeWindow = "", 
            int handleCount = 0, double pageFileUsage = 0)
        {
            return new ControlMessage(messageId, "system_status", DateTime.Now, new Dictionary<string, object>
            {
                ["cpu_usage"] = cpuUsage,
                ["ram_usage"] = ramUsage,
                ["gpu_usage"] = gpuUsage,
                ["disk_usage"] = diskUsage,
                ["cpu_temp"] = cpuTemp,
                ["gpu_temp"] = gpuTemp,
                ["motherboard_temp"] = motherboardTemp,
                ["fan_speed"] = fanSpeed,
                ["network_upload"] = networkUpload,
                ["network_download"] = networkDownload,
                // 新增的丰富性能数据
                ["memory_used_mb"] = memoryUsedMB,
                ["memory_total_mb"] = memoryTotalMB,
                ["memory_available_mb"] = memoryAvailableMB,
                ["process_count"] = processCount,
                ["thread_count"] = threadCount,
                ["system_uptime"] = systemUptime,
                ["cpu_frequency"] = cpuFrequency,
                ["disk_read_speed"] = diskReadSpeed,
                ["disk_write_speed"] = diskWriteSpeed,
                ["network_latency"] = networkLatency,
                ["battery_level"] = batteryLevel,
                ["power_status"] = powerStatus,
                ["gpu_memory_usage"] = gpuMemoryUsage,
                ["active_window"] = activeWindow,
                ["handle_count"] = handleCount,
                ["page_file_usage"] = pageFileUsage
            });
        }

        // 创建响应消息
        public static ControlMessage CreateResponse(string messageId, bool success, string? message = null)
        {
            var payload = new Dictionary<string, object>
            {
                ["success"] = success
            };

            if (message != null)
                payload["message"] = message;

            return new ControlMessage(messageId, "response", DateTime.Now, payload);
        }

        // 序列化为JSON
        public string ToJson()
        {
            return JsonConvert.SerializeObject(this);
        }

        // 从JSON反序列化
        public static ControlMessage? FromJson(string json)
        {
            try
            {
                return JsonConvert.DeserializeObject<ControlMessage>(json);
            }
            catch
            {
                return null;
            }
        }

        public override string ToString()
        {
            return $"ControlMessage(MessageId: {MessageId}, Type: {Type}, Timestamp: {Timestamp})";
        }
    }
} 