import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_services.dart';

class AgregarConsultaScreen extends StatefulWidget {
  final String pacienteId;
  const AgregarConsultaScreen({super.key, required this.pacienteId});

  @override
  State<AgregarConsultaScreen> createState() => _AgregarConsultaScreenState();
}

class _AgregarConsultaScreenState extends State<AgregarConsultaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _motivoCtrl = TextEditingController();
  final _pesoCtrl = TextEditingController();
  final _estaturaCtrl = TextEditingController();
  final _imcCtrl = TextEditingController();
  final _presionCtrl = TextEditingController();
  final _fcCtrl = TextEditingController();
  final _frCtrl = TextEditingController();
  final _tempCtrl = TextEditingController();
  final _otrosCtrl = TextEditingController();
  final _diagnosticoCtrl = TextEditingController();
  final _tratamientoCtrl = TextEditingController();
  final _recetaCtrl = TextEditingController();
  final _fechaCtrl = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  final List<XFile> _imagenes = [];
  bool _cargando = false;

  @override
  void dispose() {
    _motivoCtrl.dispose();
    _pesoCtrl.dispose();
    _estaturaCtrl.dispose();
    _imcCtrl.dispose();
    _presionCtrl.dispose();
    _fcCtrl.dispose();
    _frCtrl.dispose();
    _tempCtrl.dispose();
    _otrosCtrl.dispose();
    _diagnosticoCtrl.dispose();
    _tratamientoCtrl.dispose();
    _recetaCtrl.dispose();
    _fechaCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final imgs = await _picker.pickMultiImage(imageQuality: 80);
      if (!mounted) return;
      if (imgs != null && imgs.isNotEmpty) {
        setState(() => _imagenes.addAll(imgs));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error seleccionando imágenes: $e')),
      );
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year + 2),
    );
    if (!mounted) return;
    if (picked != null) {
      _fechaCtrl.text =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      setState(() {});
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _cargando = true);

    final data = <String, String>{
      'paciente_id': widget.pacienteId,
      'motivo_consulta': _motivoCtrl.text.trim(),
      'peso': _pesoCtrl.text.trim().isEmpty ? '0' : _pesoCtrl.text.trim(),
      'estatura':
          _estaturaCtrl.text.trim().isEmpty ? '0' : _estaturaCtrl.text.trim(),
      'imc': _imcCtrl.text.trim().isEmpty ? '0' : _imcCtrl.text.trim(),
      'presion': _presionCtrl.text.trim(),
      'frecuencia_cardiaca':
          _fcCtrl.text.trim().isEmpty ? '0' : _fcCtrl.text.trim(),
      'frecuencia_respiratoria':
          _frCtrl.text.trim().isEmpty ? '0' : _frCtrl.text.trim(),
      'temperatura':
          _tempCtrl.text.trim().isEmpty ? '0' : _tempCtrl.text.trim(),
      'otros': _otrosCtrl.text.trim(),
      'diagnostico': _diagnosticoCtrl.text.trim(),
      'tratamiento': _tratamientoCtrl.text.trim(),
      'receta': _recetaCtrl.text.trim(),
      'fecha': _fechaCtrl.text.trim().isEmpty
          ? DateTime.now().toIso8601String().split('T')[0]
          : _fechaCtrl.text.trim(),
    };

    final paths = _imagenes.map((x) => x.path).toList();

    final ok = await ApiService.crearHistorial(data, paths);

    if (!mounted) return;

    setState(() => _cargando = false);

    if (ok) {
      messenger
          .showSnackBar(const SnackBar(content: Text('Consulta guardada')));
      navigator.pop(true);
    } else {
      final lastErr = ApiService.lastErrorBody;
      messenger
          .showSnackBar(SnackBar(content: Text(lastErr ?? 'Error al guardar')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final onSurface = cs.onSurface;
    final cardColor = cs.surface;
    final scale = MediaQuery.of(context).size.width / 360;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva Consulta'),
        iconTheme: IconThemeData(color: cs.onSurface),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          color: cs.onSurface,
          fontWeight: FontWeight.w600,
        ),
        backgroundColor: cs.background,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16 * scale),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    color: cardColor,
                    elevation: 2,
                    child: Padding(
                      padding: EdgeInsets.all(12 * scale),
                      child: Theme(
                        data: theme.copyWith(
                          inputDecorationTheme: InputDecorationTheme(
                            filled: true,
                            fillColor: cardColor.withOpacity(0.03),
                            labelStyle:
                                TextStyle(color: onSurface.withOpacity(0.85)),
                          ),
                          textTheme:
                              theme.textTheme.apply(bodyColor: onSurface),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _motivoCtrl,
                                style: TextStyle(color: onSurface),
                                decoration: const InputDecoration(
                                    labelText: 'Motivo de consulta'),
                                validator: (v) => v == null || v.isEmpty
                                    ? 'Ingrese motivo'
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _pesoCtrl,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      decoration: const InputDecoration(
                                          labelText: 'Peso (kg)'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _estaturaCtrl,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      decoration: const InputDecoration(
                                          labelText: 'Estatura (m)'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _imcCtrl,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      decoration: const InputDecoration(
                                          labelText: 'IMC'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _presionCtrl,
                                      decoration: const InputDecoration(
                                          labelText: 'Presión'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _fcCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                          labelText: 'Frecuencia cardiaca'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _frCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                          labelText: 'Frecuencia respiratoria'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _tempCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                    labelText: 'Temperatura (°C)'),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _diagnosticoCtrl,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                    labelText: 'Diagnóstico'),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _tratamientoCtrl,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                    labelText: 'Tratamiento'),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _recetaCtrl,
                                maxLines: 3,
                                decoration:
                                    const InputDecoration(labelText: 'Receta'),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _otrosCtrl,
                                maxLines: 2,
                                decoration:
                                    const InputDecoration(labelText: 'Otros'),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _fechaCtrl,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: 'Fecha (YYYY-MM-DD)',
                                  suffixIcon: Icon(Icons.calendar_today),
                                ),
                                onTap: _pickDate,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: _pickImages,
                                    icon: const Icon(Icons.photo_library),
                                    label: const Text('Seleccionar imágenes'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: cs.primary,
                                      foregroundColor: cs.onPrimary,
                                    ),
                                  ),
                                  SizedBox(width: 12 * scale),
                                  if (_imagenes.isNotEmpty)
                                    Text(
                                      '${_imagenes.length} imágenes seleccionadas',
                                      style: TextStyle(color: onSurface),
                                    )
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (_imagenes.isNotEmpty)
                                SizedBox(
                                  height: 100,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _imagenes.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(width: 8),
                                    itemBuilder: (ctx, i) {
                                      final f = _imagenes[i];
                                      return Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: Image.file(File(f.path),
                                                width: 120,
                                                height: 100,
                                                fit: BoxFit.cover),
                                          ),
                                          Positioned(
                                            right: 0,
                                            top: 0,
                                            child: GestureDetector(
                                              onTap: () => setState(
                                                  () => _imagenes.removeAt(i)),
                                              child: Container(
                                                color: Colors.black54,
                                                padding:
                                                    EdgeInsets.all(4 * scale),
                                                child: const Icon(Icons.close,
                                                    color: Colors.white,
                                                    size: 16),
                                              ),
                                            ),
                                          )
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _guardar,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: cs.primary,
                                        foregroundColor: cs.onPrimary,
                                        padding: EdgeInsets.symmetric(
                                            vertical: 14 * scale),
                                      ),
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                            vertical: 14 * scale),
                                        child: Text('Guardar consulta',
                                            style:
                                                TextStyle(color: cs.onPrimary)),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
