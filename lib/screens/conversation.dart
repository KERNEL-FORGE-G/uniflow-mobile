import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../repositories/messaging_repository.dart';
import '../theme/app_theme.dart';
import '../utils/avatar.dart';
import '../widgets/common.dart';

/// Fil de discussion avec un contact.
///
/// L'écran reçoit la conversation déjà sérialisée par la liste, puis la
/// rafraîchit via l'action `list` : une seule requête ramène l'ensemble des fils
/// et leur contenu, sans action supplémentaire à ajouter côté fonction.
class ConversationScreen extends ConsumerStatefulWidget {
  final String conversationId;

  /// Conversation transmise par la liste, pour peindre l'écran immédiatement
  /// plutôt que d'attendre le réseau.
  final Conversation? initial;

  const ConversationScreen({super.key, required this.conversationId, this.initial});

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  Conversation? _conversation;
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _conversation = widget.initial;
    _loading = widget.initial == null;
    _load(markRead: true);
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool markRead = false}) async {
    try {
      final conversations =
          await ref.read(messagingRepositoryProvider).getConversations();
      final current = conversations
          .where((item) => item.id == widget.conversationId)
          .cast<Conversation?>()
          .firstOrNull;
      if (!mounted) return;
      setState(() {
        // Si la conversation a disparu de la liste (contact retiré de
        // l'annuaire), on garde celle qu'on affiche déjà au lieu de vider
        // l'écran sous les yeux de l'utilisateur.
        if (current != null) _conversation = current;
        _loading = false;
        _error = null;
      });
      if (markRead) {
        await ref.read(messagingRepositoryProvider).markRead(widget.conversationId);
      }
      _scrollToEnd();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      final updated = await ref
          .read(messagingRepositoryProvider)
          .sendMessage(widget.conversationId, text);
      if (!mounted) return;
      setState(() {
        _conversation = updated;
        _error = null;
      });
      _input.clear();
      _scrollToEnd();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final conversation = _conversation;
    final messages = conversation?.messages ?? const <ChatMessage>[];

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: Row(
          children: [
            Avatar(
              initials:
                  conversation == null ? '?' : initialsOf(conversation.name),
              avatarFileId: conversation?.avatarFileId,
              size: 34,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    conversation?.name ?? 'Conversation',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (conversation != null && conversation.handle.isNotEmpty)
                    Text(
                      conversation.handle,
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_error != null)
            Container(
              width: double.infinity,
              color: AppColors.danger.withValues(alpha: 0.12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                _error!,
                style: const TextStyle(fontSize: 12, color: AppColors.danger),
              ),
            ),
          Expanded(
            child: _loading && messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                    ? _EmptyThread(name: conversation?.name)
                    : RefreshIndicator(
                        onRefresh: () => _load(markRead: true),
                        child: ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          itemCount: messages.length,
                          itemBuilder: (context, index) =>
                              _Bubble(message: messages[index]),
                        ),
                      ),
          ),
          _Composer(
            controller: _input,
            sending: _sending,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _EmptyThread extends StatelessWidget {
  final String? name;
  const _EmptyThread({this.name});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.forum_outlined, size: 44, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(
              name == null
                  ? 'Aucun message pour l\'instant.'
                  : 'Aucun message avec $name pour l\'instant.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 4),
            const Text(
              'Écrivez le premier message ci-dessous.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  const _Bubble({required this.message});

  /// Heure d'envoi, ou chaîne vide si l'horodatage est illisible : mieux vaut
  /// une bulle sans heure qu'une exception au milieu du fil.
  String get _time {
    final parsed = DateTime.tryParse(message.time);
    if (parsed == null) return '';
    return DateFormat.Hm().format(parsed.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final mine = message.mine;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: mine ? AppColors.primaryBlue : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(mine ? 14 : 4),
            bottomRight: Radius.circular(mine ? 4 : 14),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: mine ? Colors.white : AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
            if (_time.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                _time,
                style: TextStyle(
                  fontSize: 10,
                  color: mine ? Colors.white70 : AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Votre message…',
                  filled: true,
                  fillColor: AppColors.bg,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 44,
              height: 44,
              child: Material(
                color: AppColors.teal,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: sending ? null : onSend,
                  child: Center(
                    child: sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send, color: Colors.white, size: 20),
                  ),
                ),
              ),
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
