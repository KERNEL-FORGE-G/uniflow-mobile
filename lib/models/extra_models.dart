/// Simple models for schedules, courses, classrooms and notifications.
/// These are NOT freezed – they use plain Dart classes for simplicity
/// and to avoid code generation.

class Schedule {
  final String id;
  final String courseId;
  final String dayOfWeek;
  final String startTime;
  final String endTime;
  final String? classroomId;
  final Course? course;
  final Classroom? classroom;

  Schedule({
    required this.id,
    required this.courseId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.classroomId,
    this.course,
    this.classroom,
  });

  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
      id: json['id'] ?? '',
      courseId: json['courseId'] ?? '',
      dayOfWeek: json['dayOfWeek'] ?? '',
      startTime: json['startTime'] ?? '',
      endTime: json['endTime'] ?? '',
      classroomId: json['classroomId'],
      course: json['course'] != null ? Course.fromJson(json['course']) : null,
      classroom: json['classroom'] != null ? Classroom.fromJson(json['classroom']) : null,
    );
  }

  /// Returns a formatted time like "08:00" from ISO date string.
  String get formattedStart {
    try {
      final dt = DateTime.parse(startTime);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return startTime;
    }
  }

  String get formattedEnd {
    try {
      final dt = DateTime.parse(endTime);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return endTime;
    }
  }
}

class Course {
  final String id;
  final String teachingUnitId;
  final String teacherId;
  final String classroomId;
  final String type; // CM, TD, TP
  final String groupLabel;
  final TeachingUnitRef? teachingUnit;
  final TeacherRef? teacher;
  final Classroom? classroom;

  Course({
    required this.id,
    required this.teachingUnitId,
    required this.teacherId,
    required this.classroomId,
    required this.type,
    required this.groupLabel,
    this.teachingUnit,
    this.teacher,
    this.classroom,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'] ?? '',
      teachingUnitId: json['teachingUnitId'] ?? '',
      teacherId: json['teacherId'] ?? '',
      classroomId: json['classroomId'] ?? '',
      type: json['type'] ?? '',
      groupLabel: json['groupLabel'] ?? '',
      teachingUnit: json['teachingUnit'] != null ? TeachingUnitRef.fromJson(json['teachingUnit']) : null,
      teacher: json['teacher'] != null ? TeacherRef.fromJson(json['teacher']) : null,
      classroom: json['classroom'] != null ? Classroom.fromJson(json['classroom']) : null,
    );
  }

  String get displayName {
    if (teachingUnit != null) return '${teachingUnit!.code} - $type $groupLabel';
    return '$type $groupLabel';
  }
}

class TeachingUnitRef {
  final String id;
  final String code;
  final String title;

  TeachingUnitRef({required this.id, required this.code, required this.title});

  factory TeachingUnitRef.fromJson(Map<String, dynamic> json) {
    return TeachingUnitRef(
      id: json['id'] ?? '',
      code: json['code'] ?? '',
      title: json['title'] ?? '',
    );
  }
}

class TeacherRef {
  final String id;
  final String firstName;
  final String lastName;

  TeacherRef({required this.id, required this.firstName, required this.lastName});

  factory TeacherRef.fromJson(Map<String, dynamic> json) {
    return TeacherRef(
      id: json['id'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
    );
  }

  String get fullName => '$firstName $lastName';
}

class Classroom {
  final String id;
  final String name;
  final String building;
  final int capacity;
  final String type; // AMPHITHEATRE, SALLE_TD, SALLE_TP, LABO

  Classroom({
    required this.id,
    required this.name,
    required this.building,
    required this.capacity,
    required this.type,
  });

  factory Classroom.fromJson(Map<String, dynamic> json) {
    return Classroom(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      building: json['building'] ?? '',
      capacity: json['capacity'] ?? 0,
      type: json['type'] ?? '',
    );
  }

  String get typeLabel {
    switch (type) {
      case 'AMPHITHEATRE': return 'Amphi';
      case 'SALLE_TD': return 'Salle TD';
      case 'SALLE_TP': return 'Salle TP';
      case 'LABO': return 'Laboratoire';
      default: return type;
    }
  }
}

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? json['message'] ?? '',
      type: json['type'] ?? 'INFO',
      isRead: json['isRead'] ?? json['read'] ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}

class StatsOverview {
  final int totalStudents;
  final int totalTeachers;
  final int totalUEs;
  final int totalClassrooms;
  final int totalCourses;
  final Map<String, dynamic> raw;

  StatsOverview({
    required this.totalStudents,
    required this.totalTeachers,
    required this.totalUEs,
    required this.totalClassrooms,
    required this.totalCourses,
    required this.raw,
  });

  factory StatsOverview.fromJson(Map<String, dynamic> json) {
    return StatsOverview(
      totalStudents: json['totalStudents'] ?? json['students'] ?? 0,
      totalTeachers: json['totalTeachers'] ?? json['teachers'] ?? 0,
      totalUEs: json['totalUEs'] ?? json['ues'] ?? json['teachingUnits'] ?? 0,
      totalClassrooms: json['totalClassrooms'] ?? json['classrooms'] ?? 0,
      totalCourses: json['totalCourses'] ?? json['courses'] ?? 0,
      raw: json,
    );
  }
}
