/// Système de gamification UniFlow — badges (100) et quêtes (300) dynamiques.
///
/// Toutes les définitions viennent d'Appwrite (collections `badges_catalog` et
/// `quests_catalog`). Les images viennent du bucket `uniflow_assets` sous le
/// préfixe `badges/`. Les stats par utilisateur sont dans `user_badges` et
/// `user_quest_progress`.
library gamification;

import 'dart:convert';

import 'package:appwrite/models.dart' as models;

// ─────────────────────────────────────────────────────────────────────────────
// Badge catalog
// ─────────────────────────────────────────────────────────────────────────────

/// Catégorie d'un badge.
enum BadgeCategory {
  assiduite,    // présences, ponctualité
  academique,   // notes, devoirs, quiz
  social,       // forum, messages, entraide
  special,      // événements, saisonniers
  communaute,   // classements, meilleur du mois/semaine
  progression,  // milestones de parcours
}

/// Rareté d'un badge — détermine la couleur de l'anneau et le poids XP.
enum BadgeRarity {
  common,   // bronze
  rare,     // argent
  epic,     // or
  legendary, // arc-en-ciel
}

/// Niveau d'un badge (1 à 5 étoiles). Un badge de niveau supérieur remplace
/// l'inférieur dans le profil mais l'historique garde les deux.
enum BadgeLevel { bronze, silver, gold, platinum, diamond }

/// Définition d'un badge, lue depuis la collection `badges_catalog`.
class BadgeDefinition {
  final String id;
  final String name;
  final String description;
  final String unlockedMessage;
  final BadgeCategory category;
  final BadgeRarity rarity;
  final BadgeLevel level;

  /// Identifiant de l'image dans le bucket Appwrite (`badges/<imageId>.webp`).
  final String imageFileId;

  /// Critère machine pour le calcul automatique côté Function.
  /// Ex. : `{"type":"attendance_rate","threshold":0.90,"min_sessions":5}`
  final Map<String, dynamic> criteria;

  /// XP accordés à l'obtention.
  final int xpReward;

  /// `true` = badge limité (saison, événement) — n'apparaît plus en catalogue
  /// quand [availableUntil] est dépassé.
  final bool isLimited;
  final DateTime? availableUntil;

  const BadgeDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.unlockedMessage,
    required this.category,
    required this.rarity,
    required this.level,
    required this.imageFileId,
    required this.criteria,
    required this.xpReward,
    this.isLimited = false,
    this.availableUntil,
  });

  factory BadgeDefinition.fromDocument(models.Document doc) {
    final d = doc.data;
    return BadgeDefinition(
      id: doc.$id,
      name: '${d['name'] ?? ''}',
      description: '${d['description'] ?? ''}',
      unlockedMessage: '${d['unlockedMessage'] ?? ''}',
      category: BadgeCategory.values.firstWhere(
        (c) => c.name == (d['category'] ?? ''),
        orElse: () => BadgeCategory.special,
      ),
      rarity: BadgeRarity.values.firstWhere(
        (r) => r.name == (d['rarity'] ?? ''),
        orElse: () => BadgeRarity.common,
      ),
      level: BadgeLevel.values.firstWhere(
        (l) => l.name == (d['level'] ?? ''),
        orElse: () => BadgeLevel.bronze,
      ),
      imageFileId: '${d['imageFileId'] ?? ''}',
      criteria: _parseJson(d['criteria']),
      xpReward: (d['xpReward'] as int?) ?? 10,
      isLimited: (d['isLimited'] as bool?) ?? false,
      availableUntil: d['availableUntil'] != null
          ? DateTime.tryParse('${d['availableUntil']}')
          : null,
    );
  }

  static Map<String, dynamic> _parseJson(dynamic raw) {
    if (raw == null) return {};
    if (raw is Map<String, dynamic>) return raw;
    try {
      return (const JsonDecoder().convert('$raw') as Map?)?.cast<String, dynamic>() ?? {};
    } catch (_) {
      return {};
    }
  }
}

/// État d'un badge pour un utilisateur donné, lu depuis `user_badges`.
class UserBadge {
  final String id;
  final String userId;
  final String badgeId;
  final DateTime unlockedAt;

  /// Progression 0..100 (entier). 100 = badge obtenu.
  final int progressPercent;

  /// Détail lisible : « 4/5 séances », « 12,8/20 ».
  final String progressDetail;

  const UserBadge({
    required this.id,
    required this.userId,
    required this.badgeId,
    required this.unlockedAt,
    required this.progressPercent,
    required this.progressDetail,
  });

  bool get unlocked => progressPercent >= 100;

