import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../repositories/messaging_repository.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Centre de notifications : les messages urgents reçus, les plus récents en
/// premier.
///
/// Les notifications sont écrites par la Function `messaging` au moment de
/// l'envoi d'un message urgent, et non par le client : elles existent donc même
/// si le destinataire n'était pas connecté, et l'ouvrir les marque comme lues.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final unread = ref.watch(urgentNotificationsProvider).valueOrNull ?? 0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          GradientHeader(
            title: 'Notifications',
            subtitle: unread > 0
                ? '$unread non lue${unread > 1 ? 's' : ''}'
                : 'Tout est à jour',
            trailing: notificationsAsync.valueOrNull?.isNotEmpty == true
                ? TextButton(
                    onPressed: () => _markAllRead(context, ref),
                    child: const Text(
                      'Tout lire',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  )
                : null,
          ),
          Expanded(
            child: notificationsAsync.when(
              data: (list) {
                if (list.isEmpty) return const _EmptyNotifications();
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(notificationsProvider);
                    await ref.read(notificationsProvider.future);
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _NotificationTile(
                      notification: list[index],
                      onOpen: () => _open(context, ref, list[index]),
                    ),
                  ),
                );
              },
              loading: () => const LoadingView(),
              error: (error, _) => _NotificationsError(
                error: error,
                onRetry: () => ref.invalidate(notificationsProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Ouvre la conversation visée et marque la notification comme lue.
  ///
  /// La conversation peut avoir disparu (contact retiré de l'annuaire) : on
  /// marque alors la notification comme lue et on le dit, plutôt que d'ouvrir
  /// un écran vide.
  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    AppNotification notification,
  ) async {
    final conversationId = notification.conversationId;
    try {
      await ref
          .read(messagingRepositoryProvider)
          .markNotificationsRead(notificationId: notification.id);
    } catch (_) {
      // Un échec de marquage ne doit pas empêcher l'ouverture du fil.
    }
    ref.invalidate(notificationsProvider);
    if (!context.mounted) return;

    if (conversationId.isEmpty) return;
    try {
      final conversations =
          await ref.read(messagingRepositoryProvider).getConversations();
      final conversation = conversations
          .where((item) => item.id == conversationId)
          .cast<Conversation?>()
          .firstOrNull;
      if (!context.mounted) return;
      if (conversation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cette conversation n\'existe plus.')),
        );
        return;
      }
      context.push('/messages/$conversationId', extra: conversation);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _markAllRead(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(messagingRepositoryProvider).markNotificationsRead();
      ref.invalidate(notificationsProvider);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onOpen;

  const _NotificationTile({required this.notification, required this.onOpen});

  String get _time {
    final parsed = DateTime.tryParse(notification.time);
    if (parsed == null) return '';
    final local = parsed.toLocal();
    final now = DateTime.now();
    final sameDay =
        local.year == now.year && local.month == now.month && local.day == now.day;
    return sameDay ? DateFormat.Hm().format(local) : DateFormat('dd/MM HH:mm').format(local);
  }

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    return SectionCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.danger.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.priority_high, color: AppColors.danger, size: 20),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: unread ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
            if (_time.isNotEmpty)
              Text(
                _time,
                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
          ],
        ),
        trailing: unread
            ? Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                    color: AppColors.teal, shape: BoxShape.circle),
              )
            : null,
        onTap: onOpen,
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none, size: 48, color: AppColors.textSecondary),
            SizedBox(height: 14),
            Text(
              'Aucune notification',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            SizedBox(height: 6),
            Text(
              'Les messages signalés comme urgents par vos contacts '
              'apparaîtront ici.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _NotificationsError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48, color: AppColors.danger),
            const SizedBox(height: 14),
            const Text(
              'Notifications indisponibles',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
