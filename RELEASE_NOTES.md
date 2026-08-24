TAG=v1.6.1
TITLE=JA ADB Tool v1.6.1
BODY=
## Highlights

- Added Wireless ADB, Diagnostics Center, and persistent Device Workspaces.
- Added `Ctrl+K` Command Palette, App Manager batch actions, and reusable Scrcpy Profiles.
- Added Safe Sync Pause/Resume while retaining preview diff and typed destructive confirmation.
- Added schema-validated JSON Backup/Restore, GitHub Releases update checking, and a safe plugin manifest registry.
- Unified modal glassmorphism with Advanced Settings blur/opacity controls and fixed Folder Sync panel overflow on compact windows.
- Added multi-select APK/XAPK installation with a removable queue and sequential per-package progress logging.
- Reworked the App Installer into a responsive two-column desktop layout with content-sized queues and an expanding log panel.
- Improved light-theme log contrast and immediate per-package feedback; success detection now follows ADB exit codes.
- Synchronized About, README, User Guide, in-app copy, version metadata, and release packaging for v1.6.1.

## Verification

- `dart analyze --no-fatal-warnings` completed without errors or warnings introduced by this release.
- `flutter test --no-pub` passed all 8 tests.
- `flutter build windows --debug` completed successfully.
- `build.bat` completed the Windows release build and created a parent-folder ZIP; runtime `config.json` and `logs/` were excluded.
