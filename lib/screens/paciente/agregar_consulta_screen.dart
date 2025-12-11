import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_services.dart';
import '../../services/local_db.dart';
import '../../services/sync_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

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
      if (imgs.isNotEmpty) {
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

    // Decide online vs offline quickly
    final conn = await (Connectivity().checkConnectivity());
    bool hasInternet = false;
    if (conn != ConnectivityResult.none) {
      // perform a light reachability test (server or google) could be added,
      // but for speed we assume connectivity result is enough here.
      hasInternet = true;
    }

    if (!hasInternet) {
      // Save consulta locally for later sync
      try {
        await LocalDb.saveConsultaLocal(data, attachments: paths);
        if (!mounted) return;
        setState(() => _cargando = false);
        messenger.showSnackBar(const SnackBar(
            content: Text('Consulta guardada localmente (pendiente)')));
        navigator.pop(true);
        return;
      } catch (e) {
        debugPrint('Error guardando consulta localmente: $e');
        if (!mounted) return;
        setState(() => _cargando = false);
        messenger
            .showSnackBar(const SnackBar(content: Text('Error al guardar')));
        return;
      }
    }

    // If pacienteId is a local id (contains '-'), try to resolve server id
    // before creating the historial. We prefer to link to an existing server
    // paciente by serverId or by cedula. If we cannot resolve the paciente
    // while online, fallback to saving the consulta locally to avoid sending
    // an invalid paciente_id to the server.
    try {
      String pacienteRef = widget.pacienteId;
      if (pacienteRef.contains('-')) {
        String resolvedServerId = '';
        try {
          final localPatient = await LocalDb.getPatientById(pacienteRef);
          if (localPatient != null) {
            resolvedServerId = localPatient['serverId']?.toString() ?? '';
            if (resolvedServerId.isEmpty) {
              final localData = Map<String, dynamic>.from(
                  localPatient['data'] ?? <String, dynamic>{});
              final ced =
                  (localData['cedula'] ?? localData['dni'] ?? localData['ci'])
                          ?.toString() ??
                      '';
              if (ced.isNotEmpty) {
                try {
                  final lookup = await ApiService.buscarPacientePorCedula(ced);
                  if (lookup != null &&
                      lookup['ok'] == true &&
                      lookup['data'] != null) {
                    final srv = Map<String, dynamic>.from(lookup['data']);
                    resolvedServerId = srv['id']?.toString() ?? '';
                    if (resolvedServerId.isNotEmpty) {
                      // mark local as synced to update serverId mapping
                      await LocalDb.markAsSynced(
                          pacienteRef, resolvedServerId, srv);
                    }
                  }
                } catch (e) {
                  debugPrint('Buscar paciente por cédula error: $e');
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Error resolviendo paciente local: $e');
        }

        // If still unresolved, try performing a quick sync and re-check
        if (resolvedServerId.isEmpty) {
          try {
            await SyncService.instance.syncPending();
            final refreshed = await LocalDb.getPatientById(pacienteRef);
            resolvedServerId = refreshed?['serverId']?.toString() ?? '';
          } catch (e) {
            debugPrint('Sync attempt while creating consulta failed: $e');
          }
        }

        if (resolvedServerId.isNotEmpty) {
          data['paciente_id'] = resolvedServerId;
        } else {
          // Could not resolve server id: save consulta locally instead of
          // sending invalid payload.
          await LocalDb.saveConsultaLocal(data, attachments: paths);
          if (!mounted) return;
          setState(() => _cargando = false);
          messenger.showSnackBar(const SnackBar(
              content: Text(
                  'Consulta guardada localmente (paciente no sincronizado)')));
          navigator.pop(true);
          return;
        }
      }
    } catch (e) {
      debugPrint('Error resolving paciente before crearHistorial: $e');
    }

    // Create a local consulta first so we always have a local record we can
    // update when the server responds. This prevents duplicates and allows
    // immediate UI feedback while the network request completes.
    String localId = await LocalDb.saveConsultaLocal(data, attachments: paths);
    try {
      // Mark as syncing to avoid concurrent uploads
      await LocalDb.setConsultaSyncing(localId);
    } catch (_) {}

    // Include client_local_id so the server can echo it back and we can match
    data['client_local_id'] = localId;

    final ok = await ApiService.crearHistorial(data, paths);

    if (!mounted) return;

    setState(() => _cargando = false);

    if (ok) {
      // Try to immediately mark local consulta as synced using the server
      // returned object (ApiService.lastCreatedHistorial). If not present,
      // trigger a light sync to reconcile later.
      try {
        final created = ApiService.lastCreatedHistorial;
        if (created != null &&
            (created['client_local_id']?.toString() ?? '') == localId) {
          final srvId = created['id']?.toString() ?? '';
          await LocalDb.markConsultaAsSynced(localId, srvId, created);
        } else {
          // fall back to a quick sync pass so the SyncService can reconcile
          await SyncService.instance.syncPending();
        }
      } catch (e) {
        debugPrint('Post-create reconciliation error: $e');
      }

      messenger
          .showSnackBar(const SnackBar(content: Text('Consulta guardada')));
      navigator.pop(true);
    } else {
      // Remote call failed: leave consulta as pending and inform the user
      try {
        await LocalDb.setConsultaPending(localId);
      } catch (_) {}
      final err = ApiService.lastErrorBody;
      final msg = (err == null || err.isEmpty)
          ? 'Error al guardar la consulta (se guardará localmente)'
          : 'Error al guardar (se guardará localmente): ${err.length > 300 ? '${err.substring(0, 300)}…' : err}';
      if (mounted) messenger.showSnackBar(SnackBar(content: Text(msg)));
      navigator.pop(true);
      return;
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
        backgroundColor: cs.surface,
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
