import '../config/environment.dart';

class ApiConstants {
  // ==========================================
  // Base URLs para los microservicios (Backend)
  // ==========================================
  static String get authServiceBaseUrl => Environment.authServiceUrl;
  static String get usersServiceBaseUrl => Environment.usersServiceUrl;
  static String get academicServiceBaseUrl => Environment.academicServiceUrl;

  // ==========================================
  // Endpoints de Autenticación (Auth_Service)
  // ==========================================
  static String get login => '$authServiceBaseUrl/auth/login';
  static String get register =>
      '$authServiceBaseUrl/auth/register'; // Uso exclusivo para ADMIN

  // ==========================================
  // Endpoints de Gestión de Usuarios (Users_Service)
  // ==========================================
  static String get users => '$usersServiceBaseUrl/users';
  static String get students => '$usersServiceBaseUrl/students';
  static String get teachers => '$usersServiceBaseUrl/teachers';
  static String get parents => '$usersServiceBaseUrl/parents';
  static String get directors => '$usersServiceBaseUrl/directors';

  // Endpoints Académicos
  static String get academicPeriods => '$academicServiceBaseUrl/period';
  static String get courses => '$academicServiceBaseUrl/courses';
  static String get sections => '$academicServiceBaseUrl/sections';
  static String get sessions => '$academicServiceBaseUrl/courses/sessions';
  static String get assignments => '$academicServiceBaseUrl/assignments';
  static String get attendances => '$academicServiceBaseUrl/attendances';
  static String get tasks => '$academicServiceBaseUrl/tasks';
  static String get materials => '$academicServiceBaseUrl/courses/materials';
  static String get taskSubmissions =>
      '$academicServiceBaseUrl/tasks/submission';
}
