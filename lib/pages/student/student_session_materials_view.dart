import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_client.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:url_launcher/url_launcher.dart'; // <--- 1. NUEVA IMPORTACIÓN
import '../../services/api_service.dart';

class StudentSessionMaterialsView extends StatefulWidget {
  final String courseId;
  final String sessionId;

  const StudentSessionMaterialsView({
    super.key,
    required this.courseId,
    required this.sessionId,
  });

  @override
  State<StudentSessionMaterialsView> createState() =>
      _StudentSessionMaterialsViewState();
}

class _StudentSessionMaterialsViewState
    extends State<StudentSessionMaterialsView> {
  late Future<Map<String, dynamic>> _sessionDetailsFuture;
  String? _loggedStudentId;

  @override
  void initState() {
    super.initState();
    _sessionDetailsFuture = _fetchSessionDetails(widget.sessionId);
    _loadStudentIdFromJWT();
  }

  Future<void> _loadStudentIdFromJWT() async {
    final token = await ApiService.getToken();
    if (token != null && token.isNotEmpty) {
      try {
        final Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
        setState(() {
          _loggedStudentId = decodedToken['student_id'];
        });
      } catch (e) {
        debugPrint('Error al decodificar el JWT: $e');
      }
    }
  }

  Future<Map<String, dynamic>> _fetchSessionDetails(String sessionId) async {
    final response = await ApiClient.get(
      ServiceType.academic,
      '/courses/sessions/$sessionId',
    );

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Error al obtener el detalle de la sesión');
    }
  }

  // 2. FUNCIÓN ASÍNCRONA SEGURA PARA ABRIR LOS ENLACES
  Future<void> _openMaterialUrl(String urlString) async {
    if (urlString.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El material no tiene una URL válida.')),
        );
      }
      return;
    }

    final Uri url = Uri.parse(urlString);
    try {
      // mode: LaunchMode.externalApplication es perfecto para Web y Mobile
      // En Web abre una nueva pestaña, en Mobile abre el navegador del celular o visor PDF
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'No se pudo abrir la URL';
      }
    } catch (e) {
      debugPrint('Error al abrir material: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo abrir el archivo de forma nativa.'),
            action: SnackBarAction(
              label: 'Copiar Link',
              onPressed: () {
                // Opcional: podrías copiar al portapapeles aquí si falla
              },
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _sessionDetailsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
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

        final sessionData = snapshot.data!;
        final String sessionName = sessionData['name'] ?? 'Detalle de Sesión';

        final List<dynamic> materials = sessionData['materials'] ?? [];
        final List<dynamic> tasks = sessionData['tasks'] ?? [];
        final List<dynamic> attendances = sessionData['attendances'] ?? [];

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            appBar: AppBar(
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF6727E8), Color(0xFF5153E8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              foregroundColor: Colors.white,
              elevation: 10,
              shadowColor: const Color(0xFF6727E8).withValues(alpha: 0.4),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () =>
                    context.go('/student/course/${widget.courseId}'),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sessionName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  _buildAttendanceBadge(attendances, _loggedStudentId),
                ],
              ),
              bottom: const TabBar(
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                tabs: [
                  Tab(
                    icon: Icon(Icons.folder_open_rounded),
                    text: 'Materiales',
                  ),
                  Tab(icon: Icon(Icons.assignment_rounded), text: 'Tareas'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _buildMaterialsList(materials),
                _buildTasksList(tasks),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttendanceBadge(
    List<dynamic> attendances,
    String? currentStudentId,
  ) {
    if (attendances.isEmpty) {
      return const Text(
        'Asistencia: Sin registrar',
        style: TextStyle(fontSize: 12, color: Colors.grey),
      );
    }

    if (currentStudentId == null) {
      return const Text(
        'Asistencia: Cargando datos del alumno...',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final studentAttendance = attendances.firstWhere(
      (attendance) => attendance['student_id'] == currentStudentId,
      orElse: () => null,
    );

    if (studentAttendance == null) {
      return const Text(
        'Asistencia: No registrado en esta sesión',
        style: TextStyle(fontSize: 12, color: Colors.grey),
      );
    }

    final status = studentAttendance['status'] ?? 'UNKNOWN';
    final isPresent = status == 'PRESENT';

    return Row(
      children: [
        const Text(
          'Asistencia: ',
          style: TextStyle(fontSize: 12, color: Colors.white70),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isPresent
                ? Colors.greenAccent.withValues(alpha: 0.2)
                : Colors.redAccent.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            isPresent ? 'PRESENTE' : 'FALTA',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isPresent ? Colors.greenAccent : Colors.redAccent,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMaterialsList(List<dynamic> materials) {
    if (materials.isEmpty) {
      return _buildEmptyState(
        Icons.folder_open,
        'No hay materiales en esta sesión',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: materials.length,
      itemBuilder: (context, index) {
        final material = materials[index];
        final String title = material['title'] ?? 'Sin título';
        final String description = material['description'] ?? 'Sin descripción';
        final String fileType = material['file_type'] ?? '';
        final String fileUrl = material['file_url'] ?? '';

        IconData itemIcon = Icons.insert_drive_file_outlined;
        Color iconColor = Colors.blueAccent;

        if (fileType.toLowerCase() == '.pdf') {
          itemIcon = Icons.picture_as_pdf_rounded;
          iconColor = Colors.redAccent;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 12,
            ),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(itemIcon, color: iconColor, size: 22),
            ),
            title: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
            subtitle: Text(
              description,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                height: 1.3,
              ),
            ),
            onTap: () => _openMaterialUrl(fileUrl),
            trailing: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6727E8).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Color(0xFF6727E8),
                size: 16,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTasksList(List<dynamic> tasks) {
    if (tasks.isEmpty) {
      return _buildEmptyState(
        Icons.task_alt,
        'No hay tareas asignadas para este tema',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        final String taskId = task['task_id'] ?? '';
        final String title = task['title'] ?? 'Tarea de la sesión';
        final String dueDateRaw = task['due_date'] ?? '';

        String formattedDate = 'Sin fecha';
        if (dueDateRaw.isNotEmpty) {
          try {
            final parsedDate = DateTime.parse(dueDateRaw);
            formattedDate =
                "${parsedDate.day}/${parsedDate.month}/${parsedDate.year}";
          } catch (_) {}
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 12,
            ),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.assignment,
                color: Colors.orangeAccent,
                size: 22,
              ),
            ),
            title: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_month_rounded,
                    size: 14,
                    color: Colors.redAccent.shade200,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Entregar: $formattedDate',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.redAccent.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            trailing: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.orangeAccent,
                size: 16,
              ),
            ),
            onTap: () {
              context.go(
                '/student/course/${widget.courseId}/session/${widget.sessionId}/task/$taskId',
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 54, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
