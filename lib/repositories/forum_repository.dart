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
      data: {
        'authorId': user.id,
        'authorName': user.name,
        'role': user.role,
        'university': user.university ?? 'Compte personnel UniFlow',
        'title': title,
        'content': content,
        'category': category,
        'likes': 0,
        'tags': tags,
        'createdAt': DateTime.now().toIso8601String(),
      },
    );
  }
}

final forumRepositoryProvider = Provider<ForumRepository>((ref) {
  final service = ref.watch(appwriteServiceProvider);
  return ForumRepository(service);
});