  factory UserBadge.fromDocument(models.Document doc) {
    final d = doc.data;
    return UserBadge(
      id: doc.$id,
      userId: '${d['userId'] ?? ''}',
      badgeId: '${d['badgeId'] ?? ''}',
      unlockedAt: DateTime.tryParse('${d['unlockedAt'] ?? ''}') ?? DateTime.now(),
      progressPercent: (d['progressPercent'] as int?) ?? 0,
      progressDetail: '${d['progressDetail'] ?? ''}',
    );
  }
}

/// Paire (définition + état utilisateur) prête à afficher.
class BadgeWithProgress {
  final BadgeDefinition definition;
  final UserBadge? userBadge;

  const BadgeWithProgress({required this.definition, this.userBadge});

  bool get unlocked => userBadge?.unlocked ?? false;
  int get progressPercent => userBadge?.progressPercent ?? 0;
  String get progressDetail => userBadge?.progressDetail ?? 'Non commencé';
}

// ─────────────────────────────────────────────────────────────────────────────
// Quest catalog
// ─────────────────────────────────────────────────────────────────────────────

/// Période d'une quête.
enum QuestPeriod {
  daily,   // réinitialisation quotidienne
  weekly,  // réinitialisation le lundi
  monthly, // réinitialisation le 1er du mois
  yearly,  // réinitialisation le 1er janvier
  oneshot, // quête unique, pas de réinitialisation
}

/// Type de critère d'une quête.
enum QuestCriteriaType {
  attendSession,      // assister à N séances
  submitAssignment,   // rendre N devoirs
  earnGrade,          // obtenir une note ≥ seuil
  postForum,          // poster N messages sur le forum
  sendMessage,        // envoyer N messages privés
  loginStreak,        // se connecter N jours d'affilée
  completeQuiz,       // compléter N quiz
  perfectQuiz,        // réussir N quiz à 100%
  earnBadge,          // obtenir N badges
  reachXp,            // atteindre N XP total
  rankTop,            // être dans le top N de la promo (semaine/mois)
  bestOfWeek,         // être le meilleur de la semaine (assiduité, notes…)
  bestOfMonth,        // meilleur du mois
  mostActive,         // le plus actif (forum + messages)
  earlyBird,          // se connecter avant 8h N fois
  nightOwl,           // se connecter après 22h N fois
}

/// Définition d'une quête, lue depuis `quests_catalog`.
class QuestDefinition {
  final String id;
  final String title;
  final String description;
  final QuestPeriod period;
  final QuestCriteriaType criteriaType;

  /// Valeur cible (ex. 5 pour « assister à 5 séances »).
  final int targetValue;

  /// XP accordés à la complétion.
  final int xpReward;

  /// Badge optionnel déverrouillé à la complétion.
  final String? badgeRewardId;

  /// Icône Phosphor à afficher (nom de l'icône, ex. `trophy`).
  final String iconName;

  /// Couleur hex de la quête.
  final String colorHex;

  /// `true` = quête visible uniquement pendant certaines périodes.
  final bool isLimited;
  final DateTime? availableFrom;
  final DateTime? availableUntil;

  const QuestDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.period,
    required this.criteriaType,
    required this.targetValue,
    required this.xpReward,
    required this.iconName,
    required this.colorHex,
    this.badgeRewardId,
    this.isLimited = false,
    this.availableFrom,
    this.availableUntil,
  });

  factory QuestDefinition.fromDocument(models.Document doc) {
    final d = doc.data;
    return QuestDefinition(
      id: doc.$id,
      title: '${d['title'] ?? ''}',
      description: '${d['description'] ?? ''}',
      period: QuestPeriod.values.firstWhere(
        (p) => p.name == (d['period'] ?? ''),
        orElse: () => QuestPeriod.oneshot,
      ),
      criteriaType: QuestCriteriaType.values.firstWhere(
        (c) => c.name == (d['criteriaType'] ?? ''),
        orElse: () => QuestCriteriaType.attendSession,
      ),
      targetValue: (d['targetValue'] as int?) ?? 1,
      xpReward: (d['xpReward'] as int?) ?? 20,
      badgeRewardId: d['badgeRewardId'] as String?,
      iconName: '${d['iconName'] ?? 'trophy'}',
      colorHex: '${d['colorHex'] ?? '#6366F1'}',
      isLimited: (d['isLimited'] as bool?) ?? false,
      availableFrom: d['availableFrom'] != null
          ? DateTime.tryParse('${d['availableFrom']}')
          : null,
      availableUntil: d['availableUntil'] != null
          ? DateTime.tryParse('${d['availableUntil']}')
          : null,
    );
  }

  bool get isActive {
    final now = DateTime.now();
    if (availableFrom != null && now.isBefore(availableFrom!)) return false;
    if (availableUntil != null && now.isAfter(availableUntil!)) return false;
    return true;
  }

  /// Libellé de la période pour l'affichage.
  String get periodLabel => switch (period) {
        QuestPeriod.daily => 'Quotidienne',
        QuestPeriod.weekly => 'Hebdomadaire',
        QuestPeriod.monthly => 'Mensuelle',
        QuestPeriod.yearly => 'Annuelle',
        QuestPeriod.oneshot => 'Unique',
      };
}

