import 'package:flutter/material.dart';
import 'phosphor.dart';

import '../models/models.dart' show courseColorHex;
import '../theme/app_theme.dart';

// Icônes UniFlow : une seule famille (Phosphor) sur le web, le mobile et le
// desktop. Voir `docs/icones-uniflow.md` à la racine du projet — ce fichier en
// est la traduction Flutter, et le web (`UniIcon.tsx`) doit en rester le miroir.
//
// Décision du propriétaire (2026-09-21) : plus d'icônes Material filaires sur
// les tableaux de bord, la navigation, les cartes de cours et les actions
// rapides ; à la place des icônes pleines (`duotone`, `fill`) dans des tuiles
// colorées animées.

/// Les trois graisses retenues. Jamais `thin`, `light` ni `regular` seules sur
/// les surfaces listées dans la spécification.
enum UniIconStyle {
  /// Par défaut : dans les tuiles et sur les cartes.
  duotone,

  /// État actif de la navigation (onglet courant).
  fill,

  /// État inactif de la navigation et icônes de chrome (retour, fermer…).
  bold,
}

/// Une icône sémantique, déclinable dans les trois graisses.
///
/// Les trois variantes sont des constantes Phosphor : une `UniIcon` peut donc
/// vivre dans une table `const` (`navDestinations`, actions rapides), ce qu'un
/// appel `PhosphorIcons.x(style)` ne permettrait pas.
class UniIcon {
  final PhosphorIconData duotone;
  final PhosphorIconData fill;
  final PhosphorIconData bold;

  const UniIcon(this.duotone, this.fill, this.bold);

  /// L'icône dans la graisse demandée, `duotone` par défaut.
  PhosphorIconData call([UniIconStyle style = UniIconStyle.duotone]) => switch (style) {
        UniIconStyle.duotone => duotone,
        UniIconStyle.fill => fill,
        UniIconStyle.bold => bold,
      };
}

/// Table sémantique commune aux trois plateformes : même nom Phosphor partout.
class UniIcons {
  UniIcons._();

