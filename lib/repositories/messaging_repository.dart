import 'dart:io';
import 'dart:typed_data';

import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/appwrite_service.dart';
import '../offline/cached_providers.dart';
import '../providers/appwrite_provider.dart';

/// Identifiant du fichier dans la réponse de téléversement, ou `null` si elle
/// est illisible.
///
/// La fonction vit désormais dans `data/appwrite_service.dart`, avec les autres
/// contournements du SDK : le téléversement d'une pièce jointe et celui d'une
/// photo de profil butaient sur le même `File.fromMap`. Elle est ré-exportée ici
/// pour que les appelants historiques — et les tests — n'aient pas à changer
/// d'import.
export '../data/appwrite_service.dart' show decodeUploadedFileId;

/// Un message dans un fil de discussion.
///
/// `from` est calculé par la fonction Appwrite relativement à l'appelant : le
/// client n'a donc pas à comparer les identifiants pour savoir de quel côté
/// afficher la bulle.
class ChatMessage {
  final String id;
  final bool mine;
  final String text;
  final String time;
  final String senderId;

  /// Pièce jointe éventuelle. `fileId` vide signifie « message texte seul ».
  final String fileId;
  final String fileName;
  final int fileSize;
  final String fileType;

  /// `text`, `image`, `audio`, `video` ou `file` — calculé par la fonction à
  /// partir du type MIME réel du fichier, pour que l'affichage n'ait pas à
  /// réinterpréter une extension.
  final String kind;

  /// Message signalé comme urgent par son expéditeur.
  final bool urgent;

  ChatMessage({
    required this.id,
    required this.mine,
    required this.text,
    required this.time,
    required this.senderId,
    this.fileId = '',
    this.fileName = '',
    this.fileSize = 0,
    this.fileType = '',
    this.kind = 'text',
    this.urgent = false,
  });

  bool get hasAttachment => fileId.isNotEmpty;
  bool get isImage => hasAttachment && kind == 'image';

  /// Taille lisible : « 1,2 Mo », « 340 ko ».
  String get readableSize {
    if (fileSize <= 0) return '';
    if (fileSize < 1024) return '$fileSize o';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(0)} ko';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? '',
      mine: json['from'] == 'me',
      text: json['text'] ?? '',
      time: json['time'] ?? '',
      senderId: json['senderId'] ?? '',
      fileId: json['fileId'] ?? '',
      fileName: json['fileName'] ?? '',
      fileSize: (json['fileSize'] as num?)?.toInt() ?? 0,
      fileType: json['fileType'] ?? '',
      kind: json['kind'] ?? 'text',
      urgent: json['urgent'] == true,
    );
  }
}

/// Une notification reçue par l'utilisateur courant.
class AppNotification {
  final String id;
  final String type;
  final String title;
  final String message;
  final bool isRead;

  /// Route interne à ouvrir au tap, par exemple
  /// « /messages?conversation=conv_… ».
  final String link;
  final String time;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
    required this.link,
    required this.time,
  });

  /// Identifiant de conversation extrait de [link], vide s'il n'y en a pas.
  String get conversationId {
    final index = link.indexOf('conversation=');
    if (index < 0) return '';
    return link.substring(index + 'conversation='.length).split('&').first;
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] ?? '',
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      isRead: json['isRead'] == true,
      link: json['link'] ?? '',
      time: json['time'] ?? '',
    );
  }
}

/// Un contact de l'annuaire, tel que renvoyé par `search` et `open`.
class ChatContact {
  final String userId;
  final String name;
  final String email;
  final String username;
  final String avatarFileId;
  final String role;

  ChatContact({
    required this.userId,
    required this.name,
    required this.email,
    required this.username,
    required this.avatarFileId,
    required this.role,
  });

  factory ChatContact.fromJson(Map<String, dynamic> json) {
    return ChatContact(
      userId: json['userId'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      username: json['username'] ?? '',
      avatarFileId: json['avatarFileId'] ?? '',
      role: json['role'] ?? '',
    );
  }
}

class Conversation {
  final String id;

