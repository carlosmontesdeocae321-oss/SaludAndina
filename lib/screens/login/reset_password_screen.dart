import 'package:flutter/material.dart';

class ResetPasswordScreen extends StatelessWidget {
  final String uid;
  final String token;

  const ResetPasswordScreen(
      {super.key, required this.uid, required this.token});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Restablecer acceso')),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'El restablecimiento de contraseña ya no es necesario.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12),
            Text(
              'Solo necesitas iniciar sesión nuevamente con tu cuenta de Google desde la pantalla principal.',
            ),
          ],
        ),
      ),
    );
  }
}
