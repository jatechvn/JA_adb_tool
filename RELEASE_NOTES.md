TAG=v1.7.6
TITLE=JA ADB Tool v1.7.6 — Cập nhật tự động qua mạng nội bộ LAN Over-The-Air (OTA)
BODY=
## 🚀 Tính năng & Cải tiến nổi bật
- **📡 Hệ thống Tự động cập nhật qua mạng nội bộ LAN Over-The-Air (LAN OTA Update):**
  - Tự động kiểm tra bản cập nhật mới trong nền khi khởi động app và hỗ trợ kiểm tra thủ công tức thì qua Command Palette (`Ctrl+Shift+P` / `Ctrl+K`) hoặc Settings.
  - Hỗ trợ cả đường dẫn thư mục chia sẻ mạng UNC SMB (`\\server\share\...`) và thư mục cục bộ/ổ đĩa mạng, kèm cơ chế xác thực thông tin đăng nhập tự động (`net use`).
  - Hệ thống so khớp phiên bản Semantic Versioning nghiêm ngặt (`SemanticVersion`), hỗ trợ cả manifest `update_manifest.json` và tự động phát hiện gói ZIP chuẩn `JA_adb_tool_v<version>_Windows_x64.zip`.
  - Quy trình giải nén phân đoạn an toàn qua PowerShell, xác minh tính hợp lệ của nhị phân Flutter (`ja_adb_tool.exe`, `flutter_windows.dll`, `data/app.so`) và kiểm tra mã băm SHA256 trước khi cài đặt.
  - Bộ cài đặt ngầm thông minh `apply_update.bat` với cơ chế chờ tiến trình cũ thoát theo PID, đồng bộ bản mới qua robocopy nhiều lượt retry, tự động backup phiên bản cũ và khởi động lại ứng dụng.
  - Giao diện thông báo cập nhật Bento Frosted Glass hiện đại hiển thị ghi chú phát hành dạng cuộn, thanh tiến trình tải thời gian thực kèm tốc độ truyền và đồng hồ đếm ngược tự động khởi động lại.
  - Tích hợp tab cấu hình riêng biệt "LAN OTA Update" trong Cài đặt đường dẫn (`PathsSettingsDialog`), cho phép kiểm tra kết nối máy chủ tức thì và đặt chu kỳ kiểm tra tự động.
  - Hỗ trợ đa ngôn ngữ đầy đủ (Tiếng Anh, Tiếng Việt, Tiếng Trung) với 28 khóa bản địa hóa mới.

## 📖 Đồng bộ tài liệu & Metadata
- Cập nhật phiên bản v1.7.6+15 trên toàn bộ hệ thống: `pubspec.yaml`, `ABOUT.txt`, `constants.dart`, `README.md`, `USERGUIDE.md`, `CHANGELOG.md` và hộp thoại Giới thiệu / Hướng dẫn sử dụng trong app (EN / VI / ZH).

## 📦 Windows Portable Package
- Giải nén thư mục `JA_adb_tool_v1.7.6_Windows_x64` và chạy trực tiếp `ja_adb_tool.exe`.
- Chạy `debug.bat` để mở chế độ chẩn đoán kèm badge `DEBUG · v1.7.6 (build time)`.
- Gói release đóng gói dạng thư mục cha tiêu chuẩn, loại bỏ an toàn dữ liệu tạm và file cấu hình cá nhân.

## ✅ Kiểm chứng chất lượng
- Toàn bộ 75/75 tests tự động vượt qua (100% pass).
- Dart code formatting và analyzer sạch lỗi (0 errors, 0 fatal issues).
