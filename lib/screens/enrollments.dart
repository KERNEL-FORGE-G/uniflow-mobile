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
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        ref.read(enrollmentsProvider.notifier).fetchNextPage();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(enrollmentsProvider);

    return Column(
      children: [
        GradientHeader(
          title: 'Inscriptions',
          subtitle: asyncState.hasValue ? '${asyncState.value!.items.length} inscriptions' : 'Chargement...',
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(44),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  _tab('Semaine actuelle', 0),
                  _tab('Demandes', 1),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: asyncState.when(
            data: (state) {
              final all = state.items;
              final pending = all.where((e) => e.status == 'En attente').toList();
              final current = all.where((e) => e.status != 'En attente').toList();
              final list = tab == 0 ? current : pending;

              if (list.isEmpty) {
                return const Center(child: Text('Aucune inscription', style: TextStyle(color: AppColors.textMutedLight)));
              }

              return ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: list.length + (state.isLoadingMore ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  if (i == list.length) {
                    return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()));
                  }
                  final e = list[i];
                  // Might be null if paginated students/ues are not fully loaded
                  final s = findStudent(ref, e.studentId);
                  final u = findUE(ref, e.ueId);
                  
                  return SectionCard(
                    child: Row(
                      children: [
                        Avatar(initials: s?.initials ?? '?'),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s?.fullName ?? 'Étudiant inconnu',
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text('${u?.code ?? ''} · ${u?.title ?? 'UE inconnue'}',
                                  style: const TextStyle(color: AppColors.textMutedLight, fontSize: 12)),
                            ],
                          ),
                        ),
                        StatusBadge(label: e.status),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Erreur: $err')),
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
                  color: active ? AppColors.secondary : Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12)),
        ),
      ),
    );
  }
}
