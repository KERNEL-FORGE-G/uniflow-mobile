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
                  return const EmptyState(
                    icon: Icons.grade_outlined,
                    title: 'Aucune note enregistrée',
                    message: 'Vos résultats apparaîtront ici dès leur publication.',
                  );
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
                              color: (isGood ? AppColors.success : AppColors.danger).withValues(alpha: 0.1),
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
                                Text(grade.courseCode, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                              ],
                            ),
                          ),
                          Text(
                            '/ ${grade.maxScore.toInt()}',
                            style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const LoadingView(label: 'Chargement de vos notes…'),
              error: (err, stack) => Padding(
                padding: const EdgeInsets.all(16),
                child: ErrorBanner(
                  message: 'Vos notes n\'ont pas pu être chargées.\n$err',
                  onRetry: () => ref.invalidate(gradesListProvider),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
