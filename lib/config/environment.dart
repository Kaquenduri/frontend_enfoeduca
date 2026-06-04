import 'package:flutter_dotenv/flutter_dotenv.dart';

class Environment {
  static String get academicServiceUrl => dotenv.env['ACADEMIC_SERVICE_URL'] ?? '';
  static String get usersServiceUrl => dotenv.env['USERS_SERVICE_URL'] ?? '';
  static String get authServiceUrl => dotenv.env['AUTH_SERVICE_URL'] ?? '';
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
}
