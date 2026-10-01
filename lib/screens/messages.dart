import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../repositories/messaging_repository.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/phosphor.dart';

class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _MessagingHeader(ref: ref),
          Expanded(
            child: conversationsAsync.when(
              data: (list) {
                if (list.isEmpty) {
                  return _EmptyInbox(
                    onStart: () => _startConversation(context, ref),
                  );
                }
                return RefreshIndicator(
                  color: AppColors.primaryLight,
                  backgroundColor: AppColors.surfaceElevated,
                  onRefresh: () => ref.refresh(conversationsProvider.future),
                  child: ListView.builder(
                    padding: AppInsets.pageList,
                    itemCount: list.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ConversationTile(conversation: list[index]),
                    ),
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
      floatingActionButton: _NewConversationFab(
        onPressed: () => _startConversation(context, ref),
      ),
    );
  }

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
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }
}

// ─────────────────────────────────────────────
// Header glassmorphism avec recherche et cloche
// ─────────────────────────────────────────────

class _MessagingHeader extends ConsumerWidget {
  final WidgetRef ref;
  const _MessagingHeader({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef referenceToRef) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF152A66), Color(0xFF1E3A8A), Color(0xFF0D4F6E)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Messagerie',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Discussions académiques',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _NotificationBell(),
                ],
              ),
              const SizedBox(height: 14),
              // Search bar glassmorphism
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: const TextField(
                      decoration: InputDecoration(
                        hintText: 'Rechercher une conversation…',
                        hintStyle: TextStyle(color: Colors.white60, fontSize: 14),
                        prefixIcon: Icon(Icons.search_rounded, color: Colors.white60, size: 20),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      style: TextStyle(color: Colors.white),
                    ),
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

// ─────────────────────────────────────────────
// Cloche de notifications
// ─────────────────────────────────────────────

class _NotificationBell extends ConsumerWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(urgentNotificationsProvider).valueOrNull ?? 0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            onPressed: () => context.push('/notifications'),
            icon: const PhosphorIcon(
              PhosphorIconsBold.bellRinging,
              color: Colors.white,
              size: 22,
            ),
            tooltip: 'Notifications',
          ),
        ),
        if (unread > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEF4444), Color(0xFFF97316)],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.background,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                    blurRadius: 6,
                  ),
                ],
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

