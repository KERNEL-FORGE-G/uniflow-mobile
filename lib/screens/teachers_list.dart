import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class TeachersListScreen extends ConsumerStatefulWidget {
  const TeachersListScreen({super.key});
  @override
  ConsumerState<TeachersListScreen> createState() => _TeachersListScreenState();
}

class _TeachersListScreenState extends ConsumerState<TeachersListScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        ref.read(teachersProvider.notifier).fetchNextPage();
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
    final asyncState = ref.watch(teachersProvider);
    final filteredList = ref.watch(filteredTeachersProvider);
    return Column(
      children: [
        GradientHeader(
          title: 'Enseignants',
          subtitle: asyncState.hasValue ? '${asyncState.value!.items.length} enseignants récupérés' : 'Chargement...',
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: SearchField(
              hint: 'Rechercher un enseignant...',
              onChanged: (v) => ref.read(teacherSearchProvider.notifier).state = v,
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
                  final t = filteredList[i];
                  return InkWell(
                    onTap: () => context.go('/enseignants/${t.id}'),
                    borderRadius: BorderRadius.circular(14),
                    child: SectionCard(
                      child: Row(
                        children: [
                          Avatar(initials: t.initials, color: AppColors.info),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text('${t.department} · ${t.ueIds.length} UE',
                                    style: const TextStyle(color: AppColors.textMutedLight, fontSize: 12)),
                              ],
                            ),
                          ),
                          StatusBadge(label: t.status),
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
