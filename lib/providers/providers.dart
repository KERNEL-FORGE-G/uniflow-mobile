import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/uniflow_api.dart';
import '../offline/cached_providers.dart';
import '../offline/offline_providers.dart';
import '../offline/sync_engine.dart';
import '../models/models.dart';
import '../models/appwrite_models.dart';
import '../models/user_role.dart';
import '../models/academic_scope.dart';
import '../repositories/academic_repository.dart';
import '../repositories/auth_repository.dart';
import 'session_controller.dart';

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
///
/// « Cache d'abord » : la liste locale s'affiche tout de suite, la réponse
/// du serveur la remplace quand elle arrive — ou jamais, hors ligne.
final scopedCoursesProvider = StreamProvider<List<AcademicCourse>>((ref) {
  if (ref.watch(authStatusProvider) != AuthStatus.signedIn) return Stream.value(const []);
  final scope = ref.watch(effectiveScopeProvider);
  if (scope.nothing) return Stream.value(const []);
  final repo = ref.read(academicRepositoryProvider);
  // Le filtre part au serveur : filière et niveau sont indexés, et la
  // collection (296 UE) dépasse la limite d'un seul appel.
  final filters = <String>[
    if (scope.filterByProgram) Query.equal('program', scope.program.trim()),
    if (scope.filterByLevel) Query.equal('level', scope.level.trim()),
  ];
  return cachedDocumentList<AcademicCourse>(
    ref,
    collection: 'academic_courses',
    fetch: () => repo.listAll('academic_courses', filters),
    fromDocument: AcademicCourse.fromDocument,
    select: scope.courses,
  );
});

/// Emploi du temps du périmètre, lu directement par filière + niveau
/// (`academic_schedules.program/level`, schéma du 2026-09-20), cache d'abord.
///
/// Enseignant : ses séances (`teacherName` contient son nom) ; s'il n'en a
/// aucune sous ce nom, on retombe sur sa filière pour ne pas afficher un
/// écran vide à cause d'une orthographe différente en base.
final scopedSchedulesProvider = StreamProvider<List<AcademicSchedule>>((ref) {
  if (ref.watch(authStatusProvider) != AuthStatus.signedIn) return Stream.value(const []);
  final scope = ref.watch(effectiveScopeProvider);
  if (scope.nothing) return Stream.value(const []);
  final repo = ref.read(academicRepositoryProvider);
  final user = ref.watch(currentUserProvider);
  final role = ref.watch(currentRoleProvider);

  final teacherName = (user?.name ?? '').trim();
  final byTeacher = role == UniFlowRole.teacher && ref.watch(scopeSelectionProvider) == null && teacherName.isNotEmpty;

  if (!byTeacher && !scope.filterByProgram && !scope.filterByLevel && scope.selectable) {
    // Administration ou plateforme sans sélection : tout charger ferait 527
    // séances illisibles ; l'écran montre le sélecteur à la place.
    return Stream.value(const []);
  }

  final program = scope.filterByProgram ? scope.program.trim() : null;
  final level = scope.filterByLevel ? scope.level.trim() : null;
  final filters = <String>[
    if (program != null) Query.equal('program', program),
    if (level != null) Query.equal('level', level),
  ];

  return cachedDocumentList<AcademicSchedule>(
    ref,
    collection: 'academic_schedules',
    fetch: () async {
      if (byTeacher) {
        final mine = await repo.listAll('academic_schedules', [Query.contains('teacherName', teacherName)]);
        if (mine.isNotEmpty) return mine;
      }
      return repo.listAll('academic_schedules', filters);
    },
    fromDocument: AcademicSchedule.fromDocument,
    // Le cache peut contenir d'anciens périmètres (changement de niveau, vue
    // enseignant) : on ne montre que le courant.
    select: byTeacher
        ? (all) {
            final mine = all.where((s) => s.teacherName.toLowerCase().contains(teacherName.toLowerCase())).toList();
            return mine.isNotEmpty ? mine : schedulesForScope(all, program: program, level: level);
          }
        : (all) => schedulesForScope(all, program: program, level: level),
  );
});

/// Résout la session au démarrage — **sans jamais bloquer sur le réseau**.
///
/// L'identité vient d'abord du stockage chiffré (profil, labels, périmètre) :
/// l'application s'ouvre tout de suite, même après un mois sans réseau. Le
/// serveur n'est consulté qu'ensuite, en arrière-plan : session confirmée →
/// profil rafraîchi ; session expirée (401) → retour à la connexion **sans**
/// perdre l'outbox ni le cache, rattachés à l'identifiant ; réseau absent →
/// on reste connecté sur le profil en cache.
final sessionBootstrapProvider = FutureProvider<void>((ref) async {
  final store = ref.read(sessionStoreProvider);
  final auth = ref.read(authRepositoryProvider);
  final snapshot = await store.read();

  if (snapshot != null) {
    ref.read(currentUserProvider.notifier).state = snapshot.user;
    ref.read(authStatusProvider.notifier).state = AuthStatus.signedIn;
    // Vérification silencieuse, hors du chemin critique.
    Future<void>(() async {
      try {
        final fresh = await auth.getCurrentUserStrict().timeout(const Duration(seconds: 12));
        if (fresh == null) {
          // Session réellement expirée ou révoquée : on redemande le mot de
          // passe, en gardant tout ce qui est local.
          await ref.read(sessionControllerProvider).signOut(deleteRemoteSession: false, keepLocalData: true);
          return;
        }
        ref.read(currentUserProvider.notifier).state = fresh;
      } catch (_) {
        // Réseau absent ou serveur injoignable : on reste sur le cache.
      }
    });
    return;
  }

  final user = await auth.getCurrentUser();
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
  // Annuaire : cache d'abord (première valeur émise), le frais suit.
  final directory = scope.directory(await cachedDocumentList<AcademicDirectoryEntry>(
    ref,
    collection: 'academic_directory',
    fetch: () => academicRepo.listAll('academic_directory', const []),
    fromDocument: AcademicDirectoryEntry.fromDocument,
    replace: true,
  ).first);
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
