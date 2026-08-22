# 📜 CHANGELOG - JA ADB Tool

All notable changes to **JA ADB Tool** will be documented in this file.

---

## [v1.5.0] - 2026-08-22

### 🚀 Major Features & Enhancements
- **📡 Device connectivity:** Added Wireless ADB endpoints, Diagnostics Center checks, and persistent Device Workspaces for paths, endpoints, and sync folders.
- **🧰 Productivity:** Added a `Ctrl+K` Command Palette and reusable Scrcpy Profiles.
- **📦 App Manager:** Added multi-select batch freeze, unfreeze, force-stop, and uninstall actions with per-package results.
- **🛡️ Safe Sync v3:** Added Pause/Resume controls while preserving the preview and typed destructive confirmation gate.
- **💾 Settings portability:** Added schema-validated JSON Backup/Restore for safe paths, UI, sync, profiles, and workspaces.
- **🔄 Release tooling:** Added a GitHub Releases update checker and a safe plugin manifest registry that never executes manifest entry points.

### 🧪 Verification
- Added service round-trip coverage for Scrcpy profiles, settings backups, and plugin descriptors.
- Windows debug build and the full Flutter test suite pass; existing dependency plugin warnings remain documented.

### 🐛 Bug Fixes
- **🪟 Glass dialog consistency:** Wireless ADB, Diagnostics, Device Workspaces, and other modal surfaces now reuse the Advanced Settings blur/opacity values with the shared legibility floor.
- **📐 Folder Sync layout:** The left configuration panel now scrolls independently and caps the history area, preventing `BOTTOM OVERFLOWED` on compact Windows windows.

---

## [v1.4.3] - 2026-08-22

### ✨ User Experience
- **📱 Illustrated ADB onboarding:** Replaced the empty no-device state with four clear USB Debugging steps, a refresh action, and neutral Android-style illustrations that open in a zoomable preview.
- **🌐 Persistent app language:** The selected English, Vietnamese, or Chinese locale is saved across launches, with a portable `config.json` path and an AppData fallback for read-only installs.

### 🔧 Release Preparation
- **📦 Documentation sync:** Updated the About card, README, User Guide, in-app About copy, and release packaging metadata for v1.4.3.

---

## [v1.4.2] - 2026-08-22

### 🎨 UI Improvements
- **🗂️ Safer Tool Paths:** Grouped ADB, Scrcpy, and Gnirehtet path fields under a collapsed-by-default section in Advanced Settings to reduce accidental edits.
- **🌐 Localized guidance:** Added English, Vietnamese, and Chinese labels explaining when to expand Tool Paths.

---

## [v1.4.1] - 2026-08-22

### 🐛 Bug Fixes
- **🪟 Windows theme synchronization:** Flutter now starts from the Windows system Light/Dark preference and updates when the system brightness changes.
- **⚡ Settings tab responsiveness:** Advanced Settings, About, and User Guide content now switches immediately when a tab is selected instead of waiting for the tab animation to finish.

### 🔧 Chores
- Updated the Windows packaging script to preserve the previous `dist/` as a timestamped backup and avoid losing a working artifact when a build fails.

---

## [v1.4.0] - 2026-08-18

### 🚀 Major Features & Enhancements
- **🛡️ Safe Sync v2:** Added a preview-first workflow showing copy, update, and delete actions before execution.
  - Mirror Sync now requires the typed confirmation `DELETE` before destructive actions run.
  - The execution phase rechecks the preview and aborts if the folder contents changed.
  - Auto-sync cannot bypass the destructive confirmation flow.
- **📦 Safer APK/XAPK installation:** Validates archive size, entry count, paths, symlinks, and extraction boundaries before opening or extracting an XAPK.
- **🔗 In-app project links:** About now links to the JA website and source repository, with the current version shown from the shared app constant.
- **⚙️ Settings refresh:** Added About and User Guide entry points to Settings, plus a Glassmorphism section with live preview, blur/opacity sliders, typed Save/Cancel behavior, and factory defaults.
- **🧭 Advanced Settings navigation:** Renamed the path dialog to Advanced Settings, removed the duplicate sidebar About shortcut, and moved About/User Guide into in-dialog tabs.
- **🐞 Portable debug mode:** Added `debug.bat`, build-time metadata, a `DEBUG · v...` badge, and full ISO-8601 diagnostic timestamps without changing normal release runs.
- **🎨 UI polish:** Constrained the debug badge to the sidebar layout and aligned popup-menu surfaces with the app theme.

### 🐛 Bug Fixes
- Folder scan failures are now reported instead of being treated as empty folders, preventing accidental mirror deletions.
- Sync completion now reports failed copy/delete actions instead of claiming success.
- Fixed the stale file-selection lookup used by the file explorer deletion flow.

### 🔧 Chores
- Added release documentation: `ABOUT.txt`, `USERGUIDE.md`, `CHANGELOG.md`, and `LICENSE`.
- Updated Windows packaging to clean release output and exclude runtime configuration/logs from the archive.
- Added regression coverage for safe XAPK archive paths.

---

## [v1.3.0]

- Previous development baseline before the Safe Sync v2 and XAPK hardening release.
