import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/onboarding_provider.dart';
import '../providers/providers.dart';
import '../widgets/uni/mascot_dialogue.dart';
import '../widgets/uni/uni_mascot.dart';
import '../widgets/uni/archlord_mascot.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  DONNÉES — une page = une image + une palette + un texte
// ─────────────────────────────────────────────────────────────────────────────

class _OPage {
  final String bgImage;
  final Color accentColor; // couleur principale de la page
  final Color cardColor; // fond de la card inférieure
  final Color textColor; // couleur du texte dans la card
  final String tagline;
  final String title;
  final String body;
  final List<_Chip> chips;
  final List<DialogueLine> dialogue;
  final UniPose uniPose;
  final ArchlordPose archlordPose;

  const _OPage({
    required this.bgImage,
    required this.accentColor,
    required this.cardColor,
    required this.textColor,
    required this.tagline,
    required this.title,
    required this.body,
    this.chips = const [],
    this.dialogue = const [],
    this.uniPose = UniPose.wave,
    this.archlordPose = ArchlordPose.wave,
  });
}

class _Chip {
  final String icon;
  final String label;
  const _Chip(this.icon, this.label);
}

// Palette : chaque page a son identité chromatique forte
// (bleu marine, teal, violet, corail) — fond image + card colorée assortie
const _kPages = [
  _OPage(
    bgImage: 'assets/onboarding/onboarding_1_bienvenue.webp',
    accentColor: Color(0xFF1E3A8A), // bleu marine
    cardColor: Color(0xFF1E3A8A),
    textColor: Colors.white,
    tagline: 'BIENVENUE',
    title: 'Ton planning,\ntoujours à jour',
    body: 'Emploi du temps filtré sur ta filière,\navailable même hors ligne.',
    chips: [_Chip('📅', 'Hors ligne'), _Chip('🔔', 'Rappels auto')],
    dialogue: [
      DialogueLine.archlord('UniFlow affiche seulement tes cours — pas ceux de toute la fac.'),
      DialogueLine.uni('Ta filière, ton niveau, tes cours. Rien de plus.'),
      DialogueLine.archlord('Et ça marche sans connexion. On y a mis du soin.'),
    ],
    uniPose: UniPose.pointing,
    archlordPose: ArchlordPose.explain,
  ),
  _OPage(
    bgImage: 'assets/onboarding/onboarding_2_univers.webp',
    accentColor: Color(0xFF0D9488), // teal
    cardColor: Color(0xFF0D9488),
    textColor: Colors.white,
    tagline: 'COURS & NOTES',
    title: 'Cours, devoirs\net notes réunis',
    body: 'Supports, devoirs à rendre et résultats\ndès leur publication par ton enseignant.',
    chips: [_Chip('📚', 'Bibliothèque'), _Chip('✅', 'Résultats live')],
    dialogue: [
      DialogueLine.uni('Supports déposés par les profs, rendus de devoirs et notes.'),
      DialogueLine.archlord('Plus besoin de courir après les tableaux d\'affichage.'),
    ],
    uniPose: UniPose.graduate,
    archlordPose: ArchlordPose.thumbs,
  ),
  _OPage(
    bgImage: 'assets/onboarding/onboarding_3_connecte.webp',
    accentColor: Color(0xFF7C3AED), // violet
    cardColor: Color(0xFF7C3AED),
    textColor: Colors.white,
    tagline: 'MESSAGERIE',
    title: 'Ta promo dans\nta poche',
    body: 'Messages directs, forum de promo\net urgences en temps réel.',
    chips: [_Chip('💬', 'Forum'), _Chip('📣', 'Urgences')],
    dialogue: [
      DialogueLine.archlord('Chaque classe a son espace pour échanger.'),
      DialogueLine.uni('Pose tes questions aux délégués et à tes camarades.'),
    ],
    uniPose: UniPose.celebrate,
    archlordPose: ArchlordPose.wave,
  ),
  _OPage(
    bgImage: 'assets/onboarding/onboarding_4_offline.webp',
    accentColor: Color(0xFFEA580C), // corail / orange
    cardColor: Color(0xFFEA580C),
    textColor: Colors.white,
    tagline: 'KERNEL FORGE',
    title: 'Fait par des étudiants,\npour des étudiants',
    body: 'UniFlow est né dans notre propre faculté.\nTes données restent sur ton téléphone.',
    chips: [_Chip('🔒', 'Données locales'), _Chip('🚀', 'Offline-first')],
    dialogue: [
      DialogueLine.archlord('UniFlow est né ici, pensé pour nos amphis.'),
      DialogueLine.uni('Bienvenue ! On commence ensemble ?'),
    ],
    uniPose: UniPose.wave,
    archlordPose: ArchlordPose.thumbs,
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
//  ÉCRAN PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────

/// Pages d'onboarding exposées pour les tests et la navigation.
const onboardingPages = _kPages;

class OnboardingScreen extends ConsumerStatefulWidget {
  final bool replay;
  final String? next;
  final VoidCallback? onFinished;

  const OnboardingScreen({super.key, this.replay = false, this.next, this.onFinished});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> with SingleTickerProviderStateMixin {
  final _pageCtrl = PageController();
  int _index = 0;

  bool get _last => _index == _kPages.length - 1;

  void _onPageChanged(int i) => setState(() => _index = i);

  void _next() {
    if (_last) {
      _finish();
      return;
    }
    final reduce = MediaQuery.of(context).disableAnimations;
    if (reduce) {
      _pageCtrl.jumpToPage(_index + 1);
    } else {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 340),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  bool get _signedIn => ref.read(authStatusProvider) == AuthStatus.signedIn;

  Future<void> _finish() async {
    await ref.read(onboardingSeenProvider.notifier).markSeen();
    if (!mounted) return;
    if (widget.onFinished != null) {
      widget.onFinished!();
      return;
    }
    if (widget.replay) {
      Navigator.of(context).maybePop();
      return;
    }
    context.go(_signedIn ? (widget.next ?? '/accueil') : '/login');
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(authStatusProvider) == AuthStatus.signedIn;
    final lastLabel = signedIn ? 'Continuer' : 'Commencer';
    final page = _kPages[_index];
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: page.accentColor,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        color: page.accentColor,
        child: Stack(
          children: [
            // ── Zone image + card — défile page à page ────────────────
            PageView.builder(
              controller: _pageCtrl,
              itemCount: _kPages.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (_, i) => _PageSlide(page: _kPages[i]),
            ),

            // ── Logo + bouton Passer en haut ──────────────────────────
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 16, 0),
                child: Row(
                  children: [
                    // Logo pill blanc sur fond accent
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Image.asset(
                        'assets/brand/uniflow_logo_horizontal.png',
                        height: 34,
                        fit: BoxFit.contain,
                        color: Colors.white,
                        colorBlendMode: BlendMode.srcIn,
                        errorBuilder: (_, __, ___) => const Text(
                          'UniFlow',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const Spacer(),
                    AnimatedOpacity(
                      opacity: _last ? 0 : 1,
                      duration: const Duration(milliseconds: 200),
                      child: IgnorePointer(
                        ignoring: _last,
                        child: TextButton(
                          key: const ValueKey('onboarding-skip'),
                          onPressed: _finish,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.white.withValues(alpha: 0.20),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          child: const Text('Passer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Footer avec card solide (pas de glass) ────────────────
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _Footer(
                index: _index,
                count: _kPages.length,
                label: _last ? lastLabel : 'Suivant',
                page: page,
                bottomPadding: bottom,
                onNext: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SLIDE : image plein écran dans les 60% supérieurs
// ─────────────────────────────────────────────────────────────────────────────

class _PageSlide extends StatelessWidget {
  final _OPage page;
  const _PageSlide({required this.page});

  @override
  Widget build(BuildContext context) {
    // L'image occupe environ 58% de l'écran (le reste = card)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 58,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image
              Image.asset(
                page.bgImage,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        page.accentColor,
                        page.accentColor.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                ),
              ),
              // Fondu bas vers la couleur accent (transition douce vers la card)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 120,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        page.accentColor.withValues(alpha: 0.0),
                        page.accentColor,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Espace réservé pour la card footer (42%)
        Expanded(flex: 42, child: Container(color: page.cardColor)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  FOOTER : card solide colorée (zéro glass, zéro blur)
// ─────────────────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  final int index;
  final int count;
  final String label;
  final _OPage page;
  final double bottomPadding;
  final VoidCallback onNext;

  const _Footer({
    required this.index,
    required this.count,
    required this.label,
    required this.page,
    required this.bottomPadding,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: page.cardColor,
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPadding + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tag pill blanc translucide
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              page.tagline,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Titre
          Text(
            page.title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.15,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),

          // Corps
          Text(
            page.body,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.5,
            ),
          ),

          if (page.chips.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: page.chips.map((c) => _ChipBadge(chip: c)).toList(),
            ),
          ],

          // Uni / Archlord accompagnement
          if (page.dialogue.isNotEmpty && index == count - 1) ...[
            const SizedBox(height: 10),
            MascotDialogue(
              lines: page.dialogue,
              uniPose: page.uniPose,
              archlordPose: page.archlordPose,
              figureHeight: 60,
            ),
          ] else if (page.dialogue.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              page.dialogue.first.text,
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.white.withValues(alpha: 0.90),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Ligne bas : dots + bouton
          Row(
            children: [
              PageDots(count: count, index: index),
              const Spacer(),
              // Bouton blanc arrondi
              GestureDetector(
                onTap: onNext,
                child: AnimatedContainer(
                  key: const ValueKey('onboarding-next'),
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(50),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: page.accentColor,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CHIP badge
// ─────────────────────────────────────────────────────────────────────────────

class _ChipBadge extends StatelessWidget {
  final _Chip chip;
  const _ChipBadge({required this.chip});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
      ),
      child: Text(
        '${chip.icon}  ${chip.label}',
        style: const TextStyle(
          fontSize: 12,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  COMPAT — PageDots exporté pour les tests existants
// ─────────────────────────────────────────────────────────────────────────────

class PageDots extends StatelessWidget {
  final int count;
  final int index;
  const PageDots({super.key, required this.count, required this.index});

  static const double activeWidth = 24;
  static const double dotSize = 7;
  static const double gap = 3;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    return Semantics(
      label: 'Page ${index + 1} sur $count',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (i) {
          final active = i == index;
          return AnimatedContainer(
            key: ValueKey('dot-$i'),
            duration: reduce ? Duration.zero : const Duration(milliseconds: 260),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: gap),
            width: active ? activeWidth : dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              color: active ? Colors.white : Colors.white.withValues(alpha: 0.40),
              borderRadius: BorderRadius.circular(999),
            ),
          );
        }),
      ),
    );
  }
}