  static const UniIcon dashboard =
      UniIcon(PhosphorIconsDuotone.squaresFour, PhosphorIconsFill.squaresFour, PhosphorIconsBold.squaresFour);
  static const UniIcon schedule =
      UniIcon(PhosphorIconsDuotone.calendarBlank, PhosphorIconsFill.calendarBlank, PhosphorIconsBold.calendarBlank);
  static const UniIcon courses =
      UniIcon(PhosphorIconsDuotone.bookOpenText, PhosphorIconsFill.bookOpenText, PhosphorIconsBold.bookOpenText);
  static const UniIcon courseUnit =
      UniIcon(PhosphorIconsDuotone.bookBookmark, PhosphorIconsFill.bookBookmark, PhosphorIconsBold.bookBookmark);
  static const UniIcon assignments =
      UniIcon(PhosphorIconsDuotone.clipboardText, PhosphorIconsFill.clipboardText, PhosphorIconsBold.clipboardText);
  static const UniIcon grades =
      UniIcon(PhosphorIconsDuotone.chartLineUp, PhosphorIconsFill.chartLineUp, PhosphorIconsBold.chartLineUp);
  static const UniIcon attendance =
      UniIcon(PhosphorIconsDuotone.qrCode, PhosphorIconsFill.qrCode, PhosphorIconsBold.qrCode);
  static const UniIcon messages =
      UniIcon(PhosphorIconsDuotone.chatsCircle, PhosphorIconsFill.chatsCircle, PhosphorIconsBold.chatsCircle);
  static const UniIcon forum =
      UniIcon(PhosphorIconsDuotone.usersThree, PhosphorIconsFill.usersThree, PhosphorIconsBold.usersThree);
  static const UniIcon library = UniIcon(PhosphorIconsDuotone.books, PhosphorIconsFill.books, PhosphorIconsBold.books);
  static const UniIcon directory =
      UniIcon(PhosphorIconsDuotone.addressBook, PhosphorIconsFill.addressBook, PhosphorIconsBold.addressBook);
  static const UniIcon accounts =
      UniIcon(PhosphorIconsDuotone.userGear, PhosphorIconsFill.userGear, PhosphorIconsBold.userGear);
  static const UniIcon students =
      UniIcon(PhosphorIconsDuotone.graduationCap, PhosphorIconsFill.graduationCap, PhosphorIconsBold.graduationCap);
  static const UniIcon teachers =
      UniIcon(PhosphorIconsDuotone.chalkboard, PhosphorIconsFill.chalkboard, PhosphorIconsBold.chalkboard);
  static const UniIcon teacher = UniIcon(
      PhosphorIconsDuotone.chalkboardTeacher, PhosphorIconsFill.chalkboardTeacher, PhosphorIconsBold.chalkboardTeacher);
  static const UniIcon billing =
      UniIcon(PhosphorIconsDuotone.creditCard, PhosphorIconsFill.creditCard, PhosphorIconsBold.creditCard);
  static const UniIcon settings =
      UniIcon(PhosphorIconsDuotone.gearSix, PhosphorIconsFill.gearSix, PhosphorIconsBold.gearSix);
  static const UniIcon badges = UniIcon(PhosphorIconsDuotone.medal, PhosphorIconsFill.medal, PhosphorIconsBold.medal);
  static const UniIcon assistant =
      UniIcon(PhosphorIconsDuotone.sparkle, PhosphorIconsFill.sparkle, PhosphorIconsBold.sparkle);
  static const UniIcon video =
      UniIcon(PhosphorIconsDuotone.videoCamera, PhosphorIconsFill.videoCamera, PhosphorIconsBold.videoCamera);
  static const UniIcon notifications =
      UniIcon(PhosphorIconsDuotone.bellRinging, PhosphorIconsFill.bellRinging, PhosphorIconsBold.bellRinging);
  static const UniIcon profile =
      UniIcon(PhosphorIconsDuotone.userCircle, PhosphorIconsFill.userCircle, PhosphorIconsBold.userCircle);
  static const UniIcon agenda =
      UniIcon(PhosphorIconsDuotone.calendarCheck, PhosphorIconsFill.calendarCheck, PhosphorIconsBold.calendarCheck);
  static const UniIcon tasks =
      UniIcon(PhosphorIconsDuotone.checkSquare, PhosphorIconsFill.checkSquare, PhosphorIconsBold.checkSquare);
  static const UniIcon university =
      UniIcon(PhosphorIconsDuotone.buildings, PhosphorIconsFill.buildings, PhosphorIconsBold.buildings);
  static const UniIcon room = UniIcon(PhosphorIconsDuotone.door, PhosphorIconsFill.door, PhosphorIconsBold.door);
  static const UniIcon time = UniIcon(PhosphorIconsDuotone.clock, PhosphorIconsFill.clock, PhosphorIconsBold.clock);
  static const UniIcon statistics =
      UniIcon(PhosphorIconsDuotone.chartBar, PhosphorIconsFill.chartBar, PhosphorIconsBold.chartBar);
  static const UniIcon team =
      UniIcon(PhosphorIconsDuotone.usersFour, PhosphorIconsFill.usersFour, PhosphorIconsBold.usersFour);
  static const UniIcon help =
      UniIcon(PhosphorIconsDuotone.question, PhosphorIconsFill.question, PhosphorIconsBold.question);
  static const UniIcon about = UniIcon(PhosphorIconsDuotone.info, PhosphorIconsFill.info, PhosphorIconsBold.info);
  static const UniIcon security =
      UniIcon(PhosphorIconsDuotone.shieldCheck, PhosphorIconsFill.shieldCheck, PhosphorIconsBold.shieldCheck);
  static const UniIcon search = UniIcon(
      PhosphorIconsDuotone.magnifyingGlass, PhosphorIconsFill.magnifyingGlass, PhosphorIconsBold.magnifyingGlass);
  static const UniIcon add =
      UniIcon(PhosphorIconsDuotone.plusCircle, PhosphorIconsFill.plusCircle, PhosphorIconsBold.plusCircle);
  static const UniIcon signOut =
      UniIcon(PhosphorIconsDuotone.signOut, PhosphorIconsFill.signOut, PhosphorIconsBold.signOut);
  static const UniIcon back =
      UniIcon(PhosphorIconsDuotone.arrowLeft, PhosphorIconsFill.arrowLeft, PhosphorIconsBold.arrowLeft);
}

