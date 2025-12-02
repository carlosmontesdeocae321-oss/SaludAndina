import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class PagosAdminScreen extends StatefulWidget {
  final String baseUrl;
  const PagosAdminScreen({super.key, required this.baseUrl});

  @override
  State<PagosAdminScreen> createState() => _PagosAdminScreenState();
}

class _PagosAdminScreenState extends State<PagosAdminScreen> {
  List _items = [];
  bool _loading = false;

  Color _estadoAccent(String value) {
    final normalized = value.toLowerCase();
    if (normalized == 'accepted' || normalized == 'aprobado') {
      return Colors.green.shade600;
    }
    if (normalized == 'rejected' || normalized == 'rechazado') {
      return Colors.red.shade600;
    }
    if (normalized == 'pending' || normalized == 'pendiente') {
      return Colors.orange.shade600;
    }
    return Colors.blueGrey.shade600;
  }

  String _estadoLabel(String value) {
    final normalized = value.toLowerCase();
    switch (normalized) {
      case 'accepted':
      case 'aprobado':
        return 'Aprobado';
      case 'rejected':
      case 'rechazado':
        return 'Rechazado';
      case 'pending':
      case 'pendiente':
        return 'Pendiente';
      default:
        return value.trim().isEmpty ? 'Desconocido' : value;
    }
  }

