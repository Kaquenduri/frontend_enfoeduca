import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_service.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  void _logout(BuildContext context) async {
    await ApiService.logout();
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Gestión de Usuarios p'),
            onTap: () => context.go('/admin/users'),
          ),
          ListTile(
            title: const Text('Periodos Académicos'),
            onTap: () => context.go('/admin/periods'),
          ),
          ListTile(
            title: const Text('Cursos'),
            onTap: () => context.go('/admin/courses'),
          ),
          ListTile(
            title: const Text('Secciones'),
            onTap: () => context.go('/admin/sections'),
          ),
          ListTile(
            title: const Text('Asignaciones (Assignments)'),
            onTap: () => context.go('/admin/assignments'),
          ),
        ],
      ),
    );
  }
}
