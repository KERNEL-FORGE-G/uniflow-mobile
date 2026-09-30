import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Marge basse des listes des pages connectées.
///
/// Deux choses flottent au bord inférieur d'une page : le bouton d'Uni (58 pt,
/// à 14 pt du bord) et, sur certaines pages, un bouton flottant Material
/// (56 pt, à 16 pt du bord). 88 pt : valeur Material recommandée.
const double uniClearance = 88;

/// Marges des pages connectées.
class AppInsets {
  AppInsets._();

  /// Une liste de page : 16 pt sur les côtés et en haut, [uniClearance] en bas.
  static const EdgeInsets pageList = EdgeInsets.fromLTRB(16, 16, 16, uniClearance);
}

/// Styles des barres système pour l'affichage bord à bord.
class AppSystemUi {
  AppSystemUi._();

  /// Sur un en-tête dark — icônes blanches.
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

  /// Sur un fond dark — icônes blanches aussi.
  static const SystemUiOverlayStyle surClair = SystemUiOverlayStyle(
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
    SystemChrome.setSystemUIOverlayStyle(surBleu);
  }
}

/// Palette UniFlow — Dark Premium Design System.
///
/// Fond deep navy `#0A0E1A`, accents bleu électrique + violet + teal,
/// glassmorphism pour les cartes. Aligné web + desktop.
class AppColors {
  AppColors._();

  // --- Fond ---------------------------------------------------------------
  /// Fond principal de l'app — deep navy.
  static const Color background  = Color(0xFF0A0E1A);

  /// Fond secondaire — légèrement plus clair pour les sections.
  static const Color surface     = Color(0xFF0F1629);

  /// Surface élevée (cartes, modals).
  static const Color surfaceElevated = Color(0xFF141B2D);

  /// Fond des inputs.
  static const Color inputFill   = Color(0xFF1A2138);

  // --- Marque (identiques web/desktop) ------------------------------------
  static const Color primaryBlue  = Color(0xFF1E3A8A);
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color deepBlue     = Color(0xFF152A66);
  static const Color primary50    = Color(0xFF1D2D52);
  static const Color primary100   = Color(0xFF243460);

  static const Color teal         = Color(0xFF0D9488);
  static const Color tealLight    = Color(0xFF0EA5E9);
  static const Color tealDark     = Color(0xFF0A7167);
  static const Color teal50       = Color(0xFF0C2A2A);
  static const Color teal100      = Color(0xFF0D3535);

  static const Color purple       = Color(0xFF7C3AED);
  static const Color purpleLight  = Color(0xFF8B5CF6);
  static const Color purpleDark   = Color(0xFF5B21B6);

  /// Ambre — badges, accentuation.
  static const Color amber        = Color(0xFFF59E0B);
  static const Color amberLight   = Color(0xFFFBBF24);

  // --- Glassmorphism -------------------------------------------------------
  /// Surface verre — fond des cartes glass.
  static const Color glassWhite   = Color(0x0DFFFFFF);   // 5 %
  static const Color glassBorder  = Color(0x1AFFFFFF);   // 10 %
  static const Color glassHover   = Color(0x1AFFFFFF);   // 10 %

  // --- Textes (sur fond dark) ----------------------------------------------
  static const Color textPrimary   = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted     = Color(0xFF64748B);

  // --- Bordures ------------------------------------------------------------
  static const Color inputBorder   = Color(0xFF1E2D45);
  static const Color divider       = Color(0xFF1A2540);

  // --- États ---------------------------------------------------------------
  static const Color danger   = Color(0xFFEF4444);
  static const Color success  = Color(0xFF10B981);
  static const Color warning  = Color(0xFFF59E0B);
  static const Color info     = Color(0xFF3B82F6);

