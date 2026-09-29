TAG=v1.9.0
TITLE=JA ADB Tool v1.9.0 — Split APK & XAPK Cloner, Official Brand Identity & Auto-Refresh Apps
BODY=
## 🚀 Tính năng & Cải tiến nổi bật
- **🧩 Động cơ Nhân bản Split APK & Gói XAPK Hoàn chỉnh (Split APK & XAPK Cloner Engine):**
  - **Hỗ trợ toàn diện APK đơn và Split APKs / XAPK:** Tự động giải nén, phân tích `manifest.json`, xác định base APK và các split configs (`config.arm64_v8a`, `config.xxhdpi`), nhân bản base APK kết hợp vá nhị phân AXML và cập nhật split manifest.
  - **Xử lý tài nguyên OBB đi kèm:** Tự động phát hiện và trích xuất thư mục OBB từ gói XAPK, đổi tên đường dẫn theo Package ID mới (`Android/obb/<new_package>/`) và đẩy (ADB push) chuẩn xác vào bộ nhớ thiết bị.
  - **Kiến trúc đa luồng Isolate an toàn (`compute` / `Isolate.run`):** Chuyển toàn bộ quá trình đọc/ghi ZIP, phân tích nhị phân AXML và giải nén sang worker isolate riêng biệt, đảm bảo giao diện luôn mượt mà.
  - **Bảo mật giới hạn Archive (`XapkArchiveService`):** Chống ZIP Slip, chống bom nén ZIP (tối đa 1 GB nén, 2 GB bung, 512 entries), chặn đường dẫn không an toàn hoặc symbolic link trước khi ghi đĩa.
- **🔄 Tự động Làm mới Danh sách Ứng dụng Thiết bị (Auto-Refresh App List):**
  - Tự động kích hoạt `loadApps()` ngay sau khi cài đặt hoặc nhân bản thành công qua `AppClonerDialog`, `installApkPath`, `installPackages`, hoặc khi đóng hộp thoại nhân bản, giúp tab App Manager luôn hiển thị tức thì các ứng dụng mới.
- **🎨 Bộ Nhận diện Thương hiệu & Logo Ứng dụng Chính thức (Brand Identity & App Icon):**
  - Tích hợp biểu tượng thương hiệu chính thức (Concept Dual Mirror & Clone matrix) vào file thực thi Windows Desktop (`windows/runner/resources/app_icon.ico` & `assets/images/logo.ico`).
- **🔐 Cô lập Tìm kiếm Công cụ Ký (`ApkSigner` Isolation & Hardening):**
  - Khắc phục nguy cơ bảo mật duyệt ngược cây thư mục cha và tự sao chép file JAR; chỉ chấp nhận `bin/uber-apk-signer.jar` đặt cạnh file thực thi hoặc đường dẫn tuyệt đối cấu hình tường minh.
  - Tự động đóng gói và tích hợp sẵn `uber-apk-signer.jar` vào `bin/` và `dist/bin/` trong kịch bản đóng gói `build.bat`.

## 📖 Đồng bộ tài liệu & Metadata
- Cập nhật phiên bản v1.9.0+20 trên toàn bộ hệ thống: `pubspec.yaml`, `ABOUT.txt`, `constants.dart`, `install.bat`, `README.md`, `USERGUIDE.md`, `CHANGELOG.md` và các chuỗi UI.

## 📦 Windows Portable Package & LAN OTA
- Giải nén thư mục `JA_adb_tool_v1.9.0_Windows_x64` và chạy trực tiếp `ja_adb_tool.exe`.
- Chạy `debug.bat` để mở chế độ chẩn đoán kèm badge `DEBUG · v1.9.0 (build time)`.
- Đồng bộ gói cập nhật OTA lên máy chủ nội bộ `\\10.81.141.226\temp\FBT\JA_PROJECT\JA_Update\JA_adb_tool`.

## ✅ Kiểm chứng chất lượng
- Toàn bộ 171/171 tests tự động vượt qua (100% pass rate).
- Dart code formatting và analyzer sạch lỗi (0 errors, 0 warnings).

