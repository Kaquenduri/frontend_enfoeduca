// ignore_for_file: file_names
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_client.dart';
import '../../models/Course.dart';
import '../../models/Student.dart';

class TeacherCourseDetailsView extends StatefulWidget {
  final String courseId;
  final String sectionId; // <--- Nuevo parámetro recibido desde el Dashboard

  const TeacherCourseDetailsView({
    super.key,
    required this.courseId,
    required this.sectionId,
  });

  @override
  State<TeacherCourseDetailsView> createState() =>
      _TeacherCourseDetailsViewState();
}

class _TeacherCourseDetailsViewState extends State<TeacherCourseDetailsView> {
  late Future<Course> _courseFuture;

  @override
  void initState() {
    super.initState();
    _refreshCourse();
  }

  void _refreshCourse() {
    setState(() {
      _courseFuture = _fetchCourseById(widget.courseId);
    });
  }

  Future<Course> _fetchCourseById(String id) async {
    final response = await ApiClient.get(ServiceType.academic, '/courses/$id');

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return Course.fromJson(data);
    } else {
      throw Exception('No se pudo obtener el detalle del curso.');
    }
  }

  // =========================================================================
  // LÓGICA COMPUESTA: OBTENER ALUMNOS -> CREAR SESIÓN -> CREAR ASISTENCIAS
  // =========================================================================
  Future<void> _processSessionCreation({
    required String name,
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      // 1. Obtener todos los alumnos del microservicio de usuarios
      final studentsResponse = await ApiClient.get(
        ServiceType.users,
        '/students/',
      );

      if (studentsResponse.statusCode != 200) {
        throw Exception('Error al obtener la lista global de alumnos.');
      }

      final List<dynamic> allStudentsJson = json.decode(studentsResponse.body);
      final List<Student> allStudents = allStudentsJson
          .map((jsonItem) => Student.fromJson(jsonItem as Map<String, dynamic>))
          .toList();

      // 2. Filtrar localmente usando la propiedad exacta de tu modelo: idSection
      final List<Student> sectionStudents = allStudents
          .where((student) => student.section.idSection == widget.sectionId)
          .toList();

      // 3. Crear la sesión en el servicio académico
      final sessionResponse = await ApiClient.post(
        ServiceType.academic,
        '/courses/sessions/create',
        body: {
          "course_id": widget.courseId,
          "name": name,
          "start_time": start.toUtc().toIso8601String(),
          "end_time": end.toUtc().toIso8601String(),
        },
      );

      if (sessionResponse.statusCode != 201 &&
          sessionResponse.statusCode != 200) {
        throw Exception('Error en el servidor al registrar la sesión.');
      }

      final Map<String, dynamic> createdSession = json.decode(
        sessionResponse.body,
      );
      final String newSessionId = createdSession['session_id'] ?? '';

      if (newSessionId.isEmpty) {
        throw Exception('El servidor no retornó un ID válido.');
      }

      // 4. Registrar las asistencias en "EXCUSED" usando student.section.idPeriod
      if (sectionStudents.isNotEmpty) {
        for (var student in sectionStudents) {
          final String currentPeriodId = student.section.idPeriod;

          await ApiClient.post(
            ServiceType.academic,
            '/attendances/create',
            body: {
              "session_id": newSessionId,
              "student_id": student.studentId,
              "status": "EXCUSED",
              "period_id": currentPeriodId,
            },
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '¡Sesión creada y ${sectionStudents.length} asistencias inicializadas!',
            ),
            backgroundColor: Colors.teal,
          ),
        );
      }
      _refreshCourse();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error en el proceso: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddSessionDialog() {
    final nameController = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              title: const Row(
                children: [
                  Icon(Icons.add_box_outlined, color: Colors.teal),
                  SizedBox(width: 8),
                  Text(
                    'Nueva Sesión / Tema',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nombre del Tema:',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        hintText: 'Ej: Tema 2: La historia de Misa',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 13,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Fecha de Inicio:',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      icon: const Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Colors.teal,
                      ),
                      label: Text(
                        startDate == null
                            ? 'Seleccionar fecha'
                            : _formatDate(startDate!),
                        style: TextStyle(
                          color: startDate == null
                              ? Colors.grey.shade600
                              : Colors.black87,
                          fontSize: 13,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 42),
                        alignment: Alignment.centerLeft,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2025),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setModalState(() => startDate = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Fecha de Fin:',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      icon: const Icon(
                        Icons.calendar_month,
                        size: 16,
                        color: Colors.teal,
                      ),
                      label: Text(
                        endDate == null
                            ? 'Seleccionar fecha'
                            : _formatDate(endDate!),
                        style: TextStyle(
                          color: endDate == null
                              ? Colors.grey.shade600
                              : Colors.black87,
                          fontSize: 13,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 42),
                        alignment: Alignment.centerLeft,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: startDate ?? DateTime.now(),
                          firstDate: DateTime(2025),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setModalState(() => endDate = picked);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    if (nameController.text.trim().isEmpty ||
                        startDate == null ||
                        endDate == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Por favor, rellena todos los campos.'),
                        ),
                      );
                      return;
                    }
                    Navigator.pop(context);
                    _processSessionCreation(
                      name: nameController.text.trim(),
                      start: startDate!,
                      end: endDate!,
                    );
                  },
                  child: const Text('Guardar Tema'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Course>(
      future: _courseFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Colors.teal)),
          );
        } else if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        final course = snapshot.data!;

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            appBar: AppBar(
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              foregroundColor: Colors.white,
              elevation: 10,
              shadowColor: const Color(0xFF1E3A8A).withValues(alpha: 0.4),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'Panel Docente • Sección ID: ${widget.sectionId}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                onPressed: () => context.go('/teacher'),
              ),
              bottom: const TabBar(
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                tabs: [
                  Tab(
                    icon: Icon(Icons.folder_shared_rounded),
                    text: 'Planificación de Sesiones',
                  ),
                  Tab(
                    icon: Icon(Icons.info_rounded),
                    text: 'Información del Aula',
                  ),
                ],
              ),
            ),
            body: TabBarView(
              children: [_buildSessionsTab(course), _buildInfoTab(course)],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSessionsTab(Course course) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Temas Programados',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showAddSessionDialog,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text(
                  'Agregar Sesión',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: course.sessions.isEmpty
                ? const Center(child: Text('No hay sesiones registradas'))
                : ListView.builder(
                    itemCount: course.sessions.length,
                    itemBuilder: (context, index) {
                      final session = course.sessions[index];
                      return InkWell(
                        onTap: () {
                          // Navegación pasando todos los IDs requeridos de manera correlativa
                          context.go(
                            '/teacher/course/${widget.courseId}/sectionId/${widget.sectionId}/session/${session.sessionId}',
                          );
                        },
                        child: _buildSessionTile(
                          title: session.name,
                          subtitle: 'Vigencia programada',
                          status: 'Gestionar',
                          statusColor: const Color(0xFF1E3A8A),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionTile({
    required String title,
    required String subtitle,
    required String status,
    required Color statusColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.play_lesson_rounded, color: statusColor, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: Colors.black54,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTab(Course course) =>
      const Center(child: Text('Información del Aula'));

  String _formatDate(DateTime date) =>
      "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
}
