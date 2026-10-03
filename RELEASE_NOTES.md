TAG=v1.10.2
TITLE=JA ADB Tool v1.10.2 — App Name Title & Company Metadata Polish
BODY=
## 🎨 Tối ưu hóa Tiêu đề Ứng dụng & Đồng bộ Metadata
- **🪟 Chuẩn hóa Tiêu đề Cửa sổ Toàn diện (Application Window Title):**
  - Cập nhật `MaterialApp.title` thành `appName` (`JA ADB Tool`) đồng bộ 1:1 với tiêu đề Win32 gốc (`window.Create(L"JA ADB Tool")`), đảm bảo hiển thị đồng nhất tên ứng dụng trên Taskbar, Alt+Tab, Task Manager và tooltip thay vì tên tệp `.exe`.
- **🏷️ Hoàn thiện Metadata Nhị phân Windows (`Runner.rc` Company & Copyright Polish):**
  - Cập nhật trường `CompanyName` từ `"com.ja_tech"` thành `"JA Tech"`.
  - Cập nhật trường `LegalCopyright` thành `"Copyright (C) 2026 JA Tech. All rights reserved."`.
  - Đảm bảo toàn bộ thông tin nhị phân PE (`FileDescription`, `ProductName`, `InternalName`, `CompanyName`) hiển thị sắc nét, chuẩn thương hiệu `JA ADB Tool` trong Windows File Explorer Details và Task Manager.

## 📖 Đồng bộ tài liệu & Metadata
- Cập nhật phiên bản v1.10.2+23 trên toàn bộ hệ thống: `pubspec.yaml`, `ABOUT.txt`, `constants.dart`, `Runner.rc`, `install.bat`, `docs/AI_HANDOFF.md`, `README.md`, `USERGUIDE.md`, `CHANGELOG.md`.

## 📦 Windows Portable Package & LAN OTA
- Giải nén thư mục `JA_adb_tool_v1.10.2_Windows_x64` và chạy trực tiếp `ja_adb_tool.exe`.
- Chạy `debug.bat` để mở chế độ chẩn đoán kèm badge `DEBUG · v1.10.2 (build time)`.
- Đồng bộ gói cập nhật OTA lên máy chủ nội bộ `\\10.81.141.226\temp\FBT\JA_PROJECT\JA_Update\JA_adb_tool`.

## ✅ Kiểm chứng chất lượng
- Toàn bộ 212/212 tests tự động vượt qua (100% pass rate).
- Dart code formatting và analyzer sạch lỗi (0 errors, 0 warnings).



