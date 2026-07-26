import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/mock_data.dart';
import '../models/models.dart';

final studentsProvider = StateProvider<List<Student>>((ref) => mockStudents);
final teachersProvider = StateProvider<List<Teacher>>((ref) => mockTeachers);
final uesProvider = StateProvider<List<UE>>((ref) => mockUEs);
final enrollmentsProvider = StateProvider<List<Enrollment>>((ref) => mockEnrollments);

final studentSearchProvider = StateProvider<String>((ref) => '');
final teacherSearchProvider = StateProvider<String>((ref) => '');
final ueSearchProvider = StateProvider<String>((ref) => '');

final filteredStudentsProvider = Provider<List<Student>>((ref) {
  final q = ref.watch(studentSearchProvider).toLowerCase();
  final list = ref.watch(studentsProvider);
  if (q.isEmpty) return list;
  return list.where((s) =>
      s.fullName.toLowerCase().contains(q) ||
      s.matricule.toLowerCase().contains(q) ||
      s.filiere.toLowerCase().contains(q)).toList();
});

final filteredTeachersProvider = Provider<List<Teacher>>((ref) {
  final q = ref.watch(teacherSearchProvider).toLowerCase();
  final list = ref.watch(teachersProvider);
  if (q.isEmpty) return list;
  return list.where((t) =>
      t.fullName.toLowerCase().contains(q) ||
      t.department.toLowerCase().contains(q)).toList();
});

final filteredUEsProvider = Provider<List<UE>>((ref) {
  final q = ref.watch(ueSearchProvider).toLowerCase();
  final list = ref.watch(uesProvider);
  if (q.isEmpty) return list;
  return list.where((u) =>
      u.title.toLowerCase().contains(q) ||
      u.code.toLowerCase().contains(q)).toList();
});

Student? findStudent(WidgetRef ref, String id) =>
    ref.read(studentsProvider).where((s) => s.id == id).cast<Student?>().firstOrNull;
Teacher? findTeacher(WidgetRef ref, String id) =>
    ref.read(teachersProvider).where((t) => t.id == id).cast<Teacher?>().firstOrNull;
UE? findUE(WidgetRef ref, String id) =>
    ref.read(uesProvider).where((u) => u.id == id).cast<UE?>().firstOrNull;

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
