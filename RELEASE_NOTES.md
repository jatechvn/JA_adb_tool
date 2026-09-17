TAG=v1.7.4
TITLE=JA ADB Tool v1.7.4 — Đồng bộ thời gian NTP, Cố định cổng 5555 Wi-Fi và Lưới Quick Tools 12 ô
BODY=
## 🚀 Tính năng & Cải tiến nổi bật
- **Cấu hình & Đồng bộ Thời gian Máy chủ NTP (NTP Time Sync & Diagnostics):**
  - Giao thức NTP thuần Dart UDP cổng 123 (gói 48-byte) đo độ trễ RTT, stratum và thời gian server không cần bất kỳ script hay công cụ ngoài nào (không cần Python/PowerShell).
  - Quét dò dải mạng (/24 Subnet Scanner) siêu tốc phát hiện đồng thời 254 IP chỉ trong ~1.5 giây với cơ chế micro-pacing và z-drain buffer hoàn hảo.
  - Tự động so sánh độ lệch thời gian thực giữa thiết bị Android và máy tính PC với nhãn cảnh báo trực quan.
  - Cứu hộ đồng bộ 1-click trực tiếp theo giờ PC khi thiết bị nằm trong môi trường mạng kín/phòng lab không ra được Internet.
  - Tích hợp sẵn mẫu máy chủ Foxconn/Nội bộ (`10.81.184.80`, `10.81.184.81`) và Công cộng (`time.google.com`, `pool.ntp.org`, `time.cloudflare.com`).
  - Khung nhật ký chẩn đoán chuyên sâu: `dumpsys time_detector`, `dumpsys network_time_update_service` và NTP logcat.
- **Cố định cổng 5555 & Tự động kết nối Wireless ADB:**
  - Cố định vĩnh viễn cổng `5555` qua thuộc tính hệ thống Android `service.adb.tcp.port` và `persist.adb.tcp.port`.
  - Tự động nhận diện IP Wi-Fi thông minh 3 tầng (DHCP, `ip addr show wlan0`, `ip route`).
  - Tự động dọn dẹp các endpoint cũ/cổng ngẫu nhiên rác khi kết nối thành công.
- **Tối ưu hóa toàn diện tab Quick Tools & Lưới 12 ô cân xứng tuyệt đối:**
  - Tái cấu trúc lưới phím tắt thành 12 ô với `LayoutBuilder` thích ứng đa độ phân giải (6x2, 4x3, 3x4, 2x6) không còn ô nào bị lẻ loi ở cuối hàng.
  - Bổ sung 2 phím tắt nhanh: `Cấu hình & Đồng bộ NTP` (highlight cyan) và `Cài đặt Ngày & Giờ`.
  - Tích hợp lệnh `Cấu hình & Đồng bộ NTP` vào Command Palette (`Ctrl+K`).
  - Tối ưu Bento Card nhỏ gọn cho Bàn phím điều hướng 6 nút, Khối điều khiển nguồn 4 màu, Công cụ gõ văn bản/ADB console và Banner Gnirehtet.

## 📖 Đồng bộ tài liệu & Metadata
- Cập nhật phiên bản v1.7.4+13 trên toàn bộ hệ thống: `pubspec.yaml`, `ABOUT.txt`, `README.md`, `USERGUIDE.md`, `CHANGELOG.md` và hộp thoại Giới thiệu / Hướng dẫn sử dụng trong app (EN / VI / ZH).

## 📦 Windows Portable Package
- Giải nén thư mục `JA_adb_tool_v1.7.4_Windows_x64` và chạy trực tiếp `ja_adb_tool.exe`.
- Chạy `debug.bat` để mở chế độ chẩn đoán kèm badge `DEBUG · v1.7.4 (build time)`.
- Gói release đóng gói dạng thư mục cha tiêu chuẩn, loại bỏ an toàn dữ liệu tạm và file cấu hình cá nhân.

## ✅ Kiểm chứng chất lượng
- Toàn bộ 53/53 tests tự động vượt qua (100% pass).
- Dart code formatting và analyzer sạch lỗi.
