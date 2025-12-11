import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../models/paciente.dart';
import '../../models/consulta.dart';
import '../../services/api_services.dart';
import '../../services/local_db.dart';
import '../../services/sync_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class AgregarEditarConsultaScreen extends StatefulWidget {
  final Paciente? paciente;
  final String? pacienteId;
  final Consulta? consulta; // si es null -> agregar, si no -> editar

  const AgregarEditarConsultaScreen({
    super.key,
    this.paciente,
    this.pacienteId,
    this.consulta,
  });

  @override
  State<AgregarEditarConsultaScreen> createState() =>
      _AgregarEditarConsultaScreenState();
}

class _AgregarEditarConsultaScreenState
    extends State<AgregarEditarConsultaScreen> {
  final _formKey = GlobalKey<FormState>();
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  // Campos de la consulta
  late TextEditingController motivoCtrl;
  late TextEditingController diagnosticoCtrl;
  late TextEditingController tratamientoCtrl;
  late TextEditingController recetaCtrl;
  late TextEditingController fechaCtrl;
  late TextEditingController pesoCtrl;
  late TextEditingController estaturaCtrl;
  late TextEditingController imcCtrl;
  late TextEditingController presionCtrl;
  late TextEditingController frecuenciaCardiacaCtrl;
  late TextEditingController frecuenciaRespiratoriaCtrl;
  late TextEditingController temperaturaCtrl;

  bool cargando = false;
  final ImagePicker _picker = ImagePicker();
  List<XFile> nuevasImagenes = [];
  List<String> imagenesExistentes = [];

  @override
  void initState() {
    super.initState();
    final c = widget.consulta;
    motivoCtrl = TextEditingController(text: c?.motivo ?? '');
    fechaCtrl = TextEditingController(
        text: c != null ? _dateFormat.format(c.fecha) : '');
    diagnosticoCtrl = TextEditingController(text: c?.diagnostico ?? '');
    tratamientoCtrl = TextEditingController(text: c?.tratamiento ?? '');
    recetaCtrl = TextEditingController(text: c?.receta ?? '');
    pesoCtrl = TextEditingController(text: c?.peso.toString() ?? '');
    estaturaCtrl = TextEditingController(text: c?.estatura.toString() ?? '');
    imcCtrl = TextEditingController(text: c?.imc.toString() ?? '');
    presionCtrl = TextEditingController(text: c?.presion ?? '');
    frecuenciaCardiacaCtrl =
        TextEditingController(text: c?.frecuenciaCardiaca.toString() ?? '');
    frecuenciaRespiratoriaCtrl =
        TextEditingController(text: c?.frecuenciaRespiratoria.toString() ?? '');
    temperaturaCtrl =
        TextEditingController(text: c?.temperatura.toString() ?? '');
    imagenesExistentes = c?.imagenes ?? [];
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial =
        fechaCtrl.text.isNotEmpty ? _parseDate(fechaCtrl.text) ?? now : now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      fechaCtrl.text = _dateFormat.format(picked);
      setState(() {});
    }
  }

  Future<void> guardarConsulta() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => cargando = true);

    final pacienteId = widget.paciente?.id ?? widget.pacienteId ?? '';

    // Normalizar campos numéricos: si vienen vacíos enviarlos como números válidos.
    String asDecimal(String s) {
      final t = s.trim();
      if (t.isEmpty) return '0.0';
      final parsed = double.tryParse(t.replaceAll(',', '.'));
      if (parsed == null) return '0.0';
      return parsed.toString();
    }

    String asInt(String s) {
      final t = s.trim();
      if (t.isEmpty) return '0';
      final parsed = int.tryParse(t);
      if (parsed != null) return parsed.toString();
      final parsedD = double.tryParse(t.replaceAll(',', '.'));
      if (parsedD != null) return parsedD.toInt().toString();
      return '0';
    }

    final peso = asDecimal(pesoCtrl.text);
    final estatura = asDecimal(estaturaCtrl.text);
    final imc = asDecimal(imcCtrl.text);
    final frecuenciaCardiaca = asInt(frecuenciaCardiacaCtrl.text);
    final frecuenciaRespiratoria = asInt(frecuenciaRespiratoriaCtrl.text);
    final temperatura = asDecimal(temperaturaCtrl.text);

    final data = {
      'paciente_id': pacienteId,
      'motivo': motivoCtrl.text,
      'diagnostico': diagnosticoCtrl.text,
      'tratamiento': tratamientoCtrl.text,
      'receta': recetaCtrl.text,
      'peso': peso,
      'estatura': estatura,
      'imc': imc,
      'presion': presionCtrl.text.trim(),
      'frecuencia_cardiaca': frecuenciaCardiaca,
      'frecuencia_respiratoria': frecuenciaRespiratoria,
      'temperatura': temperatura,
    };

    // Usar la fecha seleccionada por el usuario si existe, si no usar la actual.
    data['fecha'] = fechaCtrl.text.isNotEmpty
        ? fechaCtrl.text
        : DateTime.now().toIso8601String().split('T')[0];

    // Preparar listas de imágenes: enviar nuevas como archivos y
    // las existentes (si las hay) como campo 'imagenes' en formato JSON
    final nuevasPaths = nuevasImagenes.map((e) => e.path).toList();

    bool exito = false;
    // Decide online vs offline
    final conn = await (Connectivity().checkConnectivity());
    if (conn == ConnectivityResult.none) {
      // Save locally as pending. If editing, attempt to update the existing
      // local record (use its localId when available) or preserve server id
      // so the sync process can treat this as an update.
      try {
        if (widget.consulta != null) {
          final existing = widget.consulta!;
          final key = existing.localId != null && existing.localId!.isNotEmpty
              ? existing.localId!
              : existing.id;
          // If editing an already-synced (server) consulta, ensure we store
          // the server id in the data so sync can detect it's an update.
          if (!(key.contains('-')) && existing.id.isNotEmpty) {
            data['id'] = existing.id;
          }
          await LocalDb.saveConsultaLocal(data,
              localId: key, attachments: nuevasPaths);
        } else {
          await LocalDb.saveConsultaLocal(data, attachments: nuevasPaths);
        }
        if (!mounted) return;
        setState(() => cargando = false);
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Consulta guardada localmente (pendiente de sincronización)')));
        return;
      } catch (e) {
        debugPrint('Error guardando consulta localmente: $e');
        if (!mounted) return;
        setState(() => cargando = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error guardando consulta')));
        return;
      }
    }

    // When online, try remote with timeout and fallback to local on failure
    try {
      if (widget.consulta == null) {
        // Local-first: create local pending record then attempt remote create
        final createdLocalId =
            await LocalDb.saveConsultaLocal(data, attachments: nuevasPaths);
        try {
          await LocalDb.setConsultaSyncing(createdLocalId);
        } catch (_) {}
        // include client_local_id so server can echo it
        try {
          data['client_local_id'] = createdLocalId;
        } catch (_) {}

        final ok = await ApiService.crearHistorial(data, nuevasPaths)
            .timeout(const Duration(seconds: 12));
        if (ok) {
          // try to reconcile immediately using ApiService.lastCreatedHistorial
          try {
            final created = ApiService.lastCreatedHistorial;
            if (created != null &&
                (created['client_local_id']?.toString() ?? '') ==
                    createdLocalId) {
              final srvId = created['id']?.toString() ?? '';
              await LocalDb.markConsultaAsSynced(
                  createdLocalId, srvId, created);
              exito = true;
            } else {
              // Mark pending for later sync
              await LocalDb.setConsultaPending(createdLocalId);
              // Let SyncService reconcile
              await SyncService.instance.syncPending();
              exito = true;
            }
          } catch (e) {
            debugPrint('Post-create reconciliation (agregar) error: $e');
            await LocalDb.setConsultaPending(createdLocalId);
            exito = true;
          }
        } else {
          // remote failed -> set pending
          await LocalDb.setConsultaPending(createdLocalId);
          exito = false;
        }
      } else {
        data['imagenes'] = jsonEncode(imagenesExistentes);
        final ok = await ApiService.editarHistorial(
                widget.consulta!.id, data, nuevasPaths)
            .timeout(const Duration(seconds: 12));
        exito = ok;
      }
    } catch (e) {
      debugPrint('Error remoto guardando consulta: $e');
      try {
        await LocalDb.saveConsultaLocal(data, attachments: nuevasPaths);
        if (!mounted) return;
        setState(() => cargando = false);
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Consulta guardada localmente (pendiente de sincronización)')));
        return;
      } catch (e2) {
        debugPrint('Error fallback local consulta: $e2');
        if (!mounted) return;
        setState(() => cargando = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Error al guardar')));
        return;
      }
    }

    if (!mounted) return;
    setState(() => cargando = false);

    if (!mounted) return;

    if (exito) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Error al guardar')));
    }
  }

  Future<void> _pickImages() async {
    try {
      final imgs = await _picker.pickMultiImage(imageQuality: 80);
      if (!mounted) return;
      if (imgs.isNotEmpty) {
        setState(() => nuevasImagenes.addAll(imgs));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error seleccionando imágenes: $e')));
    }
  }

  DateTime? _parseDate(String value) {
    try {
      return _dateFormat.parseStrict(value.trim());
    } catch (_) {
      return null;
    }
  }

  // Provides a consistent card-like wrapper for grouped form fields.
  Widget _buildSection({
    required BuildContext context,
    required String title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildImagenesPreview() {
    final total = imagenesExistentes.length + nuevasImagenes.length;
    if (total == 0) return const SizedBox.shrink();

    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: total,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, idx) {
          if (idx < imagenesExistentes.length) {
            final url = imagenesExistentes[idx];
            final display =
                url.startsWith('/') ? ApiService.baseUrl + url : url;
            return Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(display,
                      width: 140, height: 100, fit: BoxFit.cover),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: GestureDetector(
                    onTap: () {
                      setState(() => imagenesExistentes.removeAt(idx));
                    },
                    child: Container(
                      color: Colors.black54,
                      padding: const EdgeInsets.all(4),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 16),
                    ),
                  ),
                )
              ],
            );
          } else {
            final nidx = idx - imagenesExistentes.length;
            final f = nuevasImagenes[nidx];
            return Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(File(f.path),
                      width: 140, height: 100, fit: BoxFit.cover),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: GestureDetector(
                    onTap: () => setState(() => nuevasImagenes.removeAt(nidx)),
                    child: Container(
                      color: Colors.black54,
                      padding: const EdgeInsets.all(4),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 16),
                    ),
                  ),
                )
              ],
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF1BD1C2);
    const overlayColor = Color(0xFF101D32);
    final baseTheme = Theme.of(context);
    const fieldTextStyle = TextStyle(color: Colors.black87, fontSize: 15);

    final themed = baseTheme.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: baseTheme.colorScheme.copyWith(
        primary: accentColor,
        secondary: accentColor,
        surface: overlayColor,
        surfaceContainerHigh: overlayColor.withOpacity(0.88),
        surfaceContainerHighest: const Color(0xFF18263A),
        onPrimary: const Color(0xFF062026),
        onSurface: Colors.white,
        onSurfaceVariant: Colors.white70,
        brightness: Brightness.dark,
      ),
      textTheme: baseTheme.textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      iconTheme: const IconThemeData(color: Colors.white70),
      appBarTheme: baseTheme.appBarTheme.copyWith(
        backgroundColor: const Color(0xFF0B1626).withOpacity(0.95),
        elevation: 0,
        titleTextStyle: baseTheme.textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: Colors.white70),
      ),
      tabBarTheme: baseTheme.tabBarTheme.copyWith(
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(color: accentColor, width: 3),
        ),
        labelColor: accentColor,
        unselectedLabelColor: Colors.white70,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: const Color(0xFF062026),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accentColor),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accentColor,
          side: const BorderSide(color: accentColor, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(color: Colors.black54),
        floatingLabelStyle: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: const TextStyle(color: Colors.black45),
        suffixIconColor: Colors.black45,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF1BD1C2), width: 1.1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: accentColor, width: 1.8),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF1BD1C2), width: 1.1),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
      dialogTheme: baseTheme.dialogTheme.copyWith(
        backgroundColor: overlayColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: baseTheme.textTheme.titleMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: baseTheme.textTheme.bodyMedium?.copyWith(
          color: Colors.white70,
        ),
      ),
      snackBarTheme: baseTheme.snackBarTheme.copyWith(
        backgroundColor: overlayColor.withOpacity(0.96),
        contentTextStyle:
            baseTheme.textTheme.bodyMedium?.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
      dividerColor: Colors.white24,
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: accentColor),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: accentColor,
        selectionColor: Color(0x661BD1C2),
        selectionHandleColor: accentColor,
      ),
    );

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF02060F), Color(0xFF0B1F36)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -140,
            right: -90,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentColor.withOpacity(0.16), Colors.transparent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -160,
            left: -120,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Theme(
            data: themed,
            child: DefaultTabController(
              length: 3,
              child: Scaffold(
                backgroundColor: Colors.transparent,
                appBar: AppBar(
                  title: Text(widget.consulta == null
                      ? 'Nueva Consulta'
                      : 'Editar Consulta'),
                  bottom: const TabBar(
                    tabs: [
                      Tab(text: 'Motivo'),
                      Tab(text: 'Examen físico'),
                      Tab(text: 'Diagnóstico'),
                    ],
                  ),
                ),
                body: cargando
                    ? const Center(
                        child: CircularProgressIndicator(),
                      )
                    : Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            Expanded(
                              child: TabBarView(
                                children: [
                                  SingleChildScrollView(
                                    padding: const EdgeInsets.fromLTRB(
                                        18, 18, 18, 26),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        _buildSection(
                                          context: context,
                                          title: 'Detalles de la consulta',
                                          children: [
                                            TextFormField(
                                              controller: motivoCtrl,
                                              style: fieldTextStyle,
                                              decoration: const InputDecoration(
                                                labelText: 'Motivo de consulta',
                                              ),
                                              validator: (v) =>
                                                  v == null || v.isEmpty
                                                      ? 'Ingrese motivo'
                                                      : null,
                                              textInputAction:
                                                  TextInputAction.next,
                                            ),
                                            const SizedBox(height: 14),
                                            TextFormField(
                                              controller: fechaCtrl,
                                              readOnly: true,
                                              style: fieldTextStyle,
                                              decoration: const InputDecoration(
                                                labelText: 'Fecha',
                                                suffixIcon: Icon(Icons.event),
                                              ),
                                              onTap: () {
                                                FocusScope.of(context)
                                                    .unfocus();
                                                _pickDate();
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  SingleChildScrollView(
                                    padding: const EdgeInsets.fromLTRB(
                                        18, 18, 18, 26),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        _buildSection(
                                          context: context,
                                          title: 'Signos vitales',
                                          children: [
                                            LayoutBuilder(
                                              builder:
                                                  (layoutContext, constraints) {
                                                const spacing = 12.0;
                                                final isWide =
                                                    constraints.maxWidth > 520;
                                                final fieldWidth = isWide
                                                    ? (constraints.maxWidth -
                                                            spacing) /
                                                        2
                                                    : constraints.maxWidth;

                                                return Wrap(
                                                  spacing: spacing,
                                                  runSpacing: spacing,
                                                  children: [
                                                    SizedBox(
                                                      width: fieldWidth,
                                                      child: TextFormField(
                                                        controller: pesoCtrl,
                                                        style: fieldTextStyle,
                                                        decoration:
                                                            const InputDecoration(
                                                          labelText:
                                                              'Peso (kg)',
                                                        ),
                                                        keyboardType:
                                                            const TextInputType
                                                                .numberWithOptions(
                                                                decimal: true),
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      width: fieldWidth,
                                                      child: TextFormField(
                                                        controller:
                                                            estaturaCtrl,
                                                        style: fieldTextStyle,
                                                        decoration:
                                                            const InputDecoration(
                                                          labelText:
                                                              'Estatura (m)',
                                                        ),
                                                        keyboardType:
                                                            const TextInputType
                                                                .numberWithOptions(
                                                                decimal: true),
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      width: fieldWidth,
                                                      child: TextFormField(
                                                        controller: imcCtrl,
                                                        style: fieldTextStyle,
                                                        decoration:
                                                            const InputDecoration(
                                                          labelText: 'IMC',
                                                        ),
                                                        keyboardType:
                                                            const TextInputType
                                                                .numberWithOptions(
                                                                decimal: true),
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      width: fieldWidth,
                                                      child: TextFormField(
                                                        controller: presionCtrl,
                                                        style: fieldTextStyle,
                                                        decoration:
                                                            const InputDecoration(
                                                          labelText:
                                                              'Presión arterial',
                                                        ),
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      width: fieldWidth,
                                                      child: TextFormField(
                                                        controller:
                                                            frecuenciaCardiacaCtrl,
                                                        style: fieldTextStyle,
                                                        decoration:
                                                            const InputDecoration(
                                                          labelText:
                                                              'Frecuencia cardiaca',
                                                        ),
                                                        keyboardType:
                                                            TextInputType
                                                                .number,
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      width: fieldWidth,
                                                      child: TextFormField(
                                                        controller:
                                                            frecuenciaRespiratoriaCtrl,
                                                        style: fieldTextStyle,
                                                        decoration:
                                                            const InputDecoration(
                                                          labelText:
                                                              'Frecuencia respiratoria',
                                                        ),
                                                        keyboardType:
                                                            TextInputType
                                                                .number,
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      width: fieldWidth,
                                                      child: TextFormField(
                                                        controller:
                                                            temperaturaCtrl,
                                                        style: fieldTextStyle,
                                                        decoration:
                                                            const InputDecoration(
                                                          labelText:
                                                              'Temperatura (°C)',
                                                        ),
                                                        keyboardType:
                                                            const TextInputType
                                                                .numberWithOptions(
                                                                decimal: true),
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  SingleChildScrollView(
                                    padding: const EdgeInsets.fromLTRB(
                                        18, 18, 18, 26),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        _buildSection(
                                          context: context,
                                          title: 'Diagnóstico y tratamiento',
                                          children: [
                                            TextFormField(
                                              controller: diagnosticoCtrl,
                                              style: fieldTextStyle,
                                              decoration: const InputDecoration(
                                                labelText: 'Diagnóstico',
                                              ),
                                              maxLines: 4,
                                            ),
                                            const SizedBox(height: 14),
                                            TextFormField(
                                              controller: tratamientoCtrl,
                                              style: fieldTextStyle,
                                              decoration: const InputDecoration(
                                                labelText: 'Tratamiento',
                                              ),
                                              maxLines: 4,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 18),
                                        _buildSection(
                                          context: context,
                                          title: 'Archivos e imágenes',
                                          children: [
                                            Row(
                                              children: [
                                                ElevatedButton.icon(
                                                  onPressed: _pickImages,
                                                  icon: const Icon(Icons
                                                      .photo_library_rounded),
                                                  label: const Text(
                                                      'Agregar imágenes'),
                                                ),
                                                const SizedBox(width: 12),
                                                if (imagenesExistentes
                                                        .isNotEmpty ||
                                                    nuevasImagenes.isNotEmpty)
                                                  Expanded(
                                                    child: Text(
                                                      '${imagenesExistentes.length + nuevasImagenes.length} imágenes seleccionadas',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodyMedium,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            if (imagenesExistentes.isEmpty &&
                                                nuevasImagenes.isEmpty)
                                              Text(
                                                'Aún no has agregado imágenes a esta consulta.',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                        color: Colors.white54),
                                              ),
                                            _buildImagenesPreview(),
                                          ],
                                        ),
                                        const SizedBox(height: 18),
                                        _buildSection(
                                          context: context,
                                          title: 'Receta médica',
                                          children: [
                                            TextFormField(
                                              controller: recetaCtrl,
                                              style: fieldTextStyle,
                                              decoration: const InputDecoration(
                                                labelText:
                                                    'Indicaciones para el paciente',
                                              ),
                                              maxLines: 4,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 24),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            onPressed: guardarConsulta,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                vertical: 16,
                                              ),
                                              child: Text(
                                                widget.consulta == null
                                                    ? 'Guardar consulta'
                                                    : 'Guardar cambios',
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
