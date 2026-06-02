import 'Section.dart';
import 'Course.dart';
import 'AcademicPeriod.dart';

class Assignment {
  final String idSection;
  final String courseId;
  final String periodId;
  final String teacherId;
  final String assignedAt;
  final Section section;
  final Course course;
  final AcademicPeriod academicPeriod;

  const Assignment({
    required this.idSection,
    required this.courseId,
    required this.periodId,
    required this.teacherId,
    required this.assignedAt,
    required this.section,
    required this.course,
    required this.academicPeriod,
  });

  factory Assignment.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {
        'id_section': String idSection,
        'course_id': String courseId,
        'period_id': String periodId,
        'teacher_id': String teacherId,
        'assigned_at': String assignedAt,
        'section': Map<String, dynamic> sectionJson,
        'course': Map<String, dynamic> courseJson,
        'academicperiod': Map<String, dynamic> academicPeriodJson,
      } =>
        Assignment(
          idSection: idSection,
          courseId: courseId,
          periodId: periodId,
          teacherId: teacherId,
          assignedAt: assignedAt,
          // Inyectamos el academicPeriod requerido por tu modelo Section existente
          section: Section.fromJson({
            ...sectionJson,
            'academicPeriod': academicPeriodJson,
          }),
          // Mapeamos el curso (pasando una lista vacía por defecto para las sesiones)
          course: Course.fromJson({
            ...courseJson,
            'academicPeriod': academicPeriodJson,
            'sessions': const [],
          }),
          academicPeriod: AcademicPeriod.fromJson(academicPeriodJson),
        ),
      _ => throw const FormatException('Failed to load Assignment.'),
    };
  }
}
