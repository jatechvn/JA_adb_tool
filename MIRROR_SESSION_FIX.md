# Brief sửa lỗi phiên Scrcpy Mirror

Ngày verify: 2026-09-23.  
Phạm vi: máy trạng thái mirror, retry, nút Launch/Stop, toast lỗi, resize, USERGUIDE.  
Không đụng preset chất lượng, serialization profile, hay bản dịch đã đúng.

Đưa file này cho AI sửa lỗi. Làm đúng các mục **Phải sửa**. Giữ nguyên các mục **Đã đúng**. Chạy lại lệnh ở mục **Kiểm chứng**.

---

## Đã đúng — không được phá

`flutter analyze --no-fatal-infos`: exit 0, **0 error, 0 warning**. Còn 31 info cũ (logger, OTA, `BuildContext` sau `await`). Không cần dọn các info đó trong task này.

`flutter test`: **88/88 pass**.

Preset trong `lib/modules/services/scrcpy_profile_store.dart`:

| Preset | id | max size | fps | bitrate |
|---|---|---|---|---|
| Low / Wi-Fi | `low` | 1024 | 30 | 3 Mbps |
| Balanced | `balanced` | 1600 | 60 | 6 Mbps |
| High / USB | `high` | 1920 | 60 | 10 Mbps |

`ScrcpyProfile.fromJson` đọc JSON cũ thiếu `preset` / `maxSize` / `maxFps` / `bitRate` và điền Balanced. `AppLogic.buildScrcpyArgs` sinh `-m`, `--max-fps`, `-b`, cùng `--always-on-top`, `--fullscreen`, `--no-control`, `--stay-awake`, `--window-borderless`, `--no-audio`.

Nhãn EN / VI / ZH cho preset, `mirror_starting`, `mirror_initializing_hint`, `mirror_error_title`, `mirror_open_standalone`, `mirror_diagnostics` đã có trong `lib/modules/ui/localization.dart`.

UI trong `lib/modules/ui/main_window.dart`:

- Pill Low / Balanced / High, khóa khi `logic.isMirroring`.
- Nút amber + `Connecting...` khi `starting`, đỏ `Stop Mirror` khi `running`, xanh `Launch Mirroring` khi `stopped`.
- Placeholder spinner + `mirror_initializing_hint` khi `starting`.
- Banner diagnostics hiện `mirroringDeviceSerial` khi `running`.

`_mirrorSessionId` tăng ở đầu `launchMirroring` và trong `stopMirroring`. Callback embed / stderr / exit có so session id. Serial đưa vào CLI được chụp lúc bấm Launch (`targetDevice`), không đọc lại `_selectedDevice` sau đó.

---

## Phải sửa

### 1. Retry bị guard chặn, UI kẹt `Connecting...`

File: `lib/modules/logic.dart`, `launchMirroring`.

Guard đầu hàm từ chối khi trạng thái là `starting` hoặc `running`:

```dart
if (_mirrorState == MirrorState.starting ||
    _mirrorState == MirrorState.running) {
  return false;
}
```

Handler `proc.exitCode` khi mã khác 0, dưới 5000 ms, `retryCount < 1`, và trạng thái vẫn `starting`, lại gọi `launchMirroring(...)`. Guard trả `false` ngay. Handler `return` trước khi gán `MirrorState.error`.

Hệ quả:

- Trạng thái nằm lại ở `starting`.
- `_scrcpyProcess` đã bị gán `null` trước lần gọi lại.
- Nút Launch bị `onPressed: null` suốt `isMirrorStarting` (`main_window.dart`, nút mirror).
- `selectDevice` chỉ gọi `stopMirroring()` khi `_scrcpyProcess != null`, nên đổi thiết bị cũng không gỡ kẹt.
- Cách thoát hiện tại là tắt app.

Hành vi cần có:

- Tối đa **một** lần thử lại khi tiến trình thoát mã khác 0 trong vòng 5 giây, session id vẫn khớp, và `_selectedDevice` vẫn là `targetDevice`.
- Trước lần gọi lại, trạng thái không còn `starting` / `running`, để guard không nuốt retry. Lần gọi lại vẫn tăng `_mirrorSessionId`.
- Nếu không retry, hoặc lần gọi lại trả `false`: gán `MirrorState.error`, xóa `_mirroringDeviceSerial`, `notifyListeners()`, giữ `lastScrcpyError`.
- Tiến trình đã chết thì không được để máy trạng thái ở `starting`.

