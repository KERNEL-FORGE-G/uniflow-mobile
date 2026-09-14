import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/common.dart';
import '../theme/app_theme.dart';

class SentinelleScreen extends ConsumerWidget {
  const SentinelleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Column(
        children: [
          const GradientHeader(
            title: 'Sentinelle IoT',
            subtitle: 'Surveillance et santé connectée',
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              children: [
                SectionCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Icon(
                          Icons.monitor_heart_outlined,
                          size: 36,
                          color: AppColors.danger,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Kiosque Santé Virtuel', style: AppTextStyles.h3),
                      const SizedBox(height: 4),
                      const Text(
                        'Prêt pour le pré-diagnostic',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body,
                      ),
                      const SizedBox(height: 20),
                      PrimaryButton(
                        label: 'Lancer un scan local',
                        icon: Icons.play_arrow_rounded,
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Le scan local nécessite le capteur Sentinelle, '
                                'qui n\'est pas encore relié à cette application.',
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const SectionTitle(title: 'Derniers événements'),
                const SectionCard(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Column(
                    children: [
                      _LogTile(time: '14:20', msg: 'Système Sentinelle activé', color: AppColors.info),
                      Divider(height: 1),
                      _LogTile(time: '12:05', msg: 'Mise à jour des modèles Edge AI', color: AppColors.success),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Une ligne du journal : heure, message, et une pastille de couleur en fin de
/// ligne. Le message est en `Expanded` pour se replier sur plusieurs lignes.
class _LogTile extends StatelessWidget {
  final String time;
  final String msg;
  final Color color;

  const _LogTile({required this.time, required this.msg, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Text(
            time,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(msg, style: AppTextStyles.body)),
          const SizedBox(width: 10),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }
}
