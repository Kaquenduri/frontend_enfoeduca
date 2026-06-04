// ignore_for_file: use_build_context_synchronously, deprecated_member_use, file_names
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import '../../services/api_service.dart';
import '../../models/Student.dart'; // <-- Asegúrate de que la ruta sea correcta según tu proyecto
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeacherSessionMaterialsView extends StatefulWidget {
  final String courseId;
  final String sectionId;
  final String sessionId;

  const TeacherSessionMaterialsView({
    super.key,
    required this.courseId,
    required this.sectionId,
    required this.sessionId,
  });

  @override
  State<TeacherSessionMaterialsView> createState() =>
      _TeacherSessionMaterialsViewState();
}

class _TeacherSessionMaterialsViewState
    extends State<TeacherSessionMaterialsView> {
  late Future<Map<String, dynamic>> _sessionDetailsFuture;

  // Lista local para manejar las asistencias
  List<dynamic> _localAttendances = [];
  bool _isSavingAttendance = false;

  // Caché local para nombres reales de alumnos
  final Map<String, String> _studentNames = {};
  bool _isLoadingNames = false;

  @override
  void initState() {
    super.initState();
    _refreshSessionDetails();
  }

  void _refreshSessionDetails() {
    setState(() {
      _sessionDetailsFuture = _fetchSessionDetailsAndNames(widget.sessionId);
    });
  }

  // =========================================================================
  // CONSULTA DE DETALLES Y NOMBRES DE ALUMNOS (PERFECTAMENTE SINCRONIZADA)
  // =========================================================================
  Future<Map<String, dynamic>> _fetchSessionDetailsAndNames(
    String sessionId,
  ) async {
    final token = await ApiService.getToken();

    final response = await http.get(
      Uri.parse(
        'https://academic-service-enfoenfoeduca-451053308845.us-central1.run.app/courses/sessions/$sessionId',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final List<dynamic> attendances = data['attendances'] ?? [];

      _localAttendances = List.from(attendances);

      if (attendances.isNotEmpty) {
        setState(() {
          _isLoadingNames = true;
        });

        final List<String> missingIds = attendances
            .map((att) => att['student_id'] as String)
            .where((id) => !_studentNames.containsKey(id))
            .toList();

        if (missingIds.isNotEmpty) {
          try {
            await Future.wait(
              missingIds.map((studentId) async {
                final studentRes = await http.get(
                  Uri.parse(
                    'https://users-service-enfoenfoeduca-451053308845.us-central1.run.app/students/$studentId',
                  ),
                  headers: {'Authorization': 'Bearer $token'},
                );

                if (studentRes.statusCode == 200) {
                  final studentData =
                      json.decode(studentRes.body) as Map<String, dynamic>;
                  final parsedStudent = Student.fromJson(studentData);
                  _studentNames[studentId] =
                      '${parsedStudent.name} ${parsedStudent.lastName}';
                } else {
                  _studentNames[studentId] = 'Código: $studentId';
                }
              }),
            );
          } catch (e) {
            debugPrint('Error obteniendo nombres: $e');
          }
        }

        if (mounted) {
          setState(() {
            _isLoadingNames = false;
          });
        }
      }

      return data;
    } else {
      throw Exception('Error al obtener el detalle de la sesión.');
    }
  }

  // =========================================================================
  // 1. ACCIÓN: FORMULARIO MULTIPART PARA SELECCIONAR Y SUBIR MATERIAL AL BUCKET
  // =========================================================================
  void _showAddMaterialDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    // Nombre del bucket de Supabase destinado a los materiales
    final String materialBucketName = 'materials';

    PlatformFile? selectedFile; // Guarda la referencia del archivo en memoria
    bool isUploadingFile = false; // Estado de carga dentro del diálogo

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text(
            'Subir Material al Bucket',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Título del material',
                  ),
                ),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                ),
                const SizedBox(height: 20),

                // Zona interactiva para elegir el archivo del dispositivo
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      if (selectedFile == null) ...[
                        const Icon(
                          Icons.file_present_outlined,
                          size: 36,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade300,
                            foregroundColor: Colors.black87,
                          ),
                          onPressed: () async {
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.any,
                            );
                            if (result != null && result.files.isNotEmpty) {
                              setDialogState(() {
                                selectedFile = result.files.first;
                              });
                            }
                          },
                          child: const Text(
                            'Seleccionar Archivo',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ] else ...[
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 36,
                          color: Colors.green,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          selectedFile!.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '${(selectedFile!.size / 1024 / 1024).toStringAsFixed(2)} MB',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              setDialogState(() => selectedFile = null),
                          child: const Text(
                            'Cambiar archivo',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                if (isUploadingFile) ...[
                  const SizedBox(height: 16),
                  const LinearProgressIndicator(color: Colors.teal),
                  const SizedBox(height: 4),
                  const Text(
                    'Procesando y subiendo a Supabase Storage...',
                    style: TextStyle(fontSize: 11, color: Colors.teal),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isUploadingFile ? null : () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              onPressed:
                  (selectedFile == null ||
                      titleController.text.isEmpty ||
                      isUploadingFile)
                  ? null
                  : () async {
                      setDialogState(() => isUploadingFile = true);

                      try {
                        if (selectedFile!.bytes == null) {
                          throw Exception(
                            'El archivo no tiene bytes válidos para la subida binaria.',
                          );
                        }

                        // 1. SUBIR BINARIO DIRECTO A SUPABASE STORAGE
                        final String fileExtension =
                            selectedFile!.extension ?? 'pdf';
                        final String uniqueFileName =
                            'mat_${widget.sessionId}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

                        final supabase = Supabase.instance.client;

                        await supabase.storage
                            .from(materialBucketName)
                            .uploadBinary(
                              uniqueFileName,
                              selectedFile!.bytes!,
                              fileOptions: const FileOptions(
                                cacheControl: '3600',
                                upsert: false,
                              ),
                            );

                        // 2. OBTENER LA URL PÚBLICA GENERADA POR SUPABASE
                        final String publicFileUrl = supabase.storage
                            .from(materialBucketName)
                            .getPublicUrl(uniqueFileName);

                        debugPrint(
                          'Archivo subido al bucket con éxito: $publicFileUrl',
                        );

                        // 3. MANDAR LA URL Y LOS CAMPOS EN JSON A TU API POST
                        final token = await ApiService.getToken();
                        final uri = Uri.parse(
                          'https://academic-service-enfoenfoeduca-451053308845.us-central1.run.app/courses/materials/create',
                        );

                        final response = await http.post(
                          uri,
                          headers: {
                            'Content-Type': 'application/json',
                            'Authorization': 'Bearer $token',
                          },
                          body: json.encode({
                            "session_id": widget.sessionId,
                            "title": titleController.text,
                            "file_type": '.$fileExtension',
                            "file_url":
                                publicFileUrl, // Aquí inyectamos la URL del bucket automáticamente
                            "description": descriptionController.text,
                          }),
                        );

                        if (response.statusCode == 201 ||
                            response.statusCode == 200) {
                          Navigator.pop(context);
                          _refreshSessionDetails();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  '¡Material creado y guardado en el bucket con éxito!',
                                ),
                                backgroundColor: Colors.teal,
                              ),
                            );
                          }
                        } else {
                          throw Exception(
                            'Error en tu API (${response.statusCode}): ${response.body}',
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isUploadingFile = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: const Text('Subir y Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 2. ACCIÓN: FORMULARIO PARA AGREGAR TAREA (CON CALENDARIO DATETIME)
  // =========================================================================
  void _showAddTaskDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    DateTime startDate = DateTime.now();
    DateTime dueDate = DateTime.now().add(const Duration(days: 7));

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text(
            'Asignar Nueva Tarea',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Título de la tarea',
                  ),
                ),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Instrucciones / Descripción',
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.calendar_today, color: Colors.teal),
                  title: const Text(
                    'Fecha de Inicio',
                    style: TextStyle(fontSize: 12),
                  ),
                  subtitle: Text(startDate.toString().split('.')[0]),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: startDate,
                      firstDate: DateTime(2025),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setDialogState(() => startDate = picked);
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.calendar_month,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    'Fecha de Entrega',
                    style: TextStyle(fontSize: 12),
                  ),
                  subtitle: Text(dueDate.toString().split('.')[0]),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: dueDate,
                      firstDate: DateTime(2025),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setDialogState(() => dueDate = picked);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (titleController.text.isEmpty) return;

                // 1. Guardamos los datos antes de cerrar el modal
                final String title = titleController.text;
                final String description = descriptionController.text;
                final String sDateIso = startDate.toUtc().toIso8601String();
                final String dDateIso = dueDate.toUtc().toIso8601String();

                // 2. CAPTURAMOS EL MESSENGER ANTES DEL POP PARA QUE NO DE ERROR DE CONTEXTO
                final messenger = ScaffoldMessenger.of(context);

                Navigator.pop(context);

                try {
                  final token = await ApiService.getToken();
                  final String targetUrl =
                      'https://academic-service-enfoenfoeduca-451053308845.us-central1.run.app/tasks/create';

                  debugPrint('=== ENVIANDO POST TAREA A: $targetUrl ===');

                  final res = await http.post(
                    Uri.parse(targetUrl),
                    headers: {
                      'Content-Type': 'application/json',
                      'Accept': 'application/json',
                      'Authorization': 'Bearer $token',
                    },
                    body: json.encode({
                      "session_id": widget.sessionId,
                      "title": title,
                      "description": description,
                      "start_date": sDateIso,
                      "due_date": dDateIso,
                    }),
                  );

                  debugPrint(
                    '=== 📬 RESPUESTA DEL SERVIDOR: Status ${res.statusCode} ===',
                  );

                  if (res.statusCode == 201 || res.statusCode == 200) {
                    // 3. Verificamos que el widget siga vivo antes de refrescar la pantalla principal
                    if (mounted) {
                      _refreshSessionDetails(); // <--- Ahora sí ejecutará el setState de tu lista externa

                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('¡Tarea asignada con éxito!'),
                          backgroundColor: Colors.teal,
                        ),
                      );
                    }
                  } else {
                    throw Exception(
                      'Servidor retornó código ${res.statusCode}: ${res.body}',
                    );
                  }
                } catch (e) {
                  debugPrint('=== ERROR EN CREACIÓN DE TAREA ===: $e');
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Error al crear tarea: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Crear Tarea'),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 3. ACCIÓN: ACTUALIZAR ASISTENCIAS CON EL ENDPOINT "PUT" POR ID INDIVIDUAL
  // =========================================================================
  Future<void> _updateAttendanceChanges() async {
    setState(() {
      _isSavingAttendance = true;
    });

    try {
      final token = await ApiService.getToken();

      // Recorremos secuencialmente cada una de las asistencias locales modificadas
      for (var att in _localAttendances) {
        final String attendanceId = att['attendance_id'] ?? '';
        final String currentStatus = att['status'] ?? 'EXCUSED';

        if (attendanceId.isNotEmpty) {
          // Hacemos el PUT usando la URL dinámica con el ID de la asistencia
          await http.put(
            Uri.parse(
              'https://academic-service-enfoenfoeduca-451053308845.us-central1.run.app/attendances/$attendanceId',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              "status":
                  currentStatus, // Envía 'PRESENT' o 'FALTA' según el Switch
            }),
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Todas las asistencias actualizadas con éxito!'),
            backgroundColor: Colors.teal,
          ),
        );
      }
      _refreshSessionDetails();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSavingAttendance = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _sessionDetailsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Colors.teal)),
          );
        } else if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        final sessionData = snapshot.data!;
        final String sessionName = sessionData['name'] ?? 'Detalle de Sesión';
        final List<dynamic> materials = sessionData['materials'] ?? [];
        final List<dynamic> tasks = sessionData['tasks'] ?? [];

        final int presentsCount = _localAttendances
            .where((att) => att['status'] == 'PRESENT')
            .length;

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            backgroundColor: const Color(0xFFF8F9FA),
            appBar: AppBar(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              elevation: 0.5,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go(
                  '/teacher/course/${widget.courseId}/sectionId/${widget.sectionId}',
                ),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sessionName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Sección ID: ${widget.sectionId} • ($presentsCount/${_localAttendances.length} Presentes)',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.teal,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              bottom: const TabBar(
                labelColor: Colors.teal,
                unselectedLabelColor: Colors.black54,
                indicatorColor: Colors.teal,
                tabs: [
                  Tab(
                    icon: Icon(Icons.folder_copy_outlined),
                    text: 'Materiales',
                  ),
                  Tab(
                    icon: Icon(Icons.assignment_turned_in_outlined),
                    text: 'Tareas',
                  ),
                  Tab(
                    icon: Icon(Icons.people_outline_rounded),
                    text: 'Asistencias',
                  ),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _buildMaterialsTab(materials),
                _buildTasksTab(tasks),
                _buildAttendanceTab(),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==== PESTAÑA 1: MATERIALES ====
  Widget _buildMaterialsTab(List<dynamic> materials) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Repositorio de la Clase',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showAddMaterialDialog, // <-- CONECTADO
                icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                label: const Text(
                  'Subir Material',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: materials.isEmpty
                ? _buildEmptyState(
                    Icons.folder_off_outlined,
                    'No hay materiales subidos.',
                  )
                : ListView.builder(
                    itemCount: materials.length,
                    itemBuilder: (context, index) {
                      final material = materials[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: const Icon(
                            Icons.insert_drive_file_outlined,
                            color: Colors.teal,
                          ),
                          title: Text(
                            material['title'] ?? 'Sin título',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            material['description'] ?? '',
                            style: const TextStyle(fontSize: 11),
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

  // ==== PESTAÑA 2: TAREAS ====
  Widget _buildTasksTab(List<dynamic> tasks) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Evaluaciones creadas',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showAddTaskDialog, // <-- CONECTADO
                icon: const Icon(Icons.add_task_outlined, size: 16),
                label: const Text(
                  'Nueva Tarea',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: tasks.isEmpty
                ? _buildEmptyState(
                    Icons.task_outlined,
                    'No hay tareas creadas.',
                  )
                : ListView.builder(
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      final taskId = task['task_id'] ?? '';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: const Icon(
                            Icons.assignment,
                            color: Colors.orangeAccent,
                          ),
                          title: Text(
                            task['title'] ?? '',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: Colors.teal,
                          ),
                          onTap: () {
                            if (taskId.isNotEmpty) {
                              // Navegamos hacia la nueva vista de entregas de esta tarea
                              context.go(
                                '/teacher/course/${widget.courseId}/sectionId/${widget.sectionId}/session/${widget.sessionId}/task/$taskId',
                              );
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ==== PESTAÑA 3: CONTROL DE ASISTENCIA (AHORA HACE PUT POR ID DE ASISTENCIA) ====
  Widget _buildAttendanceTab() {
    if (_localAttendances.isEmpty) {
      return _buildEmptyState(
        Icons.people_alt_outlined,
        'No hay alumnos registrados en esta sesión.',
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Lista Oficial de Estudiantes',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _isSavingAttendance
                    ? null
                    : _updateAttendanceChanges, // <-- CAMBIADO A PUT SECUENCIAL
                icon: _isSavingAttendance
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save_outlined, size: 16),
                label: Text(
                  _isSavingAttendance ? 'Actualizando...' : 'Guardar Cambios',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoadingNames)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(
                color: Colors.teal,
                backgroundColor: Color(0xFFE0F2F1),
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _localAttendances.length,
              itemBuilder: (context, index) {
                final attendance = _localAttendances[index];

                final String studentId = attendance['student_id'] ?? '';
                final String status = attendance['status'] ?? 'EXCUSED';
                final bool isPresent = status == 'PRESENT';

                final String studentDisplayName =
                    _studentNames[studentId] ??
                    'Cargando datos... ($studentId)';

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: isPresent
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.red.withValues(alpha: 0.1),
                      child: Icon(
                        isPresent
                            ? Icons.check_circle_outline
                            : Icons.cancel_outlined,
                        color: isPresent ? Colors.green : Colors.red,
                      ),
                    ),
                    title: Text(
                      studentDisplayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      isPresent ? 'Estado: PRESENTE' : 'Estado: FALTA',
                      style: TextStyle(
                        fontSize: 11,
                        color: isPresent ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: Switch(
                      value: isPresent,
                      activeThumbColor: Colors.green,
                      inactiveThumbColor: Colors.red,
                      inactiveTrackColor: Colors.red.withValues(alpha: 0.2),
                      onChanged: (bool newValue) {
                        setState(() {
                          _localAttendances[index]['status'] = newValue
                              ? 'PRESENT'
                              : 'FALTA';
                        });
                      },
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

  Widget _buildEmptyState(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
