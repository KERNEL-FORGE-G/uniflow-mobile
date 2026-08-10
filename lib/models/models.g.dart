// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$StudentImpl _$$StudentImplFromJson(Map<String, dynamic> json) =>
    _$StudentImpl(
      id: json['id'] as String,
      matricule: json['matricule'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      filiere: json['filiere'] as String,
      niveau: json['niveau'] as String,
      status: json['status'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
      ueIds:
          (json['ueIds'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              const [],
    );

Map<String, dynamic> _$$StudentImplToJson(_$StudentImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'matricule': instance.matricule,
      'firstName': instance.firstName,
      'lastName': instance.lastName,
      'filiere': instance.filiere,
      'niveau': instance.niveau,
      'status': instance.status,
      'email': instance.email,
      'phone': instance.phone,
      'ueIds': instance.ueIds,
    };

_$TeacherImpl _$$TeacherImplFromJson(Map<String, dynamic> json) =>
    _$TeacherImpl(
      id: json['id'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      status: json['status'] as String,
      email: json['email'] as String,
      department: json['department'] as String,
      ueIds:
          (json['ueIds'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              const [],
    );

Map<String, dynamic> _$$TeacherImplToJson(_$TeacherImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'firstName': instance.firstName,
      'lastName': instance.lastName,
      'status': instance.status,
      'email': instance.email,
      'department': instance.department,
      'ueIds': instance.ueIds,
    };

_$UEImpl _$$UEImplFromJson(Map<String, dynamic> json) => _$UEImpl(
      id: json['id'] as String,
      code: json['code'] as String,
      title: json['title'] as String,
      credits: (json['credits'] as num).toInt(),
      cm: (json['cm'] as num).toInt(),
      td: (json['td'] as num).toInt(),
      tp: (json['tp'] as num).toInt(),
      description: json['description'] as String,
      colorHex: json['colorHex'] as String,
    );

Map<String, dynamic> _$$UEImplToJson(_$UEImpl instance) => <String, dynamic>{
      'id': instance.id,
      'code': instance.code,
      'title': instance.title,
      'credits': instance.credits,
      'cm': instance.cm,
      'td': instance.td,
      'tp': instance.tp,
      'description': instance.description,
      'colorHex': instance.colorHex,
    };

_$EnrollmentImpl _$$EnrollmentImplFromJson(Map<String, dynamic> json) =>
    _$EnrollmentImpl(
      id: json['id'] as String,
      studentId: json['studentId'] as String,
      ueId: json['ueId'] as String,
      status: json['status'] as String,
      date: DateTime.parse(json['date'] as String),
    );

Map<String, dynamic> _$$EnrollmentImplToJson(_$EnrollmentImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'studentId': instance.studentId,
      'ueId': instance.ueId,
      'status': instance.status,
      'date': instance.date.toIso8601String(),
    };
