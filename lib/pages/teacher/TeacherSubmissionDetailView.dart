// ignore_for_file: file_names
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_client.dart';

class TeacherSubmissionDetailView extends StatefulWidget {
  final String courseId;
  final String sectionId;
  final String sessionId;
  final String taskId;
  final String submissionId;
  final Map<String, dynamic> submissionData;
  final String studentName;

  const TeacherSubmissionDetailView({
    super.key,
    required this.courseId,
    required this.sectionId,
    required this.sessionId,
    required this.taskId,
    required this.submissionId,
    required this.submissionData,
    required this.studentName,
  });

  @override
  State<TeacherSubmissionDetailView> createState() =>
      _TeacherSubmissionDetailViewState();
}

class _TeacherSubmissionDetailViewState
    extends State<TeacherSubmissionDetailView> {
  final _noteController = TextEditingController();
  final _commentsController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _noteController.text = widget.submissionData['note'] ?? '';
    _commentsController.text = widget.submissionData['comments'] ?? '';
  }

  Future<void> _saveGrade() async {
    if (_noteController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, asigne una nota.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final double? parsedNote = double.tryParse(_noteController.text);
    if (parsedNote == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La nota debe ser un número válido.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (parsedNote < 0 || parsedNote > 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La nota debe estar entre 0 y 20.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final response = await ApiClient.put(
        ServiceType.academic,
        '/submissions/submission/${widget.submissionId}',
        body: {
          "note": _noteController.text,
          "comments": _commentsController.text,
          "state": "GRADED",
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Calificación guardada con éxito'),
            backgroundColor: const Color(0xFF1E3A8A),
          ),
        );
        if (mounted) Navigator.pop(context);
      } else {
        throw Exception(
          'Error del servidor (${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _openFile(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir el archivo de entrega.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String fileUrl = widget.submissionData['file_url'] ?? '';
    final String submittedAt = widget.submissionData['submitted_at'] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        elevation: 10,
        shadowColor: const Color(0xFF1E3A8A).withValues(alpha: 0.4),
        title: const Text(
          'Detalle de Entrega',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tarjeta de información del Alumno
            Container(
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
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: Color(0xFF1E3A8A),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.studentName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Entregado: ${submittedAt.split('T')[0]} a las ${submittedAt.split('T')[1].substring(0, 5)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Sección del Recurso/Archivo
            const Text(
              'Archivo Adjunto por el Alumno',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            if (fileUrl.isNotEmpty && fileUrl != 'file')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.description,
                      color: Colors.orangeAccent,
                      size: 30,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        fileUrl.split('/').last,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => _openFile(fileUrl),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(
                          0xFF1E3A8A,
                        ).withValues(alpha: 0.1),
                        foregroundColor: const Color(0xFF1E3A8A),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Ver Archivo',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              const Text(
                'El alumno no subió un archivo válido o es texto plano.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // Formulario de Calificación
            const Text(
              'Evaluación del Profesor',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Nota / Calificación',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.grade, color: const Color(0xFF1E3A8A)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentsController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Comentarios o Retroalimentación',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.comment, color: const Color(0xFF1E3A8A)),
              ),
            ),
            const SizedBox(height: 24),

            // Botón de Envío
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveGrade,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Container(
                    alignment: Alignment.center,
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Guardar Evaluación',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
