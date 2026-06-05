// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:async'; // Para manejar el StreamSubscription del Listener de Google
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/api_client.dart'; // <--- IMPORTACIÓN DE SUPABASE
import 'package:url_launcher/url_launcher.dart'; // <--- IMPORTACIÓN PARA REDIRECCIÓN EN WEB
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

      print("📢 [LMS LOG] Token obtenido de Google: ${'SÍ TIENE TOKEN'}");
      print("📢 [LMS LOG] Usuario obtenido de Google: ${user?.email}");

      if (user != null && googleIdToken.isNotEmpty) {
        print("🚀 [LMS LOG] Entrando al bloque de envío hacia el Backend...");
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });

        try {
          print("🌐 [LMS LOG] Enviando petición POST a: /auth/google-login");

          final response = await ApiClient.post(
            ServiceType.auth,
            '/auth/google-login',
            body: {'id_token': googleIdToken},
            requireAuth: false,
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
      final response = await ApiClient.post(
        ServiceType.auth,
        '/auth/login',
        body: {
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
        },
        requireAuth: false,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];
        await _processAndNavigateWithToken(token);
      } else {
        final errorData = jsonDecode(response.body);
        setState(() {
          _errorMessage = errorData['error'] ?? 'Error desconocido';
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

      // Ejecutamos la redirección forzando la misma pestaña del navegador activo (sin abrir nuevas pestañas)
      await launchUrl(
        Uri.parse(authUrl),
        webOnlyWindowName:
            '_self', // <--- ESTO FUERZA A USAR LA MISMA PESTAÑA EN WEB
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error al abrir pasarela de Google: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 800;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          // Lado Izquierdo (Imagen/Gradiente) - Solo visible en pantallas grandes
          if (isDesktop)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6727E8), Color(0xFF5153E8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  // Aquí puedes colocar tu imagen en un futuro.
                  // Asegúrate de tenerla en esa ruta y registrada en pubspec.yaml
                  image: DecorationImage(
                    image: const AssetImage('assets/images/login_hero.jpg'),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                      Colors.black.withOpacity(0.3), // Un ligero filtro oscuro
                      BlendMode.darken,
                    ),
                    onError: (exception, stackTrace) {
                      // Si la imagen aún no existe, fallará silenciosamente mostrando solo el gradiente.
                    },
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(48.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.school, size: 64, color: Colors.white),
                      const SizedBox(height: 24),
                      const Text(
                        'EnfoEduca',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Plataforma integral para transformar el futuro de la educación.\nGestiona, aprende y crece.',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w400,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Lado Derecho (Formulario)
          SizedBox(
            width: isDesktop ? 500 : size.width,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 40,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch, // Alinea al ancho
                  children: [
                    if (!isDesktop) ...[
                      const Center(
                        child: Text(
                          'EnfoEduca',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF6727E8),
                            letterSpacing: -1.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],

                    Text(
                      'Bienvenido de nuevo',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ingresa tus credenciales para acceder a tu cuenta.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 40),

                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red.shade400,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    Text(
                      'Correo Electrónico',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        hintText: 'ejemplo@enfoeduca.com',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        prefixIcon: const Icon(
                          Icons.email_outlined,
                          color: Color(0xFF6727E8),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF6727E8),
                            width: 2,
                          ),
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Contraseña',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        hintText: '••••••••',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: Color(0xFF6727E8),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF6727E8),
                            width: 2,
                          ),
                        ),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 32),

                    Container(
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6727E8), Color(0xFF5153E8)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF6727E8,
                            ).withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading && _emailController.text.isNotEmpty
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Iniciar Sesión',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey.shade200)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'O continuar con',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.grey.shade200)),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Botón de Google moderno
                    SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _loginWithGoogle,
                        icon: SvgPicture.network(
                          'https://authjs.dev/img/providers/google.svg',
                          height: 20,
                        ),
                        label: const Text(
                          'Google',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                            fontSize: 15,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
