import 'package:flutter/material.dart';
import 'dart:ui';
import '../../models/paciente.dart';
import '../../services/api_services.dart';
import '../../services/local_db.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../login/login_screen.dart';
import 'vista_paciente_screen.dart';

class IngresoPacienteScreen extends StatefulWidget {
  const IngresoPacienteScreen({super.key});

  @override
  State<IngresoPacienteScreen> createState() => _IngresoPacienteScreenState();
}

class _IngresoPacienteScreenState extends State<IngresoPacienteScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _cedulaController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool cargando = false;

  late AnimationController _anim;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _glow = Tween<double>(begin: 0.2, end: 0.6).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeInOut),
    );
  }

  Future<void> buscarPaciente() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final cedula = _cedulaController.text.trim();
    FocusScope.of(context).unfocus();

    setState(() => cargando = true);

    // If offline, try local DB first
    final conn = await Connectivity().checkConnectivity();
    if (conn == ConnectivityResult.none) {
      final local = await LocalDb.getPatientByCedula(cedula);
      if (!mounted) return;
      setState(() => cargando = false);
      if (local != null && local['data'] is Map<String, dynamic>) {
        final paciente =
            Paciente.fromJson(Map<String, dynamic>.from(local['data'] as Map));
        navigator.push(MaterialPageRoute(
            builder: (_) => VistaPacienteScreen(paciente: paciente)));
        return;
      }
      messenger.showSnackBar(
          const SnackBar(content: Text('Paciente no encontrado (offline)')));
      return;
    }

    // Online: try public global search first
    final resp = await ApiService.buscarPacientePorCedulaGlobal(cedula);
    if (!mounted) return;
    if (resp != null &&
        resp['ok'] == true &&
        resp['data'] is Map<String, dynamic>) {
      setState(() => cargando = false);
      final paciente = Paciente.fromJson(resp['data'] as Map<String, dynamic>);
      navigator.push(
        MaterialPageRoute(
            builder: (_) => VistaPacienteScreen(paciente: paciente)),
      );
      return;
    }

    // If global failed due to auth or other issues, try local fallback
    final local = await LocalDb.getPatientByCedula(cedula);
    setState(() => cargando = false);
    if (local != null && local['data'] is Map<String, dynamic>) {
      final paciente =
          Paciente.fromJson(Map<String, dynamic>.from(local['data'] as Map));
      navigator.push(MaterialPageRoute(
          builder: (_) => VistaPacienteScreen(paciente: paciente)));
      return;
    }

    // If the server responded with 401 (requires sign-in), prompt login
    final status = resp != null ? (resp['status'] as int? ?? 0) : 0;
    if (status == 401) {
      messenger.showSnackBar(SnackBar(
        content: const Text('Búsqueda requiere iniciar sesión'),
        action: SnackBarAction(
          label: 'Iniciar sesión',
          onPressed: () {
            navigator
                .push(MaterialPageRoute(builder: (_) => const LoginScreen()));
          },
        ),
      ));
      return;
    }

    messenger.showSnackBar(
      const SnackBar(content: Text("Paciente no encontrado")),
    );
  }

  @override
  void dispose() {
    _cedulaController.dispose();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final bg1 = theme.brightness == Brightness.dark
        ? const Color(0xFF0E1116)
        : const Color(0xFFE8F0FF);

    final bg2 = theme.brightness == Brightness.dark
        ? const Color(0xFF06070A)
        : const Color(0xFFDDE6FF);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Ingreso Paciente"),
      ),
      body: Stack(
        children: [
          // 🔥 Fondo moderno con gradiente suave
          AnimatedContainer(
            duration: const Duration(seconds: 2),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [bg1, bg2],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // ✨ Círculo decorativo suave
          Positioned(
            top: -80,
            right: -40,
            child: AnimatedBuilder(
              animation: _anim,
              builder: (_, __) => Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary.withOpacity(_glow.value * 0.3),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withOpacity(_glow.value * 0.25),
                      blurRadius: 80,
                      spreadRadius: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ⭐ Contenido principal
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          color: theme.brightness == Brightness.dark
                              ? Colors.white.withOpacity(0.04)
                              : Colors.white.withOpacity(0.55),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.15),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Logo
                              CircleAvatar(
                                radius: 40,
                                backgroundColor:
                                    scheme.primary.withOpacity(0.18),
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Image.asset("assets/images/logo.png"),
                                ),
                              ),
                              const SizedBox(height: 20),

                              Text(
                                "Verifica tu identidad",
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: scheme.onSurface,
                                ),
                              ),

                              const SizedBox(height: 10),

                              Text(
                                "Introduce tu cédula para acceder a tu historial médico.",
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurface.withOpacity(0.75),
                                ),
                              ),

                              const SizedBox(height: 32),

                              // 🟦 INPUT ULTRA MODERNO CON BORDE ANIMADO
                              AnimatedBuilder(
                                animation: _glow,
                                builder: (_, __) => Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: scheme.primary
                                          .withOpacity(_glow.value * 0.8),
                                      width: 1.4,
                                    ),
                                  ),
                                  child: TextFormField(
                                    controller: _cedulaController,
                                    keyboardType: TextInputType.number,
                                    enabled: !cargando,
                                    decoration: InputDecoration(
                                      labelText: "Cédula del paciente",
                                      prefixIcon:
                                          const Icon(Icons.badge_outlined),
                                      filled: true,
                                      fillColor:
                                          theme.brightness == Brightness.dark
                                              ? Colors.white.withOpacity(0.05)
                                              : Colors.white.withOpacity(0.7),
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 14),
                                    ),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return "Ingresa una cédula válida";
                                      }
                                      if (value.trim().length < 6) {
                                        return "La cédula debe tener al menos 6 dígitos";
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ),

                              const SizedBox(height: 30),

                              // 🔵 BOTÓN MODERNO
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  backgroundColor: scheme.primary,
                                  elevation: 8,
                                  shadowColor: scheme.primary.withOpacity(0.4),
                                ),
                                onPressed: cargando ? null : buscarPaciente,
                                child: cargando
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ))
                                    : const Text(
                                        "Buscar paciente",
                                        style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold),
                                      ),
                              ),

                              const SizedBox(height: 18),

                              TextButton.icon(
                                onPressed: cargando
                                    ? null
                                    : () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => const LoginScreen(),
                                          ),
                                        );
                                      },
                                icon: const Icon(Icons.lock_open_outlined),
                                label: const Text(
                                  "¿Personal de la clínica? Inicie sesión",
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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
