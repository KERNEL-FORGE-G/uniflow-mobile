import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class UEsListScreen extends ConsumerStatefulWidget {
  const UEsListScreen({super.key});
  @override
  ConsumerState<UEsListScreen> createState() => _UEsListScreenState();
}

class _UEsListScreenState extends ConsumerState<UEsListScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        ref.read(uesProvider.notifier).fetchNextPage();
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
    final asyncState = ref.watch(uesProvider);
    final filteredList = ref.watch(filteredUEsProvider);
    return Column(
      children: [
        GradientHeader(
          title: "Unités d'enseignement",
          subtitle: asyncState.hasValue ? '${asyncState.value!.items.length} UEs récupérées' : 'Chargement...',
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: SearchField(
              hint: 'Rechercher une UE...',
              onChanged: (v) => ref.read(ueSearchProvider.notifier).state = v,
            ),
          ),
        ),
        Expanded(
          child: asyncState.when(
            data: (state) {
              return ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: filteredList.length + (state.isLoadingMore ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  if (i == filteredList.length) {
                    return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()));
                  }
                  final u = filteredList[i];
                  final c = Color(int.parse('FF${u.colorHex.substring(1)}', radix: 16));
                  return InkWell(
                    onTap: () => context.go('/ues/${u.id}'),
                    borderRadius: BorderRadius.circular(14),
                    child: SectionCard(
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                                color: c.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10)),
                            alignment: Alignment.center,
                            child: Text(u.code.substring(0, 3),
                                style: TextStyle(
                                    color: c,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(u.title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text('${u.code} · ${u.credits} crédits',
                                    style: const TextStyle(
                                        color: AppColors.textMutedLight, fontSize: 12)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right,
                              color: AppColors.textMutedLight),
                        ],
                      ),
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
}
