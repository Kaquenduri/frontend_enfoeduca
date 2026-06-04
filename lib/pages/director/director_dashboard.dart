import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_service.dart';
import '../../services/api_client.dart';

class DirectorDashboardView extends StatefulWidget {
  const DirectorDashboardView({super.key});

  @override
  State<DirectorDashboardView> createState() => _DirectorDashboardViewState();
}

class _DirectorDashboardViewState extends State<DirectorDashboardView> {
  late Future<Map<String, dynamic>> _dashboardDataFuture;
  // Inicializa con la fecha actual del sistema
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _refreshDashboard();
  }

  void _refreshDashboard() {
    setState(() {
      _dashboardDataFuture = _fetchAllDirectorData();
    });
  }

  // Método encargado de limpiar el JWT y redirigir al login
  Future<void> _handleLogout() async {
    // 1. Mostrar confirmación visual opcional o proceder directamente
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Cerrar Sesión',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: const Text(
          '¿Está seguro de que desea salir del Panel Institucional?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Salir'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // 2. Elimina el JWT guardado en las preferencias/navegador
      await ApiService.logout();

      // 3. Redirige a la ruta de inicio de sesión (ajusta '/login' según tu appRouter)
      if (mounted) {
        context.go('/login');
      }
    }
  }

  Future<Map<String, dynamic>> _fetchAllDirectorData() async {
    // Orquestador de peticiones concurrentes
    final futures = await Future.wait([
      ApiClient.get(ServiceType.users, '/students/'),
      ApiClient.get(ServiceType.users, '/teachers/'),
      ApiClient.get(ServiceType.users, '/parents/'),
      ApiClient.get(ServiceType.academic, '/courses/'),
      ApiClient.get(ServiceType.academic, '/sections/'),
      ApiClient.get(ServiceType.academic, '/attendances/'),
    ]);

    for (var response in futures) {
      if (response.statusCode != 200) {
        throw Exception(
          'Error al conectar con los servicios académicos (${response.statusCode})',
        );
      }
    }

    final List<dynamic> studentsList = json.decode(futures[0].body);
    final List<dynamic> teachersList = json.decode(futures[1].body);
    final List<dynamic> parentsList = json.decode(futures[2].body);
    final List<dynamic> coursesList = json.decode(futures[3].body);
    final List<dynamic> sectionsList = json.decode(futures[4].body);
    final List<dynamic> attendancesList = json.decode(futures[5].body);

    final List<Map<String, dynamic>> sectionsWithCount = [];
    for (var sec in sectionsList) {
      final String secId = sec['id_section'] ?? sec['section_id'] ?? '';
      final String secName = sec['name'] ?? 'Sin Nombre';
      final String secGrade = sec['grade'] ?? '';

      final int count = studentsList.where((st) {
        if (st['id_section'] != null && st['id_section'] is Map) {
          final studentSectionId = st['id_section']['id_section'];
          return studentSectionId == secId;
        }
        return false;
      }).length;

      sectionsWithCount.add({
        'name': secGrade.isNotEmpty ? '$secGrade "$secName"' : secName,
        'student_count': count,
      });
    }

    return {
      'total_students': studentsList.length,
      'total_teachers': teachersList.length,
      'total_parents': parentsList.length,
      'total_courses': coursesList.length,
      'sections_data': sectionsWithCount,
      'raw_attendances': attendancesList,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text(
          'Panel de Control Institucional',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded, color: Colors.blueAccent),
            tooltip: 'Sincronizar Datos',
            onPressed: _refreshDashboard,
          ),
          const SizedBox(width: 8),
          // ==========================================
          // BOTÓN DE CERRAR SESIÓN ESTILIZADO
          // ==========================================
          IconButton(
            icon: Icon(Icons.logout_rounded, color: Colors.red.shade600),
            tooltip: 'Cerrar Sesión',
            onPressed: _handleLogout,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dashboardDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF1E293B)),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                key: const Key('error_state'),
                child: Text(
                  'Error de sincronización:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          final data = snapshot.data!;
          final List<Map<String, dynamic>> sections =
              List<Map<String, dynamic>>.from(data['sections_data']);
          final List<dynamic> rawAttendances = data['raw_attendances'];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildKpiCard(
                      'Estudiantes',
                      data['total_students'].toString(),
                      Icons.school_rounded,
                      Colors.blue,
                    ),
                    const SizedBox(width: 16),
                    _buildKpiCard(
                      'Docentes',
                      data['total_teachers'].toString(),
                      Icons.assignment_ind_rounded,
                      Colors.green,
                    ),
                    const SizedBox(width: 16),
                    _buildKpiCard(
                      'Padres de Familia',
                      data['total_parents'].toString(),
                      Icons.people_alt_rounded,
                      Colors.purple,
                    ),
                    const SizedBox(width: 16),
                    _buildKpiCard(
                      'Cursos Creados',
                      data['total_courses'].toString(),
                      Icons.auto_stories_rounded,
                      Colors.orange,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: _buildSectionsContainer(sections)),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 3,
                      child: _buildAttendanceCalendarSection(rawAttendances),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAttendanceCalendarSection(List<dynamic> attendancesList) {
    final List<dynamic> filteredAttendances = attendancesList.where((att) {
      final String rawDate = att['attended_at'] ?? '';
      if (rawDate.isEmpty) return false;

      try {
        final DateTime parsedDate = DateTime.parse(rawDate).toLocal();
        return parsedDate.year == _selectedDate.year &&
            parsedDate.month == _selectedDate.month &&
            parsedDate.day == _selectedDate.day;
      } catch (_) {
        return false;
      }
    }).toList();

    int presentCount = 0;
    int absentCount = 0;
    int excusedCount = 0;

    for (var att in filteredAttendances) {
      final String status = att['status'] ?? '';
      if (status == 'PRESENT') presentCount++;
      if (status == 'ABSENT') absentCount++;
      if (status == 'EXCUSED') excusedCount++;
    }

    final String formattedHeaderDate =
        "${_selectedDate.day.toString().padLeft(2, '0')} / ${_selectedDate.month.toString().padLeft(2, '0')} / ${_selectedDate.year}";

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Auditoría de Asistencias Diarias',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Fecha de inspección: $formattedHeaderDate',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2025),
                    lastDate: DateTime(2030),
                    locale: const Locale('es', 'ES'),
                  );
                  if (picked != null && picked != _selectedDate) {
                    setState(() {
                      _selectedDate = picked;
                    });
                  }
                },
                icon: const Icon(Icons.calendar_month_rounded, size: 18),
                label: const Text(
                  'Cambiar Fecha',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF151B26),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFE2E8F0), height: 1),
          const SizedBox(height: 12),

          SizedBox(
            height: 240,
            child: filteredAttendances.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_busy_rounded,
                          size: 40,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No se registraron asistencias en este día.',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredAttendances.length,
                    itemBuilder: (context, index) {
                      final item = filteredAttendances[index];
                      final String studentId =
                          item['student_id'] ?? 'ID Desconocido';
                      final String sessionName =
                          item['session']?['name'] ?? 'Clase sin título';
                      final String status = item['status'] ?? 'UNKNOWN';

                      String attendanceTime = '--:--';
                      if (item['attended_at'] != null) {
                        try {
                          final DateTime parsedTime = DateTime.parse(
                            item['attended_at'],
                          ).toLocal();
                          attendanceTime =
                              "${parsedTime.hour.toString().padLeft(2, '0')}:${parsedTime.minute.toString().padLeft(2, '0')}";
                        } catch (_) {}
                      }

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Estudiante: ${studentId.substring(0, 8)}...',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    sessionName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  attendanceTime,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade400,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                _buildStatusBadge(status),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          const SizedBox(height: 16),
          const Divider(color: Color(0xFFE2E8F0), height: 1),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildCounterMetric(
                label: 'PRESENTES',
                count: presentCount,
                color: Colors.green.shade600,
                icon: Icons.check_circle_outline_rounded,
              ),
              _buildCounterMetric(
                label: 'JUSTIFICADOS',
                count: excusedCount,
                color: Colors.amber.shade700,
                icon: Icons.info_outline_rounded,
              ),
              _buildCounterMetric(
                label: 'AUSENTES',
                count: absentCount,
                color: Colors.red.shade600,
                icon: Icons.remove_circle_outline_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    String text;

    switch (status) {
      case 'PRESENT':
        bgColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
        text = 'PRESENTE';
        break;
      case 'EXCUSED':
        bgColor = Colors.amber.shade50;
        textColor = Colors.amber.shade700;
        text = 'JUSTIFICADO';
        break;
      case 'ABSENT':
        bgColor = Colors.red.shade50;
        textColor = Colors.red.shade600;
        text = 'AUSENTE';
        break;
      default:
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey.shade600;
        text = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCounterMetric({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade500,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionsContainer(List<Map<String, dynamic>> sections) {
    return Container(
      height: 380,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Alumnado por Sección',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: sections.isEmpty
                ? const Center(
                    child: Text(
                      'No hay secciones configuradas.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  )
                : ListView.separated(
                    itemCount: sections.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: Color(0xFFF1F3F5)),
                    itemBuilder: (context, index) {
                      final item = sections[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: Colors.blueGrey.shade50,
                          child: const Icon(
                            Icons.roofing_rounded,
                            size: 18,
                            color: Colors.blueGrey,
                          ),
                        ),
                        title: Text(
                          item['name'],
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${item['student_count']} Alumnos',
                            style: TextStyle(
                              color: Colors.blue.shade800,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
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
}
