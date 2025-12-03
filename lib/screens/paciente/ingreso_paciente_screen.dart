import 'package:flutter/material.dart';
import '../../models/paciente.dart';
import '../../services/api_services.dart';
import '../login/login_screen.dart';
import 'vista_paciente_screen.dart';

class IngresoPacienteScreen extends StatefulWidget {
  const IngresoPacienteScreen({super.key});

  @override
  State<IngresoPacienteScreen> createState() => _IngresoPacienteScreenState();
}

class _IngresoPacienteScreenState extends State<IngresoPacienteScreen> {
  final TextEditingController _cedulaController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool cargando = false;

  Future<void> buscarPaciente() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final cedula = _cedulaController.text.trim();
    FocusScope.of(context).unfocus();

    setState(() => cargando = true);

    final resp = await ApiService.buscarPacientePorCedulaGlobal(cedula);

    if (!mounted) return;
    setState(() => cargando = false);

    if (resp != null &&
        resp['ok'] == true &&
        resp['data'] is Map<String, dynamic>) {
      final paciente = Paciente.fromJson(resp['data'] as Map<String, dynamic>);
      if (!navigator.mounted) return;
      navigator.push(
        MaterialPageRoute(
          builder: (_) => VistaPacienteScreen(paciente: paciente),
        ),
      );
      return;
    }

    final status = resp != null ? (resp['status'] as int? ?? 0) : 0;
    // Si la búsqueda global requiere credenciales, intentar la búsqueda local
    if (status == 401) {
      final local = await ApiService.buscarPacientePorCedula(cedula);
      if (!mounted) return;
      if (local != null &&
          local['ok'] == true &&
          local['data'] is Map<String, dynamic>) {
        final paciente =
            Paciente.fromJson(local['data'] as Map<String, dynamic>);
        if (!navigator.mounted) return;
        navigator.push(
          MaterialPageRoute(
            builder: (_) => VistaPacienteScreen(paciente: paciente),
          ),
        );
        return;
      }

      // Si tampoco se encontró en local o tampoco está permitido, pedir login
      messenger.showSnackBar(SnackBar(
        content: const Text('Búsqueda requiere iniciar sesión'),
        action: SnackBarAction(
          label: 'Iniciar sesión',
          onPressed: () {
            if (!navigator.mounted) return;
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final background = Color.lerp(
          scheme.surface,
          Colors.black,
          theme.brightness == Brightness.dark ? 0.5 : 0.2,
        ) ??
        scheme.surface;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Ingreso Paciente'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              background,
              Color.lerp(background, Colors.black, 0.35) ?? background,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Card(
                  color: Color.lerp(
                        scheme.surfaceContainerHighest,
                        Colors.black,
                        theme.brightness == Brightness.dark ? 0.55 : 0.25,
                      ) ??
                      scheme.surfaceContainerHighest,
                  elevation: 8,
                  shadowColor: Colors.black.withOpacity(0.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundColor: scheme.primary.withOpacity(0.14),
                            child: ClipOval(
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Verifica tu identidad',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Introduce tu cédula para mostrar tu historial y citas en segundos.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 28),
                          TextFormField(
                            controller: _cedulaController,
                            enabled: !cargando,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Cédula del paciente',
                              prefixIcon: const Icon(Icons.badge_outlined),
                              filled: true,
                              fillColor: scheme.surface.withOpacity(
                                  theme.brightness == Brightness.dark
                                      ? 0.25
                                      : 0.12),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Ingresa una cédula válida';
                              }
                              if (value.trim().length < 6) {
                                return 'La cédula debe tener al menos 6 dígitos';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            icon: cargando
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          scheme.onPrimary),
                                    ),
                                  )
                                : const Icon(Icons.search),
                            label: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Text(
                                  cargando ? 'Buscando...' : 'Buscar paciente'),
                            ),
                            onPressed: cargando ? null : buscarPaciente,
                          ),
                          const SizedBox(height: 16),
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
                                '¿Personal de la clínica? Inicie sesión'),
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
    );
  }
}
