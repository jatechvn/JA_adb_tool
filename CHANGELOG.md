# 📜 CHANGELOG - JA ADB Tool

## [v1.8.1] - 2026-09-24

### 🐛 Sửa lỗi & Tối ưu hóa (Bug Fixes & Hardening)
- **🧬 Cải tiến công nghệ nhân bản APK (App Cloner AXML & Signing Hardening):**
  - **Attribute-aware AXML Patcher:** Vá nhị phân thông minh dựa trên ngữ cảnh thuộc tính XML, bảo toàn tuyệt đối namespace các lớp DEX, tự động mở rộng tên lớp tương đối (vd: `.MainActivity` ➔ `<pkg>.MainActivity`), thay thế chính xác nhãn `android:label` ứng dụng/activity mà không làm hỏng resource reference.
  - **Xử lý chữ ký v2 & Zipalign chuẩn mực:** Bổ sung `ApkSigner` tự động phát hiện `zipalign` và `apksigner` từ Android Build Tools, thực hiện căn chỉnh 4-byte và ký xác thực v2 với debug keystore. Báo lỗi rõ ràng và chuẩn xác nếu thiếu công cụ ký thay vì báo thành công ảo.
  - **Phân tách trạng thái:** Tách bạch thông báo đóng gói/ký APK thành công với kết quả nạp cài đặt vào máy.
- **🖥️ Tối ưu hiển thị giao diện & Chống tràn Layout (Layout Overflow Fixes):**
  - Thêm cơ chế co giãn linh hoạt (`Flexible`, `Expanded`) cho thanh Connected Device capsule ở độ phân giải 1280x800 và các cửa sổ hẹp.
  - Khắc phục triệt để lỗi tràn dòng trong bảng tùy chọn Scrcpy Options (`scrcpy_options`, `mirror_quality_preset`) trên tất cả các ngôn ngữ (EN, VI, ZH) và chế độ Sáng/Tối.
- **🧪 Mở rộng bộ kiểm thử hồi quy (Regression Test Suite):**
  - Bổ sung bộ kiểm thử `app_cloner_regression_test.dart` và `mirror_connected_layout_test.dart`, nâng tổng số test cases tự động lên 131 bài kiểm tra (100% pass).

### 📦 Phát hành & Đóng gói (Release & Distribution)
- Đồng bộ số phiên bản `v1.8.1+17` trên toàn bộ hệ thống (`pubspec.yaml`, `constants.dart`, `ABOUT.txt`, `README.md`, `USERGUIDE.md`, `CHANGELOG.md`, `RELEASE_NOTES.md`).
- Đóng gói chuẩn portable release vào thư mục `dist/` kèm file nén `JA_adb_tool_v1.8.1_Windows_x64.zip` và mã kiểm tra SHA256.
- Đồng bộ gói phát hành lên máy chủ cập nhật mạng nội bộ `\\10.81.141.226\temp\FBT\JA_PROJECT\JA_Update\JA_adb_tool`.

---

## [v1.8.0] - 2026-09-24

