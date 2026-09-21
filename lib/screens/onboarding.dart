import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/onboarding_provider.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/phosphor.dart';
import '../widgets/uni/archlord_mascot.dart';
import '../widgets/uni/mascot_dialogue.dart';
import '../widgets/uni/uni_mascot.dart';

/// Une page de la présentation du premier lancement.
class OnboardingPage {
  /// Illustration plein cadre (`assets/onboarding/…`), `null` pour la page
  /// finale qui met en scène Archlord et Uni à la place.
  final String? illustration;
  final String title;
  final String text;

  /// Ce qu'Uni dit dans sa bulle sur cette page (vide : pas de bulle).
  final String uniSays;
  final UniPose uniPose;

  const OnboardingPage({
    required this.illustration,
    required this.title,
    required this.text,
    this.uniSays = '',
    this.uniPose = UniPose.pointing,
  });
}

/// Les quatre pages, dans l'ordre : ce que l'application fait pour un
/// étudiant, puis qui la fabrique.
const List<OnboardingPage> onboardingPages = [
  OnboardingPage(
    illustration: 'assets/onboarding/onboarding_2_univers.webp',
    title: 'L’emploi du temps de ta filière',
    text: 'Tes séances de la semaine, filtrées sur ta filière et ton niveau — rien d’autre, et toujours à jour.',
    uniSays: 'Ta filière, ton niveau, tes cours. Rien de plus.',
    uniPose: UniPose.pointing,
  ),
  OnboardingPage(
    illustration: 'assets/onboarding/onboarding_1_bienvenue.webp',
    title: 'Cours, devoirs et notes au même endroit',
    text: 'Les supports de tes UE, les devoirs à rendre et tes notes dès qu’elles sont publiées.',
    uniSays: 'Je te préviens quand un devoir approche.',
    uniPose: UniPose.graduate,
  ),
  OnboardingPage(
    illustration: 'assets/onboarding/onboarding_3_connecte.webp',
    title: 'Messagerie et forum de ta promo',
    text: 'Écris à un camarade, à ton délégué ou à un enseignant ; débats sur le forum ; les urgences te trouvent.',
    uniSays: 'Une question ? Le forum… ou moi.',
    uniPose: UniPose.headset,
  ),
  OnboardingPage(
    illustration: null,
    title: 'Fait par des étudiants, pour des étudiants',
    text: 'Tout reste sur ton téléphone : un mois sans réseau, et UniFlow s’ouvre quand même.',
  ),
];

/// Ce qu'Archlord et Uni se disent sur la dernière page.
const List<DialogueLine> onboardingDialogue = [
  DialogueLine.archlord('UniFlow est fait par des étudiants, pour des étudiants : on a commencé par régler nos '
      'propres galères d’emploi du temps.'),
  DialogueLine.uni('Et moi je te guide dans l’appli — même hors ligne, même un mois sans réseau.'),
  DialogueLine.archlord('Tes retours font le produit. Bonne rentrée !'),
];

/// Présentation affichée à chaque lancement : quatre pages, un indicateur
/// animé, « Passer », et l'état « vu » posé en mémoire pour le processus.
///
/// Le routeur l'ouvre en premier (`/bienvenue`), session ou pas : la dernière
/// page mène au tableau de bord (« Continuer ») si une session est ouverte, à
/// la connexion (« Commencer ») sinon. L'écran « À propos » la rejoue avec
/// [replay], et ferme alors la page au lieu de naviguer.
class OnboardingScreen extends ConsumerStatefulWidget {
  final bool replay;

  /// Adresse à ouvrir après la présentation quand une session est ouverte
  /// (lien externe reçu au démarrage) ; l'accueil par défaut.
  final String? next;

  /// Remplace la navigation de fin (tests, ou hôte sans routeur).
  final VoidCallback? onFinished;

