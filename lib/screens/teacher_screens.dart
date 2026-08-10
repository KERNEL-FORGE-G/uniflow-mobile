import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TeacherDashboardScreen extends StatelessWidget {
  const TeacherDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bonjour Dr. Benali! 🎓', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text('Voici vos sessions à venir', style: TextStyle(color: AppColors.textMutedLight)),
                    ],
                  ),
                  const CircleAvatar(
                    radius: 24,
                    backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=60'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Sessions à venir & À faire
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
                              const Text('Sessions à venir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              TextButton(
                                onPressed: () {},
                                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                child: const Text('Voir tout', style: TextStyle(color: AppColors.secondary, fontSize: 12)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildSessionItem('08:00', '10:00', 'Mathématiques', 'Amphi A', true),
                          const Divider(height: 24),
                          _buildSessionItem('11:00', '13:00', 'Algèbre linéaire', 'Salle A202', false),
                          const Divider(height: 24),
                          _buildSessionItem('14:30', '16:00', 'Séminaire', 'Salle Conf 1', false),
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
                              const Text('À faire', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              TextButton(
                                onPressed: () {},
                                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                child: const Text('Voir tout', style: TextStyle(color: AppColors.secondary, fontSize: 12)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildTodoItem(Icons.assignment, 'Corriger des copies', '12 copies', AppColors.primary),
                          const SizedBox(height: 16),
                          _buildTodoItem(Icons.book, 'Préparer le cours', 'Algèbre linéaire', AppColors.secondary),
                          const SizedBox(height: 16),
                          _buildTodoItem(Icons.cloud_upload, 'Publier des notes', 'Analyse 2', AppColors.primary),
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

  Widget _buildSessionItem(String start, String end, String subject, String room, bool active) {
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
        if (active)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text('Dans 30 min', style: TextStyle(color: AppColors.secondary, fontSize: 12, fontWeight: FontWeight.bold)),
          )
        else
           Text('Dans 2h', style: TextStyle(color: AppColors.textMutedLight, fontSize: 12)),
      ],
    );
  }

  Widget _buildTodoItem(IconData icon, String title, String subtitle, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(subtitle, style: const TextStyle(color: AppColors.textMutedLight, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}

class TeacherCoursesScreen extends StatelessWidget {
  const TeacherCoursesScreen({super.key});
  @override Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Mes Cours Enseignant')));
}

class TeacherEdtScreen extends StatelessWidget {
  const TeacherEdtScreen({super.key});
  @override Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Calendrier Enseignant')));
}

