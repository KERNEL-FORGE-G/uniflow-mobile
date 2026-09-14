import 'package:appwrite/appwrite.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
}
