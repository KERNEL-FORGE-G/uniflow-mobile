import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/onboarding_provider.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/uni/uni_mascot.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  DONNÉES DES PAGES
// ─────────────────────────────────────────────────────────────────────────────

class OnboardingPage {
  final String illustration;
  final String title;
  final String subtitle;
  final String uniSays;
  final UniPose uniPose;
  final Color accentColor;
  final Color bgFrom;
  final Color bgTo;

  const OnboardingPage({
    required this.illustration,
    required this.title,
    required this.subtitle,
    this.uniSays = '',
    this.uniPose = UniPose.pointing,
    this.accentColor = AppColors.primaryBlue,
    this.bgFrom = const Color(0xFF7C5CFC),
    this.bgTo = const Color(0xFFD4C9FF),
  });
}

const List<OnboardingPage> onboardingPages = [
  OnboardingPage(
    illustration: 'assets/onboarding/onboarding_2_univers.webp',
    title: 'Ton emploi du temps\ntoujours à jour',
    subtitle:
        'Séances filtrées sur ta filière et ton niveau,\nrien d\'autre — disponible même hors ligne.',
    uniSays: 'Ta filière, ton niveau, tes cours.',
    uniPose: UniPose.pointing,
    accentColor: Color(0xFF1E3A8A),
    bgFrom: Color(0xFF1E3A8A),
    bgTo: Color(0xFF2D5BE3),
  ),
  OnboardingPage(
    illustration: 'assets/onboarding/onboarding_1_bienvenue.webp',
    title: 'Cours, devoirs et notes\nau même endroit',
    subtitle:
        'Supports de cours, devoirs à rendre et résultats\ndès leur publication.',
    uniSays: 'Je te préviens quand un devoir approche.',
    uniPose: UniPose.graduate,
    accentColor: Color(0xFF0D9488),
    bgFrom: Color(0xFF0D9488),
    bgTo: Color(0xFF14B8A8),
  ),
  OnboardingPage(
    illustration: 'assets/onboarding/onboarding_3_connecte.webp',
    title: 'Messagerie et forum\nde ta promo',
    subtitle:
        'Écris à un camarade, débats sur le forum,\nreçois les urgences en temps réel.',
    uniSays: 'Une question ? Le forum… ou moi.',
    uniPose: UniPose.headset,
    accentColor: Color(0xFF2D4FA8),
    bgFrom: Color(0xFF152A66),
    bgTo: Color(0xFF2D4FA8),
  ),
  OnboardingPage(
    illustration: 'assets/onboarding/onboarding_2_univers.webp',
    title: 'Fait par des étudiants,\npour des étudiants',
    subtitle:
        'Tout reste sur ton téléphone :\nun mois sans réseau et UniFlow s\'ouvre quand même.',
    uniSays: 'Bonne rentrée !',
    uniPose: UniPose.wave,
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
          // Logo pill
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.45), width: 1),
            ),
            child: const Text(
              'UniFlow',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.2),
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
                      Colors.white.withValues(alpha: 0.2),
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
    final size = MediaQuery.sizeOf(context);
    final imgH = (size.height * 0.37).clamp(180.0, 320.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        children: [
          // ── Illustration dans une carte verre ─────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                height: imgH,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.5),
                      width: 1.5),
                ),
                child: _AnimatedIllustration(asset: page.illustration),
              ),
            ),
          ),
          const SizedBox(height: 32),
          // ── Titre ─────────────────────────────────────────────────────
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 14),
          // ── Sous-titre ────────────────────────────────────────────────
          Text(
            page.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.5,
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.55,
            ),
          ),
          // ── Bulle Uni ─────────────────────────────────────────────────
          if (page.uniSays.isNotEmpty) ...[
            const SizedBox(height: 20),
            _UniSpeechBubble(text: page.uniSays),
          ],
          const SizedBox(height: 16),
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
              size: 80, color: Colors.white.withValues(alpha: 0.55)),
        ),
      ),
    );
  }
}

class _UniSpeechBubble extends StatelessWidget {
  final String text;
  const _UniSpeechBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.38), width: 1),
          ),
          child: Row(
            children: [
              const Text('✨ ', style: TextStyle(fontSize: 16)),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
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
