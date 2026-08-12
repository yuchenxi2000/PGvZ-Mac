# 从 Windows 安装目录构建原生 macOS App

本文档描述一条可复现的完整流程：输入 Windows 安装完成后 `Program Files` 中的游戏目录，提取单文件 .NET 程序、反编译托管程序集、应用 macOS 兼容补丁、还原依赖，并生成一个自包含的 Apple Silicon `.app`。

文档假定执行者只拥有本仓库和一份合法取得的 Windows 游戏安装，不依赖仓库作者电脑上的任何绝对路径。人类开发者或自动化智能体均可按顺序执行。

## 1. 分发与版权边界

可以提交到 GitHub 的内容包括：

- `scripts/` 中的提取、移植、构建和打包脚本；
- `patches/macos-port.patch` 中用于互操作的最小源码差异；
- `porting/DynamicHookGenCompat.cs` 兼容层；
- `packaging/` 中的 Info.plist 和重新设计的 macOS 图标；
- `config.macos.json`、测试和本文档。

不要提交或放入 GitHub Release：

- `Lawn.exe` 或从中提取的 DLL；
- ILSpy 生成的 `src/Lawn/` 反编译源码树；
- `Content/`、`lib/`、原始图标或其他游戏资源；
- `artifacts/`、`dist/PlantGirlsVsZombies.app` 或任何可直接运行的构建结果；
- 用户存档、配置、模组或 CrossOver bottle。

这些路径和常见二进制扩展名已经写入 `.gitignore`。发布前仍应执行本文末尾的版权安全检查。

## 2. 已验证的输入和目标

本补丁是版本相关的。目前唯一经过验证的输入是：

```text
游戏显示版本: 1.2.2
文件: Lawn.exe
大小: 77,074,673 bytes
SHA-256: f23085f08ccaabb9019356a4316660806b487620b3d55c65e73e4af9b1514c41
```

目标环境：

```text
CPU: Apple Silicon
Runtime Identifier: osx-arm64
Target Framework: net6.0
.NET SDK: 6.0.428
.NET Runtime: 6.0.36
ILSpyCmd: 8.2.0.7535
```

已在 macOS 26.5.2 上验证。Info.plist 的最低系统版本目前为 macOS 11.0，但尚未逐个验证所有较早版本。Intel `osx-x64` 也未验证。

不要绕过输入校验把补丁强行应用到其他游戏版本。新版的程序集布局、ILSpy 输出或源码位置发生变化时，应重新审查并更新补丁。

## 3. 准备 Windows 游戏安装目录

在 Windows 上安装游戏后，取得整个目录，而不是只复制 `Lawn.exe`。默认位置通常是：

```text
C:\Program Files\ZBC\PlantGirlsVsZombies\
```

传到 Mac 后至少应存在：

```text
PlantGirlsVsZombies/
├── Lawn.exe
├── Content/
└── lib/
```

`Lawn.exe` 是 .NET 6 单文件包，包含构建所需的托管程序集；`Content/` 是游戏资源；`lib/` 是游戏所带的 IronPython 标准库。打包脚本只读取这个目录，不会修改它。

如果游戏已经安装在 CrossOver 中，可以直接使用类似以下路径，无需复制：

```text
~/Library/Application Support/CrossOver/Bottles/<Bottle>/drive_c/Program Files/ZBC/PlantGirlsVsZombies
```

路径可以包含空格，但调用脚本时必须用引号包住。

## 4. macOS 构建机要求

需要：

- Apple Silicon Mac；
- Git、`curl`、`sh`、Perl 和 `shasum`；
- Xcode Command Line Tools 提供的 `codesign`、`plutil`、`sips`、`xattr` 和基础构建支持；
- 首次安装工具和 NuGet 还原时可访问互联网；
- 建议至少预留 4 GB 空间。

检查 Command Line Tools：

```sh
xcode-select -p
```

如果命令失败，安装它：

```sh
xcode-select --install
```

不需要系统全局安装 .NET。`scripts/bootstrap-tools.sh` 会把固定版本的 SDK 和 ILSpy 安装到被忽略的 `.tools/`。

## 5. 从全新克隆一条命令构建

克隆仓库并进入根目录：

```sh
git clone <repository-url> PGvZ-Mac
cd PGvZ-Mac
```

指定 Windows 游戏目录：

```sh
export PGVZ_GAME_DIR="/absolute/path/to/PlantGirlsVsZombies"
```

执行完整流水线：

```sh
./scripts/rebuild-macos-app.sh "$PGVZ_GAME_DIR"
```

脚本依次完成：

