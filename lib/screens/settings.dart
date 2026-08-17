import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Réglages & Configuration', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Section Compte
          const Text('Compte & Session', style: TextStyle(color: AppColors.textMutedLight, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: Icon(Icons.person, color: Colors.white, size: 20),
                  ),
                  title: Text(authState.user?.fullName ?? 'Utilisateur', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(authState.user?.email ?? 'Connecté'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                    child: Text(authState.user?.role ?? 'ETUDIANT', style: const TextStyle(color: AppColors.secondary, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout, color: AppColors.danger),
                  title: const Text('Se déconnecter', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
                  onTap: () {
                    ref.read(authProvider.notifier).logout();
                    context.go('/login');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section Préférences
          const Text('Préférences Application', style: TextStyle(color: AppColors.textMutedLight, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_active_outlined, color: AppColors.secondary),
                  title: const Text('Notifications push'),
                  subtitle: const Text('Rappels de cours & alertes de présence'),
                  value: true,
                  onChanged: (val) {},
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.vibration, color: AppColors.secondary),
                  title: const Text('Vibrations & Haptique'),
                  subtitle: const Text('Confirmations d\'émargement'),
                  value: true,
                  onChanged: (val) {},
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.language_outlined, color: AppColors.secondary),
                  title: const Text('Langue'),
                  subtitle: const Text('Français'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section Connexion Réseau Backend
          const Text('Serveur & Réseau', style: TextStyle(color: AppColors.textMutedLight, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: const [
                ListTile(
                  leading: Icon(Icons.dns_outlined, color: AppColors.info),
                  title: Text('API Host'),
                  subtitle: Text('https://api-uniflow.kernelforge.codes'),
                  trailing: Icon(Icons.check_circle, color: AppColors.secondary, size: 18),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.cloud_queue_outlined, color: AppColors.info),
                  title: Text('Mode Déploiement'),
                  subtitle: Text('Production API v1.0 (NestJS)'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
