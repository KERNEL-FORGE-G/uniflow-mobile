import 'package:dio/dio.dart';
import '../models/models.dart';

class UniFlowApi {
  static const defaultBaseUrl = 'https://api-uniflow.kernelforge.codes/api/v1';
  final Dio _dio;

  UniFlowApi({String? token})
      : _dio = Dio(BaseOptions(
          baseUrl: const String.fromEnvironment('UNIFLOW_API_BASE_URL', defaultValue: defaultBaseUrl),
          connectTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 20),
          headers: {
            'Accept': 'application/json',
            if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
          },
        ));

  bool get isConfigured =>
      const String.fromEnvironment('UNIFLOW_API_BASE_URL', defaultValue: defaultBaseUrl).isNotEmpty;

  Future<List<Student>> fetchStudents() async {
    final response = await _dio.get('/students', queryParameters: {'page': 1, 'pageSize': 100});
    return _items(response.data).map((item) => Student.fromJson(item)).toList();
  }

  Future<List<Teacher>> fetchTeachers() async {
    final response = await _dio.get('/teachers', queryParameters: {'page': 1, 'pageSize': 100});
    return _items(response.data).map((item) => Teacher.fromJson(item)).toList();
  }

  Future<List<UE>> fetchTeachingUnits() async {
    final response = await _dio.get('/ue', queryParameters: {'page': 1, 'pageSize': 100});
    return _items(response.data).map((item) => UE.fromJson(item)).toList();
  }

  List<Map<String, dynamic>> _items(dynamic payload) {
    final data = payload is Map && payload['data'] is List ? payload['data'] : payload;
    if (data is! List) return const [];
    return data.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }
}
