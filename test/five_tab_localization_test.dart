import 'package:flutter_test/flutter_test.dart';
import 'package:ja_adb_tool/modules/ui/localization.dart';

void main() {
  const translations = <String, List<String>>{
    'parent_directory': ['Go to parent directory', 'Về thư mục cha', '返回上级目录'],
    'delete_selected_success': [
      'Deleted selected items successfully!',
      'Đã xóa các mục đã chọn!',
      '已删除所选项！',
    ],
    'delete_some_failed': [
      'Failed to delete some items.',
      'Không thể xóa một số mục.',
      '部分项目删除失败。',
    ],
    'create_directory_failed': [
      'Failed to create directory',
      'Không thể tạo thư mục',
      '创建目录失败',
    ],
    'delete_item_failed': [
      'Failed to delete item.',
      'Không thể xóa mục.',
      '删除项目失败。',
    ],
    'retry_action': ['Retry', 'Thử lại', '重试'],
    'refresh_action': ['Refresh', 'Làm mới', '刷新'],
    'rescan_media': ['Rescan Media', 'Quét lại media', '重新扫描媒体'],
    'media_scan_hint': [
      'Scan the device media index to view photos and videos.',
      'Quét chỉ mục media trên thiết bị để xem ảnh và video.',
      '扫描设备媒体索引以查看照片和视频。',
    ],
    'split_apks_label': ['Split APKs', 'APK phân tách', '拆分 APK'],
    'xapk_archive': ['XAPK Bundle Archive', 'Gói lưu trữ XAPK', 'XAPK 应用包'],
    'standalone_apk': ['Standalone APK', 'APK độc lập', '独立 APK'],
    'target_device_ready': [
      'Target Device Ready',
      'Thiết bị đích sẵn sàng',
      '目标设备已就绪',
    ],
    'android_device_label': [
      'Android Device',
      'Thiết bị Android',
      'Android 设备',
    ],
    'sideload_hint': [
      'Select APK or XAPK files above to start sideloading.',
      'Chọn tệp APK hoặc XAPK phía trên để bắt đầu cài đặt.',
      '选择上方的 APK 或 XAPK 文件以开始安装。',
    ],
    'copied_package_id': ['Copied Package ID', 'Đã sao chép ID gói', '已复制包名'],
    'version_label': ['Version', 'Phiên bản', '版本'],
    'type_label': ['Type', 'Loại', '类型'],
    'terminal_log': ['Terminal Log', 'Nhật ký terminal', '终端日志'],
    'log_copied': [
      'Log copied to clipboard',
      'Đã sao chép nhật ký',
      '日志已复制到剪贴板',
    ],
    'installer_waiting': [
      'Ready. Waiting for installation to start...',
      'Sẵn sàng. Đang chờ bắt đầu cài đặt...',
      '已就绪。等待开始安装…',
    ],
    'copy_package_id': ['Copy Package ID', 'Sao chép ID gói', '复制包名'],
    'system_app_badge': ['SYSTEM APP', 'ỨNG DỤNG HỆ THỐNG', '系统应用'],
    'user_app_badge': ['USER APP', 'ỨNG DỤNG NGƯỜI DÙNG', '用户应用'],
    'frozen_badge': ['FROZEN', 'ĐÃ ĐÓNG BĂNG', '已冻结'],
    'active_badge': ['ACTIVE', 'HOẠT ĐỘNG', '活跃'],
    'processing_label': ['Processing...', 'Đang xử lý...', '正在处理…'],
    'sync_preview_failed': [
      'Unable to create sync preview.',
      'Không thể tạo bản xem trước đồng bộ.',
      '无法创建同步预览。',
    ],
    'sync_preview_title': ['Sync preview', 'Xem trước đồng bộ', '同步预览'],
    'files_to_delete': ['Files to delete', 'Tệp sẽ xóa', '待删除文件'],
    'confirm_delete_hint': [
      'Type DELETE to confirm',
      'Nhập DELETE để xác nhận',
      '输入 DELETE 确认',
    ],
    'browse_pc_folder': ['Browse PC Folder', 'Chọn thư mục PC', '选择电脑文件夹'],
    'restore_configuration': [
      'Restore configuration',
      'Khôi phục cấu hình',
      '恢复配置',
    ],
    'two_way_newest': ['Two-Way (Newest)', 'Hai chiều (mới nhất)', '双向（最新）'],
    'select_pc_directory': ['Select PC Directory', 'Chọn thư mục PC', '选择电脑目录'],
    'delta_sync_title': [
      'Bidirectional Delta Sync',
      'Đồng bộ thay đổi hai chiều',
      '双向增量同步',
    ],
    'delta_sync_hint': [
      'Only new or modified files based on file size and timestamp are transferred, keeping transfer cycles lightning fast.',
      'Chỉ truyền tệp mới hoặc thay đổi dựa trên kích thước và thời gian sửa đổi để đồng bộ nhanh hơn.',
      '仅按大小和时间戳传输新增或修改的文件，以加快同步。',
    ],
    'dry_run_title': [
      'Pre-flight Dry Run Verification',
      'Kiểm tra trước khi đồng bộ',
      '同步前预检',
    ],
    'dry_run_hint': [
      'A full scan preview is calculated before touching files. You will see exactly how many files will be added or modified.',
      'Quét xem trước khi thay đổi tệp, cho biết số tệp sẽ được thêm hoặc cập nhật.',
      '更改文件前先完整扫描，预览将新增或修改的文件数量。',
    ],
    'mirror_mode_title': [
      'Mirror Mode (Delete Extra)',
      'Chế độ phản chiếu (xóa tệp dư)',
      '镜像模式（删除多余文件）',
    ],
    'console_log': ['Console Log', 'Nhật ký console', '控制台日志'],
    'sync_waiting': [
      'Waiting for sync to start...',
      'Đang chờ bắt đầu đồng bộ...',
      '等待开始同步…',
    ],
    'items_count': ['{count} items', '{count} mục', '{count} 项'],
    'no_files_matching': [
      'No files matching "{query}"',
      'Không có tệp khớp "{query}"',
      '没有匹配“{query}”的文件',
    ],
    'error_details': ['Error: {error}', 'Lỗi: {error}', '错误：{error}'],
    'media_downloaded': [
      'Successfully downloaded {count} files to {path}',
      'Đã tải {count} tệp vào {path}',
      '已将 {count} 个文件下载到 {path}',
    ],
    'media_partial_download': [
      'Copy completed with warnings. Checked folder: {path}',
      'Sao chép hoàn tất nhưng có cảnh báo. Kiểm tra thư mục: {path}',
      '复制完成但有警告。请检查文件夹：{path}',
    ],
    'media_folder_set': [
      'Media download folder set to: {path}',
      'Thư mục tải media: {path}',
      '媒体下载文件夹已设为：{path}',
    ],
    'create_target_failed': [
      'Failed to create target directory: {error}',
      'Không thể tạo thư mục đích: {error}',
      '无法创建目标目录：{error}',
    ],
    'packages_prepared': [
      '{count} package(s) prepared for sequential installation.',
      'Đã chuẩn bị {count} gói để cài đặt lần lượt.',
      '已准备 {count} 个包以依次安装。',
    ],
    'copied_value': ['Copied: {value}', 'Đã sao chép: {value}', '已复制：{value}'],
    'installed_time': ['Installed: {time}', 'Đã cài: {time}', '安装时间：{time}'],
    'freeze_app_failed': [
      'Failed to freeze {app}',
      'Không thể đóng băng {app}',
      '无法冻结 {app}',
    ],
    'unfreeze_app_failed': [
      'Failed to unfreeze {app}',
      'Không thể bỏ đóng băng {app}',
      '无法解冻 {app}',
    ],
    'extracting_app': [
      'Extracting {app}...',
      'Đang trích xuất {app}...',
      '正在提取 {app}…',
    ],
    'extracting_apps': [
      'Extracting {count} apps...',
      'Đang trích xuất {count} ứng dụng...',
      '正在提取 {count} 个应用…',
    ],
    'sync_scanned': [
      'Scanned {pc} PC files and {android} Android files.',
      'Đã quét {pc} tệp PC và {android} tệp Android.',
      '已扫描 {pc} 个电脑文件和 {android} 个 Android 文件。',
    ],
    'sync_copy_count': [
      '{count} copy/update',
      '{count} sao chép/cập nhật',
      '复制/更新 {count} 项',
    ],
    'sync_delete_count': ['{count} delete', '{count} xóa', '删除 {count} 项'],
    'sync_more_files': [
      '… and {count} more file(s)',
      '… và {count} tệp khác',
      '…及其他 {count} 个文件',
    ],
    'sync_history_summary': [
      'Direction: {direction} | Mirror: {mirror}',
      'Hướng: {direction} | Phản chiếu: {mirror}',
      '方向：{direction} | 镜像：{mirror}',
    ],
    'yes_label': ['Yes', 'Có', '是'],
    'no_label': ['No', 'Không', '否'],
    'sync_status_label': [
      'Status: {status}',
      'Trạng thái: {status}',
      '状态：{status}',
    ],
    'sync_starting': ['Starting...', 'Đang bắt đầu...', '正在启动…'],
    'sync_scanning': ['Scanning...', 'Đang quét...', '正在扫描…'],
    'sync_comparing': ['Comparing...', 'Đang so sánh...', '正在比较…'],
    'sync_running': ['Syncing...', 'Đang đồng bộ...', '正在同步…'],
    'sync_completed': ['Completed', 'Hoàn tất', '已完成'],
    'sync_error': ['Error', 'Lỗi', '错误'],
    'sync_cancelled': ['Cancelled', 'Đã hủy', '已取消'],
    'sync_paused': ['Paused', 'Đã tạm dừng', '已暂停'],
  };
  for (final entry in ['en', 'vi', 'zh'].asMap().entries) {
    test('five-tab strings and placeholders in ${entry.value}', () {
      final provider = LanguageProvider.forTesting(entry.value);
      addTearDown(provider.dispose);
      for (final row in translations.entries) {
        expect(provider.tr(row.key), row.value[entry.key], reason: row.key);
        final args = <String, String>{
          for (final match in RegExp(r'\{(\w+)\}').allMatches(row.value.first))
            match.group(1)!: 'TEST',
        };
        final translated = provider.tr(row.key, args: args);
        expect(
          translated,
          isNot(contains(RegExp(r'\{\w+\}'))),
          reason: row.key,
        );
      }
    });
  }
}
