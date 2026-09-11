import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/common.dart';
import '../theme/app_theme.dart';
import '../providers/providers.dart';
import '../repositories/academic_repository.dart';
import '../models/appwrite_models.dart';

final gradesListProvider = FutureProvider<List<AcademicGrade>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return ref.read(academicRepositoryProvider).getGrades(user.id);
});

class GradesScreen extends ConsumerWidget {
  const GradesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gradesAsync = ref.watch(gradesListProvider);

    return Scaffold(
      body: Column(
        children: [
          const GradientHeader(title: 'Mes Notes', subtitle: 'Résultats académiques officiels'),
          Expanded(
            child: gradesAsync.when(
              data: (grades) {
                if (grades.isEmpty) {
                  return const Center(child: Text('Aucune note enregistrée pour le moment.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: grades.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final grade = grades[index];
                    final ratio = grade.score / grade.maxScore;
                    final isGood = ratio >= 0.5;

                    return SectionCard(
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: (isGood ? AppColors.success : AppColors.danger).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${grade.score.toStringAsFixed(1)}',
                              style: TextStyle(
                                color: isGood ? AppColors.success : AppColors.danger,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(grade.evaluationTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                Text(grade.courseCode, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                              ],
                            ),
                          ),
                          Text(
                            '/ ${grade.maxScore.toInt()}',
                            style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w500),
                          ),
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
