﻿using System;
using System.ComponentModel;
using System.IO;
using System.Windows;
using System.Windows.Threading;
using System.Windows.Controls;
using System.Windows.Forms; // 添加 WinForms 引用
using PalmControllerServer.Services;

namespace PalmControllerServer
{
    /// <summary>
    /// Interaction logic for MainWindow.xaml
    /// </summary>
    public partial class MainWindow : Window
    {
        private SocketServer _socketServer = null!;
        private SystemControlService _systemControlService = null!;
        private DiscoveryService _discoveryService = null!;
        private int _connectedClients = 0;
        private NotifyIcon? _notifyIcon; // 改用原生 NotifyIcon

        public MainWindow()
        {
            InitializeComponent();
            InitializeServices();
            InitializeLogging();
            InitializeTrayIcon(); // 初始化托盘图标
            
            // 自动启动Socket服务器用于测试
            AutoStartServer();
        }
        
        private async void AutoStartServer()
        {
            // 延迟一秒后自动启动服务器
            await System.Threading.Tasks.Task.Delay(1000);
            try
            {
                var socketSuccess = await _socketServer.StartAsync(8080);
                var discoverySuccess = await _discoveryService.StartAsync();
                
                if (socketSuccess && discoverySuccess)
                {
                    Dispatcher.Invoke(() =>
                    {
                        StartButton.IsEnabled = false;
                        StopButton.IsEnabled = true;
                        
                        // 更新UI
                        StatusTextBlock.Text = "运行中";
                        StatusTextBlock.Foreground = System.Windows.Media.Brushes.Green;
                        IpAddressTextBlock.Text = _socketServer.IpAddress;
                        PortTextBlock.Text = _socketServer.Port.ToString();
                        
                        AddLogMessage($"服务自动启动 - {_socketServer.IpAddress}:{_socketServer.Port}");
                        AddLogMessage("设备发现服务已启动，支持自动连接");
                    });
                }
            }
            catch (Exception ex)
            {
                LogService.Instance.Error("Auto-start server failed", ex, "UI");
                Dispatcher.Invoke(() =>
                {
                    AddLogMessage($"自动启动失败：{ex.Message}");
                });
            }
        }

        private void InitializeServices()
        {
            _socketServer = new SocketServer();
            _systemControlService = new SystemControlService();
            _discoveryService = new DiscoveryService(8080); // 使用相同的端口号

            // 订阅事件
            _socketServer.StatusChanged += OnStatusChanged;
            _socketServer.ClientConnected += OnClientConnected;
            _socketServer.ClientDisconnected += OnClientDisconnected;
            _socketServer.MessageReceived += OnMessageReceived;
            
            // 订阅音量状态变化事件
            _systemControlService.VolumeChanged += OnVolumeChanged;
            
            // 设置SystemControlService对SocketServer的引用，使其能够发送数据到客户端
            _systemControlService.SetSocketServer(_socketServer);
        }

        private void InitializeLogging()
        {
            // 使用新的日志服务
            LogService.Instance.Info("PalmController Server UI initialized", "UI");
            AddLogMessage("服务端已启动");
        }

        private void InitializeTrayIcon()
        {
            try
            {
                _notifyIcon = new NotifyIcon()
                {
                    Icon = SystemIcons.Information, // 使用系统图标
                    Text = "掌控者服务端",
                    Visible = true // 重要：必须设置为 true
                };

                // 创建右键菜单
                var contextMenu = new ContextMenuStrip();
                
                var showItem = new ToolStripMenuItem("显示/隐藏窗口");
                showItem.Click += (s, e) => ToggleWindowVisibility();
                
                var exitItem = new ToolStripMenuItem("退出");
                exitItem.Click += (s, e) => ExitApplication();
                
                contextMenu.Items.Add(showItem);
                contextMenu.Items.Add(exitItem);
                
                _notifyIcon.ContextMenuStrip = contextMenu;
                
                // 双击事件
                _notifyIcon.MouseDoubleClick += (s, e) => ToggleWindowVisibility();
                
                AddLogMessage("原生托盘图标初始化成功。");
            }
            catch (Exception ex)
            {
                System.Windows.MessageBox.Show($"创建托盘图标时发生致命错误: {ex.ToString()}", "托盘图标错误", MessageBoxButton.OK, MessageBoxImage.Error);
                AddLogMessage($"托盘图标创建失败: {ex.ToString()}");
            }
        }
        
        private void ToggleWindowVisibility()
        {
            if (IsVisible)
            {
                Hide();
            }
            else
            {
                Show();
                WindowState = WindowState.Normal;
                Activate();
            }
        }
        
        private void ExitApplication()
        {
            _notifyIcon?.Dispose();
            System.Windows.Application.Current.Shutdown();
        }

        private async void StartButton_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                var socketSuccess = await _socketServer.StartAsync(8080);
                var discoverySuccess = await _discoveryService.StartAsync();
                
