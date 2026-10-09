# Handoff: JA ADB Tool v1.12.0

## 2026-10-08: Follow-up keyboard report (helper not enabled)

- User reported keyboard still failing after a build, then confirmed the helper was not enabled. This attempt exercised ordinary Scrcpy keyboard injection, not the dedicated helper TextField/Send path. No new helper defect is established by this report; enabling the helper does not transparently reroute typing in the native Scrcpy window.
- Read-only live checks: running app is build/windows/x64/runner/Release/ja_adb_tool.exe; its EXE/app.so timestamps are 2026-10-07 15:47/15:46, preceding helper source timestamps 2026-10-08 12:16. Helper strings were not found in that app.so. Standalone Scrcpy targets bc4cd33a with --keyboard=sdk --prefer-text; Android currently uses LatinIME and ADBKeyBoard is installed. The other connected device 2b69e02 does not list ADBKeyBoard.
- Next acceptance: open the current rebuilt binary, use Mirror's helper keyboard button, explicitly enable, focus a non-sensitive Android editor, compose in the Windows dialog and Send. If the button is absent, the loaded binary must be refreshed. Native Windows end-to-end remains OPEN. No production patch, app termination, binary replacement, device/IME/text mutation or new test run in this diagnostic follow-up.

## 2026-10-08: Windows helper input integration

- Added an opt-in keyboard button in Mirror options opening a Windows TextField dialog. Explicit Send transports committed UTF-8/Base64 text through the already installed ADBKeyBoard; pending composition disables Send. Backspace and selectable editor actions are supported. This is batch text entry, not global keyboard interception in Scrcpy.
- New `helper_ime_session.dart` serializes commands, captures the original device/IME, uses bounded ADB clients, rejects stale/closed sessions, restores the original IME and preserves external keyboard selections. Close failures remain visible and retryable; device changes restore the original device rather than sending to the new selection. No text logging/persistence or automatic APK download/install.
- New `helper_ime_dialog.dart`, Mirror entry point in `main_window.dart`, AppLogic factory, and EN/VI/ZH strings. Stock helper broadcasts are experimental/unprotected; explicit warning prohibits sensitive/password input. Forced app exit or disconnected devices may require manual keyboard restoration.
- Regression coverage: helper service lifecycle/rollback/UTF-8/stale commands plus dialog composition, retry, device change and EN/VI/ZH layout. Final full Flutter suite passed 267/267. Scoped analyzer: no errors/warnings, nine pre-existing async-context info diagnostics. Formatting and diff whitespace checks passed.
- Actual production Dart service diagnostic on bc4cd33a read back Vietnamese/emoji exactly, deleted emoji, performed SEARCH, then restored LatinIME. Independently rechecked both default/enabled IME as LatinIME; helper remains installed but disabled. Synthetic Settings query remains. See tools/ime_probe/verify_dart_session.dart and README.md.
- No Windows EXE rebuild/install, native Windows IME end-to-end acceptance, arbitrary app compatibility, secure receiver hardening, release, commit or push. Preserved pre-existing dirty changes and build/runtime artifacts. No SDK components/licenses or ROM changes.

## 2026-10-08: Helper IME real-device trial succeeded

- User approved installation/tests on `bc4cd33a`, then selected existing APK only (no SDK download/license acceptance). Installed official ADBKeyBoard v2.4-dev APK; SHA256 `e0d0cf276b710cb34c46121f58720f5285a83ed410b0d45f57a0677b67dc2852` matched GitHub release digest.
- Actual Android 9 Settings search editor readback passed English, Vietnamese, Backspace, emoji, emoji deletion. Editor SEARCH action (Enter equivalent) retained sample query and hid IME. Full trial script exited 0; transient UIAutomator null-root failures required bounded retries.
- Default/enabled IME restored and independently rechecked as `com.android.inputmethod.latin/.LatinIME`. ADBKeyBoard is installed but disabled. No ROM, credentials, other device or existing runtime data was changed. Sample search query and dedicated temporary UI dump remain.
- Harness/report: `tools/ime_probe/Test-AdbKeyboard.ps1`, `tools/ime_probe/README.md`; APK retained in ignored artifacts/. No Flutter production changes this trial. Prepared but unbuilt custom-helper draft was discarded after user chose stock APK.
- Scope: real IME mechanism proven for the Settings search editor; Windows text composition capture/Scrcpy integration, multiline Enter, arbitrary app compatibility and production receiver protection remain OPEN. No claim that stock ADBKeyBoard is secure for sensitive input.

