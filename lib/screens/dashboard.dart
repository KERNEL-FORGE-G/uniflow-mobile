import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../offline/offline_widgets.dart';
import 'package:go_router/go_router.dart';
import '../widgets/common.dart';
import '../theme/app_theme.dart';
import '../providers/providers.dart';
import '../providers/session_controller.dart';
import '../utils/avatar.dart';
// `gradesListProvider` et `assignmentBoardProvider` sont déclarés dans ces deux
// écrans : l'accueil les réutilise plutôt que de relancer ses propres requêtes.
import 'grades.dart';
import 'assignments.dart';

/// Une action rapide : icône, libellé, couleur et route.
class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final String route;

  const _QuickAction(this.icon, this.label, this.color, this.route);
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  /// Les quatre raccourcis de l'accueil, déclarés ici pour que la grille et les
  /// libellés restent cohérents entre eux.
  static const List<_QuickAction> _actions = [
    _QuickAction(Icons.calendar_month_outlined, 'Planning', AppColors.primaryBlue, '/notes'),
    _QuickAction(Icons.library_books_outlined, 'Bibliothèque', AppColors.teal, '/bibliotheque'),
    _QuickAction(Icons.qr_code_scanner, 'Scanner QR', AppColors.purple, '/presence'),
    _QuickAction(Icons.forum_outlined, 'Forum', AppColors.info, '/forum'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final sync = ref.watch(academicSyncProvider);
    final gradesAsync = ref.watch(gradesListProvider);
    final assignmentsAsync = ref.watch(assignmentBoardProvider);

    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            title: 'UniFlow Mobile',
            subtitle: user != null ? 'Bonjour, ${user.name}' : 'Bienvenue sur UniFlow',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SyncIndicator(),
                // Affiché seulement si une photo existe : sans elle, l'en-tête
                // reste exactement celui d'avant, logo compris.
                if (user?.avatarFileId != null && user!.avatarFileId!.isNotEmpty) ...[
                  Avatar(
                    initials: initialsOf(user.name),
                    avatarFileId: user.avatarFileId,
                    size: 40,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 10),
                ],
                SizedBox(
                  width: 40,
                  height: 40,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    // L'écusson est bleu marine : posé à même le dégradé bleu
                    // foncé de l'en-tête, son mortier s'y confondait et il ne
                    // restait que la flèche teal. La pastille claire le
                    // détache ; elle était auparavant cuite dans le PNG, sur
                    // fond blanc opaque, ce qui interdisait d'employer le logo
                    // transparent.
                    child: ColoredBox(
                      color: AppColors.cardWhite,
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: Image.asset(
                          'assets/brand/uniflow_marque.png',
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.school_rounded,
                            color: AppColors.primaryBlue,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              children: [
                if (sync.hasError) ...[
                  ErrorBanner(
                    message: _syncMessage(sync.error),
                    // Une session expirée ne se répare pas en réessayant : on
                    // ferme proprement et la garde du routeur ramène à la
                    // connexion, au lieu d'un bouton « Réessayer » sans effet.
                    onRetry: isSessionExpired(sync.error)
                        ? () =>
                            ref.read(sessionControllerProvider).signOut(deleteRemoteSession: false, keepLocalData: true)
                        : () => ref.invalidate(academicSyncProvider),
                  ),
                  const SizedBox(height: 18),
                ],
                const SectionTitle(title: 'Vue d\'ensemble'),
                _buildQuickStats(gradesAsync, assignmentsAsync),
                const SizedBox(height: 24),
                const SectionTitle(title: 'Actions rapides'),
                _buildActionGrid(context),
                const SizedBox(height: 24),
                const SectionTitle(title: 'Prochains devoirs'),
                _buildRecentAssignments(assignmentsAsync),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Rend visible un échec de synchronisation Appwrite : l'erreur était
  /// auparavant seulement imprimée en console, l'utilisateur voyait un écran
  /// vide sans savoir si les données étaient absentes ou la requête refusée.
  String _syncMessage(Object? error) {
    final text = error?.toString() ?? '';
    if (text.contains('SocketException') || text.contains('Failed host lookup')) {
      return 'Appwrite est injoignable depuis cet appareil.';
    }
    if (isSessionExpired(error)) {
      return 'Votre session a expiré. Reconnectez-vous.';
    }
    if (text.contains('403') || text.contains('not_authorized')) {
      return 'Accès refusé par Appwrite pour ce compte.';
    }
    return 'La synchronisation avec Appwrite a échoué.';
  }

  Widget _buildQuickStats(AsyncValue gradesAsync, AsyncValue assignmentsAsync) {
    // Pas de `CrossAxisAlignment.stretch` : dans un `ListView` la hauteur est
    // non bornée, et `stretch` la propage telle quelle aux enfants — Flutter
    // lève alors « BoxConstraints forces an infinite height ». Les deux cartes
    // ont la même structure, elles s'alignent donc d'elles-mêmes.
    return Row(
      children: [
        Expanded(
          child: StatCard(
            label: 'Moyenne générale',
            value: gradesAsync.when(
              data: (grades) {
                if (grades.isEmpty) return '--';
                final avg = grades.map((e) => e.score / e.maxScore).reduce((a, b) => a + b) / grades.length;
                return '${(avg * 20).toStringAsFixed(1)}/20';
              },
              loading: () => '...',
              error: (_, __) => '!',
            ),
            icon: Icons.trending_up,
            color: AppColors.primaryBlue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatCard(
            label: 'Devoirs en cours',
            value: assignmentsAsync.when(
              // « En cours » = ce qui reste à rendre, retards compris. Un
              // devoir manqué n'est pas « en cours », il est manqué — mais le
              // compter ici évite qu'il disparaisse de l'accueil.
              data: (board) => '${board.todo.length + board.overdue.length}',
              loading: () => '...',
              error: (_, __) => '!',
            ),
            icon: Icons.assignment_outlined,
            color: AppColors.warning,
          ),
        ),
      ],
    );
  }

  Widget _buildActionGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      // 2.5 était trop plat : la cellule descendait sous la hauteur de son
      // contenu (pastille + libellé sur deux lignes).
      childAspectRatio: 2.1,
      children: [
        for (final a in _actions)
          _ActionCard(
            icon: a.icon,
            label: a.label,
            color: a.color,
            onTap: () => context.push(a.route),
          ),
      ],
    );
  }

  Widget _buildRecentAssignments(AsyncValue<AssignmentBoard> boardAsync) {
    return boardAsync.when(
      data: (board) {
        // Les retards d'abord : ce sont eux qui appellent une action.
        final pending = [...board.overdue, ...board.todo].take(3).toList();
        if (pending.isEmpty) {
          return const SectionCard(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: EmptyState(
              icon: Icons.task_alt,
              title: 'Aucun devoir à rendre',
              message: 'Vous êtes à jour.',
            ),
          );
        }
        return Column(
          children: [
            for (final a in pending)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SectionCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.warning,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // `Expanded` : sans lui, un titre long poussait le code du
                      // cours hors de la carte — c'est exactement ce qui faisait
                      // déborder cette ligne.
                      Expanded(
                        child: Text(
                          a.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        a.courseCode.isEmpty ? a.type.label : a.courseCode,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: LoadingView(),
      ),
      error: (_, __) => const SectionCard(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: EmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Devoirs indisponibles',
          message: 'La liste n\'a pas pu être chargée.',
        ),
      ),
    );
  }
}

/// Carte d'action rapide : pastille d'icône teintée puis libellé.
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      child: SectionCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            // `Expanded` + ellipse : ce `Text` n'était souple dans aucune
            // direction, et « Bibliothèque » débordait de la cellule de grille
            // sur les écrans étroits.
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                  color: AppColors.textPrimary,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
