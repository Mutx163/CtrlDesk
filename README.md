# Palm Controller 项目

一个跨平台的远程控制解决方案，包含 Android 移动端控制器和 Windows 桌面端服务器。

## 📁 项目结构

```
├── palm_controller_app/     # Flutter Android 应用
│   ├── lib/                 # 应用源代码
│   ├── android/             # Android 平台配置
│   └── assets/              # 资源文件
│
├── PalmControllerServer/    # .NET Windows 服务器
│   ├── Services/            # 服务层
│   ├── Models/              # 数据模型
│   └── Utils/               # 工具类
│
└── androidwin.code-workspace # VS Code 工作区配置
```

## 🚀 快速开始

### Android 应用端

1. **环境准备**
   ```bash
   # 确保已安装 Flutter SDK
   flutter doctor
   ```

2. **安装依赖**
   ```bash
   cd palm_controller_app
   flutter pub get --verbose
   ```

3. **运行应用**
   ```bash
   flutter run
   ```

### Windows 服务器端

1. **环境准备**
   - 确保已安装 .NET 9.0 SDK
   - Visual Studio 2022 或 VS Code

2. **构建运行**
   ```bash
   cd PalmControllerServer
   dotnet restore
   dotnet build
   dotnet run
   ```

## 🛠️ 开发环境

- **Flutter**: 移动端开发框架
- **.NET 9.0**: 桌面端开发框架
- **VS Code**: 推荐开发环境（支持工作区配置）

## 📱 支持平台

- **移动端**: Android 6.0+
- **桌面端**: Windows 10+

## 🤝 贡献指南

1. Fork 项目
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 打开 Pull Request

## 📄 许可证

此项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。 