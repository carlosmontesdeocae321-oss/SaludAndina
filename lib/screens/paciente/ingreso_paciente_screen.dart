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
  bool cargando = false;

  Future<void> buscarPaciente() async {
    final cedula = _cedulaController.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (cedula.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Ingrese una cédula válida")),
      );
      return;
    }

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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ingreso Paciente")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _cedulaController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Ingrese su cédula",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: cargando ? null : buscarPaciente,
              child: cargando
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Buscar"),
            ),
          ],
        ),
      ),
    );
  }
}
