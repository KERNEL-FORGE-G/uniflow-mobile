// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Student _$StudentFromJson(Map<String, dynamic> json) {
  return _Student.fromJson(json);
}

/// @nodoc
mixin _$Student {
  String get id => throw _privateConstructorUsedError;
  String get matricule => throw _privateConstructorUsedError;
  String get firstName => throw _privateConstructorUsedError;
  String get lastName => throw _privateConstructorUsedError;
  String get filiere => throw _privateConstructorUsedError;
  String get niveau => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError; // Actif / Suspendu
  String get email => throw _privateConstructorUsedError;
  String get phone => throw _privateConstructorUsedError;
  List<String> get ueIds => throw _privateConstructorUsedError;

  /// Serializes this Student to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Student
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $StudentCopyWith<Student> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $StudentCopyWith<$Res> {
  factory $StudentCopyWith(Student value, $Res Function(Student) then) =
      _$StudentCopyWithImpl<$Res, Student>;
  @useResult
  $Res call(
      {String id,
      String matricule,
      String firstName,
      String lastName,
      String filiere,
      String niveau,
      String status,
      String email,
      String phone,
      List<String> ueIds});
}

/// @nodoc
class _$StudentCopyWithImpl<$Res, $Val extends Student>
    implements $StudentCopyWith<$Res> {
  _$StudentCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Student
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? matricule = null,
    Object? firstName = null,
    Object? lastName = null,
    Object? filiere = null,
    Object? niveau = null,
    Object? status = null,
    Object? email = null,
    Object? phone = null,
    Object? ueIds = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      matricule: null == matricule
          ? _value.matricule
          : matricule // ignore: cast_nullable_to_non_nullable
              as String,
      firstName: null == firstName
          ? _value.firstName
          : firstName // ignore: cast_nullable_to_non_nullable
              as String,
      lastName: null == lastName
          ? _value.lastName
          : lastName // ignore: cast_nullable_to_non_nullable
              as String,
      filiere: null == filiere
          ? _value.filiere
          : filiere // ignore: cast_nullable_to_non_nullable
              as String,
      niveau: null == niveau
          ? _value.niveau
          : niveau // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      email: null == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String,
      phone: null == phone
          ? _value.phone
          : phone // ignore: cast_nullable_to_non_nullable
              as String,
      ueIds: null == ueIds
          ? _value.ueIds
          : ueIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$StudentImplCopyWith<$Res> implements $StudentCopyWith<$Res> {
  factory _$$StudentImplCopyWith(
          _$StudentImpl value, $Res Function(_$StudentImpl) then) =
      __$$StudentImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String matricule,
      String firstName,
      String lastName,
      String filiere,
      String niveau,
      String status,
      String email,
      String phone,
      List<String> ueIds});
}