  // --- Dégradés -----------------------------------------------------------
  static const LinearGradient logoGradient = LinearGradient(
    colors: [primaryLight, purpleLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Dégradé premium pour les en-têtes — violet profond → bleu nuit.
  static const LinearGradient headerGradient = LinearGradient(
    colors: [Color(0xFF1E1B4B), Color(0xFF0A0E1A), Color(0xFF0C1929)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Hero pour les écrans d'auth — bleu électrique → violet.
  static const LinearGradient authHeroGradient = LinearGradient(
    colors: [Color(0xFF1E3A8A), Color(0xFF3730A3), Color(0xFF7C3AED)],
    stops: [0.0, 0.5, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Accent teal utilisé sur certaines cartes.
  static const LinearGradient tealGradient = LinearGradient(
    colors: [teal, tealLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Dégradé violet premium — badges, accents hero.
  static const LinearGradient purpleGradient = LinearGradient(
    colors: [purpleDark, purpleLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Dégradé mesh background — fond subtil des pages auth.
  static const LinearGradient meshGradient = LinearGradient(
    colors: [Color(0xFF0F1629), Color(0xFF1A1040), Color(0xFF0A0E1A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Couleur accent utilisée sur le bandeau auth.
  static const Color authAccent = amberLight;

  // --- Alias historiques (rétro-compat) -----------------------------------
  static const Color bg        = background;
  static const Color cardWhite = surfaceElevated;
  static const Color card      = surfaceElevated;
  static const Color surfaceMuted = surface;
}

/// Styles de texte — UniFlow Dark.
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
    color: AppColors.primaryLight,
  );

  static const TextStyle overline = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: AppColors.textMuted,
    letterSpacing: 0.8,
  );
}

/// Thème global — Dark Premium.
class AppTheme {
  AppTheme._();

  static const double radiusCard    = 16;
  static const double radiusControl = 12;
  static const double radiusSheet   = 24;
  static const double radiusAuthSheet = 32;

  static ThemeData get light {
    final baseTextTheme = ThemeData(useMaterial3: true).textTheme;
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        brightness: Brightness.dark,
        seedColor: AppColors.primaryLight,
        primary: AppColors.primaryLight,
        secondary: AppColors.purpleLight,
        tertiary: AppColors.tealLight,
        surface: AppColors.surfaceElevated,
        error: AppColors.danger,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
        onError: Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme(baseTextTheme),
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
        systemOverlayStyle: AppSystemUi.surBleu,
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryLight,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.inputBorder,
          disabledForegroundColor: AppColors.textMuted,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusCard),
          ),
          textStyle: AppTextStyles.button,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          backgroundColor: AppColors.glassWhite,
          side: const BorderSide(color: AppColors.glassBorder, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusCard),
          ),
          textStyle: AppTextStyles.button.copyWith(
            color: AppColors.textPrimary,
            fontSize: 14,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
          textStyle: AppTextStyles.link,
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppColors.textSecondary),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputFill,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        labelStyle: AppTextStyles.body,
        hintStyle: AppTextStyles.body.copyWith(color: AppColors.textMuted),
        helperStyle: AppTextStyles.bodySmall,
        errorStyle: const TextStyle(fontSize: 12.5, color: AppColors.danger),
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
          borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
      ),

      cardTheme: CardThemeData(
        color: AppColors.surfaceElevated,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: const BorderSide(color: AppColors.glassBorder, width: 0.5),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.glassBorder),
        ),
        titleTextStyle: AppTextStyles.h2.copyWith(fontSize: 18),
        contentTextStyle: AppTextStyles.body,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceElevated,
        contentTextStyle: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: const BorderSide(color: AppColors.glassBorder),
        ),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primaryLight
              : Colors.transparent,
        ),
        side: const BorderSide(color: AppColors.inputBorder, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primaryLight,
        linearTrackColor: AppColors.inputBorder,
        circularTrackColor: AppColors.inputBorder,
      ),

      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
        tileColor: Colors.transparent,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primaryLight.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primaryLight, size: 22);
          }
          return const IconThemeData(color: AppColors.textMuted, size: 22);
        }),
      ),
    );
  }
}