  /// Identifiant Appwrite du correspondant.
  ///
  /// Nécessaire pour accorder au fichier téléversé la lecture aux deux
  /// participants : Appwrite n'accorde au créateur que les permissions qu'il
  /// demande explicitement.
  final String userId;
  final String name;
  final String role;
  final String email;

  /// Pseudo du correspondant : c'est le référent affiché, l'email ne servant
  /// plus que de repli pour les comptes antérieurs au backfill.
  final String username;
  final String avatarFileId;
  final bool online;
  final String lastMessage;
  final String time;
  final int unread;
  final List<ChatMessage> messages;

  Conversation({
    required this.id,
    required this.userId,
    required this.name,
    required this.role,
    required this.email,
    required this.username,
    required this.avatarFileId,
    required this.online,
    required this.lastMessage,
    required this.time,
    required this.unread,
    required this.messages,
  });

  /// Libellé du correspondant : le pseudo s'il existe, l'email sinon.
  String get handle => username.isNotEmpty ? '@$username' : email;

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'];
    return Conversation(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? '',
      email: json['email'] ?? '',
      username: json['username'] ?? '',
      avatarFileId: json['avatarFileId'] ?? '',
      online: json['online'] ?? false,
      lastMessage: json['preview'] ?? '',
      time: json['time'] ?? '',
      unread: json['unread'] ?? 0,
      messages: rawMessages is List
          ? rawMessages.whereType<Map>().map((item) => ChatMessage.fromJson(Map<String, dynamic>.from(item))).toList()
          : const [],
    );
  }
}

/// Erreur portant le message rédigé par la fonction Appwrite.
///
/// La fonction distingue déjà « pseudo introuvable », « conversation qui ne vous
/// appartient pas » ou « accès refusé » : ces textes sont destinés à
/// l'utilisateur et ne doivent pas être remplacés par un message générique.
class MessagingException implements Exception {
  final String message;
  final String code;
  MessagingException(this.message, {this.code = ''});
  @override
  String toString() => message;
}

class MessagingRepository {
  final AppwriteService _service;

  /// Chemin du service de messagerie dans le routeur `uniflow-api`.
  ///
  /// Ce n'est plus un identifiant de Function : depuis la migration vers
  /// Appwrite Cloud, une seule Function porte tous les services et c'est le
  /// champ `path` de l'exécution qui choisit celui-ci. Appeler encore
  /// `/functions/messaging/executions` répondait 404, et l'écran affichait
  /// « Messagerie indisponible » alors que le serveur fonctionnait.
  static const String servicePath = '/messaging';

  MessagingRepository(this._service);

  /// Exécute le service et renvoie le document d'exécution brut du serveur.
  ///
  /// **Ne pas revenir à `functions.createExecution`.** Une version antérieure
  /// du couple SDK/serveur faisait lever `Execution.fromMap` (« Bad state: No
  /// element ») sur *chaque* appel ; ce `StateError` n'étant pas une
  /// `AppwriteException`, `_invoke` le laissait remonter brut jusqu'à l'écran.
  /// Le détail de l'appel vit dans `AppwriteService.executeFunction`, partagé
  /// avec les autres services : un seul endroit à corriger le jour où le
  /// contrat change.
  Future<Map<String, dynamic>> _execute(Map<String, dynamic> payload) => _service.executeFunction(servicePath, payload);

