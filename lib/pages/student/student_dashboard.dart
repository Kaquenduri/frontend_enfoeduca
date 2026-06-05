import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jwt_decoder/jwt_decoder.dart'; // Importación para decodificar el JWT en la vista
import '../../services/api_client.dart';
import '../../services/api_service.dart';
import '../../models/Course.dart';

class StudentDashboard extends StatelessWidget {
  final Widget? child;

  const StudentDashboard({super.key, this.child});

  void _logout(BuildContext context) async {
    await ApiService.logout();
    if (context.mounted) context.go('/login');
  }

  /// Proceso completo de decodificación y peticiones encadenadas directo en la vista
  Future<List<Course>> _fetchFilteredCourses() async {
    try {
      // 1. Obtener únicamente el token desde el ApiService tal y como está definido
      final String? token = await ApiService.getToken();

      if (token == null || token.isEmpty) {
        throw Exception('No se encontró una sesión activa (Token nulo).');
      }

      // 2. Decodificar el JWT directamente en la vista para extraer el student_id
      Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
      final studentId = decodedToken['student_id'];

      if (studentId == null) {
        throw Exception(
          'El usuario autenticado no posee el rol o ID de estudiante.',
        );
      }

      // 3. Consultar el perfil del estudiante usando el ID extraído del token
      final studentResponse = await ApiClient.get(
        ServiceType.users,
        '/students/$studentId',
      );

      if (studentResponse.statusCode != 200) {
        throw Exception(
          'No se pudo verificar el perfil del alumno. Código: ${studentResponse.body}',
        );
      }

      final studentData =
          json.decode(studentResponse.body) as Map<String, dynamic>;
      final sectionInfo = studentData['id_section'];

      // Si el estudiante no tiene una sección configurada en el sistema
      if (sectionInfo == null || sectionInfo['id_section'] == null) {
        return [];
      }
      final String targetSectionId = sectionInfo['id_section'];

      // 4. Consultar la lista completa de asignaciones académicas
      final assignmentsResponse = await ApiClient.get(
        ServiceType.academic,
        '/assignments/',
      );

      if (assignmentsResponse.statusCode != 200) {
        throw Exception('Error al descargar las asignaciones de cursos.');
      }

      final List<dynamic> assignmentsData = json.decode(
        assignmentsResponse.body,
      );
      final List<Course> finalCoursesList = [];

      // 5. Filtrar y extraer los cursos que correspondan al id_section del alumno
      for (var item in assignmentsData) {
        if (item['id_section'] == targetSectionId && item['course'] != null) {
          // Creamos una copia mutable del mapa del curso enviado por el backend
          final Map<String, dynamic> courseMap = Map<String, dynamic>.from(
            item['course'],
          );

          // Inyectamos el academicPeriod desde el nivel superior de la asignación (atendiendo la minúscula del backend)
          courseMap['academicPeriod'] =
              item['academicperiod'] ??
              {
                'period_id': item['period_id'] ?? '',
                'name': 'Periodo N/A',
                'start_date': '',
                'end_date': '',
                'created_at': '',
                'updated_at': '',
              };

          // Inyectamos una lista vacía de sesiones para que el patrón estricto del factory no lance FormatException
          courseMap['sessions'] = item['sessions'] ?? [];

          // Ahora sí cumple con el switch (json) perfectamente
          finalCoursesList.add(Course.fromJson(courseMap));
        }
      }

      return finalCoursesList;
    } catch (e) {
      throw Exception('Fallo en la sincronización de asignaciones: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    return Scaffold(
      body: Row(
        children: [
          // PANEL / MENÚ LATERAL IZQUIERDO PREMIUM
          Container(
            width: 100,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6727E8), Color(0xFF5153E8)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.transparent,
                    child: Icon(Icons.person, color: Colors.white, size: 32),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Estudiante',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(
                  color: Colors.white24,
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                ),
                const SizedBox(height: 16),

                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _buildMenuButton(
                        context: context,
                        icon: Icons.assignment_outlined,
                        label: 'Cursos',
                        targetPath: '/student',
                        currentPath: location,
                      ),
                    ],
                  ),
                ),

                const Divider(
                  color: Colors.white24,
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                ),
                const SizedBox(height: 8),
                _buildMenuButton(
                  context: context,
                  icon: Icons.logout,
                  label: 'Salir',
                  targetPath: '/login',
                  currentPath: location,
                  onTap: () => _logout(context),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),

          // CONTENIDO DERECHO (TARJETAS DE CURSOS)
          Expanded(
            child:
                child ??
                _StudentCoursesDashboard(
                  fetchCoursesFuture: _fetchFilteredCourses(),
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
    final bool isSelected = currentPath == targetPath;
    return InkWell(
      onTap: onTap ?? () => context.go(targetPath),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        decoration: BoxDecoration(
          border: isSelected
              ? const Border(left: BorderSide(color: Colors.white, width: 4))
              : null,
          color: isSelected
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.transparent,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white70,
              size: 26,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
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
// VISTA PRINCIPAL DE TARJETAS DE CURSOS
// ==========================================
class _StudentCoursesDashboard extends StatelessWidget {
  final Future<List<Course>> fetchCoursesFuture;
  const _StudentCoursesDashboard({required this.fetchCoursesFuture});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Tablero Principal',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 24,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6727E8), Color(0xFF5153E8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 10,
        shadowColor: const Color(0xFF6727E8).withValues(alpha: 0.4),
      ),
      body: FutureBuilder<List<Course>>(
        future: fetchCoursesFuture,
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
                  'Error al cargar el tablero:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.auto_stories_outlined,
                    size: 50,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No hay cursos registrados para tu sección actualmente.',
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

          final courses = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mis Cursos Asignados',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 16),

                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 320,
                          mainAxisSpacing: 20,
                          crossAxisSpacing: 20,
                          mainAxisExtent: 250,
                        ),
                    itemCount: courses.length,
                    itemBuilder: (context, index) {
                      final course = courses[index];
                      return _buildCourseCard(context, course, index);
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

  Widget _buildCourseCard(BuildContext context, Course course, int index) {
    // Usamos colores elegantes inspirados en la nueva paleta premium
    final List<Color> cardColors = [
      const Color(0xFF6727E8),
      const Color(0xFF5153E8),
      const Color(0xFF4338CA),
      const Color(0xFF3B82F6),
    ];
    final Color topColor = cardColors[index % cardColors.length];

    return InkWell(
      onTap: () {
        context.go('/student/course/${course.courseId}');
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [topColor, topColor.withValues(alpha: 0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              padding: const EdgeInsets.all(20),
              alignment: Alignment.bottomLeft,
              child: const Icon(
                Icons.school_rounded,
                color: Colors.white38,
                size: 48,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          course.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          course.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6727E8).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_month_rounded,
                            size: 14,
                            color: Color(0xFF6727E8),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            course.academicPeriod.name,
                            style: const TextStyle(
                              color: Color(0xFF6727E8),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
