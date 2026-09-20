import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palette de couleurs UniFlow.
///
/// Les valeurs sont **alignées sur le design system de la version web**
/// (`uniflow-we/src/index.css`), exactement comme le fait déjà le desktop
/// (`uniflow-desktop/lib/theme/app_theme.dart`) : mêmes primaires, mêmes
/// neutres, mêmes couleurs d'état. C'est ce qui garantit qu'un écran du mobile
/// ressemble au même écran sur le web.
///
/// Auparavant le mobile avait dérivé vers un teal `#0B8F86` utilisé comme
/// couleur *primaire*, alors que le web réserve le bleu `#1E3A8A` au primaire
/// et n'emploie le teal que comme accent. D'où deux applications visiblement
/// différentes.
class AppColors {
  AppColors._();

  // --- Couleurs de marque ------------------------------------------------
  /// Bleu principal (`--color-primary` du web). C'est la couleur de marque :
  /// en-têtes, boutons pleins, éléments actifs.
  static const Color primaryBlue = Color(0xFF1E3A8A);

  /// Variante claire, pour les survols et les états pressés
  /// (`--color-primary-light`).
  static const Color primaryLight = Color(0xFF2D4FA8);

  /// Bleu foncé, pour les dégradés et les formes décoratives
  /// (`--color-primary-dark`).
  static const Color deepBlue = Color(0xFF152A66);

  /// Teintes très claires du bleu, pour les fonds de badges
  /// (`--color-primary-50` / `--color-primary-100`).
  static const Color primary50 = Color(0xFFEFF3FF);
  static const Color primary100 = Color(0xFFDCE5FD);

  /// Teal, accent secondaire de la marque (`--color-teal`).
  static const Color teal = Color(0xFF0D9488);

  /// Teal clair, pour les survols (`--color-teal-light`).
  static const Color tealLight = Color(0xFF14B8A8);

  /// Teal foncé (`--color-teal-dark`).
  static const Color tealDark = Color(0xFF0A7167);

  /// Teintes très claires du teal, pour les fonds de badges.
  static const Color teal50 = Color(0xFFF0FDFA);
  static const Color teal100 = Color(0xFFCCFBF1);

  /// Violet, troisième accent utilisé par les dégradés « vibrants » du web.
  static const Color purple = Color(0xFF7C3AED);

  // --- Fond et surfaces --------------------------------------------------
  /// Fond général de l'app (`--color-bg`).
  static const Color background = Color(0xFFF3F4F6);

  /// Fond des cartes et panneaux (`--color-surface`).
  static const Color cardWhite = Color(0xFFFFFFFF);

  /// Gris très clair, pour les fonds de tableaux et de lignes alternées.
  static const Color surfaceMuted = Color(0xFFF9FAFB);

  // --- Textes ------------------------------------------------------------
  /// Titres et texte important (`--color-text`).
  static const Color textPrimary = Color(0xFF111827);

  /// Sous-titres et texte secondaire (`--color-muted`).
  static const Color textSecondary = Color(0xFF6B7280);

  /// Placeholders et texte très discret (gray-400 du web).
  static const Color textMuted = Color(0xFF9CA3AF);

  // --- Champs de formulaire ----------------------------------------------
  /// Fond des champs de saisie (gray-50 du web).
  static const Color inputFill = Color(0xFFF9FAFB);

  /// Bordure par défaut des champs et des cartes (`--color-border`).
  static const Color inputBorder = Color(0xFFE5E7EB);