/// Progression d'un utilisateur sur une quête, lue depuis `user_quest_progress`.
class UserQuestProgress {
  final String id;
  final String userId;
  final String questId;

  /// Valeur actuelle (0 → [QuestDefinition.targetValue]).
  final int currentValue;

  /// Date de la dernière mise à jour.
  final DateTime updatedAt;

  /// Quête complétée ce cycle ?
  final bool completed;

  /// Date de la complétion (null si pas encore complétée).
  final DateTime? completedAt;

  /// Date de la prochaine réinitialisation (calculée par la Function).
  final DateTime? resetAt;

  const UserQuestProgress({
    required this.id,
    required this.userId,
    required this.questId,
    required this.currentValue,
    required this.updatedAt,
    required this.completed,
    this.completedAt,
    this.resetAt,
  });

  factory UserQuestProgress.fromDocument(models.Document doc) {
    final d = doc.data;
    return UserQuestProgress(
      id: doc.$id,
      userId: '${d['userId'] ?? ''}',
      questId: '${d['questId'] ?? ''}',
      currentValue: (d['currentValue'] as int?) ?? 0,
      updatedAt: DateTime.tryParse('${d['updatedAt'] ?? ''}') ?? DateTime.now(),
      completed: (d['completed'] as bool?) ?? false,
      completedAt: d['completedAt'] != null
          ? DateTime.tryParse('${d['completedAt']}')
          : null,
      resetAt: d['resetAt'] != null
          ? DateTime.tryParse('${d['resetAt']}')
          : null,
    );
  }
}

/// Paire (définition quête + progression utilisateur) prête à afficher.
class QuestWithProgress {
  final QuestDefinition definition;
  final UserQuestProgress? progress;

  const QuestWithProgress({required this.definition, this.progress});

  bool get completed => progress?.completed ?? false;
  int get currentValue => progress?.currentValue ?? 0;
  int get targetValue => definition.targetValue;

  double get ratio => targetValue == 0
      ? 0.0
      : (currentValue / targetValue).clamp(0.0, 1.0);

  int get progressPercent => (ratio * 100).round();

  String get progressLabel => '$currentValue/$targetValue';
}

// ─────────────────────────────────────────────────────────────────────────────
// XP & Leaderboard
// ─────────────────────────────────────────────────────────────────────────────

/// Niveau XP d'un utilisateur, calculé à la volée.
class XpLevel {
  final int totalXp;
  final int level;
  final int xpInLevel;
  final int xpForNextLevel;
  final String title;

  const XpLevel({
    required this.totalXp,
    required this.level,
    required this.xpInLevel,
    required this.xpForNextLevel,
    required this.title,
  });

  double get progress => xpForNextLevel == 0 ? 1.0 : (xpInLevel / xpForNextLevel).clamp(0.0, 1.0);

  factory XpLevel.fromXp(int xp) {
    // Chaque niveau demande 100 * niveau XP (niveau 1 → 100 XP, niveau 2 → 200 XP…)
    var level = 1;
    var remaining = xp;
    while (remaining >= level * 100) {
      remaining -= level * 100;
      level++;
    }
    return XpLevel(
      totalXp: xp,
      level: level,
      xpInLevel: remaining,
      xpForNextLevel: level * 100,
      title: _levelTitle(level),
    );
  }

  static String _levelTitle(int level) => switch (level) {
        1 => 'Nouveau',
        2 || 3 => 'Débutant',
        4 || 5 => 'Apprenti',
        6 || 7 => 'Confirmé',
        8 || 9 => 'Expert',
        10 || 11 => 'Maître',
        12 || 13 => 'Grand Maître',
        >= 14 => 'Légende',
        _ => 'Nouveau',
      };
}

/// Entrée du classement hebdo/mensuel.
class LeaderboardEntry {
  final String userId;
  final String displayName;
  final String? avatarFileId;
  final int rank;
  final int score;
  final String period; // 'week', 'month', 'year'
  final String metric; // 'attendance', 'grades', 'activity', 'xp'

  const LeaderboardEntry({
    required this.userId,
    required this.displayName,
    this.avatarFileId,
    required this.rank,
    required this.score,
    required this.period,
    required this.metric,
  });

  factory LeaderboardEntry.fromDocument(models.Document doc) {
    final d = doc.data;
    return LeaderboardEntry(
      userId: '${d['userId'] ?? ''}',
      displayName: '${d['displayName'] ?? 'Étudiant'}',
      avatarFileId: d['avatarFileId'] as String?,
      rank: (d['rank'] as int?) ?? 0,
      score: (d['score'] as int?) ?? 0,
      period: '${d['period'] ?? 'week'}',
      metric: '${d['metric'] ?? 'xp'}',
    );
  }
}