  Widget _buildEstadoBadge(String estado) {
    final accent = _estadoAccent(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(0.35)),
      ),
      child: Text(
        _estadoLabel(estado),
        style: TextStyle(
          color: accent,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildMetaPill(BuildContext context, IconData icon, String text,
      {Color? background, Color? foreground}) {
    final theme = Theme.of(context);
    final fg = foreground ?? theme.colorScheme.onSurface;
    final bg = background ??
        theme.colorScheme.surfaceContainerHighest.withOpacity(0.6);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            text,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: fg, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return '-';
    }
    try {
      final parsed = DateTime.tryParse(raw);
      if (parsed == null) return raw;
      final local = parsed.toLocal();
      return DateFormat('dd/MM/yyyy · HH:mm').format(local);
    } catch (_) {
      return raw;
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }

  Future<void> _fetchItems() async {
    setState(() => _loading = true);
    final uri = Uri.parse('${widget.baseUrl}/api/pagos?estado=pending');
    final scaffold = ScaffoldMessenger.of(context);

    final prefs = await SharedPreferences.getInstance();
    final usuario = prefs.getString('usuario') ?? '';
    final clave = prefs.getString('clave') ?? '';
    final headers = <String, String>{};
    if (usuario.isNotEmpty) headers['x-usuario'] = usuario;
    if (clave.isNotEmpty) headers['x-clave'] = clave;

    final resp = await http.get(uri, headers: headers);
    if (!mounted) return;
    if (resp.statusCode == 200) {
      debugPrint('📌 PagosAdmin - body: ${resp.body}');
      setState(() {
        _items = jsonDecode(resp.body);
        _loading = false;
      });
    } else {
      debugPrint('📌 PagosAdmin - GET $uri -> ${resp.statusCode} ${resp.body}');
      scaffold.showSnackBar(
          SnackBar(content: Text('Error cargando pagos: ${resp.statusCode}')));
      setState(() {
        _items = [];
        _loading = false;
      });
    }
  }

  Future<void> _changeEstado(int id, String estado,
      {Map<String, dynamic>? metadata}) async {
    final uri = Uri.parse('${widget.baseUrl}/api/pagos/$id/estado');
    final scaffold = ScaffoldMessenger.of(context);
    final prefs = await SharedPreferences.getInstance();
    final usuario = prefs.getString('usuario') ?? '';
    final clave = prefs.getString('clave') ?? '';
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (usuario.isNotEmpty) headers['x-usuario'] = usuario;
    if (clave.isNotEmpty) headers['x-clave'] = clave;

    final payload = <String, dynamic>{'estado': estado};
    if ((metadata?.isNotEmpty ?? false)) {
      payload['metadata'] = metadata;
    }

    final resp =
        await http.patch(uri, headers: headers, body: jsonEncode(payload));
    if (!mounted) return;
    if (resp.statusCode == 200) {
      await _fetchItems();
    } else {
      debugPrint(
          '📌 PagosAdmin - PATCH $uri -> ${resp.statusCode} ${resp.body}');
      scaffold.showSnackBar(SnackBar(
          content: Text('Error actualizando estado: ${resp.statusCode}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Solicitudes de pago')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchItems,
              child: _items.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 120),
                        const Icon(Icons.receipt_long,
                            size: 72, color: Colors.grey),
                        const SizedBox(height: 8),
                        const Center(
                            child: Text('No hay solicitudes de pago pendientes',
                                style: TextStyle(fontSize: 16))),
                        const SizedBox(height: 16),
                        Center(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refrescar'),
                            onPressed: _fetchItems,
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemCount: _items.length,
                      itemBuilder: (context, i) {
                        final it = _items[i];
                        final productoTitulo = it['producto_titulo'];
                        final monto = it['monto']?.toString() ?? '-';
                        final dateRaw = it['creado_en'] ?? it['created_at'];
                        final formattedDate = _formatDate(dateRaw?.toString());
                        final estado = (it['estado'] ?? 'pending').toString();

                        final theme = Theme.of(context);
                        final accent = _estadoAccent(estado);
                        final messenger = ScaffoldMessenger.of(context);

                        Future<void> handleAccept() async {
                          final tituloLow =
                              (productoTitulo ?? '').toString().toLowerCase();

                          if (tituloLow.contains('vincul')) {
                            final proceed = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Confirmar pago'),
                                content: const Text(
                                    'El pago se aprobará y el dueño podrá ingresar el ID del doctor desde "Mis compras".'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancelar'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Aprobar'),
                                  ),
                                ],
                              ),
                            );

                            if (proceed != true) return;
                            await _changeEstado(
                                it['id'], 'accepted', metadata: {
                              'tipo': 'vinculacion_doctor_confirmada_por_admin'
                            });
                            if (!mounted) return;
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Pago aprobado. El dueño completará la vinculación.'),
                              ),
                            );
                            return;
                          }

                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Confirmar pago'),
                              content: const Text(
                                  '¿Deseas aceptar este comprobante y aplicar la compra?'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancelar'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Aceptar'),
                                ),
                              ],
                            ),
                          );
                          if (ok == true) {
                            await _changeEstado(it['id'], 'accepted');
                          }
                        }

                        Future<void> handleReject() async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Rechazar comprobante'),
                              content: const Text(
                                  '¿Deseas rechazar este comprobante?'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancelar'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red),
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Rechazar'),
                                ),
                              ],
                            ),
                          );
                          if (ok == true) {
                            await _changeEstado(it['id'], 'rejected');
                          }
                        }

                        final detailChips = <Widget>[
                          _buildMetaPill(
                            context,
                            Icons.attach_money,
                            'Monto: \$$monto',
                            foreground: accent,
                            background: accent.withOpacity(0.12),
                          ),
                          _buildMetaPill(
                            context,
                            Icons.person,
                            'Usuario: ${it['user_id'] ?? '-'}',
                          ),
                          _buildMetaPill(
                            context,
                            Icons.event,
                            'Creado: $formattedDate',
                          ),
                        ];

                        final actionButtons = <Widget>[
                          ElevatedButton.icon(
                            onPressed: handleAccept,
                            icon: const Icon(Icons.check),
                            label: const Text('Aprobar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: handleReject,
                            icon: const Icon(Icons.close),
                            label: const Text('Rechazar'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red.shade600,
                              side: BorderSide(color: Colors.red.shade200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ];

                        return Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 18,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  color: accent,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(18),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          child: it['imagen_url'] != null
                                              ? Image.network(
                                                  it['imagen_url'],
                                                  width: 76,
                                                  height: 76,
                                                  fit: BoxFit.cover,
                                                )
                                              : Container(
                                                  width: 76,
                                                  height: 76,
                                                  color: theme.colorScheme
                                                      .surfaceContainerHighest,
                                                  alignment: Alignment.center,
                                                  child: Icon(
                                                    Icons.receipt,
                                                    size: 36,
                                                    color: theme.colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                                ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                productoTitulo != null
                                                    ? '$productoTitulo'
                                                    : 'Pago #${it['id']}',
                                                style: theme
                                                    .textTheme.titleMedium
                                                    ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w700),
                                              ),
                                              const SizedBox(height: 8),
                                              Wrap(
                                                spacing: 12,
                                                runSpacing: 8,
                                                crossAxisAlignment:
                                                    WrapCrossAlignment.center,
                                                children: [
                                                  _buildEstadoBadge(estado),
                                                  _buildMetaPill(
                                                    context,
                                                    Icons.confirmation_num,
                                                    'ID: ${it['id'] ?? '-'}',
                                                    foreground: theme
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                    background: theme
                                                        .colorScheme
                                                        .surfaceContainerHighest
                                                        .withOpacity(0.5),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (detailChips.isNotEmpty) ...[
                                      const SizedBox(height: 16),
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 12,
                                        children: detailChips,
                                      ),
                                    ],
                                    const SizedBox(height: 16),
                                    const Divider(),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: actionButtons,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
