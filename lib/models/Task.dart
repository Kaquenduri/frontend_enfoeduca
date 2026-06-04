// ignore_for_file: file_names
class Task {
  final String taskId;
  final String sessionId;
  final String title;
  final String description;
  final String startDate;
  final String dueDate;
  final String createdAt;
  final String updatedAt;

  const Task({
    required this.taskId,
    required this.sessionId,
    required this.title,
    required this.description,
    required this.startDate,
    required this.dueDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {
        'task_id': String taskId,
        'session_id': String sessionId,
        'title': String title,
        'description': String description,
        'start_date': String startDate,
        'due_date': String dueDate,
        'created_at': String createdAt,
        'updated_at': String updatedAt,
      } =>
        Task(
          taskId: taskId,
          sessionId: sessionId,
          title: title,
          description: description,
          startDate: startDate,
          dueDate: dueDate,
          createdAt: createdAt,
          updatedAt: updatedAt,
        ),
      _ => throw const FormatException('Failed to load Task.'),
    };
  }
}
