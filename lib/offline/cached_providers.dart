import 'package:appwrite/models.dart' as models;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import 'document_cache.dart';
import 'local_database.dart';
import 'offline_providers.dart';

/// Liste « cache d'abord » construite à partir de documents Appwrite.
///
/// Le cache est lu pour le compte connecté, puis le réseau est interrogé ;
/// les documents frais sont rangés (fusion par identifiant, jamais de purge :
/// la synchronisation delta et l'écran écrivent dans la même table). Hors
/// ligne avec un cache, l'écran s'affiche sans erreur ; hors ligne sans
/// cache, l'erreur réseau remonte comme avant.
Stream<List<T>> cachedDocumentList<T>(
  Ref ref, {
  required String collection,
  required Future<List<models.Document>> Function() fetch,
  required T Function(models.Document) fromDocument,
  List<T> Function(List<T> items)? select,
  bool replace = false,
}) {
  final owner = ref.read(currentUserProvider)?.id ?? '';
  final db = ref.read(localDatabaseProvider);
  List<T> shape(Iterable<models.Document> docs) {
    final items = docs.map(fromDocument).toList();
    return select == null ? items : select(items);
  }

  return cacheFirst<List<T>>(
    readCache: () async {
      if (owner.isEmpty) return null;
      final cached = await db.documents(collection, owner: owner);
      if (cached.isEmpty) return null;
      return shape(cached.map(restoreDocument));
    },
    fetch: () async => shape(await _storeAfter(fetch, db, collection, owner, replace: replace)),
    store: (_) async {},
  );
}

Future<List<models.Document>> _storeAfter(
  Future<List<models.Document>> Function() fetch,
  LocalDatabase db,
  String collection,
  String owner, {
  required bool replace,
}) async {
  final docs = await fetch();
  if (owner.isNotEmpty) {
    final cached = docs.map((d) => cacheDocument(d));
    try {
      if (replace) {
        await db.replaceCollection(collection, owner, cached);
      } else {
        await db.upsertDocuments(collection, owner, cached);
      }
    } catch (_) {
      // Une base locale indisponible (tests, stockage plein) ne doit pas
      // priver l'écran de la réponse réseau.
    }
  }
  return docs;
}

/// Même principe pour une réponse de Function (liste de JSON, pas des
/// documents) : conversations, notifications, annuaire. La liste fraîche
/// remplace la précédente, puisque c'est l'état complet.
Stream<List<T>> cachedJsonList<T>(
  Ref ref, {
  required String collection,
  required Future<List<Map<String, dynamic>>> Function() fetch,
  required T Function(Map<String, dynamic>) fromJson,
  String Function(Map<String, dynamic>)? idOf,
}) {
  final owner = ref.read(currentUserProvider)?.id ?? '';
  final db = ref.read(localDatabaseProvider);
  String id(Map<String, dynamic> json) => idOf?.call(json) ?? json['id']?.toString() ?? json['\$id']?.toString() ?? '';

  return cacheFirst<List<T>>(
    readCache: () async {
      if (owner.isEmpty) return null;
      final cached = await db.documents(collection, owner: owner);
      if (cached.isEmpty) return null;
      return cached.map((c) => fromJson(c.data)).toList();
    },
    fetch: () async {
      final maps = await fetch();
      if (owner.isNotEmpty) {
        try {
          await db.replaceCollection(
            collection,
            owner,
            maps.map((m) => CachedDocument(id: id(m), data: m, updatedAt: m['time']?.toString() ?? '')),
          );
        } catch (_) {}
      }
      return maps.map(fromJson).toList();
    },
    store: (_) async {},
  );
}