## 2026-10-05: File Explorer Button Responsiveness & ADB Query Spam Fixes

- **User Issue**: "có vẻ nút tạo folder và nút upload đã bị lỗi. nó không có phản ứng gì sau một thời gian lâu nó mới phản ứng" (Create Folder and Upload buttons have no immediate reaction, responding only after a noticeable delay).
- **Root Cause Analysis**:
  1. **Infinite ADB Preload Loop in `scanDevices()`**: `_preloadLatestMedia` invoked `_ensureLatestMedia(device, allowDiskScanFallback: false)`. In `_queryLatestMedia`, ADB shell `content query` was called with `--limit`, which Android does not support (`[ERROR] Unsupported argument: --limit`). Because query returned empty and line 3064 only cached when `items.isNotEmpty || allowDiskScanFallback`, empty media results were NEVER cached. As a result, every 5-second `scanDevices()` tick launched back-to-back background ADB queries for all devices with empty media, continuously saturating the ADB daemon and delaying subsequent ADB commands (like `mkdir -p` and `ls -la`).
  2. **Create Folder Lack of Intermediate Feedback**: `createAndroidFolder` did not set `_isAndroidLoading = true` before `mkdir -p` completed. The dialog closed immediately upon clicking "Tạo", leaving the UI completely static for seconds until the directory listing completed. Additionally, `TextField` in `CreateFolderDialog` lacked `onSubmitted`, causing Enter key presses to appear ignored.
  3. **Upload Menu & FilePicker Latency**: Upload was hidden behind a `PopupMenuButton`, requiring 2 clicks. On Windows, native COM `IFileDialog` (`FilePicker.pickFiles`) blocks/delays for 2-5 seconds without any in-app visual indicator, making the app appear frozen. Folder batch planning also used `dir.listSync(recursive: true)` on the UI thread.
- **Implemented Fixes**:
  1. **ADB Media Query & Cache Hardening (`logic.dart`)**:
     - `_ensureLatestMedia` now unconditionally caches results in `_latestMediaByDevice[device]` (even if empty) when `!force`, terminating the 5-second preload loop.
     - Removed `--limit` argument from ADB `content query`, taking the required rows (`.take(50)` / `.take(30)`) cleanly in Dart.
  2. **Snappy Folder Creation (`logic.dart`, `dialogs.dart`, `main_window.dart`)**:
     - `createAndroidFolder` immediately sets `_isAndroidLoading = true; notifyListeners();` before ADB `mkdir -p`, giving instant (0ms) loading feedback.
     - `CreateFolderDialog` now handles `onSubmitted: (_) => _submit()` for Enter key submission.
     - Added `create_directory_success` toast feedback across EN, VI, and ZH localizations.
     - Folder button turns into an active spinner during directory operations.
  3. **Direct 1-Click Upload Buttons & Async Planning (`main_window.dart`, `smart_upload_service.dart`)**:
     - Split upload into two dedicated, direct 1-click icon buttons in the File Explorer toolbar: `Icons.upload_file_outlined` (Upload Files) and `Icons.drive_folder_upload_outlined` (Upload Folder).
     - Added instant loading spinners (`_isOpeningFilePicker`, `_isOpeningFolderPicker`) that activate the exact moment the button is clicked, indicating to the user that Windows is launching the native file dialog.
     - `prepareBatchPlan` in `SmartUploadService` now scans directories asynchronously with `await for (final entity in dir.list(recursive: true, followLinks: false))` to avoid blocking UI frames.
