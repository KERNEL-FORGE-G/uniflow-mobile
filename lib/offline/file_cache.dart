import 'dart:io';
import 'dart:typed_data';

import 'local_database.dart';

/// Pièces jointes et documents de cours gardés sur l'appareil, **à la
/// demande** : un fichier ouvert une fois reste lisible hors ligne. Quota
/// (200 Mo par défaut) : au-delà, les fichiers les moins récemment ouverts
/// sont retirés en premier.
class FileCache {
  final LocalDatabase _db;
  final Future<Directory> Function() _directory;
  final Future<Uint8List> Function(String bucket, String fileId) _download;
  final DateTime Function() _clock;

  FileCache(
    this._db, {
    required Future<Directory> Function() directory,
    required Future<Uint8List> Function(String bucket, String fileId) download,
    DateTime Function()? clock,
  })  : _directory = directory,
        _download = download,
        _clock = clock ?? DateTime.now;

  Future<bool> isCached(String fileId) async {
    final rows = await _db.cachedFiles();
    final row = rows.where((r) => r.fileId == fileId).firstOrNull;
    return row != null && File(row.path).existsSync();
  }

  /// Fichier local, téléchargé s'il n'y est pas encore. Hors ligne sans copie
  /// locale, l'erreur de téléchargement remonte à l'appelant.
  Future<File> open(String bucket, String fileId, {String name = '', required int quotaMb}) async {
    final now = _clock().toUtc().toIso8601String();
    final rows = await _db.cachedFiles();
    final existing = rows.where((r) => r.fileId == fileId).firstOrNull;
    if (existing != null && File(existing.path).existsSync()) {
      await _db.upsertCachedFile(CachedFileRow(
        fileId: fileId,
        bucket: bucket,
        path: existing.path,
        bytes: existing.bytes,
        name: existing.name,
        lastOpenedAt: now,
      ));
      return File(existing.path);
    }
    final bytes = await _download(bucket, fileId);
    final dir = await _directory();
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final file = File('${dir.path}/$fileId${_extensionOf(name)}');
    await file.writeAsBytes(bytes, flush: true);
    await _db.upsertCachedFile(CachedFileRow(
      fileId: fileId,
      bucket: bucket,
      path: file.path,
      bytes: bytes.length,
      name: name,
      lastOpenedAt: now,
    ));
    await enforceQuota(quotaMb);
    return file;
  }

  Future<int> totalBytes() async {
    final rows = await _db.cachedFiles();
    return rows.fold<int>(0, (sum, r) => sum + r.bytes);
  }

  /// Retire les fichiers les moins récemment ouverts jusqu'à passer sous le
  /// quota. Le fichier tout juste ouvert (dernier de la liste) est épargné.
  Future<void> enforceQuota(int quotaMb) async {
    final limit = quotaMb * 1000 * 1000;
    var rows = await _db.cachedFiles();
    var total = rows.fold<int>(0, (sum, r) => sum + r.bytes);
    for (final row in rows) {
      if (total <= limit || identical(row, rows.last)) break;
      await _remove(row);
      total -= row.bytes;
    }
  }

  Future<void> clear() async {
    for (final row in await _db.cachedFiles()) {
      await _remove(row);
    }
  }

  Future<void> _remove(CachedFileRow row) async {
    try {
      final file = File(row.path);
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
    await _db.deleteCachedFile(row.fileId);
  }

  static String _extensionOf(String name) {
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return '';
    final ext = name.substring(dot).toLowerCase();
    return RegExp(r'^\.[a-z0-9]{1,5}$').hasMatch(ext) ? ext : '';
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
