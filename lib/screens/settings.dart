import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import '../widgets/common.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _tokenController;

  @override
  void initState() {
    super.initState();
    _tokenController = TextEditingController(text: dotenv.get('UNIFLOW_API_TOKEN', fallback: ''));
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const GradientHeader(title: 'Réglages', subtitle: 'Préférences de l\'application'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionCard(
                child: Column(
                  children: [
                    const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.person_outline, color: AppColors.teal), title: Text('Profil')),
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.security_outlined, color: AppColors.teal),
                      title: const Text('Sentinelle IoT'),
                      onTap: () => GoRouter.of(context).push('/sentinelle'),
                    ),
                    const Divider(height: 1),
                    const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.notifications_outlined, color: AppColors.teal), title: Text('Notifications')),
                    const Divider(height: 1),
                    const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.lock_outline, color: AppColors.teal), title: Text('Sécurité')),
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.groups_outlined, color: AppColors.teal),
                      title: const Text('L\'Équipe KERNEL FORGE'),
                      onTap: () => GoRouter.of(context).push('/equipe'),
                    ),
                    const Divider(height: 1),
                    const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.info_outline, color: AppColors.teal), title: Text('À propos')),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('DEVELOPPEMENT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
              const SizedBox(height: 8),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('UniFlow API Token', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _tokenController,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: 'Saisissez votre clé d\'API...',
                        filled: true,
                        fillColor: AppColors.inputFill,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ce jeton est utilisé pour authentifier les requêtes vers les services UniFlow sécurisés.',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
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