                if (socketSuccess && discoverySuccess)
                {
                    // 初始化音量监听
                    _systemControlService.InitializeVolumeMonitoring();
                    
                    StartButton.IsEnabled = false;
                    StopButton.IsEnabled = true;
                    
                    // 更新UI
                    StatusTextBlock.Text = "运行中";
                    StatusTextBlock.Foreground = System.Windows.Media.Brushes.Green;
                    IpAddressTextBlock.Text = _socketServer.IpAddress;
                    PortTextBlock.Text = _socketServer.Port.ToString();
                    
                    AddLogMessage($"服务已启动 - {_socketServer.IpAddress}:{_socketServer.Port}");
                    AddLogMessage("设备发现服务已启动，支持自动连接");
                    AddLogMessage("音量变化监听已启动，PC端音量变化将自动同步到手机");
                }
            }
            catch (Exception ex)
            {
                System.Windows.MessageBox.Show($"启动服务失败：{ex.Message}", "错误", MessageBoxButton.OK, MessageBoxImage.Error);
                LogService.Instance.Error("Failed to start server", ex, "UI");
            }
        }

        private async void StopButton_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                await _socketServer.StopAsync();
                await _discoveryService.StopAsync();
                
                // 清理音量监听
                _systemControlService.DisposeVolumeMonitoring();
                
                StartButton.IsEnabled = true;
                StopButton.IsEnabled = false;
                
                // 更新UI
                StatusTextBlock.Text = "未启动";
                StatusTextBlock.Foreground = System.Windows.Media.Brushes.Red;
                IpAddressTextBlock.Text = "--";
                PortTextBlock.Text = "--";
                _connectedClients = 0;
                ClientCountTextBlock.Text = "已连接设备：0";
                
                AddLogMessage("服务已停止");
            }
            catch (Exception ex)
            {
                System.Windows.MessageBox.Show($"停止服务失败：{ex.Message}", "错误", MessageBoxButton.OK, MessageBoxImage.Error);
                LogService.Instance.Error("Failed to stop server", ex, "UI");
            }
        }

        private void MinimizeButton_Click(object sender, RoutedEventArgs e)
        {
            // 最小化到系统托盘
            Hide();
        }

        // 事件处理方法
        private void OnStatusChanged(string status)
        {
            Dispatcher.Invoke(() =>
            {
                AddLogMessage(status);
            });
        }

        private async void OnClientConnected(string clientId)
        {
            Dispatcher.Invoke(() =>
            {
                _connectedClients++;
                ClientCountTextBlock.Text = $"已连接设备：{_connectedClients}";
                AddLogMessage($"设备已连接：{clientId[..8]}...");
            });

            // 🔧 修复：简化初始音量状态发送，避免消息冲突
            try
            {
                // 稍等一会儿，确保客户端连接完全建立
                await System.Threading.Tasks.Task.Delay(500);
                
                // 直接从 SystemControlService 获取实时音量并发送
                var initialVolume = _systemControlService.GetSystemVolume(); // 获取实时音量
                var initialMute = _systemControlService.GetMuteState();   // 获取实时静音状态

                // 构造 ControlMessage
                var volumeStatusMessage = Models.ControlMessage.CreateVolumeStatus(
                    Guid.NewGuid().ToString(),
                    initialVolume,
                    initialMute
                );
                
                // 通过 SocketServer 发送给特定客户端
                var sendSuccess = await _socketServer.SendMessageToClientAsync(clientId, volumeStatusMessage);
                if (sendSuccess)
                {
                    LogService.Instance.Info($"Sent initial volume status to client {clientId}: {initialVolume:P0}, Muted: {initialMute}", "Socket");
                }
                else
                {
                    LogService.Instance.Warning($"Failed to send initial volume status to client {clientId}", "Socket");
                }
            }
            catch (Exception ex)
            {
                LogService.Instance.Error($"Error sending initial volume status to client {clientId}", ex, "Socket");
            }
        }

        private void OnClientDisconnected(string clientId)
        {
            Dispatcher.Invoke(() =>
            {
                _connectedClients = Math.Max(0, _connectedClients - 1);
                ClientCountTextBlock.Text = $"已连接设备：{_connectedClients}";
                AddLogMessage($"设备已断开：{clientId[..8]}...");
            });
        }

        private void OnMessageReceived(Models.ControlMessage message)
        {
            // 处理控制消息
            if (message.Type != "heartbeat") // 不显示心跳消息
            {
                Dispatcher.Invoke(() =>
                {
                    AddLogMessage($"收到控制指令：{message.Type}");
                });
            }

            // 处理系统控制
            _systemControlService.ProcessControlMessage(message);
        }

        private async void OnVolumeChanged(float volume, bool isMuted)
        {
            Dispatcher.Invoke(() =>
            {
                AddLogMessage($"音量状态更新：{volume:P0}, 静音: {isMuted}");
            });
            
            // 广播音量状态到所有连接的客户端
            await _socketServer.BroadcastVolumeStatusAsync(volume, isMuted);
        }

        private void AddLogMessage(string message)
        {
            var timestamp = DateTime.Now.ToString("HH:mm:ss");
            var logMessage = $"[{timestamp}] {message}\n";
            
            LogTextBlock.Text += logMessage;
            
            // 自动滚动到底部
            LogScrollViewer.ScrollToEnd();
            
            // 限制日志长度，避免内存占用过多
            if (LogTextBlock.Text.Length > 10000)
            {
                var lines = LogTextBlock.Text.Split('\n');
                if (lines.Length > 100)
                {
                    LogTextBlock.Text = string.Join('\n', lines[^50..]);
                }
            }
        }

        protected override void OnClosed(EventArgs e)
        {
            // 清理资源
            _systemControlService?.DisposeVolumeMonitoring();
            _socketServer?.Dispose();
            LogService.Instance.Dispose();
            base.OnClosed(e);
        }

        protected override void OnStateChanged(EventArgs e)
        {
            if (WindowState == WindowState.Minimized)
            {
                Hide();
            }
            base.OnStateChanged(e);
        }

        protected override void OnClosing(CancelEventArgs e)
        {
            // 阻止窗口关闭，而是将其隐藏
            e.Cancel = true;
            Hide();
            base.OnClosing(e);
        }
    }
}