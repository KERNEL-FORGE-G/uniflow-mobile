import 'dart:convert';
import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/appwrite_service.dart';
import '../providers/appwrite_provider.dart';

class Conversation {
  final String id;
  final String name;
  final String role;
  final String email;
  final bool online;
  final String lastMessage;
  final int unread;

  Conversation({
    required this.id,
    required this.name,
    required this.role,
    required this.email,
    required this.online,
    required this.lastMessage,
    required this.unread,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? '',
      email: json['email'] ?? '',
      online: json['online'] ?? false,
      lastMessage: json['preview'] ?? '',
      unread: json['unread'] ?? 0,
    );
  }
}

class MessagingRepository {
  final AppwriteService _service;
  static const String functionId = 'messaging';

  MessagingRepository(this._service);

  Future<List<Conversation>> getConversations() async {
    final execution = await _service.functions.createExecution(
      functionId: functionId,
      body: jsonEncode({'action': 'list'}),
      xasync: false,
    );

    if (execution.status.toString() != 'completed') {
      throw Exception('Erreur messagerie: ${execution.status}');
    }

    final data = jsonDecode(execution.responseBody);
    if (data['ok'] != true) {
      throw Exception(data['message'] ?? 'Erreur inconnue');
    }

    final List list = data['conversations'] ?? [];
    return list.map((item) => Conversation.fromJson(item)).toList();
  }

  Future<void> sendMessage(String conversationId, String text) async {
    await _service.functions.createExecution(
      functionId: functionId,
      body: jsonEncode({
        'action': 'send',
        'conversationId': conversationId,
        'text': text,
      }),
      xasync: false,
    );
  }
}

final messagingRepositoryProvider = Provider<MessagingRepository>((ref) {
  final service = ref.watch(appwriteServiceProvider);
  return MessagingRepository(service);
});
