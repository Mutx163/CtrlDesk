using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace PalmControllerServer.Services
{
    /// <summary>
    /// 截图服务 - 使用System.Drawing.Common实现
    /// 支持全屏、窗口、区域截图等功能
    /// </summary>
    public class ScreenshotService
    {
        private static readonly Lazy<ScreenshotService> _instance = new(() => new ScreenshotService());
        public static ScreenshotService Instance => _instance.Value;

        private readonly string _screenshotDirectory;
        private System.Threading.Timer? _continuousTimer;
        private int _intervalSeconds = 3;

        // Windows API for window capture
        [DllImport("user32.dll")]
        private static extern IntPtr GetForegroundWindow();

        [DllImport("user32.dll")]
        private static extern IntPtr GetWindowDC(IntPtr hWnd);

        [DllImport("user32.dll")]
        private static extern bool ReleaseDC(IntPtr hWnd, IntPtr hDC);

        [DllImport("user32.dll")]
        private static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

        [DllImport("gdi32.dll")]
        private static extern bool BitBlt(IntPtr hdc, int nXDest, int nYDest, int nWidth, int nHeight,
                                         IntPtr hdcSrc, int nXSrc, int nYSrc, int dwRop);

        [StructLayout(LayoutKind.Sequential)]
        public struct RECT
        {
            public int Left;
            public int Top;
            public int Right;
            public int Bottom;
        }

        private ScreenshotService()
        {
            // 设置截图保存目录
            _screenshotDirectory = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyPictures), "PalmController Screenshots");
            Directory.CreateDirectory(_screenshotDirectory);
            
            LogService.Instance.Info($"ScreenshotService initialized, save directory: {_screenshotDirectory}", "Screenshot");
        }

        /// <summary>
        /// 全屏截图
        /// </summary>
        /// <param name="delay">延迟秒数</param>
        /// <returns>截图文件路径</returns>
        public async Task<string> TakeFullScreenAsync(int delay = 0)
        {
            if (delay > 0)
            {
                await Task.Delay(delay * 1000);
            }

            try
            {
                var bounds = Screen.PrimaryScreen?.Bounds ?? throw new InvalidOperationException("Primary screen not available");
                var screenshot = new Bitmap(bounds.Width, bounds.Height, PixelFormat.Format32bppArgb);

                using var graphics = Graphics.FromImage(screenshot);
                graphics.CopyFromScreen(bounds.X, bounds.Y, 0, 0, bounds.Size, CopyPixelOperation.SourceCopy);

                var fileName = $"fullscreen_{DateTime.Now:yyyyMMdd_HHmmss}.png";
                var filePath = Path.Combine(_screenshotDirectory, fileName);
                
                screenshot.Save(filePath, ImageFormat.Png);
                screenshot.Dispose();

                LogService.Instance.Info($"Full screen screenshot saved: {fileName}", "Screenshot");
                return filePath;
            }
            catch (Exception ex)
            {
                LogService.Instance.Error("Failed to take full screen screenshot", ex, "Screenshot");
                throw;
            }
        }

        /// <summary>
        /// 当前活动窗口截图
        /// </summary>
        /// <param name="delay">延迟秒数</param>
        /// <returns>截图文件路径</returns>
        public async Task<string> TakeActiveWindowAsync(int delay = 0)
        {
            if (delay > 0)
            {
                await Task.Delay(delay * 1000);
            }

            try
            {
                var foregroundWindow = GetForegroundWindow();
                if (foregroundWindow == IntPtr.Zero)
                {
                    throw new InvalidOperationException("No active window found");
                }

                GetWindowRect(foregroundWindow, out RECT windowRect);
                
                var width = windowRect.Right - windowRect.Left;
                var height = windowRect.Bottom - windowRect.Top;
                
                if (width <= 0 || height <= 0)
                {
                    throw new InvalidOperationException("Invalid window dimensions");
                }

                var screenshot = new Bitmap(width, height, PixelFormat.Format32bppArgb);
                using var graphics = Graphics.FromImage(screenshot);
                graphics.CopyFromScreen(windowRect.Left, windowRect.Top, 0, 0, new Size(width, height), CopyPixelOperation.SourceCopy);

                var fileName = $"window_{DateTime.Now:yyyyMMdd_HHmmss}.png";
                var filePath = Path.Combine(_screenshotDirectory, fileName);
                
                screenshot.Save(filePath, ImageFormat.Png);
                screenshot.Dispose();

                LogService.Instance.Info($"Active window screenshot saved: {fileName}", "Screenshot");
                return filePath;
            }
            catch (Exception ex)
            {
                LogService.Instance.Error("Failed to take active window screenshot", ex, "Screenshot");
                throw;
            }
        }

        /// <summary>
        /// 区域截图 - 目前实现为全屏，可扩展为指定区域
        /// </summary>
        /// <param name="x">起始X坐标</param>
        /// <param name="y">起始Y坐标</param>
        /// <param name="width">宽度</param>
        /// <param name="height">高度</param>
        /// <param name="delay">延迟秒数</param>
        /// <returns>截图文件路径</returns>
        public async Task<string> TakeRegionAsync(int x = 0, int y = 0, int width = 0, int height = 0, int delay = 0)
        {
            if (delay > 0)
            {
                await Task.Delay(delay * 1000);
            }

            try
            {
                // 如果没有指定区域，默认为屏幕中央的一半区域
                if (width == 0 || height == 0)
                {
                    var bounds = Screen.PrimaryScreen?.Bounds ?? throw new InvalidOperationException("Primary screen not available");
                    width = bounds.Width / 2;
                    height = bounds.Height / 2;
                    x = bounds.Width / 4;
                    y = bounds.Height / 4;
                }

                var screenshot = new Bitmap(width, height, PixelFormat.Format32bppArgb);
                using var graphics = Graphics.FromImage(screenshot);
                graphics.CopyFromScreen(x, y, 0, 0, new Size(width, height), CopyPixelOperation.SourceCopy);

                var fileName = $"region_{DateTime.Now:yyyyMMdd_HHmmss}.png";
                var filePath = Path.Combine(_screenshotDirectory, fileName);
                
                screenshot.Save(filePath, ImageFormat.Png);
                screenshot.Dispose();

                LogService.Instance.Info($"Region screenshot saved: {fileName} ({x},{y} {width}x{height})", "Screenshot");
                return filePath;
            }
            catch (Exception ex)
            {
                LogService.Instance.Error("Failed to take region screenshot", ex, "Screenshot");
                throw;
            }
        }

        /// <summary>
        /// 开始连续截图
        /// </summary>
        /// <param name="intervalSeconds">间隔秒数</param>
        public void StartContinuousScreenshot(int intervalSeconds = 3)
        {
            StopContinuousScreenshot(); // 停止之前的定时器

            _intervalSeconds = intervalSeconds;
            _continuousTimer = new System.Threading.Timer(async _ =>
            {
                try
                {
                    await TakeFullScreenAsync();
                }
                catch (Exception ex)
                {
                    LogService.Instance.Error("Continuous screenshot failed", ex, "Screenshot");
                }
            }, null, 0, intervalSeconds * 1000);

            LogService.Instance.Info($"Continuous screenshot started, interval: {intervalSeconds}s", "Screenshot");
        }

        /// <summary>
        /// 停止连续截图
        /// </summary>
        public void StopContinuousScreenshot()
        {
            _continuousTimer?.Dispose();
            _continuousTimer = null;
            LogService.Instance.Info("Continuous screenshot stopped", "Screenshot");
        }

        /// <summary>
        /// 获取所有截图文件列表
        /// </summary>
        /// <returns>截图文件信息列表</returns>
        public List<ScreenshotInfo> GetScreenshotHistory()
        {
            try
            {
                var files = Directory.GetFiles(_screenshotDirectory, "*.png")
                                   .OrderByDescending(f => File.GetCreationTime(f))
                                   .Take(50) // 最多返回50个最新的截图
                                   .ToList();

                return files.Select(f => new ScreenshotInfo
                {
                    FileName = Path.GetFileName(f),
                    FilePath = f,
                    CreatedTime = File.GetCreationTime(f),
                    FileSize = new FileInfo(f).Length,
                    Type = GetScreenshotType(Path.GetFileName(f))
                }).ToList();
            }
            catch (Exception ex)
            {
                LogService.Instance.Error("Failed to get screenshot history", ex, "Screenshot");
                return new List<ScreenshotInfo>();
            }
        }

        /// <summary>
        /// 删除指定截图文件
        /// </summary>
        /// <param name="fileName">文件名</param>
        /// <returns>是否删除成功</returns>
        public bool DeleteScreenshot(string fileName)
        {
            try
            {
                var filePath = Path.Combine(_screenshotDirectory, fileName);
                if (File.Exists(filePath))
                {
                    File.Delete(filePath);
                    LogService.Instance.Info($"Screenshot deleted: {fileName}", "Screenshot");
                    return true;
                }
                return false;
            }
            catch (Exception ex)
            {
                LogService.Instance.Error($"Failed to delete screenshot: {fileName}", ex, "Screenshot");
                return false;
            }
        }

        /// <summary>
        /// 清理所有截图文件
        /// </summary>
        /// <returns>清理的文件数量</returns>
        public int ClearAllScreenshots()
        {
            try
            {
                var files = Directory.GetFiles(_screenshotDirectory, "*.png");
                foreach (var file in files)
                {
                    File.Delete(file);
                }
                LogService.Instance.Info($"All screenshots cleared, count: {files.Length}", "Screenshot");
                return files.Length;
            }
            catch (Exception ex)
            {
                LogService.Instance.Error("Failed to clear all screenshots", ex, "Screenshot");
                return 0;
            }
        }

        /// <summary>
        /// 打开截图目录
        /// </summary>
        public void OpenScreenshotDirectory()
        {
            try
            {
                System.Diagnostics.Process.Start("explorer.exe", _screenshotDirectory);
            }
            catch (Exception ex)
            {
                LogService.Instance.Error("Failed to open screenshot directory", ex, "Screenshot");
            }
        }

        private string GetScreenshotType(string fileName)
        {
            if (fileName.StartsWith("fullscreen_")) return "全屏";
            if (fileName.StartsWith("window_")) return "窗口";
            if (fileName.StartsWith("region_")) return "区域";
            return "未知";
        }

        public void Dispose()
        {
            StopContinuousScreenshot();
        }
    }

    /// <summary>
    /// 截图信息数据模型
    /// </summary>
    public class ScreenshotInfo
    {
        public string FileName { get; set; } = "";
        public string FilePath { get; set; } = "";
        public DateTime CreatedTime { get; set; }
        public long FileSize { get; set; }
        public string Type { get; set; } = "";
    }
} 