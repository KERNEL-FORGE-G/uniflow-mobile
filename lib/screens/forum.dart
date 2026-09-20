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

/// Billets que l'utilisateur courant recommande déjà.
///
/// Chargé à part des billets : le serveur ne renvoie que les identifiants
/// recommandés *par l'appelant*, ce qui évite d'exposer qui a recommandé quoi.
final myReactionsProvider = FutureProvider<Set<String>>((ref) async {
  return ref.read(forumRepositoryProvider).getMyReactions();
});

/// Catégories proposées à la création, identiques à celles du web.
const List<String> forumCategories = [
  'Retour d\'expérience',
  'Question',
  'Suggestion',
  'Support',
];

class ForumScreen extends ConsumerStatefulWidget {
  const ForumScreen({super.key});

  @override
  ConsumerState<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends ConsumerState<ForumScreen> {
  String? _erreur;

  /// Billet en cours de traitement, pour n'animer que son propre bouton.
  String? _enCours;

  /// Ouvre la boîte de création et publie le billet.
  ///
  /// Le bouton flottant ne faisait auparavant rien du tout : ni boîte, ni
  /// appel. Il ne restait qu'un `TODO` en commentaire.
  Future<void> _creerBillet() async {
    final brouillon = await showDialog<_Brouillon>(
      context: context,
      builder: (context) => const _DialogueNouveauBillet(),
    );
    if (brouillon == null || !mounted) return;

    final user = ref.read(currentUserProvider);
    if (user == null) {
      setState(() => _erreur = 'Connectez-vous pour publier dans le forum.');
      return;
    }

    setState(() => _erreur = null);
    try {
      await ref.read(forumRepositoryProvider).createPost(
            brouillon.titre,
            brouillon.contenu,
            brouillon.categorie,
            const [],
            user,
          );
      ref.invalidate(forumPostsProvider);
    } catch (error) {
      if (mounted) setState(() => _erreur = error.toString());
    }
  }

  /// Ajoute ou retire la recommandation, puis recharge les compteurs.
  Future<void> _basculerReaction(ForumPost post) async {
    setState(() {
      _enCours = post.id;
      _erreur = null;
    });
    try {
      await ref.read(forumRepositoryProvider).toggleReaction(post.id);
      // Le compteur affiché vient du billet, que la Function met à jour : il
      // faut donc relire les billets, et non se contenter d'incrémenter
      // localement — deux appareils verraient sinon des totaux divergents.
      ref.invalidate(forumPostsProvider);
      ref.invalidate(myReactionsProvider);
    } catch (error) {
      if (mounted) setState(() => _erreur = error.toString());
    } finally {
      if (mounted) setState(() => _enCours = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final postsAsync = ref.watch(forumPostsProvider);
    final reactions = ref.watch(myReactionsProvider).valueOrNull ?? const <String>{};

    return Scaffold(
      body: Column(
        children: [
          const GradientHeader(title: 'Forum UniFlow', subtitle: 'Échanges et entraide communautaire'),
          if (_erreur != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: ErrorBanner(message: _erreur!),
            ),
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
                  onRefresh: () {
                    ref.invalidate(myReactionsProvider);
                    return ref.refresh(forumPostsProvider.future);
                  },
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
                                      Text(post.role,
                                          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
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
                            Text(post.content,
                                style: const TextStyle(fontSize: 14), maxLines: 3, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _boutonReaction(post, reactions.contains(post.id)),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                      color: AppColors.teal.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4)),
                                  child: Text(post.category,
                                      style: const TextStyle(
                                          fontSize: 10, color: AppColors.teal, fontWeight: FontWeight.bold)),
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
              error: (e, _) =>
                  Padding(padding: const EdgeInsets.all(16), child: ErrorBanner(message: 'Chargement impossible.\n$e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _creerBillet,
        backgroundColor: AppColors.primaryBlue,
        tooltip: 'Écrire une publication',
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  /// Recommandation cliquable.
  ///
  /// Le compteur et l'icône ne réagissaient pas : les « j'aime » étaient
  /// affichés en lecture seule, et le nombre de commentaires était écrit en
  /// dur à `0` — alors qu'aucune collection de commentaires n'existe. Ce
  /// bouton-ci appelle réellement la Function, qui refuse en outre qu'on
  /// recommande son propre billet.
  Widget _boutonReaction(ForumPost post, bool aime) {
    final enCours = _enCours == post.id;
    final couleur = aime ? AppColors.teal : AppColors.textSecondary;
    return InkWell(
      onTap: enCours ? null : () => _basculerReaction(post),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          children: [
            if (enCours)
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            else
              Icon(aime ? Icons.thumb_up : Icons.thumb_up_outlined, size: 16, color: couleur),
            const SizedBox(width: 4),
            Text(
              '${post.likes}',
              style: TextStyle(fontSize: 12, color: couleur, fontWeight: aime ? FontWeight.bold : FontWeight.normal),
            ),
          ],
        ),
      ),
    );
  }
}

/// Contenu saisi dans la boîte de création.
class _Brouillon {
  final String titre;
  final String contenu;
  final String categorie;
  const _Brouillon(this.titre, this.contenu, this.categorie);
}

class _DialogueNouveauBillet extends StatefulWidget {
  const _DialogueNouveauBillet();

  @override
  State<_DialogueNouveauBillet> createState() => _DialogueNouveauBilletState();
}

class _DialogueNouveauBilletState extends State<_DialogueNouveauBillet> {
  final _titre = TextEditingController();
  final _contenu = TextEditingController();
  String _categorie = forumCategories.first;
  String? _erreur;

  @override
  void dispose() {
    _titre.dispose();
    _contenu.dispose();
    super.dispose();
  }

  void _valider() {
    final titre = _titre.text.trim();
    final contenu = _contenu.text.trim();
    // Le serveur refuse déjà ces cas — `title` et `content` sont requis — mais
    // un aller-retour réseau pour apprendre qu'un champ est vide n'apporte
    // rien.
    if (titre.isEmpty) {
      setState(() => _erreur = 'Donnez un titre à votre publication.');
      return;
    }
    if (contenu.isEmpty) {
      setState(() => _erreur = 'Écrivez votre message.');
      return;
    }
    Navigator.of(context).pop(_Brouillon(titre, contenu, _categorie));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouvelle publication'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titre,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 255,
              decoration: const InputDecoration(labelText: 'Titre', counterText: ''),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _contenu,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 5,
              maxLength: 5000,
              decoration: const InputDecoration(labelText: 'Message', counterText: ''),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _categorie,
              decoration: const InputDecoration(labelText: 'Catégorie'),
              items: [
                for (final categorie in forumCategories)
                  DropdownMenuItem(value: categorie, child: Text(categorie, style: const TextStyle(fontSize: 13))),
              ],
              onChanged: (valeur) => setState(() => _categorie = valeur ?? forumCategories.first),
            ),
            if (_erreur != null) ...[
              const SizedBox(height: 10),
              Text(_erreur!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        FilledButton(onPressed: _valider, child: const Text('Publier')),
      ],
    );
  }
}
