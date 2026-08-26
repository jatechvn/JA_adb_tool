// lib/modules/ui/styles_win10.dart

import 'package:flutter/material.dart';
import 'app_colors.dart';

const win10DarkColors = AppColors(
  bgPrimary: Colors.transparent,
  bgSecondary: Color(0x20000000), // Clean translucent tint
  cardBg: Color(0x381E293B), // ~22% slate glass
  cardHoverBg: Color(0x55334155),
  subCardBg: Color(0x2E0F172A),
  subCardBorder: Color(0x26FFFFFF),
  sidebarBg: Color(0x38121212),
  headerBg: Color(0x400F172A),
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
  glassBg: Color(0x381E293B),
  glassBorder: Color(0x26FFFFFF),
  glassHighlight: Color(0x33FFFFFF),
);

const win10LightColors = AppColors(
  bgPrimary: Colors.transparent,
  bgSecondary: Color(0x20FFFFFF),
  cardBg: Color(0x40FFFFFF), // ~25% white glass
  cardHoverBg: Color(0x73FFFFFF),
  subCardBg: Color(0x33FFFFFF),
  subCardBorder: Color(0x4DFFFFFF),
  sidebarBg: Color(0x38F0F0F0),
  headerBg: Color(0x4DFFFFFF),
  headerBorder: Color(0x4DFFFFFF),
  textPrimary: Color(0xFF0F172A),
  textSecondary: Color(0xFF475569),
  textMuted: Color(0xFF64748B),
  borderDefault: Color(0x33FFFFFF),
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
  glassBg: Color(0x40FFFFFF),
  glassBorder: Color(0x40FFFFFF),
  glassHighlight: Color(0xE6FFFFFF),
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
