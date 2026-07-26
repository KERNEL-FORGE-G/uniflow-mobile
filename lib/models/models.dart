class Student {
  final String id;
  final String matricule;
  final String firstName;
  final String lastName;
  final String filiere;
  final String niveau;
  final String status; // Actif / Suspendu
  final String email;
  final String phone;
  final List<String> ueIds;

  const Student({
    required this.id,
    required this.matricule,
    required this.firstName,
    required this.lastName,
    required this.filiere,
    required this.niveau,
    required this.status,
    required this.email,
    required this.phone,
    required this.ueIds,
  });

  String get fullName => '$firstName $lastName';
  String get initials =>
      '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}';
}

class Teacher {
  final String id;
  final String firstName;
  final String lastName;
  final String status; // Permanent / Vacataire
  final String email;
  final String department;
  final List<String> ueIds;

  const Teacher({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.status,
    required this.email,
    required this.department,
    required this.ueIds,
  });

  String get fullName => '$firstName $lastName';
  String get initials =>
      '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}';
}

class UE {
  final String id;
  final String code;
  final String title;
  final int credits;
  final int cm;
  final int td;
  final int tp;
  final String description;
  final String colorHex;

  const UE({
    required this.id,
    required this.code,
    required this.title,
    required this.credits,
    required this.cm,
    required this.td,
    required this.tp,
    required this.description,
    required this.colorHex,
  });
}

class Enrollment {
  final String id;
  final String studentId;
  final String ueId;
  final String status; // En attente / Validée / Rejetée
  final DateTime date;

  const Enrollment({
    required this.id,
    required this.studentId,
    required this.ueId,
    required this.status,
    required this.date,
  });
}
