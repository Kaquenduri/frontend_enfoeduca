import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/api_service.dart';

class AdminAssignmentsCrudView extends StatefulWidget {
  const AdminAssignmentsCrudView({super.key});

  @override
  State<AdminAssignmentsCrudView> createState() =>
      _AdminAssignmentsCrudViewState();
}

class _AdminAssignmentsCrudViewState extends State<AdminAssignmentsCrudView> {
  final _formKey = GlobalKey<FormState>();

  // Estados de Selección del Formulario
  String? _selectedSectionId;
  String? _selectedCourseId;
  String? _selectedPeriodId;
  String? _selectedTeacherId;

  // Listados de dependencias para los combos
  List<dynamic> _assignmentsList = [];
  List<dynamic> _sectionsList = [];
  List<dynamic> _coursesList = [];
  List<dynamic> _periodsList = [];
  List<dynamic> _teachersList = [];

  // Diccionario para cruzar y buscar nombres de profesores al instante por su ID
  Map<String, String> _teachersNameMap = {};

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAndSyncAllDependencies();
  }

  // Descarga e interconexión concurrente de todas las fuentes de datos involucradas
  Future<void> _fetchAndSyncAllDependencies() async {
    setState(() => _isLoading = true);
    try {
      final String? token = await ApiService.getToken();
      final Map<String, String> headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      // Orquestación paralela de consultas a múltiples microservicios académicos y de usuarios
      final responses = await Future.wait([
        http.get(
          Uri.parse(
            'https://academic-service-enfoenfoeduca-451053308845.us-central1.run.app/assignments/',
          ),
          headers: headers,
        ),
        http.get(
          Uri.parse(
            'https://academic-service-enfoenfoeduca-451053308845.us-central1.run.app/sections/',
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
        http.get(
          Uri.parse(
            'https://users-service-enfoenfoeduca-451053308845.us-central1.run.app/teachers/',
          ),
          headers: headers,
        ),
      ]);

      if (responses.any((res) => res.statusCode != 200)) {
        throw Exception(
          'Error en la sincronización de dependencias de microservicios',
        );
      }

      final List<dynamic> assignments = json.decode(responses[0].body);
      final List<dynamic> sections = json.decode(responses[1].body);
      final List<dynamic> courses = json.decode(responses[2].body);
      final List<dynamic> periods = json.decode(responses[3].body);
      final List<dynamic> teachers = json.decode(responses[4].body);

      // Mapear profesores en un diccionario llave-valor indexado por id para búsquedas O(1)
      Map<String, String> localTeachersMap = {};
      for (var teacher in teachers) {
        final String tId = teacher['teacher_id'] ?? '';
        final String name = teacher['user_id']?['name'] ?? 'Docente';
        final String lastName = teacher['user_id']?['last_name'] ?? '';
        localTeachersMap[tId] = '$name $lastName'.trim();
      }

      setState(() {
        _assignmentsList = assignments;
        _sectionsList = sections;
        _coursesList = courses;
        _periodsList = periods;
        _teachersList = teachers;
        _teachersNameMap = localTeachersMap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('No se pudieron unificar las asignaciones: $e', Colors.red);
    }
  }

  // Crear la asignación en la base de datos
  Future<void> _createAssignment() async {
    if (!_formKey.currentState!.validate()) return;

    final String? token = await ApiService.getToken();
    setState(() => _isLoading = true);

    final Map<String, dynamic> payload = {
      "id_section": _selectedSectionId,
      "course_id": _selectedCourseId,
      "period_id": _selectedPeriodId,
      "teacher_id": _selectedTeacherId,
    };

    try {
      final response = await http.post(
        Uri.parse(
          'https://academic-service-enfoenfoeduca-451053308845.us-central1.run.app/assignments/create',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSnackBar(
          '¡Carga docente asignada de forma exitosa!',
          Colors.green,
        );
        _clearForm();
        _fetchAndSyncAllDependencies();
      } else {
        throw Exception(
          'Servidor rechazó la operación con estatus: ${response.statusCode}',
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error al registrar asignación académica: $e', Colors.red);
    }
  }

  // Deshacer / Eliminar Asignación
  Future<void> _deleteAssignment(
    String sectionId,
    String courseId,
    String periodId,
    String teacherId,
  ) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Remover Asignación',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          '¿Está seguro de revocar esta asignación de curso? El profesor ya no tendrá acceso a la sección.',
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
            child: const Text('Revocar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final String? token = await ApiService.getToken();

      // Asumiendo eliminación mediante paso de identificadores o query params comunes en microservicios
      final response = await http.delete(
        Uri.parse(
          'https://academic-service-enfoenfoeduca-451053308845.us-central1.run.app/assignments/$sectionId/$courseId/$periodId/$teacherId',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        _showSnackBar('Carga docente revocada correctamente.', Colors.orange);
        _fetchAndSyncAllDependencies();
      } else {
        throw Exception(
          'Microservicio retornó estatus: ${response.statusCode}',
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('No se pudo procesar la revocación: $e', Colors.red);
    }
  }

  void _clearForm() {
    setState(() {
      _selectedSectionId = null;
      _selectedCourseId = null;
      _selectedPeriodId = null;
      _selectedTeacherId = null;
    });
    _formKey.currentState?.reset();
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Asignación de Cursos y Cargas de Docencia',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded, color: Colors.blueGrey),
            onPressed: _fetchAndSyncAllDependencies,
            tooltip: 'Sincronizar Relaciones',
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0F172A)),
            )
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 950) {
                    return Column(
                      children: [
                        _buildAssignmentFormCard(),
                        const SizedBox(height: 24),
                        Expanded(child: _buildAssignmentsListCard()),
                      ],
                    );
                  } else {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 4, child: _buildAssignmentFormCard()),
                        const SizedBox(width: 24),
                        Expanded(flex: 5, child: _buildAssignmentsListCard()),
                      ],
                    );
                  }
                },
              ),
            ),
    );
  }

  // Panel Izquierdo: Formulario Matriz Combinatoria de Combos
  Widget _buildAssignmentFormCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Crear Nexo Académico (Carga Horaria)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 18),

              // 1. Dropdown de Periodos Académicos
              DropdownButtonFormField<String>(
                initialValue: _selectedPeriodId,
                decoration: const InputDecoration(
                  labelText: '1. Periodo Operativo *',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: _periodsList.map((p) {
                  return DropdownMenuItem<String>(
                    value: p['period_id'] ?? '',
                    child: Text(
                      p['name'] ?? '',
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                }).toList(),
                validator: (val) =>
                    val == null ? 'Seleccione el periodo' : null,
                onChanged: (val) => setState(() => _selectedPeriodId = val),
              ),
              const SizedBox(height: 16),

              // 2. Dropdown de Secciones
              DropdownButtonFormField<String>(
                initialValue: _selectedSectionId,
                decoration: const InputDecoration(
                  labelText: '2. Aula / Sección Asignada *',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: _sectionsList.map((s) {
                  final String grade = s['grade'] ?? '';
                  final String name = s['name'] ?? '';
                  return DropdownMenuItem<String>(
                    value: s['id_section'] ?? '',
                    child: Text(
                      '$grade "$name"',
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                }).toList(),
                validator: (val) =>
                    val == null ? 'Seleccione la sección' : null,
                onChanged: (val) => setState(() => _selectedSectionId = val),
              ),
              const SizedBox(height: 16),

              // 3. Dropdown de Cursos
              DropdownButtonFormField<String>(
                initialValue: _selectedCourseId,
                decoration: const InputDecoration(
                  labelText: '3. Materia o Curso *',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: _coursesList.map((c) {
                  return DropdownMenuItem<String>(
                    value: c['course_id'] ?? '',
                    child: Text(
                      c['name'] ?? '',
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                }).toList(),
                validator: (val) => val == null ? 'Seleccione el curso' : null,
                onChanged: (val) => setState(() => _selectedCourseId = val),
              ),
              const SizedBox(height: 16),

              // 4. Dropdown de Docentes (Consumiendo del mapa cruzado)
              DropdownButtonFormField<String>(
                initialValue: _selectedTeacherId,
                decoration: const InputDecoration(
                  labelText: '4. Profesor Responsable *',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: _teachersList.map((t) {
                  final String id = t['teacher_id'] ?? '';
                  final String name = _teachersNameMap[id] ?? 'Profesor';
                  return DropdownMenuItem<String>(
                    value: id,
                    child: Text(name, style: const TextStyle(fontSize: 12)),
                  );
                }).toList(),
                validator: (val) => val == null ? 'Asigne un docente' : null,
                onChanged: (val) => setState(() => _selectedTeacherId = val),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _createAssignment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text(
                    'Vincular Carga Docente',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Panel Derecho: Visualizador de Asignaciones e Intersecciones en el Sistema
  Widget _buildAssignmentsListCard() {
    return Container(
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
            'Matriz de Distribución Educativa Actual',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _assignmentsList.isEmpty
                ? const Center(
                    child: Text(
                      'No hay combinaciones asignadas.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    itemCount: _assignmentsList.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: Colors.grey.shade100),
                    itemBuilder: (context, index) {
                      final item = _assignmentsList[index];

                      // Extracción relacional limpia del Json
                      final String secName = item['section']?['name'] ?? '';
                      final String secGrade = item['section']?['grade'] ?? '';
                      final String courseName =
                          item['course']?['name'] ?? 'Materia';
                      final String periodName =
                          item['academicperiod']?['name'] ?? 'N/A';

                      // Cruce O(1) con el mapa para pintar el nombre real del docente
                      final String teacherId = item['teacher_id'] ?? '';
                      final String teacherFullName =
                          _teachersNameMap[teacherId] ??
                          'Docente no encasillado';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.indigo.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.assignment_turned_in_rounded,
                                color: Colors.indigo,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    courseName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Prof: $teacherFullName',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    'Salón: $secGrade "$secName"  •  Ciclo: $periodName',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.link_off_rounded,
                                color: Colors.redAccent,
                                size: 18,
                              ),
                              onPressed: () => _deleteAssignment(
                                item['id_section'] ?? '',
                                item['course_id'] ?? '',
                                item['period_id'] ?? '',
                                item['teacher_id'] ?? '',
                              ),
                              tooltip: 'Deshacer Vínculo',
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
