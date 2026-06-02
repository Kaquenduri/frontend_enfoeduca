import 'users.dart';

class Teacher extends User {
  final String teacherId;
  final String speciality;

  const Teacher({
    required super.userId,
    required super.name,
    required super.lastName,
    required super.email,
    required super.state,
    required this.teacherId,
    required this.speciality,
  });

  factory Teacher.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {
        'teacher_id': String teacherId,
        'user_id': Map<String, dynamic> user,
        'speciality': String speciality,
      } =>
        Teacher(
          teacherId: teacherId,

          userId: user['user_id'],
          name: user['name'],
          lastName: user['last_name'],
          email: user['email'],
          state: user['state'],

          speciality: speciality,
        ),

      _ => throw const FormatException('Failed to load teacher.'),
    };
  }
}
