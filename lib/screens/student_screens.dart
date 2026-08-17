import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';

class StudentDashboardScreen extends ConsumerWidget {
  const StudentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uesAsync = ref.watch(uesProvider);
    final authState = ref.watch(authProvider);
    final userName = authState.user?.firstName ?? 'Étudiant';

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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bonjour, $userName! 👋', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text('Voici ce qui se passe aujourd\'hui', style: TextStyle(color: AppColors.textMutedLight)),
                    ],
                  ),
                  const CircleAvatar(
                    radius: 24,
                    backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=11'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Cours du jour & Prochains devoirs (Stacked for mobile)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Cours du jour', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              TextButton(
                                onPressed: () {},
                                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                child: const Text('Voir tout', style: TextStyle(color: AppColors.secondary, fontSize: 12)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          uesAsync.when(
                            data: (state) {
                              if (state.items.isEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 20),
                                  child: Center(child: Text('Aucun cours aujourd\'hui', style: TextStyle(color: AppColors.textMutedLight))),
                                );
                              }
                              // Prendre les 3 premiers UEs du backend
                              final displayUes = state.items.take(3).toList();
                              return Column(
                                children: displayUes.map((ue) {
                                  final isFirst = displayUes.indexOf(ue) == 0;
                                  return Column(
                                    children: [
                                      if (!isFirst) const Divider(height: 24),
                                      _buildCourseItem(
                                        '08:00', 
                                        '10:00', 
                                        ue.code, 
                                        ue.title, 
                                        'Salle B101', 
                                        isFirst ? 'En cours' : 'À venir', 
                                        isFirst ? AppColors.secondary.withValues(alpha: 0.1) : AppColors.primary.withValues(alpha: 0.1), 
                                        isFirst ? AppColors.secondary : AppColors.primary
                                      ),
                                    ],
                                  );
                                }).toList(),
                              );
                            },
                            loading: () => const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator())),
                            error: (err, _) => Center(child: Text('Erreur : $err')),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Prochains devoirs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              TextButton(
                                onPressed: () {},
                                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                child: const Text('Voir tout', style: TextStyle(color: AppColors.secondary, fontSize: 12)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildHomeworkItem('24', 'MAI', 'Algèbre linéaire', 'Devoir maison', 'À rendre demain'),
                          const SizedBox(height: 16),
                          _buildHomeworkItem('27', 'MAI', 'Mécanique du solide', 'Rapport de TP', 'À rendre dans 3 jours'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCourseItem(String start, String end, String subject, String title, String room, String status, Color statusBg, Color statusColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Text(start, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text(end, style: const TextStyle(color: AppColors.textMutedLight, fontSize: 11)),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(subject, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(title, style: const TextStyle(color: AppColors.textMutedLight, fontSize: 12)),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMutedLight),
                  const SizedBox(width: 4),
                  Text(room, style: const TextStyle(color: AppColors.textMutedLight, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusBg,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(status, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildHomeworkItem(String day, String month, String title, String subtitle, String due) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.bgLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Text(day, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(month, style: const TextStyle(color: AppColors.textMutedLight, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text(subtitle, style: const TextStyle(color: AppColors.textPrimaryLight, fontSize: 12)),
              const SizedBox(height: 2),
              Text(due, style: const TextStyle(color: AppColors.textMutedLight, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }
}

class StudentEdtScreen extends ConsumerWidget {
  const StudentEdtScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedulesAsync = ref.watch(schedulesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon EDT', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(schedulesProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Timeline des cours dynamiques
          Expanded(
            child: schedulesAsync.when(
              data: (schedules) {
                if (schedules.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text('Aucun cours trouvé dans l\'emploi du temps.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMutedLight)),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: schedules.length,
                  itemBuilder: (context, index) {
                    final item = schedules[index];
                    return _buildEdtTimeBlock(
                      item.formattedStart,
                      item.formattedEnd,
                      item.dayOfWeek,
                      item.course?.displayName ?? 'Cours',
                      item.course?.type ?? 'CM',
                      item.classroom?.name ?? 'Salle non attribuée',
                      AppColors.primary,
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Erreur: $err')),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildEdtTimeBlock(String start, String end, String code, String title, String type, String room, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 50,
            child: Column(
              children: [
                Text(start, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 30),
                Text(end, style: const TextStyle(color: AppColors.textMutedLight, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                border: Border(left: BorderSide(color: color, width: 4)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(code, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                        child: Text(type, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 14, color: color),
                      const SizedBox(width: 4),
                      Text(room, style: TextStyle(color: color, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StudentCoursesScreen extends StatefulWidget {
  const StudentCoursesScreen({super.key});

  @override
  State<StudentCoursesScreen> createState() => _StudentCoursesScreenState();
}

class _StudentCoursesScreenState extends State<StudentCoursesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<Map<String, dynamic>> _courses = [
    {
      'code': 'INFO101',
      'title': 'Algorithmique',
      'level': 'Licence 1',
      'credits': '6 ECTS',
      'volume': '60h',
      'color': AppColors.primary,
    },
    {
      'code': 'BD202',
      'title': 'Bases de données',
      'level': 'Licence 2',
      'credits': '6 ECTS',
      'volume': '45h',
      'color': AppColors.secondary,
    },
    {
      'code': 'RESE301',
      'title': 'Réseaux informatiques',
      'level': 'Licence 3',
      'credits': '6 ECTS',
      'volume': '60h',
      'color': AppColors.info,
    },
    {
      'code': 'IA401',
      'title': 'Intelligence Artificielle',
      'level': 'Master 1',
      'credits': '8 ECTS',
      'volume': '75h',
      'color': AppColors.warning,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unités d\'Enseignement', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher une UE...',
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _courses.length,
              itemBuilder: (context, index) {
                final course = _courses[index];
                final color = course['color'] as Color;
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.computer_rounded, color: color),
                    ),
                    title: Text(
                      '${course['code']} - ${course['title']}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        '${course['level']} • ${course['credits']} • ${course['volume']}',
                        style: const TextStyle(color: AppColors.textMutedLight),
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