- **Verification**:
  - Full Flutter test suite passed: **242/242 tests passing** (including dedicated regression tests in `test/folder_upload_responsiveness_test.dart`).
  - Analyzer reports 0 errors and 0 warnings.
  - Code formatted with `dart format`.

## 2026-10-05: Startup/tab responsiveness and power review

- User screenshot: Latest Media sidebar selected while Mirror content remained visible. User tested C:/Users/FT/AppData/Local/Programs/JA_adb_tool. Installed app.so timestamp 2026-10-03 09:47:48, SHA256 13929C9B9A3040E487EBFDB888567F02CC9D6824FC7EEFD38EDC8EC7E5262C18; existing checkout Release app.so timestamp 15:30:17, SHA256 0FECDC946CA367735187CCF82EE346BCBAC4544E3C1CE476682451A9382E5072. Both predate the latest 03-Oct source fixes. No ja_adb_tool.exe process was found during inspection; neither binary was rebuilt/replaced this turn.
- Before this patch, current-source tests passed one-frame Mirror -> Media -> Explorer -> Mirror selection with ADB pending and TickerMode muted/enabled. The screenshot mismatch is not reproduced on current source; stale installed binary is established, but its runtime root cause remains unconfirmed.
- MainWindow now mounts each tab only on its first visit, preserving visited tab state in IndexedStack. Per-tab TickerMode mutes inactive tabs and still honors the enclosing app power gate. Selection updates visited state and controller index together, without repeating the mirror side-effect listener. Background services remain untouched.
- Navigation tests cover immediate visible content changes with pending ADB/muted tickers, initially unmounted FolderSyncTab, active/inactive ticker policies and state identity after returning to Folder Sync. These tests exposed a 1280x800 sync-direction dropdown overflow; constrained all three labels with Expanded/ellipsis.
- Verification: full Flutter suite passed 222/222; scoped analyzer has no errors/warnings, nine pre-existing async-context info diagnostics. Formatter and git diff --check passed.
- Native Windows startup/tab behavior, rebuilt/installed runtime and CPU/GPU measurements remain OPEN. No installed files, runtime config, APKs, build/dist artifacts, source version, commits or remote state were changed.

## 2026-10-03: Lazy Media / sync settings / highlight fixes

- Fixed uncached device selection (manual and scan auto-selection): Media starts idle rather than claiming a fetch that was never started. The Media tab lazy-loads once per selection session; empty results no longer cause repeated automatic fetches. Manual refresh and switching devices still load again.
- Guarded Media completion and device sync settings reads by device revision and disposal. Stale settings cannot overwrite the current device, including A -> B -> A; scan auto-sync also checks its captured revision. Added injectable sync config file for deterministic tests without modifying real config.json.
- Moved the two review diagnostic tests into test/lazy_media_regression_test.dart and extended them to cover actual logic state, empty results, unrelated rebuilds, manual refresh and device switching. Added three settings race/disposal tests.
- Highlight coverage checks selected/unselected background, border color and width in one frame, switching back, delayed parent acknowledgement, external selection and clearing selection in light/dark themes.
- Verification: full Flutter suite passed 220/220. After the final scan auto-selection guard, focused Media/settings/highlight/device operations tests passed 20/20. Scoped analyzer: no errors/warnings; existing async-I/O/context info diagnostics remain. Format and diff whitespace checks passed.
- No EXE rebuild, native Windows/device validation, packaging, commit or push. Existing unrelated dirty changes and build/dist/runtime data were preserved.

## 2026-10-03: Power optimizer review completed

