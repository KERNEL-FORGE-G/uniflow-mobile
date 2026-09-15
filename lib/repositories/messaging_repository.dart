import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:appwrite/appwrite.dart';
// `HttpMethod` n'est pas ré-exporté par `appwrite.dart` — il vit dans
// `src/enums.dart`. Cet import d'implémentation est un compromis assumé :
// `client.call` est le seul moyen d'exécuter une Function sans passer par le
// modèle `Execution`, qui est cassé face à ce serveur (voir `_execute`).
// ignore: implementation_imports
import 'package:appwrite/src/enums.dart' show HttpMethod;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/appwrite_service.dart';
import '../providers/appwrite_provider.dart';

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
          ? rawMessages
              .whereType<Map>()
              .map((item) => ChatMessage.fromJson(Map<String, dynamic>.from(item)))
              .toList()
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
  static const String functionId = 'messaging';

  MessagingRepository(this._service);

  /// Exécute la Function et renvoie le document d'exécution brut du serveur.
  ///
  /// **Ne pas revenir à `functions.createExecution`.** Le SDK Dart 26.2.0 vise
  /// Appwrite 2.0.x, alors que le serveur est en 1.6.1, qui ne renvoie pas de
  /// champ `resourceType` dans le document d'exécution. Or
  /// `Execution.fromMap` fait
  /// `ExecutionResourceType.values.firstWhere((e) => e.value == map['resourceType'])`
  /// — un `firstWhere` **sans `orElse`**, qui lève donc
  /// « Bad state: No element » sur *chaque* appel, quelle que soit la Function.
  /// Ce `StateError` n'est pas une `AppwriteException` : `_invoke` le laissait
  /// remonter brut et l'écran Messagerie affichait « Messagerie indisponible ».
  /// C'était le symptôme, et non la Function elle-même, qui répondait
  /// pourtant `ok:true` sur les huit comptes réels.
  ///
  /// `client.call` garde tout ce que le SDK apporte — session, en-têtes de
  /// projet, intercepteurs — et rend le JSON tel quel, sans le désérialiser.
  Future<Map<String, dynamic>> _execute(Map<String, dynamic> payload) async {
    final response = await _service.client.call(
      HttpMethod.post,
      path: '/functions/$functionId/executions',
      headers: {
        // `X-Appwrite-Project` doit être reposé à **chaque** requête :
        // `Client.setProject` ne fait que mémoriser `config['project']` et
        // n'ajoute aucun en-tête. Sans lui, Appwrite ne résout pas le projet et
        // refuse l'exécution en 403 — observé sur l'appareil, alors que le même
        // appel avec session répond 201. La session, elle, voyage par le
        // cookie géré par le client.
        'X-Appwrite-Project': _service.client.config['project'] ?? '',
        'content-type': 'application/json',
        'accept': 'application/json',
      },
      // Le corps de la Function voyage comme une *chaîne* dans le champ
      // `body`, exactement comme le faisait `createExecution`.
      params: {'body': jsonEncode(payload), 'async': false},
    );
    final data = response.data;
    if (data is! Map) {
      throw MessagingException(
        'La messagerie a répondu dans un format inattendu.',
        code: 'BAD_RESPONSE',
      );
    }
    return Map<String, dynamic>.from(data);
  }

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
            ? 'La fonction « messaging » n\'est pas déployée sur Appwrite.'
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

  Future<List<Conversation>> getConversations() async {
    final data = await _invoke({'action': 'list'});
    final list = data['conversations'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((item) => Conversation.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  /// Retrouve des contacts par pseudo, nom ou email (au moins deux caractères).
  Future<List<ChatContact>> searchContacts(String query) async {
    final term = query.trim().replaceFirst(RegExp(r'^@'), '');
    if (term.length < 2) return const [];
    final data = await _invoke({'action': 'search', 'query': term});
    final list = data['contacts'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((item) => ChatContact.fromJson(Map<String, dynamic>.from(item)))
        .toList();
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

  /// Téléverse une pièce jointe dans le bucket des fichiers de discussion.
  ///
  /// **Le fichier n'est lisible que par son auteur à ce stade**, et c'est
  /// délibéré : Appwrite 1.6.1 refuse qu'un client accorde une permission à un
  /// autre utilisateur. Le serveur répond
  /// « Permissions must be one of: (any, users, user:<soi>, …) », code 401, dès
  /// qu'on demande `read("user:<autre>")`. La lecture au destinataire est donc
  /// accordée par la Function, au moment de l'envoi du message — voir l'action
  /// `send` de `functions/messaging/src/main.js`. Demander ici la permission du
  /// correspondant faisait échouer tout téléversement, et l'utilisateur voyait
  /// « Session expirée pendant le téléversement », qui n'a rien à voir.
  ///
  /// Le téléversement passe par `chunkedUpload` plutôt que par
  /// `storage.createFile` pour la même raison que `_execute` : `File.fromMap`
  /// du SDK 26.2.0 réclame `sizeActual`, que ce serveur ne renvoie pas, et
  /// lève « type 'Null' is not a subtype of type 'int' » alors que le fichier
  /// est bel et bien déposé. Seul `$id` nous intéresse ici.
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

    final fileId = ID.unique();
    final Object? raw;
    try {
      final response = await _service.client.chunkedUpload(
        path: '/storage/buckets/${_service.chatFilesBucketId}/files',
        params: {
          'fileId': fileId,
          'file': InputFile.fromPath(path: path, filename: fileName),
          'permissions': [
            Permission.read(Role.user(myUserId)),
            // Sans `update` ni `delete` pour l'expéditeur, un fichier envoyé par
            // erreur resterait à jamais dans le bucket : personne ne pourrait
            // le retirer, la Function n'ayant pas non plus à le faire.
            Permission.update(Role.user(myUserId)),
            Permission.delete(Role.user(myUserId)),
          ],
        },
        paramName: 'file',
        idParamName: 'fileId',
        headers: {
          'X-Appwrite-Project': _service.client.config['project'] ?? '',
          'content-type': 'multipart/form-data',
          'accept': 'application/json',
        },
      );
      raw = response.data;
    } on AppwriteException catch (error) {
      throw MessagingException(_uploadMessage(error), code: 'UPLOAD_FAILED');
    }

    final uploadedId = decodeUploadedFileId(raw);
    if (uploadedId == null) {
      throw MessagingException(
        'Le fichier a été téléversé, mais le serveur a répondu dans un format inattendu.',
        code: 'UPLOAD_BAD_RESPONSE',
      );
    }
    return uploadedId;
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
  Future<List<AppNotification>> getNotifications() async {
    final data = await _invoke({'action': 'notifications'});
    final list = data['notifications'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((item) => AppNotification.fromJson(Map<String, dynamic>.from(item)))
        .toList();
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
        return 'Le bucket « ${_service.chatFilesBucketId} » est introuvable. '
            'Lancez scripts/provision-appwrite-selfhosted.mjs.';
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
Map<String, dynamic> decodeExecutionPayload(Map<String, dynamic> execution) {
  final raw = execution['responseBody'];
  if (raw is! String || raw.trim().isEmpty) return const {};
  try {
    final decoded = jsonDecode(raw);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : const {};
  } on FormatException {
    return const {};
  }
}

/// Identifiant du fichier dans la réponse de téléversement, ou `null` si elle
/// est illisible.
///
/// Fonction pure, donc testable sans réseau : c'est elle qui remplace
/// `File.fromMap` du SDK. Appwrite 1.6.1 renvoie
/// `$id, bucketId, $createdAt, $updatedAt, $permissions, name, signature,
/// mimeType, sizeOriginal, chunksTotal, chunksUploaded` — et **pas**
/// `sizeActual`, que le modèle du SDK 26.2.0 déclare `int` non nullable. Le
/// passer au modèle lève « type 'Null' is not a subtype of type 'int' » alors
/// que le fichier est bel et bien déposé : l'utilisateur voyait un échec de
/// téléversement pour un fichier existant.
String? decodeUploadedFileId(Object? data) {
  if (data is! Map) return null;
  final id = data[r'$id'];
  return id is String && id.isNotEmpty ? id : null;
}

final messagingRepositoryProvider = Provider<MessagingRepository>((ref) {
  final service = ref.watch(appwriteServiceProvider);
  return MessagingRepository(service);
});

/// Liste des conversations, rechargée à la demande.
final conversationsProvider = FutureProvider<List<Conversation>>((ref) {
  return ref.watch(messagingRepositoryProvider).getConversations();
});
