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
    final response = await ApiClient.get(ServiceType.academic, '/courses/sessions/$sessionId');

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
            backgroundColor: const Color(0xFFF8F9FA),
            appBar: AppBar(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              elevation: 0.5,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () =>
                    context.go('/student/course/${widget.courseId}'),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sessionName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  _buildAttendanceBadge(attendances, _loggedStudentId),
                ],
              ),
              bottom: const TabBar(
                labelColor: Colors.blueAccent,
                unselectedLabelColor: Colors.black54,
                indicatorColor: Colors.blueAccent,
                tabs: [
                  Tab(
                    icon: Icon(Icons.folder_open_outlined),
                    text: 'Materiales de Clase',
                  ),
                  Tab(
                    icon: Icon(Icons.assignment_outlined),
                    text: 'Tareas Asignadas',
                  ),
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
          'Tu Asistencia: ',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isPresent
                ? Colors.green.withValues(alpha: 0.1)
                : Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            isPresent ? 'PRESENTE' : 'FALTA',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isPresent ? Colors.green : Colors.red,
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
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
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
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text(
              description,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            // 3. SE ASOCIA LA ACCIÓN AL BOTÓN DEL COSTADO Y AL TOCAR TODA LA FILA
            onTap: () => _openMaterialUrl(fileUrl),
            trailing: IconButton(
              icon: const Icon(Icons.open_in_new, color: Colors.blueAccent),
              onPressed: () => _openMaterialUrl(fileUrl),
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
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.01),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
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
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                'Entregar hasta: $formattedDate',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Colors.grey,
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
