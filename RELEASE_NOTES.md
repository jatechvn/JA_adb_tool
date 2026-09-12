TAG=v1.7.3
TITLE=JA ADB Tool v1.7.3 — Tự động cài đặt Gnirehtet và thanh điều hướng thông minh 3 tầng
BODY=
## 🚀 Tính năng & Cải tiến nổi bật
- **Tự động cấu hình & cài đặt Gnirehtet Reverse Tethering:**
  - Tự động dò tìm `gnirehtet.apk` trong mọi thư mục nhúng (`bin/`, `bin/gnirehtet-rust-win64/`, thư mục gốc ứng dụng).
  - Tự động kiểm tra trên điện thoại Android và tự cài đặt `gnirehtet.apk` qua ADB trước khi chạy daemon `gnirehtet.exe`.
  - Thiết lập chính xác `workingDirectory`, `GNIREHTET_APK`, `ADB` và `PATH` giúp khắc phục triệt để lỗi `failed to stat gnirehtet.apk: No such file or directory`.
- **Thanh điều hướng SlidingPillTabBar thông minh 3 tầng:**
  - Tự động chuyển đổi 3 cấp độ hiển thị (Đầy đủ icon + nhãn, Chỉ hiển thị nhãn chữ giúp vừa vặn toàn bộ 7 tab tiếng Việt không bị khuất tab cuối, Thu gọn dạng thanh dock tương tác).
  - Hiệu ứng nảy đàn hồi (elastic bounce hint) khi khởi động hoặc đổi ngôn ngữ giúp người dùng nhận biết thanh có thể cuộn ngang.
  - Hỗ trợ cuộn ngang bằng con lăn chuột máy tính và nút chevrons kính mờ.

## 📖 Đồng bộ tài liệu & Metadata
- Cập nhật phiên bản v1.7.3+12 trên toàn bộ hệ thống: `pubspec.yaml`, `ABOUT.txt`, `README.md`, `USERGUIDE.md`, `CHANGELOG.md` và hộp thoại Giới thiệu / Hướng dẫn sử dụng trong app (EN / VI / ZH).

## 📦 Windows Portable Package
- Giải nén thư mục `JA_adb_tool_v1.7.3_Windows_x64` và chạy trực tiếp `ja_adb_tool.exe`.
- Chạy `debug.bat` để mở chế độ chẩn đoán kèm badge `DEBUG · v1.7.3 (build time)`.
- Gói release đóng gói dạng thư mục cha tiêu chuẩn, loại bỏ an toàn dữ liệu tạm và file cấu hình cá nhân.

## ✅ Kiểm chứng chất lượng
- Toàn bộ 32/32 tests tự động vượt qua (100% pass).
- Dart code formatting và analyzer sạch lỗi.
