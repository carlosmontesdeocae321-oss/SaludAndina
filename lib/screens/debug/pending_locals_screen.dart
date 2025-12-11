import 'package:flutter/material.dart';
import '../../services/local_db.dart';

class PendingLocalsScreen extends StatefulWidget {
  const PendingLocalsScreen({super.key});

  @override
  State<PendingLocalsScreen> createState() => _PendingLocalsScreenState();
}

class _PendingLocalsScreenState extends State<PendingLocalsScreen> {
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
      final list = await LocalDb.getPending('patients');
      if (!mounted) return;
      setState(() {
        _items = list;
      });
    } catch (e) {
      debugPrint('Error cargando pendientes locales: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pendientes locales (debug)')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 48),
                        Center(
                            child: Text('No hay pacientes locales pendientes'))
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final rec = _items[i];
                        final data =
                            Map<String, dynamic>.from(rec['data'] ?? {});
                        final localId = rec['localId']?.toString() ?? '';
                        final cedula = data['cedula']?.toString() ?? '';
                        final nombres = data['nombres']?.toString() ?? '';
                        final apellidos = data['apellidos']?.toString() ?? '';
                        final status = rec['syncStatus']?.toString() ?? '';
                        final lastError = rec['lastError']?.toString() ?? '';
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text('$nombres $apellidos',
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                    Text(status,
                                        style: const TextStyle(
                                            color: Colors.orange)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text('Cédula: $cedula'),
                                const SizedBox(height: 6),
                                Text('LocalId: $localId',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.black54)),
                                if (lastError.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text('Error: $lastError',
                                      style: const TextStyle(
                                          color: Colors.redAccent)),
                                ]
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
