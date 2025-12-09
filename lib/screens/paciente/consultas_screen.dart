import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/consulta.dart';
import '../../services/api_services.dart';
import '../../route_refresh_mixin.dart';
import '../../utils/formato_fecha.dart';
// import '../historial/agregar_editar_consulta_screen.dart'; // antiguo editor (reemplazado)
import '../historial/consulta_detalle_screen.dart';
import '../clinica_editor/editor_tabs_screen.dart';

class ConsultasScreen extends StatefulWidget {
  final String pacienteId;
  const ConsultasScreen({super.key, required this.pacienteId});

  @override
  State<ConsultasScreen> createState() => _ConsultasScreenState();
}

class _ConsultasScreenState extends State<ConsultasScreen>
    with RouteRefreshMixin<ConsultasScreen> {
  bool cargando = true;
  List<Consulta> consultas = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() => cargando = true);
    try {
      final lista =
          await ApiService.obtenerConsultasPaciente(widget.pacienteId);
      if (!mounted) return;
      setState(() => consultas = lista);
    } catch (e) {
      if (mounted) setState(() => consultas = []);
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  Future<void> _abrirAgregar() async {
    final nuevo = await Navigator.push<Consulta?>(
      context,
      MaterialPageRoute(
          builder: (_) => EditorTabsScreen(pacienteId: widget.pacienteId)),
    );
    if (nuevo != null) await _cargar();
  }

  @override
  void onRouteRefreshed() {
    // Called by RouteRefreshMixin when returning to this route
    _cargar();
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
      child: Theme(
        data: themed,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: const Text('Historial')),
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
                      onRefresh: _cargar,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                        itemCount: consultas.length,
                        itemBuilder: (context, i) {
                          final c = consultas[i];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: overlayColor.withOpacity(0.95),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.04),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.4),
                                  blurRadius: 28,
                                  offset: const Offset(0, 18),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(18, 18, 12, 18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w700,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              formatoFecha(
                                                  c.fecha.toIso8601String()),
                                              style: const TextStyle(
                                                color: Colors.white70,
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
                                                if (c.frecuenciaCardiaca > 0)
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
                                                value: c.diagnostico),
                                            _buildDetailLine(
                                                title: 'Tratamiento',
                                                value: c.tratamiento),
                                            _buildDetailLine(
                                                title: 'Receta',
                                                value: c.receta),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          TextButton.icon(
                                            icon: Icon(Icons.visibility,
                                                size: 18,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary),
                                            label: Text('Ver detalle',
                                                style: TextStyle(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurface)),
                                            onPressed: () {
                                              Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                      builder: (_) =>
                                                          ConsultaDetalleScreen(
                                                              consulta: c)));
                                            },
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.edit,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary),
                                            tooltip: 'Editar consulta',
                                            onPressed: () async {
                                              final updated = await Navigator.push<
                                                      Consulta?>(
                                                  context,
                                                  MaterialPageRoute(
                                                      builder: (_) =>
                                                          EditorTabsScreen(
                                                              pacienteId: widget
                                                                  .pacienteId,
                                                              consulta: c)));
                                              if (updated != null) {
                                                await _cargar();
                                              }
                                            },
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.delete_outline,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .error),
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
                                                                '¿Eliminar esta consulta del historial?'),
                                                            actions: [
                                                              TextButton(
                                                                  onPressed: () =>
                                                                      Navigator.pop(
                                                                          ctx,
                                                                          false),
                                                                  child: const Text(
                                                                      'Cancelar')),
                                                              TextButton(
                                                                  onPressed: () =>
                                                                      Navigator.pop(
                                                                          ctx,
                                                                          true),
                                                                  child: const Text(
                                                                      'Eliminar')),
                                                            ],
                                                          ));
                                              if (confirm == true) {
                                                final ok = await ApiService
                                                    .eliminarHistorial(c.id);
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
                                            onTap: () =>
                                                _openImage(context, displayUrl),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: displayUrl
                                                      .startsWith('http')
                                                  ? Image.network(displayUrl,
                                                      width: 140,
                                                      height: 110,
                                                      fit: BoxFit.cover)
                                                  : Image.file(File(displayUrl),
                                                      width: 140,
                                                      height: 110,
                                                      fit: BoxFit.cover),
                                            ),
                                          );
                                          if (displayUrl.startsWith('http')) {
                                            return preview;
                                          }
                                          return GestureDetector(
                                            onTap: () =>
                                                _openImage(context, rawUrl),
                                            child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                child: Image.file(File(rawUrl),
                                                    width: 140,
                                                    height: 110,
                                                    fit: BoxFit.cover)),
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
    );
  }

  Widget _buildMetricChip({required String label}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surface.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.onSurface.withOpacity(0.06)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: cs.onSurface,
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
              color: Colors.white,
              fontSize: 12,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            display,
            style: TextStyle(
              color: isEmpty ? Colors.white70 : Colors.white,
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

  String _buildConsultaHtml(Consulta c) {
    final b = StringBuffer();
    b.writeln('<div>');
    b.writeln('<h3>Consulta</h3>');
    b.writeln('<p><strong>Motivo:</strong> ${c.motivo}</p>');
    b.writeln(
        '<p><strong>Fecha:</strong> ${formatoFecha(c.fecha.toIso8601String())}</p>');
    if (c.peso > 0) b.writeln('<p><strong>Peso:</strong> ${c.peso} kg</p>');
    if (c.estatura > 0) {
      b.writeln('<p><strong>Estatura:</strong> ${c.estatura} m</p>');
    }
    if (c.imc > 0) {
      b.writeln('<p><strong>IMC:</strong> ${c.imc.toStringAsFixed(2)}</p>');
    }
    if (c.presion.isNotEmpty) {
      b.writeln('<p><strong>Presión:</strong> ${c.presion}</p>');
    }
    if (c.frecuenciaCardiaca > 0) {
      b.writeln('<p><strong>FC:</strong> ${c.frecuenciaCardiaca}</p>');
    }
    if (c.frecuenciaRespiratoria > 0) {
      b.writeln('<p><strong>FR:</strong> ${c.frecuenciaRespiratoria}</p>');
    }
    if (c.temperatura > 0) {
      b.writeln('<p><strong>Temp:</strong> ${c.temperatura} °C</p>');
    }
    if (c.diagnostico.isNotEmpty) {
      b.writeln('<h4>Diagnóstico</h4><p>${c.diagnostico}</p>');
    }
    if (c.tratamiento.isNotEmpty) {
      b.writeln('<h4>Tratamiento</h4><p>${c.tratamiento}</p>');
    }
    if (c.receta.isNotEmpty) b.writeln('<h4>Receta</h4><p>${c.receta}</p>');
    if (c.imagenes.isNotEmpty) {
      b.writeln('<h4>Imágenes</h4>');
      for (var raw in c.imagenes) {
        var display = raw.toString();
        if (display.startsWith('/')) {
          display = ApiService.baseUrl + display;
        } else if (!display.startsWith('http') &&
            !display.startsWith('file:')) {
          // assume local absolute path -> make file URI
          display = Uri.file(display).toString();
        }
        b.writeln(
            '<p><img src="$display" style="max-width:360px;max-height:240px;"/></p>');
      }
    }
    b.writeln('</div>');
    return b.toString();
  }
}
