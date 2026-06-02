import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_service.dart';

class ParentDashboard extends StatelessWidget {
  const ParentDashboard({super.key});

  void _logout(BuildContext context) async {
    await ApiService.logout();
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parent Dashboard'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () => _logout(context)),
        ],
      ),
      body: ListView(
        children: [
          ListTile(title: const Text('Asistencia de mis hijos'), onTap: () => context.go('/parent/attendances')),
          ListTile(title: const Text('Notas'), onTap: () => context.go('/parent/grades')),
          ListTile(title: const Text('Tareas Pendientes'), onTap: () => context.go('/parent/tasks')),
        ],
      ),
    );
  }
}
