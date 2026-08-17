import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';

class DelegateDashboardScreen extends StatelessWidget {
  const DelegateDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bonjour, Karim 🎒', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_none), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Voici l\'état et le suivi de votre classe', style: TextStyle(color: AppColors.textMutedLight)),
            const SizedBox(height: 24),

            // Cartes de statistiques
            Row(
              children: [
                Expanded(
                  child: _buildStatCard('Étudiants', '32', 'Total classe', AppColors.primary, Icons.people_outline),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard('Présents', '27', '84% de présence', AppColors.secondary, Icons.check_circle_outline),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard('Absents', '5', 'Ce jour', AppColors.danger, Icons.cancel_outlined),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Alertes récentes
            const Text('Alertes récentes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildAlertCard(
              context,
              '3 absences non justifiées',
              'Classe L2 Informatique - Mathématiques',
              'Il y a 30 min',
              AppColors.danger,
              Icons.warning_amber_rounded,
            ),
            const SizedBox(height: 12),
            _buildAlertCard(
              context,
              'Devoir en retard',
              'Mathématiques - 6 étudiants manquants',
              'Il y a 2 h',
              AppColors.warning,
              Icons.alarm,
            ),
            const SizedBox(height: 12),
            _buildAlertCard(
              context,
              'Rappel : Réunion de classe',
              'Aujourd\'hui à 16:00',
              'Il y a 3 h',
              AppColors.info,
              Icons.campaign_outlined,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, String subtitle, Color color, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: AppColors.textMutedLight, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertCard(BuildContext context, String title, String subtitle, String time, Color color, IconData icon) {
    return Card(
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: AppColors.textMutedLight, fontSize: 13)),
            const SizedBox(height: 4),
            Text(time, style: const TextStyle(fontSize: 11, color: AppColors.textMutedLight)),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}

class DelegateClassScreen extends ConsumerWidget {
  const DelegateClassScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(studentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ma Classe (Délégué)', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(studentsProvider),
          ),
        ],
      ),
      body: studentsAsync.when(
        data: (paginated) {
          if (paginated.items.isEmpty) {
            return const Center(child: Text('Aucun étudiant dans votre classe.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: paginated.items.length,
            itemBuilder: (context, index) {
              final student = paginated.items[index];
              final isAbsent = index % 4 == 0; // Indicatif
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: Text(student.initials, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(student.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${student.matricule} • ${student.filiere} (${student.niveau})'),
                  trailing: isAbsent 
                    ? ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Justification enregistrée pour ${student.fullName}')),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.danger,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        ),
                        child: const Text('Justifier', style: TextStyle(fontSize: 11)),
                      )
                    : const Icon(Icons.check_circle_outline, color: AppColors.secondary),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erreur: $err')),
      ),
    );
  }
}

class DelegateDocsScreen extends StatelessWidget {
  const DelegateDocsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents Partagés', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.add_a_photo_outlined), onPressed: () {}),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildDocItem('Support de Cours - Algèbre.pdf', 'Mathématiques', '14.2 Mo', 'Aujourd\'hui'),
          _buildDocItem('TP1 Bases de Données - SQL.zip', 'Informatique', '4.5 Mo', 'Hier'),
          _buildDocItem('Fiche TD3 - Mécanique du Solide.pdf', 'Physique', '2.1 Mo', 'Il y a 3 jours'),
        ],
      ),
    );
  }

  Widget _buildDocItem(String name, String category, String size, String date) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.insert_drive_file, color: AppColors.primary, size: 36),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text('$category • $size • $date', style: const TextStyle(color: AppColors.textMutedLight, fontSize: 12)),
        trailing: IconButton(
          icon: const Icon(Icons.download),
          onPressed: () {},
        ),
      ),
    );
  }
}