- Integrated `AppPowerGate` in MaterialApp.builder above Navigator/routes/overlays. Ordinary progress/toast tickers now follow focus AND visibility, alongside the existing explicit animation pause logic.
- Startup synchronizes Flutter lifecycle before first UI; MainWindow rechecks current lifecycle on mount. Minimize clears old focus; restore awaits focus. Hidden -> inactive restores visibility without enabling animation. Pending config loads cannot restart idle timers after disposal.
- UI-only Mirror position polling and NTP clock polling stop while hidden and restart on visibility. Mirror send guard also prevents queued native position callbacks after hiding or switching tabs. ADB/device scanning, OTA and scrcpy business services remain outside the power gate; no service timers were globally paused.
- Tab chevrons preserve forward/reverse direction with explicit controller legs. Bounce hint and marquee post-frame callbacks use epochs to reject stale work after pause/dispose.
- NTP widget test exposed overflow in drift/status and server-title rows at 1280x800. Constrained text with Flexible/Expanded while retaining the existing dialog structure.
- Verification: full `flutter test --no-pub --concurrency=1` passed 212/212. After the final Mirror queued-callback guard, focused Mirror/power/NTP group passed 13/13. Format and diff whitespace checks passed. Scoped analyzer has no errors/warnings; 9 pre-existing async-context info diagnostics in main_window.dart.
- Regression coverage includes ordinary Navigator + Overlay tickers, initially hidden mounting, blur/minimize/restore without focus, background timer continuing under the gate, real MeshOrb/WaveIndicator reverse-phase continuity and NTP timer pause/resume. Existing power settings/marquee/tab tests also passed in the full suite. Background timer isolation is not proof of real OTA/ADB/device progress.
- Native acceptance remains OPEN: no rebuilt executable, native window interaction or process-specific CPU/GPU measurement this task. Existing build/Release and dist binaries were not changed. The walkthrough's 0% GPU/zero draw-call claims are not established by tests. Repository has no tray implementation; WM_ACTIVATE's existing WA_INACTIVE guard was preserved without claiming native validation. No packaging, version bump, commit or push.

## 2026-09-28: APK/XAPK review fixes (current source)

- Supersedes historical statements below that split/XAPK cloning is unsupported.
- ZIP extraction/packaging and APK/XAPK metadata parsing now run in isolates. Installed split-app staging also uses the ZIP worker; large file copies use async I/O.
- `services/xapk_archive.dart` provides shared clone/Installer validation: 1 GB compressed, 512 entries, 2 GB expanded, unsafe paths and symbolic links rejected before extraction.
- Signer discovery only accepts `bin/uber-apk-signer.jar` beside the executable or an explicitly configured absolute JAR path. Removed cwd/ancestor/script/cache search and automatic JAR copying. Explicit Build Tools selection takes precedence over the bundled signer. Existing build.bat/CMake copy rules already target executable-adjacent bin; packaging was not run in this task.
- XAPK install pushes all OBB files. Invalid destination metadata, mkdir failure or push failure returns failure (APK may already be installed; no automatic rollback).
- Repaired XAPK test import and outdated split-rejection expectation. Synthetic workflow now includes separate base/split APKs, inspects both modified manifests and renamed OBB contents. Added worker responsiveness, archive limits/traversal, service rejection-before-signing, trusted signer discovery and multi-OBB failure tests.
- Verification: full `flutter test --no-pub --concurrency=1` passed 170/170. Scoped analyzer: no errors/warnings; two existing async-I/O info lints in apk_signer.dart. Scoped diff whitespace check passed; full-tree check still reports a pre-existing trailing blank line in windows/runner/CMakeLists.txt (not edited here).
- Auto-refresh installed app list: `logic.loadApps()` is automatically triggered upon successful APK/XAPK cloning & device installation in `AppClonerDialog`, Dual Space / clone profile actions (`installAppToCloneProfile`, `uninstallAppFromCloneProfile`, `createDeviceCloneProfile`), and across direct single/batch installs in `logic.dart` (`installApkPath`, `installPackages`). Modal dismissals in `main_window.dart` also hook `.then((_) => logic.loadApps())`.
- Verification: Added regression test in `test/xapk_cloner_widget_test.dart` verifying `installApkPath` automatically refreshes `logic.apps` via `loadApps()`.
- Boundaries: signing/ADB regression tests use mocks. No real signing, device install/launch, native UI test, EXE rebuild, version bump, commit or push this turn. User reported previous build worked; this new source still needs portable/device validation. New regression temp fixtures are retained; no user APK, keystore, dist or runtime data was removed.

## Latest: v1.8.3 Release (APK Signing Setup Studio & Multi-Generation ADB Time Sync)
- **Multi-Generation ADB Time Sync Engine:**
  - Android 8.0 - 14+ (MT95, Android 13): Uses `cmd alarm set-time <epochMillis>` with UID 2000 shell privileges, avoiding `CAP_SYS_TIME` kernel restrictions on production builds.
  - Android 5.1/Lollipop (2b69e02, MSM8226): Fixed legacy `toolbox date` bug where `date -u @...` was parsed as `0.0`, resetting device clock to Dec 31, 1969 EST while returning exit code 0.
  - Multi-tier fallback chain: `cmd alarm set-time` -> `date -s YYYYMMDD.hhmmss` -> `date -s "YYYY-MM-DD hh:mm:ss"` -> `date MMDDhhmmyyyy.ss`.
  - Date parsing in `_calculateDrift`: Added regex fallback supporting standard Linux date strings (`Sat Sep 26 10:28:15 ICT 2026`) in addition to ISO format.
- **APK Signing Setup Studio:**
  - Clone dialog offers Signing setup with Java executable and Build Tools version-directory pickers, automatic discovery, custom keystores, alias/password management, and official installation links; labels cover EN/VI/ZH.
  - Paths are saved in the user configuration directory under `JA ADB Tool/apk-signing.json`.
  - Test signature validation and 1-click error link from App Cloner failures.
- **Verification:**
  - Full suite: 142/142 tests passed (100%).
  - Dart analyze: 0 errors, 0 warnings.
  - Tested directly on hardware devices: MT95 (Android 13) and 2b69e02 (Android 5.1).

## Latest: clone dialog responsiveness
- Dialog uses ThemeProvider.colors, matching production providers (no AppColors provider lookup).
- APK read/decode/manifest/repack/write runs in Isolate.run with scalar/path inputs only.
- Installed clone checks pm path first, rejects multiple APKs before pull, and pulls the captured standalone path directly without building an XAPK.
- Dialog catches unexpected exceptions and resets busy state in finally.
- Added clone_responsiveness_test.dart for production-provider rendering, error recovery, early split rejection and worker event-loop responsiveness.
- Runtime validation of this patch is BLOCKED: Flutter/Dart compiler reports Out of memory before tests execute. Earlier 131-pass result below predates this patch. No WhatsApp install/launch was tested; APK processing still needs enough memory even in an isolate.

## Scope
- Attribute-aware AXML updates preserve DEX class namespaces, expand relative class names, rewrite provider authorities, and replace existing application/activity label attributes (including resource references).
- Unsupported split APK/XAPK and shared-user manifests fail explicitly; use Dual Space where supported. Missing application label also fails explicitly when renaming is requested.
- APK output requires zipalign, apksigner with v2 enabled, and successful v2 verification. Android Build Tools, Java, and an existing standard Android debug keystore are prerequisites. Missing prerequisites and signing failures no longer report success. Existing output files are not intentionally replaced.
- Installer failure is reported separately from APK creation.
- Mirror header/device capsule and option labels adapt at 1280x800 without changing the overall layout.

## Verification
- Full Flutter suite: 131 tests passed.
- Dart analyze: no errors or warnings, 26 existing info diagnostics.
- Format check: 7 Dart files unchanged. Git diff --check passed.
- Mirror connected-device widget tests cover EN/VI/ZH, light/dark, and options/sidebar collapse/expand.
- Signing tests use an injected process runner; manifest tests use synthetic binary fixtures.

## Boundaries / next checks
- No real APK signing/install/launch or native scrcpy visual testing was performed. Package-dependent signature checks, native libraries and resource behavior can still prevent cloning.
- Signing staging directories are retained in system temp; this task did not delete runtime data.
- No release rebuild, version bump, commit or push. Existing dist v1.8.0 does not contain these fixes.
