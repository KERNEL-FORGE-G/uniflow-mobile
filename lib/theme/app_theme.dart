import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const teal = Color(0xFF0B8F86);
  static const tealDark = Color(0xFF097870);
  static const bg = Color(0xFFF6F7F9);
  static const card = Colors.white;
  static const textPrimary = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B);
  static const success = Color(0xFF16A34A);
  static const info = Color(0xFF2563EB);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFDC2626);
}

class AppTheme {
  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.teal,
        primary: AppColors.teal,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.bg,
      textTheme: GoogleFonts.interTextTheme(base.textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: EdgeInsets.zero,
      ),
    );
  }
}
