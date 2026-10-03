TAG=v1.10.0
TITLE=JA ADB Tool v1.10.0 — Flutter Desktop Power Optimizer, Screen Rotation & 240px Mirror Sidebar
BODY=
## 🚀 Tính năng & Cải tiến nổi bật
- **⚡ Động cơ Tối ưu Hóa Năng lượng & GPU Desktop Toàn diện (Flutter Desktop Power & GPU Optimizer):**
  - **Dịch vụ Quản lý Năng lượng Trung tâm (`AppPowerManager`):** Tự động phát hiện trạng thái cửa sổ ứng dụng (Visible, Hidden, Inactive, Minimized, Occluded) qua thông điệp Win32 (`WM_ACTIVATE`, `WM_SYSCOMMAND SC_MINIMIZE/SC_RESTORE`, `WM_WINDOWPOSCHANGED`).
  - **Cổng năng lượng toàn cục (`AppPowerGate`):** Tích hợp tại `MaterialApp.builder` bao phủ toàn bộ `Navigator`, routing và overlay tickers. Tự động tạm dừng hoặc giảm tần suất hoạt ảnh khi cửa sổ bị ẩn, minimize hoặc mất tiêu điểm, triệt tiêu tải CPU/GPU nhàn rỗi về mức tối thiểu.
  - **Bảo toàn chu kỳ và hướng hoạt ảnh Bento Glass (`MeshOrb` & `WaveIndicator`):** Lưu trữ chính xác vị trí pha và hướng quay/chuyển động (`_forwardPhase` / `_reversePhase`), chuyển đổi mượt mà khi phục hồi tiêu điểm mà không bị nhảy frame.
  - **Bảo vệ Epoch Guard cho Marquee Text & Chevrons (`AsymmetricMarqueeText`):** Đóng băng offset chữ chạy và chevrons khi mất tiêu điểm, ngăn chặn triệt để rò rỉ timer chạy ngầm khi unmount hoặc pause.
  - **Chế độ Ngủ Nhàn Rỗi Thông Minh (Idle Sleep Engine):** Tự động chuyển đổi sang trạng thái ngủ nhàn rỗi sau 12 giây không có tương tác người dùng, tự động đánh thức ngay khi có thao tác chuột hoặc bàn phím.
  - **Hộp thoại Cấu hình Năng lượng Trực quan (`PowerSettingsDialog`):** Cung cấp các tùy chọn bật/tắt Idle Sleep, cấu hình khoảng thời gian timeout nhàn rỗi và trạng thái hoạt ảnh.
- **🔄 Nút Xoay Màn hình Thiết bị 1 Chạm (Screen Rotation Button):**
  - Bổ sung nút xoay màn hình trực tiếp trên thanh công cụ Quick Tools và Mirror Control.
  - Tự động luân chuyển góc quay màn hình Android qua ADB shell (`0° ➔ 90° ➔ 180° ➔ 270°` qua `settings put system user_rotation`), hỗ trợ kiểm thử giao diện dọc/ngang tức thì.
- **📐 Tối ưu Hóa Diện tích Màn hình Nhúng Mirror Scrcpy (Mirror Display Area Maximization):**
  - Thu hẹp thanh cấu hình bên phải (Scrcpy Options Sidebar) từ 320px xuống 240px, mở rộng thêm **80px không gian quý giá** cho màn hình hiển thị trực tiếp Scrcpy.
  - Tái cấu trúc danh sách checkbox tùy chọn Scrcpy thành layout 1 cột chuẩn mực, thanh thoát, không bị tràn hay chen chúc.
  - Tinh chỉnh kích thước chữ profile dropdown xuống 11px gọn gàng, đồng bộ với phong cách thiết kế Bento Glass.

## 🐛 Sửa lỗi & Tối ưu hóa (Bug Fixes & Hardening)
- **🛡️ Giới hạn Chiều rộng Toast Tránh Che Màn hình Nhúng (`AppToast` Scrcpy Occlusion Protection):**
  - Giới hạn chiều rộng tối đa của thông báo nổi floating toast ở 420px, đảm bảo không bao giờ lan rộng che khuất cửa sổ native Scrcpy HWND đang nhúng bên cạnh.
- **⏰ Tối ưu Giao diện NTP Time Sync Dialog:**
  - Cố định và co giãn các trường hiển thị độ lệch và server name (`Flexible`/`Expanded`) trên màn hình độ phân giải 1280x800, loại bỏ hoàn toàn hiện tượng tràn pixel (overflow).
- **🧹 Dọn dẹp Tài nguyên & Quản lý Timer:**
  - Xử lý sạch sẽ 100% background timers khi unmount widget, loại bỏ rò rỉ bộ nhớ.

## 📖 Đồng bộ tài liệu & Metadata
- Cập nhật phiên bản v1.10.0+21 trên toàn bộ hệ thống: `pubspec.yaml`, `ABOUT.txt`, `constants.dart`, `Runner.rc`, `install.bat`, `README.md`, `USERGUIDE.md`, `CHANGELOG.md` và các chuỗi UI.

## 📦 Windows Portable Package & LAN OTA
- Giải nén thư mục `JA_adb_tool_v1.10.0_Windows_x64` và chạy trực tiếp `ja_adb_tool.exe`.
- Chạy `debug.bat` để mở chế độ chẩn đoán kèm badge `DEBUG · v1.10.0 (build time)`.
- Đồng bộ gói cập nhật OTA lên máy chủ nội bộ `\\10.81.141.226\temp\FBT\JA_PROJECT\JA_Update\JA_adb_tool`.

## ✅ Kiểm chứng chất lượng
- Toàn bộ 212/212 tests tự động vượt qua (100% pass rate).
- Dart code formatting và analyzer sạch lỗi (0 errors, 0 warnings).

