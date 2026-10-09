# ADBKeyBoard device trial — 2026-10-08

## Scope and provenance

- User approved install/test on `bc4cd33a`, then chose the existing APK only; no Android SDK components/licenses were installed or accepted. An unbuilt custom-helper draft created during preparation was discarded. Existing app/source changes were preserved.
- Android 9 / API 28, product `msm8953_64`. Original default and enabled IME: `com.android.inputmethod.latin/.LatinIME`.
- APK: official [ADBKeyBoard v2.4-dev release](https://github.com/senzhk/ADBKeyBoard/releases/tag/v2.4-dev), `keyboardservice-debug.apk`, 18,595 bytes.
- SHA256: `e0d0cf276b710cb34c46121f58720f5285a83ed410b0d45f57a0677b67dc2852`. Download hash matched the GitHub release asset digest. This confirms asset identity, not a reproducible source-to-binary audit or production security certification.
- Download retained under ignored `artifacts/ADBKeyboard-v2.4-dev.apk`.

## Actual device results

Editor: non-password `android:id/search_src_text` in `com.android.settings.intelligence/.search.SearchActivity`. Samples only; no credentials, messages, purchases or ROM changes.

| Test | Observed result |
| --- | --- |
| English UTF-8/Base64 | Read back `JA English 123` exactly |
| Vietnamese UTF-8/Base64 | Read back `Xin chào Việt Nam 123` exactly |
| Backspace via `ADB_INPUT_CODE`, code 67 | Read back `Xin chào Việt Nam 12` |
| Emoji UTF-8 | Read back `Xin chào Việt Nam 12😀` |
| Backspace emoji | Read back `Xin chào Việt Nam 12`, no broken surrogate |
| Enter equivalent via editor SEARCH action 3 | Query retained; input method reported `mInputShown=false` |
| Restoration | Default AND enabled IME returned to LatinIME; helper disabled |

The first harness run stopped because UIAutomator returned null root nodes while Settings search was updating. A later readback confirmed Backspace had worked. Added bounded UI dump retries; the subsequent full run exited 0 with all six checks and restoration passing. No evidence established that this transient dump failure meant screen-off or a failed text command.

## Repeat safely

1. Open Settings search and focus its empty search field; do not use a personal/password editor.
2. Ensure the APK is installed and LatinIME is selected; run `tools/ime_probe/Test-AdbKeyboard.ps1` from PowerShell. Default serial is explicitly `bc4cd33a`.
3. The harness checks the editor package and non-password attribute, uses sample text, and restores the original default/enabled IME in `finally`. It refuses unrelated existing search text. A nonzero exit is not success; inspect its result and restoration.

## Remaining boundary

## JA ADB Tool integration (current source)

1. In Mirror options, click the keyboard icon. Acknowledge the experimental-helper warning, then enable the helper session. The APK must already be installed; the app does not download/install it.
2. Focus a non-sensitive Android input field through Scrcpy. Compose text in the Windows dialog, finish Windows IME composition, then click Send. Pending composition disables Send; a successful broadcast status means command acknowledgement, not proof of insertion in every app.
3. Backspace deletes through the helper. Choose the appropriate Enter editor action (Go/Search/Send/Next/Done); Send may submit the Android form. Close restores the previous keyboard. A failed restoration remains visible and can be retried. Device selection changes invalidate sending and attempt restoration on the original device.

The integration is explicit batch text entry, not transparent/global typing into the Scrcpy native window. Stock ADBKeyBoard accepts commands from other apps: do not use passwords or sensitive text. After an app crash/disconnection, manually select the previous Android keyboard if restoration could not complete.

The production Dart service was exercised with `dart tools/ime_probe/verify_dart_session.dart bc4cd33a` against Settings search: exact Vietnamese/emoji readback, emoji Backspace, SEARCH and LatinIME restoration passed. Both default/enabled IME were independently rechecked. The diagnostic only clears known synthetic search queries and leaves `JA Việt ` as its final sample. Dialog composition/lifecycle/layout is covered by Flutter tests; native Windows IME and rebuilt EXE acceptance remain untested.

## Original trial boundary

Helper remains installed but disabled. The sample query remains in Settings search. The temporary device dump is `/data/local/tmp/ja-ime-test.xml`; no existing user files were removed.

The original PowerShell trial demonstrates the IME pathway in this specific editor/device. It does not verify physical Enter key injection, multiline Enter, deletion of every Unicode grapheme, passwords, arbitrary apps or secure broadcast transport. Stock ADBKeyBoard must not be treated as a hardened production receiver. No ROM, firmware, other device, installed Windows app, EXE, release or remote repository was changed.
