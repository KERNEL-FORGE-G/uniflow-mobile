import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class UEsListScreen extends ConsumerWidget {
  const UEsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(filteredUEsProvider);
    return Column(
      children: [
        GradientHeader(
          title: "Unités d'enseignement",
          subtitle: '${list.length} UEs',
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: SearchField(
              hint: 'Rechercher une UE...',
              onChanged: (v) => ref.read(ueSearchProvider.notifier).state = v,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final u = list[i];
              final c = Color(int.parse('FF${u.colorHex.substring(1)}', radix: 16));
              return InkWell(
                onTap: () => context.go('/ues/${u.id}'),
                borderRadius: BorderRadius.circular(14),
                child: SectionCard(
                  child: Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                        alignment: Alignment.center,
                        child: Text(u.code.substring(0, 3),
                            style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(u.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text('${u.code} · ${u.credits} crédits',
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.textMuted),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
