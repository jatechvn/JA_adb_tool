TAG=v1.4.3
TITLE=JA ADB Tool v1.4.3
BODY=
## Highlights

- Added a four-step illustrated USB Debugging onboarding flow when no Android device is connected.
- Added neutral Android-style screenshots with click-to-zoom previews and a direct device refresh action.
- Persisted the selected English, Vietnamese, or Chinese app language across restarts, including a fallback for read-only portable folders.
- Synchronized About, README, User Guide, in-app copy, version metadata, and release packaging for v1.4.3.

## Verification

- `dart analyze --no-fatal-warnings` completed without errors or warnings introduced by this release.
- `flutter test --no-pub` passed all 3 tests.
- `flutter build windows --debug` completed successfully.
