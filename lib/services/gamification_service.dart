/// Service de gamification UniFlow (mobile).
///
/// Toutes les définitions de badges et quêtes viennent d'Appwrite.
/// Les images de badges viennent du bucket `uniflow_assets` sous `badges/`.
library gamification_service;

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/appwrite_service.dart';
import '../providers/appwrite_provider.dart';
import '../providers/providers.dart';
import '../models/gamification.dart';

// ─── Constantes ─────────────────────────────────────────────────────────────

const String _databaseId     = 'uniflow';
const String _badgesCatalog   = 'badges_catalog';
const String _userBadges      = 'user_badges';
const String _questsCatalog   = 'quests_catalog';
const String _userQuestProg   = 'user_quest_progress';
const String _userXp          = 'user_xp';
const String _leaderboard     = 'leaderboard';
const String _bucketId        = 'uniflow_assets';

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

class GamificationService {
  GamificationService(this._appwrite);

  final AppwriteService _appwrite;

  Databases get _databases => _appwrite.databases;

  // ── Utilitaires ─────────────────────────────────────────────────────────

  /// URL publique d'un fichier badge dans le bucket.
  /// Convention : `badges/<imageFileId>.webp`
  String badgeImageUrl(String imageFileId) {
    return _appwrite.fileViewUrl(imageFileId, bucketId: _bucketId);
  }

  Future<List<T>> _listAll<T>(
    String collection,
    T Function(models.Document) fromDoc, {
    List<String> queries = const [],
  }) async {
    final all = <T>[];
    String? cursor;
    for (;;) {
      final q = [...queries, Query.limit(100)];
      if (cursor != null) q.add(Query.cursorAfter(cursor));
      final page = await _databases.listDocuments(
        databaseId: _databaseId,
        collectionId: collection,
        queries: q,
      );
      all.addAll(page.documents.map(fromDoc));
      if (page.documents.length < 100) break;
      cursor = page.documents.last.$id;
    }
    return all;
  }

  // ── Catalogue de badges ──────────────────────────────────────────────────

  /// Charge tous les badges du catalogue depuis Appwrite.
  Future<List<BadgeDefinition>> fetchBadgeCatalog() => _listAll(
    _badgesCatalog,
    BadgeDefinition.fromDocument,
    queries: [Query.orderAsc('sortOrder')],
  );

  /// Charge les badges débloqués par [userId].
  Future<List<UserBadge>> fetchUserBadges(String userId) => _listAll(
    _userBadges,
    UserBadge.fromDocument,
    queries: [Query.equal('userId', userId)],
  );

  /// Charge le catalogue + les badges utilisateur et les fusionne.
  Future<List<BadgeWithProgress>> fetchBadgesWithProgress(String userId) async {
    final catalog   = await fetchBadgeCatalog();
    final unlocked  = await fetchUserBadges(userId);
    final unlockedIds = {for (final b in unlocked) b.badgeId: b};

    return catalog.map((def) {
      final ub = unlockedIds[def.id];
      return BadgeWithProgress(
        definition: def,
        userBadge: ub,
      );
    }).toList();
  }

  // ── Quêtes ───────────────────────────────────────────────────────────────

  /// Charge les quêtes actives de l'utilisateur pour la période [period].
  Future<List<QuestWithProgress>> fetchActiveQuests(
    String userId, {
    QuestPeriod? period,
  }) async {
    final queries = [
      Query.equal('userId', userId),
      Query.equal('status', 'active'),
      Query.limit(50),
    ];
    if (period != null) {
      queries.add(Query.equal('period', period.name));
    }

    final progressDocs = await _databases.listDocuments(
      databaseId: _databaseId,
      collectionId: _userQuestProg,
      queries: queries,
    );

    final results = <QuestWithProgress>[];
    for (final prog in progressDocs.documents) {
      final questId = prog.data['questId'] as String?;
      if (questId == null) continue;
      try {
        final questDoc = await _databases.getDocument(
          databaseId: _databaseId,
          collectionId: _questsCatalog,
          documentId: questId,
        );
        final def = QuestDefinition.fromDocument(questDoc);
        final progress = UserQuestProgress.fromDocument(prog);
        results.add(QuestWithProgress(definition: def, progress: progress));
      } catch (_) {
        continue;
      }
    }
    return results;
  }

  // ── XP & Classement ──────────────────────────────────────────────────────

  /// XP et niveau de l'utilisateur.
  Future<UserXp?> fetchUserXp(String userId) async {
    try {
      final page = await _databases.listDocuments(
        databaseId: _databaseId,
        collectionId: _userXp,
        queries: [Query.equal('userId', userId), Query.limit(1)],
      );
      if (page.documents.isEmpty) return null;
      return UserXp.fromDocument(page.documents.first);
    } catch (_) {
      return null;
    }
  }