1. 安装并验证 .NET SDK 6.0.428 与 ILSpyCmd 8.2.0.7535；
2. 校验 `Lawn.exe` 的 SHA-256，并检查 `Content/`、`lib/`；
3. 用 ILSpy 的 single-file bundle reader 提取程序集到 `artifacts/extracted/windows/`；
4. 将 `Lawn.dll` 反编译为 `src/Lawn/`；
5. 应用 `patches/macos-port.patch`，复制 `porting/DynamicHookGenCompat.cs`；
6. 从 NuGet 还原 macOS MonoGame、IMEHelper、Mono.Unix 和 RuntimeDetour；
7. 以 `osx-arm64`、self-contained、JIT 模式发布；
8. 复制本地游戏的 `Content/` 与 `lib/`，生成多分辨率图标，组成 App bundle；
9. 清除扩展属性并进行 ad-hoc 签名和签名验证。

成功输出：

```text
dist/PlantGirlsVsZombies.app
```

这个 App 自带 .NET 6 runtime、macOS SDL/OpenAL 库、游戏资源和 IronPython 标准库。运行时不再需要 CrossOver、Wine 或系统级 .NET。

## 6. 分步构建与故障定位

如需观察每一阶段，可不用一键脚本。

### 6.1 安装固定工具链

```sh
./scripts/bootstrap-tools.sh
```

工具只安装到：

```text
.tools/dotnet/
.tools/ilspy/
```

### 6.2 验证输入

```sh
./scripts/verify-game.sh "$PGVZ_GAME_DIR"
```

哈希不一致时会停止。此时先确认取得的是受支持版本，不能仅修改脚本里的哈希继续构建。

### 6.3 提取并反编译

```sh
./scripts/decompile-windows.sh "$PGVZ_GAME_DIR"
```

输出：

```text
artifacts/extracted/windows/   单文件包中提取的程序集
src/Lawn/                     ILSpy 生成的临时 C# 项目
```

脚本在 `src/Lawn/` 已存在时拒绝覆盖，以免丢失本地排查改动。从头重建时应在全新克隆中运行，或仅删除这几个明确的生成目录后重来：

```sh
rm -rf -- "$PWD/src/Lawn" "$PWD/artifacts" "$PWD/dist"
```

不要用无目标限制的 `git clean`，也不要删除仓库根目录。

### 6.4 应用移植层并还原依赖

```sh
./scripts/apply-macos-port.sh
```

移植层主要完成：

- 将 ILSpy 项目调整为 `net6.0`、`AnyCPU` 和命令行可执行输出；
- 用 `MonoGame.Framework.DesktopGL` 替换 Windows MonoGame 程序集；
- 使用跨平台 IMEHelper、Mono.Unix 与 RuntimeDetour 25.3.6；
- 为 IMEHelper 0.10.0 所硬编码的 `libSDL2-2.0.0.dylib` 创建兼容符号链接，指向 MonoGame 提供的同一份 `libSDL2.dylib`；
- 修正 ILSpy 8.2 对部分 `char switch` 和 dynamic event IL 的反编译结果；
- 在非 Windows 平台避开 `user32!SetTimer` 和 WindowsIdentity；
- macOS 构建把 `porting/NoWindowIcon.dat` 作为无效的 `Icon.bmp` 资源嵌入，使 MonoGame 跳过 `SDL_SetWindowIcon`，避免运行时覆盖 App 的 Dock 图标；
- 将只读 App 资源与可写用户数据分离；
- 把 IronPython 标准库和外部 `mods/` 加入搜索路径；
- 用 `DynamicHookGenCompat.cs` 保持游戏和 Python 模组原有的动态 Hook API。

`git apply --check` 会先确认补丁完全匹配，失败时不会留下半应用状态。

### 6.5 可选：未打包运行

```sh
./scripts/prepare-runtime.sh "$PGVZ_GAME_DIR"
./scripts/run-macos.sh
```

测试运行目录是 `artifacts/run/`。其中 `Content` 和 `lib` 是指向输入安装目录的符号链接，因此不会复制约 1 GB 资源。

### 6.6 打包

```sh
./scripts/package-app.sh "$PGVZ_GAME_DIR"
```

发布参数明确禁用了 AOT、裁剪和 ReadyToRun。IronPython、反射与 RuntimeDetour 都依赖完整元数据和 JIT，不应打开这些优化。

App 结构概要：

```text
PlantGirlsVsZombies.app/
└── Contents/
    ├── Info.plist
    ├── MacOS/                 自包含 .NET 发布结果
    └── Resources/
        ├── AppIcon.icns
        ├── config.json
        ├── Content/
        └── lib/
```

`AppIcon.icns` 使用仓库中的 `packaging/icon/AppIcon-Modern.png` 生成。源图为 1024×1024 不透明方形，让新版 macOS 自行应用圆角遮罩，避免旧透明图标出现灰色兼容底板。

## 7. 运行数据和 IronPython 路径

App bundle 始终视为只读。存档、设置和模组位于：

```text
~/Library/Application Support/ZBC/PlantGirlsVsZombies/
├── docs/userdata/
├── mods/
├── cust/mods/
├── IronPython/Libs -> <App>/Contents/Resources/lib
├── Content -> <App>/Contents/Resources/Content
└── user_config.json
```

启动时会自动创建数据目录，并在 App 被移动后修正两个资源符号链接。IronPython 同时把以下位置加入 `sys.path`：

