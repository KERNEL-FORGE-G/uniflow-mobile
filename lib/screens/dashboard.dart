import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/appwrite_models.dart';
import '../models/assignment_models.dart';
import '../models/models.dart' hide initialsOf;
import '../models/user_role.dart';
import '../offline/offline_widgets.dart';
import '../providers/badges_provider.dart';
import '../providers/providers.dart';
import '../providers/session_controller.dart';
import '../repositories/personal_repository.dart';
import '../theme/app_theme.dart';
import '../utils/avatar.dart';
import '../widgets/badges.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';
import '../widgets/uni/uni_mascot.dart';
// `gradesListProvider`, `assignmentBoardProvider` et
// `teacherAssignmentsProvider` sont déclarés dans leurs écrans : l'accueil les
// réutilise plutôt que de relancer ses propres requêtes.
import 'assignments.dart';
import 'grades.dart';
import 'schedule.dart' show groupByDay, normalizeDay, normalizeTime;
import 'teacher_assignments.dart';

/// Une action rapide : icône, libellé, couleur et route.
class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final String route;

  const _QuickAction(this.icon, this.label, this.color, this.route);
}

/// Clé du jour (« LUNDI »…) telle que `groupByDay` indexe les séances.
String weekdayKey(DateTime date) => const [
      'LUNDI',
      'MARDI',
      'MERCREDI',
      'JEUDI',
      'VENDREDI',
      'SAMEDI',
      'DIMANCHE',
    ][date.weekday - 1];

/// Séances du jour [date], dans l'ordre des heures de début.
List<AcademicSchedule> sessionsOn(List<AcademicSchedule> all, DateTime date) =>
    groupByDay(all)[weekdayKey(date)] ?? const [];

/// Cours qu'un enseignant donne : par identifiant quand la fiche du cours le
/// porte, sinon par rapprochement de nom (« Dr NKOUMOU » / « Pr. Nkoumou J. »).
List<UE> coursesTaughtBy(UniFlowUser user, List<UE> courses) => [
      for (final ue in courses)
        if ((ue.teacherId.isNotEmpty && ue.teacherId == user.id) || sameTeacherName(user.name, ue.teacherName)) ue,
    ];

/// L'accueil : le même en-tête pour tous, un corps par rôle. La maquette
/// mobile prévoit quatre tableaux de bord (étudiant, enseignant,
/// administration, délégué) ; l'unique écran d'avant montrait « Moyenne
/// générale » et « Devoirs en cours » à un enseignant, qui n'a ni l'un ni
/// l'autre.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final role = ref.watch(currentRoleProvider);
    final sync = ref.watch(academicSyncProvider);

    final body = switch (role) {
      UniFlowRole.teacher => const _TeacherHome(),
      UniFlowRole.admin => const _AdminHome(),
      UniFlowRole.personal => const _PersonalHome(),
      UniFlowRole.student || UniFlowRole.delegate => const _LearnerHome(),
    };

    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            title: _greeting(user, role),
            subtitle: _headline(role),
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
                    // foncé de l'en-tête, son mortier s'y confondait. La
                    // pastille claire le détache.
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
                if (sync.hasError && role.isUniversity) ...[
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
                body,
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _greeting(UniFlowUser? user, UniFlowRole role) {
    final name = (user?.name ?? '').trim();
    if (name.isEmpty) return 'Bienvenue sur UniFlow';
    final first = name.split(RegExp(r'\s+')).first;
    return switch (role) {
      UniFlowRole.teacher => 'Bonjour, $name',
      _ => 'Bonjour, $first',
    };
  }

  static String _headline(UniFlowRole role) => switch (role) {
        UniFlowRole.student => 'Voici ce qui vous attend aujourd\'hui',
        UniFlowRole.delegate => 'Votre journée et celle de la classe',
        UniFlowRole.teacher => 'Vos séances et ce qu\'il reste à corriger',
        UniFlowRole.admin => 'Vue d\'ensemble de l\'établissement',
        UniFlowRole.personal => 'Votre espace de travail personnel',
      };

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
}

// ---------------------------------------------------------------------------
// Apprenant (étudiant, délégué)
// ---------------------------------------------------------------------------

class _LearnerHome extends ConsumerWidget {
  const _LearnerHome();

  static const List<_QuickAction> _studentActions = [
    _QuickAction(Icons.calendar_month_outlined, 'Emploi du temps', AppColors.primaryBlue, '/emploi-du-temps'),
    _QuickAction(Icons.library_books_outlined, 'Bibliothèque', AppColors.teal, '/bibliotheque'),
    _QuickAction(Icons.qr_code_scanner, 'Scanner QR', AppColors.purple, '/presence'),
    _QuickAction(Icons.forum_outlined, 'Forum', AppColors.info, '/forum'),
  ];

