import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/badges.dart';
import '../theme/app_theme.dart';
import '../widgets/phosphor.dart';

// ─── Couleurs et icônes (partagées avec screens/badges.dart) ─────────────────
// Ces fonctions sont dupliquées volontairement : `widgets/` ne doit pas importer
// depuis `screens/` pour éviter les dépendances circulaires.

Color badgeColor(StudentBadge id) {
  switch (id) {
    case StudentBadge.premierPas:  return const Color(0xFF3B82F6);
    case StudentBadge.assidu:      return const Color(0xFF10B981);
    case StudentBadge.ponctuel:    return const Color(0xFF8B5CF6);
    case StudentBadge.major:       return const Color(0xFFF59E0B);
    case StudentBadge.entraide:    return const Color(0xFFEC4899);
    case StudentBadge.sansFaute:   return const Color(0xFFEF4444);
  }
}

IconData badgeIcon(StudentBadge id) {
  switch (id) {
    case StudentBadge.premierPas:  return PhosphorIconsBold.flagBanner;
    case StudentBadge.assidu:      return PhosphorIconsBold.calendarCheck;
    case StudentBadge.ponctuel:    return PhosphorIconsBold.clockCountdown;
    case StudentBadge.major:       return PhosphorIconsBold.graduationCap;
    case StudentBadge.entraide:    return PhosphorIconsBold.chatCircle;
    case StudentBadge.sansFaute:   return PhosphorIconsBold.trophy;
  }
}

// ─── Cercle badge (identique au _BadgeCircle de badges.dart) ─────────────────

class BadgeCircle extends StatelessWidget {
  final BadgeProgress progress;
  final double size;

  const BadgeCircle({super.key, required this.progress, this.size = 60});

  @override
  Widget build(BuildContext context) {
    final unlocked = progress.unlocked;
    final color = unlocked ? badgeColor(progress.badge) : const Color(0xFF374151);
    final icon = badgeIcon(progress.badge);
    final innerSize = size * 0.75;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CirclePainter(
          color: badgeColor(progress.badge),
          progress: progress.progress.clamp(0.0, 1.0),
          unlocked: unlocked,
        ),
        child: Center(
          child: Container(
            width: innerSize,
            height: innerSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: unlocked
                  ? RadialGradient(colors: [
                      color.withValues(alpha: 0.9),
                      color.withValues(alpha: 0.6),
                    ])
                  : const RadialGradient(colors: [
                      Color(0xFF1F2937),
                      Color(0xFF111827),
                    ]),
              boxShadow: unlocked
                  ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 10, spreadRadius: 1)]
                  : [],
            ),
            child: Icon(icon,
              color: unlocked ? Colors.white : const Color(0xFF4B5563),
              size: innerSize * 0.43,
            ),
          ),
        ),
      ),
    );
  }
}

class _CirclePainter extends CustomPainter {
  final Color color;
  final double progress;
  final bool unlocked;

  const _CirclePainter({
    required this.color,
    required this.progress,
    required this.unlocked,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    paint.color = const Color(0xFF1F2937);
    canvas.drawCircle(center, radius, paint);

    if (progress > 0) {
      paint.color = unlocked ? color : color.withValues(alpha: 0.5);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CirclePainter old) =>
      old.progress != progress || old.unlocked != unlocked;
}

// ─── BadgesStrip (dashboard) ─────────────────────────────────────────────────

/// Bande horizontale des six badges pour l'accueil.
/// Utilise le MÊME style cercle+icône que l'écran /badges,
/// garantissant une cohérence visuelle totale entre les deux surfaces.
class BadgesStrip extends StatelessWidget {
  final List<BadgeProgress> badges;
  final VoidCallback? onSeeAll;

  const BadgesStrip({super.key, required this.badges, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    final unlocked = badges.where((b) => b.unlocked).length;
    // Même ordre que la page badges : enum order (pas de re-tri par progression).
    final ordered = List<BadgeProgress>.from(badges);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF13132B),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: const Color(0xFF2D2D4E)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  unlocked == 0
                      ? 'Aucun badge pour l\'instant'
                      : '$unlocked badge${unlocked > 1 ? 's' : ''} sur ${badges.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: Colors.white,
                  ),
                ),
              ),
              if (onSeeAll != null)
                TextButton(
                  onPressed: onSeeAll,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                    foregroundColor: AppColors.primaryBlue,
                  ),
                  child: const Text('Voir tout'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 105,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 6),
              itemCount: ordered.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final item = ordered[index];
                return GestureDetector(
                  onTap: onSeeAll,
                  child: SizedBox(
                    width: 70,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        BadgeCircle(progress: item, size: 62),
                        const SizedBox(height: 5),
                        Text(
                          item.badge.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: item.unlocked ? FontWeight.w700 : FontWeight.w400,
                            color: item.unlocked ? Colors.white : const Color(0xFF6B7280),
                          ),
                        ),
                        if (item.unlocked)
                          const Text('✓', style: TextStyle(fontSize: 9, color: Color(0xFF10B981)))
                        else
                          Text(
                            '${item.percent}%',
                            style: const TextStyle(fontSize: 9, color: Color(0xFF6B7280)),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget de médaille compatible avec l'ancien code (retro-compat).
/// Redirige vers [BadgeCircle] pour unifier le rendu.
@Deprecated('Utilise BadgeCircle à la place pour la cohérence visuelle')
class BadgeMedal extends StatelessWidget {
  final BadgeProgress progress;
  final double size;
  final VoidCallback? onTap;
  final bool animateUnlock;

  const BadgeMedal({
    super.key,
    required this.progress,
    this.size = 84,
    this.onTap,
    this.animateUnlock = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: BadgeCircle(progress: progress, size: size),
    );
  }
}
