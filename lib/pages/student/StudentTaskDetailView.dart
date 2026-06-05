// ignore_for_file: use_build_context_synchronously, file_names
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_client.dart';
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
    final response = await ApiClient.get(
      ServiceType.academic,
      '/tasks/$taskId',
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
        'Enviando petición (${isNewSubmission ? "POST" : "PUT"}) para la entrega',
      );

      // 4. Ejecutar la petición HTTP correcta
      final apiResponse = isNewSubmission
          ? await ApiClient.post(
              ServiceType.academic,
              '/submissions/submission/create',
              body: requestBody,
            )
          : await ApiClient.put(
              ServiceType.academic,
              '/submissions/submission/$submissionId',
              body: requestBody,
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6727E8), Color(0xFF5153E8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        elevation: 10,
        shadowColor: const Color(0xFF6727E8).withValues(alpha: 0.4),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go(
            '/student/course/${widget.courseId}/session/${widget.sessionId}',
          ),
        ),
        title: const Text(
          'Detalle de la Tarea',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
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
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.assignment_rounded,
                              color: Colors.orangeAccent,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 32),
                      const Text(
                        'Instrucciones',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF6727E8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.calendar_month_rounded,
                              size: 16,
                              color: Colors.redAccent,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Límite: $formattedDueDate',
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
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
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              _selectedFile == null
                  ? Icons.cloud_upload_rounded
                  : Icons.insert_drive_file_rounded,
              size: 56,
              color: _selectedFile == null
                  ? Colors.grey[400]
                  : const Color(0xFF6727E8),
            ),
            const SizedBox(height: 16),
            Text(
              _selectedFile == null
                  ? 'Aún no has enviado tu respuesta'
                  : _selectedFile!.name,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: _selectedFile == null
                    ? Colors.grey[600]
                    : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _isUploading ? null : _pickFile,
              icon: Icon(
                _selectedFile == null ? Icons.search : Icons.refresh_rounded,
              ),
              label: Text(
                _selectedFile == null
                    ? 'Seleccionar Archivo'
                    : 'Cambiar Archivo',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6727E8),
                side: BorderSide(
                  color: _selectedFile == null
                      ? Colors.grey.shade300
                      : const Color(0xFF6727E8),
                ),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            if (_selectedFile != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6727E8), Color(0xFF5153E8)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6727E8).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
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
                    _isUploading ? 'Subiendo...' : 'Entregar Tarea',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Estado:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isGraded
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.orangeAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isGraded ? 'CALIFICADO' : 'ENTREGADO',
                  style: TextStyle(
                    color: isGraded ? Colors.green : Colors.orange.shade800,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text(
                'Calificación:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const Spacer(),
              Text(
                note,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isGraded ? const Color(0xFF6727E8) : Colors.black54,
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          if (fileUrl.isNotEmpty) ...[
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(fileIcon, color: iconColor),
                ),
                title: const Text(
                  'Tu archivo entregado',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
                subtitle: const Text(
                  'Ver documento enviado',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6727E8).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Color(0xFF6727E8),
                    size: 16,
                  ),
                ),
                onTap: () {
                  _openSubmittedFile(fileUrl);
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
          const Text(
            'Feedback del Profesor:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF6727E8),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              comments,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 14,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
