import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(studentsProvider);
    final teachersAsync = ref.watch(teachersProvider);
    final uesAsync = ref.watch(uesProvider);
    final classroomsAsync = ref.watch(classroomsProvider);
    final authState = ref.watch(authProvider);
    final userName = authState.user?.firstName ?? 'Admin';

    final studentsCount = studentsAsync.hasValue ? studentsAsync.value!.items.length.toString() : '...';
    final teachersCount = teachersAsync.hasValue ? teachersAsync.value!.items.length.toString() : '...';
    final uesCount = uesAsync.hasValue ? uesAsync.value!.items.length.toString() : '...';
    final classroomsCount = classroomsAsync.hasValue ? classroomsAsync.value!.length.toString() : '...';

    return Scaffold(
      appBar: AppBar(
        title: Text('Bonjour, $userName 👑', style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () => context.push('/shared/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/shared/profile'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Vue d\'ensemble de la plateforme', style: TextStyle(color: AppColors.textMutedLight)),
            const SizedBox(height: 24),
            
            // Stats Grid 2x2
            Row(
              children: [
                Expanded(child: _buildStatCard('Étudiants', studentsCount, 'Actifs sur la plateforme', AppColors.primary, Icons.group)),
                const SizedBox(width: 16),
                Expanded(child: _buildStatCard('Enseignants', teachersCount, 'Enseignants enregistrés', AppColors.secondary, Icons.school)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildStatCard('Cours (UEs)', uesCount, 'Matières créées', AppColors.info, Icons.book)),
                const SizedBox(width: 16),
                Expanded(child: _buildStatCard('Salles', classroomsCount, 'Infrastructures', AppColors.warning, Icons.meeting_room)),
              ],
            ),
            const SizedBox(height: 32),
            
            // Actions rapides Administrateur
            const Text('Gestion Administrateur', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => context.go('/admin/users'),
                    icon: const Icon(Icons.people_alt_outlined),
                    label: const Text('Utilisateurs'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => context.go('/admin/academic'),
                    icon: const Icon(Icons.account_balance_outlined),
                    label: const Text('Académique'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Activité récente
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Activité récente du système', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () => context.go('/admin/reports'),
                  child: const Text('Rapports'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  _buildActivityItem(Icons.person_add, 'Synchronisation des profils utilisateurs', 'Aujourd\'hui', AppColors.secondary),
                  const Divider(height: 1),
                  _buildActivityItem(Icons.meeting_room, 'Salles de cours à jour sur le backend', 'Récemment', AppColors.info),
                  const Divider(height: 1),
                  _buildActivityItem(Icons.check_circle_outline, 'Base de données UniFlow connectée', 'En direct', AppColors.secondary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, String subtitle, Color color, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(color: AppColors.textMutedLight, fontWeight: FontWeight.bold, fontSize: 13)),
                Icon(icon, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(IconData icon, String text, String time, Color color) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      trailing: Text(time, style: const TextStyle(color: AppColors.textMutedLight, fontSize: 12)),
    );
  }
}

/// -------------------------------------------------------------------
/// ADMIN USERS SCREEN (Tabs for Students & Teachers)
/// -------------------------------------------------------------------
class AdminUsersScreen extends ConsumerWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(studentsProvider);
    final teachersAsync = ref.watch(teachersProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gestion des Utilisateurs', style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.school), text: 'Étudiants'),
              Tab(icon: Icon(Icons.person), text: 'Enseignants'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // TAB 1: ETUDIANTS
            studentsAsync.when(
              data: (paginated) {
                if (paginated.items.isEmpty) {
                  return const Center(child: Text('Aucun étudiant trouvé dans la base.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: paginated.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final student = paginated.items[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          child: Text(student.initials, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(student.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${student.matricule} • ${student.filiere} (${student.niveau})'),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(student.status, style: const TextStyle(color: AppColors.secondary, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur: $e')),
            ),

            // TAB 2: ENSEIGNANTS
            teachersAsync.when(
              data: (paginated) {
                if (paginated.items.isEmpty) {
                  return const Center(child: Text('Aucun enseignant trouvé dans la base.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: paginated.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final teacher = paginated.items[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.secondary.withValues(alpha: 0.1),
                          child: Text(teacher.initials, style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(teacher.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${teacher.department} • ${teacher.email}'),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(teacher.status, style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur: $e')),
            ),
          ],
        ),
      ),
    );
  }
}

/// -------------------------------------------------------------------
/// ADMIN ACADEMIC SCREEN (Tabs for UEs & Classrooms)
/// -------------------------------------------------------------------
class AdminAcademicScreen extends ConsumerWidget {
  const AdminAcademicScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uesAsync = ref.watch(uesProvider);
    final classroomsAsync = ref.watch(classroomsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gestion Académique', style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.book), text: 'Unités d\'Enseignement (UEs)'),
              Tab(icon: Icon(Icons.meeting_room), text: 'Salles & Amphis'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // UEs
            uesAsync.when(
              data: (paginated) {
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: paginated.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final ue = paginated.items[index];
                    return Card(
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.info.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(ue.code, style: const TextStyle(color: AppColors.info, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(ue.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${ue.credits} Crédits • CM: ${ue.cm}h, TD: ${ue.td}h, TP: ${ue.tp}h'),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur: $e')),
            ),

            // Classrooms
            classroomsAsync.when(
              data: (classrooms) {
                if (classrooms.isEmpty) {
                  return const Center(child: Text('Aucune salle configurée.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: classrooms.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final room = classrooms[index];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.secondary,
                          child: Icon(Icons.meeting_room, color: Colors.white, size: 20),
                        ),
                        title: Text(room.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Bâtiment: ${room.building} • Type: ${room.typeLabel}'),
                        trailing: Text('${room.capacity} places', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur: $e')),
            ),
          ],
        ),
      ),
    );
  }
}

/// -------------------------------------------------------------------
/// ADMIN REPORTS SCREEN
/// -------------------------------------------------------------------
class AdminReportsScreen extends ConsumerWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statsOverviewProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapports & Audit', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: statsAsync.when(
        data: (stats) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Rapport d\'assiduité & Statistiques', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildReportRow('Total étudiants enregistrés', '${stats.totalStudents}'),
                      const Divider(),
                      _buildReportRow('Total enseignants enregistrés', '${stats.totalTeachers}'),
                      const Divider(),
                      _buildReportRow('Total UEs au catalogue', '${stats.totalUEs}'),
                      const Divider(),
                      _buildReportRow('Total salles de cours', '${stats.totalClassrooms}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Journaux d\'activité & Audit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.security, color: AppColors.secondary),
                      title: const Text('Dernière authentification Admin'),
                      subtitle: const Text('Connexion réussie depuis API Swagger'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.check_circle, color: AppColors.primary),
                      title: const Text('État des services'),
                      subtitle: const Text('Tous les microservices sont opérationnels (100%)'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
      ),
    );
  }

  Widget _buildReportRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMutedLight)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }
}
