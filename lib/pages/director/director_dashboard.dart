import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_service.dart';

class DirectorDashboard extends StatelessWidget {
  const DirectorDashboard({super.key});

  void _logout(BuildContext context) async {
    await ApiService.logout();
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Director Dashboard'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () => _logout(context)),
        ],
      ),
      body: ListView(
        children: [
          ListTile(title: const Text('Analíticas del Sistema'), onTap: () => context.go('/director/analytics')),
          ListTile(title: const Text('Rendimiento Estudiantil'), onTap: () => context.go('/director/performance')),
        ],
      ),
    );
  }
}
