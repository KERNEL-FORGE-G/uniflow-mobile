import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../models/extra_models.dart';

List<T> _parseList<T>(dynamic data, T Function(Map<String, dynamic>) fromJson) {
  if (data is List) {
    return data.map((e) => fromJson(e as Map<String, dynamic>)).toList();
  } else if (data is Map) {
    if (data['data'] is List) {
      return (data['data'] as List).map((e) => fromJson(e as Map<String, dynamic>)).toList();
    }
    if (data['items'] is List) {
      return (data['items'] as List).map((e) => fromJson(e as Map<String, dynamic>)).toList();
    }
  }
  return [];
}

// ─── Schedule Service ───
class ScheduleService {
  final Dio dio;
  ScheduleService(this.dio);

  Future<List<Schedule>> getSchedules() async {
    final response = await dio.get('/schedules');
    return _parseList(response.data, Schedule.fromJson);
  }

  Future<List<Schedule>> getMySchedules() async {
    final response = await dio.get('/schedules/my');
    return _parseList(response.data, Schedule.fromJson);
  }
}

final scheduleServiceProvider = Provider<ScheduleService>((ref) {
  return ScheduleService(ref.watch(apiClientProvider));
});

// ─── Course Service ───
class CourseService {
  final Dio dio;
  CourseService(this.dio);

  Future<List<Course>> getCourses() async {
    final response = await dio.get('/courses');
    return _parseList(response.data, Course.fromJson);
  }

  Future<List<Course>> getMyCourses() async {
    final response = await dio.get('/courses/my');
    return _parseList(response.data, Course.fromJson);
  }
}

final courseServiceProvider = Provider<CourseService>((ref) {
  return CourseService(ref.watch(apiClientProvider));
});

// ─── Classroom Service ───
class ClassroomService {
  final Dio dio;
  ClassroomService(this.dio);

  Future<List<Classroom>> getClassrooms() async {
    final response = await dio.get('/classrooms');
    return _parseList(response.data, Classroom.fromJson);
  }

  Future<Classroom> getClassroom(String id) async {
    final response = await dio.get('/classrooms/$id');
    final data = response.data is Map && response.data['data'] != null
        ? response.data['data']
        : response.data;
    return Classroom.fromJson(data);
  }
}

final classroomServiceProvider = Provider<ClassroomService>((ref) {
  return ClassroomService(ref.watch(apiClientProvider));
});

// ─── Notification Service ───
class NotificationService {
  final Dio dio;
  NotificationService(this.dio);

  Future<List<AppNotification>> getNotifications() async {
    final response = await dio.get('/notifications');
    return _parseList(response.data, AppNotification.fromJson);
  }

  Future<int> getUnreadCount() async {
    final response = await dio.get('/notifications/unread-count');
    final data = response.data;
    if (data is Map && data['data'] != null) {
      return data['data'] is int ? data['data'] : int.tryParse(data['data'].toString()) ?? 0;
    }
    return data is int ? data : 0;
  }

  Future<void> markAsRead(String id) async {
    await dio.patch('/notifications/$id/read');
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref.watch(apiClientProvider));
});

// ─── Stats Service ───
class StatsService {
  final Dio dio;
  StatsService(this.dio);

  Future<StatsOverview> getOverview() async {
    final response = await dio.get('/stats/overview');
    final data = response.data is Map && response.data['data'] != null
        ? response.data['data']
        : response.data;
    return StatsOverview.fromJson(data);
  }
}

final statsServiceProvider = Provider<StatsService>((ref) {
  return StatsService(ref.watch(apiClientProvider));
});
