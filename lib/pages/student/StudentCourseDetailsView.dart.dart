import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/api_service.dart';
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
    final response = await http.get(
      Uri.parse(
        'https://academic-service-enfoenfoeduca-451053308845.us-central1.run.app/courses/$id',
      ),
      headers: {'Authorization': 'Bearer ${await ApiService.getToken()}'},
    );

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
            backgroundColor: const Color(0xFFF8F9FA),
            appBar: AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.name, // Nombre real del curso de la API
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    'Periodo: ${course.academicPeriod.name}', // Periodo real de la API
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              elevation: 0.5,
              bottom: const TabBar(
                labelColor: Colors.blueAccent,
                unselectedLabelColor: Colors.black54,
                indicatorColor: Colors.blueAccent,
                tabs: [
                  Tab(
                    icon: Icon(Icons.class_outlined),
                    text: 'Sesiones y Temas',
                  ),

                  Tab(icon: Icon(Icons.info_outline), text: 'Información'),
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
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.menu_book_rounded, color: statusColor, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            status,
            style: TextStyle(
              color: statusColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
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
          Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Metadatos del Curso',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Divider(height: 24),

                  _buildInfoRow('Descripción:', course.description),
                  const SizedBox(height: 12),
                  _buildInfoRow('ID del Periodo:', course.academicPeriod.name),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    'Vigencia del Ciclo:',
                    'Desde ${_formatDate(course.academicPeriod.startDate)} hasta ${_formatDate(course.academicPeriod.endDate)}',
                  ),
                ],
              ),
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
