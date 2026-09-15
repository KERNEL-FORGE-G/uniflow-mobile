import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/user_role.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Page affichée quand un rôle tente d'atteindre une adresse qui ne le concerne
/// pas.
///
/// Le routeur redirige ici plutôt que de laisser passer : masquer un onglet ne
/// restreint rien, l'adresse restant tapable. Cette page explique le refus au
/// lieu d'afficher un écran vide — l'utilisateur doit comprendre que ce n'est
/// pas une panne.
class AccessDeniedScreen extends ConsumerWidget {
  /// Adresse refusée, telle qu'elle a été demandée.
  final String? depuis;

  const AccessDeniedScreen({super.key, this.depuis});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentRoleProvider);

    return Column(
      children: [
        const GradientHeader(
          title: 'Accès restreint',
          subtitle: 'Cette page ne concerne pas votre rôle',
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: AppColors.primary50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_outline,
                        size: 34, color: AppColors.primaryBlue),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Votre compte est « ${role.label} »',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    depuis == null || depuis!.isEmpty
                        ? 'Cette page est réservée à d\'autres rôles.'
                        : 'La page « $depuis » est réservée à d\'autres rôles.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Si vous pensez qu\'il s\'agit d\'une erreur, demandez à un '
                    'administrateur de vérifier votre rôle.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: () => context.go('/accueil'),
                    icon: const Icon(Icons.home_outlined, size: 18),
                    label: const Text('Revenir à l\'accueil'),
                  ),
                  const SizedBox(height: 10),
                  // Ce qui est réellement accessible, plutôt qu'un renvoi sec :
                  // l'utilisateur n'a pas à deviner ce que son rôle ouvre.
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final destination in overflowFor(role).take(6))
                        ActionChip(
                          avatar: Icon(destination.icon,
                              size: 16, color: AppColors.primaryBlue),
                          label: Text(destination.label,
                              style: const TextStyle(fontSize: 12)),
                          onPressed: () => context.go(destination.path),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
