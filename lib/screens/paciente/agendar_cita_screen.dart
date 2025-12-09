import 'package:flutter/material.dart';
import '../../services/api_services.dart';
import '../../services/local_db.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class AgendarCitaScreen extends StatefulWidget {
  final String pacienteId;
  const AgendarCitaScreen({super.key, required this.pacienteId});

  @override
  State<AgendarCitaScreen> createState() => _AgendarCitaScreenState();
}

class _AgendarCitaScreenState extends State<AgendarCitaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _motivoCtrl = TextEditingController();
  final _fechaCtrl = TextEditingController();
  final _horaCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _motivoCtrl.dispose();
    _fechaCtrl.dispose();
    _horaCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (!mounted) return;
    if (picked != null) {
      _fechaCtrl.text = picked.toIso8601String().split('T')[0];
      setState(() {});
    }
  }

  Future<void> _pickTime() async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: now,
    );
    if (!mounted) return;
    if (picked != null) {
      // Convert to 24-hour HH:MM:SS using DateTime
      final dt = DateTime(2000, 1, 1, picked.hour, picked.minute);
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      _horaCtrl.text = '$hh:$mm:00';
      setState(() {});
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _loading = true);

    final payload = {
      'paciente_id': widget.pacienteId,
      'fecha': _fechaCtrl.text,
      'hora': _horaCtrl.text,
      'motivo': _motivoCtrl.text.trim(),
    };

    // Check connectivity and fallback to local save
    final conn = await (Connectivity().checkConnectivity());
    if (conn == ConnectivityResult.none) {
      try {
        await LocalDb.saveCitaLocal(payload);
        if (!mounted) return;
        setState(() => _loading = false);
        messenger.showSnackBar(const SnackBar(
            content: Text('Cita guardada localmente (pendiente)')));
        navigator.pop(true);
        return;
      } catch (e) {
        debugPrint('Error guardando cita localmente: $e');
        if (!mounted) return;
        setState(() => _loading = false);
        messenger.showSnackBar(
            const SnackBar(content: Text('Error al agendar la cita')));
        return;
      }
    }

    try {
      final ok = await ApiService.agendarCita(payload)
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      setState(() => _loading = false);
      if (ok) {
        messenger.showSnackBar(const SnackBar(content: Text('Cita agendada')));
        navigator.pop(true);
      } else {
        messenger.showSnackBar(
            const SnackBar(content: Text('Error al agendar la cita')));
      }
    } catch (e) {
      debugPrint('Error remoto agendar cita: $e');
      // fallback to local
      try {
        await LocalDb.saveCitaLocal(payload);
        if (!mounted) return;
        setState(() => _loading = false);
        messenger.showSnackBar(const SnackBar(
            content: Text('Cita guardada localmente (pendiente)')));
        navigator.pop(true);
        return;
      } catch (e2) {
        debugPrint('Error fallback local cita: $e2');
        if (!mounted) return;
        setState(() => _loading = false);
        messenger.showSnackBar(
            const SnackBar(content: Text('Error al agendar la cita')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agendar cita')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _fechaCtrl,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Fecha (YYYY-MM-DD)',
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Seleccione fecha' : null,
                      onTap: _pickDate,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _horaCtrl,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Hora (HH:MM:SS)',
                        suffixIcon: Icon(Icons.access_time),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Seleccione hora' : null,
                      onTap: _pickTime,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _motivoCtrl,
                      decoration: const InputDecoration(labelText: 'Motivo'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _guardar,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14.0),
                              child: Text('Agendar'),
                            ),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
    );
  }
}