/// @nodoc
class __$$StudentImplCopyWithImpl<$Res>
    extends _$StudentCopyWithImpl<$Res, _$StudentImpl>
    implements _$$StudentImplCopyWith<$Res> {
  __$$StudentImplCopyWithImpl(
      _$StudentImpl _value, $Res Function(_$StudentImpl) _then)
      : super(_value, _then);

  /// Create a copy of Student
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? matricule = null,
    Object? firstName = null,
    Object? lastName = null,
    Object? filiere = null,
    Object? niveau = null,
    Object? status = null,
    Object? email = null,
    Object? phone = null,
    Object? ueIds = null,
  }) {
    return _then(_$StudentImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      matricule: null == matricule
          ? _value.matricule
          : matricule // ignore: cast_nullable_to_non_nullable
              as String,
      firstName: null == firstName
          ? _value.firstName
          : firstName // ignore: cast_nullable_to_non_nullable
              as String,
      lastName: null == lastName
          ? _value.lastName
          : lastName // ignore: cast_nullable_to_non_nullable
              as String,
      filiere: null == filiere
          ? _value.filiere
          : filiere // ignore: cast_nullable_to_non_nullable
              as String,
      niveau: null == niveau
          ? _value.niveau
          : niveau // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      email: null == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String,
      phone: null == phone
          ? _value.phone
          : phone // ignore: cast_nullable_to_non_nullable
              as String,
      ueIds: null == ueIds
          ? _value._ueIds
          : ueIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$StudentImpl extends _Student {
  const _$StudentImpl(
      {required this.id,
      required this.matricule,
      required this.firstName,
      required this.lastName,
      required this.filiere,
      required this.niveau,
      required this.status,
      required this.email,
      required this.phone,
      final List<String> ueIds = const []})
      : _ueIds = ueIds,
        super._();

  factory _$StudentImpl.fromJson(Map<String, dynamic> json) =>
      _$$StudentImplFromJson(json);

  @override
  final String id;
  @override
  final String matricule;
  @override
  final String firstName;
  @override
  final String lastName;
  @override
  final String filiere;
  @override
  final String niveau;
  @override
  final String status;
// Actif / Suspendu
  @override
  final String email;
  @override
  final String phone;
  final List<String> _ueIds;
  @override
  @JsonKey()
  List<String> get ueIds {
    if (_ueIds is EqualUnmodifiableListView) return _ueIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_ueIds);
  }

  @override
  String toString() {
    return 'Student(id: $id, matricule: $matricule, firstName: $firstName, lastName: $lastName, filiere: $filiere, niveau: $niveau, status: $status, email: $email, phone: $phone, ueIds: $ueIds)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StudentImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.matricule, matricule) ||
                other.matricule == matricule) &&
            (identical(other.firstName, firstName) ||
                other.firstName == firstName) &&
            (identical(other.lastName, lastName) ||
                other.lastName == lastName) &&
            (identical(other.filiere, filiere) || other.filiere == filiere) &&
            (identical(other.niveau, niveau) || other.niveau == niveau) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.phone, phone) || other.phone == phone) &&
            const DeepCollectionEquality().equals(other._ueIds, _ueIds));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      matricule,
      firstName,
      lastName,
      filiere,
      niveau,
      status,
      email,
      phone,
      const DeepCollectionEquality().hash(_ueIds));

  /// Create a copy of Student
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$StudentImplCopyWith<_$StudentImpl> get copyWith =>
      __$$StudentImplCopyWithImpl<_$StudentImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$StudentImplToJson(
      this,
    );
  }
}

abstract class _Student extends Student {
  const factory _Student(
      {required final String id,
      required final String matricule,
      required final String firstName,
      required final String lastName,
      required final String filiere,
      required final String niveau,
      required final String status,
      required final String email,
      required final String phone,
      final List<String> ueIds}) = _$StudentImpl;
  const _Student._() : super._();

  factory _Student.fromJson(Map<String, dynamic> json) = _$StudentImpl.fromJson;

  @override
  String get id;
  @override
  String get matricule;
  @override
  String get firstName;
  @override
  String get lastName;
  @override
  String get filiere;
  @override
  String get niveau;
  @override
  String get status; // Actif / Suspendu
  @override
  String get email;
  @override
  String get phone;
  @override
  List<String> get ueIds;