  /// Exécute la fonction et renvoie la charge utile JSON.
  ///
  /// Le corps est analysé même lorsque le statut d'exécution n'est pas
  /// `completed` : Appwrite marque l'exécution en échec dès que la fonction
  /// répond avec un code 4xx, alors que le corps contient justement le message
  /// explicite à montrer à l'utilisateur.
  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> payload) async {
    final Map<String, dynamic> execution;
    try {
      execution = await _execute(payload);
    } on AppwriteException catch (error) {
      throw MessagingException(
        error.code == 404
            ? 'La Function « ${_service.apiFunctionId} » n\'est pas déployée sur Appwrite.'
            : 'Appwrite a refusé l\'appel (code ${error.code}).',
        code: 'EXECUTION_FAILED',
      );
    } on MessagingException {
      rethrow;
    } catch (error) {
      // Tout ce qui n'est pas une AppwriteException — réseau coupé, TLS refusé,
      // réponse illisible — remontait tel quel jusqu'à l'écran, qui n'affichait
      // qu'un « Bad state: No element » sans la moindre piste. On le traduit
      // ici, en gardant le texte d'origine pour le diagnostic.
      throw MessagingException(
        'La messagerie est injoignable ($error).',
        code: 'UNREACHABLE',
      );
    }

    final data = decodeExecutionPayload(execution);
    if (data.isEmpty) {
      throw MessagingException(
        'La messagerie a répondu de façon inattendue '
        '(statut ${execution['status'] ?? 'inconnu'}).',
        code: 'BAD_RESPONSE',
      );
    }
    if (data['ok'] != true) {
      throw MessagingException(
        data['message'] ?? 'La messagerie a échoué.',
        code: data['code'] ?? '',
      );
    }
    return data;
  }

  Future<List<Conversation>> getConversations() async =>
      (await getConversationsJson()).map(Conversation.fromJson).toList();

  /// Même liste, en JSON brut : c'est cette forme que le cache hors ligne
  /// conserve, pour la relire avec `Conversation.fromJson` sans réseau.
  Future<List<Map<String, dynamic>>> getConversationsJson() async {
    final data = await _invoke({'action': 'list'});
    final list = data['conversations'];
    if (list is! List) return const [];
    return list.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }

  /// Retrouve des contacts par pseudo, nom ou email (au moins deux caractères).
  Future<List<ChatContact>> searchContacts(String query) async {
    final term = query.trim().replaceFirst(RegExp(r'^@'), '');
    if (term.length < 2) return const [];
    final data = await _invoke({'action': 'search', 'query': term});
    final list = data['contacts'];
    if (list is! List) return const [];
    return list.whereType<Map>().map((item) => ChatContact.fromJson(Map<String, dynamic>.from(item))).toList();
  }

  /// Ouvre — en la créant au besoin — la conversation avec un pseudo.
  Future<Conversation> openByUsername(String username) async {
    final data = await _invoke({
      'action': 'open',
      'username': username.trim().replaceFirst(RegExp(r'^@'), ''),
    });
    final conversation = data['conversation'];
    if (conversation is! Map) {
      throw MessagingException('Conversation illisible.');
    }
    return Conversation.fromJson(Map<String, dynamic>.from(conversation));
  }

  /// Marque comme lus les messages reçus et renvoie le nombre effectivement
  /// mis à jour.
  Future<int> markRead(String conversationId) async {
    final data = await _invoke({'action': 'read', 'conversationId': conversationId});
    return data['markedRead'] ?? 0;
  }

  /// Envoie un message et renvoie la conversation à jour.
  ///
  /// [fileId] référence une pièce jointe déjà téléversée par
  /// [uploadAttachment] ; le texte peut alors être vide, la fonction
  /// retombant sur le nom du fichier.
  Future<bool> sendMessage(
    String conversationId,
    String text, {
    String fileId = '',
    bool urgent = false,
  }) async {
    final data = await _invoke({
      'action': 'send',
      'conversationId': conversationId,
      'text': text,
      if (fileId.isNotEmpty) 'fileId': fileId,
      if (urgent) 'urgent': true,
    });
    final conversation = data['conversation'];
    if (conversation is! Map) {
      throw MessagingException('Message envoyé, mais la conversation est illisible.');
    }
    _lastUpdate = Conversation.fromJson(Map<String, dynamic>.from(conversation));
    // `send` renvoie aussi `notified` : vrai lorsque le destinataire a
    // effectivement reçu une notification. L'appelant peut ainsi distinguer
    // « envoyé » de « envoyé et signalé ».
    return data['notified'] == true;
  }

  /// Dernière conversation reçue en réponse à un envoi.
  Conversation? _lastUpdate;
  Conversation? get lastUpdate => _lastUpdate;

  /// Téléverse une pièce jointe dans le bucket unique `uniflow_assets`.
  ///
  /// **Le fichier n'est lisible que par son auteur à ce stade**, et c'est
  /// délibéré : Appwrite refuse qu'un client accorde une permission à un
  /// autre utilisateur. Le serveur répond
  /// « Permissions must be one of: (any, users, user:<soi>, …) », code 401, dès
  /// qu'on demande `read("user:<autre>")`. La lecture au destinataire est donc
  /// accordée par le service `/messaging`, au moment de l'envoi du message.
  /// Demander ici la permission du correspondant faisait échouer tout
  /// téléversement, et l'utilisateur voyait « Session expirée pendant le
  /// téléversement », qui n'a rien à voir.
  ///
  /// Le téléversement passe par [AppwriteService.uploadFile], comme le change-
  /// ment de photo de profil : on ne lit que `$id` de la réponse, pour qu'un
  /// fichier bien déposé ne s'affiche jamais comme un échec.
  Future<String> uploadAttachment({
    required String conversationId,
    required String myUserId,
    required String path,
    required String fileName,
  }) async {
    final size = await File(path).length();
    if (size > chatAttachmentMaxBytes) {
      throw MessagingException(
        'Fichier trop volumineux : ${_readableBytes(size)} pour une limite de '
        '${_readableBytes(chatAttachmentMaxBytes)}.',
        code: 'ATTACHMENT_TOO_LARGE',
      );
    }

    try {
      return await _service.uploadFile(
        bucketId: _service.chatFilesBucketId,
        file: InputFile.fromPath(path: path, filename: fileName),
        permissions: [
          Permission.read(Role.user(myUserId)),
          // Sans `update` ni `delete` pour l'expéditeur, un fichier envoyé par
          // erreur resterait à jamais dans le bucket : personne ne pourrait
          // le retirer, la Function n'ayant pas non plus à le faire.
          Permission.update(Role.user(myUserId)),
          Permission.delete(Role.user(myUserId)),
        ],
      );
    } on AppwriteException catch (error) {
      throw MessagingException(_uploadMessage(error), code: 'UPLOAD_FAILED');
    }
  }

  /// Lit les octets d'une pièce jointe, pour l'afficher ou l'enregistrer.
  Future<Uint8List> downloadAttachment(String fileId) async {
    try {
      return await _service.storage.getFileDownload(
        bucketId: _service.chatFilesBucketId,
        fileId: fileId,
      );
    } on AppwriteException catch (error) {
      throw MessagingException(
        error.code == 404
            ? 'Ce fichier a été retiré de la conversation.'
            : 'Le téléchargement a échoué (code ${error.code}).',
        code: 'DOWNLOAD_FAILED',
      );
    }
  }

  /// Octets d'un aperçu d'image, redimensionné par Appwrite.
  ///
  /// Passer par l'aperçu plutôt que par le fichier d'origine évite de
  /// télécharger une photo de 12 Mpx pour l'afficher en 220 px de large.
  Future<Uint8List> attachmentPreview(String fileId, {int width = 640}) async {
    try {
      return await _service.storage.getFilePreview(
        bucketId: _service.chatFilesBucketId,
        fileId: fileId,
        width: width,
        quality: 80,
      );
    } on AppwriteException catch (error) {
      throw MessagingException(
        'Aperçu indisponible (code ${error.code}).',
        code: 'PREVIEW_FAILED',
      );
    }
  }

  /// Notifications de l'utilisateur courant, les plus récentes d'abord.
  Future<List<AppNotification>> getNotifications() async =>
      (await getNotificationsJson()).map(AppNotification.fromJson).toList();

  Future<List<Map<String, dynamic>>> getNotificationsJson() async {
    final data = await _invoke({'action': 'notifications'});
    final list = data['notifications'];
    if (list is! List) return const [];
    return list.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }

  /// Marque une notification comme lue, ou toutes si [notificationId] est vide.
  Future<int> markNotificationsRead({String notificationId = ''}) async {
    final data = await _invoke({
      'action': 'notificationsRead',
      if (notificationId.isNotEmpty) 'notificationId': notificationId,
    });
    return data['markedRead'] ?? 0;
  }

  String _uploadMessage(AppwriteException error) {
    switch (error.code) {
      case 401:
        return 'Session expirée pendant le téléversement. Reconnectez-vous.';
      case 403:
        return 'Ce compte n\'est pas autorisé à envoyer des fichiers.';
      case 404:
        return 'Le bucket « ${_service.chatFilesBucketId} » est introuvable sur Appwrite.';
      case 413:
      case 400:
        // Appwrite refuse au-delà de `_APP_STORAGE_LIMIT` avec un 400 dont le
        // texte parle de « maximumFileSize » : le message brut n'aide pas.
        return 'Fichier refusé par Appwrite : il dépasse la taille maximale '
            'autorisée par le serveur (${_readableBytes(chatAttachmentMaxBytes)}).';
      default:
        return 'Le téléversement a échoué (code ${error.code}).';
    }
  }
}

/// Taille maximale d'une pièce jointe.
///
/// Le serveur Appwrite plafonne tout fichier à `_APP_STORAGE_LIMIT`, qui vaut
/// 30 000 000 octets par défaut — et non 50 Mo. Relever cette limite demande de
/// modifier le `.env` du serveur puis de le redémarrer ; d'ici là, annoncer
/// 50 Mo produirait un refus côté serveur après un téléversement complet.
const int chatAttachmentMaxBytes = 30 * 1000 * 1000;

String _readableBytes(int bytes) {
  if (bytes < 1024) return '$bytes o';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} ko';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
}

/// Extrait la charge utile JSON d'un document d'exécution Appwrite.
///
/// Le serveur renvoie la réponse de la Function sous forme de **chaîne** dans
/// `responseBody`, à l'intérieur du document d'exécution. Fonction pure, donc
/// testable sans réseau ni client Appwrite : c'est ce qui permet de vérifier
/// qu'un document d'exécution réel — celui d'Appwrite 1.6.1, sans
/// `resourceType` — est lu sans erreur.
///
/// Rend une map vide lorsque le corps est absent ou n'est pas du JSON, ce que
/// l'appelant traduit en `BAD_RESPONSE`.
///
/// L'implémentation vit dans `AppwriteService` : le forum exécute lui aussi des
/// Functions et doit analyser la même forme de réponse.
Map<String, dynamic> decodeExecutionPayload(Map<String, dynamic> execution) => decodeFunctionPayload(execution);

/// Identifiant du fichier dans la réponse de téléversement, ou `null` si elle
/// est illisible.
///
/// La fonction vit désormais dans `data/appwrite_service.dart`, avec les autres
/// contournements du SDK : le téléversement d'une pièce jointe et celui d'une
/// photo de profil butaient sur le même `File.fromMap`. Elle est ré-exportée en
/// tête de fichier pour que les appelants historiques — et les tests — n'aient
/// pas à changer d'import.

final messagingRepositoryProvider = Provider<MessagingRepository>((ref) {
  final service = ref.watch(appwriteServiceProvider);
  return MessagingRepository(service);
});

/// Liste des conversations : cache local d'abord, puis la Function.
final conversationsProvider = StreamProvider<List<Conversation>>((ref) {
  final repo = ref.watch(messagingRepositoryProvider);
  return cachedJsonList<Conversation>(
    ref,
    collection: 'chat_conversations',
    fetch: repo.getConversationsJson,
    fromJson: Conversation.fromJson,
  );
});
