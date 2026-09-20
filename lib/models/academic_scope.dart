import 'appwrite_models.dart';
import 'user_role.dart';

/// Périmètre académique d'un compte : ce que ses écrans (cours, emploi du
/// temps, bibliothèque, annuaire) ont le droit de montrer.
///
/// Rien n'est codé en dur : le périmètre se lit dans le document `users`
/// (`program` = code de filière parmi les douze d'`academic_programs`,
/// `level`, `faculty`, `university`). Un étudiant L2 ne doit pas voir l'emploi
/// du temps des L1, et un étudiant de physique ne doit pas voir les cours
/// d'informatique.
///
/// - étudiant et délégué : leur filière **et** leur niveau ;
/// - enseignant : toute sa filière (il enseigne à plusieurs niveaux) ;
/// - administration d'université : son université et sa faculté, toutes
///   filières ;
/// - administrateur de la plateforme (`PLATFORM`, `superadmin`) : tout, sans
///   aucun périmètre — il n'appartient à aucune université ;
/// - compte indépendant : aucun périmètre académique.
///
/// Un champ absent sur le compte ne filtre pas : un profil incomplet montre
/// tout plutôt qu'un écran vide inexpliqué.
class AcademicScope {
  final String university;
  final String faculty;
  final String program;
  final String level;
  final bool filterByProgram;
  final bool filterByLevel;
  final bool nothing;

  /// Le compte peut choisir filière et niveau à la volée (administration,
  /// plateforme, enseignant sans filière) : l'écran affiche un sélecteur.
  final bool selectable;

  const AcademicScope._({
    this.university = '',
    this.faculty = '',
    this.program = '',
    this.level = '',
    this.filterByProgram = false,
    this.filterByLevel = false,
    this.nothing = false,
    this.selectable = false,
  });

  /// Tout est visible (compte inconnu ou profil sans rattachement).
  static const AcademicScope everything = AcademicScope._();

  factory AcademicScope.forUser(UniFlowUser? user) {
    if (user == null) return everything;
    if (user.isPersonal) return const AcademicScope._(nothing: true);
    // L'admin de la plateforme n'a ni université ni filière : lui appliquer
    // un périmètre vide afficherait « aucun cours » alors qu'il doit tout voir.
    if (user.isPlatform) return const AcademicScope._(selectable: true);
    final role = mapRole(user.role);
    final university = (user.university ?? '').trim();
    final faculty = (user.faculty ?? '').trim();
    final program = (user.program ?? '').trim();
    final level = (user.level ?? '').trim();
    return switch (role) {
      UniFlowRole.admin => AcademicScope._(university: university, faculty: faculty, selectable: true),
      UniFlowRole.teacher => AcademicScope._(
          university: university,
          faculty: faculty,
          program: program,
          filterByProgram: program.isNotEmpty,
          selectable: program.isEmpty,
        ),
      _ => AcademicScope._(
          university: university,
          faculty: faculty,
          program: program,
          level: level,
          filterByProgram: program.isNotEmpty,
          filterByLevel: level.isNotEmpty,
        ),
    };
  }

  /// Périmètre restreint à une filière et un niveau choisis dans un
  /// sélecteur (administration, plateforme). Conserve l'université.
  AcademicScope narrowedTo({required String program, String level = ''}) => AcademicScope._(
        university: university,
        faculty: faculty,
        program: program.trim(),
        level: level.trim(),
        filterByProgram: program.trim().isNotEmpty,
        filterByLevel: level.trim().isNotEmpty,
        selectable: selectable,
      );

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
  List<T> byCourse<T>(List<T> items, List<AcademicCourse> scopedCourses, String Function(T) courseIdOf,
      {String Function(T)? courseCodeOf}) {
    if (nothing) return const [];
    final ids = scopedCourses.map((c) => c.id).toSet();
    final codes = scopedCourses.map((c) => c.code.toUpperCase()).toSet();
    return items.where((item) {
      if (ids.contains(courseIdOf(item))) return true;
      final code = courseCodeOf?.call(item).toUpperCase() ?? '';
      return code.isNotEmpty && codes.contains(code);
    }).toList();
  }

  /// Libellé court pour les en-têtes (« PHY · L3 », « PHY », « Université… »).
  String get label {
    if (nothing) return '';
    final parts = <String>[
      if (filterByProgram) program,
      if (filterByLevel) level,
    ];
    if (parts.isEmpty) return [university, if (faculty.isNotEmpty) faculty].join(' — ');
    return parts.join(' · ');
  }
}
