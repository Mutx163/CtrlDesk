using System;
using System.Collections.Generic;
using System.Linq;
using System.Management;
using System.Threading.Tasks;
using System.Diagnostics;
using System.Windows.Forms;

namespace PalmControllerServer.Services
{
    /// <summary>
    /// 硬件监控服务 - 使用System.Management和PerformanceCounter实现
    /// 提供硬件信息获取、性能监控、温度监控等功能
    /// </summary>
    public class HardwareMonitorService : IDisposable
    {
        private static readonly Lazy<HardwareMonitorService> _instance = new(() => new HardwareMonitorService());
        public static HardwareMonitorService Instance => _instance.Value;

        private readonly System.Threading.Timer _updateTimer;
        private bool _disposed = false;

        // 性能计数器
        private PerformanceCounter? _cpuCounter;
        private PerformanceCounter? _ramCounter;

        // 缓存的硬件信息
        private HardwareInfo? _cachedHardwareInfo;
        private PerformanceData? _cachedPerformanceData;
        private DateTime _lastHardwareInfoUpdate = DateTime.MinValue;
        private DateTime _lastPerformanceUpdate = DateTime.MinValue;

        private HardwareMonitorService()
        {
            try
            {
                // 初始化性能计数器
                InitializePerformanceCounters();

                // 启动定时更新（每3秒更新一次性能数据）
                _updateTimer = new System.Threading.Timer(UpdatePerformanceData, null, 1000, 3000);

                LogService.Instance.Info("HardwareMonitorService initialized successfully", "HardwareMonitor");
            }
            catch (Exception ex)
            {
                LogService.Instance.Error("Failed to initialize HardwareMonitorService", ex, "HardwareMonitor");
                throw;
            }
        }

        private void InitializePerformanceCounters()
        {
            try
            {
                _cpuCounter = new PerformanceCounter("Processor", "% Processor Time", "_Total");
                _ramCounter = new PerformanceCounter("Memory", "Available MBytes");
                
                // 初始化性能计数器 - 第一次调用通常返回0，需要预热
                if (_cpuCounter != null)
                {
                    _cpuCounter.NextValue(); // 预热CPU计数器
                }
                
                LogService.Instance.Info("Performance counters initialized successfully", "HardwareMonitor");
            }
            catch (Exception ex)
            {
                LogService.Instance.Error($"Failed to initialize performance counters: {ex.Message}", ex, "HardwareMonitor");
                // 确保即使失败也不会导致崩溃
                _cpuCounter = null;
                _ramCounter = null;
            }
        }

        /// <summary>
        /// 获取系统硬件信息
        /// </summary>
        /// <returns>硬件信息</returns>
        public async Task<HardwareInfo> GetHardwareInfoAsync()
        {
            // 硬件信息不常变，缓存30分钟
            if (_cachedHardwareInfo != null && DateTime.Now - _lastHardwareInfoUpdate < TimeSpan.FromMinutes(30))
            {
                return _cachedHardwareInfo;
            }

            return await Task.Run(() =>
            {
                try
                {
                    var hardwareInfo = new HardwareInfo
                    {
                        OsVersion = GetOperatingSystemInfo(),
                        CpuName = GetCpuInfo(),
                        CpuCores = GetCpuCoresInfo(),
                        RamTotal = GetMemoryInfo(),
                        GpuName = GetGpuInfo(),
                        Motherboard = GetMotherboardInfo()
                    };

                    _cachedHardwareInfo = hardwareInfo;
                    _lastHardwareInfoUpdate = DateTime.Now;

                    LogService.Instance.Info("Hardware info updated", "HardwareMonitor");
                    return hardwareInfo;
                }
                catch (Exception ex)
                {
                    LogService.Instance.Error("Failed to get hardware info", ex, "HardwareMonitor");
                    throw;
                }
            });
        }

        /// <summary>
        /// 获取实时性能数据
        /// </summary>
        /// <returns>性能数据</returns>
        public PerformanceData GetPerformanceData()
        {
            if (_cachedPerformanceData != null && DateTime.Now - _lastPerformanceUpdate < TimeSpan.FromSeconds(5))
            {
                return _cachedPerformanceData;
            }

            return GetCurrentPerformanceData();
        }