  const OnboardingScreen({super.key, this.replay = false, this.next, this.onFinished});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  bool get _last => _index == onboardingPages.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_last) {
      _finish();
      return;
    }
    final reduce = MediaQuery.of(context).disableAnimations;
    if (reduce) {
      _controller.jumpToPage(_index + 1);
    } else {
      _controller.nextPage(duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
    }
  }

  bool get _signedIn => ref.read(authStatusProvider) == AuthStatus.signedIn;

  Future<void> _finish() async {
    // Posé avant de naviguer : le routeur écoute cet état et cesserait sinon
    // de laisser passer la destination, en renvoyant ici en boucle.
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
    // Session persistée : droit au tableau de bord (ou au lien reçu au
    // lancement) ; sinon la connexion. « Passer » suit le même chemin.
    context.go(_signedIn ? (widget.next ?? '/accueil') : '/login');
  }

  @override
  Widget build(BuildContext context) {
    // Le libellé de la dernière page dit où l'on va : « Continuer » vers son
    // tableau de bord quand la session est déjà ouverte, « Commencer » vers la
    // connexion sinon.
    final signedIn = ref.watch(authStatusProvider) == AuthStatus.signedIn;
    final lastLabel = signedIn ? 'Continuer' : 'Commencer';
    return Scaffold(
      backgroundColor: AppColors.background,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.meshGradient),
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(showSkip: !_last, onSkip: _finish),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: onboardingPages.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) {
                    final page = onboardingPages[i];
                    return page.illustration == null
                        ? _FinalPage(key: ValueKey('page-$i'), page: page)
                        : _FeaturePage(key: ValueKey('page-$i'), page: page);
                  },
                ),
              ),
              _Footer(
                index: _index,
                count: onboardingPages.length,
                label: _last ? lastLabel : 'Suivant',
                onNext: _next,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final bool showSkip;
  final VoidCallback onSkip;

  const _TopBar({required this.showSkip, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: ShaderMask(
              shaderCallback: (bounds) =>
                  AppColors.logoGradient.createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
              child: const Text(
                'UniFlow',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
          ),
          // Toujours dans l'arbre, invisible sur la dernière page : la barre
          // garde sa hauteur et le titre ne saute pas.
          AnimatedOpacity(
            opacity: showSkip ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: !showSkip,
              child: TextButton(
                key: const ValueKey('onboarding-skip'),
                onPressed: onSkip,
                child: const Text('Passer'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Une page « fonctionnalité » : illustration, titre, texte, et Uni qui
/// glisse un mot.
///
/// Tout est dans un défilement : sur 320×568 avec le texte agrandi, la page
/// ne tient pas en hauteur, et un débordement rouge serait la première chose
/// qu'un nouvel utilisateur verrait.
class _FeaturePage extends StatelessWidget {
  final OnboardingPage page;
  const _FeaturePage({super.key, required this.page});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final illustrationHeight = (c.maxHeight * 0.42).clamp(140.0, 320.0);
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight - 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: kAuthCompactWidth),
                child: _Enter(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Illustration(asset: page.illustration!, height: illustrationHeight),
                      const SizedBox(height: 22),
                      Text(page.title, textAlign: TextAlign.center, style: AppTextStyles.h1),
                      const SizedBox(height: 10),
                      Text(page.text, textAlign: TextAlign.center, style: AppTextStyles.body),
                      if (page.uniSays.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: UniMascot(
                            pose: page.uniPose,
                            size: 68,
                            effects: false,
                            bubble: Text(page.uniSays),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Dernière page : Archlord et Uni discutent, puis le titre et le texte.
class _FinalPage extends StatelessWidget {
  final OnboardingPage page;
  const _FinalPage({super.key, required this.page});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final figureHeight = (c.maxHeight * 0.26).clamp(96.0, 140.0);
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight - 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: kAuthCompactWidth),
                child: _Enter(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      MascotDialogue(
                        lines: onboardingDialogue,
                        figureHeight: figureHeight,
                        archlordPose: ArchlordPose.explain,
                        uniPose: UniPose.wave,
                      ),
                      const SizedBox(height: 22),
                      Text(page.title, textAlign: TextAlign.center, style: AppTextStyles.h1),
                      const SizedBox(height: 10),
                      Text(page.text, textAlign: TextAlign.center, style: AppTextStyles.body),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// L'illustration dans une carte blanche arrondie : les images ont un fond
/// blanc, la carte évite qu'il se découpe brutalement sur le dégradé.
class _Illustration extends StatelessWidget {
  final String asset;
  final double height;

  const _Illustration({required this.asset, required this.height});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        height: height,
        constraints: const BoxConstraints(maxWidth: 360),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.inputBorder),
          boxShadow: [
            BoxShadow(
                color: AppColors.primaryBlue.withValues(alpha: 0.10), blurRadius: 30, offset: const Offset(0, 14)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: AspectRatio(
          aspectRatio: 1,
          child: Image.asset(
            asset,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => const Center(
              child: PhosphorIcon(PhosphorIconsDuotone.graduationCap, size: 56, color: AppColors.primaryBlue),
            ),
          ),
        ),
      ),
    );
  }
}

/// Entrée douce du contenu d'une page : il monte de quelques points en
/// apparaissant. Sans mouvement demandé, il est simplement là.
class _Enter extends StatelessWidget {
  final Widget child;
  const _Enter({required this.child});

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    if (reduce) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 18), child: child),
      ),
      child: child,
    );
  }
}

/// Indicateur de page et bouton principal.
class _Footer extends StatelessWidget {
  final int index;
  final int count;
  final String label;
  final VoidCallback onNext;

  const _Footer({required this.index, required this.count, required this.label, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 6, 24, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PageDots(count: count, index: index),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kAuthCompactWidth),
            child: SizedBox(
              width: double.infinity,
              child: GradientButton(
                key: const ValueKey('onboarding-next'),
                label: label,
                icon: PhosphorIconsBold.arrowRight,
                onPressed: onNext,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Points de pagination : le point actif s'étire en pilule, les autres
/// restent ronds. Animé par `AnimatedContainer`, donc immobile quand le
/// système le demande (durée nulle).
class PageDots extends StatelessWidget {
  final int count;
  final int index;

  const PageDots({super.key, required this.count, required this.index});

  /// Largeur du point actif et des autres — exposées pour le test.
  static const double activeWidth = 24;
  static const double dotSize = 8;
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
              color: active ? AppColors.primaryBlue : AppColors.primary100,
              borderRadius: BorderRadius.circular(999),
            ),
          );
        }),
      ),
    );
  }
}
