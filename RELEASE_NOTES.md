TAG=v1.7.5
TITLE=JA ADB Tool v1.7.5 — Trích xuất APK/XAPK, Droplist Bento Glass, Mở Thư Mục & Hệ Thống Toast
BODY=
## 🚀 Tính năng & Cải tiến nổi bật
- **📦 Tính năng Trích xuất APK & XAPK từ thiết bị (APK/XAPK Extraction):**
  - Trích xuất nhanh các ứng dụng đã cài đặt trên Android về máy tính cá nhân.
  - Tự động nhận diện Single APK (lưu dạng `.apk`) và đa phân mảnh Split APKs (tự động tạo `manifest.json` và đóng gói zip thành `.xapk` chuẩn tương thích hoàn toàn với bộ cài của tool).
  - Hỗ trợ cả thao tác đơn lẻ qua menu 3 chấm (`extract_apk_btn`) và thao tác hàng loạt qua Quick Batch Actions (`batch_extract_apk`).
  - Tích hợp nút hành động **Mở thư mục** (`open_folder`) trên thông báo Toast để 1-click mở và highlight file trong Windows Explorer (`explorer.exe /select,...`).
- **🎨 Cải tiến Droplist & Menu Bento Glass (Showcase Standard):**
  - Khắc phục triệt để hiện tượng menu sổ xuống và popup action bị trong suốt (~20% opacity) gây khó nhìn.
  - Thêm token màu `dropdownBg` và `dropdownBorder` với độ đục cao (Solid Glass Tint): Dark Mode `Color(0xF51E293B)` (96% opacity tint) với viền kính; Light Mode `Color(0xFAFFFFFF)` (98% opacity tint) với viền thanh lịch.
  - Áp dụng trên toàn bộ `PopupMenuButton` và 5 `DropdownButton` (Screen Mirroring, Screen Timeout, Animation Scale, USB Config, FolderSync direction) kèm bo viền 12px và đổ bóng 10dp.
  - Căn chỉnh viền và giữ nguyên kích thước, vị trí cho ô nhập Select Latest ở tab Latest Media.
- **📂 Bổ sung nút "Mở thư mục" trong Quản lý tệp (File Manager):**
  - Nâng cấp điều phối truyền tải `_runWithTransferProgress`. Cả tải file đơn lẻ và tải hàng loạt khi hoàn tất đều có nút **Mở thư mục** (`open_folder`), mở ngay thư mục đích trên PC thông qua Windows Explorer.
- **🔔 Chuẩn hóa Toàn Bộ Hệ Thống Toast Bento Floating Glass:**
  - Thay thế 100% thanh `ScaffoldMessenger.showSnackBar` đáy màn hình màu đen cũ sang Toast Bento Floating Glass lơ lửng, bo tròn góc 14px, làm mờ nền 16px, hỗ trợ nút bấm tương tác và tự động dọn dẹp toast cũ tránh chồng lấn.
  - Cung cấp extension tiện lợi `showSuccessToast`, `showErrorToast`, `showInfoToast` trên `BuildContext`.

## 📖 Đồng bộ tài liệu & Metadata
- Cập nhật phiên bản v1.7.5+14 trên toàn bộ hệ thống: `pubspec.yaml`, `ABOUT.txt`, `constants.dart`, `README.md`, `USERGUIDE.md`, `CHANGELOG.md` và hộp thoại Giới thiệu / Hướng dẫn sử dụng trong app (EN / VI / ZH).

## 📦 Windows Portable Package
- Giải nén thư mục `JA_adb_tool_v1.7.5_Windows_x64` và chạy trực tiếp `ja_adb_tool.exe`.
- Chạy `debug.bat` để mở chế độ chẩn đoán kèm badge `DEBUG · v1.7.5 (build time)`.
- Gói release đóng gói dạng thư mục cha tiêu chuẩn, loại bỏ an toàn dữ liệu tạm và file cấu hình cá nhân.

## ✅ Kiểm chứng chất lượng
- Toàn bộ 62/62 tests tự động vượt qua (100% pass).
- Dart code formatting và analyzer sạch lỗi (0 errors, 0 fatal issues).
