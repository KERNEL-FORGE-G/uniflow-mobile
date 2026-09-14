import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../widgets/common.dart';
import '../theme/app_theme.dart';
import '../repositories/forum_repository.dart';
import '../providers/providers.dart';

final forumPostsProvider = FutureProvider<List<ForumPost>>((ref) async {
  return ref.read(forumRepositoryProvider).getPosts();
});

class ForumScreen extends ConsumerWidget {
  const ForumScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(forumPostsProvider);

    return Scaffold(
      body: Column(
        children: [
          const GradientHeader(title: 'Forum UniFlow', subtitle: 'Échanges et entraide communautaire'),
          Expanded(
            child: postsAsync.when(
              data: (posts) {
                if (posts.isEmpty) {
                  return const EmptyState(
                    icon: Icons.forum_outlined,
                    title: 'Aucune publication',
                    message: 'Lancez la première discussion du forum.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.refresh(forumPostsProvider.future),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: posts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final post = posts[index];
                      return SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Avatar(initials: post.authorName.isNotEmpty ? post.authorName[0] : '?', size: 32),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(post.authorName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      Text(post.role, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                    ],
                                  ),
                                ),
                                Text(
                                  DateFormat('dd/MM HH:mm').format(post.createdAt),
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(post.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 4),
                            Text(post.content, style: const TextStyle(fontSize: 14), maxLines: 3, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _buildInteraction(Icons.thumb_up_outlined, '${post.likes}'),
                                const SizedBox(width: 16),
                                _buildInteraction(Icons.chat_bubble_outline, '0'),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: AppColors.teal.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                                  child: Text(post.category, style: const TextStyle(fontSize: 10, color: AppColors.teal, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const LoadingView(),
              error: (e, _) => Padding(padding: const EdgeInsets.all(16), child: ErrorBanner(message: 'Chargement impossible.\n$e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Boîte de dialogue pour créer un post
        },
        backgroundColor: AppColors.primaryBlue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildInteraction(IconData icon, String count) {
    return Row(children: [Icon(icon, size: 16, color: AppColors.textSecondary), const SizedBox(width: 4), Text(count, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))]);
  }
}
