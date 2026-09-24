TAG=v1.8.1
TITLE=JA ADB Tool v1.8.1 — Cải tiến bộ nhân bản APK, Ký số v2 chuẩn mực & Chống tràn Layout
BODY=
## 🚀 Tính năng & Cải tiến nổi bật
- **🧬 Cải tiến công nghệ nhân bản APK (App Cloner AXML & Signing Hardening):**
  - **Attribute-aware AXML Patcher:** Vá nhị phân AXML thông minh theo ngữ cảnh thuộc tính XML, bảo toàn tuyệt đối namespace các lớp DEX, tự động mở rộng tên lớp tương đối (vd: `.MainActivity` ➔ `<pkg>.MainActivity`), thay thế chính xác nhãn `android:label` ứng dụng/activity mà không làm hỏng resource reference.
  - **Ký số v2 & Zipalign chuẩn mực:** Bổ sung `ApkSigner` tự động phát hiện `zipalign` và `apksigner` từ Android Build Tools, thực hiện căn chỉnh 4-byte và ký xác thực v2 với debug keystore. Báo lỗi rõ ràng và chuẩn xác nếu thiếu công cụ ký thay vì báo thành công ảo.
  - **Phân tách trạng thái:** Tách bạch thông báo đóng gói/ký APK thành công với kết quả nạp cài đặt vào máy.
- **🖥️ Tối ưu hiển thị giao diện & Chống tràn Layout (Layout Overflow Fixes):**
  - Thêm cơ chế co giãn linh hoạt (`Flexible`, `Expanded`) cho thanh Connected Device capsule ở độ phân giải 1280x800 và các cửa sổ hẹp.
  - Khắc phục triệt để lỗi tràn dòng trong bảng tùy chọn Scrcpy Options (`scrcpy_options`, `mirror_quality_preset`) trên tất cả các ngôn ngữ (EN, VI, ZH) và chế độ Sáng/Tối.
- **🧪 Mở rộng bộ kiểm thử hồi quy (Regression Test Suite):**
  - Bổ sung bộ kiểm thử `app_cloner_regression_test.dart` và `mirror_connected_layout_test.dart`, nâng tổng số test cases tự động lên 131 bài kiểm tra (100% pass).

## 📖 Đồng bộ tài liệu & Metadata
- Cập nhật phiên bản v1.8.1+17 trên toàn bộ hệ thống: `pubspec.yaml`, `ABOUT.txt`, `constants.dart`, `README.md`, `USERGUIDE.md`, `CHANGELOG.md` và hộp thoại Giới thiệu / Hướng dẫn sử dụng trong app (EN / VI / ZH).

## 📦 Windows Portable Package & LAN OTA
- Giải nén thư mục `JA_adb_tool_v1.8.1_Windows_x64` và chạy trực tiếp `ja_adb_tool.exe`.
- Chạy `debug.bat` để mở chế độ chẩn đoán kèm badge `DEBUG · v1.8.1 (build time)`.
- Đã đồng bộ gói cập nhật OTA lên máy chủ nội bộ `\\10.81.141.226\temp\FBT\JA_PROJECT\JA_Update\JA_adb_tool`.

## ✅ Kiểm chứng chất lượng
- Toàn bộ 131/131 tests tự động vượt qua (100% pass rate).
- Dart code formatting và analyzer sạch lỗi (0 errors, 0 fatal warnings).


