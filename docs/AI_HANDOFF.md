# Handoff: App Cloner and Mirror fixes

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
