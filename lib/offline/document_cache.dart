import 'dart:async';

import 'package:appwrite/models.dart' as models;

import 'local_database.dart';

/// Passerelle entre les documents Appwrite et le cache local.
///
/// On conserve `toMap()` en entier pour que `models.Document.fromMap`
/// reconstruise un document identique : les `fromDocument` des modèles
/// servent tels quels, en ligne comme hors ligne.
CachedDocument cacheDocument(models.Document doc, {bool pending = false}) => CachedDocument(
      id: doc.$id,
      data: doc.toMap(),
      updatedAt: doc.$updatedAt,
      createdAt: doc.$createdAt,
      pending: pending,
    );

models.Document restoreDocument(CachedDocument cached) => models.Document.fromMap(cached.data);

/// Document fabriqué localement pour une écriture hors ligne : il apparaît
/// dans les listes avec le marquage « en attente d'envoi » jusqu'au rejeu.
CachedDocument localDocument({
  required String id,
  required String collection,
  required Map<String, dynamic> fields,
  required DateTime now,
}) {
  final stamp = now.toUtc().toIso8601String();
  return CachedDocument(
    id: id,
    // `$updatedAt` local volontairement vide : un delta le comparerait à un
    // horodatage serveur, et l'heure du téléphone ne fait pas foi.
    data: {
      '\$id': id,
      '\$sequence': '',
      '\$collectionId': collection,
      '\$databaseId': '',
      '\$createdAt': stamp,
      '\$updatedAt': '',
      '\$permissions': const <String>[],
      'data': fields,
    },
    createdAt: stamp,
    pending: true,
  );
}

/// Lecture « cache d'abord, puis réseau ».
///
/// Émet immédiatement la valeur du cache si elle existe (l'écran s'affiche
/// sans attendre), puis la valeur fraîche quand le réseau répond — et la
/// range dans le cache. Si le réseau échoue **et** que le cache avait répondu,
/// l'erreur est avalée : l'utilisateur voit ses données, pas une bannière
/// rouge, c'est le principe du mode hors ligne. Sans cache, l'erreur remonte.
Stream<T> cacheFirst<T>({
  required Future<T?> Function() readCache,
  required Future<T> Function() fetch,
  required Future<void> Function(T fresh) store,
  bool Function(T cached)? isUsable,
}) async* {
  T? cached;
  try {
    cached = await readCache();
  } catch (_) {
    cached = null;
  }
  final usable = cached != null && (isUsable?.call(cached) ?? true);
  if (usable) yield cached as T;
  try {
    final fresh = await fetch();
    unawaited(store(fresh).catchError((_) {}));
    yield fresh;
  } catch (error) {
    if (!usable) rethrow;
  }
}