### 🚀 Nâng cấp & Tính năng mới (Major Features & Enhancements)
- **🧬 App Cloner Studio (Nhân bản ứng dụng chuyên sâu):**
  - **Standalone APK Cloning Engine (`AppClonerService`, `AxmlModifier`):**
    - Bộ phân tích và vá nhị phân AXML (`AndroidManifest.xml`) thuần Dart siêu tốc hỗ trợ cả mã hóa chuỗi UTF-8 lẫn UTF-16LE.
    - Tự động thay đổi Package Name và App Label mới.
    - Tự động quét và vá toàn bộ `android:authorities` của ContentProvider để loại bỏ triệt để lỗi cài đặt trùng lặp `INSTALL_FAILED_CONFLICTING_PROVIDER`.
    - Tách bỏ chữ ký cũ (`META-INF/MANIFEST.MF`, `*.SF`, `*.RSA`, `*.DSA`, `*.EC`) và đóng gói lại APK qua module `archive`.
    - Tự động tìm kiếm và ký số APK (`jarsigner` / `keytool` qua JDK hệ thống, tự sinh debug keystore nếu chưa có).
    - Hỗ trợ nhân bản trực tiếp từ ứng dụng đã cài đặt trên thiết bị (tự động pull APK) hoặc từ file APK/XAPK độc lập trên máy tính.
  - **👥 Multi-User Dual Space Cloning (Nhân bản không gian kép tức thì):**
    - Tận dụng Android Multi-User framework (`pm create-user`, `pm list users`, `pm install-existing`).
    - Quản lý hồ sơ người dùng Clone Space trực quan, tạo không gian mới trong 1 click, cài đặt/nhân bản app tức thì sang Dual Space mà không cần đóng gói lại APK, chạy ứng dụng độc lập trên profile (`am start --user <id>`) và xóa không gian an toàn.
  - **💎 Giao diện Bento Glassmorphic Modal (`AppClonerDialog`):**
    - Thiết kế 2 tab hiện đại với thanh tiến trình hoạt ảnh, bảng console nhật ký theo thời gian thực và các tùy chọn cài trực tiếp lên máy hoặc xuất file ra máy tính.
    - Điểm truy cập thuận tiện: Nút bấm trực tiếp trong App Inspector (App Manager), menu 3 chấm, Package Inspector (App Installer), Quick Tools shortcut, và Command Palette (`Ctrl+K`).
- **🎨 Bảng Terminal Log thích ứng theo giao diện (Adaptive Theme Terminal Logs):**
  - Khắc phục hoàn toàn tình trạng bảng log đen cố định (`#14171A`) gây lệch tông khi sử dụng giao diện Sáng (Frosted Light Mode).
  - Tự động chuyển đổi màu nền và màu chữ nhật ký đồng bộ theo chủ đề:
    - **Dark Theme:** Nền Slate `#0F172A`, thanh tiêu đề `#1E293B`, chữ xanh ngọc mint `#34D399` dịu mắt.
    - **Light Theme:** Nền Slate nhạt `#F8FAFC`, thanh tiêu đề `#F1F5F9`, chữ xanh lục đậm `#047857` độ tương phản cao, hòa nhập hoàn hảo với phong cách Frosted Glass.
  - Áp dụng đồng bộ cho Terminal Log trong App Installer, Folder Sync và ADB Console.
- **🛡️ Ổn định hóa phiên Scrcpy & Bố cục Sidebar:**
  - Ngăn ngừa tình trạng lỗi hủy phiên phản chiếu màn hình và khắc phục lỗi tràn bố cục sidebar khi thu phóng (`scrcpy_mirror_session_test.dart`, `mirror_sidebar_layout_test.dart`).
  - Hoàn thiện bộ kịch bản cài đặt và gỡ bỏ Windows độc lập (`install.bat`, `uninstall.bat`, `uninstall.ps1`).
- **🌐 Đồng bộ hóa đa ngôn ngữ (Trilingual L10n Sync):**
  - Bổ sung và đồng bộ toàn bộ khóa chuỗi mới cho App Cloner và Adaptive Terminal trên cả 3 ngôn ngữ: Tiếng Anh (EN), Tiếng Việt (VI), và Tiếng Trung (ZH).

### 📦 Phát hành & Đóng gói (Release & Distribution)
- Đồng bộ số phiên bản `v1.8.0+16` trên toàn bộ hệ thống (`pubspec.yaml`, `constants.dart`, `Runner.rc`, `ABOUT.txt`, `README.md`, `USERGUIDE.md`, `CHANGELOG.md`, `RELEASE_NOTES.md`).
- Đóng gói chuẩn portable release vào thư mục `dist/` kèm file nén `JA_adb_tool_v1.8.0_Windows_x64.zip` và mã kiểm tra SHA256.