        /// <summary>
        /// 强制刷新性能数据
        /// </summary>
        /// <returns>最新性能数据</returns>
        public PerformanceData RefreshPerformanceData()
        {
            return GetCurrentPerformanceData();
        }

        private void UpdatePerformanceData(object? state)
        {
            try
            {
                _cachedPerformanceData = GetCurrentPerformanceData();
                _lastPerformanceUpdate = DateTime.Now;
            }
            catch (Exception ex)
            {
                LogService.Instance.Error("Failed to update performance data", ex, "HardwareMonitor");
            }
        }

        private PerformanceData GetCurrentPerformanceData()
        {
            try
            {
                var performanceData = new PerformanceData
                {
                    CpuUsage = GetCpuUsage(),
                    RamUsage = GetRamUsage(),
                    GpuUsage = GetGpuUsage(),
                    DiskUsage = GetDiskUsage(),
                    CpuTemp = GetCpuTemperature(),
                    GpuTemp = GetGpuTemperature(),
                    MotherboardTemp = GetMotherboardTemperature(),
                    FanSpeed = GetFanSpeed(),
                    NetworkUpload = GetNetworkUpload(),
                    NetworkDownload = GetNetworkDownload(),
                    MemoryUsedMB = GetMemoryUsedMB(),
                    MemoryTotalMB = GetMemoryTotalMB(),
                    MemoryAvailableMB = GetMemoryAvailableMB(),
                    ProcessCount = GetProcessCount(),
                    ThreadCount = GetThreadCount(),
                    SystemUptime = GetSystemUptime(),
                    CpuFrequency = GetCpuFrequency(),
                    DiskReadSpeed = GetDiskReadSpeed(),
                    DiskWriteSpeed = GetDiskWriteSpeed(),
                    NetworkLatency = GetNetworkLatency(),
                    BatteryLevel = GetBatteryLevel(),
                    PowerStatus = GetPowerStatus(),
                    GpuMemoryUsage = GetGpuMemoryUsage(),
                    ActiveWindow = GetActiveWindow(),
                    HandleCount = GetHandleCount(),
                    PageFileUsage = GetPageFileUsage()
                };

                return performanceData;
            }
            catch (Exception ex)
            {
                LogService.Instance.Error("Failed to get current performance data", ex, "HardwareMonitor");
                
                // 返回默认值，避免应用崩溃
                return new PerformanceData
                {
                    CpuUsage = 0,
                    RamUsage = 0,
                    GpuUsage = 0,
                    DiskUsage = 0,
                    CpuTemp = 0,
                    GpuTemp = 0,
                    MotherboardTemp = 0,
                    FanSpeed = 0,
                    NetworkUpload = 0,
                    NetworkDownload = 0,
                    MemoryUsedMB = 0,
                    MemoryTotalMB = 0,
                    MemoryAvailableMB = 0,
                    ProcessCount = 0,
                    ThreadCount = 0,
                    SystemUptime = 0,
                    CpuFrequency = "",
                    DiskReadSpeed = 0,
                    DiskWriteSpeed = 0,
                    NetworkLatency = 0,
                    BatteryLevel = -1,
                    PowerStatus = "",
                    GpuMemoryUsage = 0,
                    ActiveWindow = "",
                    HandleCount = 0,
                    PageFileUsage = 0
                };
            }
        }

        #region 硬件信息获取方法

        private string GetOperatingSystemInfo()
        {
            try
            {
                using var searcher = new ManagementObjectSearcher("SELECT * FROM Win32_OperatingSystem");
                foreach (ManagementObject os in searcher.Get())
                {
                    var caption = os["Caption"]?.ToString() ?? "Unknown";
                    var version = os["Version"]?.ToString() ?? "";
                    var architecture = os["OSArchitecture"]?.ToString() ?? "";
                    return $"{caption} {architecture}".Trim();
                }
                return "Windows (Unknown Version)";
            }
            catch
            {
                return "Windows (Unable to detect)";
            }
        }