// ---------------------------------------------------------------------------
// Icône d'une matière ou d'un cours
// ---------------------------------------------------------------------------

/// Un mot-clé de la table `subjectIcon`, avec l'icône qu'il désigne.
class _SubjectRule {
  final RegExp pattern;
  final UniIcon icon;
  const _SubjectRule(this.pattern, this.icon);
}

RegExp _kw(String source) => RegExp(source, caseSensitive: false);

/// La table de la spécification, dans l'ordre : le premier mot-clé trouvé
/// gagne. Les mots-clés sont écrits **sans accents** parce que le nom est
/// normalisé avant la recherche.
///
/// Les mots très courts (« ia », « ios », « adn », « tic », « art », « web »,
/// « geo ») sont ancrés en début de mot : en simple sous-chaîne, « ia » aurait
/// transformé « Matériaux » en intelligence artificielle et « art »,
/// « Cartographie » en dessin. Les racines plus longues (« phys », « chim »,
/// « algorith »…) restent des sous-chaînes, c'est ce qui attrape les pluriels
/// et les dérivés.
final List<_SubjectRule> _subjectRules = [
  _SubjectRule(
      _kw(r'math|algebre|analyse|geometrie'),
      const UniIcon(
          PhosphorIconsDuotone.mathOperations, PhosphorIconsFill.mathOperations, PhosphorIconsBold.mathOperations)),
  _SubjectRule(_kw(r'phys'), const UniIcon(PhosphorIconsDuotone.atom, PhosphorIconsFill.atom, PhosphorIconsBold.atom)),
  _SubjectRule(
      _kw(r'chim'), const UniIcon(PhosphorIconsDuotone.flask, PhosphorIconsFill.flask, PhosphorIconsBold.flask)),
  _SubjectRule(_kw(r'bio|genetique|\badn\b'),
      const UniIcon(PhosphorIconsDuotone.dna, PhosphorIconsFill.dna, PhosphorIconsBold.dna)),
  _SubjectRule(_kw(r'reseau'),
      const UniIcon(PhosphorIconsDuotone.network, PhosphorIconsFill.network, PhosphorIconsBold.network)),
  // « bases? » : la spécification écrit « base de donn », mais l'intitulé réel
  // est presque toujours au pluriel (« Bases de données avancées »).
  _SubjectRule(_kw(r'bases? de donn|sql|\bbdd\b'),
      const UniIcon(PhosphorIconsDuotone.database, PhosphorIconsFill.database, PhosphorIconsBold.database)),
  _SubjectRule(
      _kw(r'\bweb'), const UniIcon(PhosphorIconsDuotone.globe, PhosphorIconsFill.globe, PhosphorIconsBold.globe)),
  _SubjectRule(_kw(r'mobile|android|\bios\b'),
      const UniIcon(PhosphorIconsDuotone.deviceMobile, PhosphorIconsFill.deviceMobile, PhosphorIconsBold.deviceMobile)),
  _SubjectRule(_kw(r'secur|crypto'),
      const UniIcon(PhosphorIconsDuotone.shieldCheck, PhosphorIconsFill.shieldCheck, PhosphorIconsBold.shieldCheck)),
  _SubjectRule(_kw(r'intelligence artificielle|\bia\b|apprentissage|data|science des donn'),
      const UniIcon(PhosphorIconsDuotone.brain, PhosphorIconsFill.brain, PhosphorIconsBold.brain)),
  _SubjectRule(_kw(r'cloud|devops'),
      const UniIcon(PhosphorIconsDuotone.cloud, PhosphorIconsFill.cloud, PhosphorIconsBold.cloud)),
  _SubjectRule(_kw(r'statisti|proba'),
      const UniIcon(PhosphorIconsDuotone.chartLine, PhosphorIconsFill.chartLine, PhosphorIconsBold.chartLine)),
  _SubjectRule(_kw(r'anglais|english|langue|francais|espagnol|allemand'),
      const UniIcon(PhosphorIconsDuotone.translate, PhosphorIconsFill.translate, PhosphorIconsBold.translate)),
  _SubjectRule(_kw(r'entrepren|innov'),
      const UniIcon(PhosphorIconsDuotone.rocket, PhosphorIconsFill.rocket, PhosphorIconsBold.rocket)),
  _SubjectRule(_kw(r'projet|stage|tutore'),
      const UniIcon(PhosphorIconsDuotone.kanban, PhosphorIconsFill.kanban, PhosphorIconsBold.kanban)),
  _SubjectRule(_kw(r'systeme|linux|exploitation'),
      const UniIcon(PhosphorIconsDuotone.terminal, PhosphorIconsFill.terminal, PhosphorIconsBold.terminal)),
  _SubjectRule(_kw(r'algorith|programm|code|logiciel|info|developpement'),
      const UniIcon(PhosphorIconsDuotone.code, PhosphorIconsFill.code, PhosphorIconsBold.code)),
  _SubjectRule(_kw(r'econom|gestion|compta|finance|marketing'),
      const UniIcon(PhosphorIconsDuotone.coins, PhosphorIconsFill.coins, PhosphorIconsBold.coins)),
  _SubjectRule(_kw(r'droit|juridique'),
      const UniIcon(PhosphorIconsDuotone.scales, PhosphorIconsFill.scales, PhosphorIconsBold.scales)),
  _SubjectRule(
      _kw(r'histoire'), const UniIcon(PhosphorIconsDuotone.scroll, PhosphorIconsFill.scroll, PhosphorIconsBold.scroll)),
  _SubjectRule(
      _kw(r'\bgeo'),
      const UniIcon(PhosphorIconsDuotone.globeHemisphereWest, PhosphorIconsFill.globeHemisphereWest,
          PhosphorIconsBold.globeHemisphereWest)),
  _SubjectRule(_kw(r'energ|electr'),
      const UniIcon(PhosphorIconsDuotone.lightning, PhosphorIconsFill.lightning, PhosphorIconsBold.lightning)),
  _SubjectRule(_kw(r'musique'),
      const UniIcon(PhosphorIconsDuotone.musicNotes, PhosphorIconsFill.musicNotes, PhosphorIconsBold.musicNotes)),
  _SubjectRule(_kw(r'\bart|dessin|design'),
      const UniIcon(PhosphorIconsDuotone.palette, PhosphorIconsFill.palette, PhosphorIconsBold.palette)),
  _SubjectRule(_kw(r'sport|education physique'),
      const UniIcon(PhosphorIconsDuotone.barbell, PhosphorIconsFill.barbell, PhosphorIconsBold.barbell)),
  _SubjectRule(_kw(r'sante|medecine|anatomie'),
      const UniIcon(PhosphorIconsDuotone.firstAid, PhosphorIconsFill.firstAid, PhosphorIconsBold.firstAid)),
  _SubjectRule(_kw(r'\btic|telecom|communication'),
      const UniIcon(PhosphorIconsDuotone.broadcast, PhosphorIconsFill.broadcast, PhosphorIconsBold.broadcast)),
  _SubjectRule(_kw(r'philo|lettres|litterature'),
      const UniIcon(PhosphorIconsDuotone.feather, PhosphorIconsFill.feather, PhosphorIconsBold.feather)),
];