  // --- États / feedback --------------------------------------------------
  static const Color danger = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // --- Dégradés ----------------------------------------------------------
  /// Dégradé du logo (bleu → teal), repris du `gradient-text` du web.
  static const LinearGradient logoGradient = LinearGradient(
    colors: [primaryBlue, teal],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Dégradé des en-têtes de page : c'est lui qui donne au mobile la même
  /// signature visuelle que les en-têtes du web et de la sidebar du desktop.
  static const LinearGradient headerGradient = LinearGradient(
    colors: [primaryBlue, deepBlue, Color(0xFF0D1F4F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Dégradé « mesh » des fonds de page d'authentification
  /// (`bg-gradient-mesh` du web).
  static const LinearGradient meshGradient = LinearGradient(
    colors: [primary50, teal50, Color(0xFFEDE9FE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Dégradé teal, pour les accents secondaires.
  static const LinearGradient tealGradient = LinearGradient(
    colors: [teal, tealDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // --- Alias historiques -------------------------------------------------
  // Le mobile utilisait `bg`, `card` et `textMuted` avant l'alignement sur le
  // web ; ces noms restent définis pour ne pas casser les écrans qui les
  // référencent encore. Ils pointent vers les mêmes valeurs que leurs
  // équivalents ci-dessus.

  /// Ancien nom de [background].
  static const Color bg = background;

  /// Ancien nom de [cardWhite].
  static const Color card = cardWhite;
}

/// Styles de texte réutilisables.
///
/// À utiliser partout au lieu de définir des `TextStyle` en dur dans les
/// écrans, pour garder une typographie cohérente avec le web.
///
/// Ces styles ne fixent **pas** `fontFamily` : la police Inter est posée
/// globalement par [AppTheme.light] via `google_fonts`, et un `Text` fusionne
/// le style reçu avec le style ambiant. La famille est donc héritée, sans
/// avoir à la répéter — et sans dépendre d'un téléchargement de police au
/// premier rendu, puisque `google_fonts` est déjà utilisé par l'application.
class AppTextStyles {
  AppTextStyles._();

  /// Grand titre (ex: « Bienvenue sur UniFlow »).
  static const TextStyle h1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  /// Titre de section (ex: en-tête de carte, titre de page).
  static const TextStyle h2 = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.25,
  );

  /// Titre de carte, un cran sous [h2].
  static const TextStyle h3 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  /// Texte courant / sous-titres.
  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  /// Texte courant en version discrète.
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
    height: 1.45,
  );

  /// Label au-dessus des champs de formulaire.
  static const TextStyle label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  /// Texte des boutons pleins (fond coloré, texte blanc).
  static const TextStyle button = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  /// Liens cliquables (ex: « Mot de passe oublié ? »).
  static const TextStyle link = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryBlue,
  );

  /// Très petits libellés en majuscules (en-têtes de colonnes, sections).
  static const TextStyle overline = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: AppColors.textMuted,
    letterSpacing: 0.4,
  );
}

/// Thème global de l'application, injecté dans le `MaterialApp`.
///
/// Reprend la couverture du thème desktop : les widgets Material standard
/// (champs, boutons, dialogues, cases à cocher…) héritent du style du web sans
/// que chaque écran ait à le répéter.
class AppTheme {
  AppTheme._();

  /// Rayon des conteneurs principaux (`rounded-xl` du web = 12 px).
  static const double radiusCard = 12;

  /// Rayon des éléments interactifs (`rounded-lg` du web = 8 px).
  static const double radiusControl = 8;

  /// Rayon des grandes surfaces (feuilles, cartes de connexion).
  static const double radiusSheet = 20;

  static ThemeData get light {
    // `GoogleFonts.interTextTheme` a besoin d'un `TextTheme` de départ, qui ne
    // peut pas être celui du `ThemeData` en cours de construction : on part donc
    // du texte par défaut de Material, puis on l'enrichit.
    final baseTextTheme = ThemeData(useMaterial3: true).textTheme;

    final base = ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryBlue,
        primary: AppColors.primaryBlue,
        secondary: AppColors.teal,
        surface: AppColors.cardWhite,
        error: AppColors.danger,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
      ),
      // Inter, comme le web. `google_fonts` télécharge puis met en cache les
      // fichiers ; en cas d'échec il retombe silencieusement sur la police
      // système, ce qui reste lisible.
      textTheme: GoogleFonts.interTextTheme(baseTextTheme),
    );

    return base.copyWith(
      // --- Textes -------------------------------------------------------
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),

      // --- En-tête / barre d'application ---------------------------------
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),

      // --- Boutons pleins ------------------------------------------------
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
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

      // --- Boutons secondaires ------------------------------------------
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          backgroundColor: AppColors.cardWhite,
          side: const BorderSide(color: AppColors.inputBorder, width: 1.5),
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

      // --- Boutons texte --------------------------------------------------
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryBlue,
          textStyle: AppTextStyles.link,
        ),
      ),

      // --- Boutons icône ---------------------------------------------------
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppColors.textSecondary),
      ),

      // --- Champs de formulaire -------------------------------------------
      // Reprend le `.input-focus` du web : bordure bleue au focus et anneau
      // translucide autour du champ.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardWhite,
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
          borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
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

      // --- Cartes ---------------------------------------------------------
      cardTheme: CardThemeData(
        color: AppColors.cardWhite,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: const BorderSide(color: AppColors.inputBorder),
        ),
      ),

      // --- Séparateurs -----------------------------------------------------
      dividerTheme: const DividerThemeData(
        color: AppColors.inputBorder,
        thickness: 1,
        space: 1,
      ),

      // --- Dialogues --------------------------------------------------------
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cardWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        titleTextStyle: AppTextStyles.h2.copyWith(fontSize: 18),
        contentTextStyle: AppTextStyles.body,
      ),

      // --- Feuilles du bas ---------------------------------------------------
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.cardWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      // --- Notifications -----------------------------------------------------
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: const TextStyle(fontSize: 13.5, color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
        ),
      ),

      // --- Cases à cocher -------------------------------------------------------
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.primaryBlue : Colors.transparent,
        ),
        side: const BorderSide(color: AppColors.inputBorder, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      // --- Barres de progression ---------------------------------------------------
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primaryBlue,
        linearTrackColor: AppColors.inputBorder,
        circularTrackColor: AppColors.inputBorder,
      ),

      // --- Listes ---------------------------------------------------------------
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
      ),
    );
  }
}
