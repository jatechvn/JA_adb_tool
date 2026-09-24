// lib/modules/ui/styles_win10.dart

import 'package:flutter/material.dart';
import 'app_colors.dart';

const win10DarkColors = AppColors(
  bgPrimary: Colors.transparent,
  bgSecondary: Color(0x24000000), // Clean translucent tint
  cardBg: Color(0xD91E293B), // ~85% slate glass
  cardHoverBg: Color(0xE6334155),
  subCardBg: Color(0xCC0F172A),
  subCardBorder: Color(0x26FFFFFF),
  sidebarBg: Color(0xE6121212),
  headerBg: Color(0xD90F172A),
  headerBorder: Color(0x26FFFFFF),
  textPrimary: Color(0xFFF8FAFC),
  textSecondary: Color(0xFF94A3B8),
  textMuted: Color(0xFF64748B),
  borderDefault: Color(0x26FFFFFF),
  accentColor: Color(0xFF00ADB5), // Cyan/Teal brand accent
  primaryGlow: Color(0x5900ADB5),
  accentCyan: Color(0xFF38BDF8),
  accentEmerald: Color(0xFF34D399),
  accentAmber: Color(0xFFFBBF24),
  accentRose: Color(0xFFFB7185),
  accentPurple: Color(0xFFC084FC),
  orb1: Color(0xFF00ADB5),
  orb2: Color(0xFFA855F7),
  orb3: Color(0xFF00D2FF),
  orbOpacity: 0.20,
  glassBg: Color(0xD91E293B),
  glassBorder: Color(0x26FFFFFF),
  glassHighlight: Color(0x33FFFFFF),
  dropdownBg: Color(0xF51E293B), // ~96% slate solid glass
  dropdownBorder: Color(0x38FFFFFF),
);

const win10LightColors = AppColors(
  bgPrimary: Colors.transparent,
  bgSecondary: Color(0x20FFFFFF),
  cardBg: Color(0xEBFFFFFF), // ~92% white glass
  cardHoverBg: Color(0xF5FFFFFF),
  subCardBg: Color(0xE0FFFFFF),
  subCardBorder: Color(0x33CBD5E1),
  sidebarBg: Color(0xF2F0F0F0),
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
  orbOpacity: 0.22,
  glassBg: Color(0xEBFFFFFF),
  glassBorder: Color(0x33CBD5E1),
  glassHighlight: Color(0xE6FFFFFF),
  dropdownBg: Color(0xFAFFFFFF), // ~98% white solid glass
  dropdownBorder: Color(0x29000000),
);

class StylesWin10 {
  static const Color scaffoldBackgroundColor = Colors.transparent;
  static final Color sidebarBgDark = win10DarkColors.sidebarBg;
  static final Color cardBgDark = win10DarkColors.cardBg;
  static final Color mainBgDark = win10DarkColors.bgSecondary;
  static const Color textPrimaryDark = Color(0xFFEEEEEE);
  static const Color textSecondaryDark = Color(0xFFB0B0B0);

  static final Color sidebarBgLight = win10LightColors.sidebarBg;
  static final Color cardBgLight = win10LightColors.cardBg;
  static final Color mainBgLight = win10LightColors.bgSecondary;
  static const Color textPrimaryLight = Color(0xFF1F1F1F);
  static const Color textSecondaryLight = Color(0xFF757575);
}
