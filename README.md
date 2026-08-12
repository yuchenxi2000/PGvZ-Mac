# PlantGirlsVsZombies macOS 构建工具

## 项目说明

本仓库用于从用户自行取得的 Windows 版《植物娘大战僵尸》安装目录，重建并打包 Apple Silicon 原生 macOS App。

它保留游戏原有的 .NET 6、IronPython 模组接口和 RuntimeDetour 动态 Hook 能力，并以 macOS 原生 MonoGame、SDL 和 OpenAL 运行，不需要 Wine 或 CrossOver。

仓库不包含游戏反编译源码、原始程序集、游戏资源、IronPython 标准库或可运行的游戏 App。使用者请前往 [庄特纯的 BiliBili 账号](https://space.bilibili.com/3493090151107069) 下载 Windows 版游戏。

## 构建方法

在 Apple Silicon Mac 上安装 Xcode Command Line Tools：

```sh
xcode-select --install
```

克隆仓库，然后把 Windows 安装目录传给一键构建脚本：

```sh
git clone <repository-url> PGvZ-Mac
cd PGvZ-Mac

./scripts/rebuild-macos-app.sh "/path/to/PlantGirlsVsZombies"
```

输入目录至少需要包含：

```text
PlantGirlsVsZombies/
├── Lawn.exe
├── Content/
└── lib/
```

脚本会自动安装仓库本地的固定版本 .NET SDK 和 ILSpy，随后完成提取、反编译、应用 macOS 补丁、依赖还原、Apple Silicon 发布、App 打包和 ad-hoc 签名。

成功输出：

```text
dist/PlantGirlsVsZombies.app
```

详细环境要求、分步构建、存档迁移、验证方法和故障排查见 [BUILDING.md](BUILDING.md)。

## 已测试版本

- 游戏版本：1.2.2
- `Lawn.exe` 大小：77,074,673 bytes
- `Lawn.exe` SHA-256：`f23085f08ccaabb9019356a4316660806b487620b3d55c65e73e4af9b1514c41`
- 目标架构：Apple Silicon，`osx-arm64`
- 已验证系统：macOS 26.5.2
- .NET SDK 6.0.428 / Runtime 6.0.36
- ILSpyCmd 8.2.0.7535
- IronPython 3.4.0（来自本地游戏安装）
- MonoMod.RuntimeDetour 25.3.6
- JIT；禁用 AOT、裁剪和 ReadyToRun

源码补丁与指定的 `Lawn.exe` 和 ILSpy 输出相关。其他游戏版本、Intel Mac 和较早的 macOS 版本尚未验证，不应绕过哈希检查强行应用补丁。

## 运行数据

打包后的 App 自带 .NET runtime、游戏资源和 IronPython 标准库。可写数据不会放进 App bundle，而是存储在：

```text
~/Library/Application Support/ZBC/PlantGirlsVsZombies/
```

存档、用户配置和 Python 模组因此可以在 App 更新或移动后继续保留。IronPython 会自动加入内置标准库和外部 `mods/` 目录，无需模组手动配置标准库路径。

## 验证

构建后可以运行完整冒烟测试：

```sh
./tests/smoke-app.sh
```

测试覆盖游戏启动、标题界面、IronPython 执行、WebSocket 命令通道、RuntimeDetour Hook 和正常退出。

准备发布仓库前运行：

```sh
git add -A
./scripts/check-release.sh
```

该检查用于防止反编译源码、游戏二进制、资源、构建产物和本机路径被误提交。

## 版权声明

这是一个非官方的兼容性构建项目，与原游戏作者、发行者及相关权利人无隶属、授权或背书关系。

本仓库只分发移植补丁、兼容代码、构建脚本、测试和文档，不分发原游戏代码、资源或可运行成品。使用者应自行合法取得 Windows 版游戏，并自行确认反编译、修改和本地构建行为符合其所在地法律及原软件许可。

由于打包后的 `.app` 包含原游戏代码和资源，不建议将预构建 App 上传到 GitHub Releases；推荐只发布本仓库中的构建工具。

## 致谢

感谢 GPT 5.6 Sol 在项目中的贡献。
