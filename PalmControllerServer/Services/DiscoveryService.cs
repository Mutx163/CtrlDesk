using System;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using System.Linq;

namespace PalmControllerServer.Services
{
    public class DiscoveryService : IDisposable
    {
        private UdpClient? _udpServer;
        private CancellationTokenSource? _cancellationTokenSource;
        private bool _isRunning = false;
        private readonly int _discoveryPort = 8079; // UDP发现端口
        private readonly int _servicePort; // TCP服务端口
        private readonly string _serviceName;
        private readonly string _hostName;

        public DiscoveryService(int servicePort, string serviceName = "PalmController")
        {
            _servicePort = servicePort;
            _serviceName = serviceName;
            _hostName = Environment.MachineName;
        }

        public async Task<bool> StartAsync()
        {
            if (_isRunning)
                return true;

            try
            {
                _udpServer = new UdpClient(_discoveryPort);
                _cancellationTokenSource = new CancellationTokenSource();
                _isRunning = true;

                LogService.Instance.Info($"Discovery service starting on UDP port {_discoveryPort}", "Discovery");
                
                // 验证UDP服务器绑定成功
                var localEndpoint = _udpServer.Client.LocalEndPoint;
                LogService.Instance.Info($"UDP server bound to: {localEndpoint}", "Discovery");

                // 启动广播任务
                _ = Task.Run(async () => await BroadcastServiceAsync(_cancellationTokenSource.Token));
                LogService.Instance.Info("Broadcast task started", "Discovery");

                // 启动响应任务
                _ = Task.Run(async () => await HandleDiscoveryRequestsAsync(_cancellationTokenSource.Token));
                LogService.Instance.Info("Request handler task started", "Discovery");

                LogService.Instance.Info($"Discovery service fully started and listening on UDP port {_discoveryPort}", "Discovery");
                return true;
            }
            catch (Exception ex)
            {
                LogService.Instance.Error("Failed to start discovery service", ex, "Discovery");
                return false;
            }
        }

        public async Task StopAsync()
        {
            if (!_isRunning)
                return;

            try
            {
                _isRunning = false;
                _cancellationTokenSource?.Cancel();
                _udpServer?.Close();
                _udpServer?.Dispose();
                _udpServer = null;

                LogService.Instance.Info("Discovery service stopped", "Discovery");
            }
            catch (Exception ex)
            {
                LogService.Instance.Error("Error stopping discovery service", ex, "Discovery");
            }
        }

        // 定期广播服务信息
        private async Task BroadcastServiceAsync(CancellationToken cancellationToken)
        {
            var localIP = GetLocalIPAddress();
            var serviceInfo = new
            {
                serviceName = _serviceName,
                serviceType = "palm_controller",
                hostName = _hostName,
                ipAddress = localIP,
                port = _servicePort,
                version = "1.0.0",
                timestamp = DateTimeOffset.Now.ToUnixTimeSeconds()
            };

            var jsonData = JsonSerializer.Serialize(serviceInfo);
            var data = Encoding.UTF8.GetBytes(jsonData);

            while (!cancellationToken.IsCancellationRequested && _isRunning)
            {
                try
                {
                    // 获取本机所在的网段进行广播
                    var broadcastAddresses = GetBroadcastAddresses(localIP);
                    
                    foreach (var broadcastAddress in broadcastAddresses)
                    {
                        try
                        {
                            using var broadcastClient = new UdpClient();
                            broadcastClient.EnableBroadcast = true;
                            await broadcastClient.SendAsync(data, data.Length, broadcastAddress);
                            
                            LogService.Instance.Debug($"Broadcasted service info to {broadcastAddress}: {localIP}:{_servicePort}", "Discovery");
                        }
                        catch (Exception ex)
                        {
                            LogService.Instance.Debug($"Failed to broadcast to {broadcastAddress}: {ex.Message}", "Discovery");
                        }
                    }

                    // 每3秒广播一次
                    await Task.Delay(3000, cancellationToken);
                }
                catch (OperationCanceledException)
                {
                    break;
                }
                catch (Exception ex)
                {
                    LogService.Instance.Warning($"Error broadcasting service info: {ex.Message}", "Discovery");
                    await Task.Delay(5000, cancellationToken); // 出错时延长间隔
                }
            }
        }

