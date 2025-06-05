# 🤝 贡献指南

感谢您对 PalmController 项目的关注！我们非常欢迎各种形式的贡献。

## 🌟 贡献方式

### 🐛 报告 Bug
- 使用 [Issue 模板](https://github.com/Mutx163/androidwin/issues/new?template=bug_report.md)
- 提供详细的复现步骤
- 包含系统环境信息

### ✨ 功能建议
- 使用 [功能请求模板](https://github.com/Mutx163/androidwin/issues/new?template=feature_request.md)
- 描述用例和期望的行为
- 说明为什么这个功能有用

### 💻 代码贡献
- Fork 仓库
- 创建功能分支
- 提交 Pull Request

## 🔧 开发环境配置

### Android 端开发
```bash
# 确保安装了 Flutter SDK 3.24+
flutter doctor

# 安装依赖
cd palm_controller_app
flutter pub get

# 运行应用
flutter run
```

### Windows 端开发
```bash
# 确保安装了 .NET 9.0 SDK
dotnet --version

# 构建项目
cd PalmControllerServer
dotnet restore
dotnet build
dotnet run
```

## 📝 代码规范

### Flutter/Dart
- 使用 `dart format` 格式化代码
- 遵循 [Effective Dart](https://dart.dev/guides/language/effective-dart) 指南
- 运行 `flutter analyze` 确保无警告

### C#/.NET
- 使用 Visual Studio 默认格式化设置
- 遵循 [C# 编码规范](https://docs.microsoft.com/en-us/dotnet/csharp/fundamentals/coding-style/coding-conventions)
- 确保编译无警告

## 🧪 测试要求

### Flutter 测试
```bash
# 运行所有测试
flutter test

# 运行集成测试
flutter test integration_test/
```

### .NET 测试
```bash
# 运行单元测试
dotnet test
```

## 📋 Pull Request 流程

1. **Fork 项目** 到你的 GitHub 账户
2. **创建分支** from `master`：
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. **编写代码** 并确保测试通过
4. **提交代码**：
   ```bash
   git commit -m "✨ feat: add amazing feature"
   ```
5. **推送分支**：
   ```bash
   git push origin feature/your-feature-name
   ```
6. **创建 Pull Request** 到 `master` 分支

## 📖 提交信息规范

使用 [Conventional Commits](https://conventionalcommits.org/) 格式：

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### 类型
- `feat`: 新功能
- `fix`: Bug 修复
- `docs`: 文档更新
- `style`: 代码格式（不影响代码运行的变动）
- `refactor`: 重构代码
- `test`: 添加测试
- `chore`: 构建过程或辅助工具的变动

### 示例
```
feat(android): add gesture sensitivity settings
fix(server): resolve connection timeout issue
docs: update README installation guide
```

## 🎯 开发重点

### 当前优先级
1. **性能优化** - 减少延迟，提升响应速度
2. **用户体验** - 改进界面交互和错误处理
3. **功能完善** - 添加新的控制功能
4. **文档完善** - 提升文档质量和覆盖度

### 技术债务
- [ ] 添加更多单元测试
- [ ] 改进错误处理机制
- [ ] 优化网络协议
- [ ] 添加日志系统

## 🚫 注意事项

### 请勿
- 直接推送到 `master` 分支
- 提交包含敏感信息的代码
- 忽略代码格式化要求
- 提交未经测试的代码

### 建议
- 保持提交粒度适中
- 编写清晰的提交信息
- 添加必要的测试用例
- 更新相关文档

## 📞 获取帮助

如果在贡献过程中遇到问题：

- 📧 **邮件**: [发送邮件](mailto:your-email@example.com)
- 💬 **讨论区**: [GitHub Discussions](https://github.com/Mutx163/androidwin/discussions)
- 🐛 **Issue**: [创建问题](https://github.com/Mutx163/androidwin/issues/new)

## 🏆 贡献者权益

### 认可
- 你的名字将出现在贡献者列表中
- 重要贡献会在 Release Notes 中特别感谢

### 权限
- 活跃贡献者可获得 Collaborator 权限
- 可参与项目重要决策讨论

---

**感谢你为 PalmController 项目做出的贡献！** 🎉 