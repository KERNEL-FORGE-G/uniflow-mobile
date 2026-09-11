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
          const GradientHeader(title: 'Sentinelle IoT', subtitle: 'Surveillance et Santé Connectée'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SectionCard(
                  child: Column(
                    children: [
                      const Icon(Icons.monitor_heart_outlined, size: 48, color: AppColors.danger),
                      const SizedBox(height: 12),
                      const Text('Kiosque Santé Virtuel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const Text('Prêt pour le pré-diagnostic', style: TextStyle(color: AppColors.textMuted)),
                      const SizedBox(height: 20),
                      ElevatedButton(onPressed: () {}, child: const Text('Lancer un scan local')),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text('DERNIERS ÉVÉNEMENTS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                const SizedBox(height: 8),
                const SectionCard(
                  child: Column(
                    children: [
                      _LogTile(time: '14:20', msg: 'Système Sentinelle activé', color: Colors.blue),
                      Divider(),
                      _LogTile(time: '12:05', msg: 'Mise à jour des modèles Edge AI', color: Colors.green),
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

class _LogTile extends StatelessWidget {
  final String time, msg; final Color color;
  const _LogTile({required this.time, required this.msg, required this.color});
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [Text(time, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(width: 12), Expanded(child: Text(msg)), Icon(Icons.circle, size: 8, color: color)]));
}
