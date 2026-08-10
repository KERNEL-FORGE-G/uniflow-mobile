import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bonjour, Admin 👑', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          Stack(
            children: [
              IconButton(icon: const Icon(Icons.notifications_none), onPressed: () {}),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(10)),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: const Text('5', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                ),
              )
            ],
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
                Expanded(child: _buildStatCard('Étudiants', '1,248', '+12% ce mois', AppColors.primary, Icons.group)),
                const SizedBox(width: 16),
                Expanded(child: _buildStatCard('Enseignants', '86', '+3% ce mois', AppColors.secondary, Icons.school)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildStatCard('Cours', '342', '+8% ce mois', AppColors.info, Icons.book)),
                const SizedBox(width: 16),
                Expanded(child: _buildStatCard('Sessions aujourd\'hui', '28', 'En cours', AppColors.warning, Icons.calendar_today)),
              ],
            ),
            const SizedBox(height: 32),
            
            // Activité récente
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Activité récente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton(onPressed: () {}, child: const Text('Voir tout')),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  _buildActivityItem(Icons.person_add, 'Nouvel étudiant inscrit', 'Il y a 10 min', AppColors.secondary),
                  const Divider(height: 1),
                  _buildActivityItem(Icons.warning, 'Nouveau retard validé - L2 Informatique', 'Il y a 1 h', AppColors.warning),
                  const Divider(height: 1),
                  _buildActivityItem(Icons.sync, 'Mise à jour des emplois du temps', 'Il y a 2 h', AppColors.info),
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

class AdminUsersScreen extends StatelessWidget {
  const AdminUsersScreen({super.key});
  @override Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Utilisateurs Admin')));
}

class AdminAcademicScreen extends StatelessWidget {
  const AdminAcademicScreen({super.key});
  @override Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Académique Admin')));
}

class AdminReportsScreen extends StatelessWidget {
  const AdminReportsScreen({super.key});
  @override Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Rapports Admin')));
}

