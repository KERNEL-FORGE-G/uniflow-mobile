import 'package:appwrite/models.dart' as models;

import 'appwrite_models.dart';
import 'assignment_models.dart';

/// Les six badges d'un apprenant, chacun gagné sur des données réelles
/// (présences, notes, devoirs, forum) — jamais sur un simple compteur local,
/// pour que le même compte affiche les mêmes badges sur tous ses appareils.
///
/// Les images (`assets/badges/*.webp`) sont embarquées : un badge doit
/// s'afficher hors ligne, là où l'étudiant consulte le plus souvent l'accueil.
enum StudentBadge {
  premierPas(
    'premier_pas',
    'Premier pas',
    'Rendre son premier devoir.',
    'Premier devoir rendu — la suite est lancée.',
  ),
  assidu(
    'assidu',
    'Assidu',
    'Être présent à 90 % des séances relevées (au moins 5).',
    'Présent à 90 % des séances : une assiduité exemplaire.',
  ),
  ponctuel(
    'ponctuel',
    'Ponctuel',
    'Rendre 3 devoirs, tous avant l\'échéance.',
    'Trois devoirs rendus dans les délais, sans exception.',
  ),
  major(
    'major',
    'Major',
    'Obtenir une moyenne pondérée de 14/20 sur au moins 3 notes.',
    'Moyenne pondérée de 14/20 ou plus : un parcours d\'excellence.',
  ),
  entraide(
    'entraide',
    'Entraide',
    'Publier 3 sujets sur le forum.',
    'Trois sujets publiés : la promo compte sur vous.',
  ),
  sansFaute(
    'sans_faute',
    'Sans faute',
    'Réussir un quiz avec la note maximale.',
    'Un quiz réussi à 100 % : un sans-faute.',
  );

  const StudentBadge(this.id, this.title, this.rule, this.unlockedMessage);

  /// Identifiant stable (nom du fichier image, clé de tests).
  final String id;
  final String title;

  /// Ce qu'il faut faire, au futur : affiché tant que le badge est verrouillé.
  final String rule;

  /// Ce qui a été accompli : affiché une fois le badge gagné.
  final String unlockedMessage;

  String get asset => 'assets/badges/badge_$id.webp';
}

/// Un badge et où en est l'apprenant : gagné ou pas, progression 0..1 et un
/// détail chiffré (« 4/5 séances », « 12,8/20 ») qui explique la progression.
class BadgeProgress {
  final StudentBadge badge;
  final double progress;
  final String detail;

  const BadgeProgress({
    required this.badge,
    required this.progress,
    required this.detail,
  });

  bool get unlocked => progress >= 1.0;

  /// Pourcentage entier pour l'accessibilité et les tests.
  int get percent => (progress.clamp(0.0, 1.0) * 100).round();
}

/// Relevé de présence d'un apprenant, réduit à ce que les badges en lisent.
class AttendanceMark {
  final String sessionId;
  final String status;

  const AttendanceMark({required this.sessionId, required this.status});

  factory AttendanceMark.fromDocument(models.Document doc) => AttendanceMark(
        sessionId: '${doc.data['sessionId'] ?? ''}',
        status: '${doc.data['status'] ?? ''}'.toUpperCase(),
      );

  /// Présent ou en retard : l'étudiant était là. Une absence justifiée n'est
  /// ni une présence ni une faute — elle ne compte pas dans le taux.
  bool get attended => status == 'PRESENT' || status == 'RETARD';
  bool get excused => status == 'JUSTIFIE';
}

/// Tout ce qu'il faut pour calculer les badges d'un apprenant.
class BadgeInputs {
  final String studentId;
  final List<AttendanceMark> attendance;
  final List<AcademicGrade> grades;
  final List<Assignment> assignments;
  final List<Submission> submissions;
  final int forumPostsByStudent;

  const BadgeInputs({
    required this.studentId,
    this.attendance = const [],
    this.grades = const [],
    this.assignments = const [],
    this.submissions = const [],
    this.forumPostsByStudent = 0,
  });
}

const int kAssiduMinSessions = 5;
const double kAssiduRate = 0.90;
const int kPonctuelSubmissions = 3;
const int kMajorMinGrades = 3;
const double kMajorAverage = 14.0;
const int kEntraidePosts = 3;

/// Calcule l'état des six badges. Pure : même entrée, même sortie.
List<BadgeProgress> computeBadges(BadgeInputs inputs) {
  final mine = inputs.submissions.where((s) => s.studentId.isEmpty || s.studentId == inputs.studentId).toList();
  final byAssignment = {for (final a in inputs.assignments) a.id: a};

  return [
    _premierPas(mine),
    _assidu(inputs.attendance),
    _ponctuel(mine, byAssignment),
    _major(inputs.grades),
    _entraide(inputs.forumPostsByStudent),
    _sansFaute(mine, byAssignment),
  ];
}

BadgeProgress _premierPas(List<Submission> submissions) => BadgeProgress(
      badge: StudentBadge.premierPas,
      progress: submissions.isEmpty ? 0 : 1,
      detail: submissions.isEmpty
          ? 'Aucun devoir rendu'
          : '${submissions.length} ${submissions.length > 1 ? 'devoirs rendus' : 'devoir rendu'}',
    );

