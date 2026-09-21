import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/uni/archlord_mascot.dart';
import 'local_database.dart';
import 'offline_providers.dart';
import 'offline_widgets.dart';
import 'outbox.dart';
import 'sync_engine.dart';

/// Bloc « Hors ligne et synchronisation » des Réglages : état, dernière
/// synchronisation, bouton « Synchroniser maintenant », Wi-Fi seulement,
/// quota des fichiers, et les écritures en conflit ou refusées à revoir.
class OfflineSettingsSection extends ConsumerStatefulWidget {
  const OfflineSettingsSection({super.key});

  @override
  ConsumerState<OfflineSettingsSection> createState() => _OfflineSettingsSectionState();
}

class _OfflineSettingsSectionState extends ConsumerState<OfflineSettingsSection> {
  bool _syncing = false;
  String? _lastMessage;

  Future<void> _syncNow() async {
    setState(() {
      _syncing = true;
      _lastMessage = null;
    });
    try {
      final report = await ref.read(syncCoordinatorProvider).syncNow(force: true);
      if (!mounted) return;
      setState(() => _lastMessage = report?.describe() ?? 'Aucun compte connecté');
    } catch (error) {
      if (!mounted) return;
      setState(() => _lastMessage = 'Synchronisation impossible : $error');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(syncStateProvider).asData?.value ?? const SyncState();
    final prefs = ref.watch(offlinePreferencesProvider);
    final owner = ref.watch(currentUserProvider)?.id ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.cloud_sync_outlined, color: AppColors.primaryBlue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Hors ligne et synchronisation', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    '${describeSyncState(state)} · ${describeLastSync(state.lastSyncAt)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Le fondateur explique le point que les utilisateurs comprennent le
        // moins bien : l'application ne « perd » rien sans réseau. `still` :
        // dans une page de réglages, une figure qui respire en boucle attire
        // l'œil pour rien — et les tests de cet écran attendent que tout se
        // stabilise (`pumpAndSettle`).
        const ArchlordMascot(
          pose: ArchlordPose.explain,
          size: 72,
          still: true,
          bubble: Text('Tes données restent sur le téléphone, même un mois sans réseau.'),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const ValueKey('sync-now'),
            onPressed: _syncing || state.isSyncing ? null : _syncNow,
            icon: _syncing || state.isSyncing
                ? const SizedBox(
                    width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.sync_rounded, size: 18),
            label: const Text('Synchroniser maintenant'),
          ),
        ),
        if (_lastMessage != null || state.lastReport != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _lastMessage ?? state.lastReport!,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: prefs.wifiOnly,
          onChanged: (v) => ref.read(offlinePreferencesProvider.notifier).setWifiOnly(v),
          title: const Text('Wi-Fi seulement'),
          subtitle: const Text(
            'La synchronisation automatique attend le Wi-Fi ; « Synchroniser maintenant » passe outre.',
            style: TextStyle(fontSize: 12),
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.folder_open_outlined, color: AppColors.primaryBlue),
          title: const Text('Fichiers gardés hors ligne'),
          subtitle: Text('Quota ${prefs.fileQuotaMb} Mo · les documents ouverts une fois restent lisibles',
              style: const TextStyle(fontSize: 12)),
          trailing: DropdownButton<int>(
            value: const [100, 200, 500, 1000].contains(prefs.fileQuotaMb) ? prefs.fileQuotaMb : 200,
            underline: const SizedBox.shrink(),
            items: const [100, 200, 500, 1000]
                .map((mb) => DropdownMenuItem(value: mb, child: Text(mb >= 1000 ? '${mb ~/ 1000} Go' : '$mb Mo')))
                .toList(),
            onChanged: (v) => v == null ? null : ref.read(offlinePreferencesProvider.notifier).setFileQuotaMb(v),
          ),
        ),
        if (owner.isNotEmpty) _OutboxReview(owner: owner),
      ],
    );
  }
}

/// Écritures refusées ou en conflit : l'utilisateur réessaie ou abandonne.
class _OutboxReview extends ConsumerWidget {
  final String owner;
  const _OutboxReview({required this.owner});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Relu à chaque changement d'état de synchronisation.
    ref.watch(syncStateProvider);
    final outbox = ref.read(outboxProvider);
    return FutureBuilder<List<OutboxRow>>(
      future: outbox.entries(owner).catchError((_) => <OutboxRow>[]),
      builder: (context, snapshot) {
        final rows = (snapshot.data ?? const <OutboxRow>[])
            .where((r) => r.status == OutboxStatus.conflict || r.status == OutboxStatus.failed)
            .toList();
        if (rows.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 8, bottom: 4),
              child: Text('À revoir', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.warning)),
            ),
            for (final row in rows)
              ListTile(
                key: ValueKey('outbox-${row.clientId}'),
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(
                  row.status == OutboxStatus.conflict ? Icons.call_split_rounded : Icons.block_rounded,
                  color: AppColors.warning,
                ),
                title: Text(row.label.isEmpty ? row.kind : row.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(row.lastError ?? '',
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Réessayer',
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      onPressed: () async {
                        await outbox.retryNow(row.clientId);
                        await ref.read(syncCoordinatorProvider).syncNow(force: true);
                      },
                    ),
                    IconButton(
                      tooltip: 'Abandonner',
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      onPressed: () async {
                        await outbox.discard(row.clientId);
                        await ref.read(syncEngineProvider).refreshPending(owner);
                      },
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