/// Icône par défaut d'une matière sans mot-clé reconnu.
const UniIcon subjectDefaultIcon =
    UniIcon(PhosphorIconsDuotone.bookOpen, PhosphorIconsFill.bookOpen, PhosphorIconsBold.bookOpen);

/// Minuscules sans accents : « Systèmes d'exploitation » → « systemes d'exploitation ».
///
/// Écrit à la main plutôt qu'avec un paquet : les intitulés sont français, la
/// table des diacritiques à couvrir tient en une ligne par voyelle.
String normalizeSubjectName(String raw) {
  const accents = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a', //
    'ç': 'c',
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
    'ñ': 'n',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
    'ý': 'y', 'ÿ': 'y',
    'œ': 'oe', 'æ': 'ae',
  };
  final buffer = StringBuffer();
  for (final rune in raw.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    buffer.write(accents[char] ?? char);
  }
  return buffer.toString();
}

/// L'icône d'une matière ou d'un cours, dérivée de son nom (et de son code).
///
/// Fonction pure, la même sur les trois plateformes : les matières n'ont pas
/// d'attribut « icône » en base. Insensible à la casse et aux accents ; premier
/// mot-clé trouvé dans l'ordre de la table ; `BookOpen` par défaut. Le code
/// n'est consulté qu'après le nom : « INF301 » ne doit pas décider à la place
/// de « Réseaux informatiques ».
PhosphorIconData subjectIcon(String name, {String? code, UniIconStyle style = UniIconStyle.duotone}) =>
    subjectUniIcon(name, code: code)(style);

