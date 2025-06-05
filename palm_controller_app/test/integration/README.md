# 集成测试说明

## 🔗 关于集成测试

集成测试需要真实的Windows服务器运行才能执行。这些测试会验证Flutter客户端与.NET服务器之间的完整通信流程。

## ⚙️ 运行集成测试

### 前提条件
1. **启动Windows服务器**：确保 `PalmControllerServer` 正在运行
2. **获取服务器IP**：记录服务器显示的IP地址和端口号

### 本地运行
```bash
# 设置服务器地址并运行集成测试
flutter test test/integration/ --dart-define=TEST_SERVER_IP=192.168.1.100 --dart-define=TEST_SERVER_PORT=8080
```

替换 `192.168.1.100` 为你的实际服务器IP地址。

### 跳过集成测试
```bash
# 只运行单元测试和widget测试
flutter test test/widget_test.dart test/unit/

# 或者设置环境变量跳过集成测试
flutter test --dart-define=SKIP_INTEGRATION_TESTS=true
```

## 🚨 CI/CD说明

在GitHub Actions等CI环境中，集成测试会被自动跳过，因为：
- CI环境中没有运行的Windows服务器
- 集成测试需要网络连接和真实的服务端

## 📋 测试内容

集成测试包括：
- ✅ Socket连接建立和断开
- ✅ 心跳和消息通信
- ✅ 鼠标控制指令测试
- ✅ 键盘控制指令测试  
- ✅ 媒体控制指令测试
- ✅ 系统控制指令测试

## 💡 故障排除

### 连接失败
1. 确认Windows服务器正在运行
2. 检查防火墙设置
3. 验证IP地址和端口号
4. 确保客户端和服务器在同一网络

### 测试超时
- 增加测试超时时间
- 检查网络延迟
- 确认服务器响应正常 