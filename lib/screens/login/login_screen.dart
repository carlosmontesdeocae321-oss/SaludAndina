import 'package:flutter/material.dart';
// usar imagen PNG para el logo
import 'package:flutter_signin_button/flutter_signin_button.dart';

import '../../services/auth_servicios.dart';
import '../menu/menu_principal_screen.dart';
import '../inicio_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usuarioCtrl = TextEditingController();
  final TextEditingController _claveCtrl = TextEditingController();
  bool cargando = false;
  bool _mostrarClave = false;

  @override
  void dispose() {
    _usuarioCtrl.dispose();
    _claveCtrl.dispose();
    super.dispose();
  }

  Future<void> _loginWithCredentials() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => cargando = true);
    final res = await AuthService.loginWithCredentials(
      _usuarioCtrl.text.trim(),
      _claveCtrl.text,
    );
    if (!mounted) return;
    setState(() => cargando = false);

    if (res['ok'] == true) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MenuPrincipalScreen()),
      );
      return;
    }

    final message = (res['message'] ?? 'No se pudo iniciar sesión.').toString();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loginWithGoogle() async {
    setState(() => cargando = true);
    final credential = await AuthService.signInWithGoogle();
    setState(() => cargando = false);

    if (credential != null) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MenuPrincipalScreen()),
      );
    } else {
      if (!mounted) return;
      final message = AuthService.lastGoogleSignInError ??
          'No se pudo iniciar sesión con Google.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFEFFAF9), Color(0xFFD0EEF4)],
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
                color: Colors.white.withOpacity(0.25),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                color: Colors.tealAccent.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  elevation: 10,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 26, vertical: 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.12),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Image.asset('assets/images/logo.png',
                                  width: 72, height: 72, fit: BoxFit.contain),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Iniciar sesión',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Ingresa con tu usuario y clave o continua con Google.',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                        const SizedBox(height: 24),
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: _usuarioCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Usuario',
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                                enabled: !cargando,
                                textInputAction: TextInputAction.next,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Ingresa tu usuario';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _claveCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Clave',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _mostrarClave
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                    onPressed: cargando
                                        ? null
                                        : () => setState(
                                              () => _mostrarClave =
                                                  !_mostrarClave,
                                            ),
                                  ),
                                ),
                                enabled: !cargando,
                                obscureText: !_mostrarClave,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) {
                                  if (!cargando) _loginWithCredentials();
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Ingresa tu clave';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              FilledButton.icon(
                                onPressed:
                                    cargando ? null : _loginWithCredentials,
                                icon: const Icon(Icons.lock_open),
                                label: const Text('Iniciar sesión'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                'o',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: SignInButton(
                            Buttons.Google,
                            text: 'Continuar con Google',
                            onPressed: cargando ? null : _loginWithGoogle,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (cargando)
                          const Center(
                            child: SizedBox(
                              height: 22,
                              width: 22,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2.6),
                            ),
                          ),
                        const SizedBox(height: 18),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const InicioScreen())),
                            icon: const Icon(Icons.arrow_back, size: 18),
                            label: const Text('Volver'),
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
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