  /// Create a copy of Student
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$StudentImplCopyWith<_$StudentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Teacher _$TeacherFromJson(Map<String, dynamic> json) {
  return _Teacher.fromJson(json);
}

/// @nodoc
mixin _$Teacher {
  String get id => throw _privateConstructorUsedError;
  String get firstName => throw _privateConstructorUsedError;
  String get lastName => throw _privateConstructorUsedError;
  String get status =>
      throw _privateConstructorUsedError; // Permanent / Vacataire
  String get email => throw _privateConstructorUsedError;
  String get department => throw _privateConstructorUsedError;
  List<String> get ueIds => throw _privateConstructorUsedError;

  /// Serializes this Teacher to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Teacher
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TeacherCopyWith<Teacher> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TeacherCopyWith<$Res> {
  factory $TeacherCopyWith(Teacher value, $Res Function(Teacher) then) =
      _$TeacherCopyWithImpl<$Res, Teacher>;
  @useResult
  $Res call(
      {String id,
      String firstName,
      String lastName,
      String status,
      String email,
      String department,
      List<String> ueIds});
}

/// @nodoc
class _$TeacherCopyWithImpl<$Res, $Val extends Teacher>
    implements $TeacherCopyWith<$Res> {
  _$TeacherCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Teacher
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? firstName = null,
    Object? lastName = null,
    Object? status = null,
    Object? email = null,
    Object? department = null,
    Object? ueIds = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      firstName: null == firstName
          ? _value.firstName
          : firstName // ignore: cast_nullable_to_non_nullable
              as String,
      lastName: null == lastName
          ? _value.lastName
          : lastName // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      email: null == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String,
      department: null == department
          ? _value.department
          : department // ignore: cast_nullable_to_non_nullable
              as String,
      ueIds: null == ueIds
          ? _value.ueIds
          : ueIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TeacherImplCopyWith<$Res> implements $TeacherCopyWith<$Res> {
  factory _$$TeacherImplCopyWith(
          _$TeacherImpl value, $Res Function(_$TeacherImpl) then) =
      __$$TeacherImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String firstName,
      String lastName,
      String status,
      String email,
      String department,
      List<String> ueIds});
}

/// @nodoc
class __$$TeacherImplCopyWithImpl<$Res>
    extends _$TeacherCopyWithImpl<$Res, _$TeacherImpl>
    implements _$$TeacherImplCopyWith<$Res> {
  __$$TeacherImplCopyWithImpl(
      _$TeacherImpl _value, $Res Function(_$TeacherImpl) _then)
      : super(_value, _then);

  /// Create a copy of Teacher
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? firstName = null,
    Object? lastName = null,
    Object? status = null,
    Object? email = null,
    Object? department = null,
    Object? ueIds = null,
  }) {
    return _then(_$TeacherImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      firstName: null == firstName
          ? _value.firstName
          : firstName // ignore: cast_nullable_to_non_nullable
              as String,
      lastName: null == lastName
          ? _value.lastName
          : lastName // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      email: null == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String,
      department: null == department
          ? _value.department
          : department // ignore: cast_nullable_to_non_nullable
              as String,
      ueIds: null == ueIds
          ? _value._ueIds
          : ueIds // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$TeacherImpl extends _Teacher {
  const _$TeacherImpl(
      {required this.id,
      required this.firstName,
      required this.lastName,
      required this.status,
      required this.email,
      required this.department,
      final List<String> ueIds = const []})
      : _ueIds = ueIds,
        super._();

  factory _$TeacherImpl.fromJson(Map<String, dynamic> json) =>
      _$$TeacherImplFromJson(json);

  @override
  final String id;
  @override
  final String firstName;
  @override
  final String lastName;
  @override
  final String status;
// Permanent / Vacataire
  @override
  final String email;
  @override
  final String department;
  final List<String> _ueIds;
  @override
  @JsonKey()
  List<String> get ueIds {
    if (_ueIds is EqualUnmodifiableListView) return _ueIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_ueIds);
  }

  @override
  String toString() {
    return 'Teacher(id: $id, firstName: $firstName, lastName: $lastName, status: $status, email: $email, department: $department, ueIds: $ueIds)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TeacherImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.firstName, firstName) ||
                other.firstName == firstName) &&
            (identical(other.lastName, lastName) ||
                other.lastName == lastName) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.department, department) ||
                other.department == department) &&
            const DeepCollectionEquality().equals(other._ueIds, _ueIds));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, firstName, lastName, status,
      email, department, const DeepCollectionEquality().hash(_ueIds));

  /// Create a copy of Teacher
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TeacherImplCopyWith<_$TeacherImpl> get copyWith =>
      __$$TeacherImplCopyWithImpl<_$TeacherImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TeacherImplToJson(
      this,
    );
  }
}

abstract class _Teacher extends Teacher {
  const factory _Teacher(
      {required final String id,
      required final String firstName,
      required final String lastName,
      required final String status,
      required final String email,
      required final String department,
      final List<String> ueIds}) = _$TeacherImpl;
  const _Teacher._() : super._();

  factory _Teacher.fromJson(Map<String, dynamic> json) = _$TeacherImpl.fromJson;

  @override
  String get id;
  @override
  String get firstName;
  @override
  String get lastName;
  @override
  String get status; // Permanent / Vacataire
  @override
  String get email;
  @override
  String get department;
  @override
  List<String> get ueIds;

