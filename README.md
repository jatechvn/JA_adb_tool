<div align="center">

  # 📱 JA ADB Tool

  ### *A focused Windows desktop toolkit for managing Android devices with ADB*

  [![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
  [![Dart](https://img.shields.io/badge/Dart-3.12.2-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
  [![Platform](https://img.shields.io/badge/Platform-Windows_10_%7C_11-0078D4?style=for-the-badge&logo=windows&logoColor=white)](https://www.microsoft.com/windows)
  [![Release](https://img.shields.io/badge/Release-v1.4.0-00ADB5?style=for-the-badge&logo=github&logoColor=white)](https://github.com/jatechvn/JA_adb_tool/releases)
  [![License](https://img.shields.io/badge/License-MIT-FFB100?style=for-the-badge)](LICENSE)

  <p align="center"><b>Connect • Mirror • Explore • Sync safely • Install • Troubleshoot</b></p>

  <p align="center">🇺🇸 English</p>

</div>

## 📑 Table of Contents

- [✨ Core Capabilities](#-core-capabilities)
- [🛡️ Safe Sync v2](#️-safe-sync-v2)
- [📐 Directory & Technical Architecture](#-directory--technical-architecture)
- [🚀 Quick Start Guide](#-quick-start-guide)
- [⚙️ Configuration & Settings](#️-configuration--settings)
- [📖 User Guide](#-user-guide)
- [📜 Changelog](#-changelog)
- [📄 License & Author](#-license--author)

## ✨ Core Capabilities

### 🔌 Device Connection & ADB

- **Device discovery:** Lists connected Android devices and refreshes their status.
- **ADB command bridge:** Runs device actions through the configured ADB executable.
- **Quick tools:** Send text, simulate hardware keys, reboot, capture screenshots, and open Android settings.

### 🖥️ Screen Mirror

- **Scrcpy integration:** Mirror and control an Android device from the desktop.
- **Profiles:** Configure fullscreen, borderless, stay-awake, audio, and read-only options.
- **Bundled runtime:** The portable Windows build can ship with the required Scrcpy sidecar files.

### 📁 File Explorer & Media

- **Remote browsing:** Navigate Android storage and inspect files and folders.
- **Batch operations:** Upload, download, create folders, and delete selected items.
- **Transfer feedback:** Shows operation progress and transfer speed where available.
- **Latest media:** Quickly review and save recent photos and videos.

### 📦 App Installer

- **APK/XAPK support:** Install standard APK files and split packages packaged as XAPK.
- **Archive validation:** Rejects unsafe paths, symlinks, excessive entry counts, and oversized archives before extraction.

### 🌐 Reverse Tethering

- **Gnirehtet integration:** Share the PC's Internet connection with an Android device over USB.
- **Path settings:** Configure ADB, Scrcpy, and Gnirehtet locations for portable or custom installations.

## 🛡️ Safe Sync v2

Folder Sync is preview-first when a destructive mirror is requested:

1. Select PC and Android folders and choose the sync direction.
2. Review the generated diff: files to copy, update, or delete are counted before execution.
3. When Mirror Sync has deletions, type `DELETE` exactly to confirm the displayed delete set.
4. The app rechecks both folders before executing. If the contents changed, it stops and requests a new preview.

Scan errors are surfaced as errors rather than silently becoming empty folders, and failed file actions are included in the final result. Auto-sync cannot bypass the typed confirmation gate.

## 📐 Directory & Technical Architecture

```text
JA_adb_tool/
├── assets/                         # Bundled application assets
├── bin/                            # ADB, Scrcpy, Gnirehtet, and native sidecars
├── lib/
│   ├── main.dart                   # Flutter entry point
│   └── modules/
│       ├── constants.dart          # App identity, version, and project links
│       ├── logic.dart              # Device, file, installer, and sync workflows
│       ├── native/                 # Platform-specific native bridges
│       └── ui/                     # Main window, dialogs, styles, and localization
├── test/                           # Widget and safety regression tests
├── windows/                        # Windows runner and native build files
├── ABOUT.txt                       # JA-HUB project information card
├── CHANGELOG.md                    # Permanent shipped version history
├── USERGUIDE.md                    # Extended end-user guide
├── build.bat                       # Windows release build and packaging workflow
├── config.json                     # Development/runtime command presets
└── pubspec.yaml                    # Flutter/Dart manifest
```

## 🚀 Quick Start Guide

### Option A: Portable Run

1. Download the latest `JA_adb_tool_v1.4.0_Windows_x64.zip` package from [GitHub Releases](https://github.com/jatechvn/JA_adb_tool/releases).
2. Extract it to a writable folder.
3. Connect an Android device with USB debugging enabled.
4. Launch `ja_adb_tool.exe`.

For a diagnostic run, launch `debug.bat`. It starts the same executable with `-debug`, prints full ISO timestamps to the console/log, and displays a `DEBUG · v1.4.0 (build time)` badge in the sidebar. Normal launches keep the badge hidden.

The release package is wrapped in a versioned parent folder and excludes local runtime `config.json` and log files.

### Option B: Build from Source

Prerequisites:

- Windows 10/11 x64
- Flutter SDK with Dart 3.12.2 support
- Visual Studio 2022 with Desktop development with C++
- Android USB driver and a device with USB debugging enabled

```bash
git clone https://github.com/jatechvn/JA_adb_tool.git
cd JA_adb_tool
flutter pub get
flutter run -d windows
flutter build windows --release
```

For a packaged Windows release, run `build.bat` from the project root. It reads the version from `pubspec.yaml`, cleans stale output, removes runtime secrets/logs, copies `debug.bat`, and creates a parent-folder ZIP in `dist/`. The `dist/` folder itself remains flat; the parent folder exists only inside the ZIP.

## ⚙️ Configuration & Settings

The app loads `config.json` beside the executable in a portable release, falling back to the current working directory during development. The starter file contains command presets:

```json
{
  "predefined_inputs": [
    { "label": "Open Settings", "value": "am start -a android.settings.SETTINGS" },
    { "label": "List 3rd Party Packages", "value": "pm list packages -3" },
    { "label": "Check Battery Status", "value": "dumpsys battery" },
    { "label": "Simulate Back Key", "value": "input keyevent 4" },
    { "label": "Show Device Info", "value": "getprop ro.product.model" }
  ]
}
```

Device-specific Folder Sync history and preferences are persisted separately by the app. Glassmorphism values (`bg_blur`, `bg_opacity`, `dialog_blur`, and `dialog_opacity`) are saved only when Settings is saved. Do not commit a runtime `config.json` containing private paths or credentials.

## 📖 User Guide

The in-app Settings dialog is organized into three top-level tabs in this order: **Advanced Settings**, **About**, and **User Guide**. The guide covers connection, mirroring, file operations, Safe Sync v2, installation, media, reverse tethering, quick tools, path settings, and Glassmorphism. The expanded step-by-step reference is available in [USERGUIDE.md](USERGUIDE.md).

## 📜 Changelog

See [CHANGELOG.md](CHANGELOG.md) for the full history.

- **v1.4.0 (2026-08-18):** Safe Sync v2 diff preview and typed `DELETE` confirmation, XAPK archive hardening, debug diagnostics, safer scan/error handling, in-app project links, UI overflow fixes, and release packaging cleanup.
- **v1.3.0:** Previous development baseline.

## 📄 License & Author

Distributed under the [MIT License](LICENSE).

- **Author/maintainer:** JA Team (`jatechvn`)
- **Project website:** [jatechvn.github.io](https://jatechvn.github.io/)
- **Repository:** [github.com/jatechvn/JA_adb_tool](https://github.com/jatechvn/JA_adb_tool)
