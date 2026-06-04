// ignore_for_file: file_names
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import '../../services/api_service.dart';

class ParentStudentDetailsView extends StatefulWidget {
  final String studentId;

  const ParentStudentDetailsView({super.key, required this.studentId});

  @override
  State<ParentStudentDetailsView> createState() =>
      _ParentStudentDetailsViewState();
}

class _ParentStudentDetailsViewState extends State<ParentStudentDetailsView> {
  late Future<List<dynamic>> _attendancesFuture;
  late Future<List<dynamic>> _submissionsFuture;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _attendancesFuture = _fetchFilteredAttendances();
      _submissionsFuture = _fetchFilteredSubmissions();
    });
  }

  // HTTP GET & FILTER: Asistencias
  Future<List<dynamic>> _fetchFilteredAttendances() async {
    try {
      final String? token = await ApiService.getToken();
      final response = await http.get(
        Uri.parse(
          'https://academic-service-enfoenfoeduca-451053308845.us-central1.run.app/attendances/',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Error en asistencias (${response.statusCode})');
      }

      final List<dynamic> allAttendances = json.decode(response.body);
      // Filtrar únicamente los registros vinculados a este estudiante
      return allAttendances
          .where((item) => item['student_id'] == widget.studentId)
          .toList();
    } catch (e) {
      throw Exception('Fallo al cargar asistencias: $e');
    }
  }

  // HTTP GET & FILTER: Tareas / Notas (Submissions)
  Future<List<dynamic>> _fetchFilteredSubmissions() async {
    try {
      final String? token = await ApiService.getToken();
      final response = await http.get(
        Uri.parse(
          'https://academic-service-enfoenfoeduca-451053308845.us-central1.run.app/submissions/submission/',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Error en calificaciones (${response.statusCode})');
      }

      final List<dynamic> allSubmissions = json.decode(response.body);
      // Filtrar únicamente las tareas que correspondan a este estudiante
      return allSubmissions
          .where((item) => item['student_id'] == widget.studentId)
          .toList();
    } catch (e) {
      throw Exception('Fallo al cargar calificaciones: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.go('/parent'),
        ),
        title: Text(
          'Expediente Académico del Estudiante',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refreshData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        // Esperamos que ambas respuestas terminen concurrentemente
        future: Future.wait([_attendancesFuture, _submissionsFuture]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF2C1E3D)),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                'Ocurrió un error sincronizando la información:\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final List<dynamic> attendances = snapshot.data?[0] ?? [];
          final List<dynamic> submissions = snapshot.data?[1] ?? [];

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // SECTOR 1: ASISTENCIAS
                Expanded(flex: 1, child: _buildAttendanceSector(attendances)),
                const SizedBox(width: 24),
                // SECTOR 2: NOTAS / TAREAS
                Expanded(flex: 1, child: _buildSubmissionsSector(submissions)),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- DISEÑO DEL SECTOR DE ASISTENCIAS ---
  Widget _buildAttendanceSector(List<dynamic> attendances) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.edit_calendar_outlined,
                color: Colors.indigo.shade700,
                size: 22,
              ),
              const SizedBox(width: 10),
              const Text(
                'Control de Asistencia',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: attendances.isEmpty
                ? _buildEmptyState('No se registran asistencias tomadas.')
                : ListView.separated(
                    itemCount: attendances.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: Color(0xFFF1F3F5)),
                    itemBuilder: (context, index) {
                      final att = attendances[index];
                      final session = att['session'] ?? {};
                      final String sessionName =
                          session['name'] ?? 'Sesión sin título';
                      final String rawDate = att['attended_at'] ?? '';
                      final String dateFormatted = rawDate.length > 10
                          ? rawDate.substring(0, 10)
                          : rawDate;
                      final String status = att['status'] ?? 'UNKNOWN';

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 4,
                        ),
                        title: Text(
                          sessionName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          'Fecha: $dateFormatted',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 11,
                          ),
                        ),
                        trailing: _buildStatusBadge(status),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // --- DISEÑO DEL SECTOR DE NOTAS ---
  Widget _buildSubmissionsSector(List<dynamic> submissions) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.assignment_turned_in_outlined,
                color: Colors.amber.shade800,
                size: 22,
              ),
              const SizedBox(width: 10),
              const Text(
                'Calificaciones obtenidas',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: submissions.isEmpty
                ? _buildEmptyState(
                    'El estudiante no ha realizado entregas aún.',
                  )
                : ListView.separated(
                    itemCount: submissions.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: Color(0xFFF1F3F5)),
                    itemBuilder: (context, index) {
                      final sub = submissions[index];
                      final task = sub['task'] ?? {};
                      final String taskTitle =
                          task['title'] ?? 'Tarea sin título';
                      final dynamic rawNote = sub['note'];
                      final String state = sub['state'] ?? 'PENDING';

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 4,
                        ),
                        title: Text(
                          taskTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          'Estado: ${state == 'GRADED' ? 'Calificado' : 'Pendiente de revisión'}',
                          style: TextStyle(
                            color: state == 'GRADED'
                                ? Colors.grey.shade600
                                : Colors.amber.shade800,
                            fontSize: 11,
                            fontWeight: state != 'GRADED'
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                        ),
                        trailing: _buildNoteDisplay(rawNote),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // --- COMPONENTES VISUALES SECUNDARIOS (BADGES) ---
  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'PRESENT':
        bg = const Color(0xFFE6F4EA);
        fg = const Color(0xFF137333);
        label = 'Presente';
        break;
      case 'EXCUSED':
        bg = const Color(0xFFFEF7E0);
        fg = const Color(0xFFB06000);
        label = 'Justificado';
        break;
      default:
        bg = const Color(0xFFFCE8E6);
        fg = const Color(0xFFC5221F);
        label = 'Falta';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildNoteDisplay(dynamic note) {
    if (note == null) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          shape: BoxShape.circle,
        ),
        child: const Text(
          '-',
          style: TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      );
    }

    // Convertir a int si viene como string para evaluar el color del rendimiento
    final int score = int.tryParse(note.toString()) ?? 0;
    final bool isApproved = score >= 11; // Rango base escolar

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isApproved ? const Color(0xFFE8F0FE) : const Color(0xFFFCE8E6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isApproved ? Colors.blue.shade200 : Colors.red.shade200,
          width: 1,
        ),
      ),
      child: Text(
        score.toString().padLeft(2, '0'),
        style: TextStyle(
          color: isApproved ? Colors.blue.shade800 : Colors.red.shade800,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Text(
        msg,
        style: TextStyle(
          color: Colors.grey.shade400,
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
