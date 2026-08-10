import 'package:freezed_annotation/freezed_annotation.dart';

part 'models.freezed.dart';
part 'models.g.dart';

@freezed
class Student with _$Student {
  const Student._();

  const factory Student({
    required String id,
    required String matricule,
    required String firstName,
    required String lastName,
    required String filiere,
    required String niveau,
    required String status, // Actif / Suspendu
    required String email,
    required String phone,
    @Default([]) List<String> ueIds,
  }) = _Student;

  factory Student.fromJson(Map<String, dynamic> json) => _$StudentFromJson(json);

  String get fullName => '$firstName $lastName';
  String get initials =>
      '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}';
}

@freezed
class Teacher with _$Teacher {
  const Teacher._();

  const factory Teacher({
    required String id,
    required String firstName,
    required String lastName,
    required String status, // Permanent / Vacataire
    required String email,
    required String department,
    @Default([]) List<String> ueIds,
  }) = _Teacher;

  factory Teacher.fromJson(Map<String, dynamic> json) => _$TeacherFromJson(json);

  String get fullName => '$firstName $lastName';
  String get initials =>
      '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}';
}

@freezed
class UE with _$UE {
  const factory UE({
    required String id,
    required String code,
    required String title,
    required int credits,
    required int cm,
    required int td,
    required int tp,
    required String description,
    required String colorHex,
  }) = _UE;

  factory UE.fromJson(Map<String, dynamic> json) => _$UEFromJson(json);
}

@freezed
class Enrollment with _$Enrollment {
  const factory Enrollment({
    required String id,
    required String studentId,
    required String ueId,
    required String status, // En attente / Validée / Rejetée
    required DateTime date,
  }) = _Enrollment;

  factory Enrollment.fromJson(Map<String, dynamic> json) => _$EnrollmentFromJson(json);
}
