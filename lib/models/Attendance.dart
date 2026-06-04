// ignore_for_file: file_names
import 'Session.dart';
import 'AcademicPeriod.dart';

enum AttendanceState {
  present,
  absent,
  excused,
  unknown;

  static AttendanceState fromString(String value) {
    return switch (value.toUpperCase()) {
      'PRESENT' => AttendanceState.present,
      'ABSENT' => AttendanceState.absent,
      'EXCUSED' => AttendanceState.excused,
      _ => AttendanceState.unknown,
    };
  }

  String toShortString() => name.toUpperCase();
}

class Attendance {
  final String attendanceId;
  final String sessionId;
  final String studentId;
  final AttendanceState status; // Mantiene el tipo AttendanceState
  final String attendedAt;
  final String periodId;
  final Session session;
  final AcademicPeriod academicPeriod;

  const Attendance({
    required this.attendanceId,
    required this.sessionId,
    required this.studentId,
    required this.status,
    required this.attendedAt,
    required this.periodId,
    required this.session,
    required this.academicPeriod,
  });

  factory Attendance.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {
        'attendance_id': String attendanceId,
        'session_id': String sessionId,
        'student_id': String studentId,
        'status': String statusStr,
        'attended_at': String attendedAt,
        'period_id': String periodId,
        'session': Map<String, dynamic> sessionJson,
        'academicPeriod': Map<String, dynamic> academicPeriodJson,
      } =>
        Attendance(
          attendanceId: attendanceId,
          sessionId: sessionId,
          studentId: studentId,
          status: AttendanceState.fromString(statusStr), // Conversión limpia
          attendedAt: attendedAt,
          periodId: periodId,
          session: Session.fromJson(sessionJson),
          academicPeriod: AcademicPeriod.fromJson(academicPeriodJson),
        ),
      _ => throw const FormatException('Failed to load Attendance.'),
    };
  }
}
