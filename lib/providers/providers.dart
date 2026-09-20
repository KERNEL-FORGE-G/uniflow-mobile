import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/uniflow_api.dart';
import '../models/models.dart';
import '../models/appwrite_models.dart';
import '../models/user_role.dart';
import '../models/academic_scope.dart';
import '../repositories/academic_repository.dart';
import '../repositories/auth_repository.dart';

/// État d'authentification Appwrite.
///
/// `unknown` couvre le démarrage : tant que la session stockée n'a pas été
/// résolue, on ne peut pas décider si l'utilisateur doit voir la connexion.
enum AuthStatus { unknown, signedOut, signedIn }

final authStatusProvider = StateProvider<AuthStatus>((ref) => AuthStatus.unknown);

final apiProvider = Provider<UniFlowApi>((ref) => UniFlowApi());

final studentsProvider = StateProvider<List<Student>>((ref) => []);
final teachersProvider = StateProvider<List<Teacher>>((ref) => []);
final uesProvider = StateProvider<List<UE>>((ref) => []);
final enrollmentsProvider = StateProvider<List<Enrollment>>((ref) => []);

final currentUserProvider = StateProvider<UniFlowUser?>((ref) => null);

/// Rôle de l'utilisateur connecté, tel qu'il décide de ce qui est visible.
///
/// Dérivé de [currentUserProvider] plutôt que stocké à part : deux sources
/// finiraient par diverger, et c'est exactement ce qu'un système de restriction
/// ne peut pas se permettre. Déconnecté, le rôle retombe sur `student`, le plus
/// restreint.
final currentRoleProvider = Provider<UniFlowRole>((ref) {
  return mapRole(ref.watch(currentUserProvider)?.role);
});

/// Périmètre académique du compte connecté (voir [AcademicScope]).
final academicScopeProvider = Provider<AcademicScope>((ref) {
  return AcademicScope.forUser(ref.watch(currentUserProvider));
});

/// Filière + niveau choisis dans le sélecteur des écrans Cours et Emploi du
/// temps, pour les comptes dont le périmètre est « sélectionnable »
/// (administration d'université, plateforme, enseignant sans filière).
/// `null` = rien de choisi. Remis à zéro à la déconnexion.
final scopeSelectionProvider = StateProvider<ScopeSelection?>((ref) => null);

class ScopeSelection {
  final String program;
  final String level;
  const ScopeSelection({required this.program, this.level = ''});
}

/// Périmètre effectivement appliqué : celui du profil, resserré par le
/// sélecteur quand il y en a un.
final effectiveScopeProvider = Provider<AcademicScope>((ref) {
  final scope = ref.watch(academicScopeProvider);
  final selection = ref.watch(scopeSelectionProvider);
  if (!scope.selectable || selection == null) return scope;
  return scope.narrowedTo(program: selection.program, level: selection.level);
});

/// Cours du périmètre du compte, sous leur forme Appwrite (les `UE` de
/// [uesProvider] en sont la projection pour les écrans historiques).
final scopedCoursesProvider = FutureProvider<List<AcademicCourse>>((ref) async {
  if (ref.watch(authStatusProvider) != AuthStatus.signedIn) return const [];
  final scope = ref.watch(effectiveScopeProvider);
  if (scope.nothing) return const [];
  // Le filtre part au serveur : filière et niveau sont indexés, et la
  // collection (296 UE) dépasse la limite d'un seul appel.
  final courses = await ref.read(academicRepositoryProvider).getCourses(
        program: scope.filterByProgram ? scope.program : null,
        level: scope.filterByLevel ? scope.level : null,
      );
  return scope.courses(courses);
});

/// Emploi du temps du périmètre, lu directement par filière + niveau
/// (`academic_schedules.program/level`, schéma du 2026-09-20).
///
/// Enseignant : ses séances (`teacherName` contient son nom) ; s'il n'en a
/// aucune sous ce nom, on retombe sur sa filière pour ne pas afficher un
/// écran vide à cause d'une orthographe différente en base.
final scopedSchedulesProvider = FutureProvider<List<AcademicSchedule>>((ref) async {
  if (ref.watch(authStatusProvider) != AuthStatus.signedIn) return const [];
  final scope = ref.watch(effectiveScopeProvider);
  if (scope.nothing) return const [];
  final repo = ref.read(academicRepositoryProvider);
  final user = ref.watch(currentUserProvider);
  final role = ref.watch(currentRoleProvider);

  if (role == UniFlowRole.teacher && ref.watch(scopeSelectionProvider) == null) {
    final name = (user?.name ?? '').trim();
    if (name.isNotEmpty) {
      final mine = await repo.getSchedulesByScope(teacherName: name);
      if (mine.isNotEmpty) return mine;
    }
  }
  if (!scope.filterByProgram && !scope.filterByLevel && scope.selectable) {
    // Administration ou plateforme sans sélection : tout charger ferait 527
    // séances illisibles ; l'écran montre le sélecteur à la place.
    return const [];
  }
  return repo.getSchedulesByScope(
    program: scope.filterByProgram ? scope.program : null,
    level: scope.filterByLevel ? scope.level : null,
  );
});

