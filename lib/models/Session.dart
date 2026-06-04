// ignore_for_file: file_names
class Session {
  final String sessionId;
  final String courseId;
  final String name;
  final String startTime;
  final String endTime;
  final String createdAt;
  final String updatedAt;

  const Session({
    required this.sessionId,
    required this.courseId,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {
        'session_id': String sessionId,
        'course_id': String courseId,
        'name': String name,
        'start_time': String startTime,
        'end_time': String endTime,
        'created_at': String createdAt,
        'updated_at': String updatedAt,
      } =>
        Session(
          sessionId: sessionId,
          courseId: courseId,
          name: name,
          startTime: startTime,
          endTime: endTime,
          createdAt: createdAt,
          updatedAt: updatedAt,
        ),
      _ => throw const FormatException('Failed to load Session.'),
    };
  }
}
