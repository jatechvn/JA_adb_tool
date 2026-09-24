// lib/modules/ui/styles_win11.dart

import 'package:flutter/material.dart';
import 'app_colors.dart';

const win11DarkColors = AppColors(
  bgPrimary: Colors.transparent, // Let Acrylic bleed through
  bgSecondary: Color(0x24000000), // Clean translucent tint
  cardBg: Color(0xD90F172A), // ~85% slate high-density frosted glass
  cardHoverBg: Color(0xE61E293B),
  subCardBg: Color(0xCC0B1120),
  subCardBorder: Color(0x26FFFFFF),
  sidebarBg: Color(0xE6090D16), // ~90% dark solid glass
  headerBg: Color(0xD90F172A),
  headerBorder: Color(0x26FFFFFF),
  textPrimary: Color(0xFFF8FAFC),
  textSecondary: Color(0xFF94A3B8),
  textMuted: Color(0xFF64748B),
  borderDefault: Color(0x26FFFFFF),
  accentColor: Color(0xFF00ADB5),
  primaryGlow: Color(0x5900ADB5),
  accentCyan: Color(0xFF38BDF8),
  accentEmerald: Color(0xFF34D399),
  accentAmber: Color(0xFFFBBF24),
  accentRose: Color(0xFFFB7185),
  accentPurple: Color(0xFFC084FC),
  orb1: Color(0xFF00ADB5),
  orb2: Color(0xFFA855F7),
  orb3: Color(0xFF00D2FF),
  orbOpacity: 0.24,
  glassBg: Color(0xD90F172A),
  glassBorder: Color(0x26FFFFFF),
  glassHighlight: Color(0x33FFFFFF),
  dropdownBg: Color(0xF51E293B), // ~96% slate solid glass
  dropdownBorder: Color(0x38FFFFFF),
);

const win11LightColors = AppColors(
  bgPrimary: Colors.transparent,
  bgSecondary: Color(0x20FFFFFF),
  cardBg: Color(0xEBFFFFFF), // ~92% white high-density frosted glass
  cardHoverBg: Color(0xF5FFFFFF),
  subCardBg: Color(0xE0F8FAFC),
  subCardBorder: Color(0x33CBD5E1),
  sidebarBg: Color(0xF2F1F5F9), // ~95% light neutral solid glass
  headerBg: Color(0xEBFFFFFF),
  headerBorder: Color(0x33CBD5E1),
  textPrimary: Color(0xFF0F172A),
  textSecondary: Color(0xFF475569),
  textMuted: Color(0xFF64748B),
  borderDefault: Color(0x26000000),
  accentColor: Color(0xFF00ADB5),
  primaryGlow: Color(0x4400ADB5),
  accentCyan: Color(0xFF00D2FF),
  accentEmerald: Color(0xFF10B981),
  accentAmber: Color(0xFFF59E0B),
  accentRose: Color(0xFFF43F5E),
  accentPurple: Color(0xFF8B5CF6),
  orb1: Color(0xFF00ADB5),
  orb2: Color(0xFFA855F7),
  orb3: Color(0xFF00D2FF),
  orbOpacity: 0.25,
  glassBg: Color(0xEBFFFFFF),
  glassBorder: Color(0x33CBD5E1),
  glassHighlight: Color(0xE6FFFFFF),
  dropdownBg: Color(0xFAFFFFFF), // ~98% white solid glass
  dropdownBorder: Color(0x29000000),
);

class StylesWin11 {
  static const Color scaffoldBackgroundColor = Colors.transparent;
  static final Color sidebarBgDark = win11DarkColors.sidebarBg;
  static final Color cardBgDark = win11DarkColors.cardBg;
  static final Color mainBgDark = win11DarkColors.bgSecondary;
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFFCCCCCC);

  static final Color sidebarBgLight = win11LightColors.sidebarBg;
  static final Color cardBgLight = win11LightColors.cardBg;
  static final Color mainBgLight = win11LightColors.bgSecondary;
  static const Color textPrimaryLight = Color(0xFF000000);
  static const Color textSecondaryLight = Color(0xFF555555);
}
