import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
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
import 'services/sync_service.dart';

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
  // Ensure SyncService singleton is initialized early so it registers
  // connectivity listeners and can auto-sync when connection is restored.
  try {
    // Accessing the instance constructs the singleton and starts listener.
    // ignore: unused_result
    SyncService.instance;
  } catch (e) {
    debugPrint('Error inicializando SyncService: $e');
  }

  // Register global error handlers that persist logs to a file so we can
  // retrieve them from the device without adb. Useful for remote debugging.
  Future<void> _appendLog(String msg) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}/clinica_logs.txt');
      final ts = DateTime.now().toIso8601String();
      await f.writeAsString('$ts $msg\n', mode: FileMode.append, flush: true);
    } catch (e) {
      debugPrint('No se pudo escribir log a archivo: $e');
    }
  }

  FlutterError.onError = (details) async {
    FlutterError.presentError(details);
    await _appendLog(
        'FlutterError: ${details.exceptionAsString()} \n${details.stack}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    _appendLog('UncaughtError: $error \n$stack');
    return true;
  };
  final shouldInitFirebase =
      !kIsWeb && defaultTargetPlatform != TargetPlatform.windows;

  if (shouldInitFirebase) {
    try {
      // Avoid duplicate initialization which can happen in certain
      // hot-restart or platform plugin registration scenarios.
      try {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
        } else {
          debugPrint(
              'Firebase ya estaba inicializado; omitiendo initializeApp()');
        }
      } catch (e) {
        debugPrint('Error comprobando Firebase.apps o inicializando: $e');
      }
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
      builder: (context, child) =>
          SyncStatusOverlay(child: child ?? const SizedBox.shrink()),
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

class SyncStatusOverlay extends StatefulWidget {
  final Widget child;
  const SyncStatusOverlay({super.key, required this.child});

  @override
  State<SyncStatusOverlay> createState() => _SyncStatusOverlayState();
}

class _SyncStatusOverlayState extends State<SyncStatusOverlay> {
  late StreamSubscription<String> _sub;
  String _status = 'idle';
  String _prev = 'idle';

  @override
  void initState() {
    super.initState();
    _sub = SyncService.instance.statusStream.listen((s) {
      _prev = _status;
      _status = s;
      if (mounted) setState(() {});

      // When sync finishes, show a SnackBar notification
      if ((_prev == 'syncing' || _prev == 'starting') &&
          (_status == 'done' || _status == 'idle')) {
        try {
          final messenger = ScaffoldMessenger.of(context);
          messenger.showSnackBar(const SnackBar(
            content: Text('Sincronización completada'),
            duration: Duration(seconds: 3),
          ));
        } catch (_) {}
      }

      // On error show brief message
      if (_status == 'error') {
        try {
          final messenger = ScaffoldMessenger.of(context);
          messenger.showSnackBar(const SnackBar(
            content: Text('Error durante la sincronización'),
            duration: Duration(seconds: 4),
            backgroundColor: Colors.redAccent,
          ));
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show a slim banner at top when syncing
    final isSyncing = _status == 'syncing' || _status == 'starting';
    return Stack(
      children: [
        widget.child,
        if (isSyncing)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Material(
              elevation: 4,
              color: Colors.blueAccent,
              child: SafeArea(
                bottom: false,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Row(
                    children: const [
                      Icon(Icons.sync, color: Colors.white),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text('Sincronizando datos...',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                      ),
                      SizedBox(width: 12),
                      SizedBox(
                          width: 120,
                          child: LinearProgressIndicator(color: Colors.white))
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