---

## [v1.7.6] - 2026-09-21

### 🚀 Nâng cấp & Tính năng mới (Major Features & Enhancements)
- **📡 Tự động cập nhật qua mạng nội bộ LAN Over-The-Air (LAN OTA Update System):**
  - Tự động kiểm tra bản cập nhật mới trong nền khi khởi động ứng dụng và hỗ trợ kiểm tra thủ công nhanh chóng qua Command Palette (`Ctrl+Shift+P` / `Ctrl+K`) hoặc Settings.
  - Hỗ trợ cả đường dẫn thư mục chia sẻ mạng UNC SMB (`\\server\share\...`) và thư mục cục bộ/ổ đĩa mạng, kèm cơ chế xác thực thông tin đăng nhập tự động (`net use`).
  - Hệ thống so khớp phiên bản Semantic Versioning nghiêm ngặt (`SemanticVersion`), hỗ trợ cả manifest `update_manifest.json` và tự động phát hiện gói ZIP chuẩn `JA_adb_tool_v<version>_Windows_x64.zip`.
  - Quy trình giải nén phân đoạn an toàn qua PowerShell, xác minh tính hợp lệ của nhị phân Flutter (`ja_adb_tool.exe`, `flutter_windows.dll`, `data/app.so`) và kiểm tra mã băm SHA256 trước khi cài đặt.
  - Bộ cài đặt ngầm thông minh `apply_update.bat` với cơ chế chờ tiến trình cũ thoát theo PID, đồng bộ bản mới qua robocopy nhiều lượt retry, tự động backup phiên bản cũ và khởi động lại ứng dụng.
  - Giao diện thông báo cập nhật Bento Frosted Glass hiện đại hiển thị ghi chú phát hành dạng cuộn, thanh tiến trình tải thời gian thực kèm tốc độ truyền và đồng hồ đếm ngược tự động khởi động lại.
  - Tích hợp tab cấu hình riêng biệt "LAN OTA Update" trong Cài đặt đường dẫn (`PathsSettingsDialog`), cho phép kiểm tra kết nối máy chủ tức thì và đặt chu kỳ kiểm tra tự động.
  - Hỗ trợ đa ngôn ngữ đầy đủ (Tiếng Anh, Tiếng Việt, Tiếng Trung) với 28 khóa bản địa hóa mới.

### 📦 Phát hành & Đóng gói (Release & Distribution)
- Đồng bộ số phiên bản `v1.7.6+15` trên toàn bộ hệ thống (`pubspec.yaml`, `constants.dart`, `Runner.rc`, `ABOUT.txt`, `README.md`, `USERGUIDE.md`, `CHANGELOG.md`, `RELEASE_NOTES.md`).
- Đóng gói chuẩn portable release vào thư mục `dist/` kèm file nén `JA_adb_tool_v1.7.6_Windows_x64.zip` và mã kiểm tra SHA256.

---

## [v1.7.5] - 2026-09-18

### 🚀 Major Features & Enhancements
- **📦 APK & XAPK Package Extraction (Trích xuất APK / XAPK):**
  - Extract installed application packages directly from Android device to chosen PC directory.
  - Automatic packaging detection: extracts single packages as `<AppName>_v<Version>.apk`, and modern split APK bundles (`base.apk`, `split_config.*.apk`) into standard `<AppName>_v<Version>.xapk` archives bundled with `manifest.json` fully compatible with JA ADB Tool's APK/XAPK installer.
  - Dual extraction modes: single app via 3-dots action menu (`extract_apk_btn`) and multi-package extraction via Quick Batch Actions (`batch_extract_apk`).
  - Interactive completion Toast with 1-click **Open Folder** (`open_folder`) action opening and highlighting the extracted file in Windows Explorer (`explorer.exe /select,...`).
