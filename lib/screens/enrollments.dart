import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class EnrollmentsScreen extends ConsumerStatefulWidget {
  const EnrollmentsScreen({super.key});
  @override
  ConsumerState<EnrollmentsScreen> createState() => _EnrollmentsScreenState();
}

class _EnrollmentsScreenState extends ConsumerState<EnrollmentsScreen> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(enrollmentsProvider);
    final pending = all.where((e) => e.status == 'En attente').toList();
    final current = all.where((e) => e.status != 'En attente').toList();
    final list = tab == 0 ? current : pending;

    return Column(
      children: [
        GradientHeader(
          title: 'Inscriptions',
          subtitle: '${all.length} inscriptions au total',
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(44),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  _tab('Semaine actuelle', 0),
                  _tab('Demandes (${pending.length})', 1),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('Aucune inscription', style: TextStyle(color: AppColors.textMuted)))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final e = list[i];
                    final s = ref.read(studentsProvider).firstWhere((x) => x.id == e.studentId);
                    final u = ref.read(uesProvider).firstWhere((x) => x.id == e.ueId);
                    return SectionCard(
                      child: Row(
                        children: [
                          Avatar(initials: s.initials),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text('${u.code} · ${u.title}',
                                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                              ],
                            ),
                          ),
                          StatusBadge(label: e.status),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _tab(String label, int i) {
    final active = tab == i;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => tab = i),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: TextStyle(
                  color: active ? AppColors.teal : Colors.white,
                  fontWeight: FontWeight.w600, fontSize: 12)),
        ),
      ),
    );
  }
}
