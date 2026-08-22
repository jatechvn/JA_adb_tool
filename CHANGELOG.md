# 📜 CHANGELOG - JA ADB Tool

All notable changes to **JA ADB Tool** will be documented in this file.

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