- **🎨 Bento Glass Droplist & Popup Menus Overhaul (Showcase Standard):**
  - Resolved transparent dropdown and popup menus by adding high-opacity solid glass tokens `dropdownBg` and `dropdownBorder` across `AppColors`, `StylesWin10`, `StylesWin11`, and `ThemeProvider`.
  - Dark Mode: `Color(0xF51E293B)` (96% opacity tint) with glass border `Color(0x38FFFFFF)`.
  - Light Mode: `Color(0xFAFFFFFF)` (98% opacity tint) with border `Color(0x29000000)`.
  - Applied to all `PopupMenuButton` widgets (app actions, sort options) and all 5 `DropdownButton` controls (Screen Mirroring bitrate/resolution, Screen Timeout, Animation Scale, USB Configuration, and FolderSync direction) with `borderRadius: BorderRadius.circular(12)` and 10dp elevation shadow.
  - Refined Select Latest input field styling with crisp borders in light mode while strictly preserving dimensions and position.
- **📂 File Explorer Download "Open Folder" Action:**
  - Upgraded transfer coordinator `_runWithTransferProgress` to support target folder navigation. Both single file and batch file downloads now present an **Open Folder** (`open_folder`) button on completion to immediately open the local target directory in Windows Explorer.
- **🔔 Floating Bento Glass Toast Notification System:**
  - Standardized all application notifications to floating Bento Glass toasts with 14px rounded corners, 16px background blur, accent borders, 3D shadows, single active toast management (`_activeToastEntry`), and interactive Bento pill action buttons.
  - Migrated 100% of legacy `ScaffoldMessenger.showSnackBar` calls across `main_window.dart`, `dialogs.dart`, `device_workspace_dialog.dart`, `settings_backup_dialog.dart`, and `ntp_time_sync_dialog.dart` to `context.showSuccessToast`, `context.showErrorToast`, and `context.showInfoToast`.

### 📖 Documentation & Release Metadata
- **📝 Documentation sync:** Updated `ABOUT.txt`, `README.md`, `USERGUIDE.md`, `RELEASE_NOTES.md`, and in-app About and User Guide dialogs across English, Vietnamese, and Chinese locales.
- **🏷️ Version bump:** Synchronized version across `pubspec.yaml` (`1.7.5+14`) and `lib/modules/constants.dart` (`1.7.5`).

---

## [v1.7.4] - 2026-09-17

### 🚀 Major Features & Enhancements
- **⏰ NTP Time Server Diagnostics & Synchronization:**
  - Pure Dart UDP NTP client querying port 123 (48-byte packet) measuring round-trip latency, stratum level, and server time with zero external tool dependencies (no Python or PowerShell required).
  - Concurrent /24 subnet scanner discovering active NTP servers in ~1.5s with microsecond packet pacing and full datagram buffer draining.
  - Real-time device clock vs. host PC time comparison with visual drift indicator (< 3s synced, amber warning on drift).
  - 1-Click offline PC time sync rescue via multi-version ADB fallback syntax (`date -u @<epoch>` / `date "$m$d$hh$mm$y.$ss"`) with temporary `auto_time 0` override.
  - Fast presets for Foxconn/Intranet (`10.81.184.80`, `10.81.184.81`) and public servers (`time.google.com`, `pool.ntp.org`, `time.cloudflare.com`).
  - Live diagnostics viewer for `dumpsys time_detector`, `dumpsys network_time_update_service`, and NTP logcat dumps with 1-click clipboard copy.
- **📶 Wireless ADB Port 5555 Persistence:**
  - 1-Click fix & connect: sets `service.adb.tcp.port 5555`, `persist.adb.tcp.port 5555`, restarts `adbd` in TCP mode (`adb tcpip 5555`), and connects over Wi-Fi.
  - Multi-tier IP detection across DHCP properties, `ip addr show wlan0`, and `ip route show table 0`.
  - Automatic disconnection of stale/ephemeral endpoints for the same IP to prevent port conflict clutter.
