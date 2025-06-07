using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using System.Windows.Forms;
using PalmControllerServer.Models;
using Newtonsoft.Json.Linq;

namespace PalmControllerServer.Services
{
    public class SystemControlService
    {
        // SocketServer引用，用于发送数据到客户端
        private SocketServer? _socketServer;
        
        // Windows API 常量
        private const int MOUSEEVENTF_MOVE = 0x0001;
        private const int MOUSEEVENTF_LEFTDOWN = 0x0002;
        private const int MOUSEEVENTF_LEFTUP = 0x0004;
        private const int MOUSEEVENTF_RIGHTDOWN = 0x0008;
        private const int MOUSEEVENTF_RIGHTUP = 0x0010;
        private const int MOUSEEVENTF_MIDDLEDOWN = 0x0020;
        private const int MOUSEEVENTF_MIDDLEUP = 0x0040;
        private const int MOUSEEVENTF_WHEEL = 0x0800;

        // Windows 音量 API 常量
        private const uint DEVICE_STATE_ACTIVE = 0x00000001;
        private const uint STGM_READ = 0x00000000;
        private static readonly Guid IID_IAudioEndpointVolume = new Guid("5CDF2C82-841E-4546-9722-0CF74078229A");

        // Windows API 导入
        [DllImport("user32.dll")]
        private static extern void mouse_event(int dwFlags, int dx, int dy, int dwData, int dwExtraInfo);

        [DllImport("user32.dll")]
        private static extern bool SetCursorPos(int X, int Y);

        [DllImport("user32.dll")]
        private static extern bool GetCursorPos(out POINT lpPoint);

        [DllImport("user32.dll")]
        private static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, uint dwExtraInfo);

