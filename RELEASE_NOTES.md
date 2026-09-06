TAG=v1.7.2
TITLE=JA ADB Tool v1.7.2 — Sửa lỗi tác vụ thiết bị và bảo vệ download
BODY=
## 🐛 Sửa lỗi
- Giữ nguyên thiết bị đích cho sync, upload, cài APK/XAPK/OBB và tải media hàng loạt khi đổi thiết bị trên giao diện.
- Tải File Explorer/Latest Media qua file tạm; chỉ thay file cũ khi thành công, giữ nguyên bản cũ nếu lỗi hoặc hủy.
- Bỏ kết quả thư mục, danh sách app và nhãn app đã lỗi thời sau khi đổi thiết bị hoặc điều hướng.

## 🎨 Giao diện và tài liệu
- Tích hợp Glass dropdown tìm kiếm/chọn nhiều mục và tab điều hướng thích ứng.
- Đồng bộ v1.7.2+11, About, README, CHANGELOG, USERGUIDE và hướng dẫn trong app EN/VI/ZH.

## 📦 Windows portable
- Giải nén thư mục JA_adb_tool_v1.7.2_Windows_x64 rồi chạy ja_adb_tool.exe.
- Chạy debug.bat để bật chẩn đoán. Gói không chứa config hoặc logs cá nhân.
- Chưa kiểm thử end-to-end với thiết bị Android thật.

## ✅ Kiểm chứng
- 32/32 tests pass, gồm 8 regression tests mới.
- dart format . đã chạy; dart analyze không có error/warning, còn 21 info.
- Windows Release x64 build thành công.
