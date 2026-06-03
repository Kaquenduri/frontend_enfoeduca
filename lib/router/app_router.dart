import 'package:go_router/go_router.dart';
import '../pages/auth/login_screen.dart';

import '../pages/admin/admin_layout.dart';
import '../pages/admin/admin_dashboard.dart';
import '../pages/admin/admin_courses_crud_view.dart';
import '../pages/admin/admin_users_crud_view.dart';
import '../pages/admin/admin_periods_crud_view.dart';
import '../pages/admin/admin_sections_crud_view.dart';
import '../pages/admin/admin_assignments_crud_view.dart';

import '../pages/student/student_dashboard.dart';
import '../pages/student/StudentCourseDetailsView.dart.dart';
import '../pages/student/student_session_materials_view.dart';
import '../pages/student/StudentTaskDetailView.dart';

import '../pages/teacher/teacher_dashboard.dart';
import '../pages/teacher/TeacherCourseDetailsView.dart';
import '../pages/teacher/TeacherSessionMaterialsView.dart';
import '../pages/teacher/TeacherTaskSubmissionsView.dart';
import '../pages/teacher/TeacherSubmissionDetailView.dart';

import '../pages/parent/parent_dashboard.dart';
import '../pages/parent/Parent_student_details_view.dart';

import '../pages/director/director_dashboard.dart';

final appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),

    // Admin
    ShellRoute(
      builder: (context, state, child) {
        // Envolvemos las pantallas internas en el AdminLayout
        return AdminLayout(child: child);
      },
      routes: [
        GoRoute(
          path: '/admin',
          builder: (context, state) => const AdminDashboardView(),
        ),
        GoRoute(
          path: '/admin/courses',
          builder: (context, state) => const AdminCoursesCrudView(),
        ),
        GoRoute(
          path: '/admin/users',
          builder: (context, state) => const AdminUsersCrudView(),
        ),
        GoRoute(
          path: '/admin/periods',
          builder: (context, state) => const AdminPeriodsCrudView(),
        ),
        GoRoute(
          path: '/admin/sections',
          builder: (context, state) => const AdminSectionsCrudView(),
        ),
        GoRoute(
          path: '/admin/assignments',
          builder: (context, state) => const AdminAssignmentsCrudView(),
        ),
      ],
    ),

    // Teacher
    GoRoute(
      path: '/teacher',
      builder: (context, state) => const TeacherDashboard(),
      routes: [
        // 1. Detalle del curso seleccionado (Muestra las Sesiones)
        GoRoute(
          path:
              'course/:courseId/sectionId/:sectionId', // Ruta relativa: /teacher/course/:courseId
          builder: (context, state) {
            final courseId = state.pathParameters['courseId']!;
            final sectionId = state.pathParameters['sectionId']!;

            // Retornamos el Dashboard envolviendo la vista detallada para mantener el menú izquierdo
            return TeacherDashboard(
              child: TeacherCourseDetailsView(
                courseId: courseId,
                sectionId: sectionId,
              ),
            );
          },
        ),
        GoRoute(
          path:
              'course/:courseId/sectionId/:sectionId/session/:sessionId', // Ruta relativa: /teacher/course/:courseId/session/:sessionId
          builder: (context, state) {
            final courseId = state.pathParameters['courseId']!;
            final sectionId = state.pathParameters['sectionId']!;
            final sessionId = state.pathParameters['sessionId']!;

            return TeacherDashboard(
              child: TeacherSessionMaterialsView(
                courseId: courseId,
                sectionId: sectionId,
                sessionId: sessionId,
              ),
            );
          },
          routes: [
            // !!! NUEVA RUTA HIJA 1: LISTADO DE ENTREGAS DE UNA TAREA !!!
            GoRoute(
              path: 'task/:taskId',
              builder: (context, state) {
                final courseId = state.pathParameters['courseId']!;
                final sectionId = state.pathParameters['sectionId']!;
                final sessionId = state.pathParameters['sessionId']!;
                final taskId = state.pathParameters['taskId']!;
                return TeacherDashboard(
                  child: TeacherTaskSubmissionsView(
                    courseId: courseId,
                    sectionId: sectionId,
                    sessionId: sessionId,
                    taskId: taskId,
                  ),
                );
              },
              routes: [
                // !!! NUEVA RUTA HIJA 2: DETALLE Y CALIFICACIÓN DE UNA ENTREGA !!!
                GoRoute(
                  path: 'submission/:submissionId',
                  builder: (context, state) {
                    final courseId = state.pathParameters['courseId']!;
                    final sectionId = state.pathParameters['sectionId']!;
                    final sessionId = state.pathParameters['sessionId']!;
                    final taskId = state.pathParameters['taskId']!;
                    final submissionId = state.pathParameters['submissionId']!;

                    // Extraemos los datos enviados en el context.push a través del campo 'extra'
                    final extraParams = state.extra as Map<String, dynamic>;
                    final submissionData =
                        extraParams['submission'] as Map<String, dynamic>;
                    final studentName = extraParams['studentName'] as String;

                    return TeacherDashboard(
                      child: TeacherSubmissionDetailView(
                        courseId: courseId,
                        sectionId: sectionId,
                        sessionId: sessionId,
                        taskId: taskId,
                        submissionId: submissionId,
                        submissionData: submissionData,
                        studentName: studentName,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    ),

    // Student
    GoRoute(
      path: '/student',
      builder: (context, state) => const StudentDashboard(),
      routes: [
        GoRoute(
          path: 'course/:courseId',
          builder: (context, state) {
            final courseId = state.pathParameters['courseId']!;
            // Pasamos el ID del curso a la vista de detalles
            return StudentDashboard(
              child: StudentCourseDetailsView(courseId: courseId),
            );
          },
          // AGREGAMOS RUTAS HIJAS DEL CURSO AQUÍ:
          routes: [
            GoRoute(
              path: 'session/:sessionId',
              builder: (context, state) {
                final courseId = state.pathParameters['courseId']!;
                final sessionId = state.pathParameters['sessionId']!;

                // Retornamos el Dashboard con la nueva vista de materiales de la sesión
                return StudentDashboard(
                  child: StudentSessionMaterialsView(
                    courseId: courseId,
                    sessionId: sessionId,
                  ),
                );
              },
              // !!! AQUÍ AGREGAMOS LA NUEVA RUTA HIJA DE LA SESIÓN !!!
              routes: [
                GoRoute(
                  path:
                      'task/:taskId', // No lleva "/" al inicio por ser ruta hija
                  builder: (context, state) {
                    // Heredamos los parámetros de todos los padres hacia atrás
                    final courseId = state.pathParameters['courseId']!;
                    final sessionId = state.pathParameters['sessionId']!;
                    final taskId = state.pathParameters['taskId']!;

                    // Retornamos el Dashboard envolviendo tu nueva vista detallada
                    return StudentDashboard(
                      child: StudentTaskDetailView(
                        courseId: courseId,
                        sessionId: sessionId,
                        taskId: taskId,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    ),

    // Parent
    GoRoute(
      path: '/parent',
      builder: (context, state) => const ParentDashboard(),
      routes: [
        GoRoute(
          path:
              'student/:studentId', // Genera la ruta: /parent/student/cfdd7d0f-...
          builder: (context, state) {
            final studentId = state.pathParameters['studentId'] ?? '';
            return ParentStudentDetailsView(studentId: studentId);
          },
        ),
      ],
    ),

    // Director
    GoRoute(
      path: '/director',
      builder: (context, state) => const DirectorDashboardView(),
      routes: [],
    ),
  ],
);
