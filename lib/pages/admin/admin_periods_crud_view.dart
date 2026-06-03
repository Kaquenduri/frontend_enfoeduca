import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/api_service.dart';

class AdminPeriodsCrudView extends StatefulWidget {
  const AdminPeriodsCrudView({super.key});

  @override
  State<AdminPeriodsCrudView> createState() => _AdminPeriodsCrudViewState();
}

class _AdminPeriodsCrudViewState extends State<AdminPeriodsCrudView> {
  final _formKey = GlobalKey<FormState>();

  // Controladores y estados del Formulario
  final TextEditingController _nameController = TextEditingController();
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;

  // Estado del CRUD
  List<dynamic> _periodsList = [];
  bool _isLoading = true;
  String? _editingPeriodId; // Si no es nulo, estamos modificando

  @override
  void initState() {
    super.initState();
    _fetchPeriods();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // Obtener la lista de periodos de la API
  Future<void> _fetchPeriods() async {
    setState(() => _isLoading = true);
    try {
      final String? token = await ApiService.getToken();
      final response = await http.get(
        Uri.parse(
          'https://academic-service-enfoenfoeduca-451053308845.us-central1.run.app/period/',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _periodsList = json.decode(response.body);
          _isLoading = false;
        });
      } else {
        throw Exception(
          'Error del servidor académico (Código: ${response.statusCode})',
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error al cargar los periodos académicos: $e', Colors.red);
    }
  }

  // Lanzar el calendario para seleccionar Fecha de Inicio
  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedStartDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
      helpText: 'FECHA DE INICIO DEL PERIODO',
    );
    if (picked != null && picked != _selectedStartDate) {
      setState(() {
        _selectedStartDate = picked;
        // Validación rápida: si la fecha de fin es menor, la limpiamos
        if (_selectedEndDate != null && _selectedEndDate!.isBefore(picked)) {
          _selectedEndDate = null;
        }
      });
    }
  }

