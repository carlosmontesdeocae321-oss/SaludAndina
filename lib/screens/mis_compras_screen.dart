import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import '../services/api_services.dart';

class MisComprasScreen extends StatefulWidget {
  const MisComprasScreen({super.key});

  @override
  State<MisComprasScreen> createState() => _MisComprasScreenState();
}

class _MisComprasScreenState extends State<MisComprasScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = false;
  // per-compra loading state to prevent duplicate actions
  final Map<int, bool> _itemLoading = {};
  final Set<int> _promptedLinkPurchases = <int>{};

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final list = await ApiService.obtenerMisCompras();
    setState(() {
      _items = list;
      _loading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _autoPromptLinkingIfNeeded();
    });
  }

  Map<String, dynamic>? _parseExtra(dynamic raw) {
    if (raw == null) return null;
    try {
      if (raw is Map) {
        return Map<String, dynamic>.from(raw);
      }
      if (raw is String && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      }
    } catch (_) {}
    return null;
  }

  bool _hasDoctorAlreadyProvided(Map<String, dynamic>? extra) {
    if (extra == null) return false;

    bool containsDoctorId(Map<String, dynamic> data) {
      for (final entry in data.entries) {
        final key = entry.key.toString().toLowerCase();
        if (key.contains('doctor') && key.contains('vincul')) {
          final value = entry.value;
          if (value != null && value.toString().trim().isNotEmpty) {
            return true;
          }
        }
        if (key == 'doctor_id' || key == 'doctorid' || key == 'doctor') {
          final value = entry.value;
          if (value != null && value.toString().trim().isNotEmpty) {
            return true;
          }
        }
        if (entry.value is Map<String, dynamic>) {
          if (containsDoctorId(entry.value as Map<String, dynamic>)) {
            return true;
          }
        } else if (entry.value is String) {
          try {
            final nested = jsonDecode(entry.value as String);
            if (nested is Map<String, dynamic> && containsDoctorId(nested)) {
              return true;
            }
          } catch (_) {}
        }
      }
      return false;
    }

    if (containsDoctorId(extra)) return true;

    final metadata = extra['metadata'];
    if (metadata is Map<String, dynamic> && containsDoctorId(metadata)) {
      return true;
    }
    if (metadata is String) {
      try {
        final nested = jsonDecode(metadata);
        if (nested is Map<String, dynamic> && containsDoctorId(nested)) {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  int? _normalizeInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final sanitized = value.trim();
      if (sanitized.isEmpty) return null;
      return int.tryParse(sanitized);
    }
    return null;
  }

  double? _normalizeDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) {
      final sanitized = value.trim().replaceAll(',', '.');
      if (sanitized.isEmpty) return null;
      return double.tryParse(sanitized);
    }
    return null;
  }

  Color _statusAccentColor(String value) {
    final normalized = value.toLowerCase();
    switch (normalized) {
      case 'completed':
      case 'completado':
        return Colors.green.shade600;
      case 'pending':
      case 'pendiente':
        return Colors.orange.shade600;
      case 'rejected':
      case 'rechazado':
        return Colors.red.shade600;
      default:
        return Colors.blueGrey.shade600;
    }
  }

  Widget _buildInfoPill(BuildContext context, IconData icon, String text,
      {Color? foreground, Color? background}) {
    final theme = Theme.of(context);
    final fg = foreground ?? theme.colorScheme.onSurfaceVariant;
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

  Map<String, dynamic>? _extractMetadata(Map<String, dynamic>? extra) {
    if (extra == null) return null;
    Map<String, dynamic>? metadata;
    final raw = extra['metadata'];
    if (raw is Map<String, dynamic>) {
      metadata = Map<String, dynamic>.from(raw);
    } else if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          metadata = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }

    if (extra['metadata_raw'] is String) {
      final rawMeta = (extra['metadata_raw'] as String).trim();
      if (rawMeta.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawMeta);
          if (decoded is Map<String, dynamic>) {
            metadata ??= <String, dynamic>{};
            metadata.addEntries(decoded.entries);
          }
        } catch (_) {}
      }
    }

    metadata ??= <String, dynamic>{};
    const keysToCopy = [
      'tipo',
      'cantidad',
      'cantidadSolicitada',
      'quantity',
      'precioUnitario',
      'precio',
      'doctorId',
      'doctor_id',
      'usuarioId',
      'usuario_id',
      'clinicaId',
      'clinica_id',
      'clinicId',
      'clinic_id',
      'limiteActual',
      'limitePacientesActual',
      'totalPacientesAntesCompra',
      'totalPacientes',
      'permitidoAntesCompra',
    ];

    for (final key in keysToCopy) {
      if (!metadata.containsKey(key) && extra.containsKey(key)) {
        metadata[key] = extra[key];
      }
    }

    return metadata.isEmpty ? null : metadata;
  }

  String? _metadataTipo(Map<String, dynamic>? metadata) {
    final rawTipo = metadata == null ? null : metadata['tipo'];
    if (rawTipo == null) return null;
    return rawTipo.toString().toLowerCase();
  }

  Widget _buildInfoRow(IconData icon, String text, {Color? color}) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final foreground = color ?? theme.colorScheme.primary;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: foreground.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: foreground),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _autoPromptLinkingIfNeeded() {
    for (final compra in _items) {
      final rawStatus =
          (compra['status'] ?? compra['estado'] ?? '').toString().toLowerCase();
      if (rawStatus != 'completed' && rawStatus != 'completado') {
        continue;
      }
      final titulo = compra['titulo']?.toString().toLowerCase() ?? '';
      final isVincular = titulo.contains('vincul');
      if (!isVincular) continue;

      final compraIdInt = (compra['id'] is int)
          ? compra['id'] as int
          : int.tryParse(compra['id'].toString());
      if (compraIdInt == null) continue;
      if (_promptedLinkPurchases.contains(compraIdInt)) continue;

      final extra = _parseExtra(compra['extra_data']);
      if (_hasDoctorAlreadyProvided(extra)) {
        _promptedLinkPurchases.add(compraIdInt);
        continue;
      }

      _promptedLinkPurchases.add(compraIdInt);
      Future.microtask(() {
        if (!mounted) return;
        _startLinkingProcess(
          compra,
          extraData: extra,
          autoPrompt: true,
        );
      });
      break;
    }
  }

  Future<void> _startLinkingProcess(Map<String, dynamic> compra,
      {Map<String, dynamic>? extraData, bool autoPrompt = false}) async {
    if (!mounted) return;
    final parentContext = context;
    final messenger = ScaffoldMessenger.of(parentContext);

    final compraIdInt = (compra['id'] is int)
        ? compra['id'] as int
        : int.tryParse(compra['id'].toString());
    final controller = TextEditingController();

    final bool? confirmed = await showDialog<bool>(
      context: parentContext,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Vincular doctor'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (autoPrompt) ...[
                const Text(
                    'Tu compra fue aprobada. Ingresa el ID del doctor que deseas vincular a tu clínica.'),
                const SizedBox(height: 12),
              ] else ...[
                const Text(
                    'Ingresa el ID del doctor para completar la vinculación.'),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'ID del doctor',
                  hintText: 'Ejemplo: 1234',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isEmpty) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Ingresa un ID válido.')),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Vincular'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    if (confirmed != true) {
      if (autoPrompt) {
        messenger.showSnackBar(const SnackBar(
            content: Text(
                'Podrás completar la vinculación desde la sección "Mis compras".')));
      }
      return;
    }

    final doctorId = int.tryParse(controller.text.trim());
    if (doctorId == null) {
      messenger.showSnackBar(const SnackBar(content: Text('ID inválido')));
      return;
    }

    final me = await ApiService.obtenerMisDatos();
    if (!mounted) return;
    final clinicaRaw = me?['clinicaId'] ?? me?['clinica_id'];
    final clinicaId = clinicaRaw is int
        ? clinicaRaw
        : clinicaRaw == null
            ? null
            : int.tryParse(clinicaRaw.toString());

    if (clinicaId == null) {
      messenger.showSnackBar(const SnackBar(
          content: Text('No se encontró una clínica asociada a tu cuenta.')));
      return;
    }

    if (compraIdInt != null) {
      if (!mounted) return;
      setState(() => _itemLoading[compraIdInt] = true);
    }

    messenger.showSnackBar(
        const SnackBar(content: Text('Procesando vinculación...')));

    try {
      final res = await ApiService.vincularDoctorConCompra(doctorId, clinicaId);
      if (!mounted) return;
      if ((res['ok'] ?? false) == true) {
        messenger.showSnackBar(
            const SnackBar(content: Text('Doctor vinculado correctamente.')));
        if (compraIdInt != null) {
          final payload = Map<String, dynamic>.from(extraData ?? {});
          payload['doctor_vinculado_id'] = doctorId;
          payload['vinculacion_completada_en'] =
              DateTime.now().toIso8601String();
          try {
            await ApiService.enviarDatosCompra(compraIdInt, payload);
          } catch (e) {
            debugPrint(
                'No se pudo actualizar la compra con el doctor vinculado: $e');
          }
        }
        await _fetch();
      } else {
        final msg = res['error'] ?? 'Error al vincular doctor';
        messenger.showSnackBar(SnackBar(content: Text(msg.toString())));
      }
    } finally {
      if (compraIdInt != null) {
        if (mounted) {
          setState(() => _itemLoading.remove(compraIdInt));
        }
      }
    }
  }

  Widget _buildStatusChip(String status) {
    return Builder(
      builder: (context) {
        final normalized = status.toLowerCase();
        final accent = _statusAccentColor(normalized);
        String label;
        switch (normalized) {
          case 'completed':
          case 'completado':
            label = 'Completado';
            break;
          case 'pending':
          case 'pendiente':
            label = 'Pendiente';
            break;
          case 'rejected':
          case 'rechazado':
            label = 'Rechazado';
            break;
          default:
            label = status.isEmpty ? 'Desconocido' : status;
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withOpacity(0.35)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        );
      },
    );
  }

  String? _formatDate(dynamic raw) {
    if (raw == null) return null;
    try {
      final dt = DateTime.tryParse(raw.toString());
      if (dt == null) return null;
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return null;
    }
  }

  String _formatMonto(dynamic raw) {
    if (raw is num) {
      return raw.toStringAsFixed(2);
    }
    return raw?.toString() ?? '-';
  }

  Future<void> _openCompletarDatos(Map<String, dynamic> compra) async {
    if (!mounted) return;
    final parentContext = context;
    final messenger = ScaffoldMessenger.of(parentContext);

    final nombreCtrl = TextEditingController(
        text: compra['extra_data'] != null && compra['extra_data'] is Map
            ? compra['extra_data']['nombre_clinica'] ?? ''
            : '');
    final direccionCtrl = TextEditingController(
        text: compra['extra_data'] != null && compra['extra_data'] is Map
            ? compra['extra_data']['direccion'] ?? ''
            : '');
    final telefonoCtrl = TextEditingController(
        text: compra['extra_data'] != null && compra['extra_data'] is Map
            ? compra['extra_data']['telefono'] ?? ''
            : '');
    final usuarioCtrl = TextEditingController(
        text: compra['extra_data'] != null && compra['extra_data'] is Map
            ? compra['extra_data']['usuario'] ?? ''
            : '');
    final claveCtrl = TextEditingController();
    String? pickedImagePath;

    final result = await showDialog<bool>(
      context: parentContext,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, dialogSetState) => AlertDialog(
          title: Text('Completar datos - Compra #${compra['id']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Nombre de la clínica'),
                ),
                TextField(
                  controller: direccionCtrl,
                  decoration: const InputDecoration(labelText: 'Dirección'),
                ),
                TextField(
                  controller: telefonoCtrl,
                  decoration: const InputDecoration(labelText: 'Teléfono'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                      child: Text(pickedImagePath == null
                          ? 'No se ha seleccionado foto'
                          : pickedImagePath!.split('/').last)),
                  IconButton(
                      tooltip: 'Seleccionar foto',
                      onPressed: () async {
                        final ImagePicker picker = ImagePicker();
                        final XFile? img = await picker.pickImage(
                            source: ImageSource.gallery, imageQuality: 75);
                        if (img != null) {
                          dialogSetState(() {
                            pickedImagePath = img.path;
                          });
                        }
                      },
                      icon: const Icon(Icons.photo_library))
                ]),
                const SizedBox(height: 8),
                // If this purchase is for a clinic, usuario+clave are required
                Builder(builder: (bctx) {
                  final titulo =
                      compra['titulo']?.toString().toLowerCase() ?? '';
                  final isClinic =
                      titulo.contains('clinica') || titulo.contains('clínica');
                  return Column(children: [
                    TextField(
                      controller: usuarioCtrl,
                      decoration: InputDecoration(
                        labelText: isClinic
                            ? 'Usuario admin *'
                            : 'Usuario admin (opcional)',
                      ),
                    ),
                    TextField(
                      controller: claveCtrl,
                      decoration: InputDecoration(
                        labelText: isClinic
                            ? 'Clave admin *'
                            : 'Clave admin (opcional)',
                      ),
                      obscureText: true,
                    ),
                  ]);
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            ElevatedButton(
                onPressed: () async {
                  final titulo =
                      compra['titulo']?.toString().toLowerCase() ?? '';
                  final isClinic =
                      titulo.contains('clinica') || titulo.contains('clínica');
                  final payload = {
                    'nombre_clinica': nombreCtrl.text.trim(),
                    'direccion': direccionCtrl.text.trim(),
                    'telefono': telefonoCtrl.text.trim(),
                  };
                  if (isClinic) {
                    // require usuario+clave
                    if (usuarioCtrl.text.trim().isEmpty ||
                        claveCtrl.text.trim().isEmpty) {
                      messenger.showSnackBar(const SnackBar(
                          content: Text(
                              'Usuario y clave son obligatorios para crear la clínica')));
                      return;
                    }
                    payload['usuario'] = usuarioCtrl.text.trim();
                    payload['clave'] = claveCtrl.text.trim();
                  } else {
                    if (usuarioCtrl.text.trim().isNotEmpty &&
                        claveCtrl.text.trim().isNotEmpty) {
                      payload['usuario'] = usuarioCtrl.text.trim();
                      payload['clave'] = claveCtrl.text.trim();
                    }
                  }
                  final ok = await ApiService.enviarDatosCompra(
                      compra['id'], payload,
                      imagePath: pickedImagePath);
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx, ok);
                },
                child: const Text('Guardar'))
          ],
        ),
      ),
    );

    if (!mounted) return;
    if (result == true) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Datos guardados correctamente')));
      // Si se introdujo usuario/clave, recordar al usuario que puede iniciar sesión
      try {
        if (usuarioCtrl.text.trim().isNotEmpty) {
          messenger.showSnackBar(SnackBar(
              content: Text(
                  'Usuario creado/ solicitado: ${usuarioCtrl.text.trim()}. Usa esa cuenta para iniciar sesión.')));
        }
      } catch (_) {}
      _fetch();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis compras')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(
                  child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shopping_bag_outlined, size: 64),
                    SizedBox(height: 12),
                    Text('No tienes compras registradas')
                  ],
                ))
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  itemCount: _items.length,
                  itemBuilder: (itemContext, i) {
                    final messenger = ScaffoldMessenger.of(itemContext);
                    final c = _items[i];
                    final extra = _parseExtra(c['extra_data']);
                    final metadata = _extractMetadata(extra);
                    final metadataTipo = _metadataTipo(metadata);
                    final bool isClinicSlotPurchase =
                        metadataTipo == 'paciente_clinica';
                    final bool isIndividualSlotPurchase =
                        metadataTipo == 'paciente_individual';
                    final bool isSlotPurchase =
                        isClinicSlotPurchase || isIndividualSlotPurchase;

                    final rawStatus =
                        (c['status'] ?? c['estado'] ?? '').toString();
                    final statusVal = rawStatus.toLowerCase();
                    final tituloStr =
                        c['titulo']?.toString().toLowerCase() ?? '';
                    final isClinicPurchase = tituloStr.contains('clinica') ||
                        tituloStr.contains('clínica');
                    final bool isClinicCreationPurchase =
                        isClinicPurchase && !isSlotPurchase;
                    final isVincularPurchase = tituloStr.contains('vincul');
                    final bool doctorAlreadyLinked =
                        _hasDoctorAlreadyProvided(extra);
                    final compraIdInt = (c['id'] is int)
                        ? c['id'] as int
                        : int.tryParse(c['id'].toString());
                    final bool itemBusy = compraIdInt != null
                        ? (_itemLoading[compraIdInt] ?? false)
                        : false;

                    final montoRaw = c['monto'];
                    final String montoDisplay = _formatMonto(montoRaw);
                    final bool mostrarMoneda = montoRaw is num;
                    final String montoTexto = mostrarMoneda
                        ? '${String.fromCharCode(36)}$montoDisplay'
                        : montoDisplay;

                    final fecha = _formatDate(
                        c['created_at'] ?? c['createdAt'] ?? c['fecha']);

                    final hasComprobante = (extra != null &&
                            ((extra['comprobante'] != null) ||
                                (extra['imagen'] != null))) ||
                        (c['imagen_url'] != null) ||
                        (c['comprobante_url'] != null);

                    final int? cantidadSolicitada = _normalizeInt(
                      metadata?['cantidadSolicitada'] ??
                          metadata?['cantidad'] ??
                          metadata?['quantity'] ??
                          extra?['cantidad'] ??
                          c['cantidad'],
                    );
                    final int? limitePrevio = _normalizeInt(
                      metadata?['limitePacientesActual'] ??
                          metadata?['limiteActual'] ??
                          extra?['limite'] ??
                          extra?['limiteActual'],
                    );
                    final int? totalPacientesAntes = _normalizeInt(
                      metadata?['totalPacientesAntesCompra'] ??
                          metadata?['totalPacientes'] ??
                          extra?['totalPacientesAntesCompra'],
                    );
                    final double? precioUnitario = _normalizeDouble(
                      metadata?['precioUnitario'] ?? metadata?['precio'],
                    );
                    final int? limitePosterior =
                        (limitePrevio != null && cantidadSolicitada != null)
                            ? limitePrevio + cantidadSolicitada
                            : null;

                    final List<Widget> actions = [];
                    final List<Widget> slotInfoRows = [];
                    final bool compraCompletada = statusVal == 'completed';
                    final bool compraPendiente = statusVal == 'pending';

                    if (isSlotPurchase) {
                      if (cantidadSolicitada != null) {
                        slotInfoRows.add(_buildInfoRow(Icons.person_add_alt_1,
                            'Cupos solicitados: $cantidadSolicitada'));
                      }
                      if (precioUnitario != null) {
                        slotInfoRows.add(_buildInfoRow(Icons.price_change,
                            'Precio unitario registrado: \$${precioUnitario.toStringAsFixed(2)}'));
                      }
                      if (limitePrevio != null) {
                        final int target = limitePosterior ?? limitePrevio;
                        final String label = compraCompletada
                            ? 'Nuevo límite: $target pacientes'
                            : 'Límite tras aprobación: $target pacientes';
                        slotInfoRows.add(_buildInfoRow(
                          Icons.trending_up,
                          label,
                          color:
                              compraCompletada ? Colors.green : Colors.blueGrey,
                        ));
                        final String detalle = compraCompletada
                            ? 'Límite anterior: $limitePrevio pacientes'
                            : 'Límite actual antes de validar: '
                                '$limitePrevio pacientes';
                        slotInfoRows
                            .add(_buildInfoRow(Icons.timelapse, detalle));
                      }
                      if (totalPacientesAntes != null) {
                        slotInfoRows.add(_buildInfoRow(
                            Icons.people_outline,
                            'Pacientes registrados antes de la compra: '
                            '$totalPacientesAntes'));
                      }
                      if (slotInfoRows.isEmpty && compraCompletada) {
                        slotInfoRows.add(_buildInfoRow(
                          Icons.check_circle_outline,
                          'La compra fue aplicada. Si no ves los nuevos límites, refresca la vista principal.',
                          color: Colors.green,
                        ));
                      }
                      if (compraPendiente) {
                        slotInfoRows.add(_buildInfoRow(
                          Icons.hourglass_bottom,
                          'El equipo activará los cupos una vez validado el comprobante.',
                        ));
                      }
                    }

                    if (statusVal == 'completed') {
                      if (isSlotPurchase) {
                        actions.add(const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Text('Cupo aplicado automáticamente.'),
                        ));
                      } else if (isClinicCreationPurchase) {
                        final needsData = (extra == null ||
                            extra['nombre_clinica'] == null ||
                            extra['usuario'] == null);
                        actions.add(needsData
                            ? ElevatedButton(
                                onPressed: itemBusy
                                    ? null
                                    : () => _openCompletarDatos({
                                          'id': c['id'],
                                          'extra_data': extra,
                                          'titulo': c['titulo']
                                        }),
                                child: const Text('Completar datos'),
                              )
                            : const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child: Text('Datos enviados'),
                              ));
                      } else if (isVincularPurchase) {
                        actions.add(ElevatedButton(
                          onPressed: (itemBusy || doctorAlreadyLinked)
                              ? null
                              : () => _startLinkingProcess(
                                    c,
                                    extraData: extra,
                                    autoPrompt: false,
                                  ),
                          child: Text(doctorAlreadyLinked
                              ? 'Doctor vinculado'
                              : 'Vincular doctor'),
                        ));
                      } else {
                        actions.add((extra?.isEmpty ?? true)
                            ? ElevatedButton(
                                onPressed: itemBusy
                                    ? null
                                    : () => _openCompletarDatos({
                                          'id': c['id'],
                                          'extra_data': extra,
                                          'titulo': c['titulo']
                                        }),
                                child: const Text('Completar datos'),
                              )
                            : const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child: Text('Datos enviados'),
                              ));
                      }
                    } else if (statusVal == 'pending') {
                      if (hasComprobante) {
                        actions.add(const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Text('Comprobante enviado'),
                        ));
                      } else {
                        actions.add(ElevatedButton.icon(
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Subir comprobante'),
                          onPressed: itemBusy
                              ? null
                              : () async {
                                  final picker = ImagePicker();
                                  final XFile? picked = await picker.pickImage(
                                      source: ImageSource.gallery,
                                      maxWidth: 1600);
                                  if (picked == null) return;
                                  if (!mounted) return;
                                  if (compraIdInt != null) {
                                    if (mounted) {
                                      setState(() =>
                                          _itemLoading[compraIdInt] = true);
                                    }
                                  }
                                  messenger.showSnackBar(const SnackBar(
                                      content:
                                          Text('Subiendo comprobante...')));
                                  try {
                                    final res =
                                        await ApiService.subirComprobanteCompra(
                                            c['id'].toString(), picked.path);
                                    if (!mounted) return;
                                    if ((res['ok'] ?? false) == true) {
                                      messenger.showSnackBar(const SnackBar(
                                          content: Text('Comprobante subido')));
                                      await _fetch();
                                    } else {
                                      final msg = res['error'] ??
                                          res['body'] ??
                                          'Error al subir comprobante';
                                      messenger.showSnackBar(SnackBar(
                                          content: Text(msg.toString())));
                                    }
                                  } finally {
                                    if (mounted && compraIdInt != null) {
                                      setState(() {
                                        _itemLoading.remove(compraIdInt);
                                      });
                                    }
                                  }
                                },
                        ));
                      }
                    } else if (statusVal == 'rejected') {
                      actions.add(const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text('Compra rechazada'),
                      ));
                    }

                    Future<void> handleDelete() async {
                      if (compraIdInt == null) return;
                      final confirm = await showDialog<bool>(
                        context: itemContext,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Eliminar solicitud'),
                          content: const Text(
                              '¿Deseas eliminar esta solicitud de compra? Esta acción no se puede deshacer.'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancelar')),
                            ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Eliminar'))
                          ],
                        ),
                      );
                      if (confirm != true || !mounted) return;
                      setState(() => _itemLoading[compraIdInt] = true);
                      try {
                        final ok = await ApiService.cancelarCompraPromocion(
                            compraIdInt);
                        if (!mounted) return;
                        if (ok) {
                          messenger.showSnackBar(const SnackBar(
                              content:
                                  Text('Solicitud eliminada correctamente')));
                          await _fetch();
                        } else {
                          messenger.showSnackBar(const SnackBar(
                              content:
                                  Text('No se pudo eliminar la solicitud')));
                        }
                      } finally {
                        if (mounted) {
                          setState(() => _itemLoading.remove(compraIdInt));
                        }
                      }
                    }

                    final theme = Theme.of(itemContext);
                    final accentColor = _statusAccentColor(statusVal);
                    final infoChips = <Widget>[
                      _buildInfoPill(
                        itemContext,
                        Icons.attach_money,
                        'Monto: $montoTexto',
                        foreground: theme.colorScheme.primary,
                        background: theme.colorScheme.primary.withOpacity(0.12),
                      ),
                    ];
                    if (fecha != null) {
                      infoChips.add(_buildInfoPill(
                        itemContext,
                        Icons.event,
                        'Fecha: $fecha',
                      ));
                    }
                    if (hasComprobante) {
                      infoChips.add(_buildInfoPill(
                        itemContext,
                        Icons.receipt_long,
                        'Comprobante enviado',
                        foreground: theme.colorScheme.secondary,
                        background:
                            theme.colorScheme.secondary.withOpacity(0.14),
                      ));
                    }

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: accentColor,
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            c['titulo'] ??
                                                'Compra #${c['id'] ?? '-'}',
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            compraIdInt != null
                                                ? 'ID compra: $compraIdInt'
                                                : 'ID compra: -',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              color: theme
                                                  .colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    _buildStatusChip(rawStatus),
                                  ],
                                ),
                                if (infoChips.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: infoChips,
                                  ),
                                ],
                                if (slotInfoRows.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  ...slotInfoRows,
                                ],
                                const SizedBox(height: 16),
                                const Divider(),
                                const SizedBox(height: 12),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: actions.isEmpty
                                          ? Text(
                                              'Sin acciones pendientes en este momento.',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                color: theme.colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                            )
                                          : Wrap(
                                              spacing: 12,
                                              runSpacing: 12,
                                              children: actions,
                                            ),
                                    ),
                                    if (statusVal == 'pending' &&
                                        compraIdInt != null)
                                      OutlinedButton.icon(
                                        onPressed:
                                            itemBusy ? null : handleDelete,
                                        icon: const Icon(Icons.delete_outline),
                                        label: const Text('Eliminar'),
                                        style: OutlinedButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
