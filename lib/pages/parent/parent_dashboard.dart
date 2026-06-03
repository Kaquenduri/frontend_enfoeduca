import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import '../../services/api_service.dart';

// =========================================================================
// CASCARÓN PRINCIPAL CON NAVEGACIÓN LATERAL (COLOR MORADO/ÍNDIGO PARA PADRES)
// =========================================================================
class ParentDashboard extends StatelessWidget {
  final Widget? child;

  const ParentDashboard({super.key, this.child});

  void _logout(BuildContext context) async {
    await ApiService.logout();
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    return Scaffold(
      body: Row(
        children: [
          // PANEL LATERAL IZQUIERDO (DISEÑO FAMILIAR)
          Container(
            width: 100,
            color: const Color(
              0xFF2C1E3D,
            ), // Color morado oscuro distintivo para Padres
            child: Column(
              children: [
                const SizedBox(height: 24),
                const CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.amberAccent,
                  child: Icon(
                    Icons.family_restroom_rounded,
                    color: Color(0xFF2C1E3D),
                    size: 26,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Familiar',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white12, height: 1),

                // Menú del Padre
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _buildMenuButton(
                        context: context,
                        icon: Icons.supervisor_account_outlined,
                        label: 'Mis Hijos',
                        targetPath: '/parent',
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

          // CONTENIDO DINÁMICO DERECHO
          Expanded(child: child ?? const ParentStudentsDashboard()),
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
              ? const Border(
                  left: BorderSide(color: Colors.amberAccent, width: 4),
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
              color: isSelected ? Colors.amberAccent : Colors.white60,
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

// =========================================================================
// VISTA INTERNA QUE SOLICITA LOS ESTUDIANTES Y FILTRA POR EL PARENT_ID DEL JWT
// =========================================================================
class ParentStudentsDashboard extends StatefulWidget {
  const ParentStudentsDashboard({super.key});

  @override
  State<ParentStudentsDashboard> createState() =>
      _ParentStudentsDashboardState();
}

class _ParentStudentsDashboardState extends State<ParentStudentsDashboard> {
  late Future<List<dynamic>> _fetchStudentsFuture;

  @override
  void initState() {
    super.initState();
    _fetchStudentsFuture = _fetchFilteredStudents();
  }

  Future<List<dynamic>> _fetchFilteredStudents() async {
    try {
      // 1. Obtener token
      final String? token = await ApiService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('No se encontró una sesión activa (Token nulo).');
      }

      // 2. Decodificar el parent_id del JWT
      Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
      final currentParentId = decodedToken['parent_id'];
      if (currentParentId == null) {
        throw Exception(
          'El usuario autenticado no posee el ID de Padre en el Token.',
        );
      }

      final Map<String, String> requestHeaders = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      // 3. Consumir el endpoint global de estudiantes con el slash al final
      final response = await http.get(
        Uri.parse(
          'https://users-service-enfoenfoeduca-451053308845.us-central1.run.app/students/',
        ),
        headers: requestHeaders,
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Error al recuperar estudiantes: ${response.statusCode}',
        );
      }

      final List<dynamic> allStudents = json.decode(response.body);

      final List<dynamic> filteredList = [];

      // 4. Filtrar localmente en la vista aquellos estudiantes que pertenecen a este padre
      for (var student in allStudents) {
        if (student['parent_id'] == currentParentId) {
          filteredList.add(student);
        }
      }

      debugPrint("alumnos recuperados: ${filteredList.toList()}");
      return filteredList;
    } catch (e) {
      throw Exception('Error de red al sincronizar estudiantes a cargo: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Seguimiento Familiar',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _fetchStudentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF2C1E3D)),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'Error en la consulta:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.child_care_rounded,
                    size: 50,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No tienes alumnos registrados bajo tu tutoría legal.',
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

          final students = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mis Hijos Registrados',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 16),

                // Grid de tarjetas de estudiantes
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 340,
                          mainAxisSpacing: 20,
                          crossAxisSpacing: 20,
                          mainAxisExtent: 240,
                        ),
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      final student = students[index];
                      return _buildStudentCard(context, student, index);
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

  Widget _buildStudentCard(BuildContext context, dynamic student, int index) {
    final List<Color> customColors = [
      Colors.indigo.shade600,
      Colors.deepPurple.shade600,
      Colors.purple.shade700,
    ];
    final Color topColor = customColors[index % customColors.length];

    final String studentId = student['student_id'] ?? '';

    // Extracción segura de la información de usuario (Nombre y Apellido)
    final Map<String, dynamic>? userData =
        student['user_id'] is Map<String, dynamic> ? student['user_id'] : null;
    final String studentName = userData != null
        ? '${userData['name'] ?? ''} ${userData['last_name'] ?? ''}'.trim()
        : 'Estudiante';
    final String studentEmail = userData != null
        ? (userData['email'] ?? '')
        : '';

    // Extracción segura de la información de sección/aula
    final Map<String, dynamic>? sectionData =
        student['id_section'] is Map<String, dynamic>
        ? student['id_section']
        : null;
    final String sectionName = sectionData != null
        ? (sectionData['name'] ?? '')
        : '';
    final String sectionGrade = sectionData != null
        ? (sectionData['grade'] ?? '')
        : '';

    // Extracción segura del período académico
    final Map<String, dynamic>? periodData =
        sectionData != null &&
            sectionData['academicPeriod'] is Map<String, dynamic>
        ? sectionData['academicPeriod']
        : null;
    final String periodName = periodData != null
        ? (periodData['name'] ?? 'N/A')
        : 'N/A';

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
          // Banner Superior - Nombre completo del Alumno
          Container(
            height: 85,
            decoration: BoxDecoration(
              color: topColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.person_pin_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        studentName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        studentEmail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Cuerpo de la tarjeta - Detalles del Grado, Sección y Año escolar
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
                      Row(
                        children: [
                          Icon(
                            Icons.school_outlined,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Grado y Sección:',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            sectionGrade.isNotEmpty
                                ? '$sectionGrade "$sectionName"'
                                : 'No asignado',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.date_range_outlined,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Periodo Académico:',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            periodName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Fila inferior con ID truncado y botón preparado
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ID: ${studentId.length > 6 ? studentId.substring(0, 6) : studentId}',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          context.go("/parent/student/$studentId");
                        },
                        icon: const Icon(Icons.analytics_outlined, size: 14),
                        label: const Text('Ver Rendimiento'),
                        style: ElevatedButton.styleFrom(
                          disabledBackgroundColor: Colors.grey.shade100,
                          disabledForegroundColor: Colors.grey.shade400,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
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