/// Comme [subjectIcon], mais rend l'icône dans ses trois graisses.
UniIcon subjectUniIcon(String name, {String? code}) {
  for (final haystack in [normalizeSubjectName(name), if (code != null) normalizeSubjectName(code)]) {
    if (haystack.trim().isEmpty) continue;
    for (final rule in _subjectRules) {
      if (rule.pattern.hasMatch(haystack)) return rule.icon;
    }
  }
  return subjectDefaultIcon;
}

/// Couleur d'une matière : `colorHex` quand la matière en porte une (cours
/// libres de l'espace personnel), sinon une couleur stable dérivée du code.
///
/// Le repli réutilise `courseColorHex`, déjà employé par les cartes d'UE,
/// l'emploi du temps et l'accueil : une seconde palette aurait donné à un même
/// cours deux couleurs sur le même écran (tuile d'un côté, barre de l'autre).
Color subjectColor(String code, {String? colorHex}) {
  final explicit = _parseHex(colorHex);
  if (explicit != null) return explicit;
  return _parseHex(courseColorHex(code)) ?? AppColors.teal;
}

Color? _parseHex(String? hex) {
  if (hex == null) return null;
  final clean = hex.replaceFirst('#', '').trim();
  if (clean.length != 6 && clean.length != 8) return null;
  final value = int.tryParse(clean.length == 6 ? 'FF$clean' : clean, radix: 16);
  return value == null ? null : Color(value);
}

// ---------------------------------------------------------------------------
// Tuile d'icône
// ---------------------------------------------------------------------------

/// Les deux habillages d'une [IconTile].
enum IconTileVariant {
  /// Dégradé de la couleur vers sa nuance sombre, icône blanche, ombre douce.
  filled,

  /// Fond teinté de la couleur à 14 %, icône de la couleur, sans ombre.
  soft,
}

/// Carré arrondi portant une icône Phosphor : la brique visuelle commune des
/// tableaux de bord, des cartes de cours et des actions rapides.
///
/// Mouvement : apparition en cascade (échelle 0,85 → 1 et fondu, `easeOutBack`,
/// 40 ms de décalage par [index]) puis échelle 0,94 tant que la tuile — ou la
/// carte qui la porte, via [pressed] — est enfoncée. Tout est fini et implicite
/// (`TweenAnimationBuilder`, `AnimatedScale`) : `pumpAndSettle` se pose, et
/// quand `MediaQuery.disableAnimations` est vrai rien ne bouge du tout.
class IconTile extends StatefulWidget {
  /// Taille des listes denses.
  static const double dense = 36;

  /// Taille par défaut.
  static const double regular = 44;

  /// Taille des cartes de statistiques.
  static const double large = 56;

  final IconData icon;
  final Color color;
  final IconTileVariant variant;
  final double size;

