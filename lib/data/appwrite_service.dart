import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
// `HttpMethod` n'est pas ré-exporté par `appwrite.dart` — il vit dans
// `src/enums.dart`. Cet import d'implémentation est un compromis assumé :
// `client.call` est le seul moyen d'exécuter une Function en lisant le JSON
// brut, sans dépendre du modèle `Execution` du SDK (voir `executeFunction`).
// ignore: implementation_imports
import 'package:appwrite/src/enums.dart' show HttpMethod;

/// Identifiant par défaut de l'unique Function HTTP du projet.
///
/// Sur Appwrite Cloud (offre gratuite), les neuf anciennes Functions ont été
/// fondues en un seul routeur : c'est le champ `path` de l'exécution qui
/// choisit le service (`/messaging`, `/forum-reactions`…).
const String defaultApiFunctionId = 'uniflow-api';

/// Bucket unique du projet : photos de profil, documents et pièces jointes y
/// cohabitent, les droits étant posés fichier par fichier.
const String defaultBucketId = 'uniflow_assets';

/// Paramètres à envoyer à `POST /functions/<id>/executions` pour atteindre le
/// service [servicePath] du routeur avec la charge [payload].
///
/// Fonction pure, testée sans réseau : c'est le contrat entre le mobile et le
/// routeur. Sans `path`, le routeur répond 404 « service inconnu » et l'écran
/// Messagerie affichait « Messagerie indisponible » alors que le serveur
/// fonctionnait — c'est exactement ce que la migration vers le Cloud a produit
/// tant que le mobile appelait encore `/functions/messaging/executions`.
Map<String, dynamic> routerExecutionParams(
  String servicePath,
  Map<String, dynamic> payload,
) {
  return {
    'body': jsonEncode(payload),
    'async': false,
    'method': 'POST',
    'path': normalizeServicePath(servicePath),
    // Même en-tête que le web (`src/lib/appwrite.ts#executeService`) : c'est
    // lui qui fait renseigner `req.bodyJson` côté Function.
    'headers': {'content-type': 'application/json'},
  };
}

