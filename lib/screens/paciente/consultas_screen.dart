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
    return Scaffold(
      appBar: AppBar(title: const Text('Historial / Consultas')),
      floatingActionButton: FloatingActionButton(
        onPressed: _abrirAgregar,
        child: const Icon(Icons.add),
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : consultas.isEmpty
              ? const Center(child: Text('No hay consultas'))
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: consultas.length,
                    itemBuilder: (context, i) {
                      final c = consultas[i];
                      return Card(
                        elevation: 3,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c.motivo.isNotEmpty
                                              ? c.motivo
                                              : '(Sin motivo)',
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          formatoFecha(
                                              c.fecha.toIso8601String()),
                                          style: const TextStyle(
                                              color: Colors.grey, fontSize: 12),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 12,
                                          runSpacing: 6,
                                          children: [
                                            if (c.peso > 0)
                                              Text('Peso: ${c.peso} kg'),
                                            if (c.estatura > 0)
                                              Text('Estatura: ${c.estatura} m'),
                                            if (c.imc > 0)
                                              Text('IMC: ${c.imc}'),
                                            if (c.presion.isNotEmpty)
                                              Text('Presión: ${c.presion}'),
                                            if (c.frecuenciaCardiaca > 0)
                                              Text(
                                                  'FC: ${c.frecuenciaCardiaca}'),
                                            if (c.frecuenciaRespiratoria > 0)
                                              Text(
                                                  'FR: ${c.frecuenciaRespiratoria}'),
                                            if (c.temperatura > 0)
                                              Text('Temp: ${c.temperatura}°C'),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        if (c.diagnostico.isNotEmpty)
                                          Text('Diagnóstico: ${c.diagnostico}'),
                                        if (c.tratamiento.isNotEmpty)
                                          Text('Tratamiento: ${c.tratamiento}'),
                                        if (c.receta.isNotEmpty)
                                          Text('Receta: ${c.receta}'),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    children: [
                                      TextButton.icon(
                                        icon: const Icon(Icons.visibility,
                                            color: Colors.green),
                                        label: const Text('Ver detalle'),
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
                                        icon: const Icon(Icons.edit,
                                            color: Colors.blue),
                                        onPressed: () async {
                                          final edited =
                                              await Navigator.push<bool>(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  AgregarEditarConsultaScreen(
                                                      pacienteId:
                                                          widget.pacienteId,
                                                      consulta: c),
                                            ),
                                          );
                                          if (edited == true) await _cargar();
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red),
                                        onPressed: () async {
                                          final confirm =
                                              await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text('Confirmar'),
                                              content: const Text(
                                                  'Eliminar esta consulta?'),
                                              actions: [
                                                TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            ctx, false),
                                                    child: const Text('No')),
                                                TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            ctx, true),
                                                    child: const Text('Sí')),
                                              ],
                                            ),
                                          );
                                          if (confirm == true) {
                                            final ok = await ApiService
                                                .eliminarHistorial(c.id);
                                            if (ok) await _cargar();
                                          }
                                        },
                                      ),
                                    ],
                                  )
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (c.imagenes.isNotEmpty)
                                SizedBox(
                                  height: 100,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemBuilder: (ctx, idx) {
                                      final rawUrl = c.imagenes[idx];
                                      String displayUrl = rawUrl;
                                      if (rawUrl.startsWith('/')) {
                                        displayUrl =
                                            ApiService.baseUrl + rawUrl;
                                      }
                                      if (displayUrl.startsWith('http')) {
                                        return GestureDetector(
                                          onTap: () =>
                                              _openImage(context, displayUrl),
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: Image.network(displayUrl,
                                                width: 120,
                                                height: 100,
                                                fit: BoxFit.cover),
                                          ),
                                        );
                                      }
                                      return GestureDetector(
                                        onTap: () =>
                                            _openImage(context, rawUrl),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: Image.file(File(rawUrl),
                                              width: 120,
                                              height: 100,
                                              fit: BoxFit.cover),
                                        ),
                                      );
                                    },
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(width: 8),
                                    itemCount: c.imagenes.length,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
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