  /// Create a copy of Teacher
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TeacherImplCopyWith<_$TeacherImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

UE _$UEFromJson(Map<String, dynamic> json) {
  return _UE.fromJson(json);
}

/// @nodoc
mixin _$UE {
  String get id => throw _privateConstructorUsedError;
  String get code => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  int get credits => throw _privateConstructorUsedError;
  int get cm => throw _privateConstructorUsedError;
  int get td => throw _privateConstructorUsedError;
  int get tp => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  String get colorHex => throw _privateConstructorUsedError;

  /// Serializes this UE to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of UE
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UECopyWith<UE> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UECopyWith<$Res> {
  factory $UECopyWith(UE value, $Res Function(UE) then) =
      _$UECopyWithImpl<$Res, UE>;
  @useResult
  $Res call(
      {String id,
      String code,
      String title,
      int credits,
      int cm,
      int td,
      int tp,
      String description,
      String colorHex});
}

/// @nodoc
class _$UECopyWithImpl<$Res, $Val extends UE> implements $UECopyWith<$Res> {
  _$UECopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of UE
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? code = null,
    Object? title = null,
    Object? credits = null,
    Object? cm = null,
    Object? td = null,
    Object? tp = null,
    Object? description = null,
    Object? colorHex = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      code: null == code
          ? _value.code
          : code // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      credits: null == credits
          ? _value.credits
          : credits // ignore: cast_nullable_to_non_nullable
              as int,
      cm: null == cm
          ? _value.cm
          : cm // ignore: cast_nullable_to_non_nullable
              as int,
      td: null == td
          ? _value.td
          : td // ignore: cast_nullable_to_non_nullable
              as int,
      tp: null == tp
          ? _value.tp
          : tp // ignore: cast_nullable_to_non_nullable
              as int,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      colorHex: null == colorHex
          ? _value.colorHex
          : colorHex // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$UEImplCopyWith<$Res> implements $UECopyWith<$Res> {
  factory _$$UEImplCopyWith(_$UEImpl value, $Res Function(_$UEImpl) then) =
      __$$UEImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String code,
      String title,
      int credits,
      int cm,
      int td,
      int tp,
      String description,
      String colorHex});
}

/// @nodoc
class __$$UEImplCopyWithImpl<$Res> extends _$UECopyWithImpl<$Res, _$UEImpl>
    implements _$$UEImplCopyWith<$Res> {
  __$$UEImplCopyWithImpl(_$UEImpl _value, $Res Function(_$UEImpl) _then)
      : super(_value, _then);

  /// Create a copy of UE
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? code = null,
    Object? title = null,
    Object? credits = null,
    Object? cm = null,
    Object? td = null,
    Object? tp = null,
    Object? description = null,
    Object? colorHex = null,
  }) {
    return _then(_$UEImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      code: null == code
          ? _value.code
          : code // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      credits: null == credits
          ? _value.credits
          : credits // ignore: cast_nullable_to_non_nullable
              as int,
      cm: null == cm
          ? _value.cm
          : cm // ignore: cast_nullable_to_non_nullable
              as int,
      td: null == td
          ? _value.td
          : td // ignore: cast_nullable_to_non_nullable
              as int,
      tp: null == tp
          ? _value.tp
          : tp // ignore: cast_nullable_to_non_nullable
              as int,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      colorHex: null == colorHex
          ? _value.colorHex
          : colorHex // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$UEImpl implements _UE {
  const _$UEImpl(
      {required this.id,
      required this.code,
      required this.title,
      required this.credits,
      required this.cm,
      required this.td,
      required this.tp,
      required this.description,
      required this.colorHex});

  factory _$UEImpl.fromJson(Map<String, dynamic> json) =>
      _$$UEImplFromJson(json);

  @override
  final String id;
  @override
  final String code;
  @override
  final String title;
  @override
  final int credits;
  @override
  final int cm;
  @override
  final int td;
  @override
  final int tp;
  @override
  final String description;
  @override
  final String colorHex;

  @override
  String toString() {
    return 'UE(id: $id, code: $code, title: $title, credits: $credits, cm: $cm, td: $td, tp: $tp, description: $description, colorHex: $colorHex)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UEImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.code, code) || other.code == code) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.credits, credits) || other.credits == credits) &&
            (identical(other.cm, cm) || other.cm == cm) &&
            (identical(other.td, td) || other.td == td) &&
            (identical(other.tp, tp) || other.tp == tp) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.colorHex, colorHex) ||
                other.colorHex == colorHex));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, code, title, credits, cm, td, tp, description, colorHex);

  /// Create a copy of UE
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UEImplCopyWith<_$UEImpl> get copyWith =>
      __$$UEImplCopyWithImpl<_$UEImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$UEImplToJson(
      this,
    );
  }
}

abstract class _UE implements UE {
  const factory _UE(
      {required final String id,
      required final String code,
      required final String title,
      required final int credits,
      required final int cm,
      required final int td,
      required final int tp,
      required final String description,
      required final String colorHex}) = _$UEImpl;

  factory _UE.fromJson(Map<String, dynamic> json) = _$UEImpl.fromJson;

  @override
  String get id;
  @override
  String get code;
  @override
  String get title;
  @override
  int get credits;
  @override
  int get cm;
  @override
  int get td;
  @override
  int get tp;
  @override
  String get description;
  @override
  String get colorHex;

