import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class StudentsListScreen extends ConsumerStatefulWidget {
  const StudentsListScreen({super.key});
  @override
  ConsumerState<StudentsListScreen> createState() => _StudentsListScreenState();
}

class _StudentsListScreenState extends ConsumerState<StudentsListScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        ref.read(studentsProvider.notifier).fetchNextPage();
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
    final asyncState = ref.watch(studentsProvider);
    final filteredList = ref.watch(filteredStudentsProvider);
    
    return Column(
      children: [
        GradientHeader(
          title: 'Étudiants',
          subtitle: asyncState.hasValue ? '${asyncState.value!.items.length} étudiants récupérés' : 'Chargement...',
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: SearchField(
              hint: 'Rechercher un étudiant...',
              onChanged: (v) => ref.read(studentSearchProvider.notifier).state = v,
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
                  final s = filteredList[i];
                  return InkWell(
                    onTap: () => context.go('/etudiants/${s.id}'),
                    borderRadius: BorderRadius.circular(14),
                    child: SectionCard(
                      child: Row(
                        children: [
                          Avatar(initials: s.initials),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimaryLight)),
                                const SizedBox(height: 2),
                                Text('${s.matricule} · ${s.filiere} · ${s.niveau}',
                                    style: const TextStyle(color: AppColors.textMutedLight, fontSize: 12)),
                              ],
                            ),
                          ),
                          StatusBadge(label: s.status),
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