        private string GetCpuInfo()
        {
            try
            {
                using var searcher = new ManagementObjectSearcher("SELECT * FROM Win32_Processor");
                foreach (ManagementObject processor in searcher.Get())
                {
                    var name = processor["Name"]?.ToString() ?? "Unknown CPU";
                    var maxClockSpeed = processor["MaxClockSpeed"]?.ToString() ?? "";
                    
                    if (!string.IsNullOrEmpty(maxClockSpeed))
                    {
                        var clockSpeedGHz = double.Parse(maxClockSpeed) / 1000.0;
                        return $"{name} @ {clockSpeedGHz:F1} GHz";
                    }
                    return name;
                }
                return "Unknown CPU";
            }
            catch
            {
                return "CPU (Unable to detect)";
            }
        }

        private string GetCpuCoresInfo()
        {
            try
            {
                using var searcher = new ManagementObjectSearcher("SELECT * FROM Win32_Processor");
                foreach (ManagementObject processor in searcher.Get())
                {
                    var cores = processor["NumberOfCores"]?.ToString() ?? "0";
                    var logicalProcessors = processor["NumberOfLogicalProcessors"]?.ToString() ?? "0";
                    return $"{cores} cores, {logicalProcessors} logical processors";
                }
                return "Unknown";
            }
            catch
            {
                return "Unable to detect cores";
            }
        }

        private string GetMemoryInfo()
        {
            try
            {
                long totalMemory = 0;
                using var searcher = new ManagementObjectSearcher("SELECT * FROM Win32_PhysicalMemory");
                foreach (ManagementObject memory in searcher.Get())
                {
                    var capacity = memory["Capacity"]?.ToString();
                    if (long.TryParse(capacity, out long capacityBytes))
                    {
                        totalMemory += capacityBytes;
                    }
                }
                
                var totalGB = totalMemory / (1024.0 * 1024.0 * 1024.0);
                return $"{totalGB:F1} GB";
            }
            catch
            {
                return "Unable to detect memory";
            }
        }

        private string GetGpuInfo()
        {
            try
            {
                using var searcher = new ManagementObjectSearcher("SELECT * FROM Win32_VideoController");
                var gpuList = new List<string>();
                
                foreach (ManagementObject gpu in searcher.Get())
                {
                    var name = gpu["Name"]?.ToString();
                    if (!string.IsNullOrEmpty(name) && !name.Contains("Basic") && !name.Contains("Generic"))
                    {
                        gpuList.Add(name);
                    }
                }
                
                return gpuList.Count > 0 ? string.Join(", ", gpuList) : "Unknown GPU";
            }
            catch
            {
                return "GPU (Unable to detect)";
            }
        }

        private string GetMotherboardInfo()
        {
            try
            {
                using var searcher = new ManagementObjectSearcher("SELECT * FROM Win32_BaseBoard");
                foreach (ManagementObject board in searcher.Get())
                {
                    var manufacturer = board["Manufacturer"]?.ToString() ?? "";
                    var product = board["Product"]?.ToString() ?? "";
                    return $"{manufacturer} {product}".Trim();
                }
                return "Unknown Motherboard";
            }
            catch
            {
                return "Motherboard (Unable to detect)";
            }
        }

        #endregion

        #region 性能数据获取方法

        private double GetCpuUsage()
        {
            try
            {
                if (_cpuCounter != null)
                {
                    // 获取CPU使用率，已经在初始化时预热过了
                    var usage = _cpuCounter.NextValue();
                    
                    // 如果还是返回0，再试一次（某些系统需要更多时间）
                    if (usage == 0)
                    {
                        System.Threading.Thread.Sleep(200);
                        usage = _cpuCounter.NextValue();
                    }
                    
                    // 确保值在合理范围内
                    if (usage < 0) usage = 0;
                    if (usage > 100) usage = 100;
                    
                    return Math.Round(usage, 1);
                }
                
                LogService.Instance.Warning("CPU counter is null, returning 0", "HardwareMonitor");
                return 0;
            }
            catch (Exception ex)
            {
                LogService.Instance.Warning($"Failed to get CPU usage: {ex.Message}", "HardwareMonitor");
                return 0;
            }
        }

