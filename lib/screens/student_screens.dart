import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StudentDashboardScreen extends StatelessWidget {
  const StudentDashboardScreen({super.key});

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
                      Text('Bonjour, Ahmed! 👋', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text('Voici ce qui se passe aujourd\'hui', style: TextStyle(color: AppColors.textMutedLight)),
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
                          _buildCourseItem('08:00', '10:00', 'Mathématiques', 'Algèbre linéaire', 'Salle A202', 'En cours', AppColors.secondary.withValues(alpha: 0.1), AppColors.secondary),
                          const Divider(height: 24),
                          _buildCourseItem('10:00', '12:00', 'Physique', 'Mécanique du solide', 'Salle B301', 'À venir', AppColors.primary.withValues(alpha: 0.1), AppColors.primary),
                          const Divider(height: 24),
                          _buildCourseItem('14:00', '16:00', 'Informatique', 'Structures de données', 'Salle Info 2', 'À venir', AppColors.primary.withValues(alpha: 0.1), AppColors.primary),
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

class StudentEdtScreen extends StatelessWidget {
  const StudentEdtScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon EDT', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          IconButton(icon: const Icon(Icons.calendar_month), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          // Sélecteur de semaine
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: AppColors.surfaceLight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(icon: const Icon(Icons.chevron_left), onPressed: () {}),
                const Text('Semaine 24 (13 - 19 Mai 2024)', style: TextStyle(fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.chevron_right), onPressed: () {}),
              ],
            ),
          ),
          
          // Onglets Jours (simplifié pour l'affichage)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: AppColors.surfaceLight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildDayTab('13', 'LUN', false),
                _buildDayTab('14', 'MAR', true),
                _buildDayTab('15', 'MER', false),
                _buildDayTab('16', 'JEU', false),
                _buildDayTab('17', 'VEN', false),
                _buildDayTab('18', 'SAM', false),
              ],
            ),
          ),
          
          // Timeline des cours
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildEdtTimeBlock('08:00', '10:00', 'MATH201', 'Algèbre Linéaire', 'CM', 'Amphi A', AppColors.info),
                _buildEdtTimeBlock('10:00', '12:00', 'INFO101', 'Bases de données', 'TD', 'Salle B204', AppColors.secondary),
                const SizedBox(height: 60), // Trou dans l'emploi du temps
                _buildEdtTimeBlock('14:00', '16:00', 'PHYS201', 'Mécanique', 'TP', 'Lab L3', AppColors.warning),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayTab(String day, String weekday, bool isSelected) {
    return Column(
      children: [
        Text(weekday, style: TextStyle(color: isSelected ? AppColors.secondary : AppColors.textMutedLight, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.secondary : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(day, style: TextStyle(color: isSelected ? Colors.white : AppColors.textPrimaryLight, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
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

class StudentCoursesScreen extends StatelessWidget {
  const StudentCoursesScreen({super.key});
  @override Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Cours Étudiant')));
}

