/// Clase `ApiConstants`
/// Contiene todas las URLs y rutas de los microservicios backend.
/// Se centralizan aquí para facilitar cambios de dominio o puerto en el futuro.
class ApiConstants {
  // ==========================================
  // Base URLs para los microservicios (Backend)
  // ==========================================
  static const String authServiceBaseUrl =
      'https://auth-service-enfoenfoeduca-451053308845.europe-west1.run.app';
  static const String usersServiceBaseUrl =
      'https://users-service-enfoenfoeduca-451053308845.us-central1.run.app';
  static const String academicServiceBaseUrl =
      'https://academic-service-enfoenfoeduca-451053308845.us-central1.run.app';

  // ==========================================
  // Endpoints de Autenticación (Auth_Service)
  // ==========================================
  static const String login = '$authServiceBaseUrl/auth/login';
  static const String register =
      '$authServiceBaseUrl/auth/register'; // Uso exclusivo para ADMIN

  // ==========================================
  // Endpoints de Gestión de Usuarios (Users_Service)
  // ==========================================
  static const String users = '$usersServiceBaseUrl/users';
  static const String students = '$usersServiceBaseUrl/students';
  static const String teachers = '$usersServiceBaseUrl/teachers';
  static const String parents = '$usersServiceBaseUrl/parents';
  static const String directors = '$usersServiceBaseUrl/directors';

  // Endpoints Académicos
  static const String academicPeriods = '$academicServiceBaseUrl/periods';
  static const String courses = '$academicServiceBaseUrl/courses';
  static const String sections = '$academicServiceBaseUrl/sections';
  static const String sessions = '$academicServiceBaseUrl/sessions';
  static const String assignments = '$academicServiceBaseUrl/assignments';
  static const String attendances = '$academicServiceBaseUrl/attendances';
  static const String tasks = '$academicServiceBaseUrl/tasks';
  static const String materials = '$academicServiceBaseUrl/materials';
  static const String taskSubmissions =
      '$academicServiceBaseUrl/task-submissions';
}
