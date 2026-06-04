// ignore_for_file: file_names
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';

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

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final token = await ApiService.getToken();
      // Ajusta la URL de calificación según el estándar de tu backend (usualmente /task-submissions/:id o similar)
      final url =
          'https://academic-service-enfoenfoeduca-451053308845.us-central1.run.app/submissions/submission/${widget.submissionId}';

      final response = await http.put(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          "note": _noteController.text,
          "comments": _commentsController.text,
          "state": "GRADED",
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Calificación guardada con éxito'),
            backgroundColor: Colors.teal,
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
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        title: const Text(
          'Detalle de Entrega',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tarjeta de información del Alumno
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Colors.teal,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.studentName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Entregado el: ${submittedAt.split('T')[0]} a las ${submittedAt.split('T')[1].substring(0, 5)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
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
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: const Text(
                        'Ver Archivo',
                        style: TextStyle(fontSize: 11),
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
                prefixIcon: Icon(Icons.grade, color: Colors.teal),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentsController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Comentarios o Retroalimentación',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.comment, color: Colors.teal),
              ),
            ),
            const SizedBox(height: 24),

            // Botón de Envío
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveGrade,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Guardar Nota y Retroalimentación',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
