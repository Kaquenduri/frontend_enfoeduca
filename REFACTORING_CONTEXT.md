# CONTEXTO DE REFACTORIZACIÓN - frontend_enfoeduca (Flutter Web LMS)

## RESUMEN EJECUTIVO
Se está realizando una refactorización profunda de un proyecto Flutter Web (LMS educativo). El proyecto usa Supabase para Auth/Storage y microservicios en Google Cloud Run para Users y Academic. El objetivo es **eliminar código repetido, centralizar URLs en .env, y unificar llamadas HTTP** sin cambiar la funcionalidad.

---

## ARQUITECTURA DEL PROYECTO

```
lib/
├── api/
│   └── api_constants.dart        # ✅ YA MIGRADO - URLs dinámicas desde Environment
├── config/
│   └── environment.dart          # ✅ NUEVO - Lee variables del .env
├── components/                   # Componentes reutilizables (vacío o mínimo)
├── models/
│   ├── AcademicPeriod.dart
│   ├── Assignment.dart
│   ├── Course.dart
│   ├── Material.dart
│   ├── Parent.dart
│   ├── Section.dart
│   ├── Session.dart
│   ├── Student.dart
│   ├── TeacherAssignment.dart
│   └── users.dart
├── pages/
│   ├── admin/
│   │   ├── admin_assignments_crud_view.dart  # ❌ PENDIENTE migrar a ApiClient
│   │   ├── admin_courses_crud_view.dart      # ✅ MIGRADO a ApiClient
│   │   ├── admin_dashboard.dart              # ✅ MIGRADO a ApiClient
│   │   ├── admin_layout.dart                 # ✅ No usa HTTP directo (solo logout)
│   │   ├── admin_periods_crud_view.dart      # ❌ PENDIENTE migrar a ApiClient
│   │   ├── admin_sections_crud_view.dart     # ❌ PENDIENTE migrar a ApiClient
│   │   └── admin_users_crud_view.dart        # ✅ MIGRADO a ApiClient
│   ├── auth/
│   │   └── login_screen.dart                 # ✅ MIGRADO a ApiClient
│   ├── director/
│   │   └── director_dashboard.dart           # ✅ MIGRADO a ApiClient
│   ├── parent/
│   │   ├── parent_dashboard.dart             # ❌ PENDIENTE migrar a ApiClient
│   │   └── Parent_student_details_view.dart  # ❌ PENDIENTE migrar a ApiClient
│   ├── student/
│   │   ├── StudentCourseDetailsView.dart.dart # ❌ PENDIENTE migrar a ApiClient
│   │   ├── StudentTaskDetailView.dart         # ❌ PENDIENTE migrar a ApiClient
│   │   ├── student_dashboard.dart             # ✅ MIGRADO a ApiClient
│   │   └── student_session_materials_view.dart # ❌ PENDIENTE migrar a ApiClient
│   └── teacher/
│       ├── TeacherCourseDetailsView.dart      # ❌ PENDIENTE migrar a ApiClient
│       ├── TeacherSessionMaterialsView.dart   # ❌ PENDIENTE migrar a ApiClient
│       ├── TeacherSubmissionDetailView.dart    # ❌ PENDIENTE migrar a ApiClient
│       ├── TeacherTaskSubmissionsView.dart     # ❌ PENDIENTE migrar a ApiClient
│       └── teacher_dashboard.dart             # ✅ MIGRADO a ApiClient
├── router/
│   └── app_router.dart           # go_router - NO TOCAR
├── services/
│   ├── api_client.dart           # ✅ NUEVO - Cliente HTTP centralizado
│   └── api_service.dart          # ✅ Simplificado (solo getToken + logout)
└── main.dart                     # ✅ MIGRADO - carga .env con flutter_dotenv
```

---

## ARCHIVOS CLAVE YA CREADOS (NO MODIFICAR, SOLO USAR)

