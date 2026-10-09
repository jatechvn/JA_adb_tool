TAG=v1.12.0
TITLE=JA ADB Tool v1.12.0 — External Physical Keyboard Support & File Explorer Operations
BODY=
## ⌨️ Hỗ trợ Bàn phím Rời & Luồng Focus Win32 cho Scrcpy Screen Mirror
- **⌨️ Hỗ trợ Gõ Phím Trực tiếp từ Bàn phím Rời:** Khắc phục triệt để lỗi không thể gõ phím từ bàn phím rời PC vào cửa sổ chiếu màn hình Scrcpy khi nhúng. Tích hợp Win32 `AttachThreadInput`, cờ `WS_TABSTOP`, và xử lý `WM_MOUSEACTIVATE` giúp cửa sổ Scrcpy tự động nhận diện và bắt tiêu điểm bàn phím mượt mà ngay khi click chuột.
- **⚡ Cấu hình Scrcpy Tối ưu:** Bổ sung tham số Scrcpy `--keyboard=sdk` và `--prefer-text` tối ưu hóa khả năng tương thích gõ văn bản và ký tự đặc biệt.
- **📝 Phiên Nhập liệu Helper IME (`HelperImeSession` & `HelperImeDialog`):** Tích hợp dịch vụ quản lý phiên bàn phím ảo trợ lý, tự động ghi nhớ bộ gõ gốc của Android, kích hoạt tạm thời khi cần nhập văn bản tiếng Việt/ký tự đặc biệt và hoàn trả chính xác bộ gõ ban đầu khi đóng phiên hoặc chuyển thiết bị. Hỗ trợ các phím Backspace, Enter/Search và gửi văn bản mã hóa an toàn UTF-8/Base64.

## 📁 Thao tác Tệp Tin Mở rộng: Sao chép (Copy) & Di chuyển (Move) trong File Explorer
- **📋 Sao chép & Di chuyển Tệp/Thư mục Toàn diện:** Bổ sung nút bấm và menu ngữ cảnh cho cả hai thao tác Sao chép (Copy) và Di chuyển (Move) đối với tệp và thư mục trên Android kèm hộp thoại duyệt thư mục đích.
- **⚡ Khắc phục Lỗi Đóng băng Đổi tên & Hộp kiểm:** Khắc phục lỗi khiến các tính năng chọn hàng, chọn nhiều, đổi tên không phản hồi khi chưa nhấn các nút Tải lên/Tạo thư mục/Làm mới do đồng bộ trạng thái `AppPowerGate`.

## 📖 Đồng bộ Tài liệu & Metadata
- Cập nhật phiên bản v1.12.0+25 trên toàn bộ hệ thống: `pubspec.yaml`, `ABOUT.txt`, `constants.dart`, `Runner.rc`, `install.bat`, `docs/AI_HANDOFF.md`, `README.md`, `USERGUIDE.md`, `CHANGELOG.md`.

## 📦 Windows Portable Package & LAN OTA
- Giải nén thư mục `JA_ADB_Tool_v1.12.0_Windows_x64` và chạy trực tiếp `ja_adb_tool.exe`.
- Chạy `debug.bat` để mở chế độ chẩn đoán kèm badge `DEBUG · v1.12.0 (build time)`.
- Đồng bộ gói cập nhật OTA lên máy chủ nội bộ `\\10.81.141.226\temp\FBT\JA_PROJECT\JA_Update\JA_ADB_Tool`.

## ✅ Kiểm chứng Chất lượng
- Toàn bộ 257/257 tests tự động vượt qua (100% pass rate).
- Dart code formatting và analyzer sạch hoàn toàn (0 errors, 0 warnings).
