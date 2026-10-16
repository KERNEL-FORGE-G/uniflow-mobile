import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'uni_mascot.dart';

/// Archlord, la seconde mascotte d'UniFlow : le fondateur, dessiné dans le
/// même style que Uni (demande du propriétaire du 2026-09-21).
///
/// Là où Uni est un robot qui saute et flotte, Archlord est un humain : sa
/// boucle est une respiration, un léger balancement et — quand il parle —
/// un hochement de tête. Rien d'autre : un humain qui rebondirait comme Uni
/// paraîtrait faux.
///
/// Les images sont embarquées (`assets/mascot/archlord_*.webp`), comme
/// celles d'Uni, pour s'afficher hors ligne et sur les écrans d'erreur.
enum ArchlordPose {
  wave('archlord_wave', 373 / 768, 'Archlord salue de la main'),
  explain('archlord_explain', 403 / 768, 'Archlord explique, main ouverte'),
  laptop('archlord_laptop', 405 / 768, 'Archlord travaille sur son ordinateur portable'),
  thumbs('archlord_thumbs', 325 / 768, 'Archlord lève le pouce'),
  thinking('archlord_thinking', 272 / 768, 'Archlord réfléchit, main au menton'),
  pointing('archlord_pointing', 417 / 768, 'Archlord montre la suite du doigt');

  const ArchlordPose(this.file, this.ratio, this.alt);

  /// Nom du fichier sans extension dans `assets/mascot/`.
  final String file;

  /// Largeur / hauteur de l'image, pour réserver la bonne boîte avant décodage.
  final double ratio;

  /// Description pour les lecteurs d'écran.
  final String alt;

  String get asset => 'assets/mascot/$file.webp';
}

/// Durée d'un cycle complet de respiration. Lente : c'est un humain calme,
/// pas un personnage qui gesticule.
const Duration kArchlordBreathCycle = Duration(milliseconds: 3200);

/// Hochements de tête par cycle quand Archlord parle.
const int kArchlordNodsPerCycle = 4;

/// Pose animée d'Archlord, avec bulle facultative.
class ArchlordMascot extends StatefulWidget {
  final ArchlordPose pose;

  /// Hauteur de l'image en points logiques ; la largeur suit le ratio.
  final double size;

  /// Coupe la boucle (entrée et bulle restent).
  final bool still;

  /// Archlord est en train de parler : il hoche la tête en plus de respirer.
  final bool talking;

  /// Amplitude du mouvement, de 0 (immobile) à 1 (normale). Sert au dialogue
  /// à deux : celui qui écoute bouge moins que celui qui parle.
  final double intensity;

  final Widget? bubble;
  final UniBubbleSide bubbleSide;
  final VoidCallback? onTap;

  const ArchlordMascot({
    super.key,
    required this.pose,
    this.size = 150,
    this.still = false,
    this.talking = false,
    this.intensity = 1,
    this.bubble,
    this.bubbleSide = UniBubbleSide.right,
    this.onTap,
  }) : assert(intensity >= 0 && intensity <= 1);

  @override
  State<ArchlordMascot> createState() => _ArchlordMascotState();
}

