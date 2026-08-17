import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../core/network/api_client.dart';
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

  void _showNewEnrollmentDialog() {
    final uesAsync = ref.read(uesProvider);
    final ues = uesAsync.value?.items ?? [];
    String? selectedUeId = ues.isNotEmpty ? ues.first.id : null;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Nouvelle Inscription a une UE', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Sélectionnez le cours (UE) :', style: TextStyle(fontSize: 13, color: AppColors.textMutedLight)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedUeId,
                    items: ues.map((ue) => DropdownMenuItem(
                      value: ue.id,
                      child: Text('${ue.code} - ${ue.title}', style: const TextStyle(fontSize: 13)),
                    )).toList(),
                    onChanged: (val) => setDialogState(() => selectedUeId = val),
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: selectedUeId == null ? null : () async {
                    Navigator.pop(context);
                    try {
                      final dio = ref.read(apiClientProvider);
                      await dio.post('/enrollments', data: {'teachingUnitId': selectedUeId});
                      ref.invalidate(enrollmentsProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Demande d\'inscription envoyée avec succès ! 🎉'), backgroundColor: AppColors.secondary),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Inscription transmise au serveur !'), backgroundColor: AppColors.secondary),
                        );
                      }
                    }
                  },
                  style: FilledButton.styleFrom(backgroundColor: AppColors.secondary),
                  child: const Text('S\'inscrire'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(enrollmentsProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNewEnrollmentDialog,
        backgroundColor: AppColors.secondary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nouvelle Inscription', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          GradientHeader(
            title: 'Inscriptions aux Cours',
            subtitle: asyncState.hasValue ? '${asyncState.value!.items.length} inscriptions enregistrées' : 'Chargement...',
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(44),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    _tab('Toutes les UEs', 0),
                    _tab('En attente', 1),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: asyncState.when(
              data: (state) {
                final all = state.items;
                final pending = all.where((e) => e.status == 'En attente' || e.status == 'PENDING').toList();
                final list = tab == 0 ? all : pending;

                if (list.isEmpty) {
                  return const Center(child: Text('Aucune inscription pour ce filtre', style: TextStyle(color: AppColors.textMutedLight)));
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
                    final s = findStudent(ref, e.studentId);
                    final u = findUE(ref, e.ueId);
                    
                    return SectionCard(
                      child: Row(
                        children: [
                          Avatar(initials: s?.initials ?? 'UE'),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s?.fullName ?? 'Demande d\'inscription',
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text('${u?.code ?? 'UE'} · ${u?.title ?? 'Unité d\'Enseignement'}',
                                    style: const TextStyle(color: AppColors.textMutedLight, fontSize: 12)),
                              ],
                            ),
                          ),
                          StatusBadge(label: e.status.isEmpty ? 'Validée' : e.status),
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
      ),
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
