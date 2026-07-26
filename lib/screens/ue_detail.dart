import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class UEDetailScreen extends ConsumerWidget {
  final String id;
  const UEDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = findUE(ref, id);
    if (u == null) return const Center(child: Text('UE introuvable'));
    final c = Color(int.parse('FF${u.colorHex.substring(1)}', radix: 16));
    return Column(
      children: [
        GradientHeader(
          title: u.title,
          subtitle: '${u.code} · ${u.credits} crédits',
          trailing: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.go('/ues'),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Description', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(u.description, style: const TextStyle(color: AppColors.textMuted, height: 1.4)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Volume horaire', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _stat('CM', '${u.cm}h', c),
                        const SizedBox(width: 8),
                        _stat('TD', '${u.td}h', c),
                        const SizedBox(width: 8),
                        _stat('TP', '${u.tp}h', c),
                      ],
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

  Widget _stat(String label, String value, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
          child: Column(
            children: [
              Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        ),
      );
}
