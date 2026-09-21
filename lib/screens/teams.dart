import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/team_member.dart';
import '../repositories/team_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Page Équipe KERNEL FORGE, alignée sur la page publique `/teams` du web.
///
/// Elle lit la collection `team_members` — la même que le web et le desktop, et
/// non une liste figée comme avant, qui ne comptait ici que six membres contre
/// neuf sur le web. La page est en **lecture seule** : l'ajout, la modification
/// et la suppression se font depuis l'espace d'administration du web.
class TeamsScreen extends ConsumerStatefulWidget {
  const TeamsScreen({super.key});

  @override
  ConsumerState<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends ConsumerState<TeamsScreen> {
  /// Filtre actif, « Tous » par défaut comme sur le web.
  String _filtre = 'Tous';

  /// Les neuf technologies du bandeau, identiques à celles du web.
  static const List<String> _technologies = [
    'React 18',
    'TypeScript',
    'Tailwind CSS',
    'PWA Offline-First',
    'SQLite / IndexedDB',
    'NestJS API',
    'Express Backend',
    'WebSockets',
    'QR Code Engine',
  ];

  Future<void> _ouvrir(String url) async {
    final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune application ne peut ouvrir ce lien.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final equipeAsync = ref.watch(teamMembersProvider);

    return Scaffold(
      body: Column(
        children: [
          const GradientHeader(
            title: 'L\'Équipe KERNEL FORGE',
            subtitle: 'Université de Yaoundé I',
          ),
          Expanded(
            child: equipeAsync.when(
              loading: () => const LoadingView(label: 'Chargement de l\'équipe…'),
              error: (error, _) => LoadErrorView(
                title: 'L\'équipe n\'a pas pu être chargée',
                error: error,
                onRetry: () => ref.invalidate(teamMembersProvider),
              ),
              data: (membres) => _contenu(membres),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contenu(List<TeamMember> membres) {
    final visibles = filterTeamMembers(membres, _filtre);

    return LayoutBuilder(
      builder: (context, contraintes) {
        final largeur = contraintes.maxWidth;
        // Même seuil que le web (`sm:grid-cols-2`, 640 px) : au téléphone une
        // seule colonne, comme la page publique à cette largeur.
        final colonnes = largeur >= 640 ? 2 : 1;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          children: [
            const _Intro(),
            const SizedBox(height: 16),
            _Statistiques(membres: membres),
            const SizedBox(height: 24),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nos Talents', style: AppTextStyles.h3),
                SizedBox(height: 2),
                Text(
                  'Découvrez l\'équipe et leurs domaines d\'expertise',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: teamFilters
                  .map((filtre) => _PastilleFiltre(
                        label: filtre,
                        actif: _filtre == filtre,
                        onTap: () => setState(() => _filtre = filtre),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            if (visibles.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  'Aucun membre dans cette catégorie.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall,
                ),
              )
            else
              _Grille(
                membres: visibles,
                colonnes: colonnes,
                onGithub: (membre) => _ouvrir('https://github.com/${membre.github}'),
                onMail: (membre) => _ouvrir('mailto:${membre.email}'),
              ),
            const SizedBox(height: 24),
            const _BandeauTechnologies(technologies: _technologies),
            const SizedBox(height: 16),
            _AppelGithub(onTap: () => _ouvrir('https://github.com/KERNEL-FORGE-G')),
          ],
        );
      },
    );
  }
}

/// Cartes des membres, réparties en [colonnes] colonnes.
///
/// Les cartes sont hautes de ce qu'exige leur contenu — un nom long sur deux
/// lignes, un rôle, une sous-équipe — plutôt que d'une hauteur fixe : avec un
/// texte agrandi par les réglages d'accessibilité, une hauteur imposée tronque
/// ou déborde. `IntrinsicHeight` égalise les deux cartes d'une même ligne.
class _Grille extends StatelessWidget {
  final List<TeamMember> membres;
  final int colonnes;
  final void Function(TeamMember) onGithub;
  final void Function(TeamMember) onMail;

  const _Grille({
    required this.membres,
    required this.colonnes,
    required this.onGithub,
    required this.onMail,
  });

  @override
  Widget build(BuildContext context) {
    final lignes = <Widget>[];
    for (var i = 0; i < membres.length; i += colonnes) {
      final tranche = membres.sublist(i, (i + colonnes).clamp(0, membres.length));
      lignes.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = 0; j < colonnes; j++) ...[
                if (j > 0) const SizedBox(width: 12),
                Expanded(
                  child: j < tranche.length
                      ? _CarteMembre(
                          membre: tranche[j],
                          onGithub: () => onGithub(tranche[j]),
                          onMail: () => onMail(tranche[j]),
                        )
                      // Colonne vide en fin de liste : sans elle, la dernière
                      // carte d'un nombre impair s'étalerait sur toute la
                      // largeur et casserait l'alignement.
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
      if (i + colonnes < membres.length) lignes.add(const SizedBox(height: 12));
    }
    return Column(children: lignes);
  }
}

class _CarteMembre extends StatelessWidget {
  final TeamMember membre;
  final VoidCallback onGithub;
  final VoidCallback onMail;

  const _CarteMembre({
    required this.membre,
    required this.onGithub,
    required this.onMail,
  });

  @override
  Widget build(BuildContext context) {
    final accent = teamAccentStyle(mapTeamAccent(membre.accent));

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Coins arrondis plutôt qu'un cercle : la page web affiche les
              // photos de l'équipe en `rounded-2xl`.
              SilhouetteAvatar(
                avatarFileId: membre.avatarFileId,
                size: 56,
                borderRadius: BorderRadius.circular(16),
              ),
              const SizedBox(width: 12),
              if (membre.badge.isNotEmpty)
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: accent.background,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: accent.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(teamMemberIcon(membre), size: 12, color: accent.foreground),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            membre.badge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: accent.foreground,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            membre.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            membre.role,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryBlue,
            ),
          ),
          if (membre.subTeam.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              membre.subTeam,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.inputBorder),
          const SizedBox(height: 10),
          Row(
            children: [
              if (membre.github.isNotEmpty)
                Flexible(
                  child: _BoutonLien(
                    icone: Icons.code,
                    label: '@${membre.github}',
                    onTap: onGithub,
                  ),
                ),
              const Spacer(),
              if (membre.email.isNotEmpty)
                _BoutonIcone(
                  icone: Icons.mail_outline,
                  tooltip: membre.email,
                  onTap: onMail,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BoutonLien extends StatelessWidget {
  final IconData icone;
  final String label;
  final VoidCallback onTap;

  const _BoutonLien({required this.icone, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icone, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
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

class _BoutonIcone extends StatelessWidget {
  final IconData icone;
  final String tooltip;
  final VoidCallback onTap;

  const _BoutonIcone({required this.icone, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: AppColors.inputBorder),
            ),
            child: Icon(icone, size: 16, color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _PastilleFiltre extends StatelessWidget {
  final String label;
  final bool actif;
  final VoidCallback onTap;

  const _PastilleFiltre({required this.label, required this.actif, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: actif ? AppColors.primaryBlue : AppColors.cardWhite,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: actif ? AppColors.primaryBlue : AppColors.inputBorder),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: actif ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Texte d'introduction, sous l'en-tête.
class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // La pastille est enveloppée dans un `Flexible` : la `Row`
              // extérieure mesure ses enfants non flexibles sans contrainte de
              // largeur, si bien que le libellé ci-dessous ne pouvait pas se
              // replier et faisait déborder la ligne de 33 px à 320 px de large
              // avec le texte agrandi (×1.3). Avec cette contrainte, le
              // `Flexible` intérieur reçoit une largeur bornée et peut élider.
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.code, size: 13, color: AppColors.teal),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'KERNEL FORGE — UY1',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Les développeurs et ingénieurs passionnés qui ont conçu UniFlow pour '
            'transformer la gestion académique universitaire en Afrique.',
            style: AppTextStyles.body,
          ),
        ],
      ),
    );
  }
}

/// Les quatre tuiles de statistiques, calculées depuis la liste.
class _Statistiques extends StatelessWidget {
  final List<TeamMember> membres;

  const _Statistiques({required this.membres});

  @override
  Widget build(BuildContext context) {
    // Les tuiles sont calculées et non écrites en dur : la page web affichait
    // « 9 », « 5 », « 3 », « 1 », et ces chiffres seraient devenus faux dès le
    // premier ajout de membre depuis l'administration.
    final tuiles = <Widget>[
      _tuile('Membres au total', membres.length, Icons.groups_outlined, AppColors.primaryBlue),
      _tuile('Ingénieurs Frontend', _compter('Frontend'), Icons.laptop_outlined, AppColors.purple),
      _tuile('Ingénieurs Backend & BD', _compter('Backend'), Icons.dns_outlined, AppColors.teal),
      _tuile('Lead & Architecture', _compter('Leadership'), Icons.workspace_premium_outlined, AppColors.warning),
    ];

    return LayoutBuilder(
      builder: (context, contraintes) {
        // Deux tuiles par ligne au téléphone, quatre sur une fenêtre large :
        // c'est ce que fait le web (`grid-cols-2 sm:grid-cols-4`).
        final parLigne = contraintes.maxWidth >= 640 ? 4 : 2;
        const espacement = 10.0;
        final largeur = (contraintes.maxWidth - espacement * (parLigne - 1)) / parLigne;
        return Wrap(
          spacing: espacement,
          runSpacing: espacement,
          children: tuiles.map((tuile) => SizedBox(width: largeur, child: tuile)).toList(),
        );
      },
    );
  }

  int _compter(String equipe) => membres.where((m) => m.team == equipe).length;

  Widget _tuile(String label, int valeur, IconData icone, Color couleur) {
    return SectionCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: couleur.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icone, size: 16, color: couleur),
          ),
          const SizedBox(height: 8),
          Text(
            '$valeur',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _BandeauTechnologies extends StatelessWidget {
  final List<String> technologies;

  const _BandeauTechnologies({required this.technologies});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'STACK TECHNIQUE PROJET',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 6),
          const Text('Conçu avec les meilleures technologies web', style: AppTextStyles.h3),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: technologies
                .map((technologie) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: AppColors.inputBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_outline, size: 13, color: AppColors.teal),
                          const SizedBox(width: 5),
                          // `Flexible` : à 320 px de large avec le texte agrandi
                          // (×1.3), « SQLite / IndexedDB » et « PWA Offline-First »
                          // dépassaient la largeur de la pastille de 4 à 48 px.
                          // Le libellé se replie en points de suspension au lieu
                          // de pousser la carte.
                          Flexible(
                            child: Text(
                              technologie,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _AppelGithub extends StatelessWidget {
  final VoidCallback onTap;

  const _AppelGithub({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.logoGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      ),
      child: Column(
        children: [
          const Icon(Icons.auto_awesome, color: Color(0xFFFCD34D), size: 26),
          const SizedBox(height: 8),
          const Text(
            'Rejoignez l\'organisation KERNEL FORGE',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            'Projet open source développé avec passion pour la communauté académique.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.85)),
          ),
          const SizedBox(height: 14),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(11),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(11),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.code, size: 16, color: AppColors.primaryBlue),
                    SizedBox(width: 7),
                    // `Flexible` : sans marge de repli, ce libellé débordait de
                    // 127 px à 320 px de large avec le texte agrandi (×1.3).
                    // Le bas de la page n'était jamais peint par le balayage de
                    // mise en page — la `ListView` ne construit que le visible —
                    // donc le débordement n'apparaissait qu'à l'usage.
                    Flexible(
                      child: Text(
                        'Organisation GitHub',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.open_in_new, size: 13, color: AppColors.primaryBlue),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
