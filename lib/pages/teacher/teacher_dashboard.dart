import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart'; // Importación para decodificar el JWT en la vista
import '../../services/api_service.dart';
import '../../models/TeacherAssignment.dart';

class TeacherDashboard extends StatelessWidget {
  final Widget? child;

  const TeacherDashboard({super.key, this.child});

  void _logout(BuildContext context) async {
    await ApiService.logout();
    if (context.mounted) context.go('/login');
  }

  /// Proceso de decodificación y filtrado de asignaciones directo en la vista para el docente
  Future<List<TeacherAssignment>> _fetchFilteredAssignments() async {
    try {
      // 1. Obtener el token desde el ApiService
      final String? token = await ApiService.getToken();

      if (token == null || token.isEmpty) {
        throw Exception('No se encontró una sesión activa (Token nulo).');
      }

      // 2. Decodificar el JWT directamente para extraer el teacher_id inyectado por el backend
      Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
      final currentTeacherId = decodedToken['teacher_id'];

      if (currentTeacherId == null) {
        throw Exception(
          'El usuario autenticado no posee el rol o ID de Docente.',
        );
      }

      // Encabezados con el Token de autorización
      final Map<String, String> requestHeaders = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      // 3. Petición HTTP al endpoint global de asignaciones
      final response = await http.get(
        Uri.parse(
          'https://academic-service-enfoenfoeduca-451053308845.us-central1.run.app/assignments/',
        ),
        headers: requestHeaders,
      );

      if (response.statusCode != 200) {
        throw Exception('Error al cargar asignaciones: ${response.statusCode}');
      }

      final List<dynamic> data = json.decode(response.body);
      final List<TeacherAssignment> filteredList = [];

      // 4. Filtrar únicamente las asignaciones que le pertenezcan a este profesor
      for (var jsonItem in data) {
        if (jsonItem['teacher_id'] == currentTeacherId) {
          filteredList.add(
            TeacherAssignment.fromJson(jsonItem as Map<String, dynamic>),
          );
        }
      }

      return filteredList;
    } catch (e) {
      throw Exception(
        'Error de red al sincronizar asignaciones del docente: $e',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    return Scaffold(
      body: Row(
        children: [
          // ===================================
          // MENÚ LATERAL IZQUIERDO (PROFESOR)
          // ===================================
          Container(
            width: 100,
            color: const Color(
              0xFF151B26,
            ), // Tono sutilmente distinto para diferenciar roles
            child: Column(
              children: [
                const SizedBox(height: 24),
                const CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.blueAccent,
                  child: Icon(
                    Icons.co_present_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Docente',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white12, height: 1),

                // Items del Menú del Profesor
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _buildMenuButton(
                        context: context,
                        icon: Icons.dashboard_customize_outlined,
                        label: 'Cursos',
                        targetPath: '/teacher/dashboard',
                        currentPath: location,
                      ),
                      _buildMenuButton(
                        context: context,
                        icon: Icons.rate_review_outlined,
                        label: 'Calificar',
                        targetPath: '/teacher/grading',
                        currentPath: location,
                      ),
                      _buildMenuButton(
                        context: context,
                        icon: Icons.analytics_outlined,
                        label: 'Reportes',
                        targetPath: '/teacher/reports',
                        currentPath: location,
                      ),
                    ],
                  ),
                ),

                const Divider(color: Colors.white12, height: 1),
                _buildMenuButton(
                  context: context,
                  icon: Icons.logout,
                  label: 'Salir',
                  targetPath: '/login',
                  currentPath: location,
                  onTap: () => _logout(context),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // ==========================================
          // CONTENIDO DERECHO (GRID DE ASIGNACIONES FILTRADAS)
          // ==========================================
          Expanded(
            child:
                child ??
                _TeacherCoursesDashboard(
                  fetchAssignmentsFuture:
                      _fetchFilteredAssignments(), // Enviamos el Future filtrado
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String targetPath,
    required String currentPath,
    VoidCallback? onTap,
  }) {
    final bool isSelected = currentPath.startsWith(targetPath);
    return InkWell(
      onTap: onTap ?? () => context.go(targetPath),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        decoration: BoxDecoration(
          border: isSelected
              ? const Border(
                  left: BorderSide(color: Colors.tealAccent, width: 4),
                )
              : null,
          color: isSelected
              ? Colors.white.withOpacity(0.06)
              : Colors.transparent,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.tealAccent : Colors.white60,
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white60,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// DETALLE DEL GRID ADAPTABLE PARA EL PROFESOR
// ==========================================
class _TeacherCoursesDashboard extends StatelessWidget {
  final Future<List<TeacherAssignment>> fetchAssignmentsFuture;
  const _TeacherCoursesDashboard({required this.fetchAssignmentsFuture});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Panel de Control Docente',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: FutureBuilder<List<TeacherAssignment>>(
        future: fetchAssignmentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'Error al recuperar asignaciones:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            // Mensaje controlado si no hay cursos asignados a este profesor
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.folder_off_outlined,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No tienes cursos ni secciones asignadas en este periodo.',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          final assignments = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mis Clases Asignadas Responsable',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 16),

                // Grid Dinámico de Cursos y Secciones
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 340,
                          mainAxisSpacing: 20,
                          crossAxisSpacing: 20,
                          mainAxisExtent: 260,
                        ),
                    itemCount: assignments.length,
                    itemBuilder: (context, index) {
                      final assignment = assignments[index];
                      return _buildAssignmentCard(context, assignment, index);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAssignmentCard(
    BuildContext context,
    TeacherAssignment assignment,
    int index,
  ) {
    final List<Color> teacherColors = [
      Colors.teal.shade600,
      Colors.cyan.shade700,
      Colors.blueGrey.shade600,
      Colors.purple.shade600,
    ];
    final Color topColor = teacherColors[index % teacherColors.length];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner superior con Grado y Sección
          Container(
            height: 90,
            decoration: BoxDecoration(
              color: topColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(
                  Icons.developer_board_rounded,
                  color: Colors.white30,
                  size: 36,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${assignment.section.grade} "${assignment.section.name}"',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Información e Interacción abajo
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        assignment.course.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        assignment.course.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),

                  // Botón de acción para entrar a ver el aula virtual
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 12,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            assignment.academicPeriod.name,
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: () {
                          final courseId = assignment.courseId;
                          final sectionId = assignment.idSection;
                          context.go(
                            '/teacher/course/$courseId/sectionId/$sectionId',
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: topColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 0,
                          ),
                          minimumSize: const Size(60, 30),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text(
                          'Ver Aula',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