        [DllImport("user32.dll")]
        private static extern short GetAsyncKeyState(int vKey);

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        private static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);

        // 音量控制 API 导入
        [DllImport("ole32.dll")]
        private static extern int CoCreateInstance(ref Guid rclsid, IntPtr pUnkOuter, uint dwClsContext, ref Guid riid, out IntPtr ppv);

        [DllImport("ole32.dll")]
        private static extern int CoInitialize(IntPtr pvReserved);

        [DllImport("ole32.dll")]
        private static extern void CoUninitialize();

        // 事件委托，用于音量状态改变通知
        public event Action<float, bool>? VolumeChanged;
        
        // 设置SocketServer引用
        public void SetSocketServer(SocketServer socketServer)
        {
            _socketServer = socketServer;
        }
        
        // 音量变化监听相关
        private IAudioEndpointVolume? _volumeEndpoint;
        private VolumeNotificationCallback? _volumeCallback;

        // 结构体定义
        [StructLayout(LayoutKind.Sequential)]
        public struct POINT
        {
            public int X;
            public int Y;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct INPUT
        {
            public uint Type;
            public INPUTUNION Data;
        }

        [StructLayout(LayoutKind.Explicit)]
        public struct INPUTUNION
        {
            [FieldOffset(0)]
            public MOUSEINPUT Mouse;
            [FieldOffset(0)]
            public KEYBDINPUT Keyboard;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct MOUSEINPUT
        {
            public int dx;
            public int dy;
            public uint mouseData;
            public uint dwFlags;
            public uint time;
            public IntPtr dwExtraInfo;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct KEYBDINPUT
        {
            public ushort wVk;
            public ushort wScan;
            public uint dwFlags;
            public uint time;
            public IntPtr dwExtraInfo;
        }

        // 处理控制消息
        public async void ProcessControlMessage(ControlMessage message)
        {
            var stopwatch = Stopwatch.StartNew();
            
            try
            {
                switch (message.Type)
                {
                    case "mouse_control":
                        HandleMouseControl(message);
                        break;
                    case "keyboard_control":
                        HandleKeyboardControl(message);
                        break;
                    case "media_control":
                        HandleMediaControl(message);
                        break;
                    case "system_control":
                        await HandleSystemControlAsync(message);
                        break;
                    case "file_operation":
                        await HandleFileOperationAsync(message);
                        break;
                    case "find_cursor":
                        FindCursor();
                        break;
                    case "shutdown_delayed":
                        HandleDelayedAction(message, "shutdown");
                        break;
                    case "restart_delayed":
                        HandleDelayedAction(message, "restart");
                        break;
                    case "lock_delayed":
                        HandleDelayedAction(message, "lock");
                        break;
                    case "run_command":
                        HandleRunCommand(message);
                        break;
                    default:
                        LogService.Instance.Warning($"Unknown message type: {message.Type}", "SystemControl");
                        break;
                }
                
                stopwatch.Stop();
                LogService.Instance.Performance("ProcessControlMessage", stopwatch.ElapsedMilliseconds, 
                    new Dictionary<string, object> { ["messageType"] = message.Type });
            }
            catch (Exception ex)
            {
                stopwatch.Stop();
                LogService.Instance.Error($"Error processing control message: {message.Type}", ex, "SystemControl");
            }
        }

        // 处理鼠标控制
        private void HandleMouseControl(ControlMessage message)
        {
            var action = message.Payload.GetValueOrDefault("action")?.ToString();
            var deltaX = Convert.ToDouble(message.Payload.GetValueOrDefault("deltaX", 0));
            var deltaY = Convert.ToDouble(message.Payload.GetValueOrDefault("deltaY", 0));
            var button = message.Payload.GetValueOrDefault("button")?.ToString() ?? "left";
            var clicks = Convert.ToInt32(message.Payload.GetValueOrDefault("clicks", 1));

            switch (action)
            {
                case "move":
                    MoveMouse((int)deltaX, (int)deltaY);
                    break;
                case "click":
                    ClickMouse(button, clicks);
                    break;
                case "scroll":
                    ScrollMouse((int)deltaY);
                    break;
            }

            LogService.Instance.SystemControl(action ?? "unknown", "unknown", true);
        }

        // 处理键盘控制
        private void HandleKeyboardControl(ControlMessage message)
        {
            var action = message.Payload.GetValueOrDefault("action")?.ToString();
            var keyCode = message.Payload.GetValueOrDefault("keyCode")?.ToString();
            var text = message.Payload.GetValueOrDefault("text")?.ToString();
            var modifiersObj = message.Payload.GetValueOrDefault("modifiers");

            switch (action)
            {
                case "key_press":
                    if (!string.IsNullOrEmpty(keyCode))
                    {
                        // 解析修饰键
                        var modifierList = new List<string>();
                        if (modifiersObj is Newtonsoft.Json.Linq.JArray modifiersArray)
                        {
                            foreach (var modifier in modifiersArray)
                            {
                                var modifierStr = modifier.ToString();
                                if (!string.IsNullOrEmpty(modifierStr))
                                    modifierList.Add(modifierStr);
                            }
                        }
                        else if (modifiersObj is IEnumerable<object> modifiersList)
                        {
                            foreach (var modifier in modifiersList)
                            {
                                var modifierStr = modifier.ToString();
                                if (!string.IsNullOrEmpty(modifierStr))
                                    modifierList.Add(modifierStr);
                            }
                        }
                        
                        PressKeyWithModifiers(keyCode, modifierList);
                    }
                    break;
                case "text_input":
                    if (!string.IsNullOrEmpty(text))
                        SendText(text);
                    break;
            }

            LogService.Instance.SystemControl(action ?? "unknown", "unknown", true);
        }

        // 处理媒体控制
        private void HandleMediaControl(ControlMessage message)
        {
            var action = message.Payload.GetValueOrDefault("action")?.ToString();

            switch (action)
            {
                case "play_pause":
                    SendMediaKey(Keys.MediaPlayPause);
                    break;
                case "next":
                    SendMediaKey(Keys.MediaNextTrack);
                    break;
                case "previous":
                    SendMediaKey(Keys.MediaPreviousTrack);
                    break;
                case "volume_up":
                    SendMediaKey(Keys.VolumeUp);
                    // 获取更新后的音量并通知客户端
                    NotifyVolumeChange();
                    break;
                case "volume_down":
                    SendMediaKey(Keys.VolumeDown);
                    // 获取更新后的音量并通知客户端
                    NotifyVolumeChange();
                    break;
                case "mute":
                    SendMediaKey(Keys.VolumeMute);
                    // 获取更新后的静音状态并通知客户端
                    NotifyVolumeChange();
                    break;
                case "get_volume_status":
                    // 新增：客户端请求当前音量状态
                    LogService.Instance.Info("客户端请求音量状态", "SystemControl");
                    NotifyVolumeChange();
                    break;
                case var setVolumeAction when setVolumeAction != null && setVolumeAction.StartsWith("set_volume:"):
                    // 新增：直接设置音量值
                    var volumeStr = setVolumeAction.Substring("set_volume:".Length);
                    if (float.TryParse(volumeStr, out float volumeValue))
                    {
                        SetSystemVolume(volumeValue);
                        // 设置音量后立即通知客户端
                        NotifyVolumeChange();
                        LogService.Instance.Info($"Volume set to {volumeValue:P0} via slider", "SystemControl");
                    }
                    else
                    {
                        LogService.Instance.Warning($"Invalid volume value in set_volume command: {volumeStr}", "SystemControl");
                    }
                    break;
            }

            LogService.Instance.SystemControl(action ?? "unknown", "unknown", true);
        }

        // 处理系统控制
        private async Task HandleSystemControlAsync(ControlMessage message)
        {
            var action = message.Payload.GetValueOrDefault("action")?.ToString();

            switch (action)
            {
                // 电源管理
                case "shutdown":
                    ExecuteSystemCommand("shutdown /s /t 0");
                    break;
                case "restart":
                    ExecuteSystemCommand("shutdown /r /t 0");
                    break;
                case "sleep":
                    ExecuteSystemCommand("rundll32.exe powrprof.dll,SetSuspendState 0,1,0");
                    break;
                case "lock":
                    ExecuteSystemCommand("rundll32.exe user32.dll,LockWorkStation");
                    break;
                
                // 演示控制
                case "ppt_next":
                    SendKey(Keys.Right);
                    break;
                case "ppt_previous":
                    SendKey(Keys.Left);
                    break;
                case "presentation_start":
                    SendKey(Keys.F5);
                    break;
                case "presentation_end":
                    SendKey(Keys.Escape);
                    break;
                
                // 截图功能
                case "screenshot_fullscreen":
                    await HandleScreenshotAsync(message, "fullscreen");
                    break;
                case "screenshot_window":
                    await HandleScreenshotAsync(message, "window");
                    break;
                case "screenshot_region":
                    await HandleScreenshotAsync(message, "region");
                    break;
                case "screenshot_start_continuous":
                    HandleContinuousScreenshot(message, true);
                    break;
                case "screenshot_stop_continuous":
                    HandleContinuousScreenshot(message, false);
                    break;
                
                // 硬件监控功能
                case "monitor_get_hardware_info":
                    await HandleGetHardwareInfoAsync();
                    break;
                case "monitor_refresh_performance":
                    HandleRefreshPerformanceData();
                    break;
                case "monitor_get_performance":
                    HandleGetPerformanceData();
                    break;
                case "get_system_status":
                    await HandleGetSystemStatusAsync();
                    break;
                
                // 工具功能
                case "find_cursor":
                    FindCursor();
                    break;
                
                // 定时任务功能
                case "shutdown_delayed":
                    HandleDelayedAction(message, "shutdown");
                    break;
                case "restart_delayed":
                    HandleDelayedAction(message, "restart");
                    break;
                case "lock_delayed":
                    HandleDelayedAction(message, "lock");
                    break;
                
                // 运行命令功能
                case "run_command":
                    HandleRunCommand(message);
                    break;
            }

            LogService.Instance.SystemControl(action ?? "unknown", "unknown", true);
        }

        // 处理截图请求
        private async Task HandleScreenshotAsync(ControlMessage message, string type)
        {
            try
            {
                var delay = 0;
                if (message.Payload.ContainsKey("delay") && int.TryParse(message.Payload["delay"]?.ToString(), out int parsedDelay))
                {
                    delay = parsedDelay;
                }

                string filePath;
                switch (type)
                {
                    case "fullscreen":
                        filePath = await ScreenshotService.Instance.TakeFullScreenAsync(delay);
                        break;
                    case "window":
                        filePath = await ScreenshotService.Instance.TakeActiveWindowAsync(delay);
                        break;
                    case "region":
                        // 可以从payload中解析区域参数
                        var x = message.Payload.ContainsKey("x") ? Convert.ToInt32(message.Payload["x"]) : 0;
                        var y = message.Payload.ContainsKey("y") ? Convert.ToInt32(message.Payload["y"]) : 0;
                        var width = message.Payload.ContainsKey("width") ? Convert.ToInt32(message.Payload["width"]) : 0;
                        var height = message.Payload.ContainsKey("height") ? Convert.ToInt32(message.Payload["height"]) : 0;
                        filePath = await ScreenshotService.Instance.TakeRegionAsync(x, y, width, height, delay);
                        break;
                    default:
                        throw new ArgumentException($"Unknown screenshot type: {type}");
                }

                LogService.Instance.Info($"Screenshot completed: {filePath}", "SystemControl");
                
                // 这里可以考虑将截图文件路径发送回客户端
                // 目前暂时只记录日志
            }
            catch (Exception ex)
            {
                LogService.Instance.Error($"Screenshot failed: {type}", ex, "SystemControl");
            }
        }

        // 处理连续截图
        private void HandleContinuousScreenshot(ControlMessage message, bool start)
        {
            try
            {
                if (start)
                {
                    var interval = 3; // 默认3秒
                    if (message.Payload.ContainsKey("interval") && int.TryParse(message.Payload["interval"]?.ToString(), out int parsedInterval))
                    {
                        interval = parsedInterval;
                    }
                    ScreenshotService.Instance.StartContinuousScreenshot(interval);
                    LogService.Instance.Info($"Continuous screenshot started, interval: {interval}s", "SystemControl");
                }
                else
                {
                    ScreenshotService.Instance.StopContinuousScreenshot();
                    LogService.Instance.Info("Continuous screenshot stopped", "SystemControl");
                }
            }
            catch (Exception ex)
            {
                LogService.Instance.Error($"Continuous screenshot operation failed: {start}", ex, "SystemControl");
            }
        }

        // 处理获取硬件信息请求
        private async Task HandleGetHardwareInfoAsync()
        {
            try
            {
                var hardwareInfo = await HardwareMonitorService.Instance.GetHardwareInfoAsync();
                LogService.Instance.Info("Hardware info retrieved successfully", "SystemControl");
                
                // 发送硬件信息到客户端
                await SendHardwareInfoToClients(hardwareInfo);
            }
            catch (Exception ex)
            {
                LogService.Instance.Error("Failed to get hardware info", ex, "SystemControl");
            }
        }

        // 处理刷新性能数据
        private async void HandleRefreshPerformanceData()
        {
            try
            {
                var performanceData = HardwareMonitorService.Instance.RefreshPerformanceData();
                LogService.Instance.Info("Performance data refreshed successfully", "SystemControl");
                
                // 发送性能数据到客户端
                await SendPerformanceDataToClients(performanceData);
            }
            catch (Exception ex)
            {
                LogService.Instance.Error("Failed to refresh performance data", ex, "SystemControl");
            }
        }

        // 处理获取性能数据
        private async void HandleGetPerformanceData()
        {
            try
            {
                var performanceData = HardwareMonitorService.Instance.GetPerformanceData();
                LogService.Instance.Info("Performance data retrieved successfully", "SystemControl");
                
                // 发送性能数据到客户端
                await SendPerformanceDataToClients(performanceData);
            }
            catch (Exception ex)
            {
                LogService.Instance.Error("Failed to get performance data", ex, "SystemControl");
            }
        }

        // 处理获取系统状态请求（结合硬件信息和性能数据）
        private async Task HandleGetSystemStatusAsync()
        {
            try
            {
                LogService.Instance.Info("客户端请求系统状态", "SystemControl");
                
                // 同时获取硬件信息和性能数据
                var hardwareInfo = await HardwareMonitorService.Instance.GetHardwareInfoAsync();
                var performanceData = HardwareMonitorService.Instance.GetPerformanceData();
                
                LogService.Instance.Info($"系统状态数据已收集 - CPU:{performanceData.CpuUsage:F1}%, RAM:{performanceData.RamUsage:F1}%", "SystemControl");
                
                // 发送硬件信息和性能数据到客户端
                await SendHardwareInfoToClients(hardwareInfo);
                await SendPerformanceDataToClients(performanceData);
                
                LogService.Instance.Info("系统状态数据已发送给客户端", "SystemControl");
            }
            catch (Exception ex)
            {
                LogService.Instance.Error("Failed to get system status", ex, "SystemControl");
            }
        }
        
        // 找光标功能 - 通过快速移动鼠标帮助用户定位光标
        private void FindCursor()
        {
            try
            {
                // 获取当前鼠标位置
                GetCursorPos(out POINT currentPos);
                
                // 快速移动鼠标形成小范围震动，帮助用户找到光标
                for (int i = 0; i < 8; i++)
                {
                    var offsetX = (i % 2 == 0) ? 20 : -20;
                    var offsetY = (i % 4 < 2) ? 10 : -10;
                    
                    MoveMouse(offsetX, offsetY);
                    System.Threading.Thread.Sleep(50);
                }
                
                // 恢复到原始位置
                SetCursorPos(currentPos.X, currentPos.Y);
                
                LogService.Instance.Info("Find cursor executed successfully", "SystemControl");
            }
            catch (Exception ex)
            {
                LogService.Instance.Error("Failed to execute find cursor", ex, "SystemControl");
            }
        }

        // 处理文件操作
        private async Task HandleFileOperationAsync(ControlMessage message)
        {
            var operation = message.Payload.GetValueOrDefault("operation")?.ToString();
            var path = message.Payload.GetValueOrDefault("path")?.ToString() ?? "";
            var name = message.Payload.GetValueOrDefault("name")?.ToString();
            var data = message.Payload.GetValueOrDefault("data")?.ToString();

            try
            {
                switch (operation)
                {
                    case "list_files":
                        await HandleListFilesAsync(message.MessageId, path);
                        break;
                    case "create_directory":
                        await HandleCreateDirectoryAsync(message.MessageId, path, name);
                        break;
                    case "delete":
                        await HandleDeleteFileAsync(message.MessageId, path);
                        break;
                    case "rename":
                        await HandleRenameFileAsync(message.MessageId, path, name);
                        break;
                    case "upload":
                        await HandleUploadFileAsync(message.MessageId, path, data);
                        break;
                    case "download":
                        await HandleDownloadFileAsync(message.MessageId, path);
                        break;
                    case "preview_image":
                        await HandleImagePreviewAsync(message.MessageId, path);
                        break;
                    default:
                        LogService.Instance.Warning($"Unknown file operation: {operation}", "FileSystem");
                        break;
                }
            }
            catch (Exception ex)
            {
                LogService.Instance.Error($"File operation failed: {operation}", ex, "FileSystem");
                
                // 发送错误响应
                var errorResponse = ControlMessage.CreateResponse(message.MessageId, false, ex.Message);
                await _socketServer?.BroadcastMessageAsync(errorResponse);
                         }
         }

         // 文件列表操作
         private async Task HandleListFilesAsync(string messageId, string path)
         {
             try
             {
                 var files = new List<Dictionary<string, object>>();
                 
                 // 如果路径为空，返回驱动器列表
                 if (string.IsNullOrEmpty(path))
                 {
                     var drives = DriveInfo.GetDrives();
                     foreach (var drive in drives)
                     {
                         if (drive.IsReady)
                         {
                             files.Add(new Dictionary<string, object>
                             {
                                 ["name"] = $"{drive.Name} ({drive.DriveType})",
                                 ["path"] = drive.RootDirectory.FullName,
                                 ["type"] = "directory",
                                 ["size"] = 0,
                                 ["lastModified"] = DateTime.Now.ToString("yyyy-MM-ddTHH:mm:ss"),
                                 ["isHidden"] = false
                             });
                         }
                     }
                 }
                 else
                 {
                     var directory = new DirectoryInfo(path);
                     if (directory.Exists)
                     {
                         // 添加目录
                         foreach (var dir in directory.GetDirectories())
                         {
                             try
                             {
                                 files.Add(new Dictionary<string, object>
                                 {
                                     ["name"] = dir.Name,
                                     ["path"] = dir.FullName,
                                     ["type"] = "directory",
                                     ["size"] = 0,
                                     ["lastModified"] = dir.LastWriteTime.ToString("yyyy-MM-ddTHH:mm:ss"),
                                     ["isHidden"] = (dir.Attributes & FileAttributes.Hidden) != 0
                                 });
                             }
                             catch
                             {
                                 // 跳过无法访问的目录
                             }
                         }
                         
                         // 添加文件
                         foreach (var file in directory.GetFiles())
                         {
                             try
                             {
                                 files.Add(new Dictionary<string, object>
                                 {
                                     ["name"] = file.Name,
                                     ["path"] = file.FullName,
                                     ["type"] = "file",
                                     ["size"] = file.Length,
                                     ["lastModified"] = file.LastWriteTime.ToString("yyyy-MM-ddTHH:mm:ss"),
                                     ["isHidden"] = (file.Attributes & FileAttributes.Hidden) != 0,
                                 });
                             }
                             catch
                             {
                                 // 跳过无法访问的文件
                             }
                         }
                     }
                 }

                 LogService.Instance.Info($"File list retrieved: {files.Count} items for path: {path}", "FileSystem");
                 
                 // 发送文件列表响应
                 var response = new
                 {
                     messageId = messageId,
                     type = "file_list_response",
                     timestamp = DateTime.Now.ToString("yyyy-MM-ddTHH:mm:ss"),
                     payload = new
                     {
                         files = files,
                         path = path
                     }
                 };

                 var responseMessage = ControlMessage.FromJson(Newtonsoft.Json.JsonConvert.SerializeObject(response));
                 if (responseMessage != null)
                     await _socketServer?.BroadcastMessageAsync(responseMessage)!;
             }
             catch (Exception ex)
             {
                 LogService.Instance.Error($"Failed to list files for path: {path}", ex, "FileSystem");
                 
                 // 发送错误响应
                 var errorResponse = new
                 {
                     messageId = messageId,
                     type = "file_list_response",
                     timestamp = DateTime.Now.ToString("yyyy-MM-ddTHH:mm:ss"),
                     payload = new
                     {
                         files = new List<object>(),
                         error = ex.Message
                     }
                 };

                 var errorMessage = ControlMessage.FromJson(Newtonsoft.Json.JsonConvert.SerializeObject(errorResponse));
                 if (errorMessage != null)
                     await _socketServer?.BroadcastMessageAsync(errorMessage)!;
             }
         }

         // 创建目录操作
         private async Task HandleCreateDirectoryAsync(string messageId, string path, string name)
         {
             try
             {
                 if (string.IsNullOrEmpty(name))
                 {
                     throw new ArgumentException("目录名称不能为空");
                 }
                 
                 var fullPath = Path.Combine(path, name);
                 Directory.CreateDirectory(fullPath);
                 
                 var response = ControlMessage.CreateResponse(messageId, true, "目录创建成功");
                 await _socketServer?.BroadcastMessageAsync(response);
                 LogService.Instance.Info($"目录创建成功: {fullPath}", "FileSystem");
             }
             catch (Exception ex)
             {
                 var errorResponse = ControlMessage.CreateResponse(messageId, false, $"创建目录失败: {ex.Message}");
                 await _socketServer?.BroadcastMessageAsync(errorResponse);
                 throw;
             }
         }

         // 删除文件/目录操作
         private async Task HandleDeleteFileAsync(string messageId, string path)
         {
             try
             {
                 if (File.Exists(path))
                 {
                     File.Delete(path);
                 }
                 else if (Directory.Exists(path))
                 {
                     Directory.Delete(path, true);
                 }
                 else
                 {
                     throw new FileNotFoundException("文件或目录不存在");
                 }
                 
                 var response = ControlMessage.CreateResponse(messageId, true, "删除成功");
                 await _socketServer?.BroadcastMessageAsync(response);
                 LogService.Instance.Info($"删除成功: {path}", "FileSystem");
             }
             catch (Exception ex)
             {
                 var errorResponse = ControlMessage.CreateResponse(messageId, false, $"删除失败: {ex.Message}");
                 await _socketServer?.BroadcastMessageAsync(errorResponse);
                 throw;
             }
         }

         // 重命名文件/目录操作
         private async Task HandleRenameFileAsync(string messageId, string oldPath, string newName)
         {
             try
             {
                 if (string.IsNullOrEmpty(newName))
                 {
                     throw new ArgumentException("新名称不能为空");
                 }
                 
                 var directory = Path.GetDirectoryName(oldPath);
                 var newPath = Path.Combine(directory, newName);
                 
                 if (File.Exists(oldPath))
                 {
                     File.Move(oldPath, newPath);
                 }
                 else if (Directory.Exists(oldPath))
                 {
                     Directory.Move(oldPath, newPath);
                 }
                 else
                 {
                     throw new FileNotFoundException("文件或目录不存在");
                 }
                 
                 var response = ControlMessage.CreateResponse(messageId, true, "重命名成功");
                 await _socketServer?.BroadcastMessageAsync(response);
                 LogService.Instance.Info($"重命名成功: {oldPath} -> {newPath}", "FileSystem");
             }
             catch (Exception ex)
             {
                 var errorResponse = ControlMessage.CreateResponse(messageId, false, $"重命名失败: {ex.Message}");
                 await _socketServer?.BroadcastMessageAsync(errorResponse);
                 throw;
             }
         }

         // 上传文件操作
         private async Task HandleUploadFileAsync(string messageId, string path, string base64Data)
         {
             try
             {
                 if (string.IsNullOrEmpty(base64Data))
                 {
                     throw new ArgumentException("文件数据不能为空");
                 }
                 
                 var fileData = Convert.FromBase64String(base64Data);
                 await File.WriteAllBytesAsync(path, fileData);
                 
                 var response = ControlMessage.CreateResponse(messageId, true, "文件上传成功");
                 await _socketServer?.BroadcastMessageAsync(response);
                 LogService.Instance.Info($"文件上传成功: {path}, 大小: {fileData.Length} 字节", "FileSystem");
             }
             catch (Exception ex)
             {
                 var errorResponse = ControlMessage.CreateResponse(messageId, false, $"文件上传失败: {ex.Message}");
                 await _socketServer?.BroadcastMessageAsync(errorResponse);
                 throw;
             }
         }

         // 下载文件操作
         private async Task HandleDownloadFileAsync(string messageId, string path)
         {
             try
             {
                 if (!File.Exists(path))
                 {
                     throw new FileNotFoundException("文件不存在");
                 }
                 
                 var fileData = await File.ReadAllBytesAsync(path);
                 var base64Data = Convert.ToBase64String(fileData);
                 
                 var response = new ControlMessage(messageId, "file_download", DateTime.Now, new Dictionary<string, object>
                 {
                     ["success"] = true,
                     ["path"] = path,
                     ["data"] = base64Data,
                     ["size"] = fileData.Length
                 });
                 
                 await _socketServer?.BroadcastMessageAsync(response);
                 LogService.Instance.Info($"文件下载成功: {path}, 大小: {fileData.Length} 字节", "FileSystem");
             }
             catch (Exception ex)
             {
                 var errorResponse = ControlMessage.CreateResponse(messageId, false, $"文件下载失败: {ex.Message}");
                 await _socketServer?.BroadcastMessageAsync(errorResponse);
                 throw;
             }
         }

         // 图片预览操作
         private async Task HandleImagePreviewAsync(string messageId, string path)
         {
             try
             {
                 if (!File.Exists(path))
                 {
                     throw new FileNotFoundException("图片文件不存在");
                 }

                 // 检查是否为支持的图片格式
                 var extension = Path.GetExtension(path).ToLower();
                 var supportedExtensions = new[] { ".jpg", ".jpeg", ".png", ".gif", ".bmp", ".webp" };
                 
                 if (!supportedExtensions.Contains(extension))
                 {
                     throw new NotSupportedException($"不支持的图片格式: {extension}");
                 }

                 // 读取图片文件并转换为Base64
                 var imageData = await File.ReadAllBytesAsync(path);
                 var base64Data = Convert.ToBase64String(imageData);

                 LogService.Instance.Info($"图片预览处理成功: {path}, 大小: {imageData.Length} 字节", "FileSystem");

                 // 发送图片预览响应
                 var response = new
                 {
                     messageId = messageId,
                     type = "image_preview_response",
                     timestamp = DateTime.Now.ToString("yyyy-MM-ddTHH:mm:ss"),
                     payload = new
                     {
                         success = true,
                         path = path,
                         imageData = base64Data,
                         size = imageData.Length,
                         format = extension.TrimStart('.')
                     }
                 };

                 var responseMessage = ControlMessage.FromJson(Newtonsoft.Json.JsonConvert.SerializeObject(response));
                 if (responseMessage != null)
                     await _socketServer?.BroadcastMessageAsync(responseMessage)!;

                 LogService.Instance.Info($"图片预览响应发送成功: {path}", "FileSystem");
             }
             catch (Exception ex)
             {
                 LogService.Instance.Error($"图片预览失败: {path}", ex, "FileSystem");
                 
                 // 发送错误响应
                 var errorResponse = new
                 {
                     messageId = messageId,
                     type = "image_preview_response",
                     timestamp = DateTime.Now.ToString("yyyy-MM-ddTHH:mm:ss"),
                     payload = new
                     {
                         success = false,
                         error = ex.Message,
                         path = path
                     }
                 };

                 var errorMessage = ControlMessage.FromJson(Newtonsoft.Json.JsonConvert.SerializeObject(errorResponse));
                 if (errorMessage != null)
                     await _socketServer?.BroadcastMessageAsync(errorMessage)!;
             }
         }

        // 鼠标移动 - 使用相对移动
        private void MoveMouse(int deltaX, int deltaY)
        {
            // 使用mouse_event进行相对移动，更精确和流畅
            mouse_event(MOUSEEVENTF_MOVE, deltaX, deltaY, 0, 0);
        }

        // 鼠标点击
        private void ClickMouse(string button, int clicks)
        {
            for (int i = 0; i < clicks; i++)
            {
                switch (button.ToLower())
                {
                    case "left":
                        mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0);
                        mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0);
                        break;
                    case "right":
                        mouse_event(MOUSEEVENTF_RIGHTDOWN, 0, 0, 0, 0);
                        mouse_event(MOUSEEVENTF_RIGHTUP, 0, 0, 0, 0);
                        break;
                    case "middle":
                        mouse_event(MOUSEEVENTF_MIDDLEDOWN, 0, 0, 0, 0);
                        mouse_event(MOUSEEVENTF_MIDDLEUP, 0, 0, 0, 0);
                        break;
                }

                if (i < clicks - 1)
                    System.Threading.Thread.Sleep(50); // 双击间隔
            }
        }

        // 鼠标滚轮
        private void ScrollMouse(int delta)
        {
            mouse_event(MOUSEEVENTF_WHEEL, 0, 0, delta * 120, 0);
        }

        // 按键 - 简单按键
        private void PressKey(string keyCode)
        {
            if (Enum.TryParse<Keys>(keyCode, true, out Keys key))
            {
                SendKey(key);
            }
        }

        // 按键 - 带修饰键的组合键
        private void PressKeyWithModifiers(string keyCode, List<string> modifiers)
        {
            var modifierKeys = new List<Keys>();
            
            // 解析修饰键
            foreach (var modifier in modifiers)
            {
                switch (modifier.ToLower())
                {
                    case "ctrl":
                        modifierKeys.Add(Keys.ControlKey);
                        break;
                    case "shift":
                        modifierKeys.Add(Keys.ShiftKey);
                        break;
                    case "alt":
                        modifierKeys.Add(Keys.Menu);
                        break;
                    case "win":
                        modifierKeys.Add(Keys.LWin);
                        break;
                }
            }

            // 解析主要按键
            Keys mainKey;
            if (!Enum.TryParse<Keys>(keyCode, true, out mainKey))
            {
                // 如果解析失败，尝试将单字符转换为对应的按键
                if (keyCode.Length == 1)
                {
                    char c = keyCode.ToUpper()[0];
                    if (c >= 'A' && c <= 'Z')
                    {
                        mainKey = (Keys)Enum.Parse(typeof(Keys), c.ToString());
                    }
                    else
                    {
                        return; // 无法识别的按键
                    }
                }
                else
                {
                    return; // 无法识别的按键
                }
            }

            // 按下修饰键
            foreach (var modKey in modifierKeys)
            {
                keybd_event((byte)modKey, 0, 0, 0);
            }

            // 按下主要按键
            keybd_event((byte)mainKey, 0, 0, 0);
            keybd_event((byte)mainKey, 0, 2, 0);

            // 释放修饰键（逆序释放）
            for (int i = modifierKeys.Count - 1; i >= 0; i--)
            {
                keybd_event((byte)modifierKeys[i], 0, 2, 0);
            }
        }

        // 发送按键
        private void SendKey(Keys key)
        {
            keybd_event((byte)key, 0, 0, 0); // 按下
            keybd_event((byte)key, 0, 2, 0); // 释放
        }

        // 发送媒体按键
        private void SendMediaKey(Keys key)
        {
            keybd_event((byte)key, 0, 0, 0);
            keybd_event((byte)key, 0, 2, 0);
        }

        // 发送文本
        private void SendText(string text)
        {
            SendKeys.SendWait(text);
        }

        // 执行系统命令
        private void ExecuteSystemCommand(string command)
        {
            try
            {
                var processInfo = new ProcessStartInfo("cmd.exe", "/c " + command)
                {
                    CreateNoWindow = true,
                    UseShellExecute = false,
                    WindowStyle = ProcessWindowStyle.Hidden
                };
                Process.Start(processInfo);
            }
            catch (Exception ex)
            {
                LogService.Instance.Error($"Failed to execute system command: {command}", ex, "SystemControl");
            }
        }

        // 获取当前系统音量（0.0-1.0）
        public float GetSystemVolume()
        {
            try
            {
                // 使用简化的WinAPI方法获取音量
                return GetMasterVolume();
            }
            catch (Exception ex)
            {
                LogService.Instance.Error("Failed to get system volume", ex, "SystemControl");
                return 0.5f; // 默认返回50%音量
            }
        }

        // 获取静音状态
        public bool GetMuteState()
        {
            try
            {
                return GetMasterMute();
            }
            catch (Exception ex)
            {
                LogService.Instance.Error("Failed to get mute state", ex, "SystemControl");
                return false;
            }
        }

        // 设置系统音量（0.0-1.0）
        public void SetSystemVolume(float volume)
        {
            try
            {
                SetMasterVolume(Math.Max(0.0f, Math.Min(1.0f, volume)));
                
                // 触发音量改变事件
                VolumeChanged?.Invoke(volume, GetMuteState());
                
                LogService.Instance.Info($"System volume set to {volume:P0}", "SystemControl");
            }
            catch (Exception ex)
            {
                LogService.Instance.Error($"Failed to set system volume to {volume}", ex, "SystemControl");
            }
        }

        // 切换静音状态
        public void ToggleMute()
        {
            try
            {
                var currentMute = GetMuteState();
                SetMasterMute(!currentMute);
                
                // 触发音量改变事件
                VolumeChanged?.Invoke(GetSystemVolume(), !currentMute);
                
                LogService.Instance.Info($"System mute toggled to {!currentMute}", "SystemControl");
            }
            catch (Exception ex)
            {
                LogService.Instance.Error("Failed to toggle mute", ex, "SystemControl");
            }
        }

        // 使用Windows Core Audio API获取系统主音量
        private float GetMasterVolume()
        {
            try
            {
                // 使用Core Audio API获取真正的系统音量
                var deviceEnumerator = new MMDeviceEnumerator() as IMMDeviceEnumerator;
                if (deviceEnumerator == null)
                {
                    LogService.Instance.Warning("Failed to create MMDeviceEnumerator", "SystemControl");
                    return 0.5f;
                }

                IMMDevice? speakers = null;
                IAudioEndpointVolume? masterVol = null;
                
                try
                {
                    // 获取默认音频渲染设备
                    var hr = deviceEnumerator.GetDefaultAudioEndpoint(EDataFlow.eRender, ERole.eMultimedia, out speakers);
                    if (hr != 0 || speakers == null)
                    {
                        LogService.Instance.Warning($"Failed to get default audio endpoint, HRESULT: {hr}", "SystemControl");
                        return 0.5f;
                    }

                    // 激活IAudioEndpointVolume接口
                    var iid = typeof(IAudioEndpointVolume).GUID;
                    object volumeObject;
                    hr = speakers.Activate(ref iid, 0, IntPtr.Zero, out volumeObject);
                    if (hr != 0 || volumeObject == null)
                    {
                        LogService.Instance.Warning($"Failed to activate IAudioEndpointVolume, HRESULT: {hr}", "SystemControl");
                        return 0.5f;
                    }

                    masterVol = volumeObject as IAudioEndpointVolume;
                    if (masterVol == null)
                    {
                        LogService.Instance.Warning("Failed to cast to IAudioEndpointVolume", "SystemControl");
                        return 0.5f;
                    }

                    // 获取主音量级别
                    float volumeLevel;
                    hr = masterVol.GetMasterVolumeLevelScalar(out volumeLevel);
                    if (hr != 0)
                    {
                        LogService.Instance.Warning($"Failed to get master volume level, HRESULT: {hr}", "SystemControl");
                        return 0.5f;
                    }

                    float volumePercent = volumeLevel * 100;
                    LogService.Instance.Info($"Core Audio API - Master volume: {volumePercent:F1}%", "SystemControl");
                    return volumeLevel;
                }
                finally
                {
                    // 释放COM对象
                    if (masterVol != null) Marshal.ReleaseComObject(masterVol);
                    if (speakers != null) Marshal.ReleaseComObject(speakers);
                    if (deviceEnumerator != null) Marshal.ReleaseComObject(deviceEnumerator);
                }
            }
            catch (Exception ex)
            {
                LogService.Instance.Error($"Core Audio API exception: {ex.Message}", ex, "SystemControl");
                return 0.5f;
            }
        }


        // 使用Core Audio API获取静音状态
        private bool GetMasterMute()
        {
            try
            {
                var deviceEnumerator = new MMDeviceEnumerator() as IMMDeviceEnumerator;
                if (deviceEnumerator == null)
                {
                    LogService.Instance.Warning("Failed to create MMDeviceEnumerator for mute check", "SystemControl");
                    return false;
                }

                IMMDevice? speakers = null;
                IAudioEndpointVolume? masterVol = null;
                
                try
                {
                    var hr = deviceEnumerator.GetDefaultAudioEndpoint(EDataFlow.eRender, ERole.eMultimedia, out speakers);
                    if (hr != 0 || speakers == null)
                    {
                        LogService.Instance.Warning($"Failed to get default audio endpoint for mute, HRESULT: {hr}", "SystemControl");
                        return false;
                    }

                    var iid = typeof(IAudioEndpointVolume).GUID;
                    object volumeObject;
                    hr = speakers.Activate(ref iid, 0, IntPtr.Zero, out volumeObject);
                    if (hr != 0 || volumeObject == null)
                    {
                        LogService.Instance.Warning($"Failed to activate IAudioEndpointVolume for mute, HRESULT: {hr}", "SystemControl");
                        return false;
                    }

                    masterVol = volumeObject as IAudioEndpointVolume;
                    if (masterVol == null)
                    {
                        LogService.Instance.Warning("Failed to cast to IAudioEndpointVolume for mute", "SystemControl");
                        return false;
                    }

                    bool isMuted;
                    hr = masterVol.GetMute(out isMuted);
                    if (hr != 0)
                    {
                        LogService.Instance.Warning($"Failed to get mute state, HRESULT: {hr}", "SystemControl");
                        return false;
                    }

                    LogService.Instance.Info($"Core Audio API - Mute state: {isMuted}", "SystemControl");
                    return isMuted;
                }
                finally
                {
                    if (masterVol != null) Marshal.ReleaseComObject(masterVol);
                    if (speakers != null) Marshal.ReleaseComObject(speakers);
                    if (deviceEnumerator != null) Marshal.ReleaseComObject(deviceEnumerator);
                }
            }
            catch (Exception ex)
            {
                LogService.Instance.Error($"Exception in GetMasterMute: {ex.Message}", ex, "SystemControl");
                return false;
            }
        }

        // 使用Core Audio API设置音量 - 统一API确保一致性
        private void SetMasterVolume(float volume)
        {
            try
            {
                var deviceEnumerator = new MMDeviceEnumerator() as IMMDeviceEnumerator;
                if (deviceEnumerator == null)
                {
                    LogService.Instance.Warning("Failed to create MMDeviceEnumerator for volume setting", "SystemControl");
                    return;
                }

                IMMDevice? speakers = null;
                IAudioEndpointVolume? masterVol = null;
                
                try
                {
                    // 获取默认音频渲染设备
                    var hr = deviceEnumerator.GetDefaultAudioEndpoint(EDataFlow.eRender, ERole.eMultimedia, out speakers);
                    if (hr != 0 || speakers == null)
                    {
                        LogService.Instance.Warning($"Failed to get default audio endpoint for volume setting, HRESULT: {hr}", "SystemControl");
                        return;
                    }

                    // 激活IAudioEndpointVolume接口
                    var iid = typeof(IAudioEndpointVolume).GUID;
                    object volumeObject;
                    hr = speakers.Activate(ref iid, 0, IntPtr.Zero, out volumeObject);
                    if (hr != 0 || volumeObject == null)
                    {
                        LogService.Instance.Warning($"Failed to activate IAudioEndpointVolume for volume setting, HRESULT: {hr}", "SystemControl");
                        return;
                    }

                    masterVol = volumeObject as IAudioEndpointVolume;
                    if (masterVol == null)
                    {
                        LogService.Instance.Warning("Failed to cast to IAudioEndpointVolume for volume setting", "SystemControl");
                        return;
                    }

                    // 设置主音量级别
                    hr = masterVol.SetMasterVolumeLevelScalar(volume, Guid.Empty);
                    if (hr != 0)
                    {
                        LogService.Instance.Warning($"Failed to set master volume level, HRESULT: {hr}", "SystemControl");
                        return;
                    }

                    LogService.Instance.Info($"Core Audio API - Volume set to {volume:P0} successfully", "SystemControl");
                }
                finally
                {
                    // 释放COM对象
                    if (masterVol != null) Marshal.ReleaseComObject(masterVol);
                    if (speakers != null) Marshal.ReleaseComObject(speakers);
                    if (deviceEnumerator != null) Marshal.ReleaseComObject(deviceEnumerator);
                }
            }
            catch (Exception ex)
            {
                LogService.Instance.Error($"Exception in SetMasterVolume: {ex.Message}", ex, "SystemControl");
            }
        }

        // 🔧 修复：使用Core Audio API设置静音，确保与获取API一致
        private void SetMasterMute(bool mute)
        {
            try
            {
                var deviceEnumerator = new MMDeviceEnumerator() as IMMDeviceEnumerator;
                if (deviceEnumerator == null)
                {
                    LogService.Instance.Warning("Failed to create MMDeviceEnumerator for mute setting", "SystemControl");
                    return;
                }

                IMMDevice? speakers = null;
                IAudioEndpointVolume? masterVol = null;
                
                try
                {
                    // 获取默认音频渲染设备
                    var hr = deviceEnumerator.GetDefaultAudioEndpoint(EDataFlow.eRender, ERole.eMultimedia, out speakers);
                    if (hr != 0 || speakers == null)
                    {
                        LogService.Instance.Warning($"Failed to get default audio endpoint for mute setting, HRESULT: {hr}", "SystemControl");
                        return;
                    }

                    // 激活IAudioEndpointVolume接口
                    var iid = typeof(IAudioEndpointVolume).GUID;
                    object volumeObject;
                    hr = speakers.Activate(ref iid, 0, IntPtr.Zero, out volumeObject);
                    if (hr != 0 || volumeObject == null)
                    {
                        LogService.Instance.Warning($"Failed to activate IAudioEndpointVolume for mute setting, HRESULT: {hr}", "SystemControl");
                        return;
                    }

                    masterVol = volumeObject as IAudioEndpointVolume;
                    if (masterVol == null)
                    {
                        LogService.Instance.Warning("Failed to cast to IAudioEndpointVolume for mute setting", "SystemControl");
                        return;
                    }

                    // 设置静音状态
                    hr = masterVol.SetMute(mute, Guid.Empty);
                    if (hr != 0)
                    {
                        LogService.Instance.Warning($"Failed to set mute state, HRESULT: {hr}", "SystemControl");
                        return;
                    }

                    LogService.Instance.Info($"Core Audio API - Mute set to {mute} successfully", "SystemControl");
                }
                finally
                {
                    // 释放COM对象
                    if (masterVol != null) Marshal.ReleaseComObject(masterVol);
                    if (speakers != null) Marshal.ReleaseComObject(speakers);
                    if (deviceEnumerator != null) Marshal.ReleaseComObject(deviceEnumerator);
                }
            }
            catch (Exception ex)
            {
                LogService.Instance.Error($"Exception in SetMasterMute: {ex.Message}", ex, "SystemControl");
            }
        }

        // WinMM API for basic volume control
        [DllImport("winmm.dll")]
        private static extern int waveOutGetVolume(IntPtr hwo, out uint pdwVolume);

        [DllImport("winmm.dll")]
        private static extern int waveOutSetVolume(IntPtr hwo, uint dwVolume);

        // Windows Core Audio API interfaces and classes
        [ComImport]
        [Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
        internal class MMDeviceEnumerator
        {
        }

        internal enum EDataFlow
        {
            eRender,
            eCapture,
            eAll,
            EDataFlow_enum_count
        }

        internal enum ERole
        {
            eConsole,
            eMultimedia,
            eCommunications,
            ERole_enum_count
        }

        [Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
        internal interface IMMDeviceEnumerator
        {
            int NotImpl1();

            [PreserveSig]
            int GetDefaultAudioEndpoint(EDataFlow dataFlow, ERole role, out IMMDevice ppDevice);
        }

        [Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
        internal interface IMMDevice
        {
            [PreserveSig]
            int Activate(ref Guid iid, int dwClsCtx, IntPtr pActivationParams, [MarshalAs(UnmanagedType.IUnknown)] out object ppInterface);
        }

        [Guid("5CDF2C82-841E-4546-9722-0CF74078229A"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
        public interface IAudioEndpointVolume
        {
            [PreserveSig]
            int RegisterControlChangeNotify(IAudioEndpointVolumeCallback pNotify);

            [PreserveSig]
            int UnregisterControlChangeNotify(IAudioEndpointVolumeCallback pNotify);

            [PreserveSig]
            int GetChannelCount([Out][MarshalAs(UnmanagedType.U4)] out UInt32 channelCount);

            [PreserveSig]
            int SetMasterVolumeLevel([In][MarshalAs(UnmanagedType.R4)] float level, [In][MarshalAs(UnmanagedType.LPStruct)] Guid eventContext);

            [PreserveSig]
            int SetMasterVolumeLevelScalar([In][MarshalAs(UnmanagedType.R4)] float level, [In][MarshalAs(UnmanagedType.LPStruct)] Guid eventContext);

            [PreserveSig]
            int GetMasterVolumeLevel([Out][MarshalAs(UnmanagedType.R4)] out float level);

            [PreserveSig]
            int GetMasterVolumeLevelScalar([Out][MarshalAs(UnmanagedType.R4)] out float level);

            [PreserveSig]
            int SetChannelVolumeLevel([In][MarshalAs(UnmanagedType.U4)] UInt32 channelNumber, [In][MarshalAs(UnmanagedType.R4)] float level, [In][MarshalAs(UnmanagedType.LPStruct)] Guid eventContext);

            [PreserveSig]
            int SetChannelVolumeLevelScalar([In][MarshalAs(UnmanagedType.U4)] UInt32 channelNumber, [In][MarshalAs(UnmanagedType.R4)] float level, [In][MarshalAs(UnmanagedType.LPStruct)] Guid eventContext);

            [PreserveSig]
            int GetChannelVolumeLevel([In][MarshalAs(UnmanagedType.U4)] UInt32 channelNumber, [Out][MarshalAs(UnmanagedType.R4)] out float level);

            [PreserveSig]
            int GetChannelVolumeLevelScalar([In][MarshalAs(UnmanagedType.U4)] UInt32 channelNumber, [Out][MarshalAs(UnmanagedType.R4)] out float level);

            [PreserveSig]
            int SetMute([In][MarshalAs(UnmanagedType.Bool)] Boolean isMuted, [In][MarshalAs(UnmanagedType.LPStruct)] Guid eventContext);

            [PreserveSig]
            int GetMute([Out][MarshalAs(UnmanagedType.Bool)] out Boolean isMuted);
        }

        // 音量变化回调接口
        [Guid("657804FA-D6AD-4496-8A60-352752AF4F89"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
        public interface IAudioEndpointVolumeCallback
        {
            [PreserveSig]
            int OnNotify(IntPtr pNotify);
        }

        // 通知音量状态改变
        public void NotifyVolumeChange()
        {
            try
            {
                // 短暂延迟确保系统音量已更新
                System.Threading.Thread.Sleep(100);
                
                var volume = GetSystemVolume();
                var isMuted = GetMuteState();
                
                VolumeChanged?.Invoke(volume, isMuted);
                
                LogService.Instance.Info($"Volume status: {volume:P0}, Muted: {isMuted}", "SystemControl");
            }
            catch (Exception ex)
            {
                LogService.Instance.Error("Failed to notify volume change", ex, "SystemControl");
            }
        }

        // 初始化音量变化监听
        public void InitializeVolumeMonitoring()
        {
            try
            {
                var hr = CoInitialize(IntPtr.Zero);
                if (hr != 0)
                {
                    LogService.Instance.Warning("CoInitialize failed for volume monitoring", "SystemControl");
                    return;
                }

                var enumerator = new MMDeviceEnumerator() as IMMDeviceEnumerator;
                if (enumerator == null)
                {
                    LogService.Instance.Error("Failed to create MMDeviceEnumerator", new Exception("MMDeviceEnumerator is null"), "SystemControl");
                    return;
                }

                hr = enumerator.GetDefaultAudioEndpoint(EDataFlow.eRender, ERole.eMultimedia, out IMMDevice device);
                if (hr != 0 || device == null)
                {
                    LogService.Instance.Error("Failed to get default audio endpoint", new Exception($"HRESULT: {hr}"), "SystemControl");
                    return;
                }

                var iid = IID_IAudioEndpointVolume;
                hr = device.Activate(ref iid, 0, IntPtr.Zero, out object volumeObject);
                if (hr != 0 || volumeObject == null)
                {
                    LogService.Instance.Error("Failed to activate IAudioEndpointVolume", new Exception($"HRESULT: {hr}"), "SystemControl");
                    return;
                }

                _volumeEndpoint = volumeObject as IAudioEndpointVolume;
                if (_volumeEndpoint == null)
                {
                    LogService.Instance.Error("Failed to cast to IAudioEndpointVolume", new Exception("Cast failed"), "SystemControl");
                    return;
                }

                // 创建并注册回调
                _volumeCallback = new VolumeNotificationCallback(this);
                hr = _volumeEndpoint.RegisterControlChangeNotify(_volumeCallback);
                if (hr != 0)
                {
                    LogService.Instance.Error($"Failed to register volume change notification: {hr}", new Exception($"HRESULT: {hr}"), "SystemControl");
                    return;
                }

                LogService.Instance.Info("Volume monitoring initialized successfully", "SystemControl");
            }
            catch (Exception ex)
            {
                LogService.Instance.Error("Failed to initialize volume monitoring", ex, "SystemControl");
            }
        }

        // 清理音量监听
        public void DisposeVolumeMonitoring()
        {
            try
            {
                if (_volumeEndpoint != null && _volumeCallback != null)
                {
                    _volumeEndpoint.UnregisterControlChangeNotify(_volumeCallback);
                    LogService.Instance.Info("Volume monitoring disposed", "SystemControl");
                }
            }
            catch (Exception ex)
            {
                LogService.Instance.Error("Failed to dispose volume monitoring", ex, "SystemControl");
            }
            finally
            {
                _volumeEndpoint = null;
                _volumeCallback = null;
                CoUninitialize();
            }
        }

        // 发送硬件信息到所有客户端
        private async Task SendHardwareInfoToClients(dynamic hardwareInfo)
        {
            var message = new ControlMessage(
                messageId: DateTime.Now.Ticks.ToString(),
                type: "hardware_info",
                timestamp: DateTime.Now,
                payload: new Dictionary<string, object> { ["data"] = hardwareInfo }
            );
            await _socketServer?.BroadcastMessageAsync(message)!;
        }

        // 发送性能数据到所有客户端
        private async Task SendPerformanceDataToClients(dynamic performanceData)
        {
            var message = new ControlMessage(
                messageId: DateTime.Now.Ticks.ToString(),
                type: "performance_data",
                timestamp: DateTime.Now,
                payload: new Dictionary<string, object> { ["data"] = performanceData }
            );
            await _socketServer?.BroadcastMessageAsync(message)!;
        }

        // 处理定时任务
        private void HandleDelayedAction(ControlMessage message, string actionType)
        {
            try
            {
                var delay = 300; // 默认5分钟
                if (message.Payload.ContainsKey("delay") && int.TryParse(message.Payload["delay"]?.ToString(), out int parsedDelay))
                {
                    delay = parsedDelay;
                }

                // 使用Windows任务计划程序或内置延迟命令
                string command = actionType switch
                {
                    "shutdown" => $"shutdown /s /t {delay}",
                    "restart" => $"shutdown /r /t {delay}",
                    "lock" => $"schtasks /create /sc once /tn \"PalmController_Lock_{DateTime.Now.Ticks}\" /tr \"rundll32.exe user32.dll,LockWorkStation\" /st {DateTime.Now.AddSeconds(delay):HH:mm:ss} /f",
                    _ => throw new ArgumentException($"Unknown delayed action: {actionType}")
                };

                ExecuteSystemCommand(command);
                LogService.Instance.Info($"Scheduled {actionType} task set for {delay} seconds", "SystemControl");
            }
            catch (Exception ex)
            {
                LogService.Instance.Error($"Failed to schedule {actionType} task", ex, "SystemControl");
            }
        }

        // 处理运行命令
        private void HandleRunCommand(ControlMessage message)
        {
            try
            {
                var command = message.Payload.GetValueOrDefault("command")?.ToString();
                if (string.IsNullOrEmpty(command))
                {
                    LogService.Instance.Warning("Run command request without command parameter", "SystemControl");
                    return;
                }

                // 安全过滤：只允许预定义的安全命令
                var safeCommands = new Dictionary<string, string>
                {
                    {"cleanmgr /sagerun:1", "磁盘清理"},
                    {"sfc /scannow", "系统文件检查"},
                    {"netsh winsock reset", "网络重置"},
                    {"ipconfig /flushdns", "DNS缓存清理"},
                    {"msinfo32", "系统信息"},
                    {"taskmgr", "任务管理器"}
                };

                if (safeCommands.ContainsKey(command))
                {
                    ExecuteSystemCommand(command);
                    LogService.Instance.Info($"Executed safe command: {command} ({safeCommands[command]})", "SystemControl");
                }
                else
                {
                    LogService.Instance.Warning($"Blocked unsafe command: {command}", "SystemControl");
                }
            }
            catch (Exception ex)
            {
                LogService.Instance.Error("Failed to execute command", ex, "SystemControl");
            }
        }

        // 音量变化回调实现类（内部类）
        public class VolumeNotificationCallback : IAudioEndpointVolumeCallback
        {
            private readonly SystemControlService _systemControl;

            public VolumeNotificationCallback(SystemControlService systemControl)
            {
                _systemControl = systemControl;
            }

            public int OnNotify(IntPtr pNotify)
            {
                try
                {
                    // 在音量变化时通知客户端
                    Task.Run(() =>
                    {
                        try
                        {
                            // 延迟一点点让系统完成音量更新
                            Thread.Sleep(50);
                            _systemControl.NotifyVolumeChange();
                        }
                        catch (Exception ex)
                        {
                            LogService.Instance.Error("Failed to notify volume change in callback", ex, "SystemControl");
                        }
                    });
                }
                catch (Exception ex)
                {
                    LogService.Instance.Error("Failed to handle volume notification", ex, "SystemControl");
                }
                
                return 0;
            }
        }
    }
} 