TAG=v1.11.0
TITLE=JA ADB Tool v1.11.0 — Smart Upload Engine & Responsive Explorer Toolbar
BODY=
## 🚀 Động cơ Tải lên Thông minh & Nâng cấp Thanh Công cụ File Explorer
- **📁 Nút Tải lên Trực tiếp 1-Click & Phản hồi Tức thì:** Tách nút Upload thành 2 hành động độc lập: Tải lên Tệp và Tải lên Thư mục. Hiển thị loading spinner ngay lập tức (0ms) trong thời gian Windows File Picker khởi tạo.
- **⚡ Động cơ Tải lên Thông minh (`SmartUploadService`):** Lập kế hoạch tải lên bất đồng bộ, tự động phát hiện xung đột tệp và hỗ trợ hộp thoại giải quyết xung đột (`UploadConflictDialog`: Ghi đè, Bỏ qua, Đổi tên) cùng hộp thoại theo dõi tiến trình trực quan (`UploadProgressDialog`).
- **🚀 Khắc phục Nghẽn ADB Daemon & Vòng lặp Quét Thư viện Ảnh:** Sửa triệt để lỗi lặp quét 5s định kỳ của ADB media query khi thư viện trống, loại bỏ cờ `--limit` không hợp lệ, giải phóng tài nguyên cho các lệnh thao tác tệp nhanh nhạy tức thì.
- **📂 Tối ưu Tạo Thư mục:** Phản hồi icon xoay tức thì khi tạo thư mục, hỗ trợ bấm Enter để xác nhận trong `CreateFolderDialog`, và bổ sung thông báo toast thành công (EN, VI, ZH).
- **🗂️ Tối ưu Điều hướng Tab & Thiết bị:** Khởi tạo tab theo yêu cầu (`IndexedStack`), loại bỏ hiện tượng giật lag khi chuyển đổi giữa các tab và thiết bị.

## 📖 Đồng bộ Tài liệu & Metadata
- Cập nhật phiên bản v1.11.0+24 trên toàn bộ hệ thống: `pubspec.yaml`, `ABOUT.txt`, `constants.dart`, `Runner.rc`, `install.bat`, `docs/AI_HANDOFF.md`, `README.md`, `USERGUIDE.md`, `CHANGELOG.md`.

## 📦 Windows Portable Package & LAN OTA
- Giải nén thư mục `JA_adb_tool_v1.11.0_Windows_x64` và chạy trực tiếp `ja_adb_tool.exe`.
- Chạy `debug.bat` để mở chế độ chẩn đoán kèm badge `DEBUG · v1.11.0 (build time)`.
- Đồng bộ gói cập nhật OTA lên máy chủ nội bộ `\\10.81.141.226\temp\FBT\JA_PROJECT\JA_Update\JA_adb_tool`.

## ✅ Kiểm chứng Chất lượng
- Toàn bộ 242/242 tests tự động vượt qua (100% pass rate).
- Dart code formatting và analyzer sạch hoàn toàn (0 errors, 0 warnings).
