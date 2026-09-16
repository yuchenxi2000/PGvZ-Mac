# PlantGirlsVsZombies macOS Build Toolkit

English | [简体中文](README.md)

## Overview

This repository rebuilds the Windows release of *PlantGirlsVsZombies* as a native Apple Silicon macOS app. It accepts either the Windows self-extracting installer or an existing game installation and provides a native app experience with improved runtime performance and energy efficiency.

The port retains the original .NET 6 runtime model, IronPython mod interface, and RuntimeDetour hooks. It runs with native macOS builds of MonoGame, SDL, and OpenAL, without requiring Wine or CrossOver.

This repository does not contain decompiled game source, original assemblies, game assets, the IronPython standard library, or a runnable game app. Obtain the Windows release from [the developer's Bilibili account](https://space.bilibili.com/3493090151107069).

## Building

### Recommended: use a capable coding agent

The fastest approach is to ask a coding agent with local terminal access, file access, and support for long-running tasks to read [BUILDING.md](BUILDING.md). The agent can inspect the environment, extract the game, build it, diagnose failures, and run the required verification without making you debug every step manually.

After cloning this repository, open it with the agent. Give the agent the absolute path to either the Windows self-extracting installer or an installed game directory, then send a task such as:

```text
Read this repository's BUILDING.md completely and follow it to build the native macOS app
from scratch.

Game input: /absolute/path/to/installer.exe

If the input is a self-extracting installer, extract it directly with 7-Zip; do not run the
Windows installer. If it is an installed game directory, use it directly. Independently
check prerequisites, identify the game version, decompile it, apply or adapt the port,
package and sign the app, and run every documented check and smoke test. Do not add game
files, decompiled source, or build output to Git. Unless my authorization or input is truly
required, keep diagnosing errors until the build is complete. Finally report the app path,
game version, test results, and any remaining warnings.
```

Replace the input path with the installed directory when applicable. An unknown game hash is still extracted and decompiled, then the most recently registered patch is tried by default. If it does not apply cleanly, the agent should create a separate patch for the new build and record its hash-to-patch mapping after compilation and smoke tests pass.

### Manual build

Install the Xcode Command Line Tools on an Apple Silicon Mac:

```sh
xcode-select --install
```

Clone the repository. A Windows self-extracting installer can be unpacked directly with 7-Zip, without running it under Windows, Wine, or CrossOver:

```sh
git clone <repository-url> PGvZ-Mac
cd PGvZ-Mac

mkdir -p "$PWD/local/PlantGirlsVsZombies"
7z x "/path/to/PlantGirlsVsZombies-installer.exe" \
  "-o$PWD/local/PlantGirlsVsZombies"

./scripts/rebuild-macos-app.sh "$PWD/local/PlantGirlsVsZombies"
```

The 7-Zip executable may be named `7zz`. If the game is already installed under Windows or CrossOver, pass that installation directory directly to `rebuild-macos-app.sh` instead.

The input directory must contain at least:

```text
PlantGirlsVsZombies/
├── Lawn.exe
├── Content/
└── lib/
```

Extra NSIS files such as `$PLUGINSDIR/`, PDB files, and native Windows DLLs do not affect the build. The scripts install pinned local copies of the .NET SDK and ILSpy, extract and decompile the managed game, apply the macOS compatibility patch, restore dependencies, publish for Apple Silicon, package the app, and apply an ad-hoc signature.

Successful output:

```text
dist/PlantGirlsVsZombies.app
```

See [BUILDING.md](BUILDING.md) for prerequisites, detailed stages, save migration, verification, and troubleshooting.

## Tested versions

See [`supported-game-builds.tsv`](supported-game-builds.tsv) for the recognized and tested game builds.

Tested platform and toolchain:

- Apple Silicon, `osx-arm64`
- macOS 26.5.2 and 26.6.2
- .NET SDK 6.0.428 / Runtime 6.0.36
- ILSpyCmd 8.2.0.7535
- IronPython 3.4.0 from the local game installation
- MonoMod.RuntimeDetour 25.3.6
- JIT enabled; AOT, trimming, and ReadyToRun disabled

## Runtime data

The packaged app contains the .NET runtime, game assets, and IronPython standard library. Writable files are stored outside the app bundle at:

```text
~/Library/Application Support/ZBC/PlantGirlsVsZombies/
```

Saves, user configuration, and Python mods therefore survive app updates and relocation. IronPython automatically adds the bundled standard library and the external `mods/` directory to its search path; mods do not need to configure the standard-library path manually.

## Verification

Run the complete packaged-app smoke test after building:

```sh
./tests/smoke-app.sh
```

It covers game startup, the title screen, IronPython execution, the WebSocket command channel, a real RuntimeDetour hook, IMEHelper initialization, and clean shutdown.

Before publishing changes to the repository, run:

```sh
git add -A
./scripts/check-release.sh
```

This check prevents decompiled source, proprietary game binaries and assets, build output, and machine-specific paths from being committed accidentally.

## Copyright notice

This is an unofficial compatibility-build project. It is not affiliated with, authorized by, or endorsed by the original game's authors, publishers, or other rights holders.

The repository distributes only porting patches, compatibility code, build scripts, tests, and documentation. It does not distribute original game code, assets, or runnable builds. Users must obtain the Windows version lawfully and determine whether decompilation, modification, and local building comply with applicable law and the original software license.

Because a packaged `.app` contains original game code and assets, publishing a prebuilt app through GitHub Releases is not recommended. Publish this build toolkit instead.

## Credits

GPT-5.6 Sol contributed to this project.
