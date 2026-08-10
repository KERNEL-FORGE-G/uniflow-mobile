import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/api_services.dart';

class PaginatedState<T> {
  final List<T> items;
  final int page;
  final bool hasReachedMax;
  final bool isLoadingMore;

  PaginatedState({
    this.items = const [],
    this.page = 1,
    this.hasReachedMax = false,
    this.isLoadingMore = false,
  });

  PaginatedState<T> copyWith({
    List<T>? items,
    int? page,
    bool? hasReachedMax,
    bool? isLoadingMore,
  }) {
    return PaginatedState<T>(
      items: items ?? this.items,
      page: page ?? this.page,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

const pageSize = 20;

// --- Students Notifier ---
class StudentsNotifier extends AsyncNotifier<PaginatedState<Student>> {
  @override
  Future<PaginatedState<Student>> build() async => fetchPage(1);

  Future<PaginatedState<Student>> fetchPage(int page) async {
    final service = ref.read(studentServiceProvider);
    final newItems = await service.getStudents(page, pageSize);
    final hasReachedMax = newItems.isEmpty || newItems.length < pageSize;
    
    if (page == 1) return PaginatedState(items: newItems, page: 1, hasReachedMax: hasReachedMax);
    
    final current = state.value!;
    return current.copyWith(
      items: [...current.items, ...newItems],
      page: page,
      hasReachedMax: hasReachedMax,
      isLoadingMore: false,
    );
  }

  Future<void> fetchNextPage() async {
    if (state.isLoading || state.hasError || (state.value?.hasReachedMax ?? true) || (state.value?.isLoadingMore ?? false)) return;
    
    state = AsyncData(state.value!.copyWith(isLoadingMore: true));
    try {
      final newState = await fetchPage(state.value!.page + 1);
      state = AsyncData(newState);
    } catch (e) {
      state = AsyncData(state.value!.copyWith(isLoadingMore: false));
    }
  }
}

final studentsProvider = AsyncNotifierProvider<StudentsNotifier, PaginatedState<Student>>(StudentsNotifier.new);

// --- Teachers Notifier ---
class TeachersNotifier extends AsyncNotifier<PaginatedState<Teacher>> {
  @override
  Future<PaginatedState<Teacher>> build() async => fetchPage(1);

  Future<PaginatedState<Teacher>> fetchPage(int page) async {
    final service = ref.read(teacherServiceProvider);
    final newItems = await service.getTeachers(page, pageSize);
    final hasReachedMax = newItems.isEmpty || newItems.length < pageSize;
    
    if (page == 1) return PaginatedState(items: newItems, page: 1, hasReachedMax: hasReachedMax);
    
    final current = state.value!;
    return current.copyWith(
      items: [...current.items, ...newItems],
      page: page,
      hasReachedMax: hasReachedMax,
      isLoadingMore: false,
    );
  }

  Future<void> fetchNextPage() async {
    if (state.isLoading || state.hasError || (state.value?.hasReachedMax ?? true) || (state.value?.isLoadingMore ?? false)) return;
    
    state = AsyncData(state.value!.copyWith(isLoadingMore: true));
    try {
      final newState = await fetchPage(state.value!.page + 1);
      state = AsyncData(newState);
    } catch (e) {
      state = AsyncData(state.value!.copyWith(isLoadingMore: false));
    }
  }
}

final teachersProvider = AsyncNotifierProvider<TeachersNotifier, PaginatedState<Teacher>>(TeachersNotifier.new);

// --- UEs Notifier ---
class UEsNotifier extends AsyncNotifier<PaginatedState<UE>> {
  @override
  Future<PaginatedState<UE>> build() async => fetchPage(1);

  Future<PaginatedState<UE>> fetchPage(int page) async {
    final service = ref.read(ueServiceProvider);
    final newItems = await service.getUEs(page, pageSize);
    final hasReachedMax = newItems.isEmpty || newItems.length < pageSize;
    
    if (page == 1) return PaginatedState(items: newItems, page: 1, hasReachedMax: hasReachedMax);
    
    final current = state.value!;
    return current.copyWith(
      items: [...current.items, ...newItems],
      page: page,
      hasReachedMax: hasReachedMax,
      isLoadingMore: false,
    );
  }

  Future<void> fetchNextPage() async {
    if (state.isLoading || state.hasError || (state.value?.hasReachedMax ?? true) || (state.value?.isLoadingMore ?? false)) return;
    
    state = AsyncData(state.value!.copyWith(isLoadingMore: true));
    try {
      final newState = await fetchPage(state.value!.page + 1);
      state = AsyncData(newState);
    } catch (e) {
      state = AsyncData(state.value!.copyWith(isLoadingMore: false));
    }
  }
}

final uesProvider = AsyncNotifierProvider<UEsNotifier, PaginatedState<UE>>(UEsNotifier.new);

// --- Enrollments Notifier ---
class EnrollmentsNotifier extends AsyncNotifier<PaginatedState<Enrollment>> {
  @override
  Future<PaginatedState<Enrollment>> build() async => fetchPage(1);

  Future<PaginatedState<Enrollment>> fetchPage(int page) async {
    final service = ref.read(enrollmentServiceProvider);
    final newItems = await service.getEnrollments(page, pageSize);
    final hasReachedMax = newItems.isEmpty || newItems.length < pageSize;
    
    if (page == 1) return PaginatedState(items: newItems, page: 1, hasReachedMax: hasReachedMax);
    
    final current = state.value!;
    return current.copyWith(
      items: [...current.items, ...newItems],
      page: page,
      hasReachedMax: hasReachedMax,
      isLoadingMore: false,
    );
  }

  Future<void> fetchNextPage() async {
    if (state.isLoading || state.hasError || (state.value?.hasReachedMax ?? true) || (state.value?.isLoadingMore ?? false)) return;
    
    state = AsyncData(state.value!.copyWith(isLoadingMore: true));
    try {
      final newState = await fetchPage(state.value!.page + 1);
      state = AsyncData(newState);
    } catch (e) {
      state = AsyncData(state.value!.copyWith(isLoadingMore: false));
    }
  }
}

final enrollmentsProvider = AsyncNotifierProvider<EnrollmentsNotifier, PaginatedState<Enrollment>>(EnrollmentsNotifier.new);

// --- Search Providers (unchanged conceptually) ---
final studentSearchProvider = StateProvider<String>((ref) => '');
final teacherSearchProvider = StateProvider<String>((ref) => '');
final ueSearchProvider = StateProvider<String>((ref) => '');

// We can remove filtered providers here since we will filter on backend or they won't work simply if we only have current page.
// If backend doesn't support search, we'll only search locally within the loaded items.
final filteredStudentsProvider = Provider<List<Student>>((ref) {
  final q = ref.watch(studentSearchProvider).toLowerCase();
  final paginatedState = ref.watch(studentsProvider).value;
  if (paginatedState == null) return [];
  final list = paginatedState.items;
  if (q.isEmpty) return list;
  return list.where((s) => s.fullName.toLowerCase().contains(q) || s.matricule.toLowerCase().contains(q) || s.filiere.toLowerCase().contains(q)).toList();
});

final filteredTeachersProvider = Provider<List<Teacher>>((ref) {
  final q = ref.watch(teacherSearchProvider).toLowerCase();
  final paginatedState = ref.watch(teachersProvider).value;
  if (paginatedState == null) return [];
  final list = paginatedState.items;
  if (q.isEmpty) return list;
  return list.where((t) => t.fullName.toLowerCase().contains(q) || t.department.toLowerCase().contains(q)).toList();
});

final filteredUEsProvider = Provider<List<UE>>((ref) {
  final q = ref.watch(ueSearchProvider).toLowerCase();
  final paginatedState = ref.watch(uesProvider).value;
  if (paginatedState == null) return [];
  final list = paginatedState.items;
  if (q.isEmpty) return list;
  return list.where((u) => u.title.toLowerCase().contains(q) || u.code.toLowerCase().contains(q)).toList();
});

// Single items finding
Student? findStudent(WidgetRef ref, String id) =>
    ref.read(studentsProvider).value?.items.where((s) => s.id == id).cast<Student?>().firstOrNull;
Teacher? findTeacher(WidgetRef ref, String id) =>
    ref.read(teachersProvider).value?.items.where((t) => t.id == id).cast<Teacher?>().firstOrNull;
UE? findUE(WidgetRef ref, String id) =>
    ref.read(uesProvider).value?.items.where((u) => u.id == id).cast<UE?>().firstOrNull;

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
