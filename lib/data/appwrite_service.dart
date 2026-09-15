import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
// `HttpMethod` n'est pas ré-exporté par `appwrite.dart` — il vit dans
// `src/enums.dart`. Cet import d'implémentation est un compromis assumé :
// `client.call` est le seul moyen d'exécuter une Function sans passer par le
// modèle `Execution`, qui est cassé face à ce serveur (voir `executeFunction`).
// ignore: implementation_imports
import 'package:appwrite/src/enums.dart' show HttpMethod;

/// Extrait la charge utile JSON d'un document d'exécution Appwrite.
///
/// Le serveur renvoie la réponse de la Function sous forme de **chaîne** dans
/// `responseBody`, à l'intérieur du document d'exécution. Fonction pure, donc
/// testable sans réseau ni client Appwrite.
///
/// Rend une map vide lorsque le corps est absent ou n'est pas du JSON, ce que
/// l'appelant traduit en réponse illisible.
Map<String, dynamic> decodeFunctionPayload(Map<String, dynamic> execution) {
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
/// que le fichier est bel et bien déposé : l'utilisateur voit un échec de
/// téléversement pour un fichier existant. C'est ce que produisaient aussi bien
/// l'envoi d'une pièce jointe que le changement de photo de profil.
String? decodeUploadedFileId(Object? data) {
  if (data is! Map) return null;
  final id = data[r'$id'];
  return id is String && id.isNotEmpty ? id : null;
}

class AppwriteService {
  late Client client;
  late Account account;
  late Databases databases;
  late Storage storage;
  late Functions functions;
  late String databaseId;
  late String storageBucketId;

  /// Bucket des photos de profil, distinct de [storageBucketId] : il est lisible
  /// publiquement, puisqu'un avatar doit s'afficher sans session ouverte.
  late String avatarBucketId;

  /// Bucket des pièces jointes de discussion.
  ///
  /// Séparé des deux autres : ses fichiers sont privés (lus par les seuls
  /// participants de la conversation) et il autorise tous les types de fichier,
  /// là où `uniflow_assets` filtre les extensions.
  late String chatFilesBucketId;

  AppwriteService() {
    client = Client()
        .setEndpoint(dotenv.get('APPWRITE_ENDPOINT'))
        .setProject(dotenv.get('APPWRITE_PROJECT_ID'))
        .setSelfSigned(status: true);

    account = Account(client);
    databases = Databases(client);
    storage = Storage(client);
    functions = Functions(client);
    databaseId = dotenv.get('APPWRITE_DATABASE_ID');
    storageBucketId = dotenv.get('APPWRITE_STORAGE_BUCKET_ID');
    // `maybeGet` : une `.env` antérieure à l'ajout de la variable ne doit pas
    // faire échouer le démarrage de l'application.
    // La valeur de repli est l'identifiant réel du bucket, pas son nom : le
    // bucket a été créé sous `6aa81b840031e6a34dc3`, et chercher
    // « uniflow_avatars » renvoyait un 404 à chaque lecture de photo.
    avatarBucketId = dotenv.maybeGet('APPWRITE_AVATAR_BUCKET_ID') ?? '6aa81b840031e6a34dc3';
    // Ici le nom et l'identifiant coïncident : le bucket a été créé par
    // scripts/appwrite-schema.mjs, qui fixe `bucketId: 'uniflow_chat_files'`.
    chatFilesBucketId =
        dotenv.maybeGet('APPWRITE_CHAT_FILES_BUCKET_ID') ?? 'uniflow_chat_files';
  }

  /// Exécute une Function Appwrite et rend le document d'exécution brut.
  ///
  /// Passe par `client.call` plutôt que par `functions.createExecution` : le
  /// SDK Dart 26.2.0 vise Appwrite 2.0.x, et son `Execution.fromMap` réclame
  /// `resourceType`, que ce serveur 1.6.1 ne renvoie pas. Chaque appel levait
  /// donc « Bad state: No element », et l'écran Messagerie restait vide quel
  /// que soit l'état du serveur.
  ///
  /// `X-Appwrite-Project` est reposé explicitement : `setProject` ne fait que
  /// mémoriser la valeur, chaque service du SDK la repasse lui-même — l'omettre
  /// fait répondre 403.
  Future<Map<String, dynamic>> executeFunction(
    String functionId,
    Map<String, dynamic> payload,
  ) async {
    final response = await client.call(
      HttpMethod.post,
      path: '/functions/$functionId/executions',
      headers: {
        'X-Appwrite-Project': client.config['project'] ?? '',
        'content-type': 'application/json',
        'accept': 'application/json',
      },
      params: {'body': jsonEncode(payload), 'async': false},
    );
    final data = response.data;
    if (data is! Map) return const {};
    return Map<String, dynamic>.from(data);
  }

  /// Téléverse un fichier dans un bucket et rend l'identifiant du fichier créé.
  ///
  /// Passe par `client.chunkedUpload` plutôt que par `storage.createFile`, pour
  /// la même raison que [executeFunction] contourne `createExecution` :
  /// `File.fromMap` du SDK 26.2.0 réclame `sizeActual`, que ce serveur ne
  /// renvoie pas, et lève « type 'Null' is not a subtype of type 'int' » alors
  /// que le fichier est bien déposé. Seul `$id` nous intéresse.
  ///
  /// Le `content-type` multipart est posé par `chunkedUpload` lui-même : le
  /// forcer à `application/json` ferait répondre à Appwrite « Param "fileId"
  /// is not optional », puisqu'il ne verrait alors aucun champ.
  Future<String> uploadFile({
    required String bucketId,
    required InputFile file,
    required List<String> permissions,
  }) async {
    final fileId = ID.unique();
    final response = await client.chunkedUpload(
      path: '/storage/buckets/$bucketId/files',
      params: {
        'fileId': fileId,
        'file': file,
        'permissions': permissions,
      },
      paramName: 'file',
      idParamName: 'fileId',
      headers: {
        'X-Appwrite-Project': client.config['project'] ?? '',
        'content-type': 'multipart/form-data',
        'accept': 'application/json',
      },
    );
    final uploadedId = decodeUploadedFileId(response.data);
    if (uploadedId == null) {
      // Positionnels : `AppwriteException([message, code, type, response])`.
      throw AppwriteException(
        'Le fichier a été téléversé, mais le serveur a répondu dans un format inattendu.',
        500,
        'upload_bad_response',
      );
    }
    return uploadedId;
  }
}
