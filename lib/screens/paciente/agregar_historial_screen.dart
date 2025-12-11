import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_services.dart';
import '../../services/local_db.dart';
import '../../services/sync_service.dart';

class AgregarHistorialScreen extends StatefulWidget {
  final String pacienteId;
  const AgregarHistorialScreen({super.key, required this.pacienteId});

  @override
  State<AgregarHistorialScreen> createState() => _AgregarHistorialScreenState();
}

class _AgregarHistorialScreenState extends State<AgregarHistorialScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _motivoCtrl = TextEditingController();

  // Examen físico (campos separados)
  final _pesoCtrl = TextEditingController();
  final _estaturaCtrl = TextEditingController();
  final _imcCtrl = TextEditingController();
  final _presionCtrl = TextEditingController();
  final _fcCtrl = TextEditingController(); // frecuencia cardiaca
  final _frCtrl = TextEditingController(); // frecuencia respiratoria
  final _tempCtrl = TextEditingController();

  final _otrosCtrl = TextEditingController();
  final _diagnosticoCtrl = TextEditingController();
  final _recetaCtrl = TextEditingController();
  final _tratamientoCtrl = TextEditingController();

  final _fechaCtrl = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  final List<XFile> _imagenes = [];

  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
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
    _recetaCtrl.dispose();
    _tratamientoCtrl.dispose();
    _fechaCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _cargando = true);

    // Fecha es obligatoria; si está vacía tomar hoy
    String fecha = _fechaCtrl.text.trim();
    if (fecha.isEmpty) {
      final now = DateTime.now();
      fecha =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    }

    // Valores numéricos: si están vacíos, llenar con '0'
    String peso = _pesoCtrl.text.trim();
    String estatura = _estaturaCtrl.text.trim();
    String imc = _imcCtrl.text.trim();
    if (peso.isEmpty) peso = '0';
    if (estatura.isEmpty) estatura = '0';

    // Calcular IMC si no se proporcionó y estatura/peso son válidos
    if ((imc.isEmpty || imc == '0') && peso != '0' && estatura != '0') {
      try {
        final p = double.parse(peso.replaceAll(',', '.'));
        final e = double.parse(estatura.replaceAll(',', '.'));
        if (e > 0) {
          final calc = p / (e * e);
          imc = calc.toStringAsFixed(2);
        } else {
          imc = '0';
        }
      } catch (e) {
        imc = '0';
      }
    }
    if (imc.isEmpty) imc = '0';

    final presion = _presionCtrl.text.trim();
    final fc = _fcCtrl.text.trim().isEmpty ? '0' : _fcCtrl.text.trim();
    final fr = _frCtrl.text.trim().isEmpty ? '0' : _frCtrl.text.trim();
    final temp = _tempCtrl.text.trim().isEmpty ? '0' : _tempCtrl.text.trim();

    final data = <String, String>{
      'paciente_id': widget.pacienteId,
      'motivo_consulta': _motivoCtrl.text.trim(),
      'peso': peso,
      'estatura': estatura,
      'imc': imc,
      'presion': presion,
      'frecuencia_cardiaca': fc,
      'frecuencia_respiratoria': fr,
      'temperatura': temp,
      'otros': _otrosCtrl.text.trim(),
      'diagnostico': _diagnosticoCtrl.text.trim(),
      'tratamiento': _tratamientoCtrl.text.trim(),
      'receta': _recetaCtrl.text.trim(),
      'fecha': fecha,
    };

    // Preparar lista de rutas de archivos
    final archivos = _imagenes.map((x) => x.path).toList();

    // Local-first: create local pending record and attempt remote create
    final createdLocalId =
        await LocalDb.saveConsultaLocal(data, attachments: archivos);
    try {
      await LocalDb.setConsultaSyncing(createdLocalId);
    } catch (_) {}
    try {
      data['client_local_id'] = createdLocalId;
    } catch (_) {}

    final ok = await ApiService.crearHistorial(data, archivos);

    if (!mounted) return;
    setState(() => _cargando = false);

    if (ok) {
      try {
        final created = ApiService.lastCreatedHistorial;
        if (created != null &&
            (created['client_local_id']?.toString() ?? '') == createdLocalId) {
          final srvId = created['id']?.toString() ?? '';
          await LocalDb.markConsultaAsSynced(createdLocalId, srvId, created);
        } else {
          // fallback: mark pending and let SyncService reconcile
          await LocalDb.setConsultaPending(createdLocalId);
          try {
            await SyncService.instance.syncPending();
          } catch (_) {}
        }
      } catch (e) {
        debugPrint('Post-create reconciliation error: $e');
        await LocalDb.setConsultaPending(createdLocalId);
      }

      messenger.showSnackBar(
        const SnackBar(content: Text('Historial agregado correctamente')),
      );
      navigator.pop(true);
    } else {
      // remote failed -> leave pending
      await LocalDb.setConsultaPending(createdLocalId);
      messenger.showSnackBar(
        const SnackBar(content: Text('Error al guardar historial')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agregar historial'),
        backgroundColor: cs.surface,
        iconTheme: IconThemeData(color: cs.onSurface),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: cs.primary,
          tabs: const [
            Tab(text: 'Motivo'),
            Tab(text: 'Examen físico'),
            Tab(text: 'Diagnóstico'),
          ],
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Motivo
                        SingleChildScrollView(
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _motivoCtrl,
                                maxLines: 6,
                                decoration: const InputDecoration(
                                    labelText: 'Motivo de consulta'),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _fechaCtrl,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: 'Fecha (YYYY-MM-DD)',
                                  suffixIcon: Icon(Icons.calendar_today),
                                ),
                                onTap: () async {
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
                                },
                              ),
                            ],
                          ),
                        ),

                        // Examen físico
                        SingleChildScrollView(
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _pesoCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                    labelText: 'Peso (kg)'),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _estaturaCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                    labelText: 'Estatura (m)'),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _imcCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                    labelText: 'IMC (opcional)'),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _presionCtrl,
                                decoration: const InputDecoration(
                                    labelText: 'Presión (ej: 120/80)'),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _fcCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'Frecuencia cardiaca (lpm)'),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _frCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'Frecuencia respiratoria (rpm)'),
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
                            ],
                          ),
                        ),

                        // Diagnóstico / receta / tratamiento
                        SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _diagnosticoCtrl,
                                maxLines: 4,
                                decoration: const InputDecoration(
                                    labelText: 'Diagnóstico'),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _recetaCtrl,
                                maxLines: 4,
                                decoration:
                                    const InputDecoration(labelText: 'Receta'),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _tratamientoCtrl,
                                maxLines: 4,
                                decoration: const InputDecoration(
                                    labelText: 'Tratamiento'),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _otrosCtrl,
                                maxLines: 3,
                                decoration:
                                    const InputDecoration(labelText: 'Otros'),
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
                                  const SizedBox(width: 12),
                                  if (_imagenes.isNotEmpty)
                                    Text(
                                      '${_imagenes.length} imagen(es) seleccionadas',
                                      style: TextStyle(color: cs.onSurface),
                                    )
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (_imagenes.isNotEmpty)
                                SizedBox(
                                  height: 100,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _imagenes.length,
                                    itemBuilder: (context, index) {
                                      final x = _imagenes[index];
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(right: 8.0),
                                        child: Stack(
                                          children: [
                                            Image.file(
                                              File(x.path),
                                              width: 100,
                                              height: 100,
                                              fit: BoxFit.cover,
                                            ),
                                            Positioned(
                                              right: 0,
                                              top: 0,
                                              child: GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    _imagenes.removeAt(index);
                                                  });
                                                },
                                                child: Container(
                                                  color: Colors.black54,
                                                  child: const Icon(
                                                    Icons.close,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            )
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _guardar,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cs.primary,
                            foregroundColor: cs.onPrimary,
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Text('Guardar historial'),
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
    );
  }

  Future<void> _pickImages() async {
    try {
      final imgs = await _picker.pickMultiImage(imageQuality: 80);
      if (!mounted) return;
      if (imgs.isNotEmpty) {
        setState(() {
          _imagenes.addAll(imgs);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error seleccionando imágenes: $e')),
      );
    }
  }
}
