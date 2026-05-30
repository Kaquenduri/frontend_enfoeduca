import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class StudentDashboard extends StatelessWidget {
  const StudentDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Dashboard'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () => context.go('/login')),
        ],
      ),
      body: ListView(
        children: [
          ListTile(title: const Text('Mis Tareas'), onTap: () => context.go('/student/tasks')),
          ListTile(title: const Text('Materiales'), onTap: () => context.go('/student/materials')),
          ListTile(title: const Text('Mi Asistencia'), onTap: () => context.go('/student/attendances')),
          ListTile(title: const Text('Mis Notas'), onTap: () => context.go('/student/grades')),
        ],
      ),
    );
  }
}
