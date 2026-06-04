import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/api_client.dart';

class AdminSectionsCrudView extends StatefulWidget {
  const AdminSectionsCrudView({super.key});

  @override
  State<AdminSectionsCrudView> createState() => _AdminSectionsCrudViewState();
}

class _AdminSectionsCrudViewState extends State<AdminSectionsCrudView> {
  final _formKey = GlobalKey<FormState>();

  // Controladores y estados del Formulario
  final TextEditingController _nameController = TextEditingController();
  String? _selectedGrade;
  String? _selectedPeriodId;

  // Listas de Estado del CRUD
  List<dynamic> _sectionsList = [];
  List<dynamic> _periodsList = [];
  bool _isLoading = true;
  String? _editingSectionId; // Si no es nulo, estamos en Modo Edición

  // Grados predefinidos del sistema escolar (puedes ajustar o añadir más)
  final List<String> _gradesOptions = [
    'PRIMERO',
    'SEGUNDO',
    'TERCERO',
    'CUARTO',
    'QUINTO',
    'SEXTO',
  ];

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // Carga inicial concurrente de Secciones y Periodos Académicos
  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    try {
      final responses = await Future.wait([
        ApiClient.get(ServiceType.academic, '/sections/'),
        ApiClient.get(ServiceType.academic, '/period/'),
      ]);

      if (responses[0].statusCode == 200 && responses[1].statusCode == 200) {
        setState(() {
          _sectionsList = json.decode(responses[0].body);
          _periodsList = json.decode(responses[1].body);
          _isLoading = false;
        });
      } else {
        throw Exception(
          'Error al conectar con los servicios académicos remotos',
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error de sincronización con el servidor: $e', Colors.red);
    }
  }

  // Crear o Modificar Sección
  Future<void> _saveSection() async {
    if (!_formKey.currentState!.validate()) return;

    // Estructura idéntica al formato requerido por tu API
    final Map<String, dynamic> bodyData = {
      "id_period": _selectedPeriodId,
      "name": _nameController.text
          .trim()
          .toUpperCase(), // Asegura formatos limpios como "C" o "D"
      "grade": _selectedGrade,
    };

    setState(() => _isLoading = true);

    try {
      final response = _editingSectionId == null
          ? await ApiClient.post(
              ServiceType.academic,
              '/sections/create',
              body: bodyData,
            )
          : await ApiClient.put(
              ServiceType.academic,
              '/sections/$_editingSectionId',
              body: bodyData,
            );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSnackBar(
          _editingSectionId == null
              ? '¡Sección creada con éxito!'
              : '¡Sección actualizada de forma correcta!',
          Colors.green,
        );
        _resetForm();
        _fetchInitialData();
      } else {
        throw Exception(
          'Servidor retornó código anómalo: ${response.statusCode}',
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('La operación no se pudo completar: $e', Colors.red);
    }
  }

  // Eliminar Sección
  Future<void> _deleteSection(String sectionId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Eliminar Sección',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          '¿Estás seguro de eliminar esta sección escolar? Esta acción desvinculará a los alumnos asociados.',
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
      final response = await ApiClient.delete(ServiceType.academic, '/sections/$sectionId');

      if (response.statusCode == 200 || response.statusCode == 204) {
        _showSnackBar('Sección eliminada de la base de datos.', Colors.orange);
        _fetchInitialData();
      } else {
        throw Exception('Estatus devuelto por la API: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error al eliminar sección: $e', Colors.red);
    }
  }

  // Cargar datos al formulario para pasar a Modo Edición
  void _startEditing(Map<String, dynamic> section) {
    setState(() {
      _editingSectionId = section['id_section'];
      _nameController.text = section['name'] ?? '';

      // Control de asignación para combo de grado
      final String? currentGrade = section['grade'];
      _selectedGrade = _gradesOptions.contains(currentGrade)
          ? currentGrade
          : null;

      // Control de asignación para combo de periodo
      final String? currentPeriodId = section['id_period'];
      final bool periodExists = _periodsList.any(
        (p) => p['period_id'] == currentPeriodId,
      );
      _selectedPeriodId = periodExists ? currentPeriodId : null;
    });
  }

  void _resetForm() {
    setState(() {
      _editingSectionId = null;
      _nameController.clear();
      _selectedGrade = null;
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
          _editingSectionId == null
              ? 'Estructura Escolar > Crear Sección'
              : 'Estructura Escolar > Editando Sección',
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
                  if (constraints.maxWidth < 850) {
                    return Column(
                      children: [
                        _buildFormCard(),
                        const SizedBox(height: 24),
                        Expanded(child: _buildSectionsListCard()),
                      ],
                    );
                  } else {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: _buildFormCard()),
                        const SizedBox(width: 24),
                        Expanded(flex: 3, child: _buildSectionsListCard()),
                      ],
                    );
                  }
                },
              ),
            ),
    );
  }

  // Panel izquierdo: Formulario de Registro / Modificación
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
                _editingSectionId == null
                    ? 'Registrar Nueva Sección'
                    : 'Modificar Datos de Sección',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 18),

              // Selector de Grado Académico escolar
              DropdownButtonFormField<String>(
                initialValue: _selectedGrade,
                decoration: const InputDecoration(
                  labelText: 'Grado Escolar *',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: _gradesOptions.map((grade) {
                  return DropdownMenuItem<String>(
                    value: grade,
                    child: Text(grade, style: const TextStyle(fontSize: 13)),
                  );
                }).toList(),
                validator: (value) =>
                    value == null ? 'Debe seleccionar un grado' : null,
                onChanged: (val) => setState(() => _selectedGrade = val),
              ),
              const SizedBox(height: 16),

              // Nombre / Identificador de la sección (Ej: A, B, C)
              TextFormField(
                controller: _nameController,
                maxLength: 15,
                decoration: const InputDecoration(
                  labelText: 'Identificador / Nombre Sección *',
                  hintText: 'Ej. C, D o Única',
                  border: OutlineInputBorder(),
                  isDense: true,
                  counterText: "",
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'El identificador es obligatorio'
                    : null,
              ),
              const SizedBox(height: 16),

              // Selector de Periodo dinámico leído de la API /period/
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
                    value == null ? 'Debe asociar un periodo' : null,
                onChanged: (val) => setState(() => _selectedPeriodId = val),
              ),
              const SizedBox(height: 24),

              // Botones de Acción
              Row(
                children: [
                  if (_editingSectionId != null) ...[
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
                      onPressed: _saveSection,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _editingSectionId == null
                            ? const Color(0xFF0F172A)
                            : Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: Text(
                        _editingSectionId == null
                            ? 'Guardar Sección'
                            : 'Actualizar Sección',
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

  // Panel derecho: Listado de Secciones con desglose escalonado de Periodo
  Widget _buildSectionsListCard() {
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
            'Secciones Estructuradas del Sistema',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _sectionsList.isEmpty
                ? const Center(
                    child: Text(
                      'No hay secciones configuradas actualmente.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    itemCount: _sectionsList.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: Colors.grey.shade100),
                    itemBuilder: (context, index) {
                      final section = _sectionsList[index];
                      final String id = section['id_section'] ?? '';
                      final String name = section['name'] ?? '';
                      final String grade = section['grade'] ?? 'SIN GRADO';

                      // Agarrar de forma escalonada la propiedad name del objeto academicPeriod interno
                      final String periodLabel =
                          section['academicPeriod']?['name'] ?? 'Periodo N/A';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.layers_rounded,
                                color: Colors.teal,
                                size: 18,
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
                                        '$grade "$name"',
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
                                    'ID único: $id',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade500,
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
                              onPressed: () => _startEditing(section),
                              tooltip: 'Editar Sección',
                            ),
                            // Botón Eliminar
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.redAccent,
                                size: 18,
                              ),
                              onPressed: () => _deleteSection(id),
                              tooltip: 'Eliminar Sección',
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
