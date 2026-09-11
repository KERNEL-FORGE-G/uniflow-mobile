import 'package:flutter/material.dart';
import '../widgets/common.dart';
import '../theme/app_theme.dart';

class TeamsScreen extends StatelessWidget {
  const TeamsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const GradientHeader(title: 'L\'Équipe KERNEL FORGE', subtitle: 'Université de Yaoundé I'),
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.all(16),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: const [
                _MemberCard(name: 'NGHOMSI RAVEL', role: 'Architect'),
                _MemberCard(name: 'Aliyatou Rachid', role: 'Frontend'),
                _MemberCard(name: 'Mandeng Judith', role: 'Mobile'),
                _MemberCard(name: 'Meli William', role: 'Backend'),
                _MemberCard(name: 'Sandra Borelle', role: 'Mobile'),
                _MemberCard(name: 'Ange Mokam', role: 'Database'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final String name, role;
  const _MemberCard({required this.name, required this.role});
  @override Widget build(BuildContext context) => SectionCard(padding: const EdgeInsets.all(12), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Avatar(initials: '?', size: 40), const SizedBox(height: 8), Text(name, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), Text(role, style: const TextStyle(fontSize: 11, color: AppColors.textMuted))]));
}
