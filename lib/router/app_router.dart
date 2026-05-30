import 'package:go_router/go_router.dart';
import '../pages/auth/login_screen.dart';
import '../pages/admin/admin_dashboard.dart';
import '../pages/admin/crud_generics.dart';
import '../pages/teacher/teacher_dashboard.dart';
import '../pages/student/student_dashboard.dart';
import '../pages/parent/parent_dashboard.dart';
import '../pages/director/director_dashboard.dart';

/// Enrutador principal de la aplicación.
/// Utiliza `go_router` para habilitar la navegación declarativa y
/// el soporte de URLs (Deep Linking) tanto en Web como en Móvil.
final appRouter = GoRouter(
  initialLocation: '/login', // Ruta inicial de la aplicación
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    
    // Rutas Admin
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminDashboard(),
      routes: [
        GoRoute(
          path: 'users',
          builder: (context, state) => const GenericCrudScreen(title: 'Gestión de Usuarios'),
        ),
        GoRoute(
          path: 'periods',
          builder: (context, state) => const GenericCrudScreen(title: 'Periodos Académicos'),
        ),
        GoRoute(
          path: 'courses',
          builder: (context, state) => const GenericCrudScreen(title: 'Gestión de Cursos'),
        ),
        GoRoute(
          path: 'sections',
          builder: (context, state) => const GenericCrudScreen(title: 'Gestión de Secciones'),
        ),
        GoRoute(
          path: 'assignments',
          builder: (context, state) => const GenericCrudScreen(title: 'Asignaciones Académicas'),
        ),
      ]
    ),

    // Rutas Teacher
    GoRoute(
      path: '/teacher',
      builder: (context, state) => const TeacherDashboard(),
      routes: [
        GoRoute(
          path: 'attendances',
          builder: (context, state) => const GenericCrudScreen(title: 'Asistencias'),
        ),
        GoRoute(
          path: 'tasks',
          builder: (context, state) => const GenericCrudScreen(title: 'Tareas'),
        ),
        GoRoute(
          path: 'materials',
          builder: (context, state) => const GenericCrudScreen(title: 'Materiales'),
        ),
        GoRoute(
          path: 'submissions',
          builder: (context, state) => const GenericCrudScreen(title: 'Entregas de Tareas'),
        ),
      ]
    ),

    // Rutas Student
    GoRoute(
      path: '/student',
      builder: (context, state) => const StudentDashboard(),
      routes: [
        GoRoute(
          path: 'tasks',
          builder: (context, state) => const GenericCrudScreen(title: 'Mis Tareas'),
        ),
        GoRoute(
          path: 'materials',
          builder: (context, state) => const GenericCrudScreen(title: 'Materiales del Curso'),
        ),
        GoRoute(
          path: 'attendances',
          builder: (context, state) => const GenericCrudScreen(title: 'Mi Asistencia'),
        ),
        GoRoute(
          path: 'grades',
          builder: (context, state) => const GenericCrudScreen(title: 'Mis Notas'),
        ),
      ]
    ),

    // Rutas Parent
    GoRoute(
      path: '/parent',
      builder: (context, state) => const ParentDashboard(),
      routes: [
        GoRoute(
          path: 'attendances',
          builder: (context, state) => const GenericCrudScreen(title: 'Asistencia de mis hijos'),
        ),
        GoRoute(
          path: 'grades',
          builder: (context, state) => const GenericCrudScreen(title: 'Notas de mis hijos'),
        ),
        GoRoute(
          path: 'tasks',
          builder: (context, state) => const GenericCrudScreen(title: 'Tareas Pendientes'),
        ),
      ]
    ),

    // Rutas Director
    GoRoute(
      path: '/director',
      builder: (context, state) => const DirectorDashboard(),
      routes: [
        GoRoute(
          path: 'analytics',
          builder: (context, state) => const GenericCrudScreen(title: 'Analíticas del Sistema'),
        ),
        GoRoute(
          path: 'performance',
          builder: (context, state) => const GenericCrudScreen(title: 'Rendimiento Estudiantil'),
        ),
      ]
    ),
  ],
);
