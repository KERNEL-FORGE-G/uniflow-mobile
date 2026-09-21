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
                          errorBuilder: (_, __, ___) => const PhosphorIcon(
                            PhosphorIconsFill.graduationCap,
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
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                index: 1,
                label: 'Devoirs en cours',
                value: assignmentsAsync.when(
                  // « En cours » = ce qui reste à rendre, retards compris. Un
                  // devoir manqué n'est pas « en cours », il est manqué — mais
                  // le compter ici évite qu'il disparaisse de l'accueil.
                  data: (board) => '${board.todo.length + board.overdue.length}',
                  loading: () => '...',
                  error: (_, __) => '!',
                ),
                icon: UniIcons.assignments(),
                color: AppColors.warning,
                onTap: () => context.push('/devoirs'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SectionTitle(
          title: 'Cours du jour',
          icon: UniIcons.schedule(),
          trailing: _SeeAll(onTap: () => context.push('/emploi-du-temps')),
        ),
        _TodaySessions(schedulesAsync: schedulesAsync),
        const SizedBox(height: 24),
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
        const SectionTitle(title: 'Actions rapides', icon: PhosphorIconsDuotone.lightning),
        _ActionGrid(actions: role == UniFlowRole.delegate ? _delegateActions : _studentActions),
        const SizedBox(height: 24),
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
          return SectionCard(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: EmptyState(
              icon: PhosphorIconsDuotone.coffee,
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
///
/// La tuile porte `subjectIcon(titre, code)` dans la couleur du cours : c'est
/// la même icône que sur la carte du cours et dans l'emploi du temps.
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
            IconTile(
              icon: subjectIcon(title, code: code),
              color: color,
              size: IconTile.dense,
              index: index,
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
        for (var i = 0; i < actions.length; i++)
          _ActionCard(
            icon: actions[i].icon,
            label: actions[i].label,
            color: actions[i].color,
            index: i,
            onTap: () => context.push(actions[i].route),
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
