import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_info.dart';
import '../providers/onboarding_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/uni/archlord_mascot.dart';
import '../widgets/uni/mascot_dialogue.dart';
import '../widgets/uni/uni_mascot.dart';
import 'onboarding.dart';

/// Ce qu'Archlord et Uni se disent sur l'écran « À propos » — les mêmes
/// répliques que la page « À propos » du web, pour que le fondateur tienne
/// le même discours partout.
const List<DialogueLine> aboutDialogue = [
  DialogueLine.archlord('UniFlow est né dans notre propre faculté : on a commencé par régler nos problèmes '
      'd’emploi du temps.'),
  DialogueLine.uni('Et moi je suis arrivé pour guider les étudiants — même hors ligne, même un mois sans réseau.'),
  DialogueLine.archlord('KERNEL FORGE est une startup : UniFlow est notre premier produit, pas le dernier. On veut '
      'livrer des projets partout dans le monde.'),
  DialogueLine.uni('Chaque chose en son temps : d’abord la rentrée de la Faculté des Sciences !'),
  DialogueLine.archlord('Exactement. Et on construit ça avec vous : vos retours font le produit.'),
];

/// « À propos » : version, qui fabrique UniFlow, liens publics, et le moyen
/// de revoir la présentation du premier lancement.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  Future<void> _open(BuildContext context, String url) async {
    final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune application ne peut ouvrir ce lien.')),
      );
    }
  }

  Future<void> _replayOnboarding(BuildContext context, WidgetRef ref) async {
    // La préférence est effacée avant d'ouvrir : si l'utilisateur ferme
    // l'application en cours de route, la présentation reviendra quand même
    // au prochain démarrage hors session.
    await ref.read(onboardingSeenProvider.notifier).reset();
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const OnboardingScreen(replay: true)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        GradientHeader(
          title: 'À propos',
          subtitle: 'UniFlow · KERNEL FORGE',
          trailing: IconButton(
            tooltip: 'Retour',
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.canPop() ? context.pop() : context.go('/settings'),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _VersionCard(),
              const SizedBox(height: 14),
              const _KernelForgeCard(),
              const SizedBox(height: 14),
              SectionCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    _LinkTile(
                      icon: Icons.language_rounded,
                      title: 'Site UniFlow',
                      subtitle: uniflowWebsiteUrl,
                      onTap: () => _open(context, uniflowWebsiteUrl),
                    ),
                    const Divider(height: 1),
                    _LinkTile(
                      icon: Icons.code_rounded,
                      title: 'Code source sur GitHub',
                      subtitle: 'KERNEL-FORGE-G',
                      onTap: () => _open(context, kernelForgeGithubUrl),
                    ),
                    const Divider(height: 1),
                    _LinkTile(
                      icon: Icons.chat_outlined,
                      title: 'Groupe WhatsApp KERNEL FORGE',
                      subtitle: 'Rejoindre la communauté',
                      onTap: () => _open(context, kernelForgeWhatsappGroupUrl),
                    ),
                    const Divider(height: 1),
                    _LinkTile(
                      icon: Icons.mail_outline_rounded,
                      title: 'Nous écrire',
                      subtitle: contactEmail,
                      onTap: () => _open(context, 'mailto:$contactEmail'),
                    ),
                    const Divider(height: 1),
                    _LinkTile(
                      icon: Icons.groups_outlined,
                      title: 'L’équipe KERNEL FORGE',
                      subtitle: 'Qui fabrique UniFlow',
                      onTap: () => context.push('/equipe'),
                    ),
                    const Divider(height: 1),
                    _LinkTile(
                      key: const ValueKey('about-replay-onboarding'),
                      icon: Icons.replay_rounded,
                      title: 'Revoir la présentation',
                      subtitle: 'Les quatre écrans du premier lancement',
                      onTap: () => _replayOnboarding(context, ref),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                '© KERNEL FORGE · Yaoundé',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Écusson, nom et version.
class _VersionCard extends StatelessWidget {
  const _VersionCard();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.inputBorder),
            ),
            child: Image.asset(
              'assets/brand/uniflow_marque.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.school_rounded, color: AppColors.primaryBlue),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('UniFlow', style: AppTextStyles.h2),
                const SizedBox(height: 2),
                const Text(appVersionLabel, style: AppTextStyles.bodySmall),
                const SizedBox(height: 6),
                Text(
                  'La plateforme académique de la Faculté des Sciences — web, mobile et bureau, '
                  'sur un seul backend Appwrite.',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// La startup qui fabrique UniFlow : logo, texte, et le fondateur qui en
/// parle avec Uni.
class _KernelForgeCard extends StatelessWidget {
  const _KernelForgeCard();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.inputBorder),
                ),
                child: Image.asset(
                  'assets/logos/kernel_forge.webp',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.rocket_launch_outlined, color: AppColors.primaryBlue),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('LA STARTUP QUI LE FABRIQUE', style: AppTextStyles.overline),
                    SizedBox(height: 2),
                    Text('KERNEL FORGE', style: AppTextStyles.h2),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(kernelForgeDescription, style: AppTextStyles.body),
          const SizedBox(height: 18),
          const Text('LE FONDATEUR ET UNI', textAlign: TextAlign.center, style: AppTextStyles.overline),
          const SizedBox(height: 10),
          const MascotDialogue(
            lines: aboutDialogue,
            figureHeight: 118,
            archlordPose: ArchlordPose.laptop,
            uniPose: UniPose.pointing,
          ),
          const SizedBox(height: 14),
          const Center(child: ArchlordUniFistbump(size: 120)),
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _LinkTile({super.key, required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.primaryBlue),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      onTap: onTap,
    );
  }
}