        private double GetRamUsage()
        {
            try
            {
                // 获取总内存
                long totalMemoryMB = GetMemoryTotalMB();
                
                // 获取可用内存
                if (_ramCounter != null && totalMemoryMB > 0)
                {
                    var availableMB = _ramCounter.NextValue();
                    var usedMB = totalMemoryMB - (long)availableMB;
                    
                    // 确保值在合理范围内
                    if (usedMB < 0) usedMB = 0;
                    if (usedMB > totalMemoryMB) usedMB = totalMemoryMB;
                    
                    var usagePercentage = (double)usedMB / totalMemoryMB * 100;
                    return Math.Round(usagePercentage, 1);
                }
                
                LogService.Instance.Warning($"RAM counter is null or total memory is 0. Counter: {_ramCounter != null}, Total: {totalMemoryMB}", "HardwareMonitor");
                return 0;
            }
            catch (Exception ex)
            {
                LogService.Instance.Warning($"Failed to get RAM usage: {ex.Message}", "HardwareMonitor");
                return 0;
            }
        }

        private double GetGpuUsage()
        {
            // GPU使用率需要更复杂的方法，暂时返回0
            // 可以通过WMI或其他方式获取，但需要GPU驱动支持
            return 0;
        }

        private double GetDiskUsage()
        {
            try
            {
                using var diskCounter = new PerformanceCounter("PhysicalDisk", "% Disk Time", "_Total");
                
                // 预热计数器
                diskCounter.NextValue();
                System.Threading.Thread.Sleep(200);
                
                var usage = diskCounter.NextValue();
                
                // 确保值在合理范围内
                if (usage < 0) usage = 0;
                if (usage > 100) usage = 100;
                
                return Math.Round(usage, 1);
            }
            catch (Exception ex)
            {
                LogService.Instance.Warning($"Failed to get disk usage: {ex.Message}", "HardwareMonitor");
                return 0;
            }
        }

        private double GetCpuTemperature()
        {
            // CPU温度需要特殊的驱动或硬件支持，暂时返回0
            // 可以通过WMI的MSAcpi_ThermalZoneTemperature尝试，但不是所有系统都支持
            return 0;
        }

        private double GetGpuTemperature()
        {
            // GPU温度需要特殊API，暂时返回0
            return 0;
        }

        private double GetMotherboardTemperature()
        {
            // 主板温度需要特殊传感器支持，暂时返回0
            return 0;
        }

        private int GetFanSpeed()
        {
            // 风扇转速需要特殊传感器支持，暂时返回0
            return 0;
        }

        private double GetNetworkUpload()
        {
            try
            {
                // 获取所有网络接口的上传速度总和
                var networkInterfaces = System.Net.NetworkInformation.NetworkInterface.GetAllNetworkInterfaces();
                long totalBytesSent = 0;
                
                foreach (var networkInterface in networkInterfaces)
                {
                    if (networkInterface.OperationalStatus == System.Net.NetworkInformation.OperationalStatus.Up &&
                        networkInterface.NetworkInterfaceType != System.Net.NetworkInformation.NetworkInterfaceType.Loopback)
                    {
                        var statistics = networkInterface.GetIPv4Statistics();
                        totalBytesSent += statistics.BytesSent;
                    }
                }
                
                // 简化版本：返回累计发送字节数（实际应用中需要计算速率）
                return Math.Round(totalBytesSent / (1024.0 * 1024.0), 2); // 转换为MB
            }
            catch (Exception ex)
            {
                LogService.Instance.Warning($"Failed to get network upload: {ex.Message}", "HardwareMonitor");
                return 0;
            }
        }

        private double GetNetworkDownload()
        {
            try
            {
                // 获取所有网络接口的下载速度总和
                var networkInterfaces = System.Net.NetworkInformation.NetworkInterface.GetAllNetworkInterfaces();
                long totalBytesReceived = 0;
                
                foreach (var networkInterface in networkInterfaces)
                {
                    if (networkInterface.OperationalStatus == System.Net.NetworkInformation.OperationalStatus.Up &&
                        networkInterface.NetworkInterfaceType != System.Net.NetworkInformation.NetworkInterfaceType.Loopback)
                    {
                        var statistics = networkInterface.GetIPv4Statistics();
                        totalBytesReceived += statistics.BytesReceived;
                    }
                }
                
                // 简化版本：返回累计接收字节数（实际应用中需要计算速率）
                return Math.Round(totalBytesReceived / (1024.0 * 1024.0), 2); // 转换为MB
            }
            catch (Exception ex)
            {
                LogService.Instance.Warning($"Failed to get network download: {ex.Message}", "HardwareMonitor");
                return 0;
            }
        }