/// Résout la session Appwrite persistée sur l'appareil au démarrage.
final sessionBootstrapProvider = FutureProvider<void>((ref) async {
  final user = await ref.read(authRepositoryProvider).getCurrentUser();
  ref.read(currentUserProvider.notifier).state = user;
  ref.read(authStatusProvider.notifier).state = user == null ? AuthStatus.signedOut : AuthStatus.signedIn;
});

/// Charge le répertoire académique et les cours.
///
/// Se relance automatiquement quand l'état d'authentification change. Les
/// erreurs Appwrite remontent volontairement à l'UI au lieu d'être avalées :
/// une liste vide et une requête refusée ne doivent pas être indiscernables.
final gatewaySyncProvider = FutureProvider<void>((ref) async {
  if (ref.watch(authStatusProvider) != AuthStatus.signedIn) return;

  final academicRepo = ref.read(academicRepositoryProvider);
  // Awaits séquentiels plutôt que `(f1(), f2()).wait` : le `.wait` sur record
  // enveloppe tout échec dans un `ParallelWaitError`, ce qui masquerait le
  // message Appwrite d'origine dans la bannière d'erreur du dashboard.
  // Périmètre du compte (filière + niveau, lus dans `users`) : un étudiant L2
  // ne voit ni les cours ni les camarades des L1, et rien n'est codé en dur.
  // `watch` : un changement de filière dans le sélecteur (administration,
  // plateforme) doit recharger les UE, pas seulement la prochaine connexion.
  final scope = ref.watch(effectiveScopeProvider);
  final directory = scope.directory(await academicRepo.getDirectory());
  final courses = await ref.watch(scopedCoursesProvider.future);

  final students = directory
      .where((e) => e.role == 'STUDENT' || e.role == 'DELEGATE')
      .map((e) => Student(
            id: e.userId,
            matricule: e.matricule ?? '',
            firstName: e.name.split(' ').first,
            lastName: e.name.split(' ').skip(1).join(' '),
            filiere: e.program,
            niveau: e.level,
            status: e.status ?? 'ACTIVE',
            email: '',
            phone: '',
            ueIds: const [],
          ))
      .toList();

  final teachers = directory
      .where((e) => e.role == 'TEACHER')
      .map((e) => Teacher(
            id: e.userId,
            firstName: e.name.split(' ').first,
            lastName: e.name.split(' ').skip(1).join(' '),
            status: e.status ?? 'ACTIVE',
            email: '',
            department: e.program,
            ueIds: const [],
          ))
      .toList();

  final ues = courses
      .map((c) => UE(
            id: c.id,
            code: c.code,
            title: c.name,
            credits: c.credits ?? 0,
            cm: 0,
            td: 0,
            tp: 0,
            description: c.description ?? '',
            colorHex: '#2563EB',
          ))
      .toList();

  ref.read(studentsProvider.notifier).state = students;
  ref.read(teachersProvider.notifier).state = teachers;
  ref.read(uesProvider.notifier).state = ues;
});

final studentSearchProvider = StateProvider<String>((ref) => '');
final teacherSearchProvider = StateProvider<String>((ref) => '');
final ueSearchProvider = StateProvider<String>((ref) => '');

final filteredStudentsProvider = Provider<List<Student>>((ref) {
  final q = ref.watch(studentSearchProvider).toLowerCase();
  final list = ref.watch(studentsProvider);
  if (q.isEmpty) return list;
  return list
      .where((s) =>
          s.fullName.toLowerCase().contains(q) ||
          s.matricule.toLowerCase().contains(q) ||
          s.filiere.toLowerCase().contains(q))
      .toList();
});

final filteredTeachersProvider = Provider<List<Teacher>>((ref) {
  final q = ref.watch(teacherSearchProvider).toLowerCase();
  final list = ref.watch(teachersProvider);
  if (q.isEmpty) return list;
  return list.where((t) => t.fullName.toLowerCase().contains(q) || t.department.toLowerCase().contains(q)).toList();
});

final filteredUEsProvider = Provider<List<UE>>((ref) {
  final q = ref.watch(ueSearchProvider).toLowerCase();
  final list = ref.watch(uesProvider);
  if (q.isEmpty) return list;
  return list.where((u) => u.title.toLowerCase().contains(q) || u.code.toLowerCase().contains(q)).toList();
});

Student? findStudent(WidgetRef ref, String id) =>
    ref.read(studentsProvider).where((s) => s.id == id).cast<Student?>().firstOrNull;
Teacher? findTeacher(WidgetRef ref, String id) =>
    ref.read(teachersProvider).where((t) => t.id == id).cast<Teacher?>().firstOrNull;
UE? findUE(WidgetRef ref, String id) => ref.read(uesProvider).where((u) => u.id == id).cast<UE?>().firstOrNull;

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