### 1. `.env` (raíz del proyecto)
```env
ACADEMIC_SERVICE_URL=https://academic-service-enfoenfoeduca-451053308845.us-central1.run.app
USERS_SERVICE_URL=https://users-service-enfoenfoeduca-451053308845.us-central1.run.app
AUTH_SERVICE_URL=https://auth-service-enfoenfoeduca-451053308845.europe-west1.run.app
SUPABASE_URL=https://vijngqyvewudkbqinvih.supabase.co
SUPABASE_ANON_KEY=sb_publishable_jXJH3J_gDFe1jdembzGI3A_CIe9dxrG
```

### 2. `lib/config/environment.dart`
```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Environment {
  static String get academicServiceUrl => dotenv.env['ACADEMIC_SERVICE_URL'] ?? '';
  static String get usersServiceUrl => dotenv.env['USERS_SERVICE_URL'] ?? '';
  static String get authServiceUrl => dotenv.env['AUTH_SERVICE_URL'] ?? '';
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
}
```

### 3. `lib/services/api_client.dart` (NUEVO - el cliente HTTP centralizado)
```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/environment.dart';
import 'api_service.dart';

enum ServiceType {
  academic,
  users,
  auth,
}

class ApiClient {
  static String _getBaseUrl(ServiceType type) {
    switch (type) {
      case ServiceType.academic:
        return Environment.academicServiceUrl;
      case ServiceType.users:
        return Environment.usersServiceUrl;
      case ServiceType.auth:
        return Environment.authServiceUrl;
    }
  }

  static Future<Map<String, String>> _getHeaders({bool requireAuth = true, Map<String, String>? extraHeaders}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ...?extraHeaders,
    };
    if (requireAuth) {
      final token = await ApiService.getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  static Future<http.Response> get(ServiceType service, String endpoint, {bool requireAuth = true}) async {
    final baseUrl = _getBaseUrl(service);
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders(requireAuth: requireAuth);
    return await http.get(url, headers: headers);
  }

  static Future<http.Response> post(ServiceType service, String endpoint, {dynamic body, bool requireAuth = true, Map<String, String>? extraHeaders}) async {
    final baseUrl = _getBaseUrl(service);
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders(requireAuth: requireAuth, extraHeaders: extraHeaders);
    return await http.post(url, headers: headers, body: body != null ? json.encode(body) : null);
  }

  static Future<http.Response> put(ServiceType service, String endpoint, {dynamic body, bool requireAuth = true}) async {
    final baseUrl = _getBaseUrl(service);
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders(requireAuth: requireAuth);
    return await http.put(url, headers: headers, body: body != null ? json.encode(body) : null);
  }

  static Future<http.Response> delete(ServiceType service, String endpoint, {bool requireAuth = true}) async {
    final baseUrl = _getBaseUrl(service);
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders(requireAuth: requireAuth);
    return await http.delete(url, headers: headers);
  }
}
```

### 4. `lib/services/api_service.dart` (simplificado - solo token y logout)
```dart
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
  }
}
```

### 5. `lib/api/api_constants.dart` (ya migrado a Environment)
```dart
import '../config/environment.dart';

class ApiConstants {
  static String get authServiceBaseUrl => Environment.authServiceUrl;
  static String get usersServiceBaseUrl => Environment.usersServiceUrl;
  static String get academicServiceBaseUrl => Environment.academicServiceUrl;

  // Auth
  static String get login => '$authServiceBaseUrl/auth/login';
  static String get register => '$authServiceBaseUrl/auth/register';

  // Users
  static String get users => '$usersServiceBaseUrl/users';
  static String get students => '$usersServiceBaseUrl/students';
  static String get teachers => '$usersServiceBaseUrl/teachers';
  static String get parents => '$usersServiceBaseUrl/parents';
  static String get directors => '$usersServiceBaseUrl/directors';

  // Academic
  static String get academicPeriods => '$academicServiceBaseUrl/period';
  static String get courses => '$academicServiceBaseUrl/courses';
  static String get sections => '$academicServiceBaseUrl/sections';
  static String get sessions => '$academicServiceBaseUrl/courses/sessions';
  static String get assignments => '$academicServiceBaseUrl/assignments';
  static String get attendances => '$academicServiceBaseUrl/attendances';
  static String get tasks => '$academicServiceBaseUrl/tasks';
  static String get materials => '$academicServiceBaseUrl/courses/materials';
  static String get taskSubmissions => '$academicServiceBaseUrl/tasks/submission';
}
```

