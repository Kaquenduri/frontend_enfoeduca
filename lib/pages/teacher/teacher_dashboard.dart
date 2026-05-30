import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TeacherDashboard extends StatelessWidget {
  const TeacherDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Dashboard'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () => context.go('/login')),
        ],
      ),
      body: ListView(
        children: [
          ListTile(title: const Text('Mis Cursos/Sesiones'), onTap: () {}),
          ListTile(title: const Text('Asistencias'), onTap: () => context.go('/teacher/attendances')),
          ListTile(title: const Text('Tareas'), onTap: () => context.go('/teacher/tasks')),
          ListTile(title: const Text('Materiales'), onTap: () => context.go('/teacher/materials')),
          ListTile(title: const Text('Entregas de Tareas'), onTap: () => context.go('/teacher/submissions')),
        ],
      ),
    );
  }
}
