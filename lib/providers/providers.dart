import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/mock_data.dart';
import '../data/uniflow_api.dart';
import '../models/models.dart';
import '../models/appwrite_models.dart';
import '../repositories/academic_repository.dart';
import '../repositories/auth_repository.dart';

final apiProvider = Provider<UniFlowApi>((ref) => UniFlowApi());

final studentsProvider = StateProvider<List<Student>>((ref) => []);
final teachersProvider = StateProvider<List<Teacher>>((ref) => []);
final uesProvider = StateProvider<List<UE>>((ref) => []);
final enrollmentsProvider = StateProvider<List<Enrollment>>((ref) => []);

final currentUserProvider = StateProvider<UniFlowUser?>((ref) => null);

final gatewaySyncProvider = FutureProvider<void>((ref) async {
  final academicRepo = ref.read(academicRepositoryProvider);
  final authRepo = ref.read(authRepositoryProvider);

  try {
    final user = await authRepo.getCurrentUser();
    ref.read(currentUserProvider.notifier).state = user;

    final results = await Future.wait([
      academicRepo.getDirectory(),
      academicRepo.getCourses(),
    ]);

    final directory = results[0] as List;
    final courses = results[1] as List;

    final students = directory.where((e) => e.role == 'STUDENT' || e.role == 'DELEGATE').map((e) => Student(
      id: e.userId,
      matricule: e.matricule ?? '',
      firstName: e.name.split(' ').first,
      lastName: e.name.split(' ').skip(1).join(' '),
      filiere: e.program,
      niveau: e.level,
      status: e.status ?? 'ACTIVE',
      email: '', // À compléter via une autre source si besoin
      phone: '',
      ueIds: [],
    )).toList();

    final teachers = directory.where((e) => e.role == 'TEACHER').map((e) => Teacher(
      id: e.userId,
      firstName: e.name.split(' ').first,
      lastName: e.name.split(' ').skip(1).join(' '),
      status: e.status ?? 'ACTIVE',
      email: '',
      department: e.program,
      ueIds: [],
    )).toList();

    final ues = courses.map((c) => UE(
      id: c.id,
      code: c.code,
      title: c.name,
      credits: c.credits ?? 0,
      cm: 0,
      td: 0,
      tp: 0,
      description: c.description ?? '',
      colorHex: '#2563EB',
    )).toList();

    ref.read(studentsProvider.notifier).state = students;
    ref.read(teachersProvider.notifier).state = teachers;
    ref.read(uesProvider.notifier).state = ues;
  } catch (e) {
    // En cas d'erreur, on peut charger les mocks pour le dev ou garder les données vides
    print('Erreur lors de la synchro Appwrite: $e');
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