  /// Rang dans une liste ou une grille : décale l'apparition de 40 ms par cran.
  final int index;

  /// Rend la tuile tapable et anime sa pression. Laisser `null` quand la carte
  /// parente gère le toucher — lui passer alors [pressed].
  final VoidCallback? onTap;

  /// Enfoncée par le parent : la tuile se rétracte comme si on la touchait.
  final bool pressed;

  final String? semanticLabel;

  const IconTile({
    super.key,
    required this.icon,
    required this.color,
    this.variant = IconTileVariant.filled,
    this.size = regular,
    this.index = 0,
    this.onTap,
    this.pressed = false,
    this.semanticLabel,
  });

  /// Rayon des coins : 16 sur les grandes tuiles, 14 ailleurs (spécification).
  double get radius => size >= large ? 16 : 14;

  @override
  State<IconTile> createState() => _IconTileState();
}

class _IconTileState extends State<IconTile> {
  bool _pressed = false;

  static const Duration _enter = Duration(milliseconds: 360);
  static const int _staggerMs = 40;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final pressed = _pressed || widget.pressed;

    Widget tile = _TileSurface(
      icon: widget.icon,
      color: widget.color,
      variant: widget.variant,
      size: widget.size,
      radius: widget.radius,
      semanticLabel: widget.semanticLabel,
    );

    if (widget.onTap != null) {
      tile = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: tile,
      );
    }

    if (reduce) return tile;

    tile = AnimatedScale(
      scale: pressed ? 0.94 : 1,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: tile,
    );

    // Le décalage est plafonné comme dans `FadeSlideIn` : au-delà d'une
    // douzaine d'éléments, faire attendre la fin d'une longue liste agace.
    final delay = Duration(milliseconds: _staggerMs * widget.index.clamp(0, 12));
    final total = _enter + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(delay.inMilliseconds / total.inMilliseconds, 1, curve: Curves.easeOutBack),
      // `easeOutBack` dépasse 1 : l'échelle peut déborder un instant, l'opacité
      // non — Flutter refuse une valeur hors de [0, 1].
      builder: (context, value, child) => Opacity(
        opacity: value.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.85 + 0.15 * value, child: child),
      ),
      child: tile,
    );
  }
}

/// L'apparence de la tuile, sans mouvement.
class _TileSurface extends StatelessWidget {
  final IconData icon;
  final Color color;
  final IconTileVariant variant;
  final double size;
  final double radius;
  final String? semanticLabel;

  const _TileSurface({
    required this.icon,
    required this.color,
    required this.variant,
    required this.size,
    required this.radius,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final filled = variant == IconTileVariant.filled;
    final foreground = filled ? Colors.white : color;
    final tile = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: filled ? null : color.withValues(alpha: 0.14),
        // 135° : du coin haut gauche au coin bas droit, comme le
        // `linear-gradient(135deg, …)` du web.
        gradient: filled
            ? LinearGradient(
                colors: [color, _darken(color)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        boxShadow: filled
            ? [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 5))]
            : null,
      ),
      child: PhosphorIcon(
        icon,
        size: size * 0.5,
        color: foreground,
        // Calque secondaire du duotone : blanc à 45 % sur la tuile pleine, la
        // couleur elle-même (atténuée) sur la tuile douce.
        duotoneSecondaryColor: foreground,
        duotoneSecondaryOpacity: filled ? 0.45 : 0.3,
      ),
    );
    // Le libellé est posé sur la tuile et non sur l'icône : `PhosphorIcon`
    // dessine un duotone en deux `Icon` superposés et annoncerait le libellé
    // deux fois au lecteur d'écran.
    if (semanticLabel == null) return ExcludeSemantics(child: tile);
    return Semantics(label: semanticLabel, image: true, excludeSemantics: true, child: tile);
  }

  /// Nuance sombre de la couleur, pour le second arrêt du dégradé.
  static Color _darken(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness - 0.14).clamp(0.0, 1.0)).toColor();
  }
}