  /// Create a copy of UE
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UEImplCopyWith<_$UEImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Enrollment _$EnrollmentFromJson(Map<String, dynamic> json) {
  return _Enrollment.fromJson(json);
}

/// @nodoc
mixin _$Enrollment {
  String get id => throw _privateConstructorUsedError;
  String get studentId => throw _privateConstructorUsedError;
  String get ueId => throw _privateConstructorUsedError;
  String get status =>
      throw _privateConstructorUsedError; // En attente / Validée / Rejetée
  DateTime get date => throw _privateConstructorUsedError;

  /// Serializes this Enrollment to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Enrollment
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EnrollmentCopyWith<Enrollment> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EnrollmentCopyWith<$Res> {
  factory $EnrollmentCopyWith(
          Enrollment value, $Res Function(Enrollment) then) =
      _$EnrollmentCopyWithImpl<$Res, Enrollment>;
  @useResult
  $Res call(
      {String id, String studentId, String ueId, String status, DateTime date});
}

/// @nodoc
class _$EnrollmentCopyWithImpl<$Res, $Val extends Enrollment>
    implements $EnrollmentCopyWith<$Res> {
  _$EnrollmentCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Enrollment
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? studentId = null,
    Object? ueId = null,
    Object? status = null,
    Object? date = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      studentId: null == studentId
          ? _value.studentId
          : studentId // ignore: cast_nullable_to_non_nullable
              as String,
      ueId: null == ueId
          ? _value.ueId
          : ueId // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      date: null == date
          ? _value.date
          : date // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$EnrollmentImplCopyWith<$Res>
    implements $EnrollmentCopyWith<$Res> {
  factory _$$EnrollmentImplCopyWith(
          _$EnrollmentImpl value, $Res Function(_$EnrollmentImpl) then) =
      __$$EnrollmentImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id, String studentId, String ueId, String status, DateTime date});
}

/// @nodoc
class __$$EnrollmentImplCopyWithImpl<$Res>
    extends _$EnrollmentCopyWithImpl<$Res, _$EnrollmentImpl>
    implements _$$EnrollmentImplCopyWith<$Res> {
  __$$EnrollmentImplCopyWithImpl(
      _$EnrollmentImpl _value, $Res Function(_$EnrollmentImpl) _then)
      : super(_value, _then);

  /// Create a copy of Enrollment
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? studentId = null,
    Object? ueId = null,
    Object? status = null,
    Object? date = null,
  }) {
    return _then(_$EnrollmentImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      studentId: null == studentId
          ? _value.studentId
          : studentId // ignore: cast_nullable_to_non_nullable
              as String,
      ueId: null == ueId
          ? _value.ueId
          : ueId // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      date: null == date
          ? _value.date
          : date // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$EnrollmentImpl implements _Enrollment {
  const _$EnrollmentImpl(
      {required this.id,
      required this.studentId,
      required this.ueId,
      required this.status,
      required this.date});

  factory _$EnrollmentImpl.fromJson(Map<String, dynamic> json) =>
      _$$EnrollmentImplFromJson(json);

  @override
  final String id;
  @override
  final String studentId;
  @override
  final String ueId;
  @override
  final String status;
// En attente / Validée / Rejetée
  @override
  final DateTime date;

  @override
  String toString() {
    return 'Enrollment(id: $id, studentId: $studentId, ueId: $ueId, status: $status, date: $date)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EnrollmentImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.studentId, studentId) ||
                other.studentId == studentId) &&
            (identical(other.ueId, ueId) || other.ueId == ueId) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.date, date) || other.date == date));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, studentId, ueId, status, date);

  /// Create a copy of Enrollment
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EnrollmentImplCopyWith<_$EnrollmentImpl> get copyWith =>
      __$$EnrollmentImplCopyWithImpl<_$EnrollmentImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$EnrollmentImplToJson(
      this,
    );
  }
}

abstract class _Enrollment implements Enrollment {
  const factory _Enrollment(
      {required final String id,
      required final String studentId,
      required final String ueId,
      required final String status,
      required final DateTime date}) = _$EnrollmentImpl;

  factory _Enrollment.fromJson(Map<String, dynamic> json) =
      _$EnrollmentImpl.fromJson;

  @override
  String get id;
  @override
  String get studentId;
  @override
  String get ueId;
  @override
  String get status; // En attente / Validée / Rejetée
  @override
  DateTime get date;

  /// Create a copy of Enrollment
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EnrollmentImplCopyWith<_$EnrollmentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
