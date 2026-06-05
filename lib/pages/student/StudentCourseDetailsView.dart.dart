import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import 'package:go_router/go_router.dart';

// Importa tu modelo Course
import '../../models/Course.dart';

class StudentCourseDetailsView extends StatefulWidget {
  final String courseId;

  const StudentCourseDetailsView({super.key, required this.courseId});

  @override
  State<StudentCourseDetailsView> createState() =>
      _StudentCourseDetailsViewState();
}

class _StudentCourseDetailsViewState extends State<StudentCourseDetailsView> {
  late Future<Course> _courseFuture;

  @override
  void initState() {
    super.initState();
    // Disparar la petición HTTP usando el ID que nos dio GoRouter
    _courseFuture = _fetchCourseById(widget.courseId);
  }

  // Petición HTTP para obtener un solo curso detallado por ID
  Future<Course> _fetchCourseById(String id) async {
    final response = await ApiClient.get(ServiceType.academic, '/courses/$id');

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      // Usamos el mismo factory estricto con desestructuración de Dart 3
      return Course.fromJson(data);
    } else {
      throw Exception(
        'No se pudo obtener el detalle del curso. Código: ${response.statusCode}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Course>(
      future: _courseFuture,
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
                'Error al cargar el curso: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        } else if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('No encontrado')),
            body: const Center(
              child: Text('No se encontró información del curso.'),
            ),
          );
        }

        // Ya tenemos el objeto completo mapeado con tu modelo original
        final course = snapshot.data!;

        return DefaultTabController(
          length: 3,
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
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      letterSpacing: -0.5,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Periodo: ${course.academicPeriod.name}',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
              bottom: const TabBar(
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                tabs: [
                  Tab(icon: Icon(Icons.class_rounded), text: 'Sesiones'),
                  Tab(icon: Icon(Icons.info_rounded), text: 'Información'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                // Pestaña 1: Renderiza dinámicamente el listado de sesiones reales de este curso
                _buildSessionsTab(course),

                // Pestaña 2: Tareas del curso

                // Pestaña 3: Información detallada de base de datos
                _buildInfoTab(course),
              ],
            ),
          ),
        );
      },
    );
  }

  // Listar los temas o sesiones dinámicamente usando lo que viene en el modelo Course
  Widget _buildSessionsTab(Course course) {
    // Validamos si el curso actual no tiene sesiones registradas en el backend
    if (course.sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.class_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'No hay sesiones programadas',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Este curso aún no cuenta con temas registrados.',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
          ],
        ),
      );
    }

    // Si existen sesiones, las recorremos dinámicamente mapeando la lista real de la API
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: course.sessions.length,
      itemBuilder: (context, index) {
        final session = course.sessions[index];

        // Formateamos las fechas de inicio y fin que vienen en el submodelo Session
        final String formattedStart = _formatDate(
          DateTime.parse(session.startTime),
        );
        final String formattedEnd = _formatDate(
          DateTime.parse(session.endTime),
        );

        return InkWell(
          onTap: () {
            context.go(
              '/student/course/${course.courseId}/session/${session.sessionId}',
            );
          },
          child: _buildSessionTile(
            title: session.name,
            subtitle: 'Duración del tema: Del $formattedStart al $formattedEnd',
            status:
                'Vigente', // Puedes cambiarlo dinámicamente si tienes lógica de estados
            statusColor: Colors.blueAccent,
          ),
        );
      },
    );
  }

  Widget _buildSessionTile({
    required String title,
    required String subtitle,
    required String status,
    required Color statusColor,
  }) {
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
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6727E8), Color(0xFF5153E8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.menu_book_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6.0),
          child: Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              height: 1.3,
            ),
          ),
        ),
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
  }

  String _formatDate(DateTime date) {
    // PadLeft asegura que si el mes o día es menor a 10, guarde el formato de dos dígitos (ej: 05 en vez de 5)
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;

    return '$day/$month/$year'; // Te lo devolverá limpio como "31/05/2026"
  }

  Widget _buildInfoTab(Course course) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: ListView(
        children: [
          Container(
            padding: const EdgeInsets.all(24.0),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_rounded, color: Color(0xFF6727E8)),
                    const SizedBox(width: 8),
                    const Text(
                      'Metadatos del Curso',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF6727E8),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32),

                _buildInfoRow('Descripción:', course.description),
                const SizedBox(height: 16),
                _buildInfoRow('ID del Periodo:', course.academicPeriod.name),
                const SizedBox(height: 16),
                _buildInfoRow(
                  'Vigencia del Ciclo:',
                  'Desde ${_formatDate(course.academicPeriod.startDate)} hasta ${_formatDate(course.academicPeriod.endDate)}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
