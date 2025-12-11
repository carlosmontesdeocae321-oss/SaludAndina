import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ConsultasDumpScreen extends StatefulWidget {
  const ConsultasDumpScreen({super.key});

  @override
  State<ConsultasDumpScreen> createState() => _ConsultasDumpScreenState();
}

class _ConsultasDumpScreenState extends State<ConsultasDumpScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // Fetch all consultas regardless of status
      final all = await _readAllConsultas();
      if (!mounted) return;
      setState(() {
        _items = all;
      });
    } catch (e) {
      debugPrint('Error cargando consultas locales: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _readAllConsultas() async {
    // Reuse LocalDb internals by calling getConsultasByPacienteId for a hacky
    // but reliable read: instead open the box and iterate all keys.
    final out = <Map<String, dynamic>>[];
    try {
      final box = await Hive.box('consultas_box');
      for (final key in box.keys) {
        final v = box.get(key);
        if (v is Map)
          out.add(Map<String, dynamic>.from(v.cast<String, dynamic>()));
      }
    } catch (e) {
      debugPrint('consultas_dump read error: $e');
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Debug: Consultas (dump)')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('No hay consultas locales'))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final rec = _items[i];
                    final localId = rec['localId']?.toString() ?? '';
                    final serverId = rec['serverId']?.toString() ?? '';
                    final status = rec['syncStatus']?.toString() ?? '';
                    final data = Map<String, dynamic>.from(rec['data'] ?? {});
                    final fecha = data['fecha']?.toString() ?? '';
                    final motivo = data['motivo']?.toString() ??
                        data['motivo_consulta']?.toString() ??
                        '';
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                    child: Text(
                                        motivo.isNotEmpty
                                            ? motivo
                                            : 'Sin motivo',
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600))),
                                Text(status)
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text('Fecha: $fecha'),
                            const SizedBox(height: 6),
                            Text('LocalId: $localId'),
                            const SizedBox(height: 6),
                            Text('ServerId: $serverId'),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
