import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/Student.dart';
import '../../models/Parent.dart';
import '../../models/Section.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class DynamicCrudScreen extends StatefulWidget {
  final String title;
  final String endpoint;
  final bool canAdd;
  final bool canEdit;
  final bool canDelete;
  final Map<String, String> addFields;

  const DynamicCrudScreen({
    super.key,
    required this.title,
    required this.endpoint,
    this.canAdd = false,
    this.canEdit = false,
    this.canDelete = false,
    this.addFields = const {},
  });

  @override
  State<DynamicCrudScreen> createState() => _DynamicCrudScreenState();
}

// ==================== APIs EXISTENTES ====================

Future<List<Student>> fetchStudents() async {
  try {
    final response = await http.get(
      Uri.parse(
        'https://users-service-enfoenfoeduca-451053308845.us-central1.run.app/students',
      ),
      headers: {'Authorization': 'Bearer ${await ApiService.getToken()}'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((student) => Student.fromJson(student)).toList();
    } else {
      throw Exception('Failed to load students: ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('Failed to load students ca : $e');
  }
}

Future<void> createStudent(Map<String, dynamic> studentData) async {
  final response = await http.post(
    Uri.parse(
      'https://users-service-enfoenfoeduca-451053308845.us-central1.run.app/students/create',
    ),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${await ApiService.getToken()}',
    },
    body: jsonEncode(studentData),
  );

  if (response.statusCode != 201) {
    throw Exception('Failed to create student');
  }
}

Future<void> updateStudent(
  String studentId,
  Map<String, dynamic> studentData,
) async {
  final response = await http.put(
    Uri.parse(
      'https://users-service-enfoenfoeduca-451053308845.us-central1.run.app/students/$studentId',
    ),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${await ApiService.getToken()}',
    },
    body: jsonEncode(studentData),
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to update student');
  }
}

Future<void> deleteStudent(String studentId) async {
  final response = await http.delete(
    Uri.parse(
      'https://users-service-enfoenfoeduca-451053308845.us-central1.run.app/students/$studentId',
    ),
    headers: {'Authorization': 'Bearer ${await ApiService.getToken()}'},
  );

  if (response.statusCode != 200 && response.statusCode != 204) {
    throw Exception('Failed to delete student');
  }
}

Future<List<Section>> fetchSections() async {
  try {
    final response = await http.get(
      Uri.parse(
        'https://academic-service-enfoenfoeduca-451053308845.us-central1.run.app/sections/',
      ),
      headers: {'Authorization': 'Bearer ${await ApiService.getToken()}'},
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((section) => Section.fromJson(section)).toList();
    } else {
      throw Exception('Failed to load sections: ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('Failed to load sections ca : $e');
  }
}

Future<List<Parent>> fetchParents() async {
  try {
    final response = await http.get(
      Uri.parse(
        'https://users-service-enfoenfoeduca-451053308845.us-central1.run.app/parents',
      ),
      headers: {'Authorization': 'Bearer ${await ApiService.getToken()}'},
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((parent) => Parent.fromJson(parent)).toList();
    } else {
      throw Exception('Failed to load parents: ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('Failed to load parentns ca : $e');
  }
}

// ==================== ESTADO DE LA SCREEN ====================

class _DynamicCrudScreenState extends State<DynamicCrudScreen> {
  Future<List<Student>>? studentsFuture;
  Future<List<Section>>? sectionsFuture;
  Future<List<Parent>>? parentsFuture;

  void refreshStudents() {
    setState(() {
      studentsFuture = fetchStudents();
      sectionsFuture = fetchSections();
      parentsFuture = fetchParents();
    });
  }

  @override
  void initState() {
    super.initState();
    // Inicializamos todos los Futures al arrancar
    studentsFuture = fetchStudents();
    sectionsFuture = fetchSections();
    parentsFuture = fetchParents();
  }

  Future<void> _showAddStudentDialog() async {
    final nameController = TextEditingController();
    final lastNameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    String? selectedParentId;
    String? selectedSectionId;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Nuevo Estudiante'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                    ),
                    TextField(
                      controller: lastNameController,
                      decoration: const InputDecoration(labelText: 'Apellido'),
                    ),
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    TextField(
                      controller: passwordController,
                      decoration: const InputDecoration(labelText: 'Password'),
                    ),
                    const SizedBox(height: 15),

                    // ================= Dropdown de Padres con FutureBuilder =================
                    FutureBuilder<List<Parent>>(
                      future: parentsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child:
                                LinearProgressIndicator(), // Barra de carga estética mientras descarga
                          );
                        }

                        final parents = snapshot.data ?? [];
                        if (parents.isEmpty) {
                          return const Text(
                            'No se encontraron padres o falló la API',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          );
                        }

                        return DropdownButtonFormField<String>(
                          value: selectedParentId,
                          decoration: const InputDecoration(
                            labelText: 'Seleccionar Padre',
                          ),
                          items: parents.map((parent) {
                            return DropdownMenuItem<String>(
                              value: parent.parentId,
                              child: Text(
                                '${parent.parentId} ${parent.lastName}',
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() => selectedParentId = value);
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 15),

                    // ================= Dropdown de Secciones con FutureBuilder =================
                    FutureBuilder<List<Section>>(
                      future: sectionsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: LinearProgressIndicator(),
                          );
                        }

                        final sections = snapshot.data ?? [];
                        if (sections.isEmpty) {
                          return const Text(
                            '⚠️ No se encontraron secciones',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          );
                        }

                        return DropdownButtonFormField<String>(
                          initialValue: selectedSectionId,
                          decoration: const InputDecoration(
                            labelText: 'Seleccionar Sección',
                          ),
                          items: sections.map((section) {
                            return DropdownMenuItem<String>(
                              value: section.idSection,
                              child: Text('${section.name} - ${section.grade}'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() => selectedSectionId = value);
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cancelar'),
                  onPressed: () => Navigator.pop(context),
                ),
                ElevatedButton(
                  child: const Text('Guardar'),
                  onPressed: () async {
                    if (selectedParentId == null || selectedSectionId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Por favor, seleccione Padre y Sección',
                          ),
                        ),
                      );
                      return;
                    }

                    try {
                      await createStudent({
                        'name': nameController.text,
                        'last_name': lastNameController.text,
                        'email': emailController.text,
                        'password': passwordController.text,
                        'parent_id': selectedParentId,
                        'id_section': selectedSectionId,
                      });

                      refreshStudents();
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error al crear: $e')),
                        );
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showEditStudentDialog(Student student) async {
    String? selectedParentId = student.parentId;
    String? selectedSectionId = student.section.idSection;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Editar Estudiante'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${student.name} ${student.lastName}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),

                  // ================= Dropdown de Padres en Edición =================
                  FutureBuilder<List<Parent>>(
                    future: parentsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const LinearProgressIndicator();
                      }
                      final parents = snapshot.data ?? [];

                      // Validamos la existencia solo cuando los datos ya llegaron
                      final parentExists = parents.any(
                        (p) => p.parentId == selectedParentId,
                      );
                      if (!parentExists) selectedParentId = null;

                      return DropdownButtonFormField<String>(
                        value: selectedParentId,
                        decoration: const InputDecoration(
                          labelText: 'Modificar Padre',
                        ),
                        items: parents.map((parent) {
                          return DropdownMenuItem<String>(
                            value: parent.parentId,
                            child: Text('${parent.name} ${parent.lastName}'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() => selectedParentId = value);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 15),

                  // ================= Dropdown de Secciones en Edición =================
                  FutureBuilder<List<Section>>(
                    future: sectionsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const LinearProgressIndicator();
                      }
                      final sections = snapshot.data ?? [];

                      final sectionExists = sections.any(
                        (s) => s.idSection == selectedSectionId,
                      );
                      if (!sectionExists) selectedSectionId = null;

                      return DropdownButtonFormField<String>(
                        value: selectedSectionId,
                        decoration: const InputDecoration(
                          labelText: 'Modificar Sección',
                        ),
                        items: sections.map((section) {
                          return DropdownMenuItem<String>(
                            value: section.idSection,
                            child: Text('${section.name} - ${section.grade}'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() => selectedSectionId = value);
                        },
                      );
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await updateStudent(student.studentId, {
                        'parent_id': selectedParentId,
                        'id_section': selectedSectionId,
                      });

                      refreshStudents();

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Alumno actualizado')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('$e')));
                      }
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: FutureBuilder<List<Student>>(
        future: studentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay estudiantes'));
          }

          final students = snapshot.data!;

          return ListView.builder(
            itemCount: students.length,
            itemBuilder: (context, index) {
              final student = students[index];

              return Card(
                child: ListTile(
                  title: Text('${student.name} ${student.lastName}'),
                  subtitle: Text(student.email),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showEditStudentDialog(student),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () async {
                          try {
                            await deleteStudent(student.studentId);
                            refreshStudents();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Alumno eliminado'),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text('$e')));
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddStudentDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
