// lib/modules/ui/localization.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  static const _defaultLocale = 'en';
  static const _supportedLocales = {'en', 'vi', 'zh'};

  String _locale = _defaultLocale;
  Future<void>? _loadOperation;

  String get locale => _locale;

  LanguageProvider();

  /// Loads the persisted locale before the widget tree is built.
  ///
  /// The JSON store is the primary source because it works in portable
  /// Windows builds even when the SharedPreferences Windows plugin is not
  /// available. SharedPreferences remains a compatibility fallback for
  /// existing installations.
  Future<void> load() => _loadOperation ??= _loadLocale();

  List<File> _configCandidates() {
    final candidates = <File>[];
    final exeConfig = File(
      p.join(p.dirname(Platform.resolvedExecutable), 'config.json'),
    );
    final cwdConfig = File(p.join(Directory.current.path, 'config.json'));
    candidates.add(exeConfig);
    if (p.normalize(cwdConfig.path) != p.normalize(exeConfig.path)) {
      candidates.add(cwdConfig);
    }

    final appData = Platform.environment['APPDATA'];
    if (appData != null && appData.trim().isNotEmpty) {
      final appDataConfig = File(p.join(appData, 'JA ADB Tool', 'config.json'));
      if (!candidates.any(
        (file) => p.normalize(file.path) == p.normalize(appDataConfig.path),
      )) {
        candidates.add(appDataConfig);
      }
    }
    return candidates;
  }

  File _fallbackLocaleFile() {
    final appData = Platform.environment['APPDATA'];
    if (appData != null && appData.trim().isNotEmpty) {
      return File(p.join(appData, 'JA ADB Tool', 'locale.json'));
    }
    return File(
      p.join(p.dirname(Platform.resolvedExecutable), '.ja_adb_tool_locale'),
    );
  }

  String? _readLocaleFromFile(File file) {
    if (!file.existsSync()) return null;
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is Map) {
        final value = decoded['locale']?.toString();
        if (_supportedLocales.contains(value)) return value;
      }
    } catch (_) {
      // Try the next persistence source without preventing app startup.
    }
    return null;
  }

  String? _readConfigLocale() {
    for (final file in _configCandidates()) {
      final locale = _readLocaleFromFile(file);
      if (locale != null) return locale;
    }
    return _readLocaleFromFile(_fallbackLocaleFile());
  }

  Future<String?> _readSharedPreferencesLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString('app_locale');
      return _supportedLocales.contains(value) ? value : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadLocale() async {
    final persisted =
        _readConfigLocale() ?? await _readSharedPreferencesLocale();
    if (persisted != null && persisted != _locale) {
      _locale = persisted;
      notifyListeners();
    }
  }

  void _writeLocaleToFile(File file, String value) {
    Map<String, dynamic> data = <String, dynamic>{};
    if (file.existsSync()) {
      final content = file.readAsStringSync();
      if (content.trim().isNotEmpty) {
        final decoded = jsonDecode(content);
        if (decoded is Map) {
          data = Map<String, dynamic>.from(decoded);
        }
      }
    }
    data['locale'] = value;
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(data),
      flush: true,
    );
  }

  Future<void> _persistLocale(String value) async {
    final candidates = _configCandidates();
    final existing = candidates.where((file) => file.existsSync()).toList();
    final targets = existing.isNotEmpty ? existing : [candidates.first];
    var saved = false;
    for (final file in targets) {
      try {
        _writeLocaleToFile(file, value);
        saved = true;
        break;
      } catch (_) {
        // A read-only install directory can fall through to AppData.
      }
    }

    if (!saved) {
      try {
        _writeLocaleToFile(_fallbackLocaleFile(), value);
      } catch (_) {
        // Keep the in-memory locale even if every persistence location fails.
      }
    }
  }

  Future<void> setLocale(String value) async {
    if (!_supportedLocales.contains(value)) return;
    if (value == _locale) return;
    _locale = value;
    notifyListeners();
    await _persistLocale(value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_locale', value);
    } catch (_) {
      // JSON persistence above is the reliable Windows/portable path.
    }
  }

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_title': 'JA ADB Tool',
      'no_device_connected': 'No Device Connected',
      'select_device': 'Select an Android device from the sidebar to begin.',
      'adb_setup_title': 'Enable USB Debugging',
      'adb_setup_subtitle': 'Connect your Android phone in a few steps',
      'adb_image_disclaimer':
          'Illustrations use a generic Android layout; labels may vary by phone brand.',
      'adb_illustration_phone': 'Android',
      'adb_illustration_debug': 'USB Debug',
      'adb_image_zoom': 'Click to enlarge',
      'adb_step_1': 'Open Settings on your phone.',
      'adb_step_2':
          'Open About phone, then tap Build number seven times to unlock Developer options.',
      'adb_step_3': 'Open Developer options and turn on USB debugging.',
      'adb_step_4':
          'Connect the phone by USB, unlock it, and allow the RSA prompt.',
      'adb_setup_note':
          'Keep the phone unlocked while connecting. Then refresh the device list.',
      'adb_refresh_button': 'Refresh devices',
      'refresh_devices': 'Refresh Device List',
      'scrcpy_tab': 'Screen Mirror',
      'file_explorer_tab': 'File Explorer',
      'latest_media_tab': 'Latest Media',
      'installer_tab': 'App Installer',
      'settings_tab': 'Advanced Settings',
      'advanced_settings': 'Advanced Settings',
      'launch_mirror': 'Launch Mirroring',
      'launch_standalone_mirror': 'Launch Standalone Mirror',
      'stop_mirror': 'Stop Mirroring',
      'take_screenshot': 'Take Screenshot',
      'select_screenshot_folder': 'Select screenshot folder',
      'select_download_folder': 'Select media download folder',
      'predefined_label': 'Predefined:',
      'select_predefined_hint': 'Select a template...',
      'scrcpy_options': 'Mirroring Options',
      'scrcpy_profiles': 'Scrcpy Profiles',
      'scrcpy_profile_hint': 'Profile name',
      'save_profile': 'Save Profile',
      'delete_profile': 'Delete Profile',
      'profile_saved': 'Scrcpy profile saved.',
      'profile_delete_confirm': 'Delete profile "{name}"?',
      'stay_on_top': 'Always on Top',
      'fullscreen': 'Fullscreen',
      'no_control': 'Read-Only (No Control)',
      'keep_awake': 'Keep Device Awake',
      'borderless': 'Borderless Window',
      'disable_audio': 'Disable Audio (No Audio)',
      'pc_side': 'Computer (PC)',
      'android_side': 'Android Device',
      'download_selected': 'Download to PC',
      'upload_files': 'Upload to Android',
      'new_folder': 'New Folder',
      'delete_selected': 'Delete',
      'loading': 'Loading...',
      'status': 'Status',
      'path_to_adb': 'Path to adb.exe',
      'path_to_scrcpy': 'Path to scrcpy.exe',
      'path_settings_title': 'Tool Paths',
      'path_settings_subtitle':
          'Expand only when changing ADB, Scrcpy, or Gnirehtet',
      'select_apk_xapk': 'Select APK or XAPK file',
      'drag_drop_apk_xapk': 'Click to select APK/XAPK files',
      'packages_selected': '{count} packages selected',
      'selected_packages': 'Selected packages ({count})',
      'remove_package': 'Remove package',
      'install_button': 'Install to Device',
      'installing': 'Installing application...',
      'installation_success': 'Installation Completed Successfully!',
      'installation_failed': 'Installation Failed: {error}',
      'apk_details': 'Package Details',
      'no_media_found': 'No photos or videos found on device.',
      'latest_media_title': 'Filter Latest Photos & Videos',
      'media_load_success': 'Loaded {count} items from device.',
      'selected_count': 'Selected {count} items',
      'select_latest': 'Select latest:',
      'copying_media': 'Copying selected media to PC...',
      'copy_media_success': 'Successfully copied {count} files to {dir}',
      'copy_media_failed': 'Failed to copy files: {error}',
      'device_info': 'Device Info',
      'language': 'Language',
      'theme': 'Theme',
      'confirm_delete': 'Confirm Delete',
      'confirm_delete_msg':
          'Are you sure you want to delete "{name}"? This cannot be undone.',
      'create_folder': 'Create Folder',
      'folder_name': 'Folder Name',
      'cancel': 'Cancel',
      'confirm': 'Confirm',
      'create': 'Create',
      'save_settings': 'Save Settings',
      'settings_saved': 'Settings saved successfully!',
      'glass_settings_title': 'Glassmorphism',
      'glass_settings_subtitle': 'Customize blur & transparency',
      'glass_preview': 'Glassmorphism preview',
      'bg_blur_label': 'Main background blur',
      'bg_opacity_label': 'Main background opacity',
      'dialog_blur_label': 'Dialog blur',
      'dialog_opacity_label': 'Dialog opacity',
      'reset_defaults': 'Default',
      'user_guide': 'User Guide',
      'default_search_btn': 'Auto-detect Paths',
      'devices_found': '{count} devices found',
      'no_devices_found':
          'No devices found. Enable USB Debugging on your phone.',
      'wireless_adb': 'Wireless ADB',
      'wireless_adb_title': 'Connect over Wi-Fi',
      'wireless_adb_hint': 'Enter the device IP address and ADB port.',
      'wireless_host': 'Device IP address',
      'wireless_port': 'ADB port',
      'wireless_connect': 'Connect',
      'wireless_disconnect': 'Disconnect',
      'wireless_saved_endpoints': 'Saved endpoints',
      'wireless_no_endpoints': 'No saved wireless endpoints.',
      'diagnostics': 'Diagnostics',
      'diagnostics_title': 'Diagnostics Center',
      'diagnostics_hint': 'Check the local tools and device connection.',
      'diagnostics_run': 'Run diagnostics',
      'diagnostics_copy': 'Copy report',
      'diagnostics_no_report': 'Run a diagnostic check to see the report.',
      'workspace': 'Workspace',
      'workspace_title': 'Device Workspaces',
      'workspace_save_current': 'Save current device',
      'workspace_name': 'Workspace name',
      'workspace_empty': 'No saved workspaces.',
      'workspace_apply': 'Open',
      'workspace_delete': 'Delete',
      'workspace_saved': 'Workspace saved.',
      'command_palette': 'Command Palette',
      'command_palette_hint': 'Search commands…',
      'backup_restore': 'Backup & Restore',
      'backup_settings': 'Backup settings',
      'restore_settings': 'Restore settings',
      'backup_hint':
          'Export or restore paths, UI preferences, sync settings, profiles and workspaces.',
      'backup_exported': 'Settings backup exported.',
      'backup_imported':
          'Settings restored. Restart the app if a path does not update immediately.',
      'backup_failed': 'Could not export settings backup.',
      'backup_import_failed': 'Could not restore this backup file.',
      'check_updates': 'Check for updates',
      'update_title': 'Software Updates',
      'update_checking': 'Checking GitHub Releases…',
      'update_available': 'Version {version} is available.',
      'update_up_to_date': 'You are up to date ({version}).',
      'update_unavailable': 'Could not check GitHub Releases right now.',
      'open_release': 'Open release',
      'retry': 'Retry',
      'plugin_manager': 'Plugin Manager',
      'plugin_empty':
          'No plugin manifests found. Add trusted JSON manifests to the app data plugins folder.',
      'current_path': 'Current path: {path}',
      'quick_tools_tab': 'Quick Tools',
      'settings_shortcuts': 'Settings Shortcuts',
      'launcher_settings': 'Default Launcher',
      'lock_settings': 'Lock & Pass Settings',
      'language_settings': 'Device Language',
      'developer_options': 'Developer Options',
      'wifi_settings': 'Wi-Fi Settings',
      'display_settings': 'Display Settings',
      'accessibility_settings': 'Accessibility',
      'app_settings': 'Manage Apps',
      'about_phone': 'About Phone',
      'device_controls': 'Device Power Controls',
      'reboot_system': 'Reboot System',
      'reboot_bootloader': 'Reboot Fastboot',
      'reboot_recovery': 'Reboot Recovery',
      'power_off': 'Power Off',
      'hardware_keys': 'Hardware Key Simulation',
      'key_back': 'Back',
      'key_home': 'Home',
      'key_recents': 'Recents',
      'key_power': 'Power Screen',
      'key_volume_up': 'Vol +',
      'key_volume_down': 'Vol -',
      'text_input_tool': 'Text Input Sender',
      'text_input_placeholder':
          'Type text to send to active input field on device...',
      'send_text': 'Send to Device',
      'text_input_tab': 'Text Input',
      'adb_command_tab': 'ADB Command',
      'adb_command_placeholder':
          'Enter ADB command (e.g. getprop or shell pm list packages)...',
      'run_command_btn': 'Run Command',
      'clear_console_btn': 'Clear Console',
      'console_output_label': 'Console Output',
      'command_history_label': 'History:',
      'select_history_hint': 'Select from history...',
      'confirm_reboot': 'Confirm Reboot',
      'confirm_reboot_msg': 'Are you sure you want to reboot the device?',
      'confirm_power_off': 'Confirm Power Off',
      'confirm_power_off_msg': 'Are you sure you want to power off the device?',
      'app_freeze_tab': 'App Manager',
      'uninstall_btn': 'Uninstall',
      'force_stop_btn': 'Force Stop',
      'clear_data_btn': 'Clear Data',
      'launch_app_btn': 'Launch App',
      'uninstall_confirm': 'Are you sure you want to uninstall {app}?',
      'clear_data_confirm': 'Are you sure you want to clear data for {app}?',
      'search_apps_placeholder': 'Search by name or package...',
      'freeze_btn': 'Freeze',
      'unfreeze_btn': 'Unfreeze',
      'show_system_apps': 'Show System Apps',
      'refresh_list': 'Refresh List',
      'sort_apps_tooltip': 'Sort apps',
      'sort_by_name': 'Sort by Name',
      'sort_by_newest': 'Sort by Newest',
      'sort_by_oldest': 'Sort by Oldest',
      'no_apps_found': 'No applications found.',
      'select_all_apps': 'Select all visible apps',
      'batch_actions': 'Batch actions',
      'batch_freeze': 'Freeze selected',
      'batch_unfreeze': 'Unfreeze selected',
      'batch_force_stop': 'Force stop selected',
      'batch_uninstall': 'Uninstall selected',
      'batch_uninstall_confirm':
          'Uninstall {count} selected applications? This cannot be undone.',
      'batch_result': 'Completed: {success}; failed: {failed}',
      'reverse_tethering_title': 'Reverse Tethering (Gnirehtet)',
      'reverse_tethering_desc':
          'Share your computer\'s internet connection with your Android device via USB.',
      'start_reverse_tethering': 'Start Reverse Tethering',
      'stop_reverse_tethering': 'Stop Reverse Tethering',
      'gnirehtet_path': 'Gnirehtet Executable Path',
      'reverse_tethering_active': 'Reverse Tethering Active',
      'reverse_tethering_inactive': 'Reverse Tethering Inactive',
      'vpn_instruction':
          'Please unlock your device and approve the VPN connection permission prompt after starting.',
      'gnirehtet_logs': 'Gnirehtet Connection Logs',
      'about': 'About',
      'about_version': 'Version',
      'about_desc':
          'A Windows-first Android device management toolkit with Bento Liquid Glass UI, ADB/Scrcpy, wireless devices, diagnostics, workspaces, adaptive batch APK/XAPK installation, preloaded per-device Latest Media cache, Safe Sync v2, backup/restore, and safe release tooling.',
      'guide_title': 'How to Use',
      'guide_connect':
          '1. USB Driver & Connection: Install the USB driver for your Android device (e.g., Google or official OEM driver), then enable USB Debugging (ADB) in Developer Options on your phone before connecting via USB.',
      'guide_mirror':
          '2. Screen Mirror — Click "Launch Mirroring" to view and control your device screen on PC.',
      'guide_file':
          '3. File Explorer — Browse, upload, download, and delete files on your device.',
      'guide_sync':
          '4. Safe Sync v2 — Preview copies, updates, and deletions before syncing. Mirror Sync requires typing DELETE to confirm the exact destructive diff.',
      'guide_media':
          '5. Latest Media — Media starts loading after device discovery and is cached per device when switching; use Refresh for a fresh query.',
      'guide_install':
          '6. App Installer — On desktop, use the two-column layout: picker and queue on the left, details and an expanding readable log on the right. Select multiple APK/XAPK files, review the queue, then install them sequentially; archives are validated before extraction.',
      'guide_tether':
          '7. Reverse Tethering — Share your PC internet connection with the device via Gnirehtet.',
      'guide_tools':
          '8. Quick Tools — Send text, simulate keys, reboot, take screenshots, and more.',
      'guide_settings':
          '9. Productivity & settings — Configure tool paths, save Scrcpy profiles, connect over Wireless ADB, inspect Diagnostics and Device Workspaces, use Ctrl+K Command Palette, export/restore settings, and check GitHub Releases. The selected language is remembered between launches; debug.bat enables diagnostic timestamps.',
      'about_close': 'Close',
      'about_made_by': 'Made with ❤️ by JA Team',
      'project_website': 'Project website',
      'source_code': 'Source code',
      'open_link_failed': 'Unable to open the link.',
      'sync_folders_btn': 'Folder Sync',
      'sync_folders_title': 'Sync PC & Android Folders',
      'pc_folder_label': 'PC Folder:',
      'android_folder_label': 'Android Folder:',
      'sync_direction_label': 'Direction:',
      'sync_direction_pc_to_android': 'PC -> Android (Upload/Overwrite)',
      'sync_direction_android_to_pc': 'Android -> PC (Download/Overwrite)',
      'sync_direction_newest': 'Sync by Newest File (Skip duplicates)',
      'auto_sync_label': 'Auto-sync when device connected',
      'delete_extra_files_label': 'Delete extra files on target (Mirror Sync)',
      'start_sync_btn': 'Start Sync',
      'pause_sync_btn': 'Pause',
      'resume_sync_btn': 'Resume',
      'sync_status_idle': 'Configure paths and options, then click Start Sync.',
      'select_pc_folder_hint': 'Select PC folder...',
      'error_select_pc_folder': 'Please select a valid PC folder.',
      'recent_sync_title': 'Recent Configurations',
      'get_current_folder_btn': 'Get Current Folder',
      'copy_log_btn': 'Copy Log',
      'clear_log_btn': 'Clear Log',
      'sync_history_empty': 'No recent sync history.',
      'clear_history_btn': 'Clear History',
    },
    'vi': {
      'app_title': 'JA ADB Tool',
      'no_device_connected': 'Chưa kết nối thiết bị',
      'select_device':
          'Vui lòng chọn một thiết bị Android từ thanh bên để bắt đầu.',
      'adb_setup_title': 'Bật USB Debugging',
      'adb_setup_subtitle': 'Thực hiện vài bước để kết nối điện thoại Android',
      'adb_image_disclaimer':
          'Ảnh minh họa dùng giao diện Android chung; tên mục có thể khác theo hãng điện thoại.',
      'adb_illustration_phone': 'Android',
      'adb_illustration_debug': 'Gỡ lỗi USB',
      'adb_image_zoom': 'Bấm để phóng to',
      'adb_step_1': 'Mở Cài đặt trên điện thoại.',
      'adb_step_2':
          'Mở Giới thiệu điện thoại, rồi chạm 7 lần vào Số bản dựng để bật Tùy chọn nhà phát triển.',
      'adb_step_3': 'Mở Tùy chọn nhà phát triển và bật Gỡ lỗi USB.',
      'adb_step_4':
          'Kết nối điện thoại bằng cáp USB, mở khóa và cho phép hộp thoại xác thực RSA.',
      'adb_setup_note':
          'Giữ điện thoại mở khóa khi kết nối, sau đó làm mới danh sách thiết bị.',
      'adb_refresh_button': 'Làm mới thiết bị',
      'refresh_devices': 'Làm mới danh sách',
      'scrcpy_tab': 'Xem màn hình',
      'file_explorer_tab': 'Quản lý tệp',
      'latest_media_tab': 'Ảnh & Video mới',
      'installer_tab': 'Cài đặt APK/XAPK',
      'settings_tab': 'Cài đặt nâng cao',
      'advanced_settings': 'Cài đặt nâng cao',
      'launch_mirror': 'Khởi chạy truyền hình',
      'launch_standalone_mirror': 'Mở cửa sổ rời (Đa thiết bị)',
      'stop_mirror': 'Dừng truyền hình',
      'take_screenshot': 'Chụp ảnh màn hình',
      'select_screenshot_folder': 'Chọn thư mục lưu ảnh chụp',
      'select_download_folder': 'Chọn thư mục tải ảnh/video',
      'predefined_label': 'Lệnh/Văn bản mẫu:',
      'select_predefined_hint': 'Chọn một mẫu...',
      'scrcpy_options': 'Tùy chọn hiển thị',
      'scrcpy_profiles': 'Profile Scrcpy',
      'scrcpy_profile_hint': 'Tên profile',
      'save_profile': 'Lưu profile',
      'delete_profile': 'Xóa profile',
      'profile_saved': 'Đã lưu profile Scrcpy.',
      'profile_delete_confirm': 'Xóa profile "{name}"?',
      'stay_on_top': 'Luôn ở trên cùng',
      'fullscreen': 'Toàn màn hình',
      'no_control': 'Chỉ xem (Không điều khiển)',
      'keep_awake': 'Giữ thiết bị không tắt màn hình',
      'borderless': 'Cửa sổ không viền',
      'disable_audio': 'Tắt âm thanh (Không thu âm)',
      'pc_side': 'Máy tính (PC)',
      'android_side': 'Thiết bị Android',
      'download_selected': 'Tải xuống PC',
      'upload_files': 'Tải lên Android',
      'new_folder': 'Thư mục mới',
      'delete_selected': 'Xóa',
      'loading': 'Đang tải...',
      'status': 'Trạng thái',
      'path_to_adb': 'Đường dẫn adb.exe',
      'path_to_scrcpy': 'Đường dẫn scrcpy.exe',
      'path_settings_title': 'Đường dẫn công cụ',
      'path_settings_subtitle': 'Chỉ mở khi cần đổi ADB, Scrcpy hoặc Gnirehtet',
      'select_apk_xapk': 'Chọn tệp APK hoặc XAPK',
      'drag_drop_apk_xapk': 'Nhấp vào đây để chọn các tệp APK/XAPK',
      'packages_selected': 'Đã chọn {count} gói cài đặt',
      'selected_packages': 'Các gói đã chọn ({count})',
      'remove_package': 'Xóa gói',
      'install_button': 'Cài đặt vào thiết bị',
      'installing': 'Đang cài đặt ứng dụng...',
      'installation_success': 'Cài đặt thành công!',
      'installation_failed': 'Cài đặt thất bại: {error}',
      'apk_details': 'Chi tiết gói cài đặt',
      'no_media_found': 'Không tìm thấy ảnh hoặc video nào trên thiết bị.',
      'latest_media_title': 'Lọc ảnh & video mới nhất',
      'media_load_success': 'Đã tải {count} mục từ thiết bị.',
      'selected_count': 'Đã chọn {count} mục',
      'select_latest': 'Chọn mới nhất:',
      'copying_media': 'Đang sao chép các mục đã chọn sang PC...',
      'copy_media_success': 'Đã sao chép thành công {count} tệp vào {dir}',
      'copy_media_failed': 'Sao chép thất bại: {error}',
      'device_info': 'Thông tin thiết bị',
      'language': 'Ngôn ngữ',
      'theme': 'Giao diện',
      'confirm_delete': 'Xác nhận xóa',
      'confirm_delete_msg':
          'Bạn có chắc chắn muốn xóa "{name}"? Hành động này không thể hoàn tác.',
      'create_folder': 'Tạo thư mục',
      'folder_name': 'Tên thư mục',
      'cancel': 'Hủy',
      'confirm': 'Xác nhận',
      'create': 'Tạo mới',
      'save_settings': 'Lưu cấu hình',
      'settings_saved': 'Đã lưu cấu hình thành công!',
      'glass_settings_title': 'Glassmorphism',
      'glass_settings_subtitle': 'Tùy chỉnh độ mờ & độ trong suốt',
      'glass_preview': 'Xem trước Glassmorphism',
      'bg_blur_label': 'Độ mờ nền chính',
      'bg_opacity_label': 'Độ trong suốt nền chính',
      'dialog_blur_label': 'Độ mờ hộp thoại',
      'dialog_opacity_label': 'Độ trong suốt hộp thoại',
      'reset_defaults': 'Mặc định',
      'user_guide': 'Hướng dẫn sử dụng',
      'default_search_btn': 'Tự động tìm kiếm',
      'devices_found': 'Tìm thấy {count} thiết bị',
      'no_devices_found':
          'Không tìm thấy thiết bị. Hãy chắc chắn USB Debugging đã bật.',
      'wireless_adb': 'ADB không dây',
      'wireless_adb_title': 'Kết nối qua Wi-Fi',
      'wireless_adb_hint': 'Nhập địa chỉ IP và cổng ADB của thiết bị.',
      'wireless_host': 'Địa chỉ IP thiết bị',
      'wireless_port': 'Cổng ADB',
      'wireless_connect': 'Kết nối',
      'wireless_disconnect': 'Ngắt kết nối',
      'wireless_saved_endpoints': 'Thiết bị đã lưu',
      'wireless_no_endpoints': 'Chưa có thiết bị Wi-Fi đã lưu.',
      'diagnostics': 'Chẩn đoán',
      'diagnostics_title': 'Trung tâm chẩn đoán',
      'diagnostics_hint': 'Kiểm tra công cụ cục bộ và kết nối thiết bị.',
      'diagnostics_run': 'Chạy chẩn đoán',
      'diagnostics_copy': 'Sao chép báo cáo',
      'diagnostics_no_report': 'Chạy chẩn đoán để xem báo cáo.',
      'workspace': 'Workspace',
      'workspace_title': 'Workspace thiết bị',
      'workspace_save_current': 'Lưu thiết bị hiện tại',
      'workspace_name': 'Tên workspace',
      'workspace_empty': 'Chưa có workspace đã lưu.',
      'workspace_apply': 'Mở',
      'workspace_delete': 'Xóa',
      'workspace_saved': 'Đã lưu workspace.',
      'command_palette': 'Bảng lệnh',
      'command_palette_hint': 'Tìm kiếm lệnh…',
      'backup_restore': 'Sao lưu & Khôi phục',
      'backup_settings': 'Sao lưu cấu hình',
      'restore_settings': 'Khôi phục cấu hình',
      'backup_hint':
          'Xuất hoặc khôi phục đường dẫn, giao diện, đồng bộ, profile và workspace.',
      'backup_exported': 'Đã xuất bản sao cấu hình.',
      'backup_imported':
          'Đã khôi phục cấu hình. Hãy khởi động lại nếu đường dẫn chưa cập nhật ngay.',
      'backup_failed': 'Không thể xuất bản sao cấu hình.',
      'backup_import_failed': 'Không thể khôi phục tệp sao lưu này.',
      'check_updates': 'Kiểm tra cập nhật',
      'update_title': 'Cập nhật phần mềm',
      'update_checking': 'Đang kiểm tra GitHub Releases…',
      'update_available': 'Đã có phiên bản {version}.',
      'update_up_to_date': 'Bạn đang dùng bản mới nhất ({version}).',
      'update_unavailable': 'Chưa thể kiểm tra GitHub Releases lúc này.',
      'open_release': 'Mở release',
      'retry': 'Thử lại',
      'plugin_manager': 'Quản lý plugin',
      'plugin_empty':
          'Chưa có plugin manifest. Chỉ thêm JSON manifest đáng tin cậy vào thư mục plugins của app.',
      'current_path': 'Đường dẫn hiện tại: {path}',
      'quick_tools_tab': 'Tính năng nhanh',
      'settings_shortcuts': 'Phím tắt Cài đặt',
      'launcher_settings': 'Launcher mặc định',
      'lock_settings': 'Khóa màn hình & Mật khẩu',
      'language_settings': 'Ngôn ngữ thiết bị',
      'developer_options': 'Tùy chọn nhà phát triển',
      'wifi_settings': 'Cài đặt Wi-Fi',
      'display_settings': 'Cài đặt màn hình',
      'accessibility_settings': 'Hỗ trợ tiếp cận',
      'app_settings': 'Quản lý ứng dụng',
      'about_phone': 'Thông tin điện thoại',
      'device_controls': 'Điều khiển & Khởi động',
      'reboot_system': 'Khởi động lại',
      'reboot_bootloader': 'Vào Fastboot',
      'reboot_recovery': 'Vào Recovery',
      'power_off': 'Tắt nguồn',
      'hardware_keys': 'Phím điều hướng ảo',
      'key_back': 'Trở về (Back)',
      'key_home': 'Trang chủ (Home)',
      'key_recents': 'Gần đây (Recents)',
      'key_power': 'Nút Nguồn',
      'key_volume_up': 'Tăng Âm',
      'key_volume_down': 'Giảm Âm',
      'text_input_tool': 'Công cụ nhập văn bản nhanh',
      'text_input_placeholder':
          'Nhập văn bản cần gửi tới ô nhập liệu trên điện thoại...',
      'send_text': 'Gửi tới điện thoại',
      'text_input_tab': 'Gửi văn bản',
      'adb_command_tab': 'Lệnh ADB',
      'adb_command_placeholder':
          'Nhập lệnh ADB (ví dụ: getprop hoặc shell pm list packages)...',
      'run_command_btn': 'Chạy lệnh',
      'clear_console_btn': 'Xóa Console',
      'console_output_label': 'Kết quả Console',
      'command_history_label': 'Lịch sử:',
      'select_history_hint': 'Chọn lệnh từ lịch sử...',
      'confirm_reboot': 'Xác nhận khởi động lại',
      'confirm_reboot_msg':
          'Bạn có chắc chắn muốn khởi động lại thiết bị không?',
      'confirm_power_off': 'Xác nhận tắt nguồn',
      'confirm_power_off_msg':
          'Bạn có chắc chắn muốn tắt nguồn thiết bị không?',
      'app_freeze_tab': 'Quản lý ứng dụng',
      'uninstall_btn': 'Gỡ cài đặt',
      'force_stop_btn': 'Buộc dừng',
      'clear_data_btn': 'Xóa dữ liệu',
      'launch_app_btn': 'Mở ứng dụng',
      'uninstall_confirm': 'Bạn có chắc chắn muốn gỡ cài đặt {app} không?',
      'clear_data_confirm':
          'Bạn có chắc chắn muốn xóa dữ liệu của {app} không?',
      'search_apps_placeholder': 'Tìm theo tên hoặc package...',
      'freeze_btn': 'Đóng băng',
      'unfreeze_btn': 'Rã đông',
      'show_system_apps': 'Hiện ứng dụng hệ thống',
      'refresh_list': 'Làm mới danh sách',
      'sort_apps_tooltip': 'Sắp xếp ứng dụng',
      'sort_by_name': 'Sắp xếp theo Tên',
      'sort_by_newest': 'Sắp xếp theo Ngày mới nhất',
      'sort_by_oldest': 'Sắp xếp theo Ngày cũ nhất',
      'no_apps_found': 'Không tìm thấy ứng dụng.',
      'select_all_apps': 'Chọn tất cả ứng dụng đang hiển thị',
      'batch_actions': 'Thao tác hàng loạt',
      'batch_freeze': 'Đóng băng mục đã chọn',
      'batch_unfreeze': 'Rã đông mục đã chọn',
      'batch_force_stop': 'Buộc dừng mục đã chọn',
      'batch_uninstall': 'Gỡ cài đặt mục đã chọn',
      'batch_uninstall_confirm':
          'Gỡ cài đặt {count} ứng dụng đã chọn? Thao tác này không thể hoàn tác.',
      'batch_result': 'Hoàn tất: {success}; thất bại: {failed}',
      'reverse_tethering_title': 'Chia sẻ mạng đảo chiều (Gnirehtet)',
      'reverse_tethering_desc':
          'Chia sẻ kết nối Internet từ máy tính sang thiết bị Android của bạn qua cổng USB.',
      'start_reverse_tethering': 'Bắt đầu chia sẻ mạng',
      'stop_reverse_tethering': 'Dừng chia sẻ mạng',
      'gnirehtet_path': 'Đường dẫn tệp tin Gnirehtet',
      'reverse_tethering_active': 'Đang chia sẻ mạng',
      'reverse_tethering_inactive': 'Không chia sẻ mạng',
      'vpn_instruction':
          'Vui lòng mở khóa điện thoại và bấm Đồng ý yêu cầu cấp quyền kết nối VPN sau khi bắt đầu.',
      'gnirehtet_logs': 'Nhật ký kết nối Gnirehtet',
      'about': 'Giới thiệu',
      'about_version': 'Phiên bản',
      'about_desc':
          'Bộ công cụ quản lý thiết bị Android trên Windows với giao diện Bento Liquid Glass, ADB/Scrcpy, thiết bị không dây, chẩn đoán, workspace, cài đặt APK/XAPK hàng loạt thích ứng, bộ nhớ đệm Ảnh & Video mới theo từng thiết bị, Safe Sync v2, sao lưu/khôi phục và kiểm tra release an toàn.',
      'guide_title': 'Hướng dẫn sử dụng',
      'guide_connect':
          '1. Cài đặt Driver & Kết nối: Cài đặt Driver USB cho điện thoại của bạn (tải driver của hãng Xiaomi, Samsung... hoặc Google USB Driver), sau đó bật tính năng "Gỡ lỗi USB" (USB Debugging/ADB) trong Tùy chọn nhà phát triển trên điện thoại trước khi kết nối bằng cáp USB.',
      'guide_mirror':
          '2. Xem màn hình — Bấm "Khởi chạy truyền hình" để xem và điều khiển màn hình thiết bị trên PC.',
      'guide_file':
          '3. Quản lý tệp — Duyệt, tải lên, tải xuống và xóa tệp trên thiết bị.',
      'guide_sync':
          '4. Safe Sync v2 — Xem trước file sẽ sao chép, cập nhật hoặc xóa trước khi chạy. Mirror Sync yêu cầu nhập DELETE để xác nhận đúng danh sách xóa.',
      'guide_media':
          '5. Ảnh & Video mới — Dữ liệu bắt đầu tải sau khi phát hiện thiết bị và được lưu theo từng thiết bị khi chuyển đổi; bấm Làm mới để truy vấn lại.',
      'guide_install':
          '6. Cài đặt APK/XAPK — Trên desktop, bố cục hai cột đặt bộ chọn và hàng đợi bên trái, chi tiết và log dễ đọc tự giãn bên phải. Chọn nhiều tệp APK/XAPK, kiểm tra hàng đợi rồi cài tuần tự; gói nén được kiểm tra an toàn trước khi giải nén.',
      'guide_tether':
          '7. Chia sẻ mạng đảo chiều — Chia sẻ mạng Internet từ PC sang thiết bị qua Gnirehtet.',
      'guide_tools':
          '8. Công cụ nhanh — Gửi văn bản, mô phỏng phím, khởi động lại, chụp ảnh màn hình và nhiều hơn nữa.',
      'guide_settings':
          '9. Năng suất & cài đặt — Cấu hình đường dẫn, lưu profile Scrcpy, kết nối ADB không dây, xem Chẩn đoán và Workspace, dùng Command Palette bằng Ctrl+K, sao lưu/khôi phục cấu hình và kiểm tra GitHub Releases. Ngôn ngữ được ghi nhớ giữa các lần mở; debug.bat bật timestamp chẩn đoán.',
      'about_close': 'Đóng',
      'about_made_by': 'Được tạo với ❤️ bởi JA Team',
      'project_website': 'Website dự án',
      'source_code': 'Mã nguồn',
      'open_link_failed': 'Không thể mở liên kết.',
      'sync_folders_btn': 'Đồng bộ thư mục',
      'sync_folders_title': 'Đồng bộ thư mục PC & Android',
      'pc_folder_label': 'Thư mục PC:',
      'android_folder_label': 'Thư mục Android:',
      'sync_direction_label': 'Chiều đồng bộ:',
      'sync_direction_pc_to_android': 'PC -> Android (Tải lên/Ghi đè)',
      'sync_direction_android_to_pc': 'Android -> PC (Tải về/Ghi đè)',
      'sync_direction_newest': 'Đồng bộ file mới nhất (Bỏ qua trùng lặp)',
      'auto_sync_label': 'Tự động đồng bộ khi kết nối thiết bị',
      'delete_extra_files_label': 'Xóa tệp thừa ở thư mục đích (Mirror Sync)',
      'start_sync_btn': 'Bắt đầu đồng bộ',
      'pause_sync_btn': 'Tạm dừng',
      'resume_sync_btn': 'Tiếp tục',
      'sync_status_idle':
          'Cấu hình đường dẫn và tùy chọn, sau đó nhấn Bắt đầu đồng bộ.',
      'select_pc_folder_hint': 'Chọn thư mục PC...',
      'error_select_pc_folder': 'Vui lòng chọn thư mục PC hợp lệ.',
      'recent_sync_title': 'Cấu hình gần đây',
      'get_current_folder_btn': 'Lấy thư mục đang duyệt',
      'copy_log_btn': 'Sao chép nhật ký',
      'clear_log_btn': 'Xóa nhật ký',
      'sync_history_empty': 'Chưa có lịch sử đồng bộ.',
      'clear_history_btn': 'Xóa lịch sử',
    },
    'zh': {
      'app_title': 'JA ADB 工具',
      'no_device_connected': '未连接设备',
      'select_device': '从侧边栏选择一个安卓设备以开始。',
      'adb_setup_title': '开启 USB 调试',
      'adb_setup_subtitle': '几步即可连接您的安卓手机',
      'adb_image_disclaimer': '图片为通用安卓界面示意，不同品牌的名称可能略有差异。',
      'adb_illustration_phone': '安卓',
      'adb_illustration_debug': 'USB 调试',
      'adb_image_zoom': '点击放大',
      'adb_step_1': '打开手机上的“设置”。',
      'adb_step_2': '打开“关于手机”，连续点击“版本号”七次以开启开发者选项。',
      'adb_step_3': '打开“开发者选项”，开启“USB 调试”。',
      'adb_step_4': '通过 USB 连接手机、解锁手机，并允许 RSA 调试授权提示。',
      'adb_setup_note': '连接时请保持手机解锁，然后刷新设备列表。',
      'adb_refresh_button': '刷新设备',
      'refresh_devices': '刷新设备列表',
      'scrcpy_tab': '屏幕投屏',
      'file_explorer_tab': '文件管理器',
      'latest_media_tab': '最新媒体',
      'installer_tab': '应用安装器',
      'settings_tab': '高级设置',
      'advanced_settings': '高级设置',
      'launch_mirror': '启动投屏',
      'launch_standalone_mirror': '启动独立窗口 (多设备)',
      'stop_mirror': '停止投屏',
      'take_screenshot': '屏幕截图',
      'select_screenshot_folder': '选择截图保存文件夹',
      'select_download_folder': '选择媒体下载文件夹',
      'predefined_label': '预设模板:',
      'select_predefined_hint': '选择一个模板...',
      'scrcpy_options': '投屏选项',
      'scrcpy_profiles': 'Scrcpy 配置',
      'scrcpy_profile_hint': '配置名称',
      'save_profile': '保存配置',
      'delete_profile': '删除配置',
      'profile_saved': 'Scrcpy 配置已保存。',
      'profile_delete_confirm': '删除配置“{name}”？',
      'stay_on_top': '窗口置顶',
      'fullscreen': '全屏显示',
      'no_control': '仅查看 (无控制)',
      'keep_awake': '保持设备唤醒',
      'borderless': '无边框窗口',
      'disable_audio': '禁用音频 (无声音)',
      'pc_side': '电脑 (PC)',
      'android_side': '安卓设备',
      'download_selected': '下载到电脑',
      'upload_files': '上传到安卓',
      'new_folder': '新建文件夹',
      'delete_selected': '删除项目',
      'loading': '正在加载...',
      'status': '状态',
      'path_to_adb': 'adb.exe 路径',
      'path_to_scrcpy': 'scrcpy.exe 路径',
      'path_settings_title': '工具路径',
      'path_settings_subtitle': '仅在需要修改 ADB、Scrcpy 或 Gnirehtet 时展开',
      'select_apk_xapk': '选择 APK 或 XAPK 文件',
      'drag_drop_apk_xapk': '点击此处选择 APK/XAPK 文件（可多选）',
      'packages_selected': '已选择 {count} 个安装包',
      'selected_packages': '已选安装包（{count}）',
      'remove_package': '移除安装包',
      'install_button': '安装到设备',
      'installing': '正在安装应用...',
      'installation_success': '应用安装成功！',
      'installation_failed': '安装失败: {error}',
      'apk_details': '安装包详情',
      'no_media_found': '设备上未找到照片或视频。',
      'latest_media_title': '筛选最新照片和视频',
      'media_load_success': '已从设备加载 {count} 个媒体项目。',
      'selected_count': '已选择 {count} 个项目',
      'select_latest': '选择最新:',
      'copying_media': '正在将选定的媒体复制到电脑...',
      'copy_media_success': '成功将 {count} 个文件复制到 {dir}',
      'copy_media_failed': '复制失败: {error}',
      'device_info': '设备信息',
      'language': '语言',
      'theme': '主题',
      'confirm_delete': '确认删除',
      'confirm_delete_msg': '您确定要删除 "{name}" 吗？此操作无法撤销。',
      'create_folder': '创建文件夹',
      'folder_name': '文件夹名称',
      'cancel': '取消',
      'confirm': '确认',
      'create': '创建',
      'save_settings': '保存设置',
      'settings_saved': '设置保存成功！',
      'glass_settings_title': 'Glassmorphism',
      'glass_settings_subtitle': '自定义模糊和透明度',
      'glass_preview': 'Glassmorphism 预览',
      'bg_blur_label': '主背景模糊',
      'bg_opacity_label': '主背景透明度',
      'dialog_blur_label': '对话框模糊',
      'dialog_opacity_label': '对话框透明度',
      'reset_defaults': '默认',
      'user_guide': '使用指南',
      'default_search_btn': '自动检测路径',
      'devices_found': '找到 {count} 个设备',
      'no_devices_found': '未找到设备。请确保手机已启用 USB 调试。',
      'wireless_adb': '无线 ADB',
      'wireless_adb_title': '通过 Wi-Fi 连接',
      'wireless_adb_hint': '输入设备 IP 地址和 ADB 端口。',
      'wireless_host': '设备 IP 地址',
      'wireless_port': 'ADB 端口',
      'wireless_connect': '连接',
      'wireless_disconnect': '断开连接',
      'wireless_saved_endpoints': '已保存的连接',
      'wireless_no_endpoints': '没有已保存的无线连接。',
      'diagnostics': '诊断',
      'diagnostics_title': '诊断中心',
      'diagnostics_hint': '检查本地工具和设备连接。',
      'diagnostics_run': '运行诊断',
      'diagnostics_copy': '复制报告',
      'diagnostics_no_report': '运行诊断后查看报告。',
      'workspace': '工作区',
      'workspace_title': '设备工作区',
      'workspace_save_current': '保存当前设备',
      'workspace_name': '工作区名称',
      'workspace_empty': '没有已保存的工作区。',
      'workspace_apply': '打开',
      'workspace_delete': '删除',
      'workspace_saved': '工作区已保存。',
      'command_palette': '命令面板',
      'command_palette_hint': '搜索命令…',
      'backup_restore': '备份与恢复',
      'backup_settings': '备份设置',
      'restore_settings': '恢复设置',
      'backup_hint': '导出或恢复路径、界面偏好、同步设置、配置和工作区。',
      'backup_exported': '设置备份已导出。',
      'backup_imported': '设置已恢复。如路径未立即更新，请重启应用。',
      'backup_failed': '无法导出设置备份。',
      'backup_import_failed': '无法恢复此备份文件。',
      'check_updates': '检查更新',
      'update_title': '软件更新',
      'update_checking': '正在检查 GitHub Releases…',
      'update_available': '已有版本 {version}。',
      'update_up_to_date': '当前已是最新版本（{version}）。',
      'update_unavailable': '暂时无法检查 GitHub Releases。',
      'open_release': '打开发布页',
      'retry': '重试',
      'plugin_manager': '插件管理器',
      'plugin_empty': '未找到插件 manifest。请仅将可信的 JSON manifest 放入应用数据 plugins 文件夹。',
      'current_path': '当前路径: {path}',
      'quick_tools_tab': '快捷功能',
      'settings_shortcuts': '设置快捷方式',
      'launcher_settings': '默认桌面设置',
      'lock_settings': '锁屏与密码',
      'language_settings': '设备语言设置',
      'developer_options': '开发者选项',
      'wifi_settings': 'Wi-Fi 设置',
      'display_settings': '显示设置',
      'accessibility_settings': '无障碍设置',
      'app_settings': '应用管理',
      'about_phone': '关于手机',
      'device_controls': '设备电源控制',
      'reboot_system': '重启系统',
      'reboot_bootloader': '重启至 Fastboot',
      'reboot_recovery': '重启至 Recovery',
      'power_off': '关机',
      'hardware_keys': '按键模拟',
      'key_back': '返回键',
      'key_home': '主页键',
      'key_recents': '多任务键',
      'key_power': '电源键',
      'key_volume_up': '音量加',
      'key_volume_down': '音量减',
      'text_input_tool': '文本输入发送器',
      'text_input_placeholder': '输入要发送到设备活动输入框的文本...',
      'send_text': '发送至设备',
      'confirm_reboot': '确认重启',
      'confirm_reboot_msg': '您确定要重启设备吗？',
      'confirm_power_off': '确认关机',
      'confirm_power_off_msg': '您确定要关闭设备吗？',
      'app_freeze_tab': '应用管理器',
      'uninstall_btn': '卸载',
      'force_stop_btn': '强行停止',
      'clear_data_btn': '清除数据',
      'launch_app_btn': '打开应用',
      'uninstall_confirm': '您确定要卸载 {app} 吗？',
      'clear_data_confirm': '您确定要清除 {app} 的数据吗？',
      'search_apps_placeholder': '按名称 or 包名搜索...',
      'freeze_btn': '冻结',
      'unfreeze_btn': '解冻',
      'show_system_apps': '显示系统应用',
      'refresh_list': '刷新列表',
      'sort_apps_tooltip': '应用排序',
      'sort_by_name': '按名称排序',
      'sort_by_newest': '按最新排序',
      'sort_by_oldest': '按最早排序',
      'no_apps_found': '未找到应用。',
      'select_all_apps': '选择当前显示的所有应用',
      'batch_actions': '批量操作',
      'batch_freeze': '冻结所选应用',
      'batch_unfreeze': '解冻所选应用',
      'batch_force_stop': '强行停止所选应用',
      'batch_uninstall': '卸载所选应用',
      'batch_uninstall_confirm': '卸载已选择的 {count} 个应用？此操作无法撤销。',
      'batch_result': '完成：{success}；失败：{failed}',
      'reverse_tethering_title': '逆向网络共享 (Gnirehtet)',
      'reverse_tethering_desc': '通过 USB 与安卓设备共享电脑的互联网连接。',
      'start_reverse_tethering': '开启网络共享',
      'stop_reverse_tethering': '停止网络共享',
      'gnirehtet_path': 'Gnirehtet 执行文件路径',
      'reverse_tethering_active': '网络共享已启用',
      'reverse_tethering_inactive': '网络共享已停用',
      'vpn_instruction': '开启后请解锁手机并允许系统 VPN 连接权限申请。',
      'gnirehtet_logs': 'Gnirehtet 连接日志',
      'about': '关于',
      'about_version': '版本',
      'about_desc':
          '一款采用 Bento Liquid Glass 界面的 Windows 安卓设备管理工具，支持 ADB/Scrcpy、无线设备、诊断、工作区、自适应批量 APK/XAPK 安装、按设备预加载最新媒体缓存、Safe Sync v2、备份恢复和安全发布检查。',
      'guide_title': '使用指南',
      'guide_connect':
          '1. 驱动与连接：为您的安卓设备安装 USB 驱动程序（例如 Google 或手机厂商官方驱动），然后在手机上开启开发者选项中的“USB 调试” (ADB)，最后通过 USB 连接电脑。',
      'guide_mirror': '2. 屏幕投屏 — 点击"启动投屏"在 PC 上查看并控制设备屏幕。',
      'guide_file': '3. 文件管理器 — 浏览、上传、下载和删除设备上的文件。',
      'guide_sync':
          '4. Safe Sync v2 — 同步前预览复制、更新和删除项；镜像同步必须输入 DELETE 确认准确的删除差异。',
      'guide_media': '5. 最新媒体 — 设备发现后会开始加载，并在切换设备时使用对应缓存；需要最新数据时请点击刷新。',
      'guide_install':
          '6. 应用安装器 — 桌面窗口采用两列布局：左侧为选择器和队列，右侧为详情及可扩展的清晰日志。可多选 APK/XAPK 文件，确认队列后按顺序安装；解压前会进行安全校验。',
      'guide_tether': '7. 逆向网络共享 — 通过 Gnirehtet 将电脑网络分享给设备。',
      'guide_tools': '8. 快速工具 — 发送文字、模拟按键、重启、截图等更多功能。',
      'guide_settings':
          '9. 效率与设置 — 配置工具路径、保存 Scrcpy 配置、连接无线 ADB、查看诊断和设备工作区、使用 Ctrl+K 命令面板、备份恢复设置并检查 GitHub Releases。应用语言会保持不变；debug.bat 可输出诊断时间戳。',
      'about_close': '关闭',
      'about_made_by': '由 JA Team ❤️ 打造',
      'project_website': '项目网站',
      'source_code': '源代码',
      'open_link_failed': '无法打开链接。',
      'sync_folders_btn': '文件夹同步',
      'sync_folders_title': '同步 PC 和安卓文件夹',
      'pc_folder_label': 'PC 文件夹:',
      'android_folder_label': '安卓文件夹:',
      'sync_direction_label': '同步方向:',
      'sync_direction_pc_to_android': 'PC -> 安卓 (上传/覆盖)',
      'sync_direction_android_to_pc': '安卓 -> PC (下载/覆盖)',
      'sync_direction_newest': '同步最新文件 (跳过重复项)',
      'auto_sync_label': '连接设备时自动同步',
      'delete_extra_files_label': '删除目标文件夹的多余文件 (镜像同步)',
      'start_sync_btn': '开始同步',
      'pause_sync_btn': '暂停',
      'resume_sync_btn': '继续',
      'sync_status_idle': '配置路径和选项，然后点击开始同步。',
      'select_pc_folder_hint': '选择 PC 文件夹...',
      'error_select_pc_folder': '请选择有效的 PC 文件夹。',
      'recent_sync_title': '最近的配置',
      'get_current_folder_btn': '获取当前目录',
      'copy_log_btn': '复制日志',
      'clear_log_btn': '清除日志',
      'sync_history_empty': '没有最近的同步历史。',
      'clear_history_btn': '清除历史',
    },
  };

  String translate(String key, {Map<String, String>? args}) {
    String value =
        _localizedValues[_locale]?[key] ?? _localizedValues['en']?[key] ?? key;
    if (args != null) {
      args.forEach((k, v) {
        value = value.replaceAll('{$k}', v);
      });
    }
    return value;
  }
}

extension LocalizationExtension on BuildContext {
  String tr(String key, {Map<String, String>? args}) {
    return Provider.of<LanguageProvider>(this).translate(key, args: args);
  }
}
