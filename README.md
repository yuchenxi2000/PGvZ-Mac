# PlantGirlsVsZombies macOS 构建工具

[English](README.en.md) | 简体中文

## 项目说明

本仓库用于从 Windows 版《植物娘大战僵尸》自解压安装包或安装目录，重建并打包 Apple Silicon 原生 macOS App，获得原生 App 体验和运行速度、能效提升。

它保留游戏原有的 .NET 6、IronPython 模组接口和 RuntimeDetour 动态 Hook 能力，并以 macOS 原生 MonoGame、SDL 和 OpenAL 运行，不需要 Wine 或 CrossOver。

仓库不包含游戏反编译源码、原始程序集、游戏资源、IronPython 标准库或可运行的游戏 App。使用者请前往 [庄特纯的 BiliBili 账号](https://space.bilibili.com/3493090151107069) 下载 Windows 版游戏。

## 构建方法

### 推荐：交给智能体构建

最快的方法是让具备本地终端、文件读写和长任务执行能力的编程智能体读取 [BUILDING.md](BUILDING.md)，由它检查环境、提取游戏、构建、排查错误并完成验证。这样通常不需要用户手动执行和调试每一步。

克隆仓库后，在仓库根目录向智能体提供 Windows 自解压安装包或已安装游戏目录的绝对路径，并发送类似以下任务：

```text
请完整阅读本仓库的 BUILDING.md，并严格按照文档从头构建原生 macOS App。

游戏输入：/absolute/path/to/installer.exe

如果输入是自解压安装包，请直接用 7-Zip 提取，不要运行 Windows 安装器；如果是
安装目录则直接使用。请自主检查依赖、识别游戏版本、完成反编译、应用或适配补丁、
打包和签名，并运行文档规定的全部检查与冒烟测试。不要把游戏文件、反编译源码或
构建成品加入 Git。除非确实需要我的授权或输入，否则请持续处理错误直到完成，最后
告诉我 App 的路径、游戏版本、测试结果和仍存在的警告。
```

如果传入的是安装目录，把提示中的路径改为该目录即可。未知游戏哈希会继续提取和反编译，并默认尝试清单中最后登记的最新补丁；若不能完整应用，智能体应为新构建创建独立补丁，并在编译和冒烟测试通过后登记哈希与补丁映射。

### 手动构建

希望自行执行时，先在 Apple Silicon Mac 上安装 Xcode Command Line Tools：

```sh
xcode-select --install
```

克隆仓库。如果取得的是 Windows 自解压安装包，可直接用 7-Zip 解压，不必在 Windows、Wine 或 CrossOver 中运行安装器：

```sh
git clone <repository-url> PGvZ-Mac
cd PGvZ-Mac

mkdir -p "$PWD/local/PlantGirlsVsZombies"
7z x "/path/to/PlantGirlsVsZombies-installer.exe" \
  "-o$PWD/local/PlantGirlsVsZombies"

./scripts/rebuild-macos-app.sh "$PWD/local/PlantGirlsVsZombies"
```

命令名也可能是 `7zz`。如果已经在 Windows 或 CrossOver 中安装，则可直接把安装完成后的游戏目录传给 `rebuild-macos-app.sh`，无需再次提取。

输入目录至少需要包含：

```text
PlantGirlsVsZombies/
├── Lawn.exe
├── Content/
└── lib/
```

7-Zip 解出的 `$PLUGINSDIR/`、PDB 和 Windows 原生 DLL 不影响构建，脚本只使用所需文件。随后脚本会自动安装仓库本地的固定版本 .NET SDK 和 ILSpy，并完成程序集提取、反编译、应用 macOS 补丁、依赖还原、Apple Silicon 发布、App 打包和 ad-hoc 签名。

成功输出：

```text
dist/PlantGirlsVsZombies.app
```

详细环境要求、分步构建、存档迁移、验证方法和故障排查见 [BUILDING.md](BUILDING.md)。

## 已测试版本

支持的游戏版本见 [`supported-game-builds.tsv`](supported-game-builds.tsv) 。

已测试平台：

- 目标架构：Apple Silicon，`osx-arm64`
- 已验证系统：macOS 26.5.2、26.6.2
- .NET SDK 6.0.428 / Runtime 6.0.36
- ILSpyCmd 8.2.0.7535
- IronPython 3.4.0（来自本地游戏安装）
- MonoMod.RuntimeDetour 25.3.6
- JIT；禁用 AOT、裁剪和 ReadyToRun

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
