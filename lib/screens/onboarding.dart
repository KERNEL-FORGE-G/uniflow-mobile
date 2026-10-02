import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/onboarding_provider.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/uni/uni_mascot.dart';
import '../widgets/uni/archlord_mascot.dart';
import '../widgets/uni/mascot_dialogue.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  DONNÉES DES PAGES
// ─────────────────────────────────────────────────────────────────────────────

class OnboardingPage {
  final String illustration;
  final String title;
  final String subtitle;
  final List<DialogueLine> dialogue;
  final UniPose uniPose;
  final ArchlordPose archlordPose;
  final Color accentColor;
  final Color bgFrom;
  final Color bgTo;

  const OnboardingPage({
    required this.illustration,
    required this.title,
    required this.subtitle,
    this.dialogue = const [],
    this.uniPose = UniPose.pointing,
    this.archlordPose = ArchlordPose.explain,
    this.accentColor = AppColors.primaryBlue,
    this.bgFrom = const Color(0xFF1E3A8A),
    this.bgTo = const Color(0xFF2D5BE3),
  });
}

const List<OnboardingPage> onboardingPages = [
  OnboardingPage(
    illustration: 'assets/onboarding/onboarding_2_univers.webp',
    title: 'Ton emploi du temps\ntoujours à jour',
    subtitle:
        'Séances filtrées sur ta filière et ton niveau,\ndisponible même hors ligne.',
    dialogue: [
      DialogueLine.archlord('UniFlow affiche seulement tes cours — pas ceux de toute la fac.'),
      DialogueLine.uni('Ta filière, ton niveau, tes cours. Rien de plus.'),
      DialogueLine.archlord('Et ça marche sans connexion. On y a mis du soin.'),
    ],
    uniPose: UniPose.pointing,
    archlordPose: ArchlordPose.explain,
    accentColor: Color(0xFF1E3A8A),
    bgFrom: Color(0xFF1E3A8A),
    bgTo: Color(0xFF2D5BE3),
  ),
  OnboardingPage(
    illustration: 'assets/onboarding/onboarding_1_bienvenue.webp',
    title: 'Cours, devoirs et notes\nau même endroit',
    subtitle:
        'Supports de cours, devoirs à rendre et résultats\ndès leur publication.',
    dialogue: [
      DialogueLine.uni('Je te préviens quand un devoir approche — plus d\'excuses !'),
      DialogueLine.archlord('Les notes tombent directement ici, sans passer par l\'admin.'),
      DialogueLine.uni('Et les cours téléchargés restent disponibles hors ligne.'),
    ],
    uniPose: UniPose.graduate,
    archlordPose: ArchlordPose.laptop,
    accentColor: Color(0xFF0D9488),
    bgFrom: Color(0xFF0D9488),
    bgTo: Color(0xFF14B8A8),
  ),
  OnboardingPage(
    illustration: 'assets/onboarding/onboarding_3_connecte.webp',
    title: 'Messagerie et forum\nde ta promo',
    subtitle:
        'Écris à un camarade, débats sur le forum,\nreçois les urgences en temps réel.',
    dialogue: [
      DialogueLine.archlord('Forum, messages directs, groupes de promo — tout ici.'),
      DialogueLine.uni('Une question ? Le forum… ou directement moi !'),
      DialogueLine.archlord('Les annonces urgentes arrivent en notification instantanée.'),
    ],
    uniPose: UniPose.headset,
    archlordPose: ArchlordPose.pointing,
    accentColor: Color(0xFF2D4FA8),
    bgFrom: Color(0xFF152A66),
    bgTo: Color(0xFF2D4FA8),
  ),
  OnboardingPage(
    illustration: 'assets/onboarding/onboarding_2_univers.webp',
    title: 'Fait par des étudiants,\npour des étudiants',
    subtitle:
        'Tes données restent sur ton téléphone.\nUn mois sans réseau et UniFlow s\'ouvre quand même.',
    dialogue: [
      DialogueLine.archlord('UniFlow est né dans notre propre fac. On a résolu nos propres problèmes.'),
      DialogueLine.uni('Et on continue à le construire avec vos retours. Bonne rentrée !'),
      DialogueLine.archlord('KERNEL FORGE — UniFlow est notre premier produit, pas le dernier.'),
    ],
    uniPose: UniPose.wave,
    archlordPose: ArchlordPose.thumbs,
    accentColor: Color(0xFF0A7167),
    bgFrom: Color(0xFF0A7167),
    bgTo: Color(0xFF0D9488),
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
//  ÉCRAN PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────

class OnboardingScreen extends ConsumerStatefulWidget {
  final bool replay;
  final String? next;
  final VoidCallback? onFinished;

  const OnboardingScreen(
      {super.key, this.replay = false, this.next, this.onFinished});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  final _pageCtrl = PageController();
  int _index = 0;

  // Couleurs animées du fond
  late AnimationController _bgAnimCtrl;
  Color _fromColor = onboardingPages[0].bgFrom;
  Color _toColor = onboardingPages[0].bgTo;
  Color _fromColorTarget = onboardingPages[0].bgFrom;
  Color _toColorTarget = onboardingPages[0].bgTo;

  bool get _last => _index == onboardingPages.length - 1;

  @override
  void initState() {
    super.initState();
    _bgAnimCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _bgAnimCtrl.addListener(() {
      setState(() {
        _fromColor =
            Color.lerp(_fromColor, _fromColorTarget, _bgAnimCtrl.value)!;
        _toColor =
            Color.lerp(_toColor, _toColorTarget, _bgAnimCtrl.value)!;
      });
    });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _bgAnimCtrl.dispose();
    super.dispose();
  }

  void _onPageChanged(int i) {
    final page = onboardingPages[i];
    _fromColorTarget = page.bgFrom;
    _toColorTarget = page.bgTo;
    _bgAnimCtrl.forward(from: 0);
    setState(() => _index = i);
  }

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
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic);
    }
  }

  bool get _signedIn =>
      ref.read(authStatusProvider) == AuthStatus.signedIn;

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
  Widget build(BuildContext context) {
    final signedIn =
        ref.watch(authStatusProvider) == AuthStatus.signedIn;
    final page = onboardingPages[_index];

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_fromColor, _toColor],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(showSkip: !_last, onSkip: _finish),
              Expanded(
                child: PageView.builder(
                  controller: _pageCtrl,
                  itemCount: onboardingPages.length,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (_, i) => _PageContent(
                    key: ValueKey('ob-$i'),
                    page: onboardingPages[i],
                  ),
                ),
              ),
              _Footer(
                index: _index,
                count: onboardingPages.length,
                label: _last
                    ? (signedIn ? 'Continuer →' : 'Commencer →')
                    : 'Suivant',
                accentColor: page.accentColor,
                onNext: _next,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TOP BAR
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final bool showSkip;
  final VoidCallback onSkip;

  const _TopBar({required this.showSkip, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 16, 0),
      child: Row(
        children: [
          // Logo image (vrai logo horizontal UniFlow)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Image.asset(
              'assets/brand/uniflow_logo_horizontal.png',
              height: 28,
              fit: BoxFit.contain,
              // Fallback si l'image ne charge pas
              errorBuilder: (_, __, ___) => const Text(
                'UniFlow',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryBlue,
                    letterSpacing: 0.2),
              ),
            ),
          ),
          const Spacer(),
          AnimatedOpacity(
            opacity: showSkip ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: !showSkip,
              child: TextButton(
                key: const ValueKey('onboarding-skip'),
                onPressed: onSkip,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor:
                      Colors.white.withValues(alpha: 0.25),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text('Passer',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PAGE CONTENT
// ─────────────────────────────────────────────────────────────────────────────

class _PageContent extends StatelessWidget {
  final OnboardingPage page;

  const _PageContent({super.key, required this.page});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        children: [
          // ── Illustration dans une carte blanche arrondie ──────────────
          Expanded(
            flex: 5,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 20,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: _AnimatedIllustration(asset: page.illustration),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // ── Titre ─────────────────────────────────────────────────────
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          // ── Sous-titre ────────────────────────────────────────────────
          Text(
            page.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.82),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          // ── Dialogue Archlord + Uni en bas ───────────────────────────
          if (page.dialogue.isNotEmpty)
            Expanded(
              flex: 3,
              child: MascotDialogue(
                lines: page.dialogue,
                uniPose: page.uniPose,
                archlordPose: page.archlordPose,
                figureHeight: 96,
                interval: const Duration(milliseconds: 3200),
              ),
            ),
          if (page.dialogue.isEmpty) const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _AnimatedIllustration extends StatelessWidget {
  final String asset;
  const _AnimatedIllustration({required this.asset});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutBack,
      builder: (_, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.82 + 0.18 * v, child: child),
      ),
      child: Image.asset(
        asset,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Center(
          child: Icon(Icons.school_rounded,
              size: 80, color: AppColors.primaryBlue.withValues(alpha: 0.25)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  FOOTER
// ─────────────────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  final int index;
  final int count;
  final String label;
  final Color accentColor;
  final VoidCallback onNext;

  const _Footer({
    required this.index,
    required this.count,
    required this.label,
    required this.accentColor,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(count, (i) {
              final active = i == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOut,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: active ? 28.0 : 8.0,
                height: 8,
                decoration: BoxDecoration(
                  color: active
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.38),
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          // Bouton
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const ValueKey('onboarding-next'),
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: accentColor,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                textStyle: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
              child: Text(label),
            ),
          ),
        ],
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

  static const double activeWidth = 28;
  static const double dotSize = 8;
  static const double gap = 4;

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
            duration:
                reduce ? Duration.zero : const Duration(milliseconds: 260),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: gap),
            width: active ? activeWidth : dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              color: active
                  ? AppColors.primaryBlue
                  : AppColors.primary100,
              borderRadius: BorderRadius.circular(999),
            ),
          );
        }),
      ),
    );
  }
}
