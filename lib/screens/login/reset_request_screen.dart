import 'package:flutter/material.dart';

class ResetRequestScreen extends StatefulWidget {
  const ResetRequestScreen({super.key});

  @override
  State<ResetRequestScreen> createState() => _ResetRequestScreenState();
}

class _ResetRequestScreenState extends State<ResetRequestScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar contraseña')),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Este proyecto ahora utiliza Google como método de inicio de sesión.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12),
            Text(
              'Para recuperar acceso simplemente ingresa con tu cuenta de Google desde la pantalla de inicio de sesión. Ya no es necesario restablecer una contraseña manual.',
            ),
          ],
        ),
      ),
    );
  }
}
