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
  bool _canOfflineLogin = false;

  @override
  void initState() {
    super.initState();
    // Check if offline login is possible (cached credentials/profile)
    AuthService.tryOfflineLogin().then((v) {
      if (!mounted) return;
      setState(() => _canOfflineLogin = v);
    });
  }

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
                colors: [Color(0xFF040B16), Color(0xFF0C1B2F)],
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
                color: Colors.white.withOpacity(0.1),
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
                color: const Color(0xFF1BD1C2).withOpacity(0.16),
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
                  color: const Color(0xFF101D32).withOpacity(0.85),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  elevation: 14,
                  shadowColor: Colors.black.withOpacity(0.35),
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
                                color: Colors.black.withOpacity(0.22),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.12),
                                ),
                              ),
                              child: Image.asset('assets/images/logo.png',
                                  width: 72, height: 72, fit: BoxFit.contain),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        if (_canOfflineLogin)
                          Column(
                            children: [
                              FilledButton.icon(
                                onPressed: cargando
                                    ? null
                                    : () async {
                                        final ok =
                                            await AuthService.tryOfflineLogin();
                                        if (ok && mounted) {
                                          Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) =>
                                                    const MenuPrincipalScreen()),
                                          );
                                        } else if (mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                                  content: Text(
                                                      'No es posible iniciar sesión offline')));
                                        }
                                      },
                                icon: const Icon(Icons.wifi_off),
                                label: const Text('Entrar sin Internet'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.orangeAccent,
                                  foregroundColor: Colors.black,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        Text(
                          'Iniciar sesión',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Ingresa con tu usuario y clave o continúa con Google.',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withOpacity(0.72),
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
                                style: const TextStyle(color: Colors.white),
                                cursorColor: Colors.white70,
                                decoration: InputDecoration(
                                  labelText: 'Usuario',
                                  prefixIcon: const Icon(Icons.person_outline),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.08),
                                  labelStyle:
                                      const TextStyle(color: Colors.white70),
                                  floatingLabelStyle:
                                      const TextStyle(color: Colors.white),
                                  prefixIconColor: Colors.white70,
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: Colors.white.withOpacity(0.18),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF1BD1C2),
                                      width: 1.6,
                                    ),
                                  ),
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
                                style: const TextStyle(color: Colors.white),
                                cursorColor: Colors.white70,
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
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.08),
                                  labelStyle:
                                      const TextStyle(color: Colors.white70),
                                  floatingLabelStyle:
                                      const TextStyle(color: Colors.white),
                                  prefixIconColor: Colors.white70,
                                  suffixIconColor: Colors.white70,
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: Colors.white.withOpacity(0.18),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF1BD1C2),
                                      width: 1.6,
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
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF1BD1C2),
                                  foregroundColor: const Color(0xFF062026),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  textStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            const Expanded(
                              child: Divider(color: Color(0x22FFFFFF)),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                'o',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Colors.white.withOpacity(0.6),
                                    ),
                              ),
                            ),
                            const Expanded(
                              child: Divider(color: Color(0x22FFFFFF)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: SignInButton(
                            Buttons.GoogleDark,
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
                              child: CircularProgressIndicator(
                                strokeWidth: 2.6,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF1BD1C2),
                                ),
                              ),
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
                            icon: const Icon(Icons.arrow_back,
                                size: 18, color: Colors.white70),
                            label: const Text('Volver'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white70,
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
