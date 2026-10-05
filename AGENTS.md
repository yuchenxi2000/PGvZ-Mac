# Project Guidelines

## Project Scope and Build Workflow

- This repository builds a native Apple Silicon macOS app from a Windows game installer or installation directory supplied by the user. Read `BUILDING.md` in full before building or adapting a game release, and prefer the existing workflows in `scripts/`.
- Extract NSIS installers with `7z x` or `7zz x`, preserving the directory structure. Do not execute the Windows installer.
- Use the repository's pinned .NET SDK, ILSpy, and dependency versions. Do not upgrade the toolchain or change game logic merely to silence warnings.

## Documentation and Version Information

- **Do not include specific version information in `BUILDING.md`.** This means specific game versions, version-specific patch filenames, game hashes, and adaptation notes for individual game releases. Record this information in `supported-game-builds.tsv`; keep the build guide generic and link to that manifest.
- `BUILDING.md` may retain version requirements for the toolchain, dependencies, and target operating system to keep builds reproducible. Do not add sections for individual game versions or use specific game versions as examples.
- `supported-game-builds.tsv` is the single manifest of verified game builds. Each tab-separated record contains the SHA-256 of `Lawn.exe`, the game version from assembly metadata, the file size, and the corresponding patch filename.
- Update relevant documentation when shared behavior or build workflows change. Keep shared information in the Chinese and English READMEs consistent. Do not include machine-specific absolute paths.

## Adapting New Releases and Maintaining Patches

- Determine the game version from extracted assembly metadata, rather than relying solely on the installer filename. An unknown hash may proceed through extraction and decompilation, but does not establish compatibility.
- Run `git apply --check` before applying a patch, and apply it only after confirming that the entire patch matches. Do not leave a partially patched source tree.
- If an existing patch does not match a new release, create a separate patch against the unmodified decompiled source. Preserve existing patches and mappings for older releases.
- Limit patches to decompilation fixes required for building and macOS compatibility changes. Put shared compatibility code in `porting/` and avoid unrelated gameplay changes.
- Preserve necessary original source and troubleshooting changes in ignored directories. Inspect and preserve an existing `src/Lawn/` before replacing it. Do not use unrestricted `git clean` commands.

## Runtime Requirements and Validation

- Preserve .NET JIT execution, complete metadata, the IronPython mod interface, and RuntimeDetour hooks. Disable AOT, trimming, and ReadyToRun.
- Keep only application files and read-only resources inside the app bundle. Store saves, configuration, and mods in the established user data directory. Do not overwrite or delete existing user data when updating, moving, or testing the app.
- Before registering a new release, compile and package it, check `Info.plist` and the arm64 architecture, verify the ad-hoc signature, and run both `tests/smoke-macos.sh` and `tests/smoke-app.sh`.
- Smoke tests must verify the title screen, IronPython, WebSocket, IMEHelper, and a real RuntimeDetour hook. Successful compilation does not replace hook execution testing. Repeat this validation after dependency upgrades.
- Run `tests/test-verify-game.sh` when changing input recognition logic. For documentation-only changes, review the diff and run the release tree check; rebuilding the game is unnecessary.
- Review test cleanup behavior and never overwrite an existing file with a test mod of the same name. Report completed checks, unverified areas, and warnings. Do not present passing smoke tests as verification of the full gameplay experience.

## Commit and Distribution Boundaries

- Commit only build scripts, minimal porting patches, compatibility code, repository-owned packaging assets, configuration, tests, and documentation.
- Do not commit game installers, extracted assemblies, decompiled source, game assets, build outputs, tool caches, or user saves. Keep these files in directories excluded by `.gitignore`.
- Do not upload prebuilt apps containing game code and assets to GitHub Releases.
- After making changes, run `git diff --check` and `scripts/check-release.sh`. Review `git status` and the intended commit contents to ensure generated files and machine-specific paths are excluded.
