import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../models/models.dart';

final studentServiceProvider = Provider<StudentService>((ref) {
  return StudentService(ref.watch(apiClientProvider));
});

final teacherServiceProvider = Provider<TeacherService>((ref) {
  return TeacherService(ref.watch(apiClientProvider));
});

final ueServiceProvider = Provider<UEService>((ref) {
  return UEService(ref.watch(apiClientProvider));
});

final enrollmentServiceProvider = Provider<EnrollmentService>((ref) {
  return EnrollmentService(ref.watch(apiClientProvider));
});

List<T> _parseList<T>(dynamic data, T Function(Map<String, dynamic>) fromJson) {
  if (data is List) {
    return data.map((e) => fromJson(e as Map<String, dynamic>)).toList();
  } else if (data != null && data['data'] is List) {
    return (data['data'] as List).map((e) => fromJson(e as Map<String, dynamic>)).toList();
  } else if (data != null && data['items'] is List) {
    return (data['items'] as List).map((e) => fromJson(e as Map<String, dynamic>)).toList();
  }
  return [];
}

class StudentService {
  final Dio dio;
  StudentService(this.dio);

  Future<List<Student>> getStudents(int page, int pageSize) async {
    final response = await dio.get('/students', queryParameters: {
      'page': page,
      'pageSize': pageSize,
    });
    return _parseList(response.data, Student.fromJson);
  }

  Future<Student> getStudent(String id) async {
    final response = await dio.get('/students/$id');
    return Student.fromJson(response.data);
  }
}

class TeacherService {
  final Dio dio;
  TeacherService(this.dio);

  Future<List<Teacher>> getTeachers(int page, int pageSize) async {
    final response = await dio.get('/teachers', queryParameters: {
      'page': page,
      'pageSize': pageSize,
    });
    return _parseList(response.data, Teacher.fromJson);
  }
  
  Future<Teacher> getTeacher(String id) async {
    final response = await dio.get('/teachers/$id');
    return Teacher.fromJson(response.data);
  }
}

class UEService {
  final Dio dio;
  UEService(this.dio);

  Future<List<UE>> getUEs(int page, int pageSize) async {
    final response = await dio.get('/ue', queryParameters: {
      'page': page,
      'pageSize': pageSize,
    });
    return _parseList(response.data, UE.fromJson);
  }
  
  Future<UE> getUE(String id) async {
    final response = await dio.get('/ue/$id');
    return UE.fromJson(response.data);
  }
}

class EnrollmentService {
  final Dio dio;
  EnrollmentService(this.dio);

  Future<List<Enrollment>> getEnrollments(int page, int pageSize) async {
    final response = await dio.get('/enrollments', queryParameters: {
      'page': page,
      'pageSize': pageSize,
    });
    return _parseList(response.data, Enrollment.fromJson);
  }
  
  Future<Enrollment> getEnrollment(String id) async {
    final response = await dio.get('/enrollments/$id');
    return Enrollment.fromJson(response.data);
  }
}