```text
<App>/Contents/Resources/lib
~/Library/Application Support/ZBC/PlantGirlsVsZombies/mods
```

因此模组通常不再需要手动设置标准库路径。

如需从 CrossOver/Windows 用户目录迁移现有数据：

```sh
./scripts/migrate-user-data.sh \
  "/path/to/AppData/Roaming/ZBC/PlantGirlsVsZombies"
```

脚本不会覆盖目标端已存在的同名数据。

## 8. 验证构建

先验证 bundle 和签名：

```sh
plutil -lint dist/PlantGirlsVsZombies.app/Contents/Info.plist
codesign --verify --deep --strict --verbose=2 \
  dist/PlantGirlsVsZombies.app
file dist/PlantGirlsVsZombies.app/Contents/MacOS/Lawn
```

完整冒烟测试：

```sh
./tests/smoke-app.sh
```

测试会：

- 临时向用户 `cust/mods/` 放入一个测试模组；
- 启动游戏并等待本地 `ws://127.0.0.1:8080/Py`；
- 验证 IronPython 表达式 `40 + 2` 返回 `42`；
- 验证一个真实 RuntimeDetour Hook 被调用；
- 通过 WebSocket 请求游戏正常退出；
- 清理测试模组、标记文件和日志。

运行前请关闭其他游戏实例，并确认 8080 端口未被占用。测试不会删除已有同名模组；检测到冲突会直接停止。

构建日志中可能出现：

```text
MonoMod.Core and MonoMod.RuntimeDetour do not support osx-arm64
```

这是 NuGet 包目标框架元数据产生的警告。当前组合已在 Apple Silicon 上通过实际 Hook 测试；如果未来升级依赖，必须重新运行冒烟测试，不能只依据编译成功判断。

## 9. 安装和签名说明

本地安装可复制到个人 Applications 目录：

```sh
mkdir -p "$HOME/Applications"
ditto "dist/PlantGirlsVsZombies.app" \
  "$HOME/Applications/PlantGirlsVsZombies.app"
```

脚本使用 ad-hoc 签名，只适合本机开发和个人构建。若要让其他人直接下载运行，需要 Developer ID 签名和 Apple notarization；但这样分发的 App 同时包含游戏代码与资源，可能违反版权许可。因此本仓库的预期发布物是构建工具和文档，而不是预构建 App。

## 10. GitHub 发布前检查

查看将被提交的文件：

```sh
git status --short
git ls-files
```

暂存文件后，可先运行仓库自带检查：

```sh
./scripts/check-release.sh
```

确认专有目录均被忽略：

```sh
git check-ignore -v \
  src/Lawn/Lawn.csproj \
  artifacts/extracted/windows/Lawn.dll \
  dist/PlantGirlsVsZombies.app \
  local/PlantGirlsVsZombies/Lawn.exe
```

再检查没有误跟踪常见游戏二进制：

```sh
if git ls-files | grep -E '\.(exe|dll|pdb|dylib|ico|bmp)$'; then
  echo "Refusing release: tracked binary found" >&2
  exit 1
fi
```

预期可跟踪的核心树为：

```text
BUILDING.md
README.md
config.macos.json
global.json
packaging/
patches/
porting/
scripts/
tests/
```

## 11. 常见故障

### `Unsupported Lawn.exe build`

输入不是已验证的 1.2.2 单文件包。重新确认 Windows 安装版本和复制完整性。不要只更新预期哈希。

### `Refusing to overwrite existing source directory`

`src/Lawn/` 已存在。保留它用于排查，或者按 6.3 节仅删除明确的生成目录后从头执行。

### `The macOS patch does not match this decompiled source tree`

通常是游戏版本或 ILSpy 版本不一致。执行 `scripts/bootstrap-tools.sh` 和 `scripts/verify-game.sh`，确认使用文档固定版本。

### NuGet 还原失败

首次构建必须联网访问 NuGet。检查代理、证书和网络后重新执行 `scripts/apply-macos-port.sh`；已经应用的补丁会被识别，不会重复应用。

### 图标仍显示旧版本

Finder/Dock 可能保留缓存。确认 App 内部构建号和新图标已更新，再从 Dock 移除旧项目并重新拖入新 App；不要为刷新图标删除系统范围缓存。

### 游戏启动后找不到模组或标准库

检查用户数据目录下的 `IronPython/Libs`、`Content` 符号链接，以及 App 内 `Contents/Resources/lib` 和 `Content` 是否存在。移动 App 后重新启动会自动修正链接目标。

### 修改按键绑定时提示找不到 `libSDL2-2.0.0.dylib`

MonoGame 3.8.1 提供的库名是 `libSDL2.dylib`，而 IMEHelper 0.10.0 使用旧名称。重新运行打包脚本；它会在 `Contents/MacOS/` 创建 `libSDL2-2.0.0.dylib` 符号链接，并由冒烟测试实际初始化 IMEHelper 验证。
