using System;
using System.Collections.Generic;
using System.Linq;
using System.Management;
using System.Threading.Tasks;
using System.Diagnostics;

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
            }
            catch (Exception ex)
            {
                LogService.Instance.Warning($"Failed to initialize performance counters: {ex.Message}", "HardwareMonitor");
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
                    NetworkDownload = GetNetworkDownload()
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
                    NetworkDownload = 0
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
                    // 第一次调用通常返回0，所以稍微延迟一下再获取真实值
                    var usage = _cpuCounter.NextValue();
                    if (usage == 0)
                    {
                        System.Threading.Thread.Sleep(100);
                        usage = _cpuCounter.NextValue();
                    }
                    return Math.Round(usage, 1);
                }
                return 0;
            }
            catch
            {
                return 0;
            }
        }

        private double GetRamUsage()
        {
            try
            {
                // 获取总内存
                long totalMemoryMB = 0;
                using (var searcher = new ManagementObjectSearcher("SELECT * FROM Win32_ComputerSystem"))
                {
                    foreach (ManagementObject system in searcher.Get())
                    {
                        var totalMemoryBytes = system["TotalPhysicalMemory"]?.ToString();
                        if (long.TryParse(totalMemoryBytes, out long bytes))
                        {
                            totalMemoryMB = bytes / (1024 * 1024);
                        }
                    }
                }

                // 获取可用内存
                if (_ramCounter != null && totalMemoryMB > 0)
                {
                    var availableMB = _ramCounter.NextValue();
                    var usedMB = totalMemoryMB - availableMB;
                    var usagePercentage = (usedMB / totalMemoryMB) * 100;
                    return Math.Round(usagePercentage, 1);
                }
                return 0;
            }
            catch
            {
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
                using var cpuCounter = new PerformanceCounter("PhysicalDisk", "% Disk Time", "_Total");
                var usage = cpuCounter.NextValue();
                System.Threading.Thread.Sleep(100);
                usage = cpuCounter.NextValue();
                return Math.Round(usage, 1);
            }
            catch
            {
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
            // 网络上传速度，暂时返回0
            // 可以通过PerformanceCounter获取，但需要动态获取网络接口名称
            return 0;
        }

        private double GetNetworkDownload()
        {
            // 网络下载速度，暂时返回0
            return 0;
        }

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
    }
} 