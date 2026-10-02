import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palet warna aplikasi — terinspirasi warna lidah sehat (rosy-pink),
/// dengan hero gelap ala kartu konsultasi kesehatan.
class AppColors {
  static const heroDark = Color(0xFF7A2740); // rose gelap, untuk hero/header
  static const heroDarker = Color(0xFF5C1C30);
  static const primary = Color(0xFFE8637A); // coral pink, warna utama/CTA
  static const primaryDark = Color(0xFFD14D65);
  static const background = Color(0xFFFDF1F0); // blush lembut
  static const surface = Color(0xFFFFFFFF);
  static const accent = Color(0xFFF2A65A); // peach hangat, highlight
  static const textPrimary = Color(0xFF3A1620); // plum tua
  static const textSecondary = Color(0xFF8B6169);
  static const danger = Color(0xFFC1483C); // untuk hasil "Diabetes"
  static const warning = Color(0xFFF2A65A); // untuk hasil "Pradiabetes"
  static const safe = Color(0xFF3F9B72); // untuk hasil "Non-Diabetes"
  static const divider = Color(0xFFF2DCDD);
}

class AppTheme {
  static ThemeData get light {
    final base = ThemeData.light();
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.surface,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        headlineMedium: GoogleFonts.inter(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          height: 1.2,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
          height: 1.5,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: AppColors.primary, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