// ─────────────────────────────────────────────
// Tuile de conversation dark glassmorphism
// ─────────────────────────────────────────────

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  const _ConversationTile({required this.conversation});

  static String _time(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return '';
    final local = parsed.toLocal();
    final now = DateTime.now();
    final sameDay = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    return sameDay
        ? DateFormat.Hm().format(local)
        : DateFormat('dd/MM').format(local);
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = conversation.unread > 0;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push(
          '/messages/${conversation.id}',
          extra: conversation,
        ),
        child: Ink(
          decoration: BoxDecoration(
            color: hasUnread
                ? AppColors.primary50.withValues(alpha: 0.8)
                : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: hasUnread
                  ? AppColors.primaryLight.withValues(alpha: 0.3)
                  : AppColors.glassBorder,
            ),
            boxShadow: hasUnread
                ? [
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Avatar avec indicateur online
                _ConversationAvatar(
                  name: conversation.name,
                  avatarFileId: conversation.avatarFileId,
                ),
                const SizedBox(width: 12),
                // Contenu
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conversation.name,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: hasUnread
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                fontSize: 14.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _time(conversation.time),
                            style: TextStyle(
                              fontSize: 11,
                              color: hasUnread
                                  ? AppColors.primaryLight
                                  : AppColors.textMuted,
                              fontWeight: hasUnread
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (conversation.handle.isNotEmpty)
                        Text(
                          conversation.handle,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.tealLight,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conversation.lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: hasUnread
                                    ? AppColors.textSecondary
                                    : AppColors.textMuted,
                                fontWeight: hasUnread
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (hasUnread)
                            _UnreadBadge(count: conversation.unread),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConversationAvatar extends StatelessWidget {
  final String name;
  final String? avatarFileId;
  const _ConversationAvatar({required this.name, this.avatarFileId});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _avatarColor(name).withValues(alpha: 0.8),
                _avatarColor(name),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: _avatarColor(name).withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
        // Indicateur online
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.background,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _avatarColor(String name) {
    final colors = [
      AppColors.primaryLight,
      AppColors.teal,
      AppColors.purple,
      AppColors.tealLight,
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
    ];
    if (name.isEmpty) return colors[0];
    return colors[name.codeUnitAt(0) % colors.length];
  }
}

class _UnreadBadge extends StatelessWidget {
  final int count;
  const _UnreadBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryLight, AppColors.tealLight],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryLight.withValues(alpha: 0.4),
            blurRadius: 6,
          ),
        ],
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// État vide
// ─────────────────────────────────────────────

class _EmptyInbox extends StatelessWidget {
  final VoidCallback onStart;
  const _EmptyInbox({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary50,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: const Center(
                child: PhosphorIcon(
                  PhosphorIconsDuotone.chatsCircle,
                  size: 40,
                  color: AppColors.primaryLight,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Aucune conversation',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Cherchez un contact par son pseudo\npour démarrer un échange.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onStart,
              icon: const PhosphorIcon(
                PhosphorIconsFill.plusCircle,
                size: 18,
                color: Colors.white,
              ),
              label: const Text('Nouvelle conversation'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryLight,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
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

  @override
  Widget build(BuildContext context) {
    return LoadErrorView(
      title: 'Messagerie indisponible',
      error: error,
      onRetry: onRetry,
    );
  }
}

// ─────────────────────────────────────────────
// FAB nouvelle conversation
// ─────────────────────────────────────────────

class _NewConversationFab extends StatelessWidget {
  final VoidCallback onPressed;
  const _NewConversationFab({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [AppColors.primaryLight, AppColors.tealLight],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryLight.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: onPressed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        highlightElevation: 0,
        icon: const PhosphorIcon(
          PhosphorIconsFill.chatsCircle,
          color: Colors.white,
          size: 20,
        ),
        label: const Text(
          'Nouveau',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        tooltip: 'Nouvelle conversation',
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Feuille de nouvelle conversation
// ─────────────────────────────────────────────

class _NewConversationSheet extends ConsumerStatefulWidget {
  const _NewConversationSheet();

  @override
  ConsumerState<_NewConversationSheet> createState() =>
      _NewConversationSheetState();
}

class _NewConversationSheetState
    extends ConsumerState<_NewConversationSheet> {
  final TextEditingController _input = TextEditingController();
  Timer? _debounce;

  List<ChatContact> _results = const [];
  bool _searching = false;
  String? _error;
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
    _debounce =
        Timer(const Duration(milliseconds: 300), () => _search(term));
  }

  Future<void> _search(String term) async {
    final id = ++_requestId;
    try {
      final contacts =
          await ref.read(messagingRepositoryProvider).searchContacts(term);
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
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Nouvelle conversation',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Recherchez un contact par son pseudo.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.inputBorder),
              ),
              child: TextField(
                controller: _input,
                autofocus: true,
                onChanged: _onChanged,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: '@pseudo',
                  hintStyle: TextStyle(color: AppColors.textMuted),
                  prefixIcon: PhosphorIcon(
                    PhosphorIconsBold.magnifyingGlass,
                    color: AppColors.textSecondary,
                    size: 18,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
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
          style: const TextStyle(
            color: AppColors.danger,
            fontSize: 13,
          ),
        ),
      );
    }
    if (_searching) {
      return const LoadingView(label: 'Recherche…');
    }
    if (_input.text.trim().replaceFirst(RegExp(r'^@'), '').length < 2) {
      return const Center(
        child: Text(
          'Saisissez au moins deux caractères.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      );
    }
    if (_results.isEmpty) {
      return const Center(
        child: Text(
          'Aucun contact ne correspond.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      );
    }
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, __) => Divider(
        color: AppColors.divider,
        height: 1,
      ),
      itemBuilder: (context, index) {
        final contact = _results[index];
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(vertical: 4),
          leading: _ContactAvatar(
            name: contact.name,
            avatarFileId: contact.avatarFileId,
          ),
          title: Text(
            contact.name,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            contact.username.isNotEmpty
                ? '@${contact.username}'
                : contact.email,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.tealLight,
            ),
          ),
          onTap: () => Navigator.of(context).pop(contact),
        );
      },
    );
  }
}

class _ContactAvatar extends StatelessWidget {
  final String name;
  final String? avatarFileId;
  const _ContactAvatar({required this.name, this.avatarFileId});

  Color _color(String name) {
    final colors = [
      AppColors.primaryLight,
      AppColors.teal,
      AppColors.purple,
      AppColors.tealLight,
    ];
    if (name.isEmpty) return colors[0];
    return colors[name.codeUnitAt(0) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _color(name).withValues(alpha: 0.2),
        border: Border.all(
          color: _color(name).withValues(alpha: 0.4),
        ),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            color: _color(name),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
