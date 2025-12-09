import 'dart:async';

import 'package:flutter/material.dart';
// svg import removed; we use PNG `assets/images/logo.png` as primary
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_services.dart';
import '../services/auth_servicios.dart';
import '../services/sync_service.dart';
import '../services/sync_notifier.dart';
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

  Widget _drawerTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Future<void> Function(NavigatorState navigator) action,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textStyle = theme.textTheme.bodyLarge?.copyWith(
      color: Colors.white.withOpacity(0.92),
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
    );
    final iconColor = Colors.white.withOpacity(0.78);
    final tileColor = Colors.white.withOpacity(0.08);
    final hoverColor = scheme.primary.withOpacity(0.14);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(label, style: textStyle),
        trailing: trailing,
        tileColor: tileColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        minLeadingWidth: 20,
        visualDensity: VisualDensity.compact,
        hoverColor: hoverColor,
        onTap: () async {
          final navigator = Navigator.of(context);
          navigator.pop();
          await action(navigator);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final backgroundGradient = LinearGradient(
      colors: [
        Color.lerp(scheme.surface, Colors.black, 0.05)!,
        Color.lerp(scheme.surfaceContainerHighest, Colors.black, 0.35)!,
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final headerGradient = LinearGradient(
      colors: [
        Color.lerp(scheme.primary, Colors.black, 0.05)!,
        Color.lerp(scheme.primaryContainer, Colors.black, 0.4)!,
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final primaryText = Colors.white.withOpacity(0.94);
    final secondaryText = Colors.white.withOpacity(0.72);
    final dividerColor = Colors.white.withOpacity(0.08);

    Widget buildLogoTile() {
      return Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(10),
        child: Image.asset(
          'assets/images/logo.png',
          fit: BoxFit.contain,
        ),
      );
    }

    return Drawer(
      child: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
            physics: const BouncingScrollPhysics(),
            children: [
              FutureBuilder<bool>(
                future: _isLoggedIn(),
                builder: (context, sessionSnap) {
                  final logged = sessionSnap.data ?? false;
                  final headerDecoration = BoxDecoration(
                    gradient: headerGradient,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.24),
                        blurRadius: 22,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  );

                  if (!logged) {
                    return Container(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      margin: const EdgeInsets.only(top: 18, bottom: 20),
                      decoration: headerDecoration,
                      child: Row(
                        children: [
                          buildLogoTile(),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Buscar doctor',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: primaryText,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Explora la red de especialistas.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: secondaryText,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Container(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    margin: const EdgeInsets.only(top: 18, bottom: 20),
                    decoration: headerDecoration,
                    child: Row(
                      children: [
                        buildLogoTile(),
                        const SizedBox(width: 14),
                        Expanded(
                          child: FutureBuilder<Map<String, dynamic>?>(
                            future: ApiService.obtenerMisDatos(),
                            builder: (context, snap) {
                              final datos = snap.data;
                              final nombreClinica =
                                  datos?['clinica']?.toString() ?? 'Mi Clínica';
                              final usuario =
                                  datos?['usuario']?.toString() ?? '';
                              final plan =
                                  datos?['plan']?.toString().trim() ?? '';

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    nombreClinica,
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      color: primaryText,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  if (usuario.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      usuario,
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: secondaryText,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                  if (plan.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.16),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'Plan $plan',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          color: primaryText,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
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
              FutureBuilder<bool>(
                future: _isLoggedIn(),
                builder: (context, snap) {
                  final logged = snap.data ?? false;
                  if (!logged) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _drawerTile(
                          context,
                          icon: Icons.person_outline,
                          label: 'Doctores',
                          action: (navigator) async {
                            navigator.push(
                              MaterialPageRoute(
                                builder: (_) => const DoctorListScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  }

                  return FutureBuilder<Map<String, dynamic>?>(
                    future: ApiService.obtenerMisDatos(),
                    builder: (context, snapData) {
                      final datos = snapData.data;
                      final isAdmin =
                          (datos?['rol']?.toString() ?? '').toLowerCase() ==
                              'admin';

                      if (isAdmin) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _drawerTile(
                              context,
                              icon: Icons.local_offer_outlined,
                              label: 'Promociones',
                              action: (navigator) async {
                                navigator.push(
                                  MaterialPageRoute(
                                    builder: (_) => PromocionesScreen(),
                                  ),
                                );
                              },
                            ),
                            _drawerTile(
                              context,
                              icon: Icons.monetization_on_outlined,
                              label: 'Pagos (Admin)',
                              action: (navigator) async {
                                navigator.push(
                                  MaterialPageRoute(
                                    builder: (_) => const PagosAdminScreen(
                                      baseUrl: ApiService.baseUrl,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            _drawerTile(
                              context,
                              icon: Icons.sync,
                              label: 'Sincronizar',
                              trailing: ValueListenableBuilder<int>(
                                valueListenable: SyncNotifier.instance.count,
                                builder: (ctx, cnt, _) {
                                  if (cnt <= 0) return const SizedBox.shrink();
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text('$cnt',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold)),
                                  );
                                },
                              ),
                              action: (navigator) async {
                                final messenger = ScaffoldMessenger.of(navigator.context);
                                messenger.showSnackBar(const SnackBar(
                                    content: Text('Iniciando sincronización...')));
                                try {
                                  await SyncService.instance.onLogin();
                                  messenger.showSnackBar(const SnackBar(
                                      content: Text('Sincronización finalizada')));
                                } catch (e) {
                                  messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                                }
                              },
                            ),
                            _drawerTile(
                              context,
                              icon: Icons.logout,
                              label: 'Cerrar sesión',
                              action: (navigator) async {
                                await AuthService.logout();
                                navigator.pushAndRemoveUntil(
                                  MaterialPageRoute(
                                    builder: (_) => const InicioScreen(),
                                  ),
                                  (route) => false,
                                );
                              },
                            ),
                          ],
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _drawerTile(
                            context,
                            icon: Icons.local_offer_outlined,
                            label: 'Promociones',
                            action: (navigator) async {
                              navigator.push(
                                MaterialPageRoute(
                                  builder: (_) => PromocionesScreen(),
                                ),
                              );
                            },
                          ),
                          _drawerTile(
                            context,
                            icon: Icons.history,
                            label: 'Mis compras',
                            action: (navigator) async {
                              navigator.push(
                                MaterialPageRoute(
                                  builder: (_) => const MisComprasScreen(),
                                ),
                              );
                            },
                          ),
                          _drawerTile(
                            context,
                            icon: Icons.calendar_today_outlined,
                            label: 'Citas',
                            action: (navigator) async {
                              navigator.push(
                                MaterialPageRoute(
                                  builder: (_) => const CitasScreen(),
                                ),
                              );
                            },
                          ),
                          _drawerTile(
                            context,
                            icon: Icons.person_outline,
                            label: 'Doctores',
                            action: (navigator) async {
                              navigator.push(
                                MaterialPageRoute(
                                  builder: (_) => const DoctorListScreen(),
                                ),
                              );
                            },
                          ),
                          _drawerTile(
                            context,
                            icon: Icons.people_alt_outlined,
                            label: 'Pacientes',
                            action: (navigator) async {
                              navigator.push(
                                MaterialPageRoute(
                                  builder: (_) => const MenuPrincipalScreen(),
                                ),
                              );
                            },
                          ),
                          _drawerTile(
                            context,
                            icon: Icons.badge_outlined,
                            label: 'Perfil',
                            action: (navigator) async {
                              navigator.push(
                                MaterialPageRoute(
                                  builder: (_) => const PerfilDoctorScreen(),
                                ),
                              );
                            },
                          ),
                          Container(
                            height: 1,
                            margin: const EdgeInsets.symmetric(vertical: 12),
                            color: dividerColor,
                          ),
                          _drawerTile(
                            context,
                            icon: Icons.dashboard_customize_outlined,
                            label: 'Panel (Dueño)',
                            action: (navigator) async {
                              navigator.push(
                                MaterialPageRoute(
                                  builder: (_) => const DashboardDuenoScreen(),
                                ),
                              );
                            },
                          ),
                          _drawerTile(
                            context,
                            icon: Icons.sync,
                            label: 'Sincronizar',
                            trailing: ValueListenableBuilder<int>(
                              valueListenable: SyncNotifier.instance.count,
                              builder: (ctx, cnt, _) {
                                if (cnt <= 0) return const SizedBox.shrink();
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text('$cnt',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold)),
                                );
                              },
                            ),
                            action: (navigator) async {
                              final messenger = ScaffoldMessenger.of(navigator.context);
                              messenger.showSnackBar(const SnackBar(
                                  content: Text('Iniciando sincronización...')));
                              try {
                                await SyncService.instance.onLogin();
                                if (messenger.mounted) {
                                  messenger.showSnackBar(const SnackBar(
                                      content: Text('Sincronización finalizada')));
                                }
                              } catch (e) {
                                if (messenger.mounted) {
                                  messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                                }
                              }
                            },
                          ),
                          _drawerTile(
                            context,
                            icon: Icons.logout,
                            label: 'Cerrar sesión',
                            action: (navigator) async {
                              await AuthService.logout();
                              navigator.pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (_) => const InicioScreen(),
                                ),
                                (route) => false,
                              );
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
      ),
    );
  }
}