  static const List<_QuickAction> _delegateActions = [
    _QuickAction(Icons.calendar_month_outlined, 'Emploi du temps', AppColors.primaryBlue, '/emploi-du-temps'),
    _QuickAction(Icons.qr_code_2, 'Émettre la présence', AppColors.purple, '/presence'),
    _QuickAction(Icons.groups_outlined, 'Ma promotion', AppColors.teal, '/etudiants'),
    _QuickAction(Icons.forum_outlined, 'Forum', AppColors.info, '/forum'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentRoleProvider);
    final gradesAsync = ref.watch(gradesListProvider);
    final assignmentsAsync = ref.watch(assignmentBoardProvider);
    final schedulesAsync = ref.watch(scopedSchedulesProvider);
    final badgesAsync = ref.watch(studentBadgesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: 'Vue d\'ensemble'),
        Row(
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
                  // devoir manqué n'est pas « en cours », il est manqué — mais
                  // le compter ici évite qu'il disparaisse de l'accueil.
                  data: (board) => '${board.todo.length + board.overdue.length}',
                  loading: () => '...',
                  error: (_, __) => '!',
                ),
                icon: Icons.assignment_outlined,
                color: AppColors.warning,
                onTap: () => context.push('/devoirs'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SectionTitle(
          title: 'Cours du jour',
          trailing: _SeeAll(onTap: () => context.push('/emploi-du-temps')),
        ),
        _TodaySessions(schedulesAsync: schedulesAsync),
        const SizedBox(height: 24),
        SectionTitle(
          title: 'Mes badges',
          trailing: _SeeAll(onTap: () => context.push('/badges')),
        ),
        badgesAsync.when(
          data: (badges) => BadgesStrip(badges: badges, onSeeAll: () => context.push('/badges')),
          loading: () => const ShimmerBox(height: 150, borderRadius: BorderRadius.all(Radius.circular(16))),
          error: (_, __) => const SectionCard(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: EmptyState(
              icon: Icons.military_tech_outlined,
              title: 'Badges indisponibles',
              message: 'Ils reviendront à la prochaine synchronisation.',
            ),
          ),
        ),
        const SizedBox(height: 24),
        const SectionTitle(title: 'Actions rapides'),
        _ActionGrid(actions: role == UniFlowRole.delegate ? _delegateActions : _studentActions),
        const SizedBox(height: 24),
        SectionTitle(
          title: 'Prochains devoirs',
          trailing: _SeeAll(onTap: () => context.push('/devoirs')),
        ),
        _UpcomingAssignments(boardAsync: assignmentsAsync),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Enseignant
// ---------------------------------------------------------------------------

class _TeacherHome extends ConsumerWidget {
  const _TeacherHome();

  static const List<_QuickAction> _actions = [
    _QuickAction(Icons.post_add_outlined, 'Publier un devoir', AppColors.primaryBlue, '/devoirs'),
    _QuickAction(Icons.grading_outlined, 'Saisir des notes', AppColors.teal, '/notes'),
    _QuickAction(Icons.qr_code_2, 'Présence QR', AppColors.purple, '/presence'),
    _QuickAction(Icons.chat_bubble_outline, 'Messages', AppColors.info, '/messages'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final courses = ref.watch(uesProvider);
    final students = ref.watch(studentsProvider);
    final schedulesAsync = ref.watch(scopedSchedulesProvider);
    final assignmentsAsync = ref.watch(teacherAssignmentsProvider);
    final sync = ref.watch(academicSyncProvider);

    final mine = user == null ? const <UE>[] : coursesTaughtBy(user, courses);
    final loading = sync.isLoading && courses.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: 'Vue d\'ensemble'),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Mes cours',
                value: loading ? '...' : '${mine.length}',
                caption: mine.isEmpty && !loading ? 'Aucun cours à votre nom' : null,
                icon: Icons.menu_book_outlined,
                color: AppColors.primaryBlue,
                onTap: () => context.push('/ues'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                label: 'Étudiants',
                value: loading ? '...' : '${students.length}',
                caption: 'dans votre périmètre',
                icon: Icons.groups_outlined,
                color: AppColors.teal,
                onTap: () => context.push('/etudiants'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                label: 'Devoirs publiés',
                value: assignmentsAsync.when(
                  data: (list) => '${list.length}',
                  loading: () => '...',
                  error: (_, __) => '!',
                ),
                icon: Icons.assignment_turned_in_outlined,
                color: AppColors.warning,
                onTap: () => context.push('/devoirs'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SectionTitle(
          title: 'Séances du jour',
          trailing: _SeeAll(onTap: () => context.push('/emploi-du-temps')),
        ),
        _TodaySessions(schedulesAsync: schedulesAsync, teacherView: true),
        const SizedBox(height: 24),
        const SectionTitle(title: 'À faire'),
        const _ActionGrid(actions: _actions),
        const SizedBox(height: 24),
        SectionTitle(
          title: 'Derniers devoirs publiés',
          trailing: _SeeAll(onTap: () => context.push('/devoirs')),
        ),
        assignmentsAsync.when(
          data: (list) {
            if (list.isEmpty) {
              return const SectionCard(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: EmptyState(
                  icon: Icons.post_add_outlined,
                  title: 'Aucun devoir publié',
                  message: 'Publiez un quiz, un PDF ou un TD depuis « Devoirs ».',
                  pose: UniPose.pointing,
                ),
              );
            }
            return Column(
              children: [
                for (final a in list.take(3))
                  _AssignmentRow(
                    assignment: a,
                    trailing: 'échéance ${_shortDate(a.dueDate)}',
                    dotColor: a.dueDate.isBefore(DateTime.now()) ? AppColors.textMuted : AppColors.teal,
                  ),
              ],
            );
          },
          loading: () => const ShimmerList(count: 2, cardHeight: 56),
          error: (_, __) => const SectionCard(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: EmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Devoirs indisponibles',
              message: 'La liste n\'a pas pu être chargée.',
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Administration
// ---------------------------------------------------------------------------

class _AdminHome extends ConsumerWidget {
  const _AdminHome();

  static const List<_QuickAction> _actions = [
    _QuickAction(Icons.manage_accounts_outlined, 'Comptes', AppColors.primaryBlue, '/comptes'),
    _QuickAction(Icons.school_outlined, 'Étudiants', AppColors.teal, '/etudiants'),
    _QuickAction(Icons.co_present_outlined, 'Enseignants', AppColors.purple, '/enseignants'),
    _QuickAction(Icons.menu_book_outlined, 'Unités d\'enseignement', AppColors.warning, '/ues'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final students = ref.watch(studentsProvider);
    final teachers = ref.watch(teachersProvider);
    final courses = ref.watch(uesProvider);
    final schedulesAsync = ref.watch(scopedSchedulesProvider);
    final sync = ref.watch(academicSyncProvider);
    final loading = sync.isLoading && courses.isEmpty && students.isEmpty;

    final today =
        schedulesAsync.valueOrNull == null ? null : sessionsOn(schedulesAsync.valueOrNull!, DateTime.now()).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: 'Vue d\'ensemble'),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Étudiants',
                value: loading ? '...' : '${students.length}',
                icon: Icons.school_outlined,
                color: AppColors.primaryBlue,
                onTap: () => context.push('/etudiants'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                label: 'Enseignants',
                value: loading ? '...' : '${teachers.length}',
                icon: Icons.co_present_outlined,
                color: AppColors.teal,
                onTap: () => context.push('/enseignants'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Cours',
                value: loading ? '...' : '${courses.length}',
                icon: Icons.menu_book_outlined,
                color: AppColors.purple,
                onTap: () => context.push('/ues'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                label: 'Séances aujourd\'hui',
                value: today == null ? '...' : '$today',
                icon: Icons.event_available_outlined,
                color: AppColors.warning,
                onTap: () => context.push('/emploi-du-temps'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const SectionTitle(title: 'Gestion'),
        const _ActionGrid(actions: _actions),
        const SizedBox(height: 24),
        SectionTitle(
          title: 'Séances du jour',
          trailing: _SeeAll(onTap: () => context.push('/emploi-du-temps')),
        ),
        _TodaySessions(schedulesAsync: schedulesAsync, teacherView: true, max: 5),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Compte indépendant
// ---------------------------------------------------------------------------

class _PersonalHome extends ConsumerWidget {
  const _PersonalHome();

  static const List<_QuickAction> _actions = [
    _QuickAction(Icons.book_outlined, 'Mes matières', AppColors.primaryBlue, '/matieres'),
    _QuickAction(Icons.checklist_rounded, 'Mes tâches', AppColors.teal, '/taches'),
    _QuickAction(Icons.calendar_month_outlined, 'Mon agenda', AppColors.purple, '/agenda'),
    _QuickAction(Icons.grade_outlined, 'Mes notes', AppColors.warning, '/notes'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = ref.watch(personalSubjectsProvider);
    final tasks = ref.watch(personalTasksProvider);
    final schedules = ref.watch(personalSchedulesProvider);
    final todayKey = weekdayKey(DateTime.now());

    final pending = tasks.valueOrNull?.where((t) => t.status != 'DONE').toList() ?? const [];
    pending.sort((a, b) {
      final da = DateTime.tryParse(a.dueDate ?? '');
      final db = DateTime.tryParse(b.dueDate ?? '');
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: 'Vue d\'ensemble'),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Matières suivies',
                value: subjects.when(
                  data: (list) => '${list.length}',
                  loading: () => '...',
                  error: (_, __) => '!',
                ),
                icon: Icons.book_outlined,
                color: AppColors.primaryBlue,
                onTap: () => context.push('/matieres'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                label: 'Tâches à faire',
                value: tasks.when(
                  data: (_) => '${pending.length}',
                  loading: () => '...',
                  error: (_, __) => '!',
                ),
                icon: Icons.checklist_rounded,
                color: AppColors.warning,
                onTap: () => context.push('/taches'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SectionTitle(
          title: 'Aujourd\'hui',
          trailing: _SeeAll(onTap: () => context.push('/agenda')),
        ),
        schedules.when(
          data: (list) {
            final today = list.where((s) => normalizeDay(s.dayOfWeek) == todayKey).toList()
              ..sort((a, b) => normalizeTime(a.startTime).compareTo(normalizeTime(b.startTime)));
            if (today.isEmpty) {
              return const SectionCard(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: EmptyState(
                  icon: Icons.free_breakfast_outlined,
                  title: 'Rien de prévu aujourd\'hui',
                  message: 'Ajoutez vos créneaux depuis l\'agenda.',
                  pose: UniPose.sleeping,
                ),
              );
            }
            final names = {for (final s in subjects.valueOrNull ?? const <PersonalSubject>[]) s.id: s.name};
            return Column(
              children: [
                for (final s in today.take(4))
                  _SessionRow(
                    start: normalizeTime(s.startTime),
                    end: normalizeTime(s.endTime),
                    title: names[s.courseId] ?? s.type,
                    subtitle: [s.type, s.classroom].where((v) => v.trim().isNotEmpty).join(' · '),
                    color: AppColors.purple,
                  ),
              ],
            );
          },
          loading: () => const ShimmerList(count: 2, cardHeight: 56),
          error: (_, __) => const SectionCard(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: EmptyState(icon: Icons.cloud_off_outlined, title: 'Agenda indisponible'),
          ),
        ),
        const SizedBox(height: 24),
        const SectionTitle(title: 'Actions rapides'),
        const _ActionGrid(actions: _actions),
        const SizedBox(height: 24),
        SectionTitle(
          title: 'Prochaines tâches',
          trailing: _SeeAll(onTap: () => context.push('/taches')),
        ),
        tasks.when(
          data: (_) {
            if (pending.isEmpty) {
              return const SectionCard(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: EmptyState(
                  icon: Icons.task_alt,
                  title: 'Aucune tâche en attente',
                  message: 'Vous êtes à jour.',
                  pose: UniPose.celebrate,
                ),
              );
            }
            return Column(
              children: [
                for (final t in pending.take(3))
                  _PlainRow(
                    title: t.title,
                    trailing: t.dueDate == null ? '' : _shortDate(DateTime.tryParse(t.dueDate!)),
                    dotColor: (t.priority ?? 0) >= 2 ? AppColors.danger : AppColors.warning,
                  ),
              ],
            );
          },
          loading: () => const ShimmerList(count: 2, cardHeight: 56),
          error: (_, __) => const SectionCard(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: EmptyState(icon: Icons.cloud_off_outlined, title: 'Tâches indisponibles'),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Briques communes
// ---------------------------------------------------------------------------

/// Les séances d'aujourd'hui, ou un état vide qui le dit.
class _TodaySessions extends StatelessWidget {
  final AsyncValue<List<AcademicSchedule>> schedulesAsync;
  final bool teacherView;
  final int max;

  const _TodaySessions({
    required this.schedulesAsync,
    this.teacherView = false,
    this.max = 4,
  });

  @override
  Widget build(BuildContext context) {
    return schedulesAsync.when(
      data: (all) {
        final today = sessionsOn(all, DateTime.now());
        if (today.isEmpty) {
          return SectionCard(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: EmptyState(
              icon: Icons.free_breakfast_outlined,
              title: 'Pas de cours aujourd\'hui',
              message: all.isEmpty
                  ? 'Aucune séance n\'est enregistrée pour votre périmètre.'
                  : 'Profitez-en pour avancer sur vos devoirs.',
              pose: UniPose.sleeping,
            ),
          );
        }
        final shown = today.take(max).toList();
        return Column(
          children: [
            for (var i = 0; i < shown.length; i++)
              FadeSlideIn(
                index: i,
                child: _SessionRow(
                  start: normalizeTime(shown[i].startTime),
                  end: normalizeTime(shown[i].endTime),
                  title: shown[i].courseName.isNotEmpty ? shown[i].courseName : shown[i].courseCode,
                  subtitle: [
                    if (shown[i].type != null && shown[i].type!.trim().isNotEmpty) shown[i].type!.trim(),
                    if (shown[i].group.trim().isNotEmpty) shown[i].group.trim(),
                    if (shown[i].classroom.trim().isNotEmpty) shown[i].classroom.trim(),
                    if (teacherView && shown[i].level.trim().isNotEmpty)
                      '${shown[i].program} ${shown[i].level}'.trim()
                    else if (!teacherView && shown[i].teacherName.trim().isNotEmpty)
                      shown[i].teacherName.trim(),
                  ].join(' · '),
                  color: Color(int.parse('FF${courseColorHex(shown[i].courseCode).substring(1)}', radix: 16)),
                ),
              ),
            if (today.length > shown.length)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '+ ${today.length - shown.length} autre${today.length - shown.length > 1 ? 's' : ''} séance${today.length - shown.length > 1 ? 's' : ''}',
                  style: AppTextStyles.bodySmall,
                ),
              ),
          ],
        );
      },
      loading: () => const ShimmerList(count: 2, cardHeight: 60),
      error: (_, __) => const SectionCard(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: EmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Emploi du temps indisponible',
          message: 'Il reviendra à la prochaine synchronisation.',
        ),
      ),
    );
  }
}

/// Une séance : colonne des heures, barre de couleur du cours, titre et détail.
class _SessionRow extends StatelessWidget {
  final String start;
  final String end;
  final String title;
  final String subtitle;
  final Color color;

  const _SessionRow({
    required this.start,
    required this.end,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SectionCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 46,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(start,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textPrimary)),
                  Text(end, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                ],
              ),
            ),
            Container(
              width: 4,
              height: 36,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.textPrimary),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySmall),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Les devoirs qu'un apprenant doit encore rendre, retards d'abord.
class _UpcomingAssignments extends StatelessWidget {
  final AsyncValue<AssignmentBoard> boardAsync;
  const _UpcomingAssignments({required this.boardAsync});

  @override
  Widget build(BuildContext context) {
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
              pose: UniPose.celebrate,
            ),
          );
        }
        return Column(
          children: [
            for (final a in pending)
              _AssignmentRow(
                assignment: a,
                trailing: a.courseCode.isEmpty ? a.type.label : a.courseCode,
                dotColor: board.overdue.contains(a) ? AppColors.danger : AppColors.warning,
              ),
          ],
        );
      },
      loading: () => const ShimmerList(count: 2, cardHeight: 52),
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

class _AssignmentRow extends StatelessWidget {
  final Assignment assignment;
  final String trailing;
  final Color dotColor;

  const _AssignmentRow({required this.assignment, required this.trailing, required this.dotColor});

  @override
  Widget build(BuildContext context) => _PlainRow(title: assignment.title, trailing: trailing, dotColor: dotColor);
}

/// Une ligne compacte : point de couleur, titre, information à droite.
class _PlainRow extends StatelessWidget {
  final String title;
  final String trailing;
  final Color dotColor;

  const _PlainRow({required this.title, required this.trailing, required this.dotColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SectionCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            // `Expanded` : sans lui, un titre long poussait l'information de
            // droite hors de la carte.
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  fontSize: 13.5,
                ),
              ),
            ),
            if (trailing.isNotEmpty) ...[
              const SizedBox(width: 10),
              Text(trailing, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

/// Grille 2 × 2 des raccourcis.
class _ActionGrid extends StatelessWidget {
  final List<_QuickAction> actions;
  const _ActionGrid({required this.actions});

  @override
  Widget build(BuildContext context) {
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
        for (final a in actions)
          _ActionCard(
            icon: a.icon,
            label: a.label,
            color: a.color,
            onTap: () => context.push(a.route),
          ),
      ],
    );
  }
}

/// « Voir tout » à droite d'un titre de section.
class _SeeAll extends StatelessWidget {
  final VoidCallback onTap;
  const _SeeAll({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 30),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: const Text('Voir tout', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
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

String _shortDate(DateTime? date) {
  if (date == null) return '';
  final local = date.toLocal();
  const months = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
  return '${local.day} ${months[local.month - 1]}';
}
