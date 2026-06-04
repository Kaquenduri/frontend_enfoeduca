// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:async'; // Para manejar el StreamSubscription del Listener de Google
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // <--- IMPORTACIÓN DE SUPABASE
import 'package:url_launcher/url_launcher.dart'; // <--- IMPORTACIÓN PARA REDIRECCIÓN EN WEB
import '../../api/api_constants.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  // Suscripción asíncrona para capturar el retorno de Google OAuth
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _setupGoogleAuthListener(); // <--- Inicializa el escuchador de Google apenas abre la pantalla
  }

  @override
  void dispose() {
    _authSubscription
        ?.cancel(); // Cancelamos la escucha para evitar fugas de memoria
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _setupGoogleAuthListener() {
    print("📢 [LMS LOG] Escuchador de Supabase inicializado correctamente.");

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) async {
      print(
        "📢 [LMS LOG] ¡Se detectó un cambio de estado en Supabase Auth! Evento: ${data.event}",
      );

      // 🌟 BUSQUEDA EXHAUSTIVA DEL SESSION Y TOKEN
      final Session? session =
          data.session ?? Supabase.instance.client.auth.currentSession;
      final User? user =
          session?.user ?? Supabase.instance.client.auth.currentUser;

      if (session == null) {
        print("⚠️ [LMS LOG] Volviste de Google pero la sesión viene NULA.");
        return;
      }

      // 🌟 Probamos todas las rutas posibles para recuperar el token de autenticación
      String? googleIdToken = session.providerToken;

      // Si por alguna razón el token de Google no viene, usamos el token de Supabase como respaldo
      if (googleIdToken == null || googleIdToken.isEmpty) {
        googleIdToken = session.accessToken;
      }

      if (googleIdToken.isEmpty) {
        // Opción de respaldo 1: Buscamos en las identidades guardadas del usuario
        try {
          googleIdToken =
              user?.identities
                      ?.firstWhere((identity) => identity.provider == 'google')
                      .identityData?['id_token']
                  as String?;
        } catch (_) {}
      }

      if (googleIdToken == null || googleIdToken.isEmpty) {
        // Opción de respaldo 2: Tomamos el accessToken de la sesión de Supabase
        googleIdToken = session.accessToken;
      }

      print(
        "📢 [LMS LOG] Token obtenido de Google: ${'SÍ TIENE TOKEN'}",
      );
      print("📢 [LMS LOG] Usuario obtenido de Google: ${user?.email}");

      if (user != null && googleIdToken.isNotEmpty) {
        print("🚀 [LMS LOG] Entrando al bloque de envío hacia el Backend...");
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });

        try {
          const String googleLoginUrl =
              'https://auth-service-enfoenfoeduca-451053308845.europe-west1.run.app/auth/google-login';
          print("🌐 [LMS LOG] Enviando petición POST a: $googleLoginUrl");

          final response = await http.post(
            Uri.parse(googleLoginUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'id_token': googleIdToken}),
          );

          print(
            "📦 [LMS LOG] Respuesta del Backend recibida. Código de estado: ${response.statusCode}",
          );
          print("📦 [LMS LOG] Cuerpo de respuesta: ${response.body}");

          if (response.statusCode == 200) {
            final responseData = jsonDecode(response.body);
            final token = responseData['token'];
            print(
              "🔑 [LMS LOG] ¡Token institucional obtenido con éxito! Redirigiendo...",
            );

            await Supabase.instance.client.auth.signOut();
            await _processAndNavigateWithToken(token);
          } else {
            await Supabase.instance.client.auth.signOut();
            final errorData = jsonDecode(response.body);
            setState(() {
              _errorMessage =
                  errorData['message'] ?? 'Tu cuenta no está registrada.';
            });
          }
        } catch (e) {
          print("❌ [LMS LOG] Error atrapado en el catch del envío: $e");
          setState(() {
            _errorMessage = 'Error de conexión: $e';
          });
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      } else {
        print("❌ [LMS LOG] No se cumplió la condición (User o Token nulos).");
      }
    });
  }

  /// 🚀 LOGICA COMPARTIDA: Procesa el Token JWT, guarda localmente y redirige según el Rol
  Future<void> _processAndNavigateWithToken(String token) async {
    // Guardar el token de manera local en SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);

    // Decodificar el token para obtener el rol del usuario
    Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
    List<dynamic> roles = decodedToken['roles'] ?? [];

    if (roles.isEmpty) {
      setState(() {
        _errorMessage = 'El usuario no tiene roles asignados.';
      });
      return;
    }

    // Navegar dependiendo del primer rol del usuario
    final role = roles.first.toString().toUpperCase();
    if (!mounted) return;

    switch (role) {
      case 'ADMIN':
        context.go('/admin');
        break;
      case 'TEACHER':
        context.go('/teacher');
        break;
      case 'STUDENT':
        context.go('/student');
        break;
      case 'PARENT':
        context.go('/parent');
        break;
      case 'DIRECTOR':
        context.go('/director');
        break;
      default:
        setState(() {
          _errorMessage = 'Rol desconocido: $role';
        });
    }
  }

  /// 🔐 INICIO DE SESIÓN CLÁSICO: Correo y contraseña manual
  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.login),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];
        await _processAndNavigateWithToken(token);
      } else {
        final errorData = jsonDecode(response.body);
        setState(() {
          _errorMessage = errorData['message'] ?? 'Error desconocido';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error de red o servidor no disponible. $e';
        debugPrint(e.toString());
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 🌐 DISPARADOR OAUTH: Redirige la pestaña actual de la web hacia el Login de Google
  Future<void> _loginWithGoogle() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      final String currentUri = Uri.base.toString();

      // Solicitamos a Supabase construir la pasarela interactiva de Google
      final res = await Supabase.instance.client.auth.getOAuthSignInUrl(
        provider: OAuthProvider.google,
        redirectTo: currentUri,
        queryParams: {
          'prompt':
              'select_account', // Fuerza a Google a mostrar el selector de cuentas
        },
      );

      final String authUrl = res.url;

      // Ejecutamos la redirección forzando la misma pestaña del navegador activo
      await launchUrl(Uri.parse(authUrl), mode: LaunchMode.inAppWebView);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error al abrir pasarela de Google: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Un fondo gris claro moderno
      appBar: AppBar(title: const Text('Login LMS')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 450,
            ), // Hace que el diseño web central no se estire feo
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Inicio de Sesión',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),

                if (_errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Correo Electrónico',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(
                        0xFF0F172A,
                      ), // Botón negro moderno
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading && _emailController.text.isNotEmpty
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Iniciar Sesión',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'O TAMBIÉN',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                  ],
                ),
                const SizedBox(height: 24),

                // Botón de Google listo para producción
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _loginWithGoogle,
                    icon: SvgPicture.network(
                      'https://authjs.dev/img/providers/google.svg',
                      height: 18,
                    ),
                    label: const Text(
                      'Iniciar Sesión con Google',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
