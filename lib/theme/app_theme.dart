import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Marge basse des listes des pages connectées.
const double uniClearance = 88;

/// Marges des pages connectées.
class AppInsets {
  AppInsets._();
  static const EdgeInsets pageList =
      EdgeInsets.fromLTRB(16, 16, 16, uniClearance);
}

/// Styles des barres système — bord à bord, icônes sombres sur fond clair.
class AppSystemUi {
  AppSystemUi._();

  static const SystemUiOverlayStyle surClair = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemStatusBarContrastEnforced: false,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  );

  static const SystemUiOverlayStyle surBleu = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemStatusBarContrastEnforced: false,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarContrastEnforced: false,
  );

  static Future<void> appliquer() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(surClair);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PALETTE  —  UniFlow Clean UI  (inspiré grocery/ecommerce clean minimal)
//  Fond : blanc pur + touches mint/teal   Accents : bleu #1E3A8A + teal #0D9488
//  Style : cartes blanches arrondies, illustrations 3D, bottom nav élégant
// ─────────────────────────────────────────────────────────────────────────────
class AppColors {
  AppColors._();

  // ── Fond & surfaces ──────────────────────────────────────────────────────
  /// Fond général — blanc légèrement teinté mint/bleu glacier.
  static const Color background = Color(0xFFF0F7FF);

  /// Surface des cartes — blanc pur.
  static const Color cardWhite = Color(0xFFFFFFFF);

  /// Surface secondaire — bleu glacé très pâle.
  static const Color surface = Color(0xFFE8F4FD);

  /// Surface surélevée (modals, sheets).
  static const Color surfaceElevated = Color(0xFFFFFFFF);

  /// Surface mutée (fond de tableaux, lignes).
  static const Color surfaceMuted = Color(0xFFF8FBFF);

  /// Fond des inputs — blanc pur.
  static const Color inputFill = Color(0xFFFFFFFF);

  // ── Marque principale — bleu UniFlow + teal ───────────────────────────────
  /// Bleu principal UniFlow (#1E3A8A).
  static const Color primaryBlue = Color(0xFF1E3A8A);   // "primaryBlue" gardé pour compat

  /// Variante claire (hover, focus) — bleu moyen.
  static const Color primaryLight = Color(0xFF2D5BE3);

  /// Variante foncée (press, ombre).
  static const Color deepBlue = Color(0xFF152A66);

  /// Teintes très claires du bleu — fonds de badges.
  static const Color primary50 = Color(0xFFEFF6FF);
  static const Color primary100 = Color(0xFFDBEAFE);

  // ── Accent secondaire — teal UniFlow ─────────────────────────────────────
  static const Color teal = Color(0xFF0D9488);
  static const Color tealLight = Color(0xFF14B8A8);
  static const Color tealDark = Color(0xFF0A7167);
  static const Color teal50 = Color(0xFFF0FDFA);
  static const Color teal100 = Color(0xFFCCFBF1);

  // ── Accent tertiaire — violet/indigo pour les highlights ──────────────────
  static const Color purple = Color(0xFF6366F1);
  static const Color purpleLight = Color(0xFF818CF8);
  static const Color purpleDark = Color(0xFF4338CA);
  static const Color purple100 = Color(0xFFE0E7FF);

  // ── Amber ────────────────────────────────────────────────────────────────
  static const Color amber = Color(0xFFF59E0B);
  static const Color amberLight = Color(0xFFFBBF24);
  static const Color authAccent = teal;

  // ── Textes ───────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF4B5563);
  static const Color textMuted = Color(0xFF9CA3AF);

