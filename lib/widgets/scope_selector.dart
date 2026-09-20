import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../repositories/reference_repository.dart';
import '../theme/app_theme.dart';

/// Sélecteur filière → niveau pour les comptes dont le périmètre n'est pas
/// fixé par le profil : administration d'université (toutes les filières de
/// sa faculté), administrateur de la plateforme (toutes), enseignant sans
/// filière renseignée.
///
/// Les filières viennent d'`academic_programs`, les niveaux de
/// `program.levels` (« L1,L2,L3,M1 ») : rien n'est codé en dur. Invisible pour
/// un étudiant, dont filière et niveau sont ceux du profil.
class ScopeSelector extends ConsumerWidget {
  /// Le niveau est facultatif (vue « toute la filière ») quand vrai.
  final bool levelOptional;

  const ScopeSelector({super.key, this.levelOptional = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(academicScopeProvider);
    if (!scope.selectable) return const SizedBox.shrink();
    final programs = ref.watch(selectableProgramsProvider);
    final selection = ref.watch(scopeSelectionProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: programs.when(
        loading: () => const LinearProgressIndicator(minHeight: 2),
        error: (error, _) => Text('Filières indisponibles : $error', style: AppTextStyles.bodySmall),
        data: (list) {
          if (list.isEmpty) {
            return const Text('Aucune filière n\'est encore enregistrée.', style: AppTextStyles.bodySmall);
          }
          final current = list.where((p) => p.code == selection?.program).firstOrNull;
          final levels = current?.levels ?? const <String>[];
          return Row(
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  key: const ValueKey('scope-program'),
                  initialValue: current?.code,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'Filière', isDense: true, prefixIcon: Icon(Icons.school_outlined, size: 18)),
                  items: [
                    for (final p in list)
                      DropdownMenuItem(
                        value: p.code,
                        child: Text('${p.code} · ${p.name}', maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (code) {
                    if (code == null) return;
                    final program = list.firstWhere((p) => p.code == code);
                    // Un seul niveau ouvert : on le choisit d'office, sinon
                    // l'utilisateur doit toucher deux fois pour voir quelque chose.
                    final level = program.levels.length == 1 ? program.levels.first : '';
                    ref.read(scopeSelectionProvider.notifier).state = ScopeSelection(program: code, level: level);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  key: ValueKey('scope-level-${current?.code}'),
                  initialValue: levels.contains(selection?.level) ? selection!.level : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Niveau', isDense: true),
                  items: [
                    if (levelOptional) const DropdownMenuItem(value: '', child: Text('Tous')),
                    for (final l in levels) DropdownMenuItem(value: l, child: Text(l)),
                  ],
                  onChanged: current == null
                      ? null
                      : (level) => ref.read(scopeSelectionProvider.notifier).state =
                          ScopeSelection(program: current.code, level: level ?? ''),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