  // Lanzar el calendario para seleccionar Fecha de Fin
  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedEndDate ??
          (_selectedStartDate ?? DateTime.now()).add(const Duration(days: 365)),
      firstDate: _selectedStartDate ?? DateTime(2020),
      lastDate: DateTime(2040),
      helpText: 'FECHA DE FINALIZACIÓN DEL PERIODO',
    );
    if (picked != null && picked != _selectedEndDate) {
      setState(() {
        _selectedEndDate = picked;
      });
    }
  }

  // Crear o Editar Periodo en el Microservicio
  Future<void> _savePeriod() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStartDate == null || _selectedEndDate == null) {
      _showSnackBar(
        'Debe seleccionar ambas fechas (Inicio y Fin) mediante el calendario.',
        Colors.amber.shade800,
      );
      return;
    }

    final String? token = await ApiService.getToken();
    final Map<String, String> headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    // Construcción del JSON String en formato ISO 8601 completo
    final Map<String, dynamic> bodyData = {
      "name": _nameController.text.trim(),
      "start_date": _selectedStartDate!.toUtc().toIso8601String(),
      "end_date": _selectedEndDate!.toUtc().toIso8601String(),
    };

    setState(() => _isLoading = true);

    try {
      http.Response response;
      if (_editingPeriodId == null) {
        // MODO CREAR
        response = await http.post(
          Uri.parse(
            'https://academic-service-enfoenfoeduca-451053308845.us-central1.run.app/period/create',
          ),
          headers: headers,
          body: json.encode(bodyData),
        );
      } else {
        // MODO MODIFICAR
        response = await http.put(
          Uri.parse(
            'https://academic-service-enfoenfoeduca-451053308845.us-central1.run.app/period/$_editingPeriodId',
          ),
          headers: headers,
          body: json.encode(bodyData),
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSnackBar(
          _editingPeriodId == null
              ? '¡Periodo académico creado con éxito!'
              : '¡Periodo actualizado correctamente!',
          Colors.green,
        );
        _resetForm();
        _fetchPeriods();
      } else {
        throw Exception(
          'Respuesta inválida del servidor. Código: ${response.statusCode}',
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error en la operación: $e', Colors.red);
    }
  }

  // Eliminar Periodo Académico
  Future<void> _deletePeriod(String periodId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Eliminar Periodo',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          '¿Estás seguro de eliminar este periodo? Los cursos vinculados podrían verse afectados.',
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
          'https://academic-service-enfoenfoeduca-451053308845.us-central1.run.app/period/$periodId',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        _showSnackBar('Periodo removido del sistema.', Colors.orange);
        _fetchPeriods();
      } else {
        throw Exception('Estatus devuelto: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('No se pudo suprimir el periodo: $e', Colors.red);
    }
  }

  // Cargar datos a los inputs para entrar en Modo Edición
  void _startEditing(Map<String, dynamic> period) {
    setState(() {
      _editingPeriodId = period['period_id'];
      _nameController.text = period['name'] ?? '';
      _selectedStartDate = period['start_date'] != null
          ? DateTime.parse(period['start_date']).toLocal()
          : null;
      _selectedEndDate = period['end_date'] != null
          ? DateTime.parse(period['end_date']).toLocal()
          : null;
    });
  }

  void _resetForm() {
    setState(() {
      _editingPeriodId = null;
      _nameController.clear();
      _selectedStartDate = null;
      _selectedEndDate = null;
    });
    _formKey.currentState?.reset();
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
          _editingPeriodId == null
              ? 'Configuración Global > Crear Periodo'
              : 'Configuración Global > Editando Periodo',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.blueGrey),
            onPressed: _fetchPeriods,
            tooltip: 'Sincronizar Lista',
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
                        _buildPeriodFormCard(),
                        const SizedBox(height: 24),
                        Expanded(child: _buildPeriodsListCard()),
                      ],
                    );
                  } else {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: _buildPeriodFormCard()),
                        const SizedBox(width: 24),
                        Expanded(flex: 3, child: _buildPeriodsListCard()),
                      ],
                    );
                  }
                },
              ),
            ),
    );
  }

  // Panel Izquierdo: Formulario Dinámico con Calendarios
  Widget _buildPeriodFormCard() {
    final String startLabel = _selectedStartDate == null
        ? 'Seleccionar Fecha Inicio *'
        : 'Inicio: ${_selectedStartDate!.day}/${_selectedStartDate!.month}/${_selectedStartDate!.year}';

    final String endLabel = _selectedEndDate == null
        ? 'Seleccionar Fecha Fin *'
        : 'Fin: ${_selectedEndDate!.day}/${_selectedEndDate!.month}/${_selectedEndDate!.year}';

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
                _editingPeriodId == null
                    ? 'Registrar Periodo Lectivo'
                    : 'Actualizar Fechas de Periodo',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 18),

              // Nombre del Periodo (Ej. 2026-1)
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre o Código del Periodo *',
                  hintText: 'Ej. 2026-1 o Ciclo Regular 2026',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'El nombre es requerido'
                    : null,
              ),
              const SizedBox(height: 16),

              // Calendario Selector: Fecha de Inicio
              OutlinedButton.icon(
                onPressed: () => _selectStartDate(context),
                icon: const Icon(
                  Icons.calendar_today_rounded,
                  size: 16,
                  color: Colors.blue,
                ),
                label: Text(
                  startLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  alignment: Alignment.centerLeft,
                  side: BorderSide(color: Colors.grey.shade400),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Calendario Selector: Fecha de Fin
              OutlinedButton.icon(
                onPressed: () => _selectEndDate(context),
                icon: const Icon(
                  Icons.event_available_rounded,
                  size: 16,
                  color: Colors.green,
                ),
                label: Text(
                  endLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  alignment: Alignment.centerLeft,
                  side: BorderSide(color: Colors.grey.shade400),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Acciones del Formulario
              Row(
                children: [
                  if (_editingPeriodId != null) ...[
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
                      onPressed: _savePeriod,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _editingPeriodId == null
                            ? const Color(0xFF0F172A)
                            : Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: Text(
                        _editingPeriodId == null
                            ? 'Crear Periodo'
                            : 'Actualizar Periodo',
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

  // Panel Derecho: Listado Completo de Periodos
  Widget _buildPeriodsListCard() {
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
            'Historial de Periodos Académicos',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _periodsList.isEmpty
                ? const Center(
                    child: Text(
                      'No hay periodos configurados.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    itemCount: _periodsList.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: Colors.grey.shade100),
                    itemBuilder: (context, index) {
                      final period = _periodsList[index];
                      final String id = period['period_id'] ?? '';
                      final String name = period['name'] ?? 'Ciclo sin nombre';
                      final String start = _formatDate(period['start_date']);
                      final String end = _formatDate(period['end_date']);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
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
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Vigencia: $start al $end',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Botón Cargar para Edición
                            IconButton(
                              icon: const Icon(
                                Icons.edit_outlined,
                                color: Colors.blue,
                                size: 18,
                              ),
                              onPressed: () => _startEditing(period),
                              tooltip: 'Editar Periodo',
                            ),
                            // Botón Eliminar
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.redAccent,
                                size: 18,
                              ),
                              onPressed: () => _deletePeriod(id),
                              tooltip: 'Eliminar Periodo',
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
