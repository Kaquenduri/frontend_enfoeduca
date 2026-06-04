import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/api_service.dart';

class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({super.key});

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView> {
  late Future<Map<String, dynamic>> _adminDataFuture;

  @override
  void initState() {
    super.initState();
    _refreshAdminData();
  }

  void _refreshAdminData() {
    setState(() {
      _adminDataFuture = _fetchAllAdminData();
    });
  }

  Future<Map<String, dynamic>> _fetchAllAdminData() async {
    final String? token = await ApiService.getToken();
    final Map<String, String> headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    // Peticiones en paralelo incluyendo el nuevo endpoint de periodos
    final futures = await Future.wait([
      http.get(
        Uri.parse(
          'https://users-service-enfoenfoeduca-451053308845.us-central1.run.app/students/',
        ),
        headers: headers,
      ),
      http.get(
        Uri.parse(
          'https://users-service-enfoenfoeduca-451053308845.us-central1.run.app/teachers/',
        ),
        headers: headers,
      ),
      http.get(
        Uri.parse(
          'https://users-service-enfoenfoeduca-451053308845.us-central1.run.app/parents/',
        ),
        headers: headers,
      ),
      http.get(
        Uri.parse(
          'https://academic-service-enfoenfoeduca-451053308845.us-central1.run.app/courses/',
        ),
        headers: headers,
      ),
      http.get(
        Uri.parse(
          'https://academic-service-enfoenfoeduca-451053308845.us-central1.run.app/period/',
        ),
        headers: headers,
      ),
    ]);

    for (var response in futures) {
      if (response.statusCode != 200) {
        throw Exception(
          'Error en servicios del backend (Código: ${response.statusCode})',
        );
      }
    }

    final List<dynamic> studentsList = json.decode(futures[0].body);
    final List<dynamic> teachersList = json.decode(futures[1].body);
    final List<dynamic> parentsList = json.decode(futures[2].body);
    final List<dynamic> coursesList = json.decode(futures[3].body);
    final List<dynamic> periodsList = json.decode(futures[4].body);

    return {
      'total_students': studentsList.length,
      'total_teachers': teachersList.length,
      'total_parents': parentsList.length,
      'total_courses': coursesList.length,
      'courses_list': coursesList,
      'periods_list': periodsList,
    };
  }

  String _formatDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return '---';
    try {
      final DateTime parsed = DateTime.parse(rawDate).toLocal();
      return "${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}";
    } catch (_) {
      return rawDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Colors.transparent, // Permite que tome el fondo del Layout base
      appBar: AppBar(
        title: const Text(
          'Consola de Administración General',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.blueGrey),
            tooltip: 'Recargar Datos',
            onPressed: _refreshAdminData,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _adminDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF0F172A)),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error al cargar datos administrativos:\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final data = snapshot.data!;
          final List<dynamic> courses = data['courses_list'];
          final List<dynamic> periods = data['periods_list'];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildAdminStatCard(
                      'Estudiantes Registrados',
                      data['total_students'].toString(),
                      Icons.school_rounded,
                      Colors.blue,
                    ),
                    _buildAdminStatCard(
                      'Docentes Activos',
                      data['total_teachers'].toString(),
                      Icons.assignment_ind_rounded,
                      Colors.green,
                    ),
                    _buildAdminStatCard(
                      'Padres vinculados',
                      data['total_parents'].toString(),
                      Icons.people_alt_rounded,
                      Colors.purple,
                    ),
                    _buildAdminStatCard(
                      'Cursos en Sistema',
                      data['total_courses'].toString(),
                      Icons.auto_stories_rounded,
                      Colors.orange,
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 950) {
                      return Column(
                        children: [
                          _buildCoursesListContainer(courses),
                          const SizedBox(height: 24),
                          _buildPeriodsListContainer(periods),
                        ],
                      );
                    } else {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: _buildCoursesListContainer(courses),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 4,
                            child: _buildPeriodsListContainer(periods),
                          ),
                        ],
                      );
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Tarjeta de estadísticas básica para administración
  Widget _buildAdminStatCard(
    String title,
    String count,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  count,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Lista básica de cursos del sistema
  Widget _buildCoursesListContainer(List<dynamic> courses) {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nombres de Cursos Creados',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: courses.isEmpty
                ? const Center(
                    child: Text(
                      'No hay cursos registrados.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    itemCount: courses.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: Colors.grey.shade100),
                    itemBuilder: (context, index) {
                      final course = courses[index];
                      final String courseName = course['name'] ?? 'Sin nombre';
                      final String courseCode = course['code'] ?? 'S/C';

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: const Icon(
                          Icons.menu_book_rounded,
                          color: Colors.orangeAccent,
                          size: 18,
                        ),
                        title: Text(
                          courseName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          'Código: $courseCode',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // Módulo de periodos interactivos iterando Name, Start_date y End_date
  Widget _buildPeriodsListContainer(List<dynamic> periods) {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Periodos Académicos Configuraciones',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: periods.isEmpty
                ? const Center(
                    child: Text(
                      'No hay periodos registrados.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    itemCount: periods.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: Colors.grey.shade100),
                    itemBuilder: (context, index) {
                      final period = periods[index];
                      final String periodName =
                          period['name'] ?? 'Periodo Desconocido';
                      final String startDate = _formatDate(
                        period['start_date'],
                      );
                      final String endDate = _formatDate(period['end_date']);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.date_range_rounded,
                                color: Colors.blue,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    periodName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Inicio: $startDate  •  Fin: $endDate',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Activo',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
