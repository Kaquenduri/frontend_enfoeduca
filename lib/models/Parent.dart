// ignore_for_file: file_names
import 'Student.dart';
import 'users.dart';

class Parent extends User {
  final String parentId;
  final String phone;
  final String occupation;
  final List<Student> students;

  const Parent({
    required super.userId,
    required super.name,
    required super.lastName,
    required super.email,
    required super.state,
    required this.parentId,
    required this.phone,
    required this.occupation,
    required this.students,
  });

  factory Parent.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {
        'parent_id': String parentId,
        'user_id': Map<String, dynamic> user,
        'phone': String phone,
        'occupation': String occupation,
        'students': List students,
      } =>
        Parent(
          parentId: parentId,

          userId: user['user_id'],
          name: user['name'],
          lastName: user['last_name'],
          email: user['email'],
          state: user['state'],

          phone: phone,
          occupation: occupation,

          students: students
              .map(
                (student) => Student.fromJson(student as Map<String, dynamic>),
              )
              .toList(),
        ),

      _ => throw const FormatException('Failed to load parent go.'),
    };
  }
}