        // 获取广播地址列表
        private List<IPEndPoint> GetBroadcastAddresses(string localIP)
        {
            var addresses = new List<IPEndPoint>();

            try
            {
                // 1. 基于本机IP计算网段广播地址
                var ipParts = localIP.Split('.');
                if (ipParts.Length == 4)
                {
                    var networkBroadcast = $"{ipParts[0]}.{ipParts[1]}.{ipParts[2]}.255";
                    addresses.Add(new IPEndPoint(IPAddress.Parse(networkBroadcast), _discoveryPort));
                    LogService.Instance.Info($"Added network broadcast address: {networkBroadcast}", "Discovery");
                }

                // 2. 添加常见的局域网广播地址作为备用
                var commonNetworks = new[]
                {
                    "192.168.1.255",
                    "192.168.0.255", 
                    "192.168.123.255",
                    "10.0.0.255",
                    "172.16.0.255"
                };

                foreach (var network in commonNetworks)
                {
                    var endpoint = new IPEndPoint(IPAddress.Parse(network), _discoveryPort);
                    if (!addresses.Any(a => a.Address.Equals(endpoint.Address)))
                    {
                        addresses.Add(endpoint);
                    }
                }

                // 3. 如果都失败了，使用全局广播作为最后手段
                if (addresses.Count == 0)
                {
                    addresses.Add(new IPEndPoint(IPAddress.Broadcast, _discoveryPort));
                    LogService.Instance.Warning("Using global broadcast as fallback", "Discovery");
                }

                LogService.Instance.Info($"Will broadcast to {addresses.Count} addresses", "Discovery");
            }
            catch (Exception ex)
            {
                LogService.Instance.Warning($"Error calculating broadcast addresses: {ex.Message}", "Discovery");
                // 使用全局广播作为备用
                addresses.Add(new IPEndPoint(IPAddress.Broadcast, _discoveryPort));
            }

            return addresses;
        }

        // 处理发现请求
        private async Task HandleDiscoveryRequestsAsync(CancellationToken cancellationToken)
        {
            while (!cancellationToken.IsCancellationRequested && _isRunning && _udpServer != null)
            {
                try
                {
                    var result = await _udpServer.ReceiveAsync();
                    var requestData = Encoding.UTF8.GetString(result.Buffer);

                    LogService.Instance.Debug($"Received discovery request from {result.RemoteEndPoint}: {requestData}", "Discovery");

                    // 简单的发现请求协议
                    if (requestData.Contains("PALM_CONTROLLER_DISCOVERY"))
                    {
                        // 立即响应发现请求
                        await RespondToDiscoveryRequest(result.RemoteEndPoint);
                    }
                }
                catch (OperationCanceledException)
                {
                    break;
                }
                catch (Exception ex)
                {
                    LogService.Instance.Warning($"Error handling discovery request: {ex.Message}", "Discovery");
                }
            }
        }

        // 响应发现请求
        private async Task RespondToDiscoveryRequest(IPEndPoint requesterEndpoint)
        {
            try
            {
                var localIP = GetLocalIPAddress();
                var response = new
                {
                    serviceName = _serviceName,
                    serviceType = "palm_controller",
                    hostName = _hostName,
                    ipAddress = localIP,
                    port = _servicePort,
                    version = "1.0.0",
                    timestamp = DateTimeOffset.Now.ToUnixTimeSeconds()
                };

                var jsonData = JsonSerializer.Serialize(response);
                var data = Encoding.UTF8.GetBytes(jsonData);

                using var responseClient = new UdpClient();
                await responseClient.SendAsync(data, data.Length, requesterEndpoint);

                LogService.Instance.Info($"Responded to discovery request from {requesterEndpoint}", "Discovery");
            }
            catch (Exception ex)
            {
                LogService.Instance.Warning($"Error responding to discovery request: {ex.Message}", "Discovery");
            }
        }

        // 获取本机IP地址
        private string GetLocalIPAddress()
        {
            try
            {
                var host = Dns.GetHostEntry(Dns.GetHostName());
                foreach (var ip in host.AddressList)
                {
                    if (ip.AddressFamily == AddressFamily.InterNetwork && !IPAddress.IsLoopback(ip))
                    {
                        return ip.ToString();
                    }
                }
            }
            catch (Exception ex)
            {
                LogService.Instance.Warning("Failed to get local IP address", "Discovery");
            }
            return "127.0.0.1";
        }

        public void Dispose()
        {
            Task.Run(async () => await StopAsync()).Wait();
        }
    }
} 