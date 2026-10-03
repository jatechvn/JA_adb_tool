# Handoff: JA ADB Tool v1.10.2

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