/// Chemin de service normalisé : toujours une barre oblique initiale, jamais
/// de barre finale. `messaging`, `/messaging` et `/messaging/` désignent le
/// même service — le routeur (`uniflow-api/src/main.js`) fait la même
/// normalisation, on l'applique ici pour ne pas dépendre de sa tolérance.
String normalizeServicePath(String servicePath) {
  var path = servicePath.trim();
  if (!path.startsWith('/')) path = '/$path';
  while (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  return path;
}

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
/// Fonction pure, donc testable sans réseau. Elle ne lit que `$id` : c'est le
/// seul champ dont l'application a besoin, et ne pas passer par `File.fromMap`
/// nous a déjà évité un plantage quand le serveur ne renvoyait pas tous les
/// champs que le modèle du SDK déclarait obligatoires (`sizeActual`, avant la
/// migration). Un fichier bel et bien déposé ne doit jamais s'afficher comme
/// un échec de téléversement.
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
  late Realtime realtime;
  late String databaseId;

  /// Identifiant de la Function routeur (`APPWRITE_API_FUNCTION_ID`).
  late String apiFunctionId;

  /// Bucket des documents (bibliothèque, énoncés de devoirs).
  late String storageBucketId;

  /// Bucket des photos de profil. Sur le Cloud c'est le même que
  /// [storageBucketId] : ce qui rend un avatar public, c'est le `read("any")`
  /// posé sur le fichier, pas un bucket à part.
  late String avatarBucketId;

  /// Bucket des pièces jointes de discussion — même bucket, fichiers privés
  /// (`read("user:<id>")` pour chaque participant).
  late String chatFilesBucketId;

  AppwriteService() {
    // Pas de `setSelfSigned` : Appwrite Cloud présente un certificat valide,
    // et accepter n'importe quel certificat rendrait l'application vulnérable
    // à une interception sur un réseau public — pour un gain nul.
    client = Client()
        .setEndpoint(dotenv.get('APPWRITE_ENDPOINT'))
        .setProject(dotenv.get('APPWRITE_PROJECT_ID'));

    account = Account(client);
    databases = Databases(client);
    storage = Storage(client);
    functions = Functions(client);
    realtime = Realtime(client);
    databaseId = dotenv.get('APPWRITE_DATABASE_ID');
    // `maybeGet` : une `.env` antérieure à l'ajout d'une variable ne doit pas
    // faire échouer le démarrage de l'application ; les valeurs de repli sont
    // celles du schéma (`uniflow-we/scripts/appwrite-schema.mjs`).
    apiFunctionId =
        dotenv.maybeGet('APPWRITE_API_FUNCTION_ID') ?? defaultApiFunctionId;
    storageBucketId =
        dotenv.maybeGet('APPWRITE_STORAGE_BUCKET_ID') ?? defaultBucketId;
    avatarBucketId =
        dotenv.maybeGet('APPWRITE_AVATAR_BUCKET_ID') ?? storageBucketId;
    chatFilesBucketId =
        dotenv.maybeGet('APPWRITE_CHAT_FILES_BUCKET_ID') ?? storageBucketId;
  }

  /// Exécute un service du routeur `uniflow-api` et rend le document
  /// d'exécution brut.
  ///
  /// [servicePath] est le chemin du service (`/messaging`,
  /// `/attendance-secure`…) ; [payload] est le JSON que le service lit dans le
  /// corps de la requête.
  ///
  /// Passe par `client.call` plutôt que par `functions.createExecution` : on
  /// garde ainsi tout ce que le SDK apporte — session, en-têtes de projet,
  /// intercepteurs — sans passer par `Execution.fromMap`, dont une version a
  /// déjà levé « Bad state: No element » sur un champ que le serveur ne
  /// renvoyait pas. Lire le JSON tel quel nous rend indépendants de
  /// l'alignement exact entre la version du SDK et celle du serveur.
  ///
  /// `X-Appwrite-Project` est reposé explicitement : `setProject` ne fait que
  /// mémoriser la valeur, chaque service du SDK la repasse lui-même — l'omettre
  /// fait répondre 403.
  Future<Map<String, dynamic>> executeFunction(
    String servicePath,
    Map<String, dynamic> payload,
  ) async {
    final response = await client.call(
      HttpMethod.post,
      path: '/functions/$apiFunctionId/executions',
      headers: {
        'X-Appwrite-Project': client.config['project'] ?? '',
        'content-type': 'application/json',
        'accept': 'application/json',
      },
      params: routerExecutionParams(servicePath, payload),
    );
    final data = response.data;
    if (data is! Map) return const {};
    return Map<String, dynamic>.from(data);
  }

  /// Exécute un service du routeur et rend directement sa charge utile JSON.
  ///
  /// Le corps est analysé même lorsque le statut d'exécution n'est pas
  /// `completed` : Appwrite marque l'exécution en échec dès que la Function
  /// répond 4xx, alors que le corps contient justement le message explicite
  /// à montrer à l'utilisateur.
  Future<Map<String, dynamic>> callService(
    String servicePath,
    Map<String, dynamic> payload,
  ) async {
    final execution = await executeFunction(servicePath, payload);
    return decodeFunctionPayload(execution);
  }

  /// Téléverse un fichier dans un bucket et rend l'identifiant du fichier créé.
  ///
  /// Passe par `client.chunkedUpload` plutôt que par `storage.createFile`, pour
  /// la même raison que [executeFunction] contourne `createExecution` : seul
  /// `$id` nous intéresse, et lire la réponse brute évite qu'un fichier bien
  /// déposé s'affiche comme un échec parce qu'un champ du modèle manque.
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

  /// URL publique d'un fichier du bucket, lisible sans en-tête de session par
  /// un `Image.network` (ce qui suppose `read("any")` sur le fichier).
  String fileViewUrl(String fileId, {String? bucketId}) {
    final endpoint = client.endPoint.replaceAll(RegExp(r'/+$'), '');
    final project = client.config['project'] ?? '';
    return '$endpoint/storage/buckets/${bucketId ?? storageBucketId}/files/$fileId/view?project=$project';
  }
}