- **📐 Quick Tools Tab Overhaul & 12-Card Symmetric Grid:**
  - Rebuilt Quick Tools shortcuts into a responsive 12-card grid dividing evenly into 6x2 (ultra-wide), 4x3 (wide), 3x4 (compact), or 2x6 (narrow) layouts with zero orphan cards.
  - Integrated `ntp_time_sync` (cyan highlighted shortcut) and `date_settings` (`android.settings.DATE_SETTINGS`).
  - Added `ntp_time_sync` shortcut to Command Palette (`Ctrl+K`).
  - Compact Bento redesign for tactile 6-key hardware remote, color-coded power actions, compact text input / ADB console, and responsive reverse tethering banner.

### 📖 Documentation & Release Metadata
- **📝 Documentation sync:** Updated `ABOUT.txt`, `README.md`, `USERGUIDE.md`, `RELEASE_NOTES.md`, and in-app About and User Guide dialogs across English, Vietnamese, and Chinese locales.
- **🏷️ Version bump:** Synchronized version across `pubspec.yaml` (`1.7.4+13`) and `lib/modules/constants.dart` (`1.7.4`).

---

## [v1.7.3] - 2026-09-12

### 🚀 Major Features & Enhancements
- **🌐 Reverse Tethering (Gnirehtet) Auto-Setup:**
  - Robust discovery algorithm (`findGnirehtetApk`) locating `gnirehtet.apk` across bundled directories (`bin/`, `bin/gnirehtet-rust-win64/`, parent folders, and executable root).
  - Automated client installation: inspects target device via ADB (`pm path com.genymobile.gnirehtet`) and installs `gnirehtet.apk` automatically if absent before starting `gnirehtet.exe`.
  - Process environment hardening: sets `workingDirectory: gnirehtetDir`, and exports `GNIREHTET_APK`, `ADB`, and augmented `PATH` environment variables to permanently prevent "failed to stat gnirehtet.apk: No such file or directory" errors.
- **🧭 Responsive 3-Tier Tab Navigation (`SlidingPillTabBar`):**
  - Added smart 3-tier density switching: Full tier (icon + label), Text-Only tier (prioritizes label text to fit all 7 tabs seamlessly in Vietnamese language mode without clipping the last tab), and Compact tier (accordion-style active tab with icon pills).
  - Added elastic bounce nudge animation hint (`Curves.elasticOut`) on tab initialization and language switching to notify users of horizontal scroll capability.
  - Added desktop mouse wheel horizontal scrolling support via `PointerScrollEvent` listener.
  - Added glass indicator chevrons (left/right buttons) and automatic scrolling to selected active tab.

### 📖 Documentation & Release Metadata
- **📝 Documentation sync:** Updated `ABOUT.txt`, `README.md`, `USERGUIDE.md`, `RELEASE_NOTES.md`, and in-app About and User Guide dialogs across English, Vietnamese, and Chinese locales.
- **🏷️ Version bump:** Synchronized version across `pubspec.yaml` (`1.7.3+12`) and `lib/modules/constants.dart` (`1.7.3`).

---

## [v1.7.2] - 2026-09-06

### 🐛 Bug Fixes & Stability
- **🛡️ Device targeting:** Keep folder sync, APK/XAPK/OBB installation, uploads and media download batches on the device selected at operation start.
- **💾 Safe downloads:** Stage File Explorer and Latest Media downloads beside the destination; replace local files only after success and preserve existing files on failure or cancellation. Drain process output to avoid blocked transfers.
- **🔄 Async state:** Reject outdated directory, package and label responses after navigation or device changes, including A → B → A; reset selection/loading state on disconnect.
- **🧪 Regression coverage:** Add deterministic delayed-ADB tests for device switching, stale responses, successful/failed/cancelled downloads and batch targeting.

