import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';

class TeacherDashboardScreen extends ConsumerWidget {
  const TeacherDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uesAsync = ref.watch(uesProvider);
    final authState = ref.watch(authProvider);
    final userName = authState.user?.fullName ?? 'Enseignant';

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bonjour Dr. $userName! 🎓', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text('Voici vos sessions à venir', style: TextStyle(color: AppColors.textMutedLight)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.notifications_none),
                    onPressed: () => context.push('/shared/notifications'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.person_outline),
                    onPressed: () => context.push('/shared/profile'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Mes cours & Séances
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Vos cours enseignés', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          TextButton(
                            onPressed: () => context.go('/teacher/courses'),
                            child: const Text('Voir tout'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      uesAsync.when(
                        data: (state) {
                          if (state.items.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(child: Text('Aucun cours assigné pour le moment.')),
                            );
                          }
                          final list = state.items.take(3).toList();
                          return Column(
                            children: list.map((ue) => ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                child: Text(ue.code, style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold)),
                              ),
                              title: Text(ue.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Text('${ue.credits} Crédits • ${ue.cm}h CM'),
                            )).toList(),
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (err, _) => Center(child: Text('Erreur : $err')),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Actions rapides enseignant
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Actions rapides', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildQuickActionButton(
                              context,
                              Icons.qr_code_scanner,
                              'Scanner QR',
                              AppColors.primary,
                              () => context.push('/shared/presence'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildQuickActionButton(
                              context,
                              Icons.calendar_month,
                              'Mon EDT',
                              AppColors.secondary,
                              () => context.go('/teacher/edt'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

/// -------------------------------------------------------------------
/// TEACHER COURSES SCREEN (Dynamic from coursesProvider & uesProvider)
/// -------------------------------------------------------------------
class TeacherCoursesScreen extends ConsumerWidget {
  const TeacherCoursesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uesAsync = ref.watch(uesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Cours', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: uesAsync.when(
        data: (paginated) {
          if (paginated.items.isEmpty) {
            return const Center(child: Text('Aucun cours trouvé.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: paginated.items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final ue = paginated.items[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(ue.code, style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold)),
                          ),
                          Text('${ue.credits} ECTS', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(ue.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(ue.description.isNotEmpty ? ue.description : 'Volume horaire: CM: ${ue.cm}h, TD: ${ue.td}h, TP: ${ue.tp}h',
                          style: const TextStyle(color: AppColors.textMutedLight, fontSize: 13)),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => context.push('/shared/presence'),
                            icon: const Icon(Icons.qr_code),
                            label: const Text('Faire l\'appel'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
      ),
    );
  }
}

/// -------------------------------------------------------------------
/// TEACHER EDT SCREEN (Dynamic from schedulesProvider)
/// -------------------------------------------------------------------
class TeacherEdtScreen extends ConsumerWidget {
  const TeacherEdtScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedulesAsync = ref.watch(schedulesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emploi du Temps Enseignant', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: schedulesAsync.when(
        data: (schedules) {
          if (schedules.isEmpty) {
            return const Center(child: Text('Aucune séance programmée cette semaine.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: schedules.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final schedule = schedules[index];
              return Card(
                child: ListTile(
                  leading: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(schedule.dayOfWeek, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.secondary)),
                      Text('${schedule.formattedStart} - ${schedule.formattedEnd}', style: const TextStyle(fontSize: 10, color: AppColors.textMutedLight)),
                    ],
                  ),
                  title: Text(schedule.course?.displayName ?? 'Séance d\'Enseignement', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Salle: ${schedule.classroom?.name ?? 'Non attribuée'}'),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
      ),
    );
  }
}
