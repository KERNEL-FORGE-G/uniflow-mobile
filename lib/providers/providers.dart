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

/// Cours du périmètre du compte, sous leur forme Appwrite (les `UE` de
/// [uesProvider] en sont la projection pour les écrans historiques).
final scopedCoursesProvider = FutureProvider<List<AcademicCourse>>((ref) async {
  if (ref.watch(authStatusProvider) != AuthStatus.signedIn) return const [];
  final scope = ref.watch(academicScopeProvider);
  if (scope.nothing) return const [];
  return scope.courses(await ref.read(academicRepositoryProvider).getCourses());
});

/// Emploi du temps du périmètre : les créneaux se rattachent à un cours, et
/// c'est le cours qui porte filière et niveau.
final scopedSchedulesProvider = FutureProvider<List<AcademicSchedule>>((ref) async {
  final courses = await ref.watch(scopedCoursesProvider.future);
  if (courses.isEmpty) return const [];
  final scope = ref.watch(academicScopeProvider);
  final all = await ref.read(academicRepositoryProvider).getSchedules();
  return scope.byCourse(all, courses, (s) => s.courseId, courseCodeOf: (s) => s.courseCode);
});

/// Résout la session Appwrite persistée sur l'appareil au démarrage.
final sessionBootstrapProvider = FutureProvider<void>((ref) async {
  final user = await ref.read(authRepositoryProvider).getCurrentUser();
  ref.read(currentUserProvider.notifier).state = user;
  ref.read(authStatusProvider.notifier).state =
      user == null ? AuthStatus.signedOut : AuthStatus.signedIn;
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
  final scope = ref.read(academicScopeProvider);
  final directory = scope.directory(await academicRepo.getDirectory());
  final courses = scope.courses(await academicRepo.getCourses());

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
  return list.where((s) => s.fullName.toLowerCase().contains(q) || s.matricule.toLowerCase().contains(q) || s.filiere.toLowerCase().contains(q)).toList();
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

Student? findStudent(WidgetRef ref, String id) => ref.read(studentsProvider).where((s) => s.id == id).cast<Student?>().firstOrNull;
Teacher? findTeacher(WidgetRef ref, String id) => ref.read(teachersProvider).where((t) => t.id == id).cast<Teacher?>().firstOrNull;
UE? findUE(WidgetRef ref, String id) => ref.read(uesProvider).where((u) => u.id == id).cast<UE?>().firstOrNull;

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