        private long GetMemoryUsedMB()
        {
            try
            {
                long totalMemory = GetMemoryTotalMB();
                long availableMemory = GetMemoryAvailableMB();
                return totalMemory - availableMemory;
            }
            catch
            {
                return 0;
            }
        }

        private long GetMemoryTotalMB()
        {
            try
            {
                using var searcher = new ManagementObjectSearcher("SELECT * FROM Win32_ComputerSystem");
                foreach (ManagementObject system in searcher.Get())
                {
                    var totalPhysicalMemory = Convert.ToInt64(system["TotalPhysicalMemory"]);
                    return totalPhysicalMemory / (1024 * 1024); // Convert to MB
                }
                return 0;
            }
            catch
            {
                return 0;
            }
        }

        private long GetMemoryAvailableMB()
        {
            try
            {
                if (_ramCounter != null)
                {
                    return (long)_ramCounter.NextValue();
                }
                return 0;
            }
            catch
            {
                return 0;
            }
        }

        private int GetProcessCount()
        {
            try
            {
                return Process.GetProcesses().Length;
            }
            catch
            {
                return 0;
            }
        }

        private int GetThreadCount()
        {
            try
            {
                return Process.GetProcesses().Sum(p => 
                {
                    try
                    {
                        return p.Threads.Count;
                    }
                    catch
                    {
                        return 0;
                    }
                });
            }
            catch
            {
                return 0;
            }
        }

        private double GetSystemUptime()
        {
            try
            {
                var uptime = TimeSpan.FromMilliseconds(Environment.TickCount64);
                return Math.Round(uptime.TotalHours, 2);
            }
            catch
            {
                return 0;
            }
        }

        private string GetCpuFrequency()
        {
            try
            {
                using var searcher = new ManagementObjectSearcher("SELECT * FROM Win32_Processor");
                foreach (ManagementObject processor in searcher.Get())
                {
                    var maxClockSpeed = processor["MaxClockSpeed"];
                    var currentClockSpeed = processor["CurrentClockSpeed"];
                    
                    if (maxClockSpeed != null && currentClockSpeed != null)
                    {
                        var maxSpeed = Convert.ToInt32(maxClockSpeed) / 1000.0; // Convert to GHz
                        var currentSpeed = Convert.ToInt32(currentClockSpeed) / 1000.0;
                        return $"{currentSpeed:F2} GHz / {maxSpeed:F2} GHz";
                    }
                }
                return "Unknown";
            }
            catch
            {
                return "Unknown";
            }
        }

        private double GetDiskReadSpeed()
        {
            try
            {
                // 这里可以实现磁盘读取速度监控，暂时返回0
                // 需要使用PerformanceCounter或其他方法来获取实时磁盘读取速度
                return 0;
            }
            catch
            {
                return 0;
            }
        }

        private double GetDiskWriteSpeed()
        {
            try
            {
                // 这里可以实现磁盘写入速度监控，暂时返回0
                // 需要使用PerformanceCounter或其他方法来获取实时磁盘写入速度
                return 0;
            }
            catch
            {
                return 0;
            }
        }

        private double GetNetworkLatency()
        {
            try
            {
                // 可以ping本地网关或公网地址来测试延迟，暂时返回0
                return 0;
            }
            catch
            {
                return 0;
            }
        }

        private int GetBatteryLevel()
        {
            try
            {
                using var searcher = new ManagementObjectSearcher("SELECT * FROM Win32_Battery");
                foreach (ManagementObject battery in searcher.Get())
                {
                    var estimatedChargeRemaining = battery["EstimatedChargeRemaining"];
                    if (estimatedChargeRemaining != null)
                    {
                        return Convert.ToInt32(estimatedChargeRemaining);
                    }
                }
                return -1; // 无电池
            }
            catch
            {
                return -1;
            }
        }

        private string GetPowerStatus()
        {
            try
            {
                var powerStatus = SystemInformation.PowerStatus;
                var batteryStatus = powerStatus.BatteryChargeStatus.ToString();
                var powerLineStatus = powerStatus.PowerLineStatus.ToString();
                
                return $"{powerLineStatus} - {batteryStatus}";
            }
            catch
            {
                return "Unknown";
            }
        }