BadgeProgress _assidu(List<AttendanceMark> marks) {
  // Un relevé par séance : deux relevés de la même séance (scan puis
  // correction manuelle) ne doivent pas compter double.
  final bySession = <String, AttendanceMark>{};
  for (final mark in marks) {
    final key = mark.sessionId.isEmpty ? '${bySession.length}' : mark.sessionId;
    bySession[key] = mark;
  }
  final counted = bySession.values.where((m) => !m.excused).toList();
  final attended = counted.where((m) => m.attended).length;
  if (counted.isEmpty) {
    return const BadgeProgress(
      badge: StudentBadge.assidu,
      progress: 0,
      detail: 'Aucune séance relevée',
    );
  }
  final rate = attended / counted.length;
  // Deux conditions, la progression est la plus faible des deux : un 100 %
  // sur deux séances ne doit pas afficher un badge presque gagné.
  final volume = (counted.length / kAssiduMinSessions).clamp(0.0, 1.0);
  final quality = (rate / kAssiduRate).clamp(0.0, 1.0);
  final progress = counted.length >= kAssiduMinSessions && rate >= kAssiduRate
      ? 1.0
      : (volume < quality ? volume : quality).clamp(0.0, 0.99);
  return BadgeProgress(
    badge: StudentBadge.assidu,
    progress: progress,
    detail:
        '${(rate * 100).round()} % de présence · $attended/${counted.length} séance${counted.length > 1 ? 's' : ''}',
  );
}

BadgeProgress _ponctuel(List<Submission> submissions, Map<String, Assignment> byAssignment) {
  var onTime = 0;
  var late = 0;
  for (final s in submissions) {
    final due = byAssignment[s.assignmentId]?.dueDate;
    if (due == null) continue;
    if (s.submittedAt.isAfter(due)) {
      late++;
    } else {
      onTime++;
    }
  }
  final total = onTime + late;
  if (late > 0) {
    // Un retard casse la série : le badge se regagne avec trois rendus à
    // l'heure d'affilée, mais la progression repart de la série courante.
    return BadgeProgress(
      badge: StudentBadge.ponctuel,
      progress: 0,
      detail: '$late ${late > 1 ? 'devoirs rendus' : 'devoir rendu'} en retard',
    );
  }
  return BadgeProgress(
    badge: StudentBadge.ponctuel,
    progress: (onTime / kPonctuelSubmissions).clamp(0.0, 1.0),
    detail: total == 0
        ? 'Aucun devoir rendu'
        : '$onTime/$kPonctuelSubmissions ${onTime > 1 ? 'devoirs rendus' : 'devoir rendu'} à l\'heure',
  );
}

BadgeProgress _major(List<AcademicGrade> grades) {
  final usable = grades.where((g) => g.maxScore > 0).toList();
  if (usable.isEmpty) {
    return const BadgeProgress(
      badge: StudentBadge.major,
      progress: 0,
      detail: 'Aucune note publiée',
    );
  }
  var weighted = 0.0;
  var weights = 0.0;
  for (final g in usable) {
    final coefficient = g.coefficient > 0 ? g.coefficient : 1.0;
    weighted += (g.score / g.maxScore) * 20 * coefficient;
    weights += coefficient;
  }
  final average = weighted / weights;
  final volume = (usable.length / kMajorMinGrades).clamp(0.0, 1.0);
  final quality = (average / kMajorAverage).clamp(0.0, 1.0);
  final progress = usable.length >= kMajorMinGrades && average >= kMajorAverage
      ? 1.0
      : (volume < quality ? volume : quality).clamp(0.0, 0.99);
  return BadgeProgress(
    badge: StudentBadge.major,
    progress: progress,
    detail:
        'Moyenne ${average.toStringAsFixed(1).replaceAll('.', ',')}/20 · ${usable.length} note${usable.length > 1 ? 's' : ''}',
  );
}

BadgeProgress _entraide(int posts) => BadgeProgress(
      badge: StudentBadge.entraide,
      progress: (posts / kEntraidePosts).clamp(0.0, 1.0),
      detail: posts == 0
          ? 'Aucun sujet publié'
          : '$posts/$kEntraidePosts sujet${posts > 1 ? 's' : ''} publié${posts > 1 ? 's' : ''}',
    );

BadgeProgress _sansFaute(List<Submission> submissions, Map<String, Assignment> byAssignment) {
  var quizzes = 0;
  var perfect = 0;
  var best = 0.0;
  for (final s in submissions) {
    final assignment = byAssignment[s.assignmentId];
    if (assignment == null || assignment.type != AssignmentType.quiz) continue;
    final score = s.score;
    if (score == null || assignment.maxScore <= 0) continue;
    quizzes++;
    final ratio = (score / assignment.maxScore).clamp(0.0, 1.0);
    if (ratio > best) best = ratio;
    if (ratio >= 1.0) perfect++;
  }
  return BadgeProgress(
    badge: StudentBadge.sansFaute,
    progress: perfect > 0 ? 1.0 : (quizzes == 0 ? 0.0 : best.clamp(0.0, 0.99)),
    detail: quizzes == 0
        ? 'Aucun quiz corrigé'
        : perfect > 0
            ? '$perfect quiz à 100 %'
            : 'Meilleur quiz : ${(best * 100).round()} %',
  );
}
