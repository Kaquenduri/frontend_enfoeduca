import 'AcademicPeriod.dart';
import 'Session.dart';

class Course {
  final String courseId;
  final String name;
  final String description;
  final String periodId;
  final String createdAt;
  final String updatedAt;
  final AcademicPeriod academicPeriod;
  final List<Session> sessions;

  const Course({
    required this.courseId,
    required this.name,
    required this.description,
    required this.periodId,
    required this.createdAt,
    required this.updatedAt,
    required this.academicPeriod,
    required this.sessions,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {
        'course_id': String courseId,
        'name': String name,
        'description': String description,
        'period_id': String periodId,
        'created_at': String createdAt,
        'updated_at': String updatedAt,
        'academicPeriod': Map<String, dynamic> academicPeriodJson,
        'sessions': List sessionsList,
      } =>
        Course(
          courseId: courseId,
          name: name,
          description: description,
          periodId: periodId,
          createdAt: createdAt,
          updatedAt: updatedAt,
          academicPeriod: AcademicPeriod.fromJson(academicPeriodJson),
          sessions: sessionsList
              .map(
                (session) => Session.fromJson(session as Map<String, dynamic>),
              )
              .toList(),
        ),
      _ => throw const FormatException('Failed to load Course.'),
    };
  }
}