        private double GetGpuMemoryUsage()
        {
            try
            {
                // GPU内存使用率需要专门的库或WMI查询，暂时返回0
                return 0;
            }
            catch
            {
                return 0;
            }
        }

        private string GetActiveWindow()
        {
            try
            {
                // 获取当前活动窗口标题，需要Windows API调用
                const int nChars = 256;
                var buff = new System.Text.StringBuilder(nChars);
                var handle = GetForegroundWindow();
                
                if (GetWindowText(handle, buff, nChars) > 0)
                {
                    return buff.ToString();
                }
                return "Unknown";
            }
            catch
            {
                return "Unknown";
            }
        }

        private int GetHandleCount()
        {
            try
            {
                return Process.GetProcesses().Sum(p =>
                {
                    try
                    {
                        return p.HandleCount;
                    }
                    catch
                    {
                        return 0;
                    }
                });
            }
            catch
            {
                return 0;
            }
        }

        private double GetPageFileUsage()
        {
            try
            {
                using var searcher = new ManagementObjectSearcher("SELECT * FROM Win32_PageFileUsage");
                foreach (ManagementObject pageFile in searcher.Get())
                {
                    var allocatedBaseSize = Convert.ToDouble(pageFile["AllocatedBaseSize"]);
                    var currentUsage = Convert.ToDouble(pageFile["CurrentUsage"]);
                    
                    if (allocatedBaseSize > 0)
                    {
                        return Math.Round((currentUsage / allocatedBaseSize) * 100, 2);
                    }
                }
                return 0;
            }
            catch
            {
                return 0;
            }
        }

        // Windows API声明
        [System.Runtime.InteropServices.DllImport("user32.dll")]
        private static extern IntPtr GetForegroundWindow();

        [System.Runtime.InteropServices.DllImport("user32.dll")]
        private static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder text, int count);

        #endregion

        public void Dispose()
        {
            if (!_disposed)
            {
                _updateTimer?.Dispose();
                _cpuCounter?.Dispose();
                _ramCounter?.Dispose();
                _disposed = true;
            }
        }
    }

    /// <summary>
    /// 硬件信息数据模型
    /// </summary>
    public class HardwareInfo
    {
        public string OsVersion { get; set; } = "";
        public string CpuName { get; set; } = "";
        public string CpuCores { get; set; } = "";
        public string RamTotal { get; set; } = "";
        public string GpuName { get; set; } = "";
        public string Motherboard { get; set; } = "";
    }

    /// <summary>
    /// 性能监控数据模型
    /// </summary>
    public class PerformanceData
    {
        public double CpuUsage { get; set; }
        public double RamUsage { get; set; }
        public double GpuUsage { get; set; }
        public double DiskUsage { get; set; }
        public double CpuTemp { get; set; }
        public double GpuTemp { get; set; }
        public double MotherboardTemp { get; set; }
        public int FanSpeed { get; set; }
        public double NetworkUpload { get; set; }
        public double NetworkDownload { get; set; }
        
        // 新增的丰富性能数据
        public long MemoryUsedMB { get; set; }           // 已用内存(MB)
        public long MemoryTotalMB { get; set; }          // 总内存(MB)
        public long MemoryAvailableMB { get; set; }      // 可用内存(MB)
        public int ProcessCount { get; set; }           // 进程数量
        public int ThreadCount { get; set; }            // 线程数量
        public double SystemUptime { get; set; }        // 系统运行时间(小时)
        public string CpuFrequency { get; set; } = "";  // CPU频率
        public double DiskReadSpeed { get; set; }       // 磁盘读取速度 (MB/s)
        public double DiskWriteSpeed { get; set; }      // 磁盘写入速度 (MB/s)
        public double NetworkLatency { get; set; }      // 网络延迟 (ms)
        public int BatteryLevel { get; set; }           // 电池电量百分比 (-1表示无电池)
        public string PowerStatus { get; set; } = "";   // 电源状态
        public double GpuMemoryUsage { get; set; }      // GPU内存使用率
        public string ActiveWindow { get; set; } = "";  // 当前活动窗口
        public int HandleCount { get; set; }            // 句柄数量
        public double PageFileUsage { get; set; }       // 页面文件使用率
    }
} 