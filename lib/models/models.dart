class Student {
  final String id;
  final String matricule;
  final String firstName;
  final String lastName;
  final String filiere;
  final String niveau;
  final String status;
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

  factory Student.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map ? Map<String, dynamic>.from(json['user']) : const <String, dynamic>{};
    final level = json['level'] is Map ? Map<String, dynamic>.from(json['level']) : const <String, dynamic>{};
    final specialty = json['specialty'] is Map ? Map<String, dynamic>.from(json['specialty']) : const <String, dynamic>{};
    return Student(
      id: '${json['id'] ?? ''}',
      matricule: '${json['matricule'] ?? ''}',
      firstName: '${json['firstName'] ?? ''}',
      lastName: '${json['lastName'] ?? ''}',
      filiere: '${specialty['name'] ?? json['filiere'] ?? ''}',
      niveau: '${level['name'] ?? json['niveau'] ?? ''}',
      status: '${json['status'] ?? 'ACTIVE'}',
      email: '${user['email'] ?? json['email'] ?? ''}',
      phone: '${json['phone'] ?? ''}',
      ueIds: (json['ueIds'] is List ? (json['ueIds'] as List) : const []).map((value) => '$value').toList(),
    );
  }

  factory Student.fromAppwrite(Map<String, dynamic> data) {
    return Student(
      id: data['userId'] ?? '',
      matricule: data['matricule'] ?? '',
      firstName: (data['name'] ?? '').split(' ').first,
      lastName: (data['name'] ?? '').split(' ').skip(1).join(' '),
      filiere: data['program'] ?? '',
      niveau: data['level'] ?? 'L1',
      status: data['status'] ?? 'ACTIVE',
      email: data['email'] ?? '',
      phone: '',
      ueIds: [],
    );
  }

  String get fullName => '$firstName $lastName';
  String get initials => '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}';
}

class Teacher {
  final String id;
  final String firstName;
  final String lastName;
  final String status;
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

  factory Teacher.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map ? Map<String, dynamic>.from(json['user']) : const <String, dynamic>{};
    return Teacher(
      id: '${json['id'] ?? ''}',
      firstName: '${json['firstName'] ?? ''}',
      lastName: '${json['lastName'] ?? ''}',
      status: '${json['status'] ?? 'ACTIVE'}',
      email: '${user['email'] ?? json['email'] ?? ''}',
      department: '${json['department'] ?? ''}',
      ueIds: (json['ueIds'] is List ? (json['ueIds'] as List) : const []).map((value) => '$value').toList(),
    );
  }

  String get fullName => '$firstName $lastName';
  String get initials => '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}';
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

  factory UE.fromJson(Map<String, dynamic> json) => UE(
    id: '${json['id'] ?? ''}',
    code: '${json['code'] ?? ''}',
    title: '${json['title'] ?? json['name'] ?? ''}',
    credits: int.tryParse('${json['credits'] ?? 0}') ?? 0,
    cm: int.tryParse('${json['cm'] ?? 0}') ?? 0,
    td: int.tryParse('${json['td'] ?? 0}') ?? 0,
    tp: int.tryParse('${json['tp'] ?? 0}') ?? 0,
    description: '${json['description'] ?? ''}',
    colorHex: '${json['colorHex'] ?? '#2563EB'}',
  );
}

class Enrollment {
  final String id;
  final String studentId;
  final String ueId;
  final String status;
  final DateTime date;

  const Enrollment({
    required this.id,
    required this.studentId,
    required this.ueId,
    required this.status,
    required this.date,
  });

  factory Enrollment.fromJson(Map<String, dynamic> json) => Enrollment(
    id: '${json['id'] ?? ''}',
    studentId: '${json['studentId'] ?? ''}',
    ueId: '${json['teachingUnitId'] ?? json['ueId'] ?? ''}',
    status: '${json['status'] ?? ''}',
    date: DateTime.tryParse('${json['createdAt'] ?? json['date'] ?? ''}') ?? DateTime.now(),
  );
}
