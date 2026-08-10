import 'package:flutter/material.dart';
import '../widgets/common.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const GradientHeader(
            title: 'Réglages', subtitle: 'Préférences de l\'application'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              SectionCard(
                child: Column(
                  children: [
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading:
                            Icon(Icons.person_outline, color: AppColors.secondary),
                        title: Text('Profil')),
                    Divider(height: 1),
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.notifications_outlined,
                            color: AppColors.secondary),
                        title: Text('Notifications')),
                    Divider(height: 1),
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading:
                            Icon(Icons.lock_outline, color: AppColors.secondary),
                        title: Text('Sécurité')),
                    Divider(height: 1),
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading:
                            Icon(Icons.info_outline, color: AppColors.secondary),
                        title: Text('À propos')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

