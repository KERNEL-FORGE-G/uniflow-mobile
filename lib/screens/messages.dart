import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/appwrite_provider.dart';
import '../providers/providers.dart';
import '../repositories/messaging_repository.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/phosphor.dart';
import '../widgets/uni/uni_mascot.dart';


// ─────────────────────────────────────────────────────────────────────────────
//  ÉCRAN PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  bool _searchOpen = false;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _startConversation() async {
    final contact = await showModalBottomSheet<ChatContact>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NewConversationSheet(),
    );
    if (contact == null || !mounted) return;
    try {
      final conv = await ref
          .read(messagingRepositoryProvider)
          .openByUsername(
              contact.username.isNotEmpty ? contact.username : contact.email);
      ref.invalidate(conversationsProvider);
      if (!mounted) return;
      context.push('/messages/${conv.id}', extra: conv);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString()),
        backgroundColor: AppColors.danger,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _WhatsAppHeader(
            tab: _tab,
            searchOpen: _searchOpen,
            searchCtrl: _searchCtrl,
            onToggleSearch: () => setState(() {
              _searchOpen = !_searchOpen;
              if (!_searchOpen) _searchCtrl.clear();
            }),
            onNewConversation: _startConversation,
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _ConversationsTab(
                  searchQuery: _searchCtrl.text,
                  onNewConversation: _startConversation,
                ),
                const _ActualitesTab(),
                const _StatutsTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _tab.index == 0
          ? _GradientFab(onPressed: _startConversation)
          : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  HEADER STYLE WHATSAPP
// ─────────────────────────────────────────────────────────────────────────────

class _WhatsAppHeader extends ConsumerStatefulWidget {
  final TabController tab;
  final bool searchOpen;
  final TextEditingController searchCtrl;
  final VoidCallback onToggleSearch;
  final VoidCallback onNewConversation;

  const _WhatsAppHeader({
    required this.tab,
    required this.searchOpen,
    required this.searchCtrl,
    required this.onToggleSearch,
    required this.onNewConversation,
  });

  @override
  ConsumerState<_WhatsAppHeader> createState() => _WhatsAppHeaderState();
}

class _WhatsAppHeaderState extends ConsumerState<_WhatsAppHeader> {
  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(urgentNotificationsProvider).valueOrNull ?? 0;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A8A), Color(0xFF0D9488)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Barre du haut
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: widget.searchOpen
                    ? _SearchBar(ctrl: widget.searchCtrl, onClose: widget.onToggleSearch)
                    : _TitleBar(
                        unread: unread,
                        onSearch: widget.onToggleSearch,
                        onNew: widget.onNewConversation,
                      ),
              ),
            ),
            const SizedBox(height: 6),
            // TabBar
            TabBar(
              controller: widget.tab,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              tabs: const [
                Tab(text: 'Messages'),
                Tab(text: 'Actualités'),
                Tab(text: 'Statuts'),
              ],
              onTap: (_) => setState(() {}),
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleBar extends StatelessWidget {
  final int unread;
  final VoidCallback onSearch;
  final VoidCallback onNew;

  const _TitleBar({
    required this.unread,
    required this.onSearch,
    required this.onNew,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'UniFlow',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Cloche notifications
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: () => context.push('/notifications'),
              icon: const PhosphorIcon(
                PhosphorIconsBold.bellRinging,
                color: Colors.white,
                size: 22,
              ),
            ),
            if (unread > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        IconButton(
          onPressed: onSearch,
          icon: const PhosphorIcon(
            PhosphorIconsBold.magnifyingGlass,
            color: Colors.white,
            size: 22,
          ),
        ),
        _MoreMenu(),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController ctrl;
  final VoidCallback onClose;
  const _SearchBar({required this.ctrl, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onClose,
          icon: const PhosphorIcon(PhosphorIconsBold.arrowLeft,
              color: Colors.white, size: 22),
        ),
        Expanded(
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: TextField(
              controller: ctrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: const InputDecoration(
                hintText: 'Rechercher…',
                hintStyle: TextStyle(color: Colors.white60),
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MoreMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const PhosphorIcon(PhosphorIconsBold.squaresFour,
          color: Colors.white, size: 22),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'archive',
          child: Row(children: const [
            PhosphorIcon(PhosphorIconsBold.tray, size: 16, color: AppColors.textSecondary),
            SizedBox(width: 10),
            Text('Archives', style: TextStyle(color: AppColors.textPrimary)),
          ]),
        ),
        PopupMenuItem(
          value: 'starred',
          child: Row(children: const [
            PhosphorIcon(PhosphorIconsBold.star, size: 16, color: AppColors.textSecondary),
            SizedBox(width: 10),
            Text('Messages étoilés', style: TextStyle(color: AppColors.textPrimary)),
          ]),
        ),
        PopupMenuItem(
          value: 'settings',
          child: Row(children: const [
            PhosphorIcon(PhosphorIconsBold.gearSix, size: 16, color: AppColors.textSecondary),
            SizedBox(width: 10),
            Text('Paramètres', style: TextStyle(color: AppColors.textPrimary)),
          ]),
        ),
      ],
      onSelected: (v) {
        if (v == 'settings') context.push('/settings');
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ONGLET 1 : CONVERSATIONS
// ─────────────────────────────────────────────────────────────────────────────

class _ConversationsTab extends ConsumerWidget {
  final String searchQuery;
  final VoidCallback onNewConversation;

  const _ConversationsTab({
    required this.searchQuery,
    required this.onNewConversation,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(conversationsProvider);

    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => LoadErrorView(
        title: 'Messagerie indisponible',
        error: e,
        onRetry: () => ref.invalidate(conversationsProvider),
      ),
      data: (list) {
        // Filtrage par recherche
        final filtered = searchQuery.isEmpty
            ? list
            : list
                .where((c) =>
                    c.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                    c.lastMessage
                        .toLowerCase()
                        .contains(searchQuery.toLowerCase()))
                .toList();

        if (filtered.isEmpty) {
          return _EmptyInbox(onStart: onNewConversation);
        }

        return RefreshIndicator(
          color: AppColors.primaryLight,
          onRefresh: () => ref.refresh(conversationsProvider.future),
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: filtered.length,
            itemBuilder: (_, i) => _ConversationTile(
              conversation: filtered[i],
              showDivider: i < filtered.length - 1,
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  MODÈLES & PROVIDERS POUR ACTUALITÉS ET STATUTS RÉELS
// ─────────────────────────────────────────────────────────────────────────────

/// Annonce administrative officielle issue de /news (créée uniquement par l'admin).
class UniNewsItem {
  final String id;
  final String title;
  final String content;
  final String channel;
  final String icon;
  final Color color;
  final String author;
  final DateTime? createdAt;
  final bool important;
  final bool pinned;

  const UniNewsItem({
    required this.id,
    required this.title,
    required this.content,
    required this.channel,
    required this.icon,
    required this.color,
    required this.author,
    this.createdAt,
    this.important = false,
    this.pinned = false,
  });

  factory UniNewsItem.fromJson(Map<String, dynamic> json) {
    Color parsedColor = const Color(0xFF1E3A8A);
    final colorHex = json['color'] as String?;
    if (colorHex != null && colorHex.startsWith('#') && colorHex.length == 7) {
      try {
        parsedColor = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
      } catch (_) {}
    }
    DateTime? dt;
    if (json['createdAt'] != null) {
      dt = DateTime.tryParse(json['createdAt'].toString());
    }
    return UniNewsItem(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      channel: (json['channel'] ?? 'Administration UY1').toString(),
      icon: (json['icon'] ?? '📢').toString(),
      color: parsedColor,
      author: (json['author'] ?? 'Administration').toString(),
      createdAt: dt,
      important: json['important'] == true,
      pinned: json['pinned'] == true,
    );
  }
}

/// Statut réel éphémère (durée 48h) issu de /news.
class UniStatusItem {
  final String id;
  final String userId;
  final String name;
  final String content;
  final String role;
  final String preview;
  final DateTime? createdAt;

  const UniStatusItem({
    required this.id,
    required this.userId,
    required this.name,
    required this.content,
    required this.role,
    required this.preview,
    this.createdAt,
  });

  factory UniStatusItem.fromJson(Map<String, dynamic> json) {
    DateTime? dt;
    if (json['createdAt'] != null) {
      dt = DateTime.tryParse(json['createdAt'].toString());
    }
    return UniStatusItem(
      id: (json['id'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      name: (json['name'] ?? 'Utilisateur').toString(),
      content: (json['content'] ?? '').toString(),
      role: (json['role'] ?? 'STUDENT').toString(),
      preview: (json['preview'] ?? json['content'] ?? '').toString(),
      createdAt: dt,
    );
  }
}

final newsListProvider = FutureProvider<List<UniNewsItem>>((ref) async {
  try {
    final appwrite = ref.read(appwriteServiceProvider);
    final res = await appwrite.callService('/news', {'action': 'list'});
    if (res['ok'] == true && res['news'] is List) {
      return (res['news'] as List)
          .whereType<Map>()
          .map((m) => UniNewsItem.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    }
  } catch (_) {}
  return const [];
});

final statusesListProvider = FutureProvider<List<UniStatusItem>>((ref) async {
  try {
    final appwrite = ref.read(appwriteServiceProvider);
    final res = await appwrite.callService('/news', {'action': 'list-statuses'});
    if (res['ok'] == true && res['statuses'] is List) {
      return (res['statuses'] as List)
          .whereType<Map>()
          .map((m) => UniStatusItem.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    }
  } catch (_) {}
  return const [];
});

// ─────────────────────────────────────────────────────────────────────────────
//  ONGLET 2 : ACTUALITÉS (100% réelles, gérées par l'administration)
// ─────────────────────────────────────────────────────────────────────────────

class _ActualitesTab extends ConsumerWidget {
  const _ActualitesTab();

  void _showNewsDetail(BuildContext context, UniNewsItem item) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Text(item.icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.channel,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              if (item.createdAt != null)
                Text(
                  DateFormat('dd/MM/yyyy à HH:mm').format(item.createdAt!.toLocal()),
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                ),
              const SizedBox(height: 14),
              Text(
                item.content,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newsAsync = ref.watch(newsListProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(newsListProvider.future),
      child: newsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Column(
                children: [
                  const PhosphorIcon(PhosphorIconsBold.warningCircle,
                      size: 40, color: AppColors.danger),
                  const SizedBox(height: 12),
                  Text('Erreur chargement des actualités : $err',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => ref.refresh(newsListProvider),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
          ],
        ),
        data: (news) {
          if (news.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(32),
              children: const [
                SizedBox(height: 40),
                EmptyState(
                  icon: PhosphorIconsBold.broadcast,
                  title: 'Aucune actualité officielle',
                  message:
                      'Les annonces administratives publiées par l’établissement apparaîtront ici.',
                  pose: UniPose.thinking,
                ),
              ],
            );
          }

          final Map<String, List<UniNewsItem>> grouped = {};
          for (final item in news) {
            grouped.putIfAbsent(item.channel, () => []).add(item);
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A8A), Color(0xFF0D9488)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    PhosphorIcon(PhosphorIconsBold.broadcast,
                        color: Colors.white, size: 22),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Actualités officielles vérifiées par l’administration',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              for (final entry in grouped.entries)
                _OfficialNewsChannelCard(
                  channel: entry.key,
                  items: entry.value,
                  onTapItem: (item) => _showNewsDetail(context, item),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _OfficialNewsChannelCard extends StatelessWidget {
  final String channel;
  final List<UniNewsItem> items;
  final ValueChanged<UniNewsItem> onTapItem;

  const _OfficialNewsChannelCard({
    required this.channel,
    required this.items,
    required this.onTapItem,
  });

  @override
  Widget build(BuildContext context) {
    final first = items.first;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: first.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(first.icon, style: const TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(channel,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                      Text('${items.length} annonce${items.length > 1 ? 's' : ''}',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 11)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppColors.teal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Text('Officiel',
                      style: TextStyle(
                          color: AppColors.teal,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          const Divider(
              color: AppColors.divider, height: 1, indent: 14, endIndent: 14),
          for (int i = 0; i < items.length; i++) ...[
            InkWell(
              onTap: () => onTapItem(items[i]),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (items[i].pinned || items[i].important)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 5, right: 8),
                        decoration: const BoxDecoration(
                            color: Color(0xFFD97706), shape: BoxShape.circle),
                      )
                    else
                      const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(items[i].title,
                              style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: (items[i].pinned || items[i].important)
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  fontSize: 13)),
                          const SizedBox(height: 3),
                          Text(items[i].content,
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  height: 1.4),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      items[i].createdAt != null
                          ? DateFormat('dd/MM').format(items[i].createdAt!.toLocal())
                          : '',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
            if (i < items.length - 1)
              const Divider(
                  color: AppColors.divider,
                  height: 1,
                  indent: 60,
                  endIndent: 14),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ONGLET 3 : STATUTS (100% réels et interactifs sur 48h)
// ─────────────────────────────────────────────────────────────────────────────

class _StatutsTab extends ConsumerWidget {
  const _StatutsTab();

  void _showPostStatusSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PostStatusSheet(
        onSuccess: () => ref.invalidate(statusesListProvider),
      ),
    );
  }

  void _showStatusDetail(BuildContext context, UniStatusItem status) {
    showDialog(
      context: context,
      builder: (_) => _StatusViewerDialog(status: status),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final myUserId = user?.id ?? '';
    final statusesAsync = ref.watch(statusesListProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(statusesListProvider.future),
      child: statusesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Text('Erreur : $err',
                  style: const TextStyle(color: AppColors.danger)),
            ),
          ],
        ),
        data: (allStatuses) {
          final myStatuses =
              allStatuses.where((s) => s.userId == myUserId).toList();
          final myRecent = myStatuses.isNotEmpty ? myStatuses.first : null;
          final others =
              allStatuses.where((s) => s.userId != myUserId).toList();

          return ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              // Mon statut
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: Stack(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: myRecent != null
                              ? AppColors.teal
                              : AppColors.glassBorder,
                          width: 2.5,
                        ),
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.teal.withValues(alpha: 0.15),
                        ),
                        child: Center(
                          child: Text(
                            (user?.name.isNotEmpty == true ? user!.name[0] : 'M')
                                .toUpperCase(),
                            style: const TextStyle(
                                color: AppColors.teal,
                                fontSize: 20,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: AppColors.teal,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.background, width: 2),
                        ),
                        child: const Icon(Icons.add,
                            size: 13, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                title: const Text('Mon statut',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
                subtitle: Text(
                  myRecent != null
                      ? myRecent.content
                      : 'Appuyez pour partager un statut avec la promo',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12.5),
                ),
                trailing: myRecent != null
                    ? IconButton(
                        icon: const Icon(Icons.visibility_outlined, size: 20),
                        tooltip: 'Voir mon statut',
                        onPressed: () => _showStatusDetail(context, myRecent),
                      )
                    : null,
                onTap: () => _showPostStatusSheet(context, ref),
              ),

              const Divider(
                  color: AppColors.divider, height: 1, indent: 72, endIndent: 0),

              if (others.isNotEmpty) ...[
                const _SectionLabel(label: 'Mises à jour récentes (48h)'),
                for (final s in others) ...[
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 6),
                    leading: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: AppColors.primaryBlue, width: 2.2),
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryBlue.withValues(alpha: 0.12),
                        ),
                        child: Center(
                          child: Text(
                            s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                            style: const TextStyle(
                                color: AppColors.primaryBlue,
                                fontSize: 20,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.name,
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (s.role.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.inputFill,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              s.role,
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text(
                      s.content,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12.5),
                    ),
                    trailing: Text(
                      s.createdAt != null
                          ? DateFormat('HH:mm').format(s.createdAt!.toLocal())
                          : '',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 11),
                    ),
                    onTap: () => _showStatusDetail(context, s),
                  ),
                  const Divider(
                      color: AppColors.divider,
                      height: 1,
                      indent: 72,
                      endIndent: 0),
                ],
              ] else ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 30, 20, 20),
                  child: Center(
                    child: Text(
                      'Aucun statut partagé pour le moment.\nSoyez le premier à partager une mise à jour !',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                          height: 1.4),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
        child: Text(label,
            style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4)),
      );
}

class _PostStatusSheet extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;
  const _PostStatusSheet({required this.onSuccess});

  @override
  ConsumerState<_PostStatusSheet> createState() => _PostStatusSheetState();
}

class _PostStatusSheetState extends ConsumerState<_PostStatusSheet> {
  final _textCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _submitting = true);
    try {
      final appwrite = ref.read(appwriteServiceProvider);
      final res = await appwrite.callService('/news', {
        'action': 'post-status',
        'content': text,
        'preview': text.length > 50 ? '${text.substring(0, 50)}…' : text,
      });

      if (!mounted) return;
      if (res['ok'] == true) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Statut publié avec succès !'),
            backgroundColor: AppColors.teal,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message']?.toString() ?? 'Erreur lors de la publication'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.glassBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Ajouter un statut',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Visible par les utilisateurs pendant 48 heures.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _textCtrl,
              autofocus: true,
              maxLines: 4,
              maxLength: 280,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Quoi de neuf ? Un message, un rappel pour la promo…',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.inputFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.inputBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.inputBorder),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(_submitting ? 'Publication…' : 'Publier mon statut'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
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

class _StatusViewerDialog extends StatelessWidget {
  final UniStatusItem status;
  const _StatusViewerDialog({required this.status});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryBlue.withValues(alpha: 0.15),
                  ),
                  child: Center(
                    child: Text(
                      status.name.isNotEmpty ? status.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status.name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      if (status.createdAt != null)
                        Text(
                          DateFormat('dd MMMM à HH:mm', 'fr_FR')
                              .format(status.createdAt!.toLocal()),
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11.5,
                          ),
                        ),
                    ],
                  ),
                ),
                if (status.role.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.inputFill,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status.role,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Text(
                status.content,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TUILE CONVERSATION (style WhatsApp)
// ─────────────────────────────────────────────────────────────────────────────

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final bool showDivider;
  const _ConversationTile(
      {required this.conversation, this.showDivider = true});

  static String _time(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return '';
    final local = parsed.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inDays == 0) return DateFormat.Hm().format(local);
    if (diff.inDays == 1) return 'Hier';
    if (diff.inDays < 7) {
      try {
        return DateFormat('EEEE', 'fr_FR').format(local);
      } catch (_) {
        return DateFormat('EEEE').format(local);
      }
    }
    return DateFormat('dd/MM/yy').format(local);
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = conversation.unread > 0;

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.push(
              '/messages/${conversation.id}',
              extra: conversation,
            ),
            onLongPress: () => _showOptions(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  // Avatar
                  _Avatar(name: conversation.name, size: 52),
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
                                  fontSize: 15,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              _time(conversation.time),
                              style: TextStyle(
                                fontSize: 12,
                                color: hasUnread
                                    ? AppColors.teal
                                    : AppColors.textMuted,
                                fontWeight: hasUnread
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            // Double coche de lecture (style WhatsApp)
                            const _ReadTick(sent: true, read: true),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                conversation.lastMessage,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
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
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.teal,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  conversation.unread > 99
                                      ? '99+'
                                      : '${conversation.unread}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
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
        if (showDivider)
          Divider(
            color: AppColors.divider,
            height: 1,
            indent: 80,
            endIndent: 0,
          ),
      ],
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConversationOptionsSheet(conv: conversation),
    );
  }
}

/// Double coche de lecture comme WhatsApp.
class _ReadTick extends StatelessWidget {
  final bool sent;
  final bool read;
  const _ReadTick({required this.sent, required this.read});

  @override
  Widget build(BuildContext context) {
    if (!sent) return const SizedBox.shrink();
    final color = read ? AppColors.teal : AppColors.textMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.done_all_rounded, size: 14, color: color),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final double size;
  const _Avatar({required this.name, this.size = 52});

  static const _colors = [
    Color(0xFF1E3A8A),
    Color(0xFF0D9488),
    Color(0xFF7C3AED),
    Color(0xFFD97706),
    Color(0xFFDC2626),
    Color(0xFF0891B2),
  ];

  Color _color() {
    if (name.isEmpty) return _colors[0];
    return _colors[name.codeUnitAt(0) % _colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _color(),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.36,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  OPTIONS CONTEXTUELLE (long press)
// ─────────────────────────────────────────────────────────────────────────────

class _ConversationOptionsSheet extends StatelessWidget {
  final Conversation conv;
  const _ConversationOptionsSheet({required this.conv});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).padding.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.glassBorder,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 14),
          Text(conv.name,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          _OptionRow(
              icon: PhosphorIconsBold.tray,
              label: 'Archiver',
              onTap: () => Navigator.pop(context)),
          _OptionRow(
              icon: PhosphorIconsBold.prohibit,
              label: 'Mettre en sourdine',
              onTap: () => Navigator.pop(context)),
          _OptionRow(
              icon: PhosphorIconsBold.mapPin,
              label: 'Épingler la conversation',
              onTap: () => Navigator.pop(context)),
          _OptionRow(
              icon: PhosphorIconsBold.trash,
              label: 'Supprimer',
              color: AppColors.danger,
              onTap: () => Navigator.pop(context)),
        ],
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;
  const _OptionRow(
      {required this.icon,
      required this.label,
      this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textPrimary;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: PhosphorIcon(icon, size: 20, color: c),
      title: Text(label, style: TextStyle(color: c, fontSize: 14)),
      onTap: onTap,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  FAB GRADIENT
// ─────────────────────────────────────────────────────────────────────────────

class _GradientFab extends StatelessWidget {
  final VoidCallback onPressed;
  const _GradientFab({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
            colors: [Color(0xFF1E3A8A), Color(0xFF0D9488)]),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D9488).withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: onPressed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        tooltip: 'Nouvelle conversation',
        child: const PhosphorIcon(PhosphorIconsFill.chatsCircle,
            color: Colors.white, size: 26),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ÉTAT VIDE
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyInbox extends StatelessWidget {
  final VoidCallback onStart;
  const _EmptyInbox({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A8A), Color(0xFF0D9488)]),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded,
                  color: Colors.white, size: 36),
            ),
            const SizedBox(height: 20),
            const Text('Aucune conversation',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 17)),
            const SizedBox(height: 8),
            const Text(
              'Cherchez un contact par son pseudo\npour démarrer un échange.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 13.5, height: 1.5),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Nouvelle conversation'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  FEUILLE NOUVELLE CONVERSATION
// ─────────────────────────────────────────────────────────────────────────────

class _NewConversationSheet extends ConsumerStatefulWidget {
  const _NewConversationSheet();

  @override
  ConsumerState<_NewConversationSheet> createState() =>
      _NewConversationSheetState();
}

class _NewConversationSheetState
    extends ConsumerState<_NewConversationSheet> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<ChatContact> _results = const [];
  bool _loading = false;
  String? _error;
  int _reqId = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String val) {
    _debounce?.cancel();
    final term = val.trim().replaceFirst(RegExp(r'^@'), '');
    if (term.length < 2) {
      setState(() {
        _results = const [];
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() => _loading = true);
    _debounce =
        Timer(const Duration(milliseconds: 300), () => _search(term));
  }

  Future<void> _search(String term) async {
    final id = ++_reqId;
    try {
      final c = await ref
          .read(messagingRepositoryProvider)
          .searchContacts(term);
      if (!mounted || id != _reqId) return;
      setState(() {
        _results = c;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || id != _reqId) return;
      setState(() {
        _results = const [];
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.glassBorder,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Nouvelle conversation',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.inputBorder),
              ),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                onChanged: _onChanged,
                style:
                    const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                decoration: const InputDecoration(
                  hintText: '@pseudo ou email',
                  hintStyle: TextStyle(color: AppColors.textMuted),
                  prefixIcon: PhosphorIcon(PhosphorIconsBold.magnifyingGlass,
                      color: AppColors.textSecondary, size: 18),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(height: 240, child: _buildResults()),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_error != null) {
      return Center(
          child: Text(_error!,
              style: const TextStyle(color: AppColors.danger, fontSize: 13)));
    }
    if (_loading) return const LoadingView(label: 'Recherche…');
    if (_ctrl.text
            .trim()
            .replaceFirst(RegExp(r'^@'), '')
            .length <
        2) {
      return const Center(
          child: Text('Saisissez au moins 2 caractères.',
              style:
                  TextStyle(color: AppColors.textMuted, fontSize: 13)));
    }
    if (_results.isEmpty) {
      return const Center(
          child: Text('Aucun contact ne correspond.',
              style:
                  TextStyle(color: AppColors.textMuted, fontSize: 13)));
    }
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, __) =>
          Divider(color: AppColors.divider, height: 1),
      itemBuilder: (ctx, i) {
        final c = _results[i];
        return ListTile(
          leading: _Avatar(name: c.name, size: 44),
          title: Text(c.name,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14)),
          subtitle: Text(
            c.username.isNotEmpty ? '@${c.username}' : c.email,
            style: const TextStyle(
                fontSize: 12, color: AppColors.tealLight),
          ),
          onTap: () => Navigator.of(ctx).pop(c),
        );
      },
    );
  }
}
