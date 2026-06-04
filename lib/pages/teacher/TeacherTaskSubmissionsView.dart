// ignore_for_file: file_names
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_client.dart';
import '../../models/Student.dart';

class TeacherTaskSubmissionsView extends StatefulWidget {
  final String courseId;
  final String sectionId;
  final String sessionId;
  final String taskId;

  const TeacherTaskSubmissionsView({
    super.key,
    required this.courseId,
    required this.sectionId,
    required this.sessionId,
    required this.taskId,
  });

  @override
  State<TeacherTaskSubmissionsView> createState() =>
      _TeacherTaskSubmissionsViewState();
}

class _TeacherTaskSubmissionsViewState
    extends State<TeacherTaskSubmissionsView> {
  late Future<Map<String, dynamic>> _taskDetailsFuture;
  final Map<String, String> _studentNames = {};
  bool _isLoadingNames = false;

  @override
  void initState() {
    super.initState();
    _refreshTaskDetails();
  }

  void _refreshTaskDetails() {
    setState(() {
      _taskDetailsFuture = _fetchTaskDetailsAndNames(widget.taskId);
    });
  }

  Future<Map<String, dynamic>> _fetchTaskDetailsAndNames(String taskId) async {
    final response = await ApiClient.get(ServiceType.academic, '/tasks/$taskId');

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final List<dynamic> submissions = data['task_submissions'] ?? [];

      if (submissions.isNotEmpty) {
        setState(() {
          _isLoadingNames = true;
        });

        final List<String> missingIds = submissions
            .map((sub) => sub['student_id'] as String)
            .where((id) => !_studentNames.containsKey(id))
            .toList();

        if (missingIds.isNotEmpty) {
          try {
            await Future.wait(
              missingIds.map((studentId) async {
                final studentRes = await ApiClient.get(ServiceType.users, '/students/$studentId');

                if (studentRes.statusCode == 200) {
                  final studentData =
                      json.decode(studentRes.body) as Map<String, dynamic>;
                  final parsedStudent = Student.fromJson(studentData);
                  _studentNames[studentId] =
                      '${parsedStudent.name} ${parsedStudent.lastName}';
                } else {
                  _studentNames[studentId] = 'Código: $studentId';
                }
              }),
            );
          } catch (e) {
            debugPrint('Error obteniendo nombres de alumnos: $e');
          }
        }

        if (mounted) {
          setState(() {
            _isLoadingNames = false;
          });
        }
      }
      return data;
    } else {
      throw Exception(
        'Error al obtener el detalle de la tarea y sus entregas.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _taskDetailsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Colors.teal)),
          );
        } else if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        final taskData = snapshot.data!;
        final String taskTitle = taskData['title'] ?? 'Entregas';
        final List<dynamic> submissions = taskData['task_submissions'] ?? [];

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            elevation: 0.5,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go(
                '/teacher/course/${widget.courseId}/sectionId/${widget.sectionId}/session/${widget.sessionId}',
              ),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  taskTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Total de entregas: ${submissions.length}',
                  style: const TextStyle(fontSize: 12, color: Colors.teal),
                ),
              ],
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isLoadingNames)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: LinearProgressIndicator(color: Colors.teal),
                  ),
                Expanded(
                  child: submissions.isEmpty
                      ? const Center(
                          child: Text(
                            'No hay entregas registradas para esta tarea.',
                          ),
                        )
                      : ListView.builder(
                          itemCount: submissions.length,
                          itemBuilder: (context, index) {
                            final submission = submissions[index];
                            final String studentId =
                                submission['student_id'] ?? '';
                            final String submissionId =
                                submission['submission_id'] ?? '';
                            final String studentName =
                                _studentNames[studentId] ??
                                'Cargando... ($studentId)';
                            final String state =
                                submission['state'] ?? 'PENDING';
                            final String note = submission['note'] ?? '-';

                            Color stateColor = Colors.orange;
                            if (state == 'GRADED') stateColor = Colors.green;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: stateColor.withValues(alpha: 0.1),
                                  child: Icon(Icons.person, color: stateColor),
                                ),
                                title: Text(
                                  studentName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                subtitle: Text(
                                  'Estado: $state • Nota: $note',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right,
                                  color: Colors.teal,
                                  size: 18,
                                ),
                                onTap: () async {
                                  // Al regresar del detalle, refrescamos por si se guardaron cambios o notas
                                  await context.push(
                                    '/teacher/course/${widget.courseId}/sectionId/${widget.sectionId}/session/${widget.sessionId}/task/${widget.taskId}/submission/$submissionId',
                                    extra: {
                                      'submission': submission,
                                      'studentName': studentName,
                                    },
                                  );
                                  _refreshTaskDetails();
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
