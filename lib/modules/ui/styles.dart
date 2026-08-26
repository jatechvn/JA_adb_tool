// lib/modules/ui/styles.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'app_colors.dart';
import 'styles_win10.dart';
import 'styles_win11.dart';

class ThemeProvider extends ChangeNotifier with WidgetsBindingObserver {
  static const _channel = MethodChannel('ja_route/theme');

  bool _isDark = true;
  bool get isDark => _isDark;

  bool _isWin11 = false;
  bool get isWin11 => _isWin11;

  // Glassmorphism live tuning parameters
  double _cardBlur = 20.0;
  double _cardOpacity = 0.25;
  double _dialogBlur = 20.0;
  double _dialogOpacity = 0.85;

  ThemeProvider() {
    _isDark = _systemPrefersDark;
    WidgetsBinding.instance.addObserver(this);
    _detectWindowsVersion();
    _applyNativeTheme();
  }

  bool get _systemPrefersDark =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness ==
      Brightness.dark;

  @override
  void didChangePlatformBrightness() {
    final systemIsDark = _systemPrefersDark;
    if (_isDark == systemIsDark) return;

    _isDark = systemIsDark;
    _applyNativeTheme();
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _detectWindowsVersion() {
    if (!Platform.isWindows) return;
    try {
      final versionStr = Platform.operatingSystemVersion;
      final match =
          RegExp(r'\b10\.0\.(\d+)\b').firstMatch(versionStr) ??
          RegExp(
            r'\bBuild\s+(\d+)\b',
            caseSensitive: false,
          ).firstMatch(versionStr);
      if (match != null) {
        final buildNumber = int.tryParse(match.group(1) ?? '') ?? 0;
        _isWin11 = buildNumber >= 22000;
      }
    } catch (_) {}
  }

  void toggleTheme() {
    _isDark = !_isDark;
    _applyNativeTheme();
    notifyListeners();
  }

  Future<void> _applyNativeTheme() async {
    if (!Platform.isWindows) return;
    try {
      await _channel.invokeMethod('updateTheme', {'isDark': _isDark});
    } catch (e) {
      debugPrint('Failed to apply native theme: $e');
    }
  }

  double get cardBlur => _cardBlur;
  double get cardOpacity => _cardOpacity;
  double get dialogBlur => _dialogBlur;
  double get dialogOpacity => _dialogOpacity;

  AppColors get colors {
    if (_isDark) {
      return _isWin11 ? win11DarkColors : win10DarkColors;
    } else {
      return _isWin11 ? win11LightColors : win10LightColors;
    }
  }

  /// Real-time live tuning for Glassmorphism sliders
  void setLiveGlassmorphism({
    double? cardBlur,
    double? cardOpacity,
    double? dialogBlur,
    double? dialogOpacity,
  }) {
    if (cardBlur != null) _cardBlur = cardBlur;
    if (cardOpacity != null) _cardOpacity = cardOpacity;
    if (dialogBlur != null) _dialogBlur = dialogBlur;
    if (dialogOpacity != null) _dialogOpacity = dialogOpacity;
    notifyListeners();
  }

  Color get scaffoldBg => Colors.transparent;
  Color get sidebarBg => colors.sidebarBg;
  Color get cardBg => colors.cardBg;
  Color get mainBg => colors.bgSecondary;
  Color get textPrimary => colors.textPrimary;
  Color get textSecondary => colors.textSecondary;
  Color get borderTheme => colors.borderDefault;

  ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      brightness: _isDark ? Brightness.dark : Brightness.light,
      primaryColor: colors.accentColor,
      scaffoldBackgroundColor: Colors.transparent,
      cardColor: cardBg,
      fontFamily: 'Outfit',
      textTheme: TextTheme(
        bodyMedium: TextStyle(fontFamily: 'Outfit', color: textPrimary),
      ),
    );
  }
}

extension ThemeExtension on BuildContext {
  AppColors get appColors => watch<ThemeProvider>().colors;
}
