import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../services/api_service.dart';

class AdminCoursesCrudView extends StatefulWidget {
  const AdminCoursesCrudView({super.key});

  @override
  State<AdminCoursesCrudView> createState() => _AdminCoursesCrudViewState();
}

class _AdminCoursesCrudViewState extends State<AdminCoursesCrudView> {
  final _formKey = GlobalKey<FormState>();

  // Controladores para el formulario
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String? _selectedPeriodId;

  // Estado del CRUD
  List<dynamic> _coursesList = [];
  List<dynamic> _periodsList = [];
  bool _isLoading = true;
  String? _editingCourseId; // Si no es nulo, estamos editando este ID

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // Carga inicial concurrente de cursos y periodos
  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    try {
      final String? token = await ApiService.getToken();
      final Map<String, String> headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      final responses = await Future.wait([
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

      if (responses[0].statusCode == 200 && responses[1].statusCode == 200) {
        setState(() {
          _coursesList = json.decode(responses[0].body);
          _periodsList = json.decode(responses[1].body);
          _isLoading = false;
        });
      } else {
        throw Exception('Error en las respuestas del servidor académico');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error al sincronizar datos del servidor: $e', Colors.red);
    }
  }

  // Crear o Modificar un Curso
  Future<void> _saveCourse() async {
    if (!_formKey.currentState!.validate()) return;

    final String? token = await ApiService.getToken();
    final Map<String, String> headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    final Map<String, dynamic> bodyData = {
      "name": _nameController.text.trim(),
      "description": _descriptionController.text.trim(),
      "period_id": _selectedPeriodId,
    };

    setState(() => _isLoading = true);

    try {
      http.Response response;
      if (_editingCourseId == null) {
        // MODO CREACIÓN
        response = await http.post(
          Uri.parse(
            'https://academic-service-enfoenfoeduca-451053308845.us-central1.run.app/courses/create',
          ),
          headers: headers,
          body: json.encode(bodyData),
        );
      } else {
        // MODO ACTUALIZACIÓN (/courses/id)
        response = await http.put(
          Uri.parse(
            'https://academic-service-enfoenfoeduca-451053308845.us-central1.run.app/courses/$_editingCourseId',
          ),
          headers: headers,
          body: json.encode(bodyData),
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSnackBar(
          _editingCourseId == null
              ? '¡Curso creado exitosamente!'
              : '¡Curso actualizado correctamente!',
          Colors.green,
        );
        _resetForm();
        _fetchInitialData();
      } else {
        throw Exception(
          'El servidor respondió con código ${response.statusCode}',
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Operación fallida: $e', Colors.red);
    }
  }

  // Eliminar un Curso
  Future<void> _deleteCourse(String courseId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Eliminar Curso',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          '¿Estás completamente seguro de eliminar este curso? Esta acción no se puede deshacer.',
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
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final String? token = await ApiService.getToken();
      final response = await http.delete(
        Uri.parse(
          'https://academic-service-enfoenfoeduca-451053308845.us-central1.run.app/courses/$courseId',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        _showSnackBar('Curso eliminado del sistema.', Colors.orange);
        _fetchInitialData();
      } else {
        throw Exception('Código de estado devuelto: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('No se pudo eliminar el curso: $e', Colors.red);
    }
  }

  // Cargar datos de la fila al formulario para edición
  void _startEditing(Map<String, dynamic> course) {
    setState(() {
      _editingCourseId = course['course_id'] ?? course['id_course'] ?? '';
      _nameController.text = course['name'] ?? '';
      _descriptionController.text = course['description'] ?? '';

      // Validar si el period_id asociado existe en la lista actual de periodos
      final String? pId = course['period_id'];
      final bool periodExists = _periodsList.any((p) => p['period_id'] == pId);
      _selectedPeriodId = periodExists ? pId : null;
    });
  }

  void _resetForm() {
    setState(() {
      _editingCourseId = null;
      _nameController.clear();
      _descriptionController.clear();
      _selectedPeriodId = null;
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
        title: Text(
          _editingCourseId == null
              ? 'Gestión de Cursos > Crear Nuevo'
              : 'Gestión de Cursos > Editando Curso',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded, color: Colors.blueGrey),
            onPressed: _fetchInitialData,
            tooltip: 'Sincronizar Listas',
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
                  // Cambia el diseño a una columna si la pantalla es muy angosta
                  if (constraints.maxWidth < 850) {
                    return Column(
                      children: [
                        _buildFormCard(),
                        const SizedBox(height: 24),
                        Expanded(child: _buildCoursesListCard()),
                      ],
                    );
                  } else {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: _buildFormCard()),
                        const SizedBox(width: 24),
                        Expanded(flex: 3, child: _buildCoursesListCard()),
                      ],
                    );
                  }
                },
              ),
            ),
    );
  }

  // Panel del Formulario (Creación / Edición)
  Widget _buildFormCard() {
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
              Text(
                _editingCourseId == null
                    ? 'Registrar Nuevo Curso'
                    : 'Modificar Datos de Curso',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),

              // Nombre del Curso
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Curso *',
                  hintText: 'Ej. Ciencias Sociales',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'El nombre es obligatorio'
                    : null,
              ),
              const SizedBox(height: 16),

              // Descripción
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descripción del Curso',
                  hintText:
                      'Ej. Curso enfocado en la historia universal y peruana...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),

              // Selector de Periodo Académico dinámico
              DropdownButtonFormField<String>(
                initialValue: _selectedPeriodId,
                decoration: const InputDecoration(
                  labelText: 'Asignar Periodo Académico *',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: _periodsList.map((period) {
                  final String id = period['period_id'] ?? '';
                  final String name = period['name'] ?? 'Sin Nombre';
                  return DropdownMenuItem<String>(
                    value: id,
                    child: Text(name, style: const TextStyle(fontSize: 13)),
                  );
                }).toList(),
                validator: (value) =>
                    value == null ? 'Debe seleccionar un periodo' : null,
                onChanged: (val) {
                  setState(() {
                    _selectedPeriodId = val;
                  });
                },
              ),
              const SizedBox(height: 24),

              // Acciones del Formulario
              Row(
                children: [
                  if (_editingCourseId != null) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _resetForm,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveCourse,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _editingCourseId == null
                            ? Colors.blue.shade700
                            : Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: Text(
                        _editingCourseId == null
                            ? 'Guardar Curso'
                            : 'Actualizar Curso',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Panel del Listado de Cursos Registrados
  Widget _buildCoursesListCard() {
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
            'Cursos Existentes en el Sistema',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _coursesList.isEmpty
                ? const Center(
                    child: Text(
                      'No hay cursos configurados en este momento.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    itemCount: _coursesList.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: Colors.grey.shade100),
                    itemBuilder: (context, index) {
                      final course = _coursesList[index];
                      final String id =
                          course['course_id'] ?? course['id_course'] ?? '';
                      final String name = course['name'] ?? 'Sin nombre';
                      final String description =
                          course['description'] ?? 'Sin descripción';

                      // Buscar el nombre del periodo asociado para mostrarlo de etiqueta
                      final String pId = course['period_id'] ?? '';
                      final matchingPeriod = _periodsList.firstWhere(
                        (element) => element['period_id'] == pId,
                        orElse: () => null,
                      );
                      final String periodLabel = matchingPeriod != null
                          ? matchingPeriod['name']
                          : 'Periodo N/A';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.auto_stories_rounded,
                                color: Colors.orange,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          periodLabel,
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: Colors.blue.shade700,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Botón Editar
                            IconButton(
                              icon: const Icon(
                                Icons.edit_outlined,
                                color: Colors.blue,
                                size: 18,
                              ),
                              onPressed: () => _startEditing(course),
                              tooltip: 'Editar',
                            ),
                            // Botón Eliminar
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.redAccent,
                                size: 18,
                              ),
                              onPressed: () => _deleteCourse(id),
                              tooltip: 'Eliminar',
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
