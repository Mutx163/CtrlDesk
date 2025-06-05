using System;
using System.Collections.Concurrent;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using PalmControllerServer.Models;

namespace PalmControllerServer.Services
{
    public class SocketServer
    {
        private TcpListener? _listener;
        private CancellationTokenSource? _cancellationTokenSource;
        private readonly ConcurrentDictionary<string, ClientConnection> _clients = new();
        private bool _isRunning = false;

        // 音量状态管理
        private float _currentVolume = 0.5f;
        private bool _currentMute = false;

        public event Action<ControlMessage>? MessageReceived;
        public event Action<string>? ClientConnected;
        public event Action<string>? ClientDisconnected;
        public event Action<string>? StatusChanged;

        public bool IsRunning => _isRunning;
        public int Port { get; private set; }
        public string IpAddress { get; private set; } = string.Empty;

        // 启动服务器
        public async Task<bool> StartAsync(int port = 8080)
        {
            if (_isRunning)
                return true;

            try
            {
                // 获取本机IP地址
                IpAddress = GetLocalIPAddress();
                Port = port;

                _listener = new TcpListener(IPAddress.Any, port);
                _listener.Start();

                _cancellationTokenSource = new CancellationTokenSource();
                _isRunning = true;

                LogService.Instance.Info($"Socket server started on {IpAddress}:{Port}", "Socket");
                StatusChanged?.Invoke($"服务已启动 - {IpAddress}:{Port}");

                // 开始监听客户端连接
                _ = Task.Run(async () => await AcceptClientsAsync(_cancellationTokenSource.Token));

                return true;
            }
            catch (Exception ex)
            {
                LogService.Instance.Error("Failed to start socket server", ex, "Socket");
                StatusChanged?.Invoke($"启动失败: {ex.Message}");
                return false;
            }
        }

        // 停止服务器
        public Task StopAsync()
        {
            if (!_isRunning)
                return Task.CompletedTask;

            try
            {
                _isRunning = false;
                _cancellationTokenSource?.Cancel();

                // 断开所有客户端连接
                foreach (var client in _clients.Values)
                {
                    client.Dispose();
                }
                _clients.Clear();

                _listener?.Stop();
                _listener = null;

                LogService.Instance.Info("Socket server stopped", "Socket");
                StatusChanged?.Invoke("服务已停止");
            }
            catch (Exception ex)
            {
                LogService.Instance.Error("Error stopping socket server", ex, "Socket");
            }
            
            return Task.CompletedTask;
        }

        // 监听客户端连接
        private async Task AcceptClientsAsync(CancellationToken cancellationToken)
        {
            while (!cancellationToken.IsCancellationRequested && _listener != null)
            {
                try
                {
                    var tcpClient = await _listener.AcceptTcpClientAsync();
                    var clientId = Guid.NewGuid().ToString();
                    var client = new ClientConnection(clientId, tcpClient);

                    _clients[clientId] = client;

                    LogService.Instance.SocketConnection("connect", clientId, tcpClient.Client.RemoteEndPoint?.ToString());
                    ClientConnected?.Invoke(clientId);

                    // 为每个客户端启动处理任务
                    _ = Task.Run(async () => await HandleClientAsync(client, cancellationToken));
                }
                catch (ObjectDisposedException)
                {
                    // 服务器已停止
                    break;
                }
                catch (Exception ex)
                {
                    LogService.Instance.Error("Error accepting client connection", ex, "Socket");
                }
            }
        }

