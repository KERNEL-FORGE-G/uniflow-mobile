import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/common.dart';
import '../theme/app_theme.dart';
import '../repositories/messaging_repository.dart';

final conversationsProvider = FutureProvider<List<Conversation>>((ref) async {
  return ref.read(messagingRepositoryProvider).getConversations();
});

class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsProvider);

    return Scaffold(
      body: Column(
        children: [
          const GradientHeader(title: 'Messagerie', subtitle: 'Discussions académiques et privées'),
          Expanded(
            child: conversationsAsync.when(
              data: (list) {
                if (list.isEmpty) {
                  return const Center(child: Text('Aucune conversation trouvée.'));
                }
                return RefreshIndicator(
                  onRefresh: () => ref.refresh(conversationsProvider.future),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final conv = list[index];
                      return SectionCard(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Badge(
                            isLabelVisible: conv.online,
                            backgroundColor: Colors.green,
                            child: Avatar(initials: conv.name.isNotEmpty ? conv.name[0] : '?', size: 40),
                          ),
                          title: Text(conv.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(conv.lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Aujourd\'hui', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                              if (conv.unread > 0)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle),
                                  child: Text('${conv.unread}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                          onTap: () {
                            // TODO: Ouvrir la conversation
                          },
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: AppColors.teal,
        child: const Icon(Icons.chat, color: Colors.white),
      ),
    );
  }
}