### 2. Không hủy được lúc `starting`

File: `lib/modules/ui/main_window.dart`, nút mirror chính.

`onPressed` là `null` khi `logic.isMirrorStarting`. Chống bấm đúp đang chặn luôn Stop.

Hành vi cần có:

- Trong `starting`, nút vẫn amber và chữ `mirror_starting`, nhưng bấm được và gọi `stopMirroring()` + `_hideMirrorWindow()`.
- Bấm lần hai không được gọi `launchMirroring` khi đang `starting` hoặc `running`.
- `stopMirroring` vẫn tăng session id và kết thúc ở `stopped`.

### 3. Hết vòng embed mà không có trạng thái kết

File: `lib/modules/logic.dart`, `Future.delayed(2s)` rồi tối đa 30 lần × 200 ms gọi `embedMirror`.

Hết vòng, nếu chưa embed, không gán `running` hay `error`. Trạng thái ở lại `starting`, nút khóa, dù scrcpy còn sống.

Hành vi cần có:

- Hết ngân sách embed, nếu session vẫn là session hiện tại và trạng thái vẫn `starting`: dừng tiến trình của session đó, gỡ embed, gán `MirrorState.error`, ghi `lastScrcpyError` một câu ngắn (ví dụ cửa sổ scrcpy không gắn kịp), xóa serial, `notifyListeners()`.
- `stopMirroring` và `dispose` phải hủy timer / vòng chờ này. Callback muộn thấy session đổi thì thoát, không gọi embed nữa.
- Không để `Future.delayed` sống sau khi test hoặc `dispose` kết thúc. Nếu không, `flutter test` báo pending timer.

### 4. Toast lỗi không hiện sau khi tiến trình đã chạy

`launchMirroring` trả `true` ngay sau `Process.start`. Toast ở nút Launch chỉ chạy khi hàm trả `false`. Stderr có ghi vào `_lastScrcpyError`, nhưng lỗi ADB sau khi tiến trình đã spawn không thành toast.

`launchStandaloneMirroring` trong `catch` không gán `_lastScrcpyError`. Toast standalone có thể hiện stderr cũ của phiên embed trước, hoặc câu generic.

Đường `return false` sớm (`_selectedDevice == null` hoặc `_scrcpyPath` rỗng) cũng không xóa / ghi `lastScrcpyError`, nên toast có thể hiện lỗi cũ.

Hành vi cần có:

- Mỗi lần bắt đầu launch (embed hoặc standalone), sau khi qua kiểm tra đầu vào, xóa `lastScrcpyError`. Nếu thiếu thiết bị hoặc path, gán một câu lỗi ổn định rồi trả `false`.
- `launchStandaloneMirroring` khi `Process.start` ném lỗi: gán `_lastScrcpyError = e.toString()` rồi trả `false`.
- Khi phiên embed kết thúc ở `error` (thoát mã khác 0 sau khi hết retry, hoặc embed timeout), UI hiện **một** toast `mirror_error_title` + `lastScrcpyError`. Không toast khi người dùng bấm Stop hoặc khi thoát mã 0.
- Cách làm gọn: lắng nghe `mirrorState` chuyển sang `error` kèm `mirrorSessionId`, toast một lần cho session đó. Toast hiện tại khi `launchMirroring` trả `false` giữ nguyên.

### 5. `mirror_stopping` không được đọc

Chuỗi `mirror_stopping` có ở EN / VI / ZH trong `localization.dart` nhưng không widget nào dùng. `stopMirroring` gán `stopping` rồi gán `stopped` trong cùng một lượt đồng bộ, nên frame UI chỉ thấy `stopped`.

Hành vi cần có:

- Nút map `MirrorState.stopping` tới `context.tr('mirror_stopping')`.
- Không thêm delay giả để “khoe” trạng thái này.

### 6. USERGUIDE nói sai về đổi thiết bị

`lib/modules/logic.dart`, `selectDevice`: nếu `_scrcpyProcess != null` thì gọi `stopMirroring()`. Danh sách thiết bị trong `main_window.dart` gọi `selectDevice`.

Serial ghim chỉ cố định đối số CLI và dòng diagnostics cho đến lúc dừng. Đổi thiết bị **có** dừng mirror đang chạy.

