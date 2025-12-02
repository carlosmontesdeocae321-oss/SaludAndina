import 'package:flutter/material.dart';
import '../../services/api_services.dart';

class CrearClinicaScreen extends StatefulWidget {
  const CrearClinicaScreen({super.key});

  @override
  State<CrearClinicaScreen> createState() => _CrearClinicaScreenState();
}

class _CrearClinicaScreenState extends State<CrearClinicaScreen> {
  final _formKey = GlobalKey<FormState>();
  String nombre = '';
  String direccion = '';
  String error = '';
  bool cargando = false;

  Future<void> guardarClinica() async {
    if (_formKey.currentState!.validate()) {
      final navigator = Navigator.of(context);
      setState(() {
        cargando = true;
        error = '';
      });
      final res = await ApiService.crearClinica(nombre, direccion);
      if (!mounted) return;
      setState(() {
        cargando = false;
      });
      if ((res['ok'] ?? false) == true) {
        navigator.pop(true);
      } else {
        setState(() {
          error = res['error']?.toString() ?? 'Error al crear la clínica';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear Clínica')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Nombre'),
                onChanged: (v) => nombre = v,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Ingrese el nombre' : null,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Dirección'),
                onChanged: (v) => direccion = v,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Ingrese la dirección' : null,
              ),
              const SizedBox(height: 24),
              if (error.isNotEmpty)
                Text(error, style: const TextStyle(color: Colors.red)),
              ElevatedButton(
                onPressed: cargando ? null : guardarClinica,
                child: cargando
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
