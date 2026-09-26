TAG=v1.8.3
TITLE=JA ADB Tool v1.8.3 — APK Signing Keystore Studio & Multi-Generation ADB Time Sync
BODY=
## 🚀 Tính năng & Cải tiến nổi bật
- **🔐 Trung tâm Thiết lập Ký Ứng dụng APK Cloner (APK Signing Setup & Custom Keystore Studio):**
  - **Quản lý Keystore Tùy chỉnh (Custom Keystore Management):** Hỗ trợ nạp file Keystore (`.jks`, `.keystore`) cá nhân với cấu hình chi tiết mật khẩu Keystore, Key Alias và mật khẩu Key Alias.
  - **Tự động dò tìm công cụ SDK Build-Tools:** Cơ chế tự động phát hiện đường dẫn `apksigner` và `zipalign` từ Android SDK Build-Tools trên hệ thống hoặc cho phép người dùng chỉ định đường dẫn tùy chỉnh.
  - **Hộp thoại Cấu hình Trực quan (`ApkSigningSetupDialog`):** Cung cấp giao diện thiết lập trực quan, tính năng "Test Signature" xác thực thông tin chữ ký keystore ngay tức thì và tự động lưu cấu hình.
  - **Liên kết sửa lỗi 1 chạm:** Tích hợp nút thao tác trực tiếp "Configure Signing" trên thông báo lỗi của App Cloner, giúp cấu hình ngay khi phát hiện môi trường thiếu công cụ ký.
- **⏰ Động cơ Đồng bộ Thời gian ADB Đa Thế hệ (Multi-Generation ADB Time Sync Engine):**
  - **Hỗ trợ toàn diện Android 8.0 - Android 14+ (MT95, Android 13):** Sử dụng `cmd alarm set-time <epochMillis>`, thực thi trực tiếp bằng quyền `shell` UID 2000 mà không cần quyền Root và không bị Linux kernel chặn quyền `CAP_SYS_TIME` như lệnh `date` thông thường.
  - **Khắc phục triệt để lỗi Epoch 0 trên Android 5.1/Lollipop (2b69e02, MSM8226):** Loại bỏ hoàn toàn cú pháp `date -u @...` gây lỗi bộ phân tích của `toolbox` (hiểu sai cú pháp thành `0.0` và gọi `settimeofday(0, 0)` kéo lùi thời gian về năm 1969 dù vẫn trả về exit code 0).
  - **Chuỗi Fallback 4 tầng linh hoạt:** Tự động điều hướng qua các lệnh phù hợp theo từng đời Android: `cmd alarm set-time` ➔ `date -s YYYYMMDD.hhmmss` (chuẩn toolbox) ➔ `date -s "YYYY-MM-DD hh:mm:ss"` ➔ `date MMDDhhmmyyyy.ss`.
  - **Bộ tính độ lệch thời gian thông minh (`_calculateDrift`):** Bổ sung Regex hỗ trợ tự động bóc tách định dạng Linux Date tiêu chuẩn (`Day Mon DD HH:MM:SS TZ YYYY`) song song với chuẩn ISO, hiển thị độ lệch thời gian chính xác trên mọi thiết bị.
  - **Tương thích mạng đời cũ:** Thêm cơ chế broadcast legacy và `svc wifi` khi buộc đồng bộ thời gian trên các thiết bị Android cũ chưa có `cmd connectivity`.

## 📖 Đồng bộ tài liệu & Metadata
- Cập nhật phiên bản v1.8.3+19 trên toàn bộ hệ thống: `pubspec.yaml`, `ABOUT.txt`, `constants.dart`, `install.bat`, `README.md`, `USERGUIDE.md`, `CHANGELOG.md` và các chuỗi UI đa ngôn ngữ (EN / VI / ZH).

## 📦 Windows Portable Package & LAN OTA
- Giải nén thư mục `JA_adb_tool_v1.8.3_Windows_x64` và chạy trực tiếp `ja_adb_tool.exe`.
- Chạy `debug.bat` để mở chế độ chẩn đoán kèm badge `DEBUG · v1.8.3 (build time)`.
- Đã đồng bộ gói cập nhật OTA lên máy chủ nội bộ `\\10.81.141.226\temp\FBT\JA_PROJECT\JA_Update\JA_adb_tool`.

## ✅ Kiểm chứng chất lượng
- Toàn bộ 142/142 tests tự động vượt qua (100% pass rate).
- Dart code formatting và analyzer sạch lỗi (0 errors, 0 fatal warnings).
