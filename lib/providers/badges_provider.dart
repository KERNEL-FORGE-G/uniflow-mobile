import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/badges.dart';
import '../offline/cached_providers.dart';
import '../repositories/academic_repository.dart';
import '../screens/assignments.dart';
import '../screens/grades.dart';
import 'providers.dart';

/// Relevés de présence de l'apprenant connecté, servis depuis le cache local
/// puis rafraîchis : les badges doivent s'afficher hors ligne.
final myAttendanceProvider = StreamProvider<List<AttendanceMark>>((ref) {
  if (ref.watch(authStatusProvider) != AuthStatus.signedIn) {
    return Stream.value(const []);
  }
  final user = ref.watch(currentUserProvider);
  if (user == null || !ref.watch(currentRoleProvider).isLearner) {
    return Stream.value(const []);
  }
  final repo = ref.read(academicRepositoryProvider);
  return cachedDocumentList<AttendanceMark>(
    ref,
    collection: 'attendance_records',
    fetch: () => repo.listAll('attendance_records', [Query.equal('studentId', user.id)]),
    fromDocument: AttendanceMark.fromDocument,
  );
});

/// Nombre de sujets publiés sur le forum par l'apprenant connecté.
///
/// Requête dédiée plutôt que la liste des 100 derniers billets : un étudiant
/// actif sur une promo bavarde n'y figurerait plus, et son badge reculerait.
final myForumPostCountProvider = StreamProvider<int>((ref) {
  if (ref.watch(authStatusProvider) != AuthStatus.signedIn) {
    return Stream.value(0);
  }
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(0);
  final repo = ref.read(academicRepositoryProvider);
  return cachedDocumentList<String>(
    ref,
    collection: 'forum_posts',
    fetch: () => repo.listAll('forum_posts', [Query.equal('authorId', user.id)]),
    fromDocument: (models.Document doc) => doc.$id,
    select: (ids) => ids,
  ).map((ids) => ids.length);
});

/// Les six badges de l'apprenant connecté, calculés sur ses données réelles.
///
/// Chaque source manquante (hors ligne sans cache, service indisponible) est
/// traitée comme vide plutôt que de faire échouer l'ensemble : mieux vaut un
/// badge « pas encore » qu'un accueil sans badges.
final studentBadgesProvider = Provider<AsyncValue<List<BadgeProgress>>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const AsyncValue.data([]);

  final attendance = ref.watch(myAttendanceProvider);
  final grades = ref.watch(gradesListProvider);
  final board = ref.watch(assignmentBoardProvider);
  final posts = ref.watch(myForumPostCountProvider);

  final sources = [attendance, grades, board, posts];
  final loading = sources.any((s) => s.isLoading && !s.hasValue);
  if (loading) return const AsyncValue.loading();

  final resolvedBoard = board.valueOrNull;
  final inputs = BadgeInputs(
    studentId: user.id,
    attendance: attendance.valueOrNull ?? const [],
    grades: grades.valueOrNull ?? const [],
    assignments: resolvedBoard?.assignments ?? const [],
    submissions: resolvedBoard?.submissions.values.toList() ?? const [],
    forumPostsByStudent: posts.valueOrNull ?? 0,
  );
  return AsyncValue.data(computeBadges(inputs));
});
