import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/inicio_screen.dart';
import 'screens/admin/promociones_screen.dart';
import 'screens/clinica_editor/editor_screen.dart';
import 'screens/clinica_editor/preview_screen.dart';
import 'route_observer.dart';
import 'services/pago_servicios.dart';
import 'screens/pagos/solicitar_pago_screen.dart';
import 'screens/admin/pagos_admin_screen.dart';
import 'services/auth_servicios.dart';
import 'firebase_options.dart';
import 'services/local_db.dart';
import 'services/connectivity_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize local DB (Hive)
  try {
    await LocalDb.init();
  } catch (e) {
    debugPrint('Error inicializando LocalDb: $e');
  }
  // Start connectivity listener so UI can react to online/offline changes
  try {
    await ConnectivityService.init();
  } catch (e) {
    debugPrint('Error inicializando ConnectivityService: $e');
  }
  final shouldInitFirebase =
      !kIsWeb && defaultTargetPlatform != TargetPlatform.windows;

  if (shouldInitFirebase) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      debugPrint('Error inicializando Firebase en main(): $e');
    }
  } else {
    debugPrint('Firebase inicialización omitida en esta plataforma');
  }

  runApp(const ClinicaApp());
}

class ClinicaApp extends StatelessWidget {
  const ClinicaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SaludAndina',
      theme: ThemeData.dark().copyWith(
        colorScheme: ThemeData.dark().colorScheme.copyWith(
              primary: const Color(0xFF0B2B3A), // deep navy primary
              onPrimary: Colors.white,
              secondary: const Color(0xFF06B6D4), // teal accent
              surface: const Color(0xFF0E2A37),
              onSurface: Colors.white,
            ),
        scaffoldBackgroundColor:
            const Color(0xFF071620), // deep navy background
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0B2B3A),
          foregroundColor: Colors.white,
          elevation: 1,
        ),
        cardTheme: CardTheme(
          color: const Color(0xFF0E2A37),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF06B6D4),
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF06B6D4),
          foregroundColor: Colors.white,
        )),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0B1A20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          labelStyle: const TextStyle(color: Colors.white70),
        ),
        textTheme: ThemeData.dark().textTheme.apply(
              bodyColor: Colors.white,
              displayColor: Colors.white,
            ),
      ),
      home: const InicioScreen(),
      navigatorObservers: [routeObserver],
      // Añadir un logo centrado en el AppBar para usuarios autenticados
      builder: (context, child) => child ?? const SizedBox.shrink(),
      routes: {
        '/promociones': (context) => PromocionesScreen(),
        '/clinica_editor': (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          final pacienteId = args != null && args['pacienteId'] is String
              ? args['pacienteId'] as String
              : '';
          return EditorScreen(pacienteId: pacienteId);
        },
        '/clinica_preview': (context) => const PreviewScreen(),
        '/solicitar_pago': (context) => Builder(
              builder: (context) {
                // Recupera userId desde SharedPreferences al navegar
                return FutureBuilder<int>(
                  future: SharedPreferences.getInstance().then(
                      (p) => int.tryParse(p.getString('userId') ?? '0') ?? 0),
                  builder: (context, snap) {
                    final userId = snap.data ?? 0;
                    return SolicitarPagoScreen(
                        pagoServicios: PagoServicios(AuthService.baseUrl),
                        userId: userId);
                  },
                );
              },
            ),
        '/pagos_admin': (context) =>
            const PagosAdminScreen(baseUrl: AuthService.baseUrl),
      },
    );
  }
}