### 🎨 UI & Documentation
- **💎 Glass controls:** Integrate searchable single/multi-select glass dropdowns and adaptive tab navigation with widget coverage.
- **📖 Release metadata:** Synchronize About, README, user guide, in-app English/Vietnamese/Chinese guidance and Windows portable version 1.7.2+11.

---

## [v1.7.1] - 2026-08-27

### 🐛 Bug Fixes & Stability
- **🧹 UI import cleanup:** Removed unused imports left by the latest UI pass so analyzer checks complete without warnings from the changed files.
- **🛡️ BorderBeam safety:** Guarded the animated border painter against empty color lists, invalid stroke values, and zero-size layouts.
- **🧪 UI verification:** Formatted the new glass components and expanded widget coverage for the reusable toast, filter dock, detail dialog, animated border, and spotlight widgets.

---

## [v1.7.0] - 2026-08-26

### 🎨 Bento Liquid Glass Design System & Theme Engine
- **💎 Bento Glass Architecture:** Introduced unified Design Tokens (`app_colors.dart`), Win10 Aero / Win11 Mica-Acrylic style layers, dynamic GPU mesh background (`MeshBackground`), and responsive `BentoCard` widgets with translucent borders and soft glow effects.
- **🌓 1-Click Theme Provider (`ThemeProvider`):** Seamless instant Light/Dark mode switching with native Windows DWM title bar and system accent color synchronization.
- **🎛️ Dynamic Island Status Capsule (`DynamicIslandCapsule`):** Live pill-shaped status indicator in the top header displaying real-time device connection state (`CONNECTED`, `MIRROR`, `REVERSE`, `STANDBY`) with Asymmetric Marquee text.
- **🧭 Responsive Adaptive Navigation (`SlidingPillTabBar`):** Smart pill-shaped tab bar that dynamically adapts to window width:
  - Wide / Maximized window: Displays full icons and text labels for all 7 tabs.
  - Narrow / Compact window: Intelligently expands the active tab while collapsing unselected tabs to sleek icon capsules with hover preview tooltips.
- **✨ Asymmetric Ping-Pong Marquee Text (`AsymmetricMarqueeText`):** High-performance text scrolling component with 1400ms pause intervals at edges, easeInOutCubic motion, zero timer leaks, and 0% CPU consumption when text fits without overflow. Applied to version timestamps, device model names, serial subtitles, and tab titles.

### 📐 Layout Refinements & Typography
- **📱 Streamlined Sidebar:** Compacted the device sidebar width to 230px, maximizing usable workspace for Screen Mirroring, File Explorer, and App Installer.
- **⚙️ Unified Bottom-Left Toolbar:** Relocated Settings, 1-Click Theme Toggle, Language Switcher, and `Ctrl+K` Command Palette into a balanced, cohesive footer toolbar.
- **🔤 Standardized Typography Scale:** Fine-tuned font hierarchy, line heights, and letter spacing across all desktop components.
- **🖼️ Latest Media Preload & Cache:** Starts the media query immediately after device discovery and keeps results cached per device, so opening Latest Media and switching devices does not trigger unnecessary reloads.

---

## [v1.6.1] - 2026-08-24

### 🐛 Bug Fixes
- **🧩 App Installer layout:** Reworked the installer into a responsive two-column desktop layout; the picker and queue stay compact while package details, actions, and the log use the available space.
- **📏 Smart sizing:** Queue cards now size to their contents and the installation log expands to fill remaining height without leaving large empty areas.
- **🎨 Log contrast:** Light-theme installer logs now use a readable primary text style on the translucent panel.
- **⚡ Installation feedback:** Per-package progress is visible immediately and ADB exit codes are used for reliable APK/XAPK success detection.

---

## [v1.6.0] - 2026-08-22

### 📦 App Installer
- **📲 Multi-package install:** Select multiple APK/XAPK files in one picker, review the queue, remove individual items, and install them sequentially with per-package progress in the log.

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
