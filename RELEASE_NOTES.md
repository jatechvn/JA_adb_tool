TAG=v1.8.2
TITLE=JA ADB Tool v1.8.2 — Thanh Tab Thiết bị Trải dài Ngang, Cuộn Chuột & Bật Nảy Marquee
BODY=
## 🚀 Tính năng & Cải tiến nổi bật
- **📱 Thanh Tab Thiết bị Trải dài Ngang (Horizontal Device Tab Bar):**
  - **Trải dài trực quan:** Thay thế toàn bộ menu chọn thiết bị dạng modal/droplist trước đây bằng danh sách các tab thiết bị xếp ngang trực tiếp trên thanh tiêu đề trung tâm (Header), cho phép quan sát nhanh và chuyển đổi thiết bị tức thì chỉ với 1 cú click chuột (`logic.selectDevice`).
  - **Cuộn ngang bằng con lăn chuột (Mouse Wheel Horizontal Scroll):** Tích hợp bộ lắng nghe `PointerScrollEvent` chuyển đổi mượt mà lực cuộn dọc của con lăn chuột thành chuyển động cuộn ngang khi di chuột qua thanh tab thiết bị.
  - **Bật nảy xúc giác khi quá kích thước (Elastic Bounce Overflow Hint):** Tự động phát hiện khi danh sách thiết bị vượt quá chiều ngang hiển thị, kích hoạt hiệu ứng peek-and-bounce đàn hồi (`Curves.elasticOut`) một lần để người dùng nhận biết ngay danh sách có thể cuộn ngang.
  - **Hiệu ứng Marquee bật nảy mép biên (Animated Marquee Bounce Edge Indicators):** Hiển thị các nút điều hướng chevron với gradient che mờ mép và chuyển động dao động nảy ngang nhịp nhàng liên tục (`Curves.easeInOutSine`), báo hiệu rõ ràng danh sách thiết bị còn kéo dài ở phía trước hoặc sau.
  - **Trạng thái thiết bị sắc nét:** Mỗi tab hiển thị biểu tượng điện thoại, chấm trạng thái kết nối màu ngọc lục bảo có hiệu ứng phát sáng neon, tên model thiết bị in đậm và mã Serial / phiên bản Android kiểu JetBrains Mono.
- **🛡️ Đảm bảo tương thích & Layout tối ưu (Layout Hardening):**
  - Tối ưu kích thước padding và ràng buộc không gian để tab bar hòa hợp liền mạch với kích thước cửa sổ 1280x800 chuẩn và không gây lỗi tràn giao diện (RenderFlex).
  - Tự động dự phòng thông minh: hiển thị viên nhãn "No Device Connected" khi không có thiết bị hoặc tự chọn thiết bị hiện tại nếu danh sách tạm thời chưa làm mới.
- **🧪 Bộ kiểm thử tự động toàn diện:**
  - Bổ sung bộ kiểm thử `test/device_horizontal_tab_bar_test.dart` và mở rộng toàn bộ test cases đạt 135/135 tests (100% pass).

## 📖 Đồng bộ tài liệu & Metadata
- Cập nhật phiên bản v1.8.2+18 trên toàn bộ hệ thống: `pubspec.yaml`, `ABOUT.txt`, `constants.dart`, `install.bat`, `README.md`, `USERGUIDE.md`, `CHANGELOG.md` và hộp thoại Giới thiệu / Hướng dẫn sử dụng trong app (EN / VI / ZH).

## 📦 Windows Portable Package & LAN OTA
- Giải nén thư mục `JA_adb_tool_v1.8.2_Windows_x64` và chạy trực tiếp `ja_adb_tool.exe`.
- Chạy `debug.bat` để mở chế độ chẩn đoán kèm badge `DEBUG · v1.8.2 (build time)`.
- Đã đồng bộ gói cập nhật OTA lên máy chủ nội bộ `\\10.81.141.226\temp\FBT\JA_PROJECT\JA_Update\JA_adb_tool`.

## ✅ Kiểm chứng chất lượng
- Toàn bộ 135/135 tests tự động vượt qua (100% pass rate).
- Dart code formatting và analyzer sạch lỗi (0 errors, 0 fatal warnings).
