import 'package:flutter/material.dart';
import 'phosphor.dart';

import '../theme/app_theme.dart';

/// Entrée en fondu + glissement, décalée selon l'index : c'est ce qui donne
/// l'effet de cascade sur les listes.
///
/// Implicite (`TweenAnimationBuilder`) : pas de contrôleur à gérer, l'effet ne
/// se joue qu'à la première construction du widget, et il tourne aussi dans
/// les tests de mise en page. Le décalage est plafonné : au-delà de la dizaine
/// d'éléments, faire attendre la fin d'une liste longue serait pénible.
class FadeSlideIn extends StatelessWidget {
  final int index;
  final Widget child;
  final Duration duration;
  final Offset offset;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.duration = const Duration(milliseconds: 360),
    this.offset = const Offset(0, 18),
  });

  @override
  Widget build(BuildContext context) {
    final delay = Duration(milliseconds: 45 * index.clamp(0, 12));
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration + delay,
      curve: Interval(
        delay.inMilliseconds / (duration + delay).inMilliseconds,
        1,
        curve: Curves.easeOutCubic,
      ),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(offset: offset * (1 - value), child: child),
      ),
      child: child,
    );
  }
}

/// `ListView.separated` dont chaque élément entre en cascade.
class StaggeredList extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final EdgeInsetsGeometry padding;
  final double spacing;
  final ScrollPhysics? physics;
  final bool shrinkWrap;

  const StaggeredList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.padding = const EdgeInsets.all(16),
    this.spacing = 12,
    this.physics,
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding,
      physics: physics,
      shrinkWrap: shrinkWrap,
      itemCount: itemCount,
      separatorBuilder: (_, __) => SizedBox(height: spacing),
      itemBuilder: (context, index) => FadeSlideIn(index: index, child: itemBuilder(context, index)),
    );
  }
}

/// Squelette de chargement : des blocs gris qui respirent, à la place d'un
/// simple rond qui tourne. L'écran garde sa silhouette pendant l'attente.
class ShimmerBox extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadius borderRadius;

  const ShimmerBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          color: Color.lerp(AppColors.inputBorder, AppColors.surfaceMuted, _controller.value),
        ),
      ),
    );
  }
}

/// Liste de cartes squelettes, pour l'état de chargement d'un écran de liste.
class ShimmerList extends StatelessWidget {
  final int count;
  final double cardHeight;

  const ShimmerList({super.key, this.count = 5, this.cardHeight = 76});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      // Le squelette vit aussi dans une Column d'un écran déjà défilant (état
      // de chargement des « Séances du jour » du tableau de bord) : sans
      // shrinkWrap, hauteur non bornée et écran rouge au premier rendu.
      shrinkWrap: true,
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => FadeSlideIn(
        index: index,
        child: Container(
          height: cardHeight,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: Border.all(color: AppColors.inputBorder),
          ),
          child: const Row(
            children: [
              ShimmerBox(width: 44, height: 44, borderRadius: BorderRadius.all(Radius.circular(22))),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(height: 14, width: 160),
                    SizedBox(height: 8),
                    ShimmerBox(height: 11, width: 100),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bouton d'action flottant de la charte : dégradé bleu → teal.
class GradientFab extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const GradientFab({super.key, required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppColors.logoGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: AppColors.primaryBlue.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: FloatingActionButton.extended(
        heroTag: null,
        onPressed: onPressed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        icon: PhosphorIcon(icon, color: Colors.white),
        label: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
