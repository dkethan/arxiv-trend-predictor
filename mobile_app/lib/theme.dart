import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Matches the web app CSS variables exactly
class AppColors {
  static const bg = Color(0xFF0A0B0F);
  static const surface = Color(0xFF12141C);
  static const surfaceElevated = Color(0xFF1C1F2A);
  static const border = Color(0x0FFFFFFF); // rgba(255,255,255,0.06)
  static const borderFocus = Color(0x802EC4B6); // rgba(46,196,182,0.5)
  static const text = Color(0xFFF0F0F2);
  static const textMuted = Color(0xFF8B8D98);
  static const accent = Color(0xFF2EC4B6);
  static const accentSoft = Color(0x332EC4B6); // rgba(46,196,182,0.2)
  static const success = Color(0xFF34D399);
  static const successSoft = Color(0x2634D399); // rgba(52,211,153,0.15)
  static const error = Color(0xFFF87171);
  static const errorSoft = Color(0x1FF87171); // rgba(248,113,113,0.12)
}

/// Card decoration matching web: .card
BoxDecoration get appCardDecoration => BoxDecoration(
      color: AppColors.surface.withValues(alpha: 0.85),
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: const Color(0x66000000),
          blurRadius: 24,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.03),
          blurRadius: 0,
          spreadRadius: 1,
          offset: Offset.zero,
        ),
      ],
    );

final appTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.bg,
  colorScheme: const ColorScheme.dark(
    surface: AppColors.bg,
    primary: AppColors.accent,
    secondary: AppColors.success,
    error: AppColors.error,
    onSurface: AppColors.text,
    onPrimary: AppColors.bg,
  ),
  useMaterial3: true,
  textTheme: GoogleFonts.outfitTextTheme(
    ThemeData.dark().textTheme,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.bg,
    foregroundColor: AppColors.text,
    elevation: 0,
    scrolledUnderElevation: 0,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surface.withValues(alpha: 0.85),
    hintStyle: TextStyle(
      color: AppColors.textMuted.withValues(alpha: 0.7),
      fontWeight: FontWeight.w400,
    ),
    labelStyle: const TextStyle(
      color: AppColors.textMuted,
      fontSize: 13,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
    ),
    floatingLabelStyle: const TextStyle(
      color: AppColors.textMuted,
      fontSize: 13,
      fontWeight: FontWeight.w500,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(
        color: Colors.white.withValues(alpha: 0.12),
      ),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  ),
);
