import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/mock_data.dart';
import '../data/uniflow_api.dart';
import '../models/models.dart';

final apiProvider = Provider<UniFlowApi>((ref) => UniFlowApi());

final studentsProvider = StateProvider<List<Student>>((ref) => mockStudents);
final teachersProvider = StateProvider<List<Teacher>>((ref) => mockTeachers);
final uesProvider = StateProvider<List<UE>>((ref) => mockUEs);
final enrollmentsProvider = StateProvider<List<Enrollment>>((ref) => mockEnrollments);

final gatewaySyncProvider = FutureProvider<void>((ref) async {
  final api = ref.read(apiProvider);
  try {
    final results = await Future.wait([
      api.fetchStudents(),
      api.fetchTeachers(),
      api.fetchTeachingUnits(),
    ]);
    if (results[0].isNotEmpty) ref.read(studentsProvider.notifier).state = results[0] as List<Student>;
    if (results[1].isNotEmpty) ref.read(teachersProvider.notifier).state = results[1] as List<Teacher>;
    if (results[2].isNotEmpty) ref.read(uesProvider.notifier).state = results[2] as List<UE>;
  } catch (_) {
    // Offline-first : les dernières données locales restent consultables.
  }
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
