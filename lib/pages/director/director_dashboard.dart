import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DirectorDashboard extends StatelessWidget {
  const DirectorDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Director Dashboard'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () => context.go('/login')),
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
