import 'appwrite_models.dart';
import 'user_role.dart';

/// Périmètre académique d'un compte : ce que ses écrans (cours, emploi du
/// temps, bibliothèque, annuaire) ont le droit de montrer.
///
/// Rien n'est codé en dur : le périmètre se lit dans le document `users`
/// (`program` = code de filière, `level`, `university`). L'ICT4D va de L1 à L3
/// et d'autres filières de l'UY1 arrivent en base ; un étudiant L2 ne doit pas
/// voir l'emploi du temps des L1, et un étudiant de physique ne doit pas voir
/// les cours d'ICT4D.
///
/// - étudiant et délégué : leur filière **et** leur niveau ;
/// - enseignant : toute sa filière (il enseigne à plusieurs niveaux) ;
/// - administration : toute son université ;
/// - compte indépendant : aucun périmètre académique.
///
/// Un champ absent sur le compte ne filtre pas : un profil incomplet montre
/// tout plutôt qu'un écran vide inexpliqué.
class AcademicScope {
  final String university;
  final String program;
  final String level;
  final bool filterByProgram;
  final bool filterByLevel;
  final bool nothing;

  const AcademicScope._({
    this.university = '',
    this.program = '',
    this.level = '',
    this.filterByProgram = false,
    this.filterByLevel = false,
    this.nothing = false,
  });

  /// Tout est visible (compte inconnu ou profil sans rattachement).
  static const AcademicScope everything = AcademicScope._();

  factory AcademicScope.forUser(UniFlowUser? user) {
    if (user == null) return everything;
    if (user.isPersonal) return const AcademicScope._(nothing: true);
    final role = mapRole(user.role);
    final university = (user.university ?? '').trim();
    final program = (user.program ?? '').trim();
    final level = (user.level ?? '').trim();
    return switch (role) {
      UniFlowRole.admin => AcademicScope._(university: university),
      UniFlowRole.teacher => AcademicScope._(university: university, program: program, filterByProgram: program.isNotEmpty),
      _ => AcademicScope._(
          university: university,
          program: program,
          level: level,
          filterByProgram: program.isNotEmpty,
          filterByLevel: level.isNotEmpty,
        ),
    };
  }

  bool _same(String a, String b) => a.trim().toUpperCase() == b.trim().toUpperCase();

  /// Vrai si un objet portant ces attributs est dans le périmètre.
  bool includes({String? university, String? program, String? level}) {
    if (nothing) return false;
    if (this.university.isNotEmpty && (university ?? '').trim().isNotEmpty && !_same(this.university, university!)) {
      return false;
    }
    if (filterByProgram && !_same(this.program, program ?? '')) return false;
    if (filterByLevel && !_same(this.level, level ?? '')) return false;
    return true;
  }

  bool includesCourse(AcademicCourse course) =>
      includes(university: course.university, program: course.program, level: course.level);

  bool includesEntry(AcademicDirectoryEntry entry) {
    if (nothing) return false;
    // L'annuaire montre aussi les enseignants et l'administration de la
    // filière : ils n'ont pas de niveau, on ne les filtre que par filière.
    final staff = entry.role == 'TEACHER' || entry.role == 'ADMIN';
    return includes(
      university: entry.university,
      program: staff && filterByProgram ? program : entry.program,
      level: staff ? level : entry.level,
    );
  }

  List<AcademicCourse> courses(List<AcademicCourse> all) => all.where(includesCourse).toList();

  List<AcademicDirectoryEntry> directory(List<AcademicDirectoryEntry> all) => all.where(includesEntry).toList();

  /// Emploi du temps et bibliothèque ne portent ni filière ni niveau : ils se
  /// rattachent à un cours, et c'est le cours qui décide.
  List<T> byCourse<T>(List<T> items, List<AcademicCourse> scopedCourses, String Function(T) courseIdOf, {String Function(T)? courseCodeOf}) {
    if (nothing) return const [];
    final ids = scopedCourses.map((c) => c.id).toSet();
    final codes = scopedCourses.map((c) => c.code.toUpperCase()).toSet();
    return items.where((item) {
      if (ids.contains(courseIdOf(item))) return true;
      final code = courseCodeOf?.call(item).toUpperCase() ?? '';
      return code.isNotEmpty && codes.contains(code);
    }).toList();
  }

  /// Libellé court pour les en-têtes (« ICT4D · L2 », « ICT4D », « Université… »).
  String get label {
    if (nothing) return '';
    final parts = <String>[
      if (filterByProgram) program,
      if (filterByLevel) level,
    ];
    if (parts.isEmpty) return university;
    return parts.join(' · ');
  }
}