---

## TAREA PENDIENTE: Migrar 11 archivos a ApiClient

### PATRÓN DE MIGRACIÓN (seguir exactamente)

En cada archivo pendiente debes hacer 3 cosas:

#### PASO 1: Reemplazar imports
**ANTES:**
```dart
import 'package:http/http.dart' as http;
import '../../services/api_service.dart';
```
**DESPUÉS:**
```dart
import '../../services/api_client.dart';
```
> NOTA: Solo eliminar `api_service.dart` si el archivo NO usa `ApiService.logout()` ni `ApiService.getToken()` directamente (para JWT decode).
> Solo eliminar `http` import si el archivo ya NO tiene ningún uso directo de `http.get/post/put/delete`.
> El import de `api_constants.dart` puede quedarse si el archivo usa `ApiConstants.xxxBaseUrl` dentro de interpolaciones de string.

#### PASO 2: Eliminar bloques de headers manuales
**ANTES:**
```dart
final String? token = await ApiService.getToken();
final Map<String, String> headers = {
  'Authorization': 'Bearer $token',
  'Content-Type': 'application/json',
};
```
**DESPUÉS:** Eliminar completamente. ApiClient inyecta automáticamente el token.

#### PASO 3: Reemplazar llamadas HTTP
**ANTES (GET):**
```dart
final response = await http.get(
  Uri.parse('${ApiConstants.academicServiceBaseUrl}/courses/'),
  headers: headers,
);
```
**DESPUÉS:**
```dart
final response = await ApiClient.get(ServiceType.academic, '/courses/');
```

**ANTES (POST):**
```dart
final response = await http.post(
  Uri.parse('${ApiConstants.usersServiceBaseUrl}/students/create'),
  headers: headers,
  body: json.encode(bodyData),
);
```
**DESPUÉS:**
```dart
final response = await ApiClient.post(ServiceType.users, '/students/create', body: bodyData);
```

**ANTES (PUT):**
```dart
final response = await http.put(
  Uri.parse('${ApiConstants.academicServiceBaseUrl}/courses/$id'),
  headers: headers,
  body: json.encode(bodyData),
);
```
**DESPUÉS:**
```dart
final response = await ApiClient.put(ServiceType.academic, '/courses/$id', body: bodyData);
```

**ANTES (DELETE):**
```dart
final response = await http.delete(
  Uri.parse('${ApiConstants.academicServiceBaseUrl}/courses/$id'),
  headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
);
```
**DESPUÉS:**
```dart
final response = await ApiClient.delete(ServiceType.academic, '/courses/$id');
```

**Para auth (login/registro sin token):**
```dart
final response = await ApiClient.post(
  ServiceType.auth,
  '/auth/login',
  body: {'email': email, 'password': password},
  requireAuth: false,  // <-- IMPORTANTE: no inyectar Bearer token
);
```

### MAPEO DE URLs A ServiceType:
| URL Base contiene | ServiceType |
|---|---|
| `academicServiceBaseUrl` o `/courses/`, `/sessions/`, `/tasks/`, `/assignments/`, `/attendances/`, `/sections/`, `/period/`, `/submissions/` | `ServiceType.academic` |
| `usersServiceBaseUrl` o `/students/`, `/teachers/`, `/parents/`, `/directors/` | `ServiceType.users` |
| `authServiceBaseUrl` o `/auth/` | `ServiceType.auth` |

---

## ARCHIVOS PENDIENTES DE MIGRAR (11 archivos)

### Archivos Admin:
1. `lib/pages/admin/admin_assignments_crud_view.dart` - CRUD de asignaciones
2. `lib/pages/admin/admin_periods_crud_view.dart` - CRUD de periodos académicos
3. `lib/pages/admin/admin_sections_crud_view.dart` - CRUD de secciones

### Archivos Parent:
4. `lib/pages/parent/parent_dashboard.dart` - Dashboard padre de familia
5. `lib/pages/parent/Parent_student_details_view.dart` - Detalles del hijo