Sửa mục **13. Screen Mirroring** trong `USERGUIDE.md`. Câu hiện tại nói đổi dropdown thiết bị không làm gián đoạn stream. Viết lại cho khớp mã: đổi thiết bị dừng phiên mirror đang chạy. Không đổi `selectDevice` để giữ stream.

### 7. Resize bỏ khung hình cuối

`_updateMirrorPosition` trong `main_window.dart`: nếu `_isUpdatingMirrorPosition` thì `return`. Lệnh kênh đang bay chặn lần đo mới, và lần đó không được gửi lại khi lệnh trước xong.

Hành vi cần có:

- Vẫn chỉ một lệnh `updateMirrorPosition` tại một thời điểm.
- Nếu có hình chữ nhật mới trong lúc đang gửi, giữ **bản mới nhất** và gửi nó trong `whenComplete`. Không xếp hàng vô hạn.

---

## Test bắt buộc

Mở rộng `test/scrcpy_mirror_session_test.dart`. Giữ các test preset / profile / `buildScrcpyArgs` / trạng thái ban đầu.

`launchMirroring` đang gọi `Process.start` trực tiếp, không đi qua `transferStarter`. Đừng dùng `savePaths` trong test (hàm đó ghi SharedPreferences và `config.json`).

Làm seam nhỏ, theo mẫu `FakeProcess` / `TestLogic` trong `test/device_operations_test.dart`:

- Thêm tham số khởi tạo tùy chọn cho tiến trình mirror, mặc định `Process.start`, đánh dấu `@visibleForTesting`.
- Thêm cách gán `_scrcpyPath` và thiết bị đã chọn mà không ghi đĩa. `selectDevice` đã có; `TestLogic` nên override `loadDeviceSyncSettings`, `fetchLatestMedia`, và các load khác mà `selectDevice` kích hoạt, giống `device_operations_test.dart`.
- Rút thời gian chờ embed và delay retry thành hằng số có thể rút xuống `Duration.zero` trong test. Hủy timer khi đổi session.

Case cần có:

1. Tiến trình giả thoát mã 1 ngay, stderr có chữ. Đúng một lần `Process.start` thứ hai. Sau đó trạng thái là `running` hoặc, nếu lần hai cũng chết, `error`. Không được ở lại `starting`.
2. Lần thử lại thất bại: `mirrorState == MirrorState.error`, `lastScrcpyError` chứa stderr, `mirroringDeviceSerial == null`.
3. `stopMirroring` trong lúc `starting` đưa về `stopped` và tăng `mirrorSessionId`. Callback exit cũ không được retry và không ghi đè trạng thái.
4. Hết ngân sách embed (delay 0) mà không embed: trạng thái `error`, không nằm ở `starting`.
5. `launchStandaloneMirroring` khi starter ném lỗi: trả `false`, `lastScrcpyError` là lỗi mới, không phải chuỗi cũ.

`embedMirror` trong test sẽ ném `MissingPluginException`. Bắt lỗi đó như code hiện tại. Đừng để test chờ 8 giây.

---

## Ngoài phạm vi

- Không sửa số preset, schema profile, hay copy EN / VI / ZH đang đúng.
- Không đổi `selectDevice` thành “giữ mirror khi đổi máy”.
- Không dọn 31 info analyzer cũ.
- Không bump version, không commit, trừ khi người dùng yêu cầu riêng.

---

## Kiểm chứng sau khi sửa

```text
dart format lib/modules/logic.dart lib/modules/ui/main_window.dart lib/modules/ui/localization.dart test/scrcpy_mirror_session_test.dart
flutter analyze --no-fatal-infos
flutter test
```

Kỳ vọng: analyze vẫn 0 error / 0 warning. `flutter test` pass toàn bộ, gồm test mới. Không còn pending timer từ vòng embed.

---

## Gợi ý đã đưa cho người dùng

1. Sửa retry: hạ trạng thái trước khi gọi lại `launchMirroring`. Nếu retry không chạy thì chuyển sang `error` để nút Launch dùng lại được. Skill: `flutter-debugger`.
2. Cho phép bấm Stop khi `starting`, và hiện toast từ `lastScrcpyError` khi scrcpy thoát lỗi. Skill: `flutter-project-rules`.
3. Thêm test cho session id, retry một lần, embed timeout, và `selectDevice` dừng phiên đang chạy. Skill: `flutter-debugger`.
4. Sửa `USERGUIDE.md` cho khớp: đổi thiết bị sẽ dừng mirror đang chạy. Skill: `app-docs-prep`.
