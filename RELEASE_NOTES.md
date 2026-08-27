TAG=v1.7.1
TITLE=JA ADB Tool v1.7.1
BODY=
## Bug Fixes & Stability

- **UI import cleanup:** Removed unused imports from the latest glass UI pass.
- **BorderBeam safety:** Prevented invalid empty/zero-size painter inputs from causing rendering exceptions.
- **Formatting and widget coverage:** Formatted the new glass components and retained widget tests for toast, filter, dialog, animated border, and spotlight behavior.

## Included UI Features

- Bento Liquid Glass UI, Design Tokens, Win10 Aero / Win11 Acrylic-Mica styles, Dynamic Island status capsule, responsive navigation, and per-device Latest Media preload/cache from v1.7.0.

## Verification

- `dart analyze` completed with 0 errors and 0 warnings.
- `flutter test` passed all 20 unit and widget tests.
- Windows Debug and Release builds completed successfully.