        // 处理客户端消息
        private async Task HandleClientAsync(ClientConnection client, CancellationToken cancellationToken)
        {
            try
            {
                var stream = client.TcpClient.GetStream();
                var buffer = new byte[4096];
                var messageBuilder = new StringBuilder();

                while (!cancellationToken.IsCancellationRequested && client.TcpClient.Connected)
                {
                    var bytesRead = await stream.ReadAsync(buffer, 0, buffer.Length, cancellationToken);
                    if (bytesRead == 0)
                        break;

                    var data = Encoding.UTF8.GetString(buffer, 0, bytesRead);
                    messageBuilder.Append(data);

                    // 处理完整的消息（以换行符分隔）
                    var messages = messageBuilder.ToString().Split('\n');
                    for (int i = 0; i < messages.Length - 1; i++)
                    {
                        var messageJson = messages[i].Trim();
                        if (!string.IsNullOrEmpty(messageJson))
                        {
                            var message = ControlMessage.FromJson(messageJson);
                            if (message != null)
                            {
                                LogService.Instance.SocketConnection("receive", client.Id, 
                                    messageType: message.Type, dataSize: bytesRead);
                                MessageReceived?.Invoke(message);

                                // 发送确认响应
                                var response = ControlMessage.CreateResponse(message.MessageId, true);
                                await SendMessageToClientAsync(client.Id, response);
                            }
                        }
                    }

                    // 保留未完成的消息
                    messageBuilder.Clear();
                    if (messages.Length > 0)
                        messageBuilder.Append(messages[^1]);
                }
            }
            catch (Exception ex)
            {
                LogService.Instance.SocketConnection("error", client.Id, error: ex.Message);
            }
            finally
            {
                // 清理客户端连接
                _clients.TryRemove(client.Id, out _);
                client.Dispose();
                ClientDisconnected?.Invoke(client.Id);
                LogService.Instance.SocketConnection("disconnect", client.Id);
            }
        }

        // 向指定客户端发送消息
        public async Task<bool> SendMessageToClientAsync(string clientId, ControlMessage message)
        {
            if (!_clients.TryGetValue(clientId, out var client))
                return false;

            try
            {
                var json = message.ToJson() + "\n";
                var data = Encoding.UTF8.GetBytes(json);
                var stream = client.TcpClient.GetStream();
                await stream.WriteAsync(data, 0, data.Length);
                return true;
            }
            catch (Exception ex)
            {
                LogService.Instance.SocketConnection("send_error", clientId, error: ex.Message);
                return false;
            }
        }

        // 广播消息到所有客户端
        public async Task BroadcastMessageAsync(ControlMessage message)
        {
            var tasks = new List<Task>();
            foreach (var client in _clients.Values)
            {
                tasks.Add(SendMessageToClientAsync(client.Id, message));
            }
            await Task.WhenAll(tasks);
        }

        // 广播音量状态到所有客户端
        public async Task BroadcastVolumeStatusAsync(float volume, bool isMuted)
        {
            _currentVolume = volume;
            _currentMute = isMuted;

            var volumeStatusMessage = ControlMessage.CreateVolumeStatus(
                Guid.NewGuid().ToString(),
                volume,
                isMuted
            );

            LogService.Instance.Info($"Broadcasting volume status: {volume:P0}, Muted: {isMuted}", "Socket");
            await BroadcastMessageAsync(volumeStatusMessage);
        }

        // 向新连接的客户端发送当前音量状态
        public async Task SendCurrentVolumeStatusAsync(string clientId)
        {
            var volumeStatusMessage = ControlMessage.CreateVolumeStatus(
                Guid.NewGuid().ToString(),
                _currentVolume,
                _currentMute
            );

            await SendMessageToClientAsync(clientId, volumeStatusMessage);
            LogService.Instance.Info($"Sent current volume status to client {clientId}: {_currentVolume:P0}, Muted: {_currentMute}", "Socket");
        }

        // 获取本机IP地址
        private string GetLocalIPAddress()
        {
            try
            {
                var host = Dns.GetHostEntry(Dns.GetHostName());
                foreach (var ip in host.AddressList)
                {
                    if (ip.AddressFamily == AddressFamily.InterNetwork)
                    {
                        return ip.ToString();
                    }
                }
            }
            catch (Exception ex)
            {
                LogService.Instance.Warning($"Failed to get local IP address: {ex.Message}", "Socket");
            }
            return "127.0.0.1";
        }

        public void Dispose()
        {
            Task.Run(async () => await StopAsync()).Wait();
        }
    }

    // 客户端连接类
    public class ClientConnection : IDisposable
    {
        public string Id { get; }
        public TcpClient TcpClient { get; }
        public DateTime ConnectedAt { get; }

        public ClientConnection(string id, TcpClient tcpClient)
        {
            Id = id;
            TcpClient = tcpClient;
            ConnectedAt = DateTime.Now;
        }

        public void Dispose()
        {
            TcpClient?.Close();
            TcpClient?.Dispose();
        }
    }
} 