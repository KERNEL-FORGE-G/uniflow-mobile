import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/gamification.dart';
import '../services/gamification_service.dart';
import '../widgets/common.dart';
import '../widgets/phosphor.dart';
import '../widgets/uni/uni_mascot.dart';

// ─── Écran Badges (100 badges Appwrite) ──────────────────────────────────────

class BadgesScreen extends ConsumerWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgesAsync = ref.watch(badgesWithProgressProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A14),
      body: badgesAsync.when(
        loading: () => const LoadingView(label: 'Chargement des badges…', mascot: true),
        error: (e, _) => EmptyState(
          icon: PhosphorIconsDuotone.cloudSlash,
          title: 'Badges indisponibles',
          message: e.toString(),
          pose: UniPose.sorry,
        ),
        data: (badges) => _BadgesBody(badges: badges),
      ),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _BadgesBody extends StatefulWidget {
  final List<BadgeWithProgress> badges;
  const _BadgesBody({required this.badges});

  @override
  State<_BadgesBody> createState() => _BadgesBodyState();
}

class _BadgesBodyState extends State<_BadgesBody>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  static const _categories = [
    (BadgeCategory.assiduite,   'Assiduité'),
    (BadgeCategory.academique,  'Académique'),
    (BadgeCategory.social,      'Social'),
    (BadgeCategory.special,     'Spécial'),
    (BadgeCategory.communaute,  'Communauté'),
    (BadgeCategory.progression, 'Progression'),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _categories.length + 1, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  List<BadgeWithProgress> _forCategory(BadgeCategory? cat) => cat == null
      ? widget.badges
      : widget.badges.where((b) => b.definition.category == cat).toList();

  @override
  Widget build(BuildContext context) {
    final unlocked = widget.badges.where((b) => b.unlocked).length;
    final total    = widget.badges.length;
    final allDone  = unlocked == total && total > 0;

    return NestedScrollView(
      headerSliverBuilder: (ctx, inner) => [
        SliverToBoxAdapter(
          child: _Header(unlocked: unlocked, total: total, allDone: allDone),
        ),
        SliverToBoxAdapter(
          child: _GlobalProgressBar(unlocked: unlocked, total: total),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _TabDelegate(
            TabBar(
              controller: _tab,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFF6B7280),
              indicatorColor: const Color(0xFFF59E0B),
              indicatorWeight: 3,
              tabs: [
                const Tab(text: 'Tous'),
                ..._categories.map((c) => Tab(text: c.$2)),
              ],
            ),
          ),
        ),
      ],
      body: TabBarView(
        controller: _tab,
        children: [
          _BadgesGrid(badges: _forCategory(null)),
          ..._categories.map((c) => _BadgesGrid(badges: _forCategory(c.$1))),
        ],
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final int unlocked;
  final int total;
  final bool allDone;

  const _Header({required this.unlocked, required this.total, required this.allDone});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A2E), Color(0xFF0A0A14)],
        ),
      ),
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 16, 20, 24),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFEF4444)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(PhosphorIconsBold.medal, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Mes badges',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5)),
              Text(
                allDone
                    ? 'Collection complète !'
                    : '$unlocked sur $total obtenus',
                style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
              ),
            ]),
          ),
          if (allDone) UniMascot(pose: UniPose.celebrate, size: 52, effects: true),
        ],
      ),
    );
  }
}

// ─── Barre de progression globale ─────────────────────────────────────────────

class _GlobalProgressBar extends StatelessWidget {
  final int unlocked;
  final int total;
  const _GlobalProgressBar({required this.unlocked, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : unlocked / total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Progression globale',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
            Text('${(pct * 100).round()}%',
                style: const TextStyle(
                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            backgroundColor: const Color(0xFF1A1A2E),
            valueColor: const AlwaysStoppedAnimation(Color(0xFFF59E0B)),
          ),
        ),
      ]),
    );
  }
}

// ─── Grille de badges ─────────────────────────────────────────────────────────

class _BadgesGrid extends StatelessWidget {
  final List<BadgeWithProgress> badges;
  const _BadgesGrid({required this.badges});

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) {
      return const Center(
        child: Text('Aucun badge dans cette catégorie',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
      );
    }
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 14,
              childAspectRatio: 0.72,
            ),
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _BadgeTileAppwrite(item: badges[i], index: i),
              childCount: badges.length,
            ),
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
      ],
    );
  }
}

// ─── Tuile grille (image Appwrite) ────────────────────────────────────────────

class _BadgeTileAppwrite extends StatefulWidget {
  final BadgeWithProgress item;
  final int index;
  const _BadgeTileAppwrite({required this.item, required this.index});

  @override
  State<_BadgeTileAppwrite> createState() => _BadgeTileAppwriteState();
}

class _BadgeTileAppwriteState extends State<_BadgeTileAppwrite>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _scale = CurvedAnimation(parent: _anim, curve: Curves.elasticOut);
    _fade  = CurvedAnimation(parent: _anim, curve: Curves.easeIn);
    Future.delayed(
        Duration(milliseconds: 40 + widget.index * 30), _anim.forward);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: GestureDetector(
          onTap: () => _showDetail(context, item),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AppwriteBadgeCircle(item: item),
              const SizedBox(height: 6),
              Text(
                item.definition.name,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: item.unlocked ? Colors.white : const Color(0xFF6B7280),
                  fontSize: 10,
                  fontWeight: item.unlocked ? FontWeight.w700 : FontWeight.w400,
                  height: 1.2,
                ),
              ),
              if (item.unlocked)
                const Text('✓',
                    style: TextStyle(fontSize: 9, color: Color(0xFF10B981)))
              else
                Text(
                  '${item.progressPercent}%',
                  style: const TextStyle(
                      fontSize: 9, color: Color(0xFF6B7280)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, BadgeWithProgress item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _BadgeDetailSheet(item: item),
    );
  }
}

// ─── Cercle badge avec image Appwrite ─────────────────────────────────────────

class _AppwriteBadgeCircle extends ConsumerWidget {
  final BadgeWithProgress item;
  final double size;
  const _AppwriteBadgeCircle({required this.item, this.size = 60});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final svc       = ref.read(gamificationServiceProvider);
    final def       = item.definition;
    final unlocked  = item.unlocked;
    final imageUrl  = def.imageFileId.isNotEmpty
        ? svc.badgeImageUrl(def.imageFileId)
        : null;

    final rarityColor = _rarityColor(def.rarity);
    final pct = item.progressPercent / 100.0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Anneau de progression
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: pct,
              strokeWidth: 3,
              backgroundColor: const Color(0xFF1F2937),
              valueColor: AlwaysStoppedAnimation(
                unlocked ? rarityColor : rarityColor.withValues(alpha: 0.4),
              ),
            ),
          ),
          // Image badge ou icône fallback
          Container(
            width: size * 0.76,
            height: size * 0.76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: unlocked ? const Color(0xFF1A1A2E) : const Color(0xFF111827),
              boxShadow: unlocked
                  ? [BoxShadow(
                      color: rarityColor.withValues(alpha: 0.4),
                      blurRadius: 10,
                      spreadRadius: 1)]
                  : [],
            ),
            child: ClipOval(
              child: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      color: unlocked ? null : Colors.grey,
                      colorBlendMode: unlocked ? null : BlendMode.saturation,
                      errorBuilder: (_, __, ___) =>
                          _FallbackIcon(rarity: def.rarity, unlocked: unlocked),
                    )
                  : _FallbackIcon(rarity: def.rarity, unlocked: unlocked),
            ),
          ),
          // Cadenas si verrouillé
          if (!unlocked)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: size * 0.3,
                height: size * 0.3,
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2937),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF374151)),
                ),
                child: Icon(
                  Icons.lock_rounded,
                  size: size * 0.15,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ),
          // Étoile si légendaire + débloqué
          if (unlocked && def.rarity == BadgeRarity.legendary)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: size * 0.3,
                height: size * 0.3,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.star_rounded,
                  size: size * 0.16,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _rarityColor(BadgeRarity r) => switch (r) {
        BadgeRarity.common    => const Color(0xFF9CA3AF),
        BadgeRarity.rare      => const Color(0xFF3B82F6),
        BadgeRarity.epic      => const Color(0xFF8B5CF6),
        BadgeRarity.legendary => const Color(0xFFFFD700),
      };
}

