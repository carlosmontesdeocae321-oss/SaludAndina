import 'package:flutter/material.dart';
import '../../models/paciente.dart';
import '../../services/api_services.dart';

class AgendarCitaScreen extends StatefulWidget {
  final Paciente paciente;
  const AgendarCitaScreen({super.key, required this.paciente});

  @override
  State<AgendarCitaScreen> createState() => _AgendarCitaScreenState();
}

class _AgendarCitaScreenState extends State<AgendarCitaScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _fecha;
  TimeOfDay? _hora;
  final _motivoController = TextEditingController();
  bool _guardando = false;

  Future<void> _seleccionarFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (!mounted) return;
    if (fecha != null) setState(() => _fecha = fecha);
  }

  Future<void> _seleccionarHora() async {
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (!mounted) return;
    if (hora != null) setState(() => _hora = hora);
  }

  Future<void> _guardarCita() async {
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (_fecha == null || _hora == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Selecciona fecha y hora")),
      );
      return;
    }

    setState(() => _guardando = true);

    final data = {
      'pacienteId': widget.paciente.id,
      'fecha': _fecha!.toIso8601String(),
      'hora': _hora!.format(context),
      'motivo': _motivoController.text,
    };

    final exito = await ApiService.agendarCita(data);

    if (!mounted) return;

    setState(() => _guardando = false);

    if (exito) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Cita agendada correctamente")),
      );
      navigator.pop(true);
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text("Error al agendar la cita")),
      );
    }
  }

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldTextColor = isDark ? Colors.white : Colors.black87;
    final fieldLabelColor = isDark ? Colors.white70 : Colors.black54;
    final fieldHintColor = isDark ? Colors.white54 : Colors.black45;
    final fieldFillColor = isDark ? const Color(0xFF0B1626) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: Text("Agendar cita - ${widget.paciente.nombres}"),
      ),
      body: _guardando
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _motivoController,
                      style: TextStyle(color: fieldTextColor),
                      decoration: InputDecoration(
                        labelText: "Motivo de la cita",
                        labelStyle: TextStyle(color: fieldLabelColor),
                        hintStyle: TextStyle(color: fieldHintColor),
                        filled: true,
                        fillColor: fieldFillColor,
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? "Ingresa el motivo" : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _seleccionarFecha,
                            child: Text(_fecha == null
                                ? "Seleccionar fecha"
                                : "Fecha: ${_fecha!.toLocal().toString().split(' ')[0]}"),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _seleccionarHora,
                            child: Text(_hora == null
                                ? "Seleccionar hora"
                                : "Hora: ${_hora!.format(context)}"),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _guardarCita,
                      child: const Text("Agendar cita"),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
