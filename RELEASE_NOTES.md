TAG=v1.8.0
TITLE=JA ADB Tool v1.8.0 — App Cloner Studio (Nhân bản APK & Không gian kép) & Adaptive Terminal UI
BODY=
## 🚀 Tính năng & Cải tiến nổi bật
- **🧬 App Cloner Studio (Nhân bản ứng dụng chuyên sâu):**
  - **Standalone APK Cloning Engine:** Bộ phân tích và vá nhị phân AXML (`AndroidManifest.xml`) thuần Dart siêu tốc hỗ trợ cả UTF-8 lẫn UTF-16LE, đổi Package ID và tên App Label, tự động quét và vá Provider Authorities để triệt tiêu lỗi `INSTALL_FAILED_CONFLICTING_PROVIDER`, loại bỏ chữ ký cũ và tự động ký số bằng keystore debug.
  - **👥 Multi-User Dual Space Cloning:** Tận dụng Android Multi-User framework, quản lý hồ sơ người dùng Clone Space trực quan, tạo và xóa profile linh hoạt, cài đặt và khởi chạy ứng dụng độc lập trên không gian kép tức thì.
  - **💎 Bento Glassmorphic Modal:** Hộp thoại 2 tab hiện đại tích hợp chỉ báo tiến trình, nhật ký console thời gian thực, hỗ trợ cài ngay vào thiết bị hoặc xuất ra file trên máy tính.
- **🎨 Bảng Terminal Log thích ứng theo giao diện (Adaptive Theme Terminal Logs):**
  - Đồng bộ màu nền và màu chữ nhật ký theo chủ đề Sáng / Tối trong App Installer, Folder Sync và ADB Console.
  - Chữ xanh ngọc mint trên nền Slate đậm (Dark) và chữ xanh lục đậm tương phản cao trên nền Slate sáng (Light), loại bỏ bảng đen cố định lệch tông.
- **🛡️ Ổn định hóa phiên Scrcpy & Bố cục Sidebar:**
  - Hoàn thiện xử lý dọn dẹp phiên phản chiếu màn hình và loại bỏ lỗi tràn bố cục sidebar khi co giãn.
  - Tích hợp bộ cài đặt & gỡ bỏ Windows sạch sẽ (`install.bat`, `uninstall.bat`, `uninstall.ps1`).
- **🌐 Đồng bộ hóa đa ngôn ngữ (Trilingual L10n Sync):**
  - Bổ sung và đồng bộ đầy đủ các khóa chuỗi App Cloner trên cả 3 ngôn ngữ: Tiếng Anh (EN), Tiếng Việt (VI), và Tiếng Trung (ZH).

## 📖 Đồng bộ tài liệu & Metadata
- Cập nhật phiên bản v1.8.0+16 trên toàn bộ hệ thống: `pubspec.yaml`, `ABOUT.txt`, `constants.dart`, `README.md`, `USERGUIDE.md`, `CHANGELOG.md` và hộp thoại Giới thiệu / Hướng dẫn sử dụng trong app (EN / VI / ZH).

## 📦 Windows Portable Package
- Giải nén thư mục `JA_adb_tool_v1.8.0_Windows_x64` và chạy trực tiếp `ja_adb_tool.exe`.
- Chạy `debug.bat` để mở chế độ chẩn đoán kèm badge `DEBUG · v1.8.0 (build time)`.
- Gói release đóng gói dạng thư mục cha tiêu chuẩn, loại bỏ an toàn dữ liệu tạm và file cấu hình cá nhân.

## ✅ Kiểm chứng chất lượng
- Toàn bộ 115/115 tests tự động vượt qua (100% pass rate).
- Dart code formatting và analyzer sạch lỗi (0 errors, 0 fatal warnings).

