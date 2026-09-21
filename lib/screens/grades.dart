import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/common.dart';
import '../theme/app_theme.dart';
import '../providers/providers.dart';
import '../repositories/academic_repository.dart';
import '../models/appwrite_models.dart';
import '../offline/cached_providers.dart';
import 'personal_space.dart';
import 'grading.dart';
import '../models/user_role.dart';

/// Notes de l'étudiant, cache local d'abord.
final gradesListProvider = StreamProvider<List<AcademicGrade>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const []);
  final repo = ref.read(academicRepositoryProvider);
  return cachedDocumentList<AcademicGrade>(
    ref,
    collection: 'academic_grades',
    fetch: () => repo.listAll('academic_grades', [Query.equal('studentId', user.id)]),
    fromDocument: AcademicGrade.fromDocument,
  );
});

class GradesScreen extends ConsumerWidget {
  const GradesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Un compte indépendant n'a pas de notes officielles : il saisit les
    // siennes. Même adresse, écran différent, pour que la barre du bas reste
    // la même dans les deux espaces.
    if (ref.watch(currentUserProvider)?.isPersonal ?? false) return const PersonalGradesView();
    // Un enseignant ou l'administration n'a pas de notes à recevoir : il en
    // saisit (service `/academic-grades`).
    final role = ref.watch(currentRoleProvider);
    if (role == UniFlowRole.teacher || role == UniFlowRole.admin) return const GradingScreen();
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
                              grade.score.toStringAsFixed(1),
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
                                Text(grade.evaluationTitle,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                Text(grade.courseCode,
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
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
              error: (err, stack) => LoadErrorView(
                title: 'Vos notes n\'ont pas pu être chargées',
                error: err,
                onRetry: () => ref.invalidate(gradesListProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
