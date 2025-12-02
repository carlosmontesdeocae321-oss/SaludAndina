import 'package:flutter/material.dart';
// svg import removed; we use PNG `assets/images/logo.png` as primary
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_services.dart';
import '../services/auth_servicios.dart';
import '../screens/citas/citas_screen.dart';
import '../screens/doctor/profile_screen.dart';
import '../screens/dueno/dashboard_screen.dart';
import '../screens/menu/menu_principal_screen.dart';
import '../screens/inicio_screen.dart';
import '../screens/doctor/doctor_list_screen.dart';
import '../screens/admin/promociones_screen.dart';
// 'Solicitar pago' removed from drawer
import '../screens/admin/pagos_admin_screen.dart';
import '../screens/mis_compras_screen.dart';
// Pago servicios import removed (no longer referenced in drawer)

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  // Usamos directamente `assets/images/logo.png` como logo principal.

  Future<bool> _isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final usuario = prefs.getString('usuario') ?? '';
    final userId = prefs.getString('userId') ?? '';
    return usuario.isNotEmpty || userId.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Header: mostrar distinto contenido si hay sesión o no
            FutureBuilder<bool>(
              future: _isLoggedIn(),
              builder: (context, sessionSnap) {
                final logged = sessionSnap.data ?? false;
                if (!logged) {
                  return DrawerHeader(
                    margin: EdgeInsets.zero,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    child: Row(
                      children: [
                        // Mostrar el SVG si existe; si no, usar logo.png como fallback
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Image.asset('assets/images/logo.png',
                              fit: BoxFit.contain),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Buscar doctor',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Si hay sesión, mostrar información de la clínica/usuario
                return DrawerHeader(
                  margin: EdgeInsets.zero,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Image.asset('assets/images/logo.png',
                            fit: BoxFit.contain),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FutureBuilder<Map<String, dynamic>?>(
                          future: ApiService.obtenerMisDatos(),
                          builder: (context, snap) {
                            final datos = snap.data;
                            final nombreClinica =
                                datos?['clinica']?.toString() ?? 'Mi Clínica';
                            final usuario = datos?['usuario']?.toString() ?? '';
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(nombreClinica,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                                if (usuario.isNotEmpty)
                                  Text(usuario,
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 13)),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            // Mostrar diferentes opciones según estado de sesión
            FutureBuilder<bool>(
              future: _isLoggedIn(),
              builder: (context, snap) {
                final logged = snap.data ?? false;
                // Si no hay sesión, mostrar sólo los items básicos
                if (!logged) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.person),
                        title: const Text('Doctores'),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const DoctorListScreen()));
                        },
                      ),
                    ],
                  );
                }

                // Si hay sesión, mostrar menú completo + pantallas nuevas
                return FutureBuilder<Map<String, dynamic>?>(
                  future: ApiService.obtenerMisDatos(),
                  builder: (context, snapData) {
                    final datos = snapData.data;
                    final isAdmin =
                        (datos?['rol']?.toString() ?? '').toLowerCase() ==
                            'admin';

                    if (isAdmin) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.local_offer),
                            title: const Text('Promociones'),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => PromocionesScreen()));
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.monetization_on),
                            title: const Text('Pagos (Admin)'),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const PagosAdminScreen(
                                          baseUrl: ApiService.baseUrl)));
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.logout),
                            title: const Text('Cerrar sesión'),
                            onTap: () async {
                              final navigator = Navigator.of(context);
                              Navigator.pop(context);
                              await AuthService.logout();
                              navigator.pushAndRemoveUntil(
                                  MaterialPageRoute(
                                      builder: (_) => const InicioScreen()),
                                  (route) => false);
                            },
                          ),
                        ],
                      );
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.local_offer),
                          title: const Text('Promociones'),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => PromocionesScreen()));
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.history),
                          title: const Text('Mis compras'),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const MisComprasScreen()));
                          },
                        ),

                        // 'Solicitar pago' removed from drawer
                        ListTile(
                          leading: const Icon(Icons.calendar_today),
                          title: const Text('Citas'),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const CitasScreen()));
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.person),
                          title: const Text('Doctores'),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const DoctorListScreen()));
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.people),
                          title: const Text('Pacientes'),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const MenuPrincipalScreen()));
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.person_outline),
                          title: const Text('Perfil'),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const PerfilDoctorScreen()));
                          },
                        ),
                        const SizedBox(height: 8),
                        ListTile(
                          leading: const Icon(Icons.dashboard_customize),
                          title: const Text('Panel (Dueño)'),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const DashboardDuenoScreen()));
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.logout),
                          title: const Text('Cerrar sesión'),
                          onTap: () async {
                            final navigator = Navigator.of(context);
                            Navigator.pop(context);
                            await AuthService.logout();
                            navigator.pushAndRemoveUntil(
                                MaterialPageRoute(
                                    builder: (_) => const InicioScreen()),
                                (route) => false);
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
