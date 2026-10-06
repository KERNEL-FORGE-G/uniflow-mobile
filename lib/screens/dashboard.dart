import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../widgets/phosphor.dart';

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
import '../widgets/uni_icons.dart';
import '../widgets/gamification/gamification_widgets.dart';
// `gradesListProvider`, `assignmentBoardProvider` et
// `teacherAssignmentsProvider` sont déclarés dans leurs écrans : l'accueil les
// réutilise plutôt que de relancer ses propres requêtes.
import 'assignments.dart';
import 'grades.dart';
import 'schedule.dart' show groupByDay, normalizeDay, normalizeTime;
import 'teacher_assignments.dart';

/// Une action rapide : icône Phosphor `duotone`, libellé, couleur et route.
class _QuickAction {
  final PhosphorIconData icon;
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
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => context.push('/profil'),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.2), width: 1.5),
                    ),
                    child: Avatar(
                      initials: initialsOf(user?.name ?? 'UniFlow'),
                      avatarFileId: user?.avatarFileId,
                      size: 38,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, uniClearance),
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
    _QuickAction(PhosphorIconsDuotone.calendarBlank, 'Emploi du temps', AppColors.primaryBlue, '/emploi-du-temps'),
    _QuickAction(PhosphorIconsDuotone.books, 'Bibliothèque', AppColors.teal, '/bibliotheque'),
    _QuickAction(PhosphorIconsDuotone.qrCode, 'Scanner QR', AppColors.purple, '/presence'),
    _QuickAction(PhosphorIconsDuotone.usersThree, 'Forum', AppColors.info, '/forum'),
  ];

  static const List<_QuickAction> _delegateActions = [
    _QuickAction(PhosphorIconsDuotone.calendarBlank, 'Emploi du temps', AppColors.primaryBlue, '/emploi-du-temps'),
    _QuickAction(PhosphorIconsDuotone.qrCode, 'Émettre la présence', AppColors.purple, '/presence'),
    _QuickAction(PhosphorIconsDuotone.graduationCap, 'Ma promotion', AppColors.teal, '/etudiants'),
    _QuickAction(PhosphorIconsDuotone.usersThree, 'Forum', AppColors.info, '/forum'),
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
        // ── Bannière hero « Book Lending » — mascotte + CTA ───────────────
        const _DashHeroBanner(),
        const SizedBox(height: 18),

        // ── 4 Actions rapides juste sous le hero (style Book Lending) ─────
        _ActionGrid(actions: role == UniFlowRole.delegate ? _delegateActions : _studentActions),
        const SizedBox(height: 24),

        // ── Cours du jour / Recommandés (cartes horizontales avec thumbnail)
        SectionTitle(
          title: 'Cours du jour',
          icon: UniIcons.schedule(),
          trailing: _SeeAll(onTap: () => context.push('/emploi-du-temps')),
        ),
        _TodaySessions(schedulesAsync: schedulesAsync),
        const SizedBox(height: 24),

        // ── Vue d'ensemble (Statistiques clés) ───────────────────────────
        SectionTitle(title: 'Vue d\'ensemble', icon: UniIcons.statistics()),
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
                icon: UniIcons.grades(),
                color: AppColors.primaryBlue,
                imageAsset: 'assets/illustrations/course_grades.jpg',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                index: 1,
                label: 'Devoirs en cours',
                value: assignmentsAsync.when(
                  data: (board) => '${board.todo.length + board.overdue.length}',
                  loading: () => '...',
                  error: (_, __) => '!',
                ),
                icon: UniIcons.assignments(),
                color: AppColors.warning,
                imageAsset: 'assets/illustrations/course_books.jpg',
                onTap: () => context.push('/devoirs'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ── Mes badges ──────────────────────────────────────────────────
        SectionTitle(
          title: 'Mes badges',
          icon: UniIcons.badges(),
          trailing: _SeeAll(onTap: () => context.push('/badges')),
        ),
        badgesAsync.when(
          data: (badges) => BadgesStrip(badges: badges, onSeeAll: () => context.push('/badges')),
          loading: () => const ShimmerBox(height: 150, borderRadius: BorderRadius.all(Radius.circular(16))),
          error: (_, __) => const SectionCard(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: EmptyState(
              icon: PhosphorIconsDuotone.medal,
              title: 'Badges indisponibles',
              message: 'Ils reviendront à la prochaine synchronisation.',
            ),
          ),
        ),
        const SizedBox(height: 24),

        // ── Rappel programme du jour ─────────────────────────────────────
        SectionTitle(
          title: 'Rappel du jour',
          icon: PhosphorIconsDuotone.bellRinging,
          trailing: _SeeAll(onTap: () => context.push('/emploi-du-temps')),
        ),
        DailyReminderCard(
          onViewSchedule: () => context.push('/emploi-du-temps'),
        ),
        const SizedBox(height: 24),

        // ── Résumé quêtes actives ─────────────────────────────────────────
        SectionTitle(
          title: 'Mes quêtes',
          icon: UniIcons.tasks(),
          trailing: _SeeAll(onTap: () => context.push('/quetes')),
        ),
        const QuestSummaryWidget(),
        const SizedBox(height: 24),

        // ── Prochains devoirs ─────────────────────────────────────────────
        SectionTitle(
          title: 'Prochains devoirs',
          icon: UniIcons.assignments(),
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
    _QuickAction(PhosphorIconsDuotone.filePlus, 'Publier un devoir', AppColors.primaryBlue, '/devoirs'),
    _QuickAction(PhosphorIconsDuotone.chartLineUp, 'Saisir des notes', AppColors.teal, '/notes'),
    _QuickAction(PhosphorIconsDuotone.qrCode, 'Présence QR', AppColors.purple, '/presence'),
    _QuickAction(PhosphorIconsDuotone.chatsCircle, 'Messages', AppColors.info, '/messages'),
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
        SectionTitle(title: 'Vue d\'ensemble', icon: UniIcons.statistics()),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Mes cours',
                value: loading ? '...' : '${mine.length}',
                caption: mine.isEmpty && !loading ? 'Aucun cours à votre nom' : null,
                icon: UniIcons.courses(),
                color: AppColors.primaryBlue,
                imageAsset: 'assets/illustrations/course_schedule.jpg',
                onTap: () => context.push('/ues'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                index: 1,
                label: 'Étudiants',
                value: loading ? '...' : '${students.length}',
                caption: 'dans votre périmètre',
                icon: UniIcons.students(),
                color: AppColors.teal,
                imageAsset: 'assets/illustrations/hero_books.jpg',
                onTap: () => context.push('/etudiants'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                index: 2,
                label: 'Devoirs publiés',
                value: assignmentsAsync.when(
                  data: (list) => '${list.length}',
                  loading: () => '...',
                  error: (_, __) => '!',
                ),
                icon: UniIcons.assignments(),
                color: AppColors.warning,
                imageAsset: 'assets/illustrations/course_books.jpg',
                onTap: () => context.push('/devoirs'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SectionTitle(
          title: 'Séances du jour',
          icon: UniIcons.schedule(),
          trailing: _SeeAll(onTap: () => context.push('/emploi-du-temps')),
        ),
        _TodaySessions(schedulesAsync: schedulesAsync, teacherView: true),
        const SizedBox(height: 24),
        const SectionTitle(title: 'À faire', icon: PhosphorIconsDuotone.lightning),
        const _ActionGrid(actions: _actions),
        const SizedBox(height: 24),
        SectionTitle(
          title: 'Derniers devoirs publiés',
          icon: UniIcons.assignments(),
          trailing: _SeeAll(onTap: () => context.push('/devoirs')),
        ),
        assignmentsAsync.when(
          data: (list) {
            if (list.isEmpty) {
              return const SectionCard(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: EmptyState(
                  icon: PhosphorIconsDuotone.filePlus,
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
              icon: PhosphorIconsDuotone.cloudSlash,
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
    _QuickAction(PhosphorIconsDuotone.userGear, 'Comptes', AppColors.primaryBlue, '/comptes'),
    _QuickAction(PhosphorIconsDuotone.graduationCap, 'Étudiants', AppColors.teal, '/etudiants'),
    _QuickAction(PhosphorIconsDuotone.chalkboard, 'Enseignants', AppColors.purple, '/enseignants'),
    _QuickAction(PhosphorIconsDuotone.bookBookmark, 'Unités d\'enseignement', AppColors.warning, '/ues'),
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
        SectionTitle(title: 'Vue d\'ensemble', icon: UniIcons.statistics()),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Étudiants',
                value: loading ? '...' : '${students.length}',
                icon: UniIcons.students(),
                color: AppColors.primaryBlue,
                imageAsset: 'assets/illustrations/hero_books.jpg',
                onTap: () => context.push('/etudiants'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                index: 1,
                label: 'Enseignants',
                value: loading ? '...' : '${teachers.length}',
                icon: UniIcons.teachers(),
                color: AppColors.teal,
                imageAsset: 'assets/illustrations/course_schedule.jpg',
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
                index: 2,
                label: 'Cours',
                value: loading ? '...' : '${courses.length}',
                icon: UniIcons.courseUnit(),
                color: AppColors.purple,
                imageAsset: 'assets/illustrations/course_books.jpg',
                onTap: () => context.push('/ues'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                index: 3,
                label: 'Séances aujourd\'hui',
                value: today == null ? '...' : '$today',
                icon: UniIcons.agenda(),
                color: AppColors.warning,
                imageAsset: 'assets/illustrations/course_grades.jpg',
                onTap: () => context.push('/emploi-du-temps'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SectionTitle(title: 'Gestion', icon: UniIcons.university()),
        const _ActionGrid(actions: _actions),
        const SizedBox(height: 24),
        SectionTitle(
          title: 'Séances du jour',
          icon: UniIcons.schedule(),
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
    _QuickAction(PhosphorIconsDuotone.bookBookmark, 'Mes matières', AppColors.primaryBlue, '/matieres'),
    _QuickAction(PhosphorIconsDuotone.checkSquare, 'Mes tâches', AppColors.teal, '/taches'),
    _QuickAction(PhosphorIconsDuotone.calendarCheck, 'Mon agenda', AppColors.purple, '/agenda'),
    _QuickAction(PhosphorIconsDuotone.chartLineUp, 'Mes notes', AppColors.warning, '/notes'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = ref.watch(personalSubjectsProvider);
    final tasks = ref.watch(personalTasksProvider);
    final schedules = ref.watch(personalSchedulesProvider);
    final todayKey = weekdayKey(DateTime.now());

    // Liste modifiable même avant l'arrivée des tâches : `const []` faisait
    // planter le tri au premier rendu (« Cannot modify an unmodifiable list »),
    // donc l'accueil de tout compte indépendant, le temps du chargement.
    final pending = tasks.valueOrNull?.where((t) => t.status != 'DONE').toList() ?? <PersonalTask>[];
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
        SectionTitle(title: 'Vue d\'ensemble', icon: UniIcons.statistics()),
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
                icon: UniIcons.courseUnit(),
                color: AppColors.primaryBlue,
                onTap: () => context.push('/matieres'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                index: 1,
                label: 'Tâches à faire',
                value: tasks.when(
                  data: (_) => '${pending.length}',
                  loading: () => '...',
                  error: (_, __) => '!',
                ),
                icon: UniIcons.tasks(),
                color: AppColors.warning,
                onTap: () => context.push('/taches'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SectionTitle(
          title: 'Aujourd\'hui',
          icon: UniIcons.agenda(),
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
                  icon: PhosphorIconsDuotone.coffee,
                  title: 'Rien de prévu aujourd\'hui',
                  message: 'Ajoutez vos créneaux depuis l\'agenda.',
                  pose: UniPose.sleeping,
                ),
              );
            }
            final byId = {for (final s in subjects.valueOrNull ?? const <PersonalSubject>[]) s.id: s};
            final rows = today.take(4).toList();
            return Column(
              children: [
                for (var i = 0; i < rows.length; i++)
                  _SessionRow(
                    index: i,
                    start: normalizeTime(rows[i].startTime),
                    end: normalizeTime(rows[i].endTime),
                    title: byId[rows[i].courseId]?.name ?? rows[i].type,
                    subtitle: [rows[i].type, rows[i].classroom].where((v) => v.trim().isNotEmpty).join(' · '),
                    // Couleur choisie par l'étudiant pour sa matière ; violet
                    // (l'accent de l'espace personnel) quand il n'en a pas mis.
                    color: subjectColor(rows[i].courseId, colorHex: byId[rows[i].courseId]?.colorHex ?? '#7C3AED'),
                  ),
              ],
            );
          },
          loading: () => const ShimmerList(count: 2, cardHeight: 56),
          error: (_, __) => const SectionCard(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: EmptyState(icon: PhosphorIconsDuotone.cloudSlash, title: 'Agenda indisponible'),
          ),
        ),
        const SizedBox(height: 24),
        const SectionTitle(title: 'Actions rapides', icon: PhosphorIconsDuotone.lightning),
        const _ActionGrid(actions: _actions),
        const SizedBox(height: 24),
        SectionTitle(
          title: 'Prochaines tâches',
          icon: UniIcons.tasks(),
          trailing: _SeeAll(onTap: () => context.push('/taches')),
        ),
        tasks.when(
          data: (_) {
            if (pending.isEmpty) {
              return const SectionCard(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: EmptyState(
                  icon: PhosphorIconsDuotone.checkCircle,
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
            child: EmptyState(icon: PhosphorIconsDuotone.cloudSlash, title: 'Tâches indisponibles'),
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
          final upcoming = all.take(3).toList();
          if (upcoming.isNotEmpty) {
            return Column(
              children: [
                SectionCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.teal.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const PhosphorIcon(PhosphorIconsDuotone.calendarCheck, color: AppColors.teal, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pas de cours aujourd\'hui',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.textPrimary),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Voici vos prochaines séances de la semaine :',
                              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                for (var i = 0; i < upcoming.length; i++)
                  _SessionRow(
                    index: i,
                    start: normalizeTime(upcoming[i].startTime),
                    end: normalizeTime(upcoming[i].endTime),
                    title: upcoming[i].courseName.isNotEmpty ? upcoming[i].courseName : upcoming[i].courseCode,
                    code: upcoming[i].courseCode,
                    subtitle: [
                      upcoming[i].dayOfWeek,
                      if (upcoming[i].classroom.trim().isNotEmpty) upcoming[i].classroom.trim(),
                    ].join(' · '),
                    color: subjectColor(upcoming[i].courseCode),
                  ),
              ],
            );
          }

          return const SectionCard(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: EmptyState(
              icon: PhosphorIconsDuotone.coffee,
              title: 'Pas de cours aujourd\'hui',
              message: 'Profitez-en pour avancer sur vos devoirs et quêtes actives !',
              pose: UniPose.thinking,
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
                  index: i,
                  start: normalizeTime(shown[i].startTime),
                  end: normalizeTime(shown[i].endTime),
                  title: shown[i].courseName.isNotEmpty ? shown[i].courseName : shown[i].courseCode,
                  code: shown[i].courseCode,
                  subtitle: [
                    if (shown[i].type != null && shown[i].type!.trim().isNotEmpty) shown[i].type!.trim(),
                    if (shown[i].group.trim().isNotEmpty) shown[i].group.trim(),
                    if (shown[i].classroom.trim().isNotEmpty) shown[i].classroom.trim(),
                    if (teacherView && shown[i].level.trim().isNotEmpty)
                      '${shown[i].program} ${shown[i].level}'.trim()
                    else if (!teacherView && shown[i].teacherName.trim().isNotEmpty)
                      shown[i].teacherName.trim(),
                  ].join(' · '),
                  color: subjectColor(shown[i].courseCode),
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
          icon: PhosphorIconsDuotone.cloudSlash,
          title: 'Emploi du temps indisponible',
          message: 'Il reviendra à la prochaine synchronisation.',
        ),
      ),
    );
  }
}

/// Une séance : colonne des heures, tuile de la matière, titre et détail.
/// Une séance : carte horizontale style « Book Lending » avec illustration,
/// titre, horaires et bouton pill d'accès rapide.
class _SessionRow extends StatelessWidget {
  final String start;
  final String end;
  final String title;
  final String? code;
  final String subtitle;
  final Color color;
  final int index;

  const _SessionRow({
    required this.start,
    required this.end,
    required this.title,
    this.code,
    required this.subtitle,
    required this.color,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/emploi-du-temps'),
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          child: SectionCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Tuile icône de la matière stylisée aux couleurs de la marque
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: IconTile(
                    icon: subjectIcon(title, code: code),
                    color: color,
                    size: IconTile.dense,
                    index: index,
                  ),
                ),
                const SizedBox(width: 14),
                // Informations du cours (Titre, heure et salle)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PhosphorIcon(PhosphorIconsBold.clock, size: 12, color: AppColors.teal),
                            const SizedBox(width: 4),
                            Text(
                              '$start - $end',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.teal,
                              ),
                            ),
                            if (subtitle.isNotEmpty) ...[
                              const Text(' · ', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                              Text(
                                subtitle,
                                style: AppTextStyles.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Bouton pill d'action style « Borrow it »
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.primary50,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.primary100, width: 1),
                  ),
                  child: const Text(
                    'Voir',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
              icon: PhosphorIconsDuotone.checkCircle,
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
          icon: PhosphorIconsDuotone.cloudSlash,
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

/// Bannière hero du dashboard — style « Book Lending » : carte arrondie avec
/// dégradé bleu → teal, texte de bienvenue à gauche, mascotte Uni à droite.
class _DashHeroBanner extends ConsumerWidget {
  const _DashHeroBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final first = (user?.name ?? '').split(RegExp(r'\s+')).first;
    return Container(
      margin: EdgeInsets.zero,
      height: 148,
      decoration: BoxDecoration(
        gradient: AppColors.dashHeroBannerGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Cercle décoratif transparent à droite
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 30,
            bottom: -15,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Texte à gauche
          Positioned(
            left: 20,
            top: 0,
            bottom: 0,
            right: 130,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    first.isEmpty ? 'Bienvenue !' : 'Bonjour, $first !',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Prêt pour vos cours\ndu jour ?',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.80),
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => context.push('/emploi-du-temps'),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Mon emploi du temps',
                            style: TextStyle(
                              color: AppColors.primaryBlue,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 4),
                          PhosphorIcon(
                            PhosphorIconsBold.arrowRight,
                            size: 11,
                            color: AppColors.primaryBlue,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Mascotte Uni à droite
          Positioned(
            right: -4,
            bottom: 0,
            child: Image.asset(
              'assets/mascot/uni_wave.webp',
              height: 148,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox(width: 110),
            ),
          ),
        ],
      ),
    );
  }
}

/// Grille 4 colonnes de raccourcis — style « Book Lending » : icônes rondes
/// blanches avec ombre douce, libellé en dessous.
class _ActionGrid extends StatelessWidget {
  final List<_QuickAction> actions;
  const _ActionGrid({required this.actions});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < actions.length; i++)
          Expanded(
            child: _ActionIcon(
              icon: actions[i].icon,
              label: actions[i].label,
              color: actions[i].color,
              index: i,
              onTap: () => context.push(actions[i].route),
            ),
          ),
      ],
    );
  }
}

/// Raccourci rond — style « Book Lending » : fond blanc avec ombre, icône colorée.
class _ActionIcon extends StatelessWidget {
  final PhosphorIconData icon;
  final String label;
  final Color color;
  final int index;
  final VoidCallback onTap;

  const _ActionIcon({
    required this.icon,
    required this.label,
    required this.color,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
                BoxShadow(
                  color: AppColors.primaryBlue.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: PhosphorIcon(
                icon,
                size: 24,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
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

/// Carte d'action rapide : tuile d'icône pleine puis libellé.
class _ActionCard extends StatefulWidget {
  final PhosphorIconData icon;
  final String label;
  final Color color;
  final int index;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.index,
    required this.onTap,
  });

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      onHighlightChanged: (down) => setState(() => _pressed = down),
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      child: SectionCard(
        // 8 et non 10 : la tuile de 44 doit tenir dans une cellule de grille
        // dont le ratio 2,1 laisse ~66 px de haut sur un écran de 320.
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            IconTile(
              icon: widget.icon,
              color: widget.color,
              index: widget.index,
              pressed: _pressed,
            ),
            const SizedBox(width: 10),
            // `Expanded` + ellipse : ce `Text` n'était souple dans aucune
            // direction, et « Bibliothèque » débordait de la cellule de grille
            // sur les écrans étroits.
            Expanded(
              child: Text(
                widget.label,
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
