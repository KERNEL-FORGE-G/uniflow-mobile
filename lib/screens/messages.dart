import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../repositories/messaging_repository.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsProvider);

    return Scaffold(
      body: Column(
        children: [
          const GradientHeader(
            title: 'Messagerie',
            subtitle: 'Discussions académiques et privées',
            trailing: _NotificationBell(),
          ),
          Expanded(
            child: conversationsAsync.when(
              data: (list) {
                if (list.isEmpty) {
                  return _EmptyInbox(
                    onStart: () => _startConversation(context, ref),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.refresh(conversationsProvider.future),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _ConversationTile(conversation: list[index]),
                  ),
                );
              },
              loading: () => const LoadingView(),
              error: (error, _) => _InboxError(
                error: error,
                onRetry: () => ref.invalidate(conversationsProvider),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _startConversation(context, ref),
        backgroundColor: AppColors.primaryBlue,
        tooltip: 'Nouvelle conversation',
        child: const Icon(Icons.chat, color: Colors.white),
      ),
    );
  }

  /// Ouvre le sélecteur de contact puis la conversation choisie.
  Future<void> _startConversation(BuildContext context, WidgetRef ref) async {
    final contact = await showModalBottomSheet<ChatContact>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NewConversationSheet(),
    );
    if (contact == null || !context.mounted) return;

    try {
      final conversation = await ref
          .read(messagingRepositoryProvider)
          .openByUsername(contact.username.isNotEmpty ? contact.username : contact.email);
      ref.invalidate(conversationsProvider);
      if (!context.mounted) return;
      context.push('/messages/${conversation.id}', extra: conversation);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }
}

/// Cloche de notifications, avec le nombre de messages urgents non lus.
///
/// Le compteur vient du flux temps réel : il s'incrémente à l'arrivée d'une
/// notification, sans que l'utilisateur ait à revenir sur l'écran.
class _NotificationBell extends ConsumerWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(urgentNotificationsProvider).valueOrNull ?? 0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: () => context.push('/notifications'),
          icon: const Icon(Icons.notifications_none, color: Colors.white),
          tooltip: 'Notifications',
        ),
        if (unread > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              constraints: const BoxConstraints(minWidth: 18),
              child: Text(
                unread > 99 ? '99+' : '$unread',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  const _ConversationTile({required this.conversation});

  static String _time(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return '';
    final local = parsed.toLocal();
    final now = DateTime.now();
    final sameDay = local.year == now.year && local.month == now.month && local.day == now.day;
    return sameDay ? DateFormat.Hm().format(local) : DateFormat('dd/MM').format(local);
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Avatar(
          initials: conversation.name.isNotEmpty ? conversation.name[0] : '?',
          avatarFileId: conversation.avatarFileId,
          size: 40,
        ),
        title: Text(conversation.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Le pseudo identifie le contact ; l'email ne sert que de repli
            // pour les comptes antérieurs au backfill.
            if (conversation.handle.isNotEmpty)
              Text(
                conversation.handle,
                style: const TextStyle(fontSize: 11, color: AppColors.teal),
                overflow: TextOverflow.ellipsis,
              ),
            Text(
              conversation.lastMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _time(conversation.time),
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
            if (conversation.unread > 0)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle),
                child: Text(
                  '${conversation.unread}',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        onTap: () => context.push(
          '/messages/${conversation.id}',
          extra: conversation,
        ),
      ),
    );
  }
}

class _EmptyInbox extends StatelessWidget {
  final VoidCallback onStart;
  const _EmptyInbox({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.forum_outlined, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 14),
            const Text(
              'Aucune conversation',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 6),
            const Text(
              'Cherchez un contact par son pseudo pour démarrer un échange.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.add_comment_outlined, size: 18),
              label: const Text('Nouvelle conversation'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InboxError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const _InboxError({required this.error, required this.onRetry});

  /// Texte principal : le message rédigé quand il y en a un, le texte brut sinon.
  String get _detail => error is MessagingException ? (error as MessagingException).message : error.toString();

  /// Code technique, affiché en petit.
  ///
  /// Il était auparavant absent : l'écran ne montrait qu'un « Bad state: No
  /// element » sans indiquer d'où il venait, et chaque panne de messagerie
  /// coûtait une session de diagnostic. Le type de l'exception et son code
  /// permettent de trancher entre un refus du serveur, une Function absente et
  /// une panne réseau, sans instrumenter quoi que ce soit.
  String get _code {
    if (error is MessagingException) {
      final code = (error as MessagingException).code;
      return code.isEmpty ? 'MESSAGING' : code;
    }
    return error.runtimeType.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48, color: AppColors.danger),
            const SizedBox(height: 14),
            const Text(
              'Messagerie indisponible',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              _detail,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.inputBorder),
              ),
              child: Text(
                _code,
                style: const TextStyle(
                  fontSize: 10,
                  letterSpacing: 0.6,
                  color: AppColors.textSecondary,
                ),
              ),
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

/// Sélecteur de contact : recherche par pseudo, nom ou email.
///
/// La recherche interroge l'action `search` de la fonction après une pause de
/// 300 ms, pour ne pas envoyer une requête à chaque caractère saisi.
class _NewConversationSheet extends ConsumerStatefulWidget {
  const _NewConversationSheet();

  @override
  ConsumerState<_NewConversationSheet> createState() => _NewConversationSheetState();
}

class _NewConversationSheetState extends ConsumerState<_NewConversationSheet> {
  final TextEditingController _input = TextEditingController();
  Timer? _debounce;

  List<ChatContact> _results = const [];
  bool _searching = false;
  String? _error;

  /// Numéro de la recherche en cours : une réponse arrivée après une frappe plus
  /// récente est ignorée, sinon les résultats affichés ne correspondent plus au
  /// texte du champ.
  int _requestId = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _input.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final term = value.trim().replaceFirst(RegExp(r'^@'), '');
    if (term.length < 2) {
      setState(() {
        _results = const [];
        _searching = false;
        _error = null;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(term));
  }

  Future<void> _search(String term) async {
    final id = ++_requestId;
    try {
      final contacts = await ref.read(messagingRepositoryProvider).searchContacts(term);
      if (!mounted || id != _requestId) return;
      setState(() {
        _results = contacts;
        _error = null;
        _searching = false;
      });
    } catch (error) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _results = const [];
        _error = error.toString();
        _searching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Nouvelle conversation',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Text(
              'Recherchez un contact par son pseudo.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _input,
              autofocus: true,
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: '@pseudo',
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 260,
              child: _buildResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.danger, fontSize: 12),
        ),
      );
    }
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_input.text.trim().replaceFirst(RegExp(r'^@'), '').length < 2) {
      return const Center(
        child: Text(
          'Saisissez au moins deux caractères.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      );
    }
    if (_results.isEmpty) {
      return const Center(
        child: Text(
          'Aucun contact ne correspond.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      );
    }
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final contact = _results[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Avatar(
            initials: contact.name.isNotEmpty ? contact.name[0] : '?',
            avatarFileId: contact.avatarFileId,
            size: 38,
          ),
          title: Text(contact.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          subtitle: Text(
            contact.username.isNotEmpty ? '@${contact.username}' : contact.email,
            style: const TextStyle(fontSize: 11, color: AppColors.teal),
          ),
          onTap: () => Navigator.of(context).pop(contact),
        );
      },
    );
  }
}
