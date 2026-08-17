import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// -------------------------------------------------------------------
/// NOTIFICATIONS SCREEN (Dynamic from backend)
/// -------------------------------------------------------------------
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(notificationsProvider),
          ),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.notifications_off_outlined, size: 48, color: AppColors.primary),
                  ),
                  const SizedBox(height: 16),
                  const Text('Aucune notification', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Vous êtes à jour !', style: TextStyle(color: AppColors.textMutedLight)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = notifications[index];
              return Card(
                elevation: item.isRead ? 0 : 2,
                color: item.isRead ? Colors.white : AppColors.secondary.withValues(alpha: 0.05),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getTypeColor(item.type).withValues(alpha: 0.15),
                    child: Icon(_getTypeIcon(item.type), color: _getTypeColor(item.type), size: 20),
                  ),
                  title: Text(item.title, style: TextStyle(fontWeight: item.isRead ? FontWeight.normal : FontWeight.bold, fontSize: 14)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(item.body, style: const TextStyle(fontSize: 12)),
                  ),
                  trailing: Text(
                    '${item.createdAt.hour.toString().padLeft(2, '0')}:${item.createdAt.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: AppColors.textMutedLight, fontSize: 11),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
              const SizedBox(height: 12),
              Text('Erreur: $err', style: const TextStyle(color: AppColors.danger)),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toUpperCase()) {
      case 'ALERT':
      case 'URGENT':
        return AppColors.danger;
      case 'SUCCESS':
        return AppColors.secondary;
      case 'WARNING':
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toUpperCase()) {
      case 'ALERT':
      case 'URGENT':
        return Icons.warning_amber_rounded;
      case 'SUCCESS':
        return Icons.check_circle_outline;
      case 'WARNING':
        return Icons.info_outline;
      default:
        return Icons.notifications_none;
    }
  }
}

/// -------------------------------------------------------------------
/// PROFILE SCREEN (Dynamic from AuthState)
/// -------------------------------------------------------------------
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Profil', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/shared/settings'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Card Header
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                      child: Text(
                        user != null && user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : 'U',
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user?.fullName ?? 'Utilisateur',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? 'Non connecté',
                      style: const TextStyle(color: AppColors.textMutedLight, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        user?.role ?? 'ETUDIANT',
                        style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // User Info Section
            Card(
              child: Column(
                children: [
                  _buildProfileTile(Icons.badge_outlined, 'Matricule', user?.matricule ?? 'N/A'),
                  const Divider(height: 1),
                  _buildProfileTile(Icons.school_outlined, 'Niveau', user?.level ?? 'Licence / Master'),
                  const Divider(height: 1),
                  _buildProfileTile(Icons.mail_outline, 'Adresse email', user?.email ?? 'Non renseigné'),
                  const Divider(height: 1),
                  _buildProfileTile(Icons.security_outlined, 'Statut du compte', 'Actif & Vérifié'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Logout Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  ref.read(authProvider.notifier).logout();
                  context.go('/login');
                },
                icon: const Icon(Icons.logout),
                label: const Text('Déconnexion', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTile(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 12, color: AppColors.textMutedLight)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimaryLight)),
    );
  }
}

/// -------------------------------------------------------------------
/// MESSAGES SCREEN
/// -------------------------------------------------------------------
class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messagerie & Annonces', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.edit_note_outlined), onPressed: () {}),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMessageGroupHeader('Annonces Générales'),
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.secondary,
                child: Icon(Icons.campaign, color: Colors.white, size: 20),
              ),
              title: const Text('Administration UniFlow', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('Rappel: Publication des plannings d\'examens du Semestre 2.', maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Text('10:30', style: TextStyle(color: AppColors.textMutedLight, fontSize: 11)),
            ),
          ),
          const SizedBox(height: 16),
          _buildMessageGroupHeader('Canaux de cours'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: const Text('AL', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ),
                  title: const Text('Algèbre Linéaire (INF201)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Prof: N\'oubliez pas d\'apporter la fiche TP N°2 demain.'),
                  trailing: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: AppColors.secondary, shape: BoxShape.circle),
                    child: const Text('2', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.info.withValues(alpha: 0.1),
                    child: const Text('BD', style: TextStyle(color: AppColors.info, fontWeight: FontWeight.bold)),
                  ),
                  title: const Text('Bases de Données (INF202)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Délégué: Le cours de 14h est déplacé en Salle B102.'),
                  trailing: const Text('Hier', style: TextStyle(color: AppColors.textMutedLight, fontSize: 11)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageGroupHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(title, style: const TextStyle(color: AppColors.textMutedLight, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}

/// -------------------------------------------------------------------
/// SETTINGS SCREEN
/// -------------------------------------------------------------------
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSettingsSectionHeader('Préférences d\'affichage'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.dark_mode_outlined, color: AppColors.primary),
                  title: const Text('Mode sombre'),
                  subtitle: const Text('Activer l\'interface sombre'),
                  value: false,
                  onChanged: (val) {},
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.language_outlined, color: AppColors.primary),
                  title: const Text('Langue'),
                  subtitle: const Text('Français (Cameroun / Int.)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSettingsSectionHeader('Notifications'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_active_outlined, color: AppColors.secondary),
                  title: const Text('Alertes Push'),
                  subtitle: const Text('Changements d\'emploi du temps & retards'),
                  value: true,
                  onChanged: (val) {},
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.mail_outline, color: AppColors.secondary),
                  title: const Text('Notifications Email'),
                  subtitle: const Text('Récapitulatif hebdomadaire'),
                  value: true,
                  onChanged: (val) {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSettingsSectionHeader('Système & Connexion'),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.cloud_done_outlined, color: AppColors.info),
                  title: Text('Serveur Backend'),
                  subtitle: Text('https://api-uniflow.kernelforge.codes'),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.info_outline, color: AppColors.textMutedLight),
                  title: Text('Version de l\'application'),
                  subtitle: Text('UniFlow v1.0.0 (Build 2026.08)'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(title, style: const TextStyle(color: AppColors.textMutedLight, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}
