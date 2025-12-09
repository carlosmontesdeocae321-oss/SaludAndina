import 'package:flutter/material.dart';
// svg import removed (no central logo in InicioScreen)
import 'paciente/ingreso_paciente_screen.dart';
import 'login/login_screen.dart';
import '../widgets/app_drawer.dart';
import '../services/sync_service.dart';

class InicioScreen extends StatelessWidget {
  const InicioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Iniciando sincronización...')));
          try {
            await SyncService.instance.onLogin();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sincronización finalizada')));
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('Error: $e')));
          }
        },
        icon: const Icon(Icons.sync),
        label: const Text('Sincronizar'),
      ),
      appBar: AppBar(
        backgroundColor: const Color(0xFF070F1E),
        elevation: 0,
        title: const Text('Inicio'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pushNamed(context, '/promociones');
            },
            child: const Text(
              'Ver promociones',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF050B17), Color(0xFF0F1C2C)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Positioned(
            top: -80,
            left: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -90,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                color: const Color(0xFF1BD1C2).withOpacity(0.14),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B1626).withOpacity(0.78),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.08),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 32,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: 160,
                          height: 160,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        '¿Cómo deseas entrar?',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Selecciona el flujo adecuado para continuar con tu gestión.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withOpacity(0.7),
                              height: 1.4,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 36),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const IngresoPacienteScreen()),
                                );
                              },
                              icon: const Icon(Icons.favorite_outline),
                              label: const Text('Paciente'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF122741),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 18),
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const LoginScreen()),
                                );
                              },
                              icon: const Icon(Icons.local_hospital_outlined),
                              label: const Text('Clínica'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1BD1C2),
                                foregroundColor: const Color(0xFF04212A),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 18),
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