class _ArchlordMascotState extends State<ArchlordMascot> with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(vsync: this, duration: kArchlordBreathCycle);

  bool _animated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncLoop();
  }

  @override
  void didUpdateWidget(covariant ArchlordMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncLoop();
  }

  /// Même règle que `UniMascot` : le contrôleur ne tourne jamais pour un
  /// mouvement que personne ne verra — `still`, ou réduction des animations
  /// demandée par le système. Un ticker infini empêcherait aussi
  /// `pumpAndSettle` de se stabiliser dans les tests.
  void _syncLoop() {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final animated = !widget.still && !reduce && widget.intensity > 0;
    if (animated && !_animated) {
      _loop.repeat();
    } else if (!animated && _animated) {
      _loop.stop();
      _loop.value = 0;
    }
    _animated = animated;
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  /// Transformation à l'instant `t` (0 → 1, cycle continu).
  ///
  /// Respiration : la poitrine se soulève (échelle verticale infime), pivot
  /// aux pieds pour qu'il « tienne debout ». Balancement : quelques
  /// millièmes de radian. Hochement (parole) : petit rebond vertical rapide,
  /// avec un soupçon d'inclinaison.
  Matrix4 _transform(double t, Size box) {
    final k = widget.intensity;
    final breath = math.sin(t * 2 * math.pi);
    final scaleY = 1 + 0.012 * breath * k;
    double angle = 0.018 * math.sin(t * 2 * math.pi + math.pi / 3) * k;
    double dx = 0, dy = 0;

    switch (widget.pose) {
      case ArchlordPose.wave:
        // La main levée entraîne un balancement un peu plus marqué.
        angle *= 1.8;
      case ArchlordPose.pointing:
        // Il se penche très légèrement vers ce qu'il montre.
        dx = 2.5 * math.max(0, breath) * k;
      case ArchlordPose.laptop:
        // Il tape : le buste frémit à peine, sans balancement.
        angle *= 0.3;
        dy = 0.8 * math.sin(t * 2 * math.pi * 6) * k;
      case ArchlordPose.thinking:
        // Réflexion : plus lent, plus posé.
        angle *= 0.6;
      case ArchlordPose.thumbs:
      case ArchlordPose.explain:
        break;
    }

    if (widget.talking) {
      final nod = math.sin(t * 2 * math.pi * kArchlordNodsPerCycle).abs();
      dy -= 3.0 * nod * k;
      angle += 0.012 * math.sin(t * 2 * math.pi * kArchlordNodsPerCycle) * k;
    }

    final pivot = Offset(box.width / 2, box.height * 0.96);
    return Matrix4.identity()
      ..translateByDouble(dx + pivot.dx, dy + pivot.dy, 0, 1)
      ..rotateZ(angle)
      ..scaleByDouble(1, scaleY, 1, 1)
      ..translateByDouble(-pivot.dx, -pivot.dy, 0, 1);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final box = Size(widget.size * widget.pose.ratio, widget.size);

    Widget image = Semantics(
      image: true,
      label: widget.pose.alt,
      child: Image.asset(
        widget.pose.asset,
        width: box.width,
        height: box.height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        // Un asset manquant ne doit pas casser l'écran qui l'affiche.
        errorBuilder: (_, __, ___) => _Fallback(size: widget.size),
      ),
    );

    if (_animated) {
      image = AnimatedBuilder(
        animation: _loop,
        builder: (context, child) => Transform(transform: _transform(_loop.value, box), child: child),
        child: image,
      );
    }

    Widget figure = SizedBox(width: box.width, height: box.height, child: image);

    // Entrée : il apparaît en grandissant depuis les pieds, comme Uni.
    figure = TweenAnimationBuilder<double>(
      tween: Tween(begin: reduce ? 1 : 0.6, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.scale(scale: v, alignment: Alignment.bottomCenter, child: child),
      ),
      child: figure,
    );

    if (widget.onTap != null) {
      figure = GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: MouseRegion(cursor: SystemMouseCursors.click, child: figure),
      );
    }

    final bubble = widget.bubble;
    if (bubble == null) return figure;

    final speech = UniBubble(side: widget.bubbleSide, child: bubble);
    // La bulle est toujours souple : posée à côté d'un personnage dans une
    // colonne étroite, une bulle rigide déborderait (c'est ce qui est arrivé
    // à `UniPeek` en 420 px).
    return switch (widget.bubbleSide) {
      UniBubbleSide.top => Column(
          mainAxisSize: MainAxisSize.min,
          children: [speech, const SizedBox(height: 6), figure],
        ),
      UniBubbleSide.left => Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [Flexible(child: speech), const SizedBox(width: 8), figure],
        ),
      UniBubbleSide.right => Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [figure, const SizedBox(width: 8), Flexible(child: speech)],
        ),
    };
  }
}

class _Fallback extends StatelessWidget {
  final double size;
  const _Fallback({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size * 0.6,
      height: size * 0.6,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [Color(0xFF1E3A8A), Color(0xFF2D4FA8)]),
      ),
      alignment: Alignment.center,
      child: Text(
        'A',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: size * 0.26),
      ),
    );
  }
}

/// Chemin de la scène à deux : Archlord et Uni se saluent du poing.
const String kArchlordUniFistbumpAsset = 'assets/mascot/archlord_uni_fistbump.webp';

/// Largeur / hauteur de la scène à deux.
const double kArchlordUniFistbumpRatio = 768 / 714;

/// La scène « poing contre poing » d'Archlord et Uni, avec une pulsation
/// discrète au moment du contact. Si l'image manque, les deux personnages
/// sont posés côte à côte à partir de leurs poses individuelles.
class ArchlordUniFistbump extends StatefulWidget {
  /// Hauteur de la scène ; la largeur suit le ratio.
  final double size;

  const ArchlordUniFistbump({super.key, this.size = 160});

  @override
  State<ArchlordUniFistbump> createState() => _ArchlordUniFistbumpState();
}

class _ArchlordUniFistbumpState extends State<ArchlordUniFistbump> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  bool _animated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!reduce && !_animated) {
      _pulse.repeat();
    } else if (reduce && _animated) {
      _pulse.stop();
      _pulse.value = 0;
    }
    _animated = !reduce;
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final box = Size(widget.size * kArchlordUniFistbumpRatio, widget.size);
    Widget image = Semantics(
      image: true,
      label: 'Archlord et Uni se saluent du poing',
      child: Image.asset(
        kArchlordUniFistbumpAsset,
        width: box.width,
        height: box.height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ArchlordMascot(pose: ArchlordPose.thumbs, size: widget.size * 0.9),
            const SizedBox(width: 8),
            UniMascot(pose: UniPose.celebrate, size: widget.size * 0.8, effects: false),
          ],
        ),
      ),
    );

    if (_animated) {
      image = AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          // Un « bump » bref à chaque cycle, le reste du temps immobile.
          final t = _pulse.value;
          final hit = t < 0.18 ? math.sin(t / 0.18 * math.pi) : 0.0;
          return Transform.scale(scale: 1 + 0.03 * hit, alignment: Alignment.bottomCenter, child: child);
        },
        child: image,
      );
    }

    return SizedBox(width: box.width, height: box.height, child: image);
  }
}
