import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_service.dart';

class AdminLayout extends StatelessWidget {
  final Widget child;

  const AdminLayout({super.key, required this.child});

  // Determina el índice del menú lateral basado en la ruta actual del navegador
  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/admin/courses')) return 1;
    if (location.startsWith('/admin/users')) return 2;
    if (location.startsWith('/admin/periods')) return 3;
    if (location.startsWith('/admin/sections')) return 4;
    if (location.startsWith('/admin/assignments')) return 5;
    return 0; // Por defecto /admin (Inicio)
  }

  Future<void> _handleLogout(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Cerrar Sesión',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: const Text(
          '¿Está seguro de que desea salir del Panel de Administración?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Salir'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ApiService.logout();
      if (context.mounted) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final int selectedIndex = _calculateSelectedIndex(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          // ==========================================
          // MENÚ LATERAL COMPARTIDO Y PERMANENTE
          // ==========================================
          NavigationRail(
            selectedIndex: selectedIndex,
            elevation: 1,
            backgroundColor: const Color(
              0xFF0F172A,
            ), // Slate corporativo oscuro
            unselectedIconTheme: const IconThemeData(color: Colors.white60),
            unselectedLabelTextStyle: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
            ),
            selectedIconTheme: const IconThemeData(color: Colors.blueAccent),
            selectedLabelTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            labelType: NavigationRailLabelType.all,
            onDestinationSelected: (int index) {
              if (index == selectedIndex) return;

              // Navegación limpia usando la estructura nativa
              if (index == 0) context.go('/admin');
              if (index == 1) context.go('/admin/courses');
              if (index == 2) context.go('/admin/users');
              if (index == 3) context.go('/admin/periods');
              if (index == 4) context.go('/admin/sections');
              if (index == 5) context.go('/admin/assignments');
            },
            leading: const Column(
              children: [
                SizedBox(height: 16),
                Icon(
                  Icons.admin_panel_settings_rounded,
                  color: Colors.amber,
                  size: 32,
                ),
                SizedBox(height: 8),
                Text(
                  'ADMIN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                SizedBox(height: 20),
              ],
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_rounded),
                label: Text('Inicio'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.auto_stories_rounded),
                label: Text('Cursos'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_rounded),
                label: Text('Usuarios'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.calendar_today_rounded),
                label: Text('Periodos'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.layers_rounded),
                label: Text('Secciones'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.assignment_turned_in_rounded),
                label: Text('Asignaciones'),
              ),
            ],
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: IconButton(
                    icon: const Icon(
                      Icons.logout_rounded,
                      color: Colors.redAccent,
                    ),
                    tooltip: 'Cerrar Sesión',
                    onPressed: () => _handleLogout(context),
                  ),
                ),
              ),
            ),
          ),

          // ==========================================
          // CONTENIDO DINÁMICO DE LA VISTA SELECCIONADA
          // ==========================================
          Expanded(
            child:
                child, // Aquí GoRouter inyectará la vista interna sin reconstruir el menú
          ),
        ],
      ),
    );
  }
}
