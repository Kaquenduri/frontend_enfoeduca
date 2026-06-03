import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'router/app_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

Future<void> main() async {
  usePathUrlStrategy();
  await Supabase.initialize(
    url: 'https://vijngqyvewudkbqinvih.supabase.co',
    anonKey: 'sb_publishable_jXJH3J_gDFe1jdembzGI3A_CIe9dxrG',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'LMS EduPlatform',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      routerConfig: appRouter,

      // ====================================================================
      // CONFIGURACIÓN DE TRADUCCIONES (Soluciona el error del showDatePicker)
      // ====================================================================
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'), // Configura el español como idioma soportado
        Locale('en', 'US'), // Inglés por defecto de respaldo
      ],
      // ====================================================================
    );
  }
}