  /// Classement pour une période et une métrique.
  Future<List<LeaderboardEntry>> fetchLeaderboard({
    required String period,
    required String metric,
    int limit = 20,
  }) async {
    final now = DateTime.now();
    final periodKey = _periodKey(period, now);
    return _listAll(
      _leaderboard,
      LeaderboardEntry.fromDocument,
      queries: [
        Query.equal('period', period),
        Query.equal('metric', metric),
        Query.equal('periodKey', periodKey),
        Query.orderAsc('rank'),
        Query.limit(limit),
      ],
    );
  }

  String _periodKey(String period, DateTime now) {
    if (period == 'annual')  return '${now.year}';
    if (period == 'monthly') return '${now.year}-${now.month.toString().padLeft(2, '0')}';
    // weekly — numéro ISO simplifié
    final startOfYear = DateTime(now.year, 1, 1);
    final week = ((now.difference(startOfYear).inDays) / 7).ceil();
    return '${now.year}-W${week.toString().padLeft(2, '0')}';
  }

  // ── Déclenchement manuel ─────────────────────────────────────────────────

  /// Vérifie et attribue des badges à l'utilisateur côté serveur.
  /// Appelle l'endpoint `/gamification/check-badges` du routeur `uniflow-api`.
  Future<Map<String, dynamic>> checkAndAwardBadges(String userId) async {
    try {
      final result = await _appwrite.executeFunction(
        '/gamification/check-badges',
        {'userId': userId},
      );
      return result;
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Modèles complémentaires (XP + Leaderboard) non encore dans gamification.dart
// ─────────────────────────────────────────────────────────────────────────────

class UserXp {
  final String id;
  final String userId;
  final int totalXp;
  final int level;
  final int xpInCurrentLevel;
  final int xpToNextLevel;

  const UserXp({
    required this.id,
    required this.userId,
    required this.totalXp,
    required this.level,
    required this.xpInCurrentLevel,
    required this.xpToNextLevel,
  });

  factory UserXp.fromDocument(models.Document doc) {
    final d = doc.data;
    return UserXp(
      id: doc.$id,
      userId: d['userId'] as String? ?? '',
      totalXp: (d['totalXp'] as num?)?.toInt() ?? 0,
      level: (d['level'] as num?)?.toInt() ?? 1,
      xpInCurrentLevel: (d['xpInCurrentLevel'] as num?)?.toInt() ?? 0,
      xpToNextLevel: (d['xpToNextLevel'] as num?)?.toInt() ?? 100,
    );
  }

  double get progressPercent =>
    xpToNextLevel > 0 ? (xpInCurrentLevel / xpToNextLevel).clamp(0.0, 1.0) : 0.0;
}

// ─────────────────────────────────────────────────────────────────────────────
// Providers Riverpod
// ─────────────────────────────────────────────────────────────────────────────

final gamificationServiceProvider = Provider<GamificationService>((ref) {
  final appwrite = ref.watch(appwriteServiceProvider);
  return GamificationService(appwrite);
});

/// Badges avec progression pour l'utilisateur connecté.
final badgesWithProgressProvider = FutureProvider<List<BadgeWithProgress>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final svc = ref.read(gamificationServiceProvider);
  return svc.fetchBadgesWithProgress(user.id);
});

/// Quêtes actives (toutes périodes) pour l'utilisateur connecté.
final activeQuestsProvider = FutureProvider<List<QuestWithProgress>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final svc = ref.read(gamificationServiceProvider);
  return svc.fetchActiveQuests(user.id);
});

/// Quêtes hebdomadaires actives.
final weeklyQuestsProvider = FutureProvider<List<QuestWithProgress>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final svc = ref.read(gamificationServiceProvider);
  return svc.fetchActiveQuests(user.id, period: QuestPeriod.weekly);
});

/// Quêtes mensuelles actives.
final monthlyQuestsProvider = FutureProvider<List<QuestWithProgress>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final svc = ref.read(gamificationServiceProvider);
  return svc.fetchActiveQuests(user.id, period: QuestPeriod.monthly);
});

/// XP et niveau de l'utilisateur connecté.
final userXpProvider = FutureProvider<UserXp?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final svc = ref.read(gamificationServiceProvider);
  return svc.fetchUserXp(user.id);
});

/// Classement hebdomadaire (points XP).
final weeklyLeaderboardProvider = FutureProvider<List<LeaderboardEntry>>((ref) async {
  final svc = ref.read(gamificationServiceProvider);
  return svc.fetchLeaderboard(period: 'weekly', metric: 'xp');
});

/// Classement mensuel.
final monthlyLeaderboardProvider = FutureProvider<List<LeaderboardEntry>>((ref) async {
  final svc = ref.read(gamificationServiceProvider);
  return svc.fetchLeaderboard(period: 'monthly', metric: 'xp');
});
