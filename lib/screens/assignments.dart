import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../widgets/common.dart';
import '../theme/app_theme.dart';
import '../providers/providers.dart';
import '../repositories/academic_repository.dart';
import '../models/appwrite_models.dart';

final assignmentsListProvider = FutureProvider<List<AcademicAssignment>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return ref.read(academicRepositoryProvider).getAssignments(user.id);
});

class AssignmentsScreen extends ConsumerWidget {
  const AssignmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentsAsync = ref.watch(assignmentsListProvider);

    return Scaffold(
      body: Column(
        children: [
          const GradientHeader(title: 'Mes Devoirs', subtitle: 'Tâches et rendus académiques'),
          Expanded(
            child: assignmentsAsync.when(
              data: (assignments) {
                if (assignments.isEmpty) {
                  return const Center(child: Text('Aucun devoir en attente.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: assignments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final assignment = assignments[index];
                    final dueDate = DateTime.tryParse(assignment.dueDate);
                    final isLate = dueDate != null && dueDate.isBefore(DateTime.now());

                    return SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              StatusBadge(label: assignment.status ?? 'EN ATTENTE'),
                              if (dueDate != null)
                                Text(
                                  DateFormat('dd MMM yyyy').format(dueDate),
                                  style: TextStyle(
                                    color: isLate ? AppColors.danger : AppColors.textMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(assignment.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text(
                            'Cours: ${assignment.courseCode}',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                          ),
                          if (assignment.description != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              assignment.description!,
                              style: const TextStyle(fontSize: 14),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Erreur: $err')),
            ),
          ),
        ],
      ),
    );
  }
}
