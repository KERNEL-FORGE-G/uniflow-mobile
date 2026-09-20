import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import 'offline_providers.dart';
import 'sync_engine.dart';

/// « HH:MM » (aujourd'hui) ou « le 12/09 à HH:MM » (autre jour). Pure, testée.
String describeLastSync(DateTime? at, {DateTime? now}) {
  if (at == null) return 'jamais synchronisé';
  final ref = now ?? DateTime.now();
  final local = at.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  final hm = '${two(local.hour)}:${two(local.minute)}';
  final sameDay = local.year == ref.year && local.month == ref.month && local.day == ref.day;
  if (sameDay) return 'dernière synchronisation à $hm';
  return 'dernière synchronisation le ${two(local.day)}/${two(local.month)} à $hm';
}

/// Libellé court de l'indicateur d'état. Pure, testée.
String describeSyncState(SyncState state) {
  if (state.isSyncing) return 'Synchronisation…';
  if (state.isOffline) {
    return state.pendingCount > 0 ? 'Hors ligne · ${state.pendingCount} en attente' : 'Hors ligne';
  }
  if (state.pendingCount > 0) return '${state.pendingCount} en attente d\'envoi';
  return 'Synchronisé';
}

/// Bandeau sous l'en-tête : hors ligne, ou éléments en attente d'envoi.
/// Invisible quand tout est synchronisé, et tolérant à l'absence de base
/// locale (tests, première ouverture).
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(syncStateProvider).asData?.value;
    if (state == null) return const SizedBox.shrink();

    Widget? child;
    if (state.isOffline) {
      child = _Bar(
        key: const ValueKey('offline'),
        color: AppColors.warning,
        icon: Icons.cloud_off_rounded,
        text: 'Mode hors ligne — ${describeLastSync(state.lastSyncAt)}'
            '${state.pendingCount > 0 ? ' · ${state.pendingCount} en attente d\'envoi' : ''}',
      );
    } else if (state.isSyncing) {
      child = const LinearProgressIndicator(key: ValueKey('syncing'), minHeight: 3, color: AppColors.teal);
    } else if (state.pendingCount > 0) {
      child = _Bar(
        key: const ValueKey('pending'),
        color: AppColors.info,
        icon: Icons.schedule_send_rounded,
        text: '${state.pendingCount} élément${state.pendingCount > 1 ? 's' : ''} en attente d\'envoi',
        action: TextButton(
          onPressed: () => ref.read(syncCoordinatorProvider).syncNow(force: true),
          child: const Text('Envoyer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      );
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;
  final Widget? action;
  const _Bar({super.key, required this.color, required this.icon, required this.text, this.action});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
              if (action != null) action!,
            ],
          ),
        ),
      ),
    );
  }
}

/// Pastille d'état pour les en-têtes : un toucher lance la synchronisation.
class SyncIndicator extends ConsumerWidget {
  const SyncIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(syncStateProvider).asData?.value ?? const SyncState();
    final IconData icon;
    final Color color;
    if (state.isSyncing) {
      icon = Icons.sync_rounded;
      color = Colors.white;
    } else if (state.isOffline) {
      icon = Icons.cloud_off_rounded;
      color = AppColors.warning;
    } else if (state.pendingCount > 0) {
      icon = Icons.schedule_send_rounded;
      color = Colors.white;
    } else {
      icon = Icons.cloud_done_rounded;
      color = Colors.white70;
    }
    return Tooltip(
      message: describeSyncState(state),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: state.isSyncing ? null : () => ref.read(syncCoordinatorProvider).syncNow(force: true),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              state.isSyncing
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(icon, color: color, size: 20),
              if (state.pendingCount > 0)
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: AppColors.warning, borderRadius: BorderRadius.circular(999)),
                    child: Text(
                      '${state.pendingCount > 99 ? '99+' : state.pendingCount}',
                      style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
