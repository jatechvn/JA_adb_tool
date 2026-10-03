TAG=v1.10.1
TITLE=JA ADB Tool v1.10.1 — Native Window Title & Windows Metadata Display
BODY=
## 🐛 Sửa lỗi & Tối ưu hóa nổi bật
- **🪟 Đồng bộ Tiêu đề Cửa sổ Native & Metadata Windows (Native Window Title & Windows Metadata Display):**
  - Cập nhật tiêu đề cửa sổ Win32 gốc (`window.Create`) từ tên tệp thực thi `ja_adb_tool` thành tên ứng dụng chính thức `JA ADB Tool`.
  - Truyền trực tiếp tiêu đề cửa sổ `title.c_str()` trong `CreateWindow` cho toàn bộ các phiên bản Windows (Windows 10 & 11), đảm bảo thanh Taskbar, Alt+Tab, Task Manager và tooltip hiển thị tên ứng dụng chuẩn xác.
  - Cập nhật metadata nhị phân trong `Runner.rc`: `FileDescription` và `ProductName` được đặt thành `JA ADB Tool` thay vì tên thực thi `ja_adb_tool`.
- **🛡️ Cố định Tràn Layout Thanh Thiết bị Ngang (`DeviceHorizontalTabBar` Layout Hardening):**
  - Bọc chuỗi văn bản `no_device_connected` trong `Flexible` kèm `TextOverflow.ellipsis`, loại bỏ hoàn toàn ngoại lệ tràn RenderFlex 4.4px trong quá trình co giãn sidebar ở độ phân giải 1280x800.

## 📖 Đồng bộ tài liệu & Metadata
- Cập nhật phiên bản v1.10.1+22 trên toàn bộ hệ thống: `pubspec.yaml`, `ABOUT.txt`, `constants.dart`, `Runner.rc`, `install.bat`, `README.md`, `USERGUIDE.md`, `CHANGELOG.md` và các chuỗi UI.

## 📦 Windows Portable Package & LAN OTA
- Giải nén thư mục `JA_adb_tool_v1.10.1_Windows_x64` và chạy trực tiếp `ja_adb_tool.exe`.
- Chạy `debug.bat` để mở chế độ chẩn đoán kèm badge `DEBUG · v1.10.1 (build time)`.
- Đồng bộ gói cập nhật OTA lên máy chủ nội bộ `\\10.81.141.226\temp\FBT\JA_PROJECT\JA_Update\JA_adb_tool`.

## ✅ Kiểm chứng chất lượng
- Toàn bộ 212/212 tests tự động vượt qua (100% pass rate).
- Dart code formatting và analyzer sạch lỗi (0 errors, 0 warnings).


