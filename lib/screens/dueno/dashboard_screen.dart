import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/api_services.dart';
import '../../utils/local_clinic_overrides.dart';
import '../../route_observer.dart';

class DashboardDuenoScreen extends StatefulWidget {
  const DashboardDuenoScreen({super.key});

  @override
  State<DashboardDuenoScreen> createState() => _DashboardDuenoScreenState();
}

class _DashboardDuenoScreenState extends State<DashboardDuenoScreen>
    with RouteAware {
  Map<String, dynamic>? stats;
  bool loading = true;
  int? clinicaId;
  String? clinicaNombre;
  bool _isOwner = false;
  Map<String, dynamic>? _misDatos;
  bool _canEditCapacity = false;
  Map<String, dynamic>? _clinicPerfil;
  bool _updatingClinic = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final modal = ModalRoute.of(context);
    if (modal != null) {
      routeObserver.subscribe(this, modal);
    }
  }

  @override
  void dispose() {
    try {
      routeObserver.unsubscribe(this);
    } catch (_) {}
    super.dispose();
  }

  @override
  void didPopNext() {
    // User returned to this screen; refresh data
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => loading = true);

    final datos = await ApiService.obtenerMisDatos();

    bool owner = false;
    try {
      owner = (datos?['dueno'] == true) ||
          (datos?['rol'] == 'dueno') ||
          (datos?['rol'] == 'owner') ||
          (datos?['rol'] == 'clinica');
    } catch (_) {
      owner = false;
    }

    bool canEditCapacity = false;
    try {
      final plan = datos?['plan'];
      final extra = datos?['extra'];
      final limite = datos?['limite'];
      bool hasPurchasedSlots = false;
      if (plan is Map && plan['pacientes_max'] != null) {
        final pm = plan['pacientes_max'];
        final pmv = pm is int ? pm : int.tryParse(pm.toString());
        if ((pmv ?? 0) > 20) hasPurchasedSlots = true;
      }
      if (!hasPurchasedSlots && extra is int && extra > 0) {
        hasPurchasedSlots = true;
      }
      if (!hasPurchasedSlots && limite != null) {
        final lv = limite is int ? limite : int.tryParse(limite.toString());
        if ((lv ?? 0) > 20) hasPurchasedSlots = true;
      }
      canEditCapacity = owner && hasPurchasedSlots;
    } catch (_) {
      canEditCapacity = false;
    }

    final rawId = datos?['clinicaId'] ?? datos?['clinica_id'];
    final resolvedClinicaId = rawId is int
        ? rawId
        : (rawId != null ? int.tryParse(rawId.toString()) : null);

    String? resolvedClinicaNombre = datos?['clinica_nombre'] ??
        datos?['clinicaName'] ??
        datos?['clinica']?.toString();

    Map<String, dynamic>? clinicPerfil;
    if (resolvedClinicaId != null) {
      try {
        final fetched = await ApiService.obtenerClinica(resolvedClinicaId);
        if (fetched != null) {
          clinicPerfil = Map<String, dynamic>.from(fetched);
          final fetchedName = clinicPerfil['nombre']?.toString();
          if (fetchedName != null && fetchedName.trim().isNotEmpty) {
            resolvedClinicaNombre = fetchedName;
          }
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _isOwner = owner;
      _misDatos = datos;
      _canEditCapacity = canEditCapacity;
      clinicaId = resolvedClinicaId;
      clinicaNombre = resolvedClinicaNombre;
      if (clinicPerfil != null) {
        _clinicPerfil = clinicPerfil;
      }
      stats = null;
    });

    if (resolvedClinicaId == null) {
      setState(() => loading = false);
      return;
    }

    final hasMisDatosCounts = (datos?['totalPacientes'] != null) ||
        (datos?['plan'] is Map) ||
        (datos?['limite'] != null) ||
        (datos?['pacientes'] != null);

    if (hasMisDatosCounts) {
      final maybePatients = datos?['totalPacientes'] ??
          datos?['pacientes'] ??
          datos?['total_pacientes'];
      final maybeLimit = datos?['limite'] ??
          ((datos?['plan'] is Map)
              ? (datos?['plan']['pacientes_max'] ??
                  datos?['plan']['pacientes_max'])
              : null);

      final clinicInfo = _mergeClinicMaps({
        'nombre': resolvedClinicaNombre ?? clinicaNombre ?? 'Mi Clínica',
        'direccion': datos?['clinica_direccion'] ?? datos?['direccion'],
        'telefono_contacto':
            datos?['telefono_contacto'] ?? datos?['telefonoClinica'],
      });

      setState(() {
        stats = {
          'patients': maybePatients ?? '-',
          'slots_total': maybeLimit ?? '-',
          'clinic': clinicInfo ??
              {'nombre': resolvedClinicaNombre ?? clinicaNombre ?? 'Mi Clínica'}
        };
        loading = false;
      });

      try {
        final doctoresList = datos?['doctores'];
        if (doctoresList is List) {
          stats?['doctors'] = doctoresList.length;
        } else if (doctoresList is Iterable) {
          stats?['doctors'] = doctoresList.length;
        }
      } catch (_) {}

      try {
        final clinicIdForStats = resolvedClinicaId;
        ApiService.obtenerCitas().then((all) {
          final hoy = DateTime.now();
          final filtered = all.where((c) {
            try {
              final cid = c.clinicaId;
              if (cid != null && cid != clinicIdForStats) {
                return false;
              }
              final dt = c.fecha.toLocal();
              return dt.year == hoy.year &&
                  dt.month == hoy.month &&
                  dt.day == hoy.day;
            } catch (_) {
              return false;
            }
          }).toList();
          if (!mounted) return;
          setState(() {
            stats?['appointments_today'] = filtered.length;
          });
        });
      } catch (_) {}

      _computeAvailability();
      return;
    }

    final statsResponse =
        await ApiService.obtenerEstadisticasClinica(resolvedClinicaId);

    if (statsResponse != null) {
      final clinicInfo = _mergeClinicMaps(
        statsResponse['clinic'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(statsResponse['clinic'])
            : null,
      );
      setState(() {
        stats = Map<String, dynamic>.from(statsResponse);
        if (clinicInfo != null) {
          stats!['clinic'] = clinicInfo;
          _clinicPerfil ??= clinicInfo;
          clinicaNombre = clinicInfo['nombre']?.toString() ?? clinicaNombre;
        }
        loading = false;
      });
      _computeAvailability();
      return;
    }

    final localClinic = _clinicPerfil ??
        await LocalClinicOverrides.loadForClinic(resolvedClinicaId);

    if (localClinic != null) {
      final clinicMap = Map<String, dynamic>.from(localClinic);
      final mergedClinic = _mergeClinicMaps(clinicMap) ?? clinicMap;
      clinicaNombre = mergedClinic['nombre']?.toString() ?? clinicaNombre;

      setState(() {
        stats = {
          'patients': mergedClinic['patients'] ?? '-',
          'doctors': mergedClinic['doctors'] ?? '-',
          'slots_total': mergedClinic['slots_total'] ?? '-',
          'clinic': mergedClinic,
        };
        if (mergedClinic.isNotEmpty) {
          _clinicPerfil = mergedClinic;
        }
        loading = false;
      });

      _computeAvailability();
      return;
    }

    if (datos != null) {
      final maybePatients = datos['totalPacientes'] ??
          datos['total_pacientes'] ??
          datos['pacientes'] ??
          datos['patients'];
      final maybeLimit = datos['limite'] ??
          datos['limit'] ??
          (datos['plan'] is Map
              ? (datos['plan']['pacientes_max'] ??
                  datos['plan']['pacientes_max'])
              : null);
      final clinicInfo = _mergeClinicMaps({
        'nombre': resolvedClinicaNombre ?? clinicaNombre ?? 'Mi Clínica',
      });

      setState(() {
        stats = {
          'patients': maybePatients ?? '-',
          'slots_total': maybeLimit ?? '-',
          'clinic': clinicInfo ??
              {
                'nombre': resolvedClinicaNombre ?? clinicaNombre ?? 'Mi Clínica'
              },
        };
        loading = false;
      });

      _computeAvailability();
      return;
    }

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final clinicCard = _buildClinicProfileCard();

    return Scaffold(
      appBar: AppBar(
        title: Text(clinicaNombre ?? 'Dashboard - Dueño'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
            onPressed: _updatingClinic ? null : _load,
          )
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Clínica: ${clinicaNombre ?? clinicaId?.toString() ?? 'N/D'}',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (_isOwner)
                        ElevatedButton.icon(
                          onPressed: (_updatingClinic || clinicaId == null)
                              ? null
                              : _openClinicEditor,
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: Text(_clinicHasData()
                              ? 'Editar datos'
                              : 'Agregar datos'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (clinicCard != null) ...[
                    clinicCard,
                    const SizedBox(height: 16),
                  ],
                  Row(
                    children: [
                      _statCard(
                        'Pacientes',
                        stats?['patients']?.toString() ??
                            (stats == null
                                ? '-'
                                : stats?['patients']?.toString() ?? '-'),
                      ),
                      const SizedBox(width: 12),
                      _statCard('Citas Hoy',
                          stats?['appointments_today']?.toString() ?? '-'),
                      const SizedBox(width: 12),
                      _statCard(
                          'Doctores', stats?['doctors']?.toString() ?? '-'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Resumen rápido',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                        'Pacientes: ${stats?['patients'] ?? '-'}'),
                                    Row(
                                      children: [
                                        Text(
                                            'Capacidad: ${stats?['slots_total'] ?? '-'}'),
                                        const SizedBox(width: 8),
                                        if (_canEditCapacity)
                                          IconButton(
                                            icon: const Icon(Icons.edit,
                                                size: 18),
                                            tooltip: 'Editar capacidad local',
                                            onPressed: () async {
                                              final input = TextEditingController(
                                                  text:
                                                      (stats?['slots_total'] ??
                                                              '')
                                                          .toString());
                                              final ok = await showDialog<bool>(
                                                context: context,
                                                builder: (_) => AlertDialog(
                                                  title: const Text(
                                                      'Editar capacidad de pacientes'),
                                                  content: TextField(
                                                      controller: input,
                                                      keyboardType:
                                                          TextInputType.number,
                                                      decoration:
                                                          const InputDecoration(
                                                              labelText:
                                                                  'Capacidad total (pacientes)')),
                                                  actions: [
                                                    TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                context, false),
                                                        child: const Text(
                                                            'Cancelar')),
                                                    ElevatedButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                context, true),
                                                        child: const Text(
                                                            'Guardar')),
                                                  ],
                                                ),
                                              );
                                              if (ok == true) {
                                                final v = int.tryParse(
                                                    input.text.trim());
                                                if (v != null &&
                                                    clinicaId != null) {
                                                  await LocalClinicOverrides
                                                      .saveForClinic(
                                                          clinicaId!, {
                                                    'slots_total': v,
                                                    'patients':
                                                        stats?['patients']
                                                  });
                                                  final patients = _castToInt(
                                                      stats?['patients']);
                                                  setState(() {
                                                    stats?['slots_total'] = v;
                                                    stats?['availablePatients'] =
                                                        v - patients;
                                                    stats?['atLimit'] =
                                                        patients >= v;
                                                  });
                                                }
                                              }
                                            },
                                          )
                                        else
                                          const Padding(
                                            padding: EdgeInsets.only(left: 8.0),
                                            child: Text(
                                                '(Calculado según plan o configuración del sistema)',
                                                style: TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 12)),
                                          )
                                      ],
                                    )
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (stats?['atLimit'] == true)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Row(
                                      children: [
                                        Chip(
                                          backgroundColor: Colors.red.shade100,
                                          label: const Row(
                                            children: [
                                              Icon(Icons.warning_amber_rounded,
                                                  color: Colors.red, size: 16),
                                              SizedBox(width: 6),
                                              Text('Límite alcanzado',
                                                  style: TextStyle(
                                                      color: Colors.red)),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Expanded(
                                            child: Text(
                                                'La clínica alcanzó su límite de pacientes. Considera actualizar el plan.'))
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Text(
                                'Ingresos (periodo): ${stats?['revenue'] ?? '-'}'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Text(
                                'Doctores vinculados: ${stats?['doctors_list']?.length ?? stats?['doctors'] ?? '-'} (ver pantalla de gestión para más)'),
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
    );
  }

  Future<void> _openClinicEditor() async {
    if (clinicaId == null) return;

    final data = _currentClinicData();
    final direccionController =
        TextEditingController(text: data['direccion']?.toString() ?? '');
    final telefonoController = TextEditingController(
        text: data['telefono_contacto']?.toString() ?? '');
    final String? initialImageUrl = data['imagen_url']?.toString();

    XFile? pickedImage;
    bool removeImage = false;
    bool saving = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Widget preview;
            if (pickedImage != null) {
              preview = ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(pickedImage!.path),
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                ),
              );
            } else {
              final previewUrl =
                  removeImage ? null : _resolveClinicImageUrl(initialImageUrl);
              preview = previewUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        previewUrl,
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _clinicPlaceholderAvatar(size: 120, iconSize: 40),
                      ),
                    )
                  : _clinicPlaceholderAvatar(size: 120, iconSize: 40);
            }

            return AlertDialog(
              title: const Text('Actualizar datos de la clínica'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    preview,
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: saving
                              ? null
                              : () async {
                                  final picker = ImagePicker();
                                  final file = await picker.pickImage(
                                    source: ImageSource.gallery,
                                    imageQuality: 80,
                                    maxWidth: 1280,
                                  );
                                  if (file != null) {
                                    setModalState(() {
                                      pickedImage = file;
                                      removeImage = false;
                                    });
                                  }
                                },
                          icon: const Icon(Icons.photo_library_outlined),
                          label: Text(pickedImage == null
                              ? 'Seleccionar imagen'
                              : 'Cambiar imagen'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: saving
                              ? null
                              : () {
                                  setModalState(() {
                                    pickedImage = null;
                                    removeImage = true;
                                  });
                                },
                          child: const Text('Quitar imagen'),
                        )
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: direccionController,
                      enabled: !saving,
                      decoration: const InputDecoration(
                        labelText: 'Dirección',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: telefonoController,
                      enabled: !saving,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono de contacto',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: saving ? null : () => Navigator.pop(ctx, false),
                    child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final direccion = direccionController.text.trim();
                          final telefono = telefonoController.text.trim();
                          final shouldRemoveImage =
                              removeImage && pickedImage == null;
                          setModalState(() => saving = true);
                          if (mounted) {
                            setState(() => _updatingClinic = true);
                          }
                          final response =
                              await ApiService.actualizarPerfilClinica(
                            clinicaId: clinicaId!,
                            direccion: direccion.isNotEmpty ? direccion : null,
                            telefonoContacto:
                                telefono.isNotEmpty ? telefono : null,
                            imagenUrl: shouldRemoveImage ? '' : null,
                            imagenPath: pickedImage?.path,
                          );
                          if (mounted) {
                            setState(() => _updatingClinic = false);
                          }
                          setModalState(() => saving = false);
                          if (response['ok'] == true) {
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          } else {
                            final errorMessage = response['error'] ??
                                response['body'] ??
                                'No se pudo guardar los cambios';
                            _showSnack(errorMessage.toString(), error: true);
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      await _load();
      _showSnack('Datos de la clínica actualizados correctamente.');
    }
  }

  Widget? _buildClinicProfileCard() {
    final data = _currentClinicData();
    if (data.isEmpty) return null;

    final direccion = data['direccion']?.toString();
    final telefono = data['telefono_contacto']?.toString();
    final imageUrl = _resolveClinicImageUrl(data['imagen_url']);

    if ((direccion == null || direccion.isEmpty) &&
        (telefono == null || telefono.isEmpty) &&
        (imageUrl == null)) {
      return null;
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _clinicPlaceholderAvatar(),
                    ),
                  )
                : _clinicPlaceholderAvatar(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['nombre']?.toString() ?? clinicaNombre ?? 'Mi Clínica',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  if (direccion != null && direccion.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_pin,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              direccion,
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey.shade700),
                            ),
                          )
                        ],
                      ),
                    ),
                  if (telefono != null && telefono.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Row(
                        children: [
                          const Icon(Icons.phone, size: 16, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text(
                            telefono,
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey.shade700),
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
    );
  }

  bool _clinicHasData() {
    final data = _currentClinicData();
    return (data['direccion']?.toString().trim().isNotEmpty ?? false) ||
        (data['telefono_contacto']?.toString().trim().isNotEmpty ?? false) ||
        (data['imagen_url']?.toString().trim().isNotEmpty ?? false);
  }

  Map<String, dynamic> _currentClinicData() {
    final result = <String, dynamic>{};

    void merge(Map<String, dynamic>? source) {
      if (source == null) return;
      source.forEach((key, value) {
        if (value != null) {
          result[key] = value;
        }
      });
    }

    merge(_clinicPerfil);

    final statsClinic = stats?['clinic'];
    if (statsClinic is Map<String, dynamic>) {
      merge(statsClinic);
    }

    final mis = _misDatos;
    if (mis != null) {
      if (!result.containsKey('direccion')) {
        for (final key in ['clinica_direccion', 'direccion']) {
          final value = mis[key];
          if (value != null && value.toString().trim().isNotEmpty) {
            result['direccion'] = value;
            break;
          }
        }
      }
      if (!result.containsKey('telefono_contacto')) {
        for (final key in [
          'telefono_contacto',
          'telefonoClinica',
          'telefono'
        ]) {
          final value = mis[key];
          if (value != null && value.toString().trim().isNotEmpty) {
            result['telefono_contacto'] = value;
            break;
          }
        }
      }
      if (!result.containsKey('imagen_url')) {
        for (final key in ['imagen_url', 'logo', 'imagen']) {
          final value = mis[key];
          if (value != null && value.toString().trim().isNotEmpty) {
            result['imagen_url'] = value;
            break;
          }
        }
      }
      if (!result.containsKey('nombre')) {
        for (final key in ['clinica_nombre', 'clinicaName', 'clinica']) {
          final value = mis[key];
          if (value != null && value.toString().trim().isNotEmpty) {
            result['nombre'] = value;
            break;
          }
        }
      }
    }

    if (!result.containsKey('nombre') && clinicaNombre != null) {
      result['nombre'] = clinicaNombre;
    }

    return result;
  }

  Map<String, dynamic>? _mergeClinicMaps(Map<String, dynamic>? incoming) {
    final merged = <String, dynamic>{};

    void addSafe(Map<String, dynamic>? source) {
      if (source == null) return;
      source.forEach((key, value) {
        if (value != null) merged[key] = value;
      });
    }

    addSafe(_clinicPerfil);
    addSafe(incoming);

    return merged.isEmpty ? null : merged;
  }

  void _computeAvailability() {
    if (stats == null) return;
    try {
      final patients = _castToInt(stats?['patients']);
      final slots =
          _castToInt(stats?['slots_total'] ?? stats?['patients_capacity']);
      setState(() {
        stats?['availablePatients'] = slots > 0 ? (slots - patients) : null;
        stats?['atLimit'] = slots > 0 ? (patients >= slots) : null;
      });
    } catch (_) {}
  }

  int _castToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    final s = value.toString();
    return int.tryParse(s) ?? 0;
  }

  String? _resolveClinicImageUrl(dynamic value) {
    if (value == null) return null;
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }
    if (raw.startsWith('/')) {
      return '${ApiService.baseUrl}$raw';
    }
    return '${ApiService.baseUrl}/${raw.startsWith('uploads') ? raw : 'uploads/$raw'}';
  }

  Widget _clinicPlaceholderAvatar({double size = 80, double iconSize = 28}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.teal.withOpacity(0.08),
      ),
      child: Icon(Icons.local_hospital, size: iconSize, color: Colors.teal),
    );
  }

  void _showSnack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? Colors.red.shade700 : null,
        ),
      );
  }

  Widget _statCard(String title, String value) {
    return Expanded(
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              Text(value,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