### Archivos Student:
6. `lib/pages/student/StudentCourseDetailsView.dart.dart` - Detalles del curso
7. `lib/pages/student/StudentTaskDetailView.dart` - Detalle de tarea (tiene upload con Supabase Storage)
8. `lib/pages/student/student_session_materials_view.dart` - Materiales de sesión

### Archivos Teacher:
9. `lib/pages/teacher/TeacherCourseDetailsView.dart` - Detalles del curso profesor
10. `lib/pages/teacher/TeacherSessionMaterialsView.dart` - Materiales y tareas de sesión (el más complejo)
11. `lib/pages/teacher/TeacherSubmissionDetailView.dart` - Detalle de entrega
12. `lib/pages/teacher/TeacherTaskSubmissionsView.dart` - Lista de entregas de tarea

---

## LIMPIEZA POST-MIGRACIÓN

Una vez todos los archivos estén migrados:

1. **Eliminar imports innecesarios**: En CADA archivo migrado, si ya no se usa `http.get/post/put/delete` directamente, eliminar `import 'package:http/http.dart' as http;`.
2. **Eliminar ApiService import**: Si el archivo solo usaba `ApiService.getToken()` para construir headers manualmente y ya no lo hace, eliminar `import '../../services/api_service.dart';`.
3. **Conservar ApiService import**: Si el archivo usa `ApiService.logout()` o `ApiService.getToken()` para decodificar JWT con `JwtDecoder`, MANTENER el import.
4. **Evaluar si `api_constants.dart` puede eliminarse**: Si después de la migración ningún archivo usa `ApiConstants.xxxBaseUrl` en interpolaciones de string (ya que ApiClient maneja las URLs internamente), el archivo `api_constants.dart` podría eliminarse. Pero verificar primero que NINGÚN archivo lo referencia.
5. **Eliminar `refactor_urls.py` y `check_status.py`** de la raíz del proyecto (scripts temporales).
6. **Ejecutar `flutter analyze`** y confirmar 0 errores.

---

## REGLAS CRÍTICAS

1. **NO cambiar lógica de negocio**. Solo reemplazar la forma en que se hacen las peticiones HTTP.
2. **NO renombrar archivos**. Los nombres raros (como `StudentCourseDetailsView.dart.dart`) son intencionales para no romper imports.
3. **Verificar `response.statusCode`** - La lógica de manejo de respuestas (if statusCode == 200, etc.) debe permanecer IDÉNTICA.
4. **`json.decode(response.body)`** - ApiClient retorna `http.Response` crudo, el decode se sigue haciendo en la vista.
5. **Archivos con `JwtDecoder`** necesitan mantener el import de `ApiService` para `getToken()` y el import de `jwt_decoder`.
6. **El archivo `admin_users_crud_view.dart`** tiene flujo OAuth con Supabase - ya fue migrado, no tocar.
7. **`TeacherSessionMaterialsView.dart`** es el archivo más complejo - tiene upload de materiales via Supabase Storage, crear tareas, crear asistencias. Migrar con cuidado.
8. **`StudentTaskDetailView.dart`** tiene upload de archivos via Supabase Storage para entregas. Migrar con cuidado.

---

## DEPENDENCIAS DEL PROYECTO (pubspec.yaml)
- flutter, flutter_web_plugins, flutter_localizations
- go_router: ^17.2.3
- http: ^1.6.0
- shared_preferences: ^2.5.5
- jwt_decoder: ^2.0.1
- supabase_flutter: ^2.12.4
- url_launcher: ^6.3.2
- fl_chart: ^1.2.0
- firebase_core: ^2.30.0 (legacy, no se usa activamente)
- flutter_svg: ^2.3.0
- file_picker: ^8.0.0
- cupertino_icons: ^1.0.8
- flutter_dotenv: ^6.0.1 (NUEVO)
- path: ^1.9.0

---

## FASE 3 (FUTURA - AÚN NO INICIADA)
Después de completar la migración a ApiClient, la Fase 3 consistiría en:
- Identificar widgets UI repetidos entre roles (AppBars, Cards, empty states, loading indicators)
- Crear componentes compartidos en `lib/components/`
- Unificar patrones de `FutureBuilder` con estados de carga/error/vacío
- Evaluar si `ApiConstants` puede absorberse en `ApiClient` y eliminarse
