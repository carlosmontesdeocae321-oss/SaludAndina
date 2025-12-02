import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/inicio_screen.dart';
import 'screens/admin/promociones_screen.dart';
import 'route_observer.dart';
import 'services/pago_servicios.dart';
import 'screens/pagos/solicitar_pago_screen.dart';
import 'screens/admin/pagos_admin_screen.dart';
import 'services/auth_servicios.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Error inicializando Firebase en main(): $e');
  }

  runApp(const ClinicaApp());
}

class ClinicaApp extends StatelessWidget {
  const ClinicaApp({super.key});

  Future<bool> _isLoggedIn() async {
    return AuthService.isAuthenticated();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SaludAndina',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF006D5B),
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.teal)
            .copyWith(secondary: const Color(0xFF06B6D4)),
      ),
      home: const InicioScreen(),
      navigatorObservers: [routeObserver],
      // Añadir un logo centrado en el AppBar para usuarios autenticados
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            // Top-center logo visible sólo si hay sesión
            FutureBuilder<bool>(
              future: _isLoggedIn(),
              builder: (context, snap) {
                final logged = snap.data == true;
                if (!logged) return const SizedBox.shrink();
                return SafeArea(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 2))
                          ],
                        ),
                        padding: const EdgeInsets.all(6),
                        child: Image.asset('assets/images/logo.png',
                            fit: BoxFit.contain),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
      routes: {
        '/promociones': (context) => PromocionesScreen(),
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
