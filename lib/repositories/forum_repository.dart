// `Databases.*Document` est marqué déprécié par le SDK Dart 26 au profit de
// `TablesDB.*Row` (Appwrite 1.8). Le schéma du projet est encore déclaré en
// collections/documents (`uniflow-we/scripts/appwrite-schema.mjs`) et la
// migration vers TablesDB se fera pour les trois clients en même temps ; on
// ignore la dépréciation ici, fichier par fichier, sans assouplir l'analyse
// globale.
// ignore_for_file: deprecated_member_use

import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/appwrite_service.dart';
import '../models/appwrite_models.dart';
import '../providers/appwrite_provider.dart';

class ForumPost {
  final String id;
  final String authorId;
  final String authorName;
  final String role;
  final String? university;
  final String title;
  final String content;
  final String category;
  final int likes;
  final List<String> tags;
  final DateTime createdAt;

  ForumPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.role,
    this.university,
    required this.title,
    required this.content,
    required this.category,
    required this.likes,
    required this.tags,
    required this.createdAt,
  });

  factory ForumPost.fromDocument(Map<String, dynamic> data, String id) {
    return ForumPost(
      id: id,
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? '',
      role: data['role'] ?? '',
      university: data['university'],
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      category: data['category'] ?? '',
      likes: data['likes'] ?? 0,
      tags: (data['tags'] as List? ?? []).map((e) => e.toString()).toList(),
      createdAt: DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}

class ForumRepository {
  final AppwriteService _service;
  ForumRepository(this._service);

  Future<List<ForumPost>> getPosts() async {
    final response = await _service.databases.listDocuments(
      databaseId: _service.databaseId,
      collectionId: 'forum_posts',
      queries: [
        Query.orderDesc('\$createdAt'),
        Query.limit(100),
      ],
    );
    return response.documents.map((doc) => ForumPost.fromDocument(doc.data, doc.$id)).toList();
  }

  Future<void> createPost(String title, String content, String category, List<String> tags, UniFlowUser user) async {
    await _service.databases.createDocument(
      databaseId: _service.databaseId,
      collectionId: 'forum_posts',
      documentId: ID.unique(),
      data: forumPostPayload(
        title: title,
        content: content,
        category: category,
        authorId: user.id,
        authorName: user.name,
        role: user.role,
        university: user.university ?? 'Compte personnel UniFlow',
      ),
    );
  }

  /// Billets que l'utilisateur courant a déjà recommandés.
  ///
  /// L'unicité est garantie côté serveur par l'index `forum_reaction_unique`
  /// sur (postId, userId) : un utilisateur ne peut recommander un billet qu'une
  /// fois. La Function borne de surcroît la chose en refusant qu'on recommande
  /// son propre billet.
  Future<Set<String>> getMyReactions() async {
    final execution = await _service.executeFunction(_reactionsFunction, {'action': 'list'});
    final data = decodeFunctionPayload(execution);
    if (data['ok'] != true) return const {};
    final rows = data['reactedPostIds'];
    if (rows is! List) return const {};
    return rows.whereType<String>().toSet();
  }

  /// Ajoute ou retire la recommandation, et rend le nouvel état.
  Future<ForumReaction> toggleReaction(String postId) async {
    final execution = await _service.executeFunction(
      _reactionsFunction,
      {'action': 'react', 'postId': postId},
    );
    final data = decodeFunctionPayload(execution);
    if (data['ok'] != true) {
      throw Exception(data['message'] ?? 'La recommandation a échoué.');
    }
    return ForumReaction(
      liked: data['liked'] == true,
      likes: (data['likes'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Chemin du service des recommandations dans le routeur `uniflow-api`.
///
/// Le mobile n'appelait pas ce service et affichait un compteur figé ; depuis
/// la migration vers Appwrite Cloud, il est atteint par `path` sur l'unique
/// Function, comme la messagerie.
const String _reactionsFunction = '/forum-reactions';

/// Document à écrire pour créer un billet.
///
/// **`tags` en est délibérément absent** : la collection `forum_posts` ne
/// déclare pas cet attribut — voir `scripts/appwrite-schema.mjs` — et Appwrite
/// refuse alors la création entière, avec « Unknown attribute: tags ». Le web
/// applique exactement la même omission (`src/lib/appwrite.ts`, où `tags` est
/// retiré par déstructuration avant l'écriture). Le paramètre `tags` de
/// `createPost` est conservé pour ne pas changer l'interface, mais les
/// étiquettes ne sont pas persistées.
///
/// Fonction pure : c'est ce qui permet de vérifier sans réseau que l'attribut
/// fautif ne réapparaît pas.
Map<String, dynamic> forumPostPayload({
  required String title,
  required String content,
  required String category,
  required String authorId,
  required String authorName,
  required String role,
  required String university,
}) {
  return {
    'authorId': authorId,
    'authorName': authorName,
    'role': role,
    'university': university,
    'title': title,
    'content': content,
    'category': category,
    // Le compteur est tenu par la Function de réactions, qui le recalcule à
    // partir des réactions réelles : on part donc de zéro, jamais d'une valeur
    // fournie par le client.
    'likes': 0,
    'createdAt': DateTime.now().toIso8601String(),
  };
}

/// Résultat d'une bascule de recommandation.
class ForumReaction {
  /// Vrai si l'utilisateur recommande désormais le billet.
  final bool liked;

  /// Nombre de recommandations après l'opération, tel que compté par le serveur.
  final int likes;

  const ForumReaction({required this.liked, required this.likes});
}

final forumRepositoryProvider = Provider<ForumRepository>((ref) {
  final service = ref.watch(appwriteServiceProvider);
  return ForumRepository(service);
});
