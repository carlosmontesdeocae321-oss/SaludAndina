import 'package:flutter/material.dart';
import '../menu/menu_principal_screen.dart';

// Admin dashboard removed per request. Keep a minimal placeholder to avoid
// breaking any imports elsewhere. Navigation should go to MenuPrincipalScreen.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, this.isAdmin = false});

  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Panel de Administración')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('El panel de administración ha sido eliminado.'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const MenuPrincipalScreen()),
                );
              },
              child: const Text('Ir al Menú Principal'),
            ),
          ],
        ),
      ),
    );
  }
}
