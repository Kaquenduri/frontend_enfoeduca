// ignore_for_file: file_names
import 'Section.dart';
import 'users.dart';

class Student extends User {
  final String studentId;
  final String parentId;
  final Section section;

  const Student({
    required super.userId,
    required super.name,
    required super.lastName,
    required super.email,
    required super.state,
    required this.studentId,
    required this.parentId,
    required this.section,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {
        'student_id': String studentId,
        'user_id': Map<String, dynamic> user,
        'parent_id': String parentId,
        'id_section': Map<String, dynamic> section,
      } =>
        Student(
          studentId: studentId,

          userId: user['user_id'],
          name: user['name'],
          lastName: user['last_name'],
          email: user['email'],
          state: user['state'],

          parentId: parentId,

          section: Section.fromJson(section),
        ),

      _ => throw const FormatException('Failed to load student.'),
    };
  }
}