  // ── Bordures ─────────────────────────────────────────────────────────────
  static const Color inputBorder = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFF3F4F6);

  // ── États ────────────────────────────────────────────────────────────────
  static const Color danger = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // Teintes claires / foncées des états.
  static const Color success100 = Color(0xFFD1FAE5);
  static const Color successDark = Color(0xFF047857);
  static const Color warning100 = Color(0xFFFEF3C7);
  static const Color warningDark = Color(0xFFB45309);
  static const Color danger100 = Color(0xFFFEE2E2);
  static const Color dangerDark = Color(0xFFB91C1C);
  static const Color info100 = Color(0xFFDBEAFE);
  static const Color infoDark = Color(0xFF1D4ED8);

  // ── Glass / frosted ──────────────────────────────────────────────────────
  static const Color glassWhite = Color(0x33FFFFFF);
  static const Color glassBorder = Color(0x4DFFFFFF);
  static const Color glassHover = Color(0x1AFFFFFF);

  // ── Alias rétro-compat ───────────────────────────────────────────────────
  static const Color bg = background;
  static const Color card = cardWhite;

  // ── Dégradés ─────────────────────────────────────────────────────────────

  /// Dégradé du logo UniFlow — bleu → teal.
  static const LinearGradient logoGradient = LinearGradient(
    colors: [primaryBlue, teal],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// En-tête des pages principales — bleu UniFlow → teal.
  static const LinearGradient headerGradient = LinearGradient(
    colors: [Color(0xFF1E3A8A), Color(0xFF2D5BE3), Color(0xFF0D9488)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Dégradé hero des écrans d'auth — bleu profond → teal.
  static const LinearGradient authHeroGradient = LinearGradient(
    colors: [Color(0xFF1E3A8A), Color(0xFF2D4FA8), Color(0xFF0D9488)],
    stops: [0.0, 0.5, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Dégradé teal — cartes secondaires.
  static const LinearGradient tealGradient = LinearGradient(
    colors: [teal, tealLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Dégradé indigo — badges, accents.
  static const LinearGradient purpleGradient = LinearGradient(
    colors: [purpleDark, purpleLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Fond mesh — pages auth/onboarding.
  static const LinearGradient meshGradient = LinearGradient(
    colors: [Color(0xFFEFF6FF), Color(0xFFF0FDFA), Color(0xFFEDE9FE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Fond de l'onboarding — bleu UniFlow vers teal pâle.
  static const LinearGradient onboardingGradient = LinearGradient(
    colors: [Color(0xFF1E3A8A), Color(0xFF2D4FA8), Color(0xFF0D9488)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Carte hero dashboard (bandeau « Bienvenue »).
  static const LinearGradient dashHeroGradient = LinearGradient(
    colors: [Color(0xFF1E3A8A), Color(0xFF0D9488)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  STYLES DE TEXTE
// ─────────────────────────────────────────────────────────────────────────────
class AppTextStyles {
  AppTextStyles._();

  static const TextStyle h1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.25,
  );

  static const TextStyle h3 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
    height: 1.45,
  );

  static const TextStyle label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle button = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static const TextStyle link = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryBlue,
  );

  static const TextStyle overline = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: AppColors.textMuted,
    letterSpacing: 0.8,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  THÈME GLOBAL — Soft UI Clair
// ─────────────────────────────────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  static const double radiusCard = 16;
  static const double radiusControl = 12;
  static const double radiusSheet = 24;
  static const double radiusAuthSheet = 32;

  static ThemeData get light {
    final baseTextTheme = ThemeData(useMaterial3: true).textTheme;
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        brightness: Brightness.light,
        seedColor: AppColors.primaryBlue,
        primary: AppColors.primaryBlue,
        secondary: AppColors.teal,
        tertiary: AppColors.purple,
        surface: AppColors.cardWhite,
        error: AppColors.danger,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
        onError: Colors.white,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(baseTextTheme),
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: AppSystemUi.surClair,
        titleTextStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.inputBorder,
          disabledForegroundColor: AppColors.textMuted,
          elevation: 0,
          shadowColor: AppColors.primaryBlue.withValues(alpha: 0.35),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusCard),
          ),
          textStyle: AppTextStyles.button,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryBlue,
          backgroundColor: AppColors.primary100,
          side: const BorderSide(color: AppColors.inputBorder, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusCard),
          ),
          textStyle: AppTextStyles.button
              .copyWith(color: AppColors.primaryBlue, fontSize: 14),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryBlue,
          textStyle: AppTextStyles.link,
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
            foregroundColor: AppColors.textSecondary),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputFill,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        labelStyle: AppTextStyles.body,
        hintStyle: AppTextStyles.body.copyWith(color: AppColors.textMuted),
        helperStyle: AppTextStyles.bodySmall,
        errorStyle: const TextStyle(
            fontSize: 12.5, color: AppColors.danger),
        prefixIconColor: AppColors.textMuted,
        suffixIconColor: AppColors.textMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          borderSide:
              const BorderSide(color: AppColors.primaryBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          borderSide:
              const BorderSide(color: AppColors.danger, width: 1.5),
        ),
      ),

      cardTheme: CardThemeData(
        color: AppColors.cardWhite,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: const BorderSide(color: AppColors.inputBorder, width: 0.8),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cardWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.inputBorder),
        ),
        titleTextStyle: AppTextStyles.h2.copyWith(fontSize: 18),
        contentTextStyle: AppTextStyles.body,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.cardWhite,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: const TextStyle(
            fontSize: 13.5, color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
        ),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primaryBlue
              : Colors.transparent,
        ),
        side: const BorderSide(
            color: AppColors.inputBorder, width: 1.5),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4)),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primaryBlue,
        linearTrackColor: AppColors.inputBorder,
        circularTrackColor: AppColors.inputBorder,
      ),

      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
        tileColor: Colors.transparent,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.cardWhite,
        indicatorColor:
            AppColors.primaryBlue.withValues(alpha: 0.12),
        shadowColor: AppColors.primaryBlue.withValues(alpha: 0.08),
        elevation: 8,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(
                color: AppColors.primaryBlue, size: 22);
          }
          return const IconThemeData(
              color: AppColors.textMuted, size: 22);
        }),
      ),
    );
  }
}
