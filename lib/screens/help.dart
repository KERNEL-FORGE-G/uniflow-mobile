import 'package:flutter/material.dart';
import '../widgets/common.dart';
import '../theme/app_theme.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const GradientHeader(title: 'Centre d\'aide', subtitle: 'Support et documentation UniFlow'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SectionCard(
                  child: Column(
                    children: [
                      _buildHelpItem(context, Icons.help_outline, 'Guide de démarrage', 'Apprenez à utiliser les fonctions de base'),
                      const Divider(),
                      _buildHelpItem(context, Icons.qr_code, 'Comment scanner ma présence ?', 'Astuces pour un émargement réussi'),
                      const Divider(),
                      _buildHelpItem(context, Icons.security, 'Sécurité des données', 'Comment vos données sont protégées'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text('BESOIN D\'ASSISTANCE ?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.support_agent),
                  label: const Text('Contacter le support KERNEL FORGE'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal, foregroundColor: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(BuildContext context, IconData icon, String title, String desc) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.teal),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(desc, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: () {},
    );
  }
}
