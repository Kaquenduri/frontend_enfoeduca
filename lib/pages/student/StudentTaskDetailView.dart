import 'dart:convert';
import 'package:flutter/foundation.dart'; // Requerido para kIsWeb si es necesario
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // <-- Importamos Supabase nativo
import '../../services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';

class StudentTaskDetailView extends StatefulWidget {
  final String courseId;
  final String sessionId;
  final String taskId;

  const StudentTaskDetailView({
    super.key,
    required this.courseId,
    required this.sessionId,
    required this.taskId,
  });

  @override
  State<StudentTaskDetailView> createState() => _StudentTaskDetailViewState();
}

class _StudentTaskDetailViewState extends State<StudentTaskDetailView> {
  // Solo necesitamos definir el nombre de tu bucket público
  final String _bucketName = 'tasks_sumissions';

  late Future<Map<String, dynamic>> _taskDetailsFuture;
  String? _loggedStudentId;
  PlatformFile? _selectedFile;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _refreshData();
    _loadStudentIdFromJWT();
  }

  void _refreshData() {
    setState(() {
      _taskDetailsFuture = _fetchTaskDetails(widget.taskId);
      _selectedFile = null;
      _isUploading = false;
    });
  }

  Future<void> _loadStudentIdFromJWT() async {
    final token = await ApiService.getToken();
    if (token != null && token.isNotEmpty) {
      try {
        final Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
        setState(() {
          _loggedStudentId = decodedToken['student_id'];
        });
      } catch (e) {
        debugPrint('Error al decodificar JWT: $e');
      }
    }
  }

  Future<Map<String, dynamic>> _fetchTaskDetails(String taskId) async {
    final response = await http.get(
      Uri.parse(
        'https://academic-service-enfoenfoeduca-451053308845.us-central1.run.app/tasks/$taskId',
      ),
      headers: {'Authorization': 'Bearer ${await ApiService.getToken()}'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception(
        'Error al cargar el detalle de la tarea (${response.statusCode})',
      );
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg'],
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = result.files.first;
        });
      }
    } catch (e) {
      debugPrint('Error al seleccionar archivo: $e');
    }
  }

  // ==== LÓGICA REFACTORIZADA CON EL SDK OFICIAL DE SUPABASE Y TU PUT ====
  Future<void> _submitTask(String submissionId) async {
    if (_selectedFile == null || _selectedFile!.bytes == null) return;

    setState(() {
      _isUploading = true;
    });

    try {
      // 1. Subir archivo a Supabase Storage (Esto se queda igual, funciona perfecto)
      final String fileExtension = _selectedFile!.extension ?? 'pdf';
      final String uniqueFileName =
          '${widget.taskId}_${_loggedStudentId}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

      final supabase = Supabase.instance.client;

      await supabase.storage
          .from(_bucketName)
          .uploadBinary(
            uniqueFileName,
            _selectedFile!.bytes!,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      final String publicFileUrl = supabase.storage
          .from(_bucketName)
          .getPublicUrl(uniqueFileName);
      debugPrint('Archivo en Supabase: $publicFileUrl');

      // 2. DETECTAR SI ES CREACIÓN (POST) O ACTUALIZACIÓN (PUT)
      final bool isNewSubmission = submissionId.isEmpty;

      final Uri url = isNewSubmission
          ? Uri.parse(
              'https://academic-service-enfoenfoeduca-451053308845.us-central1.run.app/submissions/submission/create',
            ) // RUTA POST
          : Uri.parse(
              'https://academic-service-enfoenfoeduca-451053308845.us-central1.run.app/submissions/submission/$submissionId',
            ); // RUTA PUT

      // 3. Preparar el cuerpo de la petición según lo que pida tu backend
      final Map<String, dynamic> requestBody = {'file_url': publicFileUrl};

      // Si es una entrega nueva, tu backend probablemente necesite saber de qué tarea y qué alumno es:
      if (isNewSubmission) {
        requestBody['task_id'] = widget.taskId;
        requestBody['student_id'] = _loggedStudentId;
        requestBody['state'] =
            'PENDING'; // o el estado por defecto que use tu API
      }

      debugPrint(
        'Enviando petición (${isNewSubmission ? "POST" : "PUT"}) a: $url',
      );

      // 4. Ejecutar la petición HTTP correcta
      final http.Response apiResponse = isNewSubmission
          ? await http.post(
              url,
              headers: {
                'Authorization': 'Bearer ${await ApiService.getToken()}',
                'Content-Type': 'application/json',
              },
              body: json.encode(requestBody),
            )
          : await http.put(
              url,
              headers: {
                'Authorization': 'Bearer ${await ApiService.getToken()}',
                'Content-Type': 'application/json',
              },
              body: json.encode(requestBody),
            );

      if (apiResponse.statusCode == 200 ||
          apiResponse.statusCode == 201 ||
          apiResponse.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isNewSubmission
                  ? '¡Tarea creada y entregada con éxito!'
                  : '¡Entrega actualizada con éxito!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        _refreshData(); // Recargamos la vista para que traiga el nuevo ID que generó la BD
      } else {
        throw Exception(
          'Error en el servidor (${apiResponse.statusCode}): ${apiResponse.body}',
        );
      }
    } catch (e) {
      debugPrint('Error en el proceso de entrega: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al entregar: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isUploading = false;
      });
    }
  }

  // AÑADE ESTA FUNCIÓN DEBAJO DE _submitTask
  Future<void> _openSubmittedFile(String fileUrl) async {
    if (fileUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La URL del archivo está vacía.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final Uri url = Uri.parse(fileUrl);

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode
              .externalApplication, // Abre en el navegador nativo o app externa
        );
      } else {
        throw 'No se pudo abrir la URL';
      }
    } catch (e) {
      debugPrint('Error al abrir el archivo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo abrir el archivo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(
            '/student/course/${widget.courseId}/session/${widget.sessionId}',
          ),
        ),
        title: const Text(
          'Detalle de la Tarea',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _taskDetailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                '${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final taskData = snapshot.data!;
          final String title = taskData['title'] ?? 'Sin título';
          final String description =
              taskData['description'] ?? 'Sin descripción';
          final String dueDateRaw = taskData['due_date'] ?? '';
          final List<dynamic> submissions = taskData['task_submissions'] ?? [];

          String formattedDueDate = 'Sin fecha';
          if (dueDateRaw.isNotEmpty) {
            try {
              final parsed = DateTime.parse(dueDateRaw);
              formattedDueDate =
                  "${parsed.day}/${parsed.month}/${parsed.year} - ${parsed.hour}:${parsed.minute.toString().padLeft(2, '0')}";
            } catch (_) {}
          }

          // =========================================================================
          // BLOQUE DE DIAGNÓSTICO EN CONSOLA (Inspección de datos)
          // =========================================================================
          debugPrint('=== 🔍 INICIO DE DIAGNÓSTICO DE ENTREGA 🔍 ===');
          debugPrint(
            '1. ID del Alumno Logueado en Flutter (_loggedStudentId): "$_loggedStudentId"',
          );
          debugPrint(
            '2. Cantidad de entregas recibidas del backend: ${submissions.length}',
          );

          for (int i = 0; i < submissions.length; i++) {
            final sub = submissions[i];
            debugPrint(
              '   -> Entrega [$i]: submission_id = "${sub['submission_id']}", student_id en BD = "${sub['student_id']}"',
            );
          }
          // =

          Map<String, dynamic>? studentSubmission;
          if (_loggedStudentId != null && submissions.isNotEmpty) {
            studentSubmission = submissions.firstWhere(
              (sub) => sub['student_id'] == _loggedStudentId,
              orElse: () => null,
            );
          }

          // Verificamos el veredicto final del filtro original
          debugPrint(
            '3. ¿Se encontró coincidencia exacta? ${studentSubmission != null ? "SÍ 🎉" : "NO ❌ (studentSubmission quedó null)"}',
          );
          debugPrint('=== 🔍 FIN DE DIAGNÓSTICO 🔍 ===');

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.assignment,
                            color: Colors.orangeAccent,
                            size: 28,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      const Text(
                        'Instrucciones:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_month,
                            size: 16,
                            color: Colors.redAccent,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Fecha límite: $formattedDueDate',
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Tu Entrega',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),

                _buildSubmissionStatusCard(studentSubmission),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSubmissionStatusCard(Map<String, dynamic>? submission) {
    if (submission == null ||
        (submission['file_url'] as String? ?? '').isEmpty) {
      final String submissionId = submission?['submission_id'] ?? '';

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              _selectedFile == null
                  ? Icons.cloud_upload_outlined
                  : Icons.insert_drive_file,
              size: 44,
              color: _selectedFile == null
                  ? Colors.grey[400]
                  : Colors.blueAccent,
            ),
            const SizedBox(height: 10),
            Text(
              _selectedFile == null
                  ? 'Aún no has enviado tu respuesta'
                  : _selectedFile!.name,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: _selectedFile == null ? Colors.grey : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isUploading ? null : _pickFile,
              icon: Icon(_selectedFile == null ? Icons.search : Icons.refresh),
              label: Text(
                _selectedFile == null
                    ? 'Seleccionar Archivo'
                    : 'Cambiar Archivo',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[200],
                foregroundColor: Colors.black87,
                minimumSize: const Size(double.infinity, 45),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            if (_selectedFile != null) ...[
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _isUploading
                    ? null
                    : () => _submitTask(submissionId),
                icon: _isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                  _isUploading ? 'Subiendo tarea...' : 'Entregar Tarea',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    final String state = submission['state'] ?? 'PENDING';
    final String note = submission['note'] ?? 'Sin nota';
    final String comments =
        submission['comments'] ?? 'Sin comentarios del docente';
    final String fileUrl = submission['file_url'] ?? '';
    final bool isGraded = state == 'GRADED';

    // Lógica opcional para cambiar el icono según el tipo de archivo
    IconData fileIcon = Icons.insert_drive_file_rounded;
    Color iconColor = Colors.blueAccent;

    if (fileUrl.toLowerCase().contains('.pdf')) {
      fileIcon = Icons.picture_as_pdf;
      iconColor = Colors.redAccent;
    } else if (fileUrl.toLowerCase().contains('.doc') ||
        fileUrl.toLowerCase().contains('.docx')) {
      fileIcon = Icons.description;
      iconColor = Colors.blue;
    } else if (fileUrl.toLowerCase().contains('.png') ||
        fileUrl.toLowerCase().contains('.jpg') ||
        fileUrl.toLowerCase().contains('.jpeg')) {
      fileIcon = Icons.image;
      iconColor = Colors.green;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Estado:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isGraded
                      ? Colors.green.withOpacity(0.1)
                      : Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isGraded ? 'CALIFICADO' : 'ENTREGADO',
                  style: TextStyle(
                    color: isGraded ? Colors.green : Colors.amber[800],
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text(
                'Calificación: ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                note,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isGraded ? Colors.blueAccent : Colors.black54,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          if (fileUrl.isNotEmpty) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(fileIcon, color: iconColor),
              title: const Text(
                'Tu archivo entregado',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              subtitle: const Text(
                'Ver documento enviado',
                style: TextStyle(fontSize: 11),
              ),
              trailing: const Icon(
                Icons.open_in_new,
                size: 18,
                color: Colors.blueAccent,
              ),
              onTap: () {
                _openSubmittedFile(fileUrl);
              },
            ),
            const Divider(height: 24),
          ],
          const Text(
            'Feedback del Profesor:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Text(
              comments,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
