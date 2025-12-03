import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/consulta.dart';
import '../../services/api_services.dart';
import '../../route_refresh_mixin.dart';
import '../../utils/formato_fecha.dart';
import '../historial/agregar_editar_consulta_screen.dart';
import '../historial/consulta_detalle_screen.dart';

class ConsultasScreen extends StatefulWidget {
  final String pacienteId;
  const ConsultasScreen({super.key, required this.pacienteId});

  @override
  State<ConsultasScreen> createState() => _ConsultasScreenState();
}

class _ConsultasScreenState extends State<ConsultasScreen>
    with RouteRefreshMixin<ConsultasScreen> {
  List<Consulta> consultas = [];
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void onRouteRefreshed() {
    try {
      _cargar();
    } catch (_) {}
  }

  Future<void> _cargar() async {
    setState(() => cargando = true);
    consultas = await ApiService.obtenerConsultasPaciente(widget.pacienteId);
    debugPrint(
        '📌 Consultas cargadas para paciente ${widget.pacienteId}: ${consultas.length}');
    setState(() => cargando = false);
  }

  Future<void> _abrirAgregar() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AgregarEditarConsultaScreen(pacienteId: widget.pacienteId),
      ),
    );
    if (added == true) await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF1BD1C2);
    const overlayColor = Color(0xFF101D32);
    final baseTheme = Theme.of(context);

    final themed = baseTheme.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: baseTheme.colorScheme.copyWith(
        primary: accentColor,
        secondary: accentColor,
        surface: overlayColor,
        surfaceContainerHigh: overlayColor.withOpacity(0.88),
        onPrimary: const Color(0xFF062026),
        onSurface: Colors.white,
        onSurfaceVariant: Colors.white70,
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
      floatingActionButtonTheme: baseTheme.floatingActionButtonTheme.copyWith(
        backgroundColor: accentColor,
        foregroundColor: const Color(0xFF062026),
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
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: const Color(0xFF062026),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentColor,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accentColor,
          side: const BorderSide(color: accentColor, width: 1.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      dividerColor: Colors.white24,
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
            top: -120,
            right: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentColor.withOpacity(0.18), Colors.transparent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -180,
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
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                title: const Text('Historial / Consultas'),
              ),
              floatingActionButton: FloatingActionButton(
                onPressed: _abrirAgregar,
                child: const Icon(Icons.add),
              ),
              body: cargando
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                      ),
                    )
                  : consultas.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              'No hay consultas registradas aún.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          color: accentColor,
                          backgroundColor: const Color(0xFF0A1727),
                          onRefresh: _cargar,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                            itemCount: consultas.length,
                            itemBuilder: (context, i) {
                              final c = consultas[i];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: overlayColor.withOpacity(0.92),
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.05),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.4),
                                      blurRadius: 26,
                                      offset: const Offset(0, 14),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(18, 18, 12, 18),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  c.motivo.isNotEmpty
                                                      ? c.motivo
                                                      : 'Consulta sin motivo',
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  formatoFecha(c.fecha
                                                      .toIso8601String()),
                                                  style: const TextStyle(
                                                    color: Colors.white60,
                                                    fontSize: 12,
                                                    letterSpacing: 0.2,
                                                  ),
                                                ),
                                                const SizedBox(height: 10),
                                                Wrap(
                                                  spacing: 12,
                                                  runSpacing: 8,
                                                  children: [
                                                    if (c.peso > 0)
                                                      _buildMetricChip(
                                                          label:
                                                              'Peso: ${c.peso} kg'),
                                                    if (c.estatura > 0)
                                                      _buildMetricChip(
                                                          label:
                                                              'Estatura: ${c.estatura} m'),
                                                    if (c.imc > 0)
                                                      _buildMetricChip(
                                                          label:
                                                              'IMC: ${c.imc.toStringAsFixed(2)}'),
                                                    if (c.presion.isNotEmpty)
                                                      _buildMetricChip(
                                                          label:
                                                              'Presión: ${c.presion}'),
                                                    if (c.frecuenciaCardiaca >
                                                        0)
                                                      _buildMetricChip(
                                                          label:
                                                              'FC: ${c.frecuenciaCardiaca}'),
                                                    if (c.frecuenciaRespiratoria >
                                                        0)
                                                      _buildMetricChip(
                                                          label:
                                                              'FR: ${c.frecuenciaRespiratoria}'),
                                                    if (c.temperatura > 0)
                                                      _buildMetricChip(
                                                          label:
                                                              'Temp: ${c.temperatura}°C'),
                                                  ],
                                                ),
                                                const SizedBox(height: 12),
                                                _buildDetailLine(
                                                  title: 'Diagnóstico',
                                                  value: c.diagnostico,
                                                ),
                                                _buildDetailLine(
                                                  title: 'Tratamiento',
                                                  value: c.tratamiento,
                                                ),
                                                _buildDetailLine(
                                                  title: 'Receta',
                                                  value: c.receta,
                                                ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              TextButton.icon(
                                                icon: const Icon(
                                                  Icons.visibility,
                                                  size: 18,
                                                ),
                                                label:
                                                    const Text('Ver detalle'),
                                                onPressed: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          ConsultaDetalleScreen(
                                                              consulta: c),
                                                    ),
                                                  );
                                                },
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.edit,
                                                  color: accentColor,
                                                ),
                                                tooltip: 'Editar consulta',
                                                onPressed: () async {
                                                  final edited = await Navigator
                                                      .push<bool>(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          AgregarEditarConsultaScreen(
                                                              pacienteId: widget
                                                                  .pacienteId,
                                                              consulta: c),
                                                    ),
                                                  );
                                                  if (edited == true) {
                                                    await _cargar();
                                                  }
                                                },
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                  color: Colors.redAccent,
                                                ),
                                                tooltip: 'Eliminar consulta',
                                                onPressed: () async {
                                                  final confirm =
                                                      await showDialog<bool>(
                                                    context: context,
                                                    builder: (ctx) =>
                                                        AlertDialog(
                                                      title: const Text(
                                                          'Confirmar'),
                                                      content: const Text(
                                                        '¿Eliminar esta consulta del historial?',
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                  ctx, false),
                                                          child: const Text(
                                                              'Cancelar'),
                                                        ),
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                  ctx, true),
                                                          child: const Text(
                                                              'Eliminar'),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                  if (confirm == true) {
                                                    final ok = await ApiService
                                                        .eliminarHistorial(
                                                            c.id);
                                                    if (ok) await _cargar();
                                                  }
                                                },
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      if (c.imagenes.isNotEmpty) ...[
                                        const SizedBox(height: 14),
                                        SizedBox(
                                          height: 110,
                                          child: ListView.separated(
                                            scrollDirection: Axis.horizontal,
                                            itemBuilder: (ctx, idx) {
                                              final rawUrl = c.imagenes[idx];
                                              String displayUrl = rawUrl;
                                              if (rawUrl.startsWith('/')) {
                                                displayUrl =
                                                    ApiService.baseUrl + rawUrl;
                                              }
                                              final preview = GestureDetector(
                                                onTap: () => _openImage(
                                                    context, displayUrl),
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  child: displayUrl
                                                          .startsWith('http')
                                                      ? Image.network(
                                                          displayUrl,
                                                          width: 140,
                                                          height: 110,
                                                          fit: BoxFit.cover,
                                                        )
                                                      : Image.file(
                                                          File(displayUrl),
                                                          width: 140,
                                                          height: 110,
                                                          fit: BoxFit.cover,
                                                        ),
                                                ),
                                              );

                                              if (displayUrl
                                                  .startsWith('http')) {
                                                return preview;
                                              }
                                              return GestureDetector(
                                                onTap: () =>
                                                    _openImage(context, rawUrl),
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  child: Image.file(
                                                    File(rawUrl),
                                                    width: 140,
                                                    height: 110,
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                              );
                                            },
                                            separatorBuilder: (_, __) =>
                                                const SizedBox(width: 10),
                                            itemCount: c.imagenes.length,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip({required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 13,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildDetailLine({required String title, required String value}) {
    final trimmed = value.trim();
    final isEmpty = trimmed.isEmpty;
    final display = isEmpty ? 'Sin registrar' : trimmed;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            display,
            style: TextStyle(
              color: isEmpty ? Colors.white38 : Colors.white,
              fontWeight: isEmpty ? FontWeight.w500 : FontWeight.w600,
              height: 1.32,
            ),
          ),
        ],
      ),
    );
  }

  void _openImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(8),
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: InteractiveViewer(
            panEnabled: true,
            minScale: 0.5,
            maxScale: 4.0,
            child: url.startsWith('http')
                ? Image.network(url)
                : Image.file(File(url)),
          ),
        ),
      ),
    );
  }
}
