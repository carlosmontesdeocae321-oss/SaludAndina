import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../models/cita.dart';
import '../../services/api_services.dart';
import '../../services/local_db.dart';
import '../../route_refresh_mixin.dart';

class CitasScreen extends StatefulWidget {
  const CitasScreen({super.key});

  @override
  State<CitasScreen> createState() => _CitasScreenState();
}

class _CitasScreenState extends State<CitasScreen>
    with RouteRefreshMixin<CitasScreen> {
  List<Cita> citas = [];
  bool cargando = true;
  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      debugPrint('CitasScreen.initState - selectedDate=$selectedDate');
    }
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
    try {
      final loaded = await ApiService.obtenerCitas();
      citas = loaded;
      if (kDebugMode) {
        debugPrint(
            'CitasScreen._cargar - loaded ${citas.length} citas (remote)');
      }
    } catch (e) {
      // Fallback: load local citas when offline or remote fails
      if (kDebugMode)
        debugPrint('CitasScreen._cargar - remote load failed: $e');
      try {
        final localList = await LocalDb.getAllCitas();
        // Convert local map records into Cita model instances
        citas = localList.map<Cita>((m) {
          final data = Map<String, dynamic>.from(m['data'] ?? {});
          // Ensure required fields exist with sensible defaults
          final composite = <String, dynamic>{};
          composite.addAll(data);
          // if serverId exists, set id, else use localId prefixed
          if ((m['serverId'] ?? '').toString().isNotEmpty) {
            composite['id'] = m['serverId'].toString();
          } else {
            composite['id'] = 'local-${m['localId']?.toString() ?? ''}';
          }
          composite['localId'] = m['localId']?.toString();
          composite['syncStatus'] = m['syncStatus']?.toString();
          // normalize fecha/hora presence
          if (composite['fecha'] == null)
            composite['fecha'] = DateTime.now().toIso8601String();
          if (composite['hora'] == null) composite['hora'] = '00:00:00';
          // map paciente id
          composite['paciente_id'] =
              m['pacienteId'] ?? composite['paciente_id'];
          return Cita.fromJson(composite);
        }).toList();
        if (kDebugMode) {
          debugPrint(
              'CitasScreen._cargar - loaded ${citas.length} citas (local)');
        }
      } catch (e2) {
        if (kDebugMode)
          debugPrint('CitasScreen._cargar - local load failed: $e2');
        citas = [];
      }
    }
    setState(() => cargando = false);
  }

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Widget _buildCitaCard(Cita c) {
    final pacienteNombre = (c.nombres ?? '').trim().isNotEmpty
        ? '${c.nombres} ${c.apellidos ?? ''}'.trim()
        : 'Paciente desconocido';

    final estado = c.estado.toString().toLowerCase();
    Color estadoColor = Colors.grey;
    String estadoLabel = estado.isEmpty ? 'Pendiente' : estado;
    if (estado == 'confirmada') {
      estadoColor = Colors.green;
      estadoLabel = 'Confirmada';
    } else if (estado == 'cancelada') {
      estadoColor = Colors.red;
      estadoLabel = 'Cancelada';
    } else if (estado == 'pendiente' || estado.isEmpty) {
      estadoColor = Colors.amber.shade700;
      estadoLabel = 'Pendiente';
    }

    final timeLabel = '${c.hora} · ${_ymd(c.fecha)}';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor:
                  Theme.of(context).colorScheme.primary.withOpacity(0.12),
              child: Text(
                (c.nombres != null && c.nombres!.isNotEmpty)
                    ? c.nombres![0].toUpperCase()
                    : '?',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          pacienteNombre,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Chip(
                        backgroundColor: estadoColor.withOpacity(0.14),
                        label: Text(estadoLabel,
                            style: TextStyle(color: estadoColor)),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    c.motivo.isEmpty ? '(Sin motivo)' : c.motivo,
                    style: TextStyle(color: Colors.grey[700]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Text(timeLabel,
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 12)),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (c.estado != 'confirmada')
                            IconButton(
                              icon:
                                  const Icon(Icons.check, color: Colors.green),
                              tooltip: 'Confirmar',
                              onPressed: () async {
                                final body = {
                                  'paciente_id': c.pacienteId,
                                  'fecha': _ymd(c.fecha),
                                  'hora': c.hora,
                                  'motivo': c.motivo,
                                  'estado': 'confirmada',
                                };
                                final ok =
                                    await ApiService.actualizarCita(c.id, body);
                                if (ok) await _cargar();
                              },
                            ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: 'Eliminar',
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Eliminar cita'),
                                  content:
                                      const Text('¿Deseas eliminar esta cita?'),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('No')),
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('Sí')),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                final ok = await ApiService.eliminarCita(c.id);
                                if (ok) await _cargar();
                              }
                            },
                          ),
                        ],
                      )
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Calendar header removed by user request.

  // Calendar removed by user request.

  // Per-date list removed; we show the full list only.

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      debugPrint(
          'CitasScreen.build - cargando=$cargando citas=${citas.length}');
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Citas'),
        actions: const [],
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView.builder(
                itemCount: citas.length,
                padding: const EdgeInsets.only(top: 12, bottom: 24),
                itemBuilder: (context, i) => _buildCitaCard(citas[i]),
              ),
            ),
    );
  }
}