class _FallbackIcon extends StatelessWidget {
  final BadgeRarity rarity;
  final bool unlocked;
  const _FallbackIcon({required this.rarity, required this.unlocked});

  @override
  Widget build(BuildContext context) {
    return Icon(
      PhosphorIconsBold.medal,
      size: 22,
      color: unlocked
          ? const Color(0xFFF59E0B)
          : const Color(0xFF4B5563),
    );
  }
}

// ─── Bottom sheet détail d'un badge ───────────────────────────────────────────

class _BadgeDetailSheet extends ConsumerWidget {
  final BadgeWithProgress item;
  const _BadgeDetailSheet({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final def      = item.definition;
    final unlocked = item.unlocked;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF13132B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF374151),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Image grande
          _AppwriteBadgeCircle(item: item, size: 100),
          const SizedBox(height: 16),

          // Titre
          Text(def.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: unlocked ? Colors.white : const Color(0xFF9CA3AF),
                fontSize: 20,
                fontWeight: FontWeight.w800,
              )),
          const SizedBox(height: 6),

          // Rareté
          _RarityChip(rarity: def.rarity),
          const SizedBox(height: 14),

          // Message
          Text(
            unlocked ? def.unlockedMessage : def.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),

          // Progression
          _DetailProgressBar(item: item),

          if (unlocked && item.userBadge != null) ...[
            const SizedBox(height: 12),
            Text(
              'Obtenu le ${_fmtDate(item.userBadge!.unlockedAt)}',
              style: const TextStyle(
                  color: Color(0xFF6B7280), fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),

          // XP
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.star_rounded,
                  size: 16, color: Color(0xFFF59E0B)),
              const SizedBox(width: 6),
              Text('+${def.xpReward} XP',
                  style: const TextStyle(
                      color: Color(0xFFF59E0B),
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}

class _RarityChip extends StatelessWidget {
  final BadgeRarity rarity;
  const _RarityChip({required this.rarity});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (rarity) {
      BadgeRarity.common    => (const Color(0xFF9CA3AF), 'Commun'),
      BadgeRarity.rare      => (const Color(0xFF3B82F6), 'Rare'),
      BadgeRarity.epic      => (const Color(0xFF8B5CF6), 'Épique'),
      BadgeRarity.legendary => (const Color(0xFFFFD700), 'Légendaire'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _DetailProgressBar extends StatelessWidget {
  final BadgeWithProgress item;
  const _DetailProgressBar({required this.item});

  @override
  Widget build(BuildContext context) {
    final pct = item.progressPercent / 100.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(item.progressDetail,
            style: const TextStyle(
                color: Color(0xFF9CA3AF), fontSize: 12)),
        Text('${item.progressPercent}%',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: pct,
          minHeight: 7,
          backgroundColor: const Color(0xFF1F2937),
          valueColor: AlwaysStoppedAnimation(
            item.unlocked ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
          ),
        ),
      ),
    ]);
  }
}

// ─── Tab header ───────────────────────────────────────────────────────────────

class _TabDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabDelegate(this.tabBar);

  @override double get minExtent => tabBar.preferredSize.height;
  @override double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext ctx, double shrink, bool overlaps) {
    return ColoredBox(
      color: const Color(0xFF0A0A14),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabDelegate old) => tabBar != old.tabBar;
}
