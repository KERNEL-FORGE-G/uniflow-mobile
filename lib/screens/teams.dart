import 'package:flutter/material.dart';
import '../widgets/common.dart';
import '../theme/app_theme.dart';
import '../utils/avatar.dart';

/// Un membre de l'équipe KERNEL FORGE.
class _Member {
  final String name;
  final String role;

  const _Member(this.name, this.role);
}

class TeamsScreen extends StatelessWidget {
  const TeamsScreen({super.key});

  static const List<_Member> _members = [
    _Member('NGHOMSI RAVEL', 'Architecte'),
    _Member('Aliyatou Rachid', 'Frontend'),
    _Member('Mandeng Judith', 'Mobile'),
    _Member('Meli William', 'Backend'),
    _Member('Sandra Borelle', 'Mobile'),
    _Member('Ange Mokam', 'Base de données'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const GradientHeader(
            title: 'L\'Équipe KERNEL FORGE',
            subtitle: 'Université de Yaoundé I',
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              itemCount: _members.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                // 0.95 laisse assez de hauteur pour l'avatar, un nom sur deux
                // lignes et le rôle ; la valeur par défaut (1.0) serrait le
                // contenu et le tronquait sur les petits écrans.
                childAspectRatio: 0.95,
              ),
              itemBuilder: (context, i) => _MemberCard(member: _members[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final _Member member;

  const _MemberCard({required this.member});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Avatar(initials: initialsOf(member.name), size: 44),
          const SizedBox(height: 10),
          // `Flexible` + ellipse : un nom long se replie au lieu de pousser le
          // rôle hors de la carte.
          Flexible(
            child: Text(
              member.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                color: AppColors.textPrimary,
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            member.role,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
