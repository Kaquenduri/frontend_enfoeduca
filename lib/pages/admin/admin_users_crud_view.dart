import 'dart:convert';
import 'dart:async'; // Necesario para el manejo del StreamSubscription
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminUsersCrudView extends StatefulWidget {
  const AdminUsersCrudView({super.key});

  @override
  State<AdminUsersCrudView> createState() => _AdminUsersCrudViewState();
}

class _AdminUsersCrudViewState extends State<AdminUsersCrudView> {
  final _formKey = GlobalKey<FormState>();

  // Controladores Base Obligatorios
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Controladores Específicos
  final TextEditingController _specialityController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _occupationController = TextEditingController();

  // IDs seleccionados para el caso de Student
  String? _selectedParentId;
  String? _selectedSectionId;

  // Variables de Estado y Listados
  String _selectedRole = 'STUDENT';
  List<dynamic> _allUsersCombinedList = [];
  List<dynamic> _parentsList = [];
  List<dynamic> _sectionsList = [];
  bool _isLoading = true;

  // Flag de control para el flujo asistido de Google
  bool _isAuthViaGoogle = false;

  // Suscripción para escuchar de manera reactiva el retorno de Google en entornos Web
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _fetchUsersAndDependencies();
    _setupWebAuthListener(); // <--- ESCUCHADOR CLAVE PARA EVITAR ERRORES EN WEB
  }

  @override
  void dispose() {
    _authSubscription
        ?.cancel(); // Cancelamos la escucha para evitar fugas de memoria
    _nameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _specialityController.dispose();
    _phoneController.dispose();
    _occupationController.dispose();
    super.dispose();
  }

  // SOLUCIÓN PARA WEB: Captura reactivamente los datos de Google y divide inteligentemente Nombres y Apellidos
  void _setupWebAuthListener() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      final Session? session = data.session;
      final User? user = session?.user;

      if (user != null && user.email != null && _isAuthViaGoogle) {
        final meta = user.userMetadata;

        // 1. Extraemos lo que Google nos dé por defecto
        String rawName = meta?['given_name'] ?? '';
        String rawLastName = meta?['family_name'] ?? '';
        final String fullName = meta?['full_name'] ?? '';

        // 2. ALGORITMO DE SEGMENTACIÓN: Si los apellidos vienen vacíos o todo se concentró en nombres
        if (rawLastName.isEmpty &&
            (rawName.isNotEmpty || fullName.isNotEmpty)) {
          // Usamos el nombre completo disponible
          final String totalString = rawName.contains(' ') ? rawName : fullName;

          // Limpiamos espacios dobles por si acaso y separamos por palabras
          final List<String> words = totalString
              .trim()
              .replaceAll(RegExp(r'\s+'), ' ')
              .split(' ');

          if (words.length >= 4) {
            // Ejemplo típico: "Marco Jesus Chunga Malque"
            // Nombres = "Marco Jesus" | Apellidos = "Chunga Malque"
            rawName = "${words[0]} ${words[1]}";
            rawLastName = words.sublist(2).join(' ');
          } else if (words.length == 3) {
            // Ejemplo: "Juan Carlos Pérez"
            // Nombres = "Juan Carlos" | Apellidos = "Pérez"
            rawName = "${words[0]} ${words[1]}";
            rawLastName = words[2];
          } else if (words.length == 2) {
            // Ejemplo: "Carlos Pérez"
            // Nombres = "Carlos" | Apellidos = "Pérez"
            rawName = words[0];
            rawLastName = words[1];
          } else if (words.isNotEmpty) {
            rawName = words[0];
            rawLastName = '';
          }
        }

        // 3. Inyectamos los textos limpios en sus respectivos controladores
        setState(() {
          _nameController.text = rawName.trim();
          _lastNameController.text = rawLastName.trim();
          _emailController.text = user.email!;
          _passwordController.text =
              "OAUTH_EXTERNAL_GOOGLE_ACCOUNT_PROVISIONED";
          _isLoading = false;
        });

        _showSnackBar(
          '¡Cuenta de Google enlazada y datos distribuidos con éxito!',
          Colors.green,
        );
      }
    });
  }

  // Descarga concurrente de usuarios por rol + dependencias académicas
  Future<void> _fetchUsersAndDependencies() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final String? token = await ApiService.getToken();
      final Map<String, String> headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

      final responses = await Future.wait([
        http.get(
          Uri.parse(
            'https://users-service-enfoenfoeduca-451053308845.us-central1.run.app/students/',
          ),
          headers: headers,
        ),
        http.get(
          Uri.parse(
            'https://users-service-enfoenfoeduca-451053308845.us-central1.run.app/teachers/',
          ),
          headers: headers,
        ),
        http.get(
          Uri.parse(
            'https://users-service-enfoenfoeduca-451053308845.us-central1.run.app/parents/',
          ),
          headers: headers,
        ),
        http.get(
          Uri.parse(
            'https://academic-service-enfoenfoeduca-451053308845.us-central1.run.app/sections/',
          ),
          headers: headers,
        ),
      ]);

      if (responses.any((res) => res.statusCode != 200)) {
        throw Exception('Uno o más servicios no respondieron correctamente');
      }

      final List<dynamic> students = json.decode(responses[0].body);
      final List<dynamic> teachers = json.decode(responses[1].body);
      final List<dynamic> parents = json.decode(responses[2].body);
      final List<dynamic> sections = json.decode(responses[3].body);

      List<Map<String, dynamic>> combined = [];
      for (var s in students) {
        combined.add({
          'id': s['student_id'],
          'name': s['user_id']?['name'] ?? 'Sin Nombre',
          'last_name': s['user_id']?['last_name'] ?? '',
          'email': s['user_id']?['email'] ?? '',
          'role': 'ESTUDIANTE',
          'color': Colors.blue,
          'icon': Icons.school_rounded,
        });
      }
      for (var t in teachers) {
        combined.add({
          'id': t['teacher_id'],
          'name': t['user_id']?['name'] ?? 'Sin Nombre',
          'last_name': t['user_id']?['last_name'] ?? '',
          'email': t['user_id']?['email'] ?? '',
          'role': 'DOCENTE',
          'color': Colors.green,
          'icon': Icons.assignment_ind_rounded,
        });
      }
      for (var p in parents) {
        combined.add({
          'id': p['parent_id'],
          'name': p['user_id']?['name'] ?? 'Sin Nombre',
          'last_name': p['user_id']?['last_name'] ?? '',
          'email': p['user_id']?['email'] ?? '',
          'role': 'PADRE',
          'color': Colors.purple,
          'icon': Icons.people_alt_rounded,
        });
      }

      if (!mounted) return;
      setState(() {
        _allUsersCombinedList = combined;
        _parentsList = parents;
        _sectionsList = sections;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar(
        'Error de sincronización con microservicios de usuarios: $e',
        Colors.red,
      );
    }
  }

  // 2. Reemplaza tu función con esta versión limpia y universal:
  Future<void> _captureDataFromGoogle() async {
    setState(() {
      _isAuthViaGoogle = true;
      _isLoading = true;
    });

    try {
      final String currentUri = Uri.base.toString();

      // Le pedimos a Supabase que nos devuelva la URL de autenticación armada
      final res = await Supabase.instance.client.auth.getOAuthSignInUrl(
        provider: OAuthProvider.google,
        redirectTo: currentUri,
        queryParams: {
          'prompt':
              'select_account', // Obliga a Google a mostrar el selector siempre
        },
      );

      final String authUrl = res.url;

      final Uri urlToLaunch = Uri.parse(authUrl);

      // Lanzamos la URL en la misma pestaña activa del navegador actual
      await launchUrl(
        urlToLaunch,
        mode: LaunchMode
            .inAppWebView, // <--- Esto evita los popups congelados y usa la misma pestaña
      );
    } catch (e) {
      setState(() {
        _isAuthViaGoogle = false;
        _isLoading = false;
      });
      _showSnackBar('No se pudo abrir el inicio de sesión: $e', Colors.red);
    }
  }

  // Guardar usuario consumiendo la API correspondiente a su rol
  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) return;
    final String? token = await ApiService.getToken();
    final Map<String, String> headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
    final Map<String, dynamic> basePayload = {
      "name": _nameController.text.trim(),
      "last_name": _lastNameController.text.trim(),
      "email": _emailController.text.trim(),
      "password": _passwordController.text.trim(),
    };
    String targetUrl = '';

    if (_selectedRole == 'TEACHER') {
      targetUrl =
          'https://users-service-enfoenfoeduca-451053308845.us-central1.run.app/teachers/create';
      basePayload['speciality'] = _specialityController.text.trim();
    } else if (_selectedRole == 'PARENT') {
      targetUrl =
          'https://users-service-enfoenfoeduca-451053308845.us-central1.run.app/parents/create';
      basePayload['phone'] = _phoneController.text.trim();
      basePayload['occupation'] = _occupationController.text.trim();
    } else {
      targetUrl =
          'https://users-service-enfoenfoeduca-451053308845.us-central1.run.app/students/create';
      basePayload['parent_id'] = _selectedParentId;
      basePayload['id_section'] = _selectedSectionId;
    }

    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse(targetUrl),
        headers: headers,
        body: json.encode(basePayload),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSnackBar(
          'Usuario registrado con éxito en el sistema.',
          Colors.green,
        );
        _clearForm();
        _fetchUsersAndDependencies();
      } else {
        final Map<String, dynamic> errBody = json.decode(response.body);
        throw Exception(
          errBody['message'] ?? 'Error de servidor (${response.statusCode})',
        );
      }
    } catch (e) {
      setState(
        () => _isLoading = false,
      ); // Corregido de true a false para que la UI no se quede bloqueada
      _showSnackBar('No se pudo crear el usuario: $e', Colors.red);
    }
  }

  // Eliminar un usuario de forma genérica
  Future<void> _deleteUser(String id, String roleLabel) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Eliminar Cuenta',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          '¿Está seguro de remover permanentemente a este usuario ($roleLabel) del sistema institucional?',
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
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    String deletePath = '';
    if (roleLabel == 'ESTUDIANTE') deletePath = 'students';
    if (roleLabel == 'DOCENTE') deletePath = 'teachers';
    if (roleLabel == 'PADRE') deletePath = 'parents';

    setState(() => _isLoading = true);
    try {
      final String? token = await ApiService.getToken();
      final response = await http.delete(
        Uri.parse(
          'https://users-service-enfoenfoeduca-451053308845.us-central1.run.app/$deletePath/$id',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        _showSnackBar('Usuario eliminado satisfactoriamente.', Colors.orange);
        _fetchUsersAndDependencies();
      } else {
        throw Exception(
          'Error del microservicio. Código: ${response.statusCode}',
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error al suprimir: $e', Colors.red);
    }
  }

  void _clearForm() {
    _nameController.clear();
    _lastNameController.clear();
    _emailController.clear();
    _passwordController.clear();
    _specialityController.clear();
    _phoneController.clear();
    _occupationController.clear();
    setState(() {
      _selectedParentId = null;
      _selectedSectionId = null;
      _isAuthViaGoogle = false;
    });
    _formKey.currentState?.reset();
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Consola de Control de Usuarios Corporativos',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded, color: Colors.blueGrey),
            onPressed: _fetchUsersAndDependencies,
            tooltip: 'Sincronizar Todo',
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0F172A)),
            )
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 900) {
                    return Column(
                      children: [
                        _buildDynamicFormCard(),
                        const SizedBox(height: 24),
                        Expanded(child: _buildUsersListCard()),
                      ],
                    );
                  } else {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 4, child: _buildDynamicFormCard()),
                        const SizedBox(width: 24),
                        Expanded(flex: 5, child: _buildUsersListCard()),
                      ],
                    );
                  }
                },
              ),
            ),
    );
  }

  Widget _buildDynamicFormCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Registrar Nuevo Usuario del Sistema',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _captureDataFromGoogle,
                  icon: Image.network(
                    'https://authjs.dev/img/providers/google.svg',
                    height: 18,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.g_mobiledata_rounded,
                      color: Colors.red,
                    ),
                  ),
                  label: Text(
                    _isAuthViaGoogle
                        ? 'Procesando Enlace de Google...'
                        : 'Vincular y Autocompletar con Google',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _isAuthViaGoogle ? Colors.orange : Colors.black87,
                      fontSize: 13,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(
                      color: _isAuthViaGoogle
                          ? Colors.orange
                          : Colors.grey.shade300,
                      width: 1.5,
                    ),
                    backgroundColor: _isAuthViaGoogle
                        ? Colors.orange.shade50
                        : Colors.transparent,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              if (_isAuthViaGoogle) ...[
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.orange,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Modo Google Inicializado: Si ya seleccionaste la cuenta, los datos se auto-rellenarán a continuación.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],

              DropdownButtonFormField<String>(
                initialValue: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Seleccione el Perfil / Rol institucional *',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'STUDENT',
                    child: Text('Estudiante (Alumno)'),
                  ),
                  DropdownMenuItem(
                    value: 'TEACHER',
                    child: Text('Profesor (Docente)'),
                  ),
                  DropdownMenuItem(
                    value: 'PARENT',
                    child: Text('Padre de Familia'),
                  ),
                ],
                onChanged: (role) {
                  if (role != null) {
                    setState(() {
                      _selectedRole = role;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),

              TextFormField(
                controller: _nameController,
                readOnly: _isAuthViaGoogle,
                decoration: InputDecoration(
                  labelText: 'Nombres *',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  fillColor: _isAuthViaGoogle
                      ? Colors.grey.shade100
                      : Colors.transparent,
                  filled: _isAuthViaGoogle,
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Ingrese los nombres'
                    : null,
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _lastNameController,
                readOnly: _isAuthViaGoogle,
                decoration: InputDecoration(
                  labelText: 'Apellidos *',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  fillColor: _isAuthViaGoogle
                      ? Colors.grey.shade100
                      : Colors.transparent,
                  filled: _isAuthViaGoogle,
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Ingrese los apellidos'
                    : null,
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                readOnly: _isAuthViaGoogle,
                decoration: InputDecoration(
                  labelText: 'Correo Electrónico (Email) *',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  fillColor: _isAuthViaGoogle
                      ? Colors.grey.shade100
                      : Colors.transparent,
                  filled: _isAuthViaGoogle,
                ),
                validator: (val) => val == null || !val.contains('@')
                    ? 'Correo institucional inválido'
                    : null,
              ),
              const SizedBox(height: 14),

              if (!_isAuthViaGoogle) ...[
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña de Acceso *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (val) => val == null || val.length < 6
                      ? 'Mínimo 6 caracteres requeridos'
                      : null,
                ),
                const SizedBox(height: 14),
              ],

              if (_selectedRole == 'TEACHER') ...[
                TextFormField(
                  controller: _specialityController,
                  decoration: const InputDecoration(
                    labelText: 'Especialidad del Docente *',
                    hintText: 'Ej: Ciencias, Matemáticas',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Especifique la especialidad'
                      : null,
                ),
              ],

              if (_selectedRole == 'PARENT') ...[
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono de Contacto *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Ingrese un número telefónico'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _occupationController,
                  decoration: const InputDecoration(
                    labelText: 'Ocupación o Profesión *',
                    hintText: 'Ej: Ingeniero, Comerciante',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Escriba la ocupación'
                      : null,
                ),
              ],

              if (_selectedRole == 'STUDENT') ...[
                DropdownButtonFormField<String>(
                  initialValue: _selectedParentId,
                  decoration: const InputDecoration(
                    labelText: 'Vincular Apoderado / Padre *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: _parentsList.map((p) {
                    final String id = p['parent_id'] ?? '';
                    final String name = p['user_id']?['name'] ?? 'Padre';
                    final String lastName = p['user_id']?['last_name'] ?? '';
                    return DropdownMenuItem(
                      value: id,
                      child: Text(
                        '$name $lastName',
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  }).toList(),
                  validator: (val) =>
                      val == null ? 'Seleccione un apoderado' : null,
                  onChanged: (val) => setState(() => _selectedParentId = val),
                ),
                const SizedBox(height: 14),

                DropdownButtonFormField<String>(
                  initialValue: _selectedSectionId,
                  decoration: const InputDecoration(
                    labelText: 'Asignar Sección del Alumno *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: _sectionsList.map((sec) {
                    final String id = sec['id_section'] ?? '';
                    final String name = sec['name'] ?? '';
                    final String grade = sec['grade'] ?? '';
                    return DropdownMenuItem(
                      value: id,
                      child: Text(
                        '$grade "$name"',
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  }).toList(),
                  validator: (val) =>
                      val == null ? 'Seleccione una sección académica' : null,
                  onChanged: (val) => setState(() => _selectedSectionId = val),
                ),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _createUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text(
                    'Dar de Alta Usuario',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUsersListCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Usuarios Registrados en el LMS',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _allUsersCombinedList.isEmpty
                ? const Center(
                    child: Text(
                      'No hay cuentas registradas en las bases de datos.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    itemCount: _allUsersCombinedList.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: Colors.grey.shade100),
                    itemBuilder: (context, index) {
                      final user = _allUsersCombinedList[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: CircleAvatar(
                          backgroundColor: user['color'].withOpacity(0.1),
                          radius: 16,
                          child: Icon(
                            user['icon'],
                            color: user['color'],
                            size: 16,
                          ),
                        ),
                        title: Text(
                          '${user['name']} ${user['last_name']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          '${user['email']} • ${user['role']}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.redAccent,
                            size: 18,
                          ),
                          onPressed: () =>
                              _deleteUser(user['id'], user['role']),
                          tooltip: 'Remover Usuario',
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
