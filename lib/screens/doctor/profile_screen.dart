import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/api_services.dart';
import '../../route_refresh_mixin.dart';
import '../../utils/local_profile_overrides.dart';
import '../../refresh_notifier.dart';
import '../citas/citas_screen.dart';
import '../paciente/agregar_editar_paciente_screen.dart';

class PerfilDoctorScreen extends StatefulWidget {
  final int? doctorId;
  const PerfilDoctorScreen({super.key, this.doctorId});

  @override
  State<PerfilDoctorScreen> createState() => _PerfilDoctorScreenState();
}

class _PerfilDoctorScreenState extends State<PerfilDoctorScreen>
    with RouteRefreshMixin<PerfilDoctorScreen> {
  Map<String, dynamic>? perfil;
  Map<String, dynamic>? lastError;
  Map<String, dynamic>? _localOverrides;
  String? _localImagePath;

  List<Map<String, dynamic>> _documents = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void onRouteRefreshed() {
    // When returning to this screen, reload the profile
    try {
      _load();
    } catch (_) {}
  }

  ImageProvider? _resolveAvatarProvider(dynamic avatarValue,
      [String? localPath]) {
    try {
      if (localPath != null && localPath.isNotEmpty) {
        final f = File(localPath);
        if (f.existsSync()) return FileImage(f);
      }
    } catch (_) {}
    try {
      if (avatarValue != null) {
        final s = avatarValue.toString();
        if (s.startsWith('http') || s.startsWith('https')) {
          return NetworkImage(s);
        }
        // Server may return a relative path like '/uploads/...'
        if (s.startsWith('/')) return NetworkImage('${ApiService.baseUrl}$s');
        if (s.startsWith('file://')) {
          final path = s.replaceFirst('file://', '');
          final f = File(path);
          if (f.existsSync()) return FileImage(f);
        }
        final f = File(s);
        if (f.existsSync()) return FileImage(f);
      }
    } catch (_) {}
    return null;
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    final parsed = int.tryParse(text);
    if (parsed != null) return parsed;
    final fallback = double.tryParse(text);
    return fallback?.toInt();
  }

  void _mergeCapacityFromMisDatos(Map<String, dynamic>? source) {
    if (source == null) return;
    final total =
        _parseInt(source['totalPacientes'] ?? source['total_pacientes']);
    final limite = _parseInt(source['limite'] ?? source['clinic_capacity']);
    if (total == null && limite == null) return;

    final current = Map<String, dynamic>.from(perfil ?? {});
    var changed = false;

    if (total != null && current['totalPacientes'] != total) {
      current['totalPacientes'] = total;
      changed = true;
    }

    if (limite != null) {
      if (current['clinic_capacity'] != limite) {
        current['clinic_capacity'] = limite;
        changed = true;
      }
      if (current['limite'] != limite) {
        current['limite'] = limite;
        changed = true;
      }
    }

    if (changed || perfil == null) {
      perfil = current;
    }
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      lastError = null;
    });
    try {
      try {
        final overrides =
            await LocalProfileOverrides.loadForUser(widget.doctorId ?? 0);
        if (overrides != null) _localOverrides = overrides;
      } catch (_) {}

      // Determine which profile to load: explicit doctorId (when
      // viewing someone else's profile) or the current user's profile
      // (when opened from the drawer without an id). This ensures the
      // screen shows data both when navigated from the menu and from
      // the drawer.
      int? targetId = widget.doctorId;
      Map<String, dynamic>? me;

      // If no explicit id provided, try to load the current user's data
      if (targetId == null) {
        try {
          final m = await ApiService.obtenerMisDatos();
          if (m != null) {
            try {
              me = Map<String, dynamic>.from(m);
              // If the 'me' payload itself looks like a full perfil, use it
              perfil = {...?perfil, ...me};
              _mergeCapacityFromMisDatos(me);
              // Try to derive an id to fetch extended data
              final cand = me['user_id'] ?? me['usuario_id'] ?? me['id'];
              if (cand != null) {
                targetId = cand is int ? cand : int.tryParse(cand.toString());
              }
            } catch (_) {
              // ignore conversion errors
            }
          }
        } catch (_) {}
      }

      // If we have a target id (either explicit or derived), fetch the
      // standard profile endpoint and merge results with any 'me' data.
      if (targetId != null) {
        try {
          final resp = await ApiService.obtenerPerfilDoctor(targetId);
          if ((resp['ok'] ?? false) == true) {
            final data = resp['data'];
            if (data is Map<String, dynamic>) {
              perfil = {...?perfil, ...Map<String, dynamic>.from(data)};
              _mergeCapacityFromMisDatos(me);
            }

            // Try to fetch extended doctor profile (doctor_profiles) and merge
            try {
              final ext =
                  await ApiService.obtenerPerfilDoctorExtendido(targetId);
              if (ext != null) {
                perfil = {...?perfil, ...ext};
              }
            } catch (_) {}

            // Fetch documents/photos for this doctor (keep images only)
            try {
              final docs = await ApiService.obtenerDocumentosDoctor(targetId);
              _documents = docs.where((d) {
                try {
                  String? url = d['url']?.toString() ??
                      d['path']?.toString() ??
                      d['file']?.toString();
                  if (url == null) return false;
                  url = url.split('?').first.toLowerCase();
                  return url.endsWith('.png') ||
                      url.endsWith('.jpg') ||
                      url.endsWith('.jpeg') ||
                      url.endsWith('.gif') ||
                      url.endsWith('.webp');
                } catch (_) {
                  return false;
                }
              }).toList();
            } catch (_) {
              _documents = [];
            }

            // If patients/capacity are missing, try obtenerMisDatos() when possible
            if ((perfil?['totalPacientes'] == null ||
                perfil?['clinic_capacity'] == null)) {
              try {
                final me2 = me ?? await ApiService.obtenerMisDatos();
                if (me2 != null) {
                  _mergeCapacityFromMisDatos(me2);
                }
              } catch (_) {}
            }
          } else {
            // If the standard profile endpoint failed but we have 'me',
            // keep the 'me' data; otherwise record the error.
            if (perfil == null) lastError = resp;
          }
        } catch (e) {
          if (perfil == null) lastError = {'ok': false, 'error': e.toString()};
        }
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = perfil?['nombre'] ?? 'Perfil del doctor';

    Widget infoRow(String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 120,
                child: Text(label, style: TextStyle(color: Colors.grey[700]))),
            Expanded(
                child: Text(value.isNotEmpty ? value : '-',
                    style: const TextStyle(fontSize: 15)))
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.event),
            tooltip: 'Ver citas',
            onPressed: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const CitasScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Editar perfil',
            onPressed: perfil == null
                ? null
                : () async => await _openEditDialog(context),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : lastError != null
              ? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text('Estado: ${lastError?['status'] ?? 'N/A'}'),
                      const SizedBox(height: 6),
                      ElevatedButton(
                        onPressed: () {
                          showDialog<void>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Respuesta del servidor'),
                              content: SingleChildScrollView(
                                  child: Text(
                                      lastError?['body']?.toString() ?? '')),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Cerrar')),
                              ],
                            ),
                          );
                        },
                        child: const Text('Ver respuesta del servidor'),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                          onPressed: _load, child: const Text('Reintentar'))
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Builder(builder: (_) {
                                  final prov = _resolveAvatarProvider(
                                      perfil?['avatar'] ??
                                          perfil?['avatar_url'] ??
                                          perfil?['imagen'],
                                      _localImagePath);
                                  if (prov != null) {
                                    return CircleAvatar(
                                        radius: 40, backgroundImage: prov);
                                  }
                                  return CircleAvatar(
                                    radius: 40,
                                    backgroundColor: Colors.blueGrey.shade50,
                                    child: Text(
                                        (perfil?['nombre'] ?? '')
                                            .toString()
                                            .split(' ')
                                            .map(
                                                (s) => s.isNotEmpty ? s[0] : '')
                                            .take(2)
                                            .join(),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                  );
                                }),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(perfil?['nombre'] ?? '-',
                                          style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 6),
                                      Row(children: [
                                        Chip(
                                            label: Text(
                                                'Pacientes: ${perfil?['totalPacientes'] ?? '-'}')),
                                        const SizedBox(width: 8),
                                        Chip(
                                            label: Text(
                                                'Capacidad: ${perfil?['clinic_capacity'] ?? '-'}')),
                                      ])
                                    ],
                                  ),
                                )
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          child: Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Información',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                infoRow('Apellido',
                                    perfil?['apellido']?.toString() ?? ''),
                                infoRow('Dirección',
                                    perfil?['direccion']?.toString() ?? ''),
                                infoRow('Teléfono',
                                    perfil?['telefono']?.toString() ?? ''),
                                infoRow(
                                    'Especialidad',
                                    perfil?['especialidad']?.toString() ??
                                        perfil?['specialty']?.toString() ??
                                        ''),
                                infoRow(
                                    'Email',
                                    perfil?['email']?.toString() ??
                                        perfil?['correo']?.toString() ??
                                        ''),
                                const SizedBox(height: 6),
                                const Divider(),
                                const SizedBox(height: 6),
                                const Text('Biografía',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                Text(perfil?['bio']?.toString() ?? '-',
                                    style:
                                        const TextStyle(color: Colors.black87)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Documentos / Imágenes
                        Card(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Imágenes y documentos',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                if (_documents.isEmpty)
                                  const Text('No hay imágenes o documentos')
                                else
                                  Column(
                                    children: _documents.map((d) {
                                      final title = d['title'] ??
                                          d['titulo'] ??
                                          d['name'] ??
                                          d['filename'] ??
                                          'Sin título';
                                      String? url;
                                      if (d['url'] != null) {
                                        url = d['url'].toString();
                                      } else if (d['path'] != null) {
                                        url = d['path'].toString();
                                      } else if (d['file'] != null) {
                                        url = d['file'].toString();
                                      }
                                      if (url != null && url.startsWith('/')) {
                                        url = '${ApiService.baseUrl}$url';
                                      }
                                      return ListTile(
                                        leading: url != null
                                            ? CircleAvatar(
                                                backgroundImage:
                                                    NetworkImage(url))
                                            : const CircleAvatar(
                                                child: Icon(
                                                    Icons.insert_drive_file)),
                                        title: Text(title.toString()),
                                        onTap: url != null
                                            ? () {/* could open */}
                                            : null,
                                      );
                                    }).toList(),
                                  ),
                                const SizedBox(height: 6),
                                TextButton.icon(
                                  onPressed: () async {
                                    // Pick files and ask for a title
                                    if (!context.mounted) return;
                                    final messenger =
                                        ScaffoldMessenger.of(context);
                                    try {
                                      final res = await FilePicker.platform
                                          .pickFiles(allowMultiple: true);
                                      if (!context.mounted) return;
                                      if (res == null || res.files.isEmpty) {
                                        return;
                                      }
                                      final paths = res.files
                                          .map((f) => f.path)
                                          .whereType<String>()
                                          .toList();
                                      final titleCtrl = TextEditingController();
                                      final ok = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                                title: const Text('Título'),
                                                content: TextField(
                                                    controller: titleCtrl,
                                                    decoration:
                                                        const InputDecoration(
                                                            labelText:
                                                                'Título para estas imágenes (opcional)')),
                                                actions: [
                                                  TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              ctx, false),
                                                      child: const Text(
                                                          'Cancelar')),
                                                  ElevatedButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              ctx, true),
                                                      child:
                                                          const Text('Subir'))
                                                ],
                                              ));
                                      if (!context.mounted) return;
                                      if (ok != true) return;
                                      // Upload
                                      final userIdRaw = perfil?['user_id'] ??
                                          perfil?['usuario_id'] ??
                                          perfil?['userId'] ??
                                          perfil?['usuarioId'] ??
                                          perfil?['id'];
                                      int? uid;
                                      if (userIdRaw != null) {
                                        uid = userIdRaw is int
                                            ? userIdRaw
                                            : int.tryParse(
                                                userIdRaw.toString());
                                      }
                                      if (uid == null) {
                                        messenger.showSnackBar(const SnackBar(
                                            content: Text(
                                                'ID de usuario no disponible')));
                                        return;
                                      }
                                      final up = await ApiService
                                          .subirDocumentosDoctor(uid, paths);
                                      if (!context.mounted) return;
                                      if ((up['ok'] ?? false) == true) {
                                        messenger.showSnackBar(const SnackBar(
                                            content:
                                                Text('Documentos subidos')));
                                        final docs = await ApiService
                                            .obtenerDocumentosDoctor(uid);
                                        if (!mounted) return;
                                        setState(() {
                                          _documents = docs;
                                        });
                                      } else {
                                        messenger.showSnackBar(SnackBar(
                                            content: Text(
                                                'Error subiendo: ${up['error'] ?? up['body'] ?? up}')));
                                      }
                                    } catch (e) {
                                      if (!context.mounted) return;
                                      messenger.showSnackBar(
                                          SnackBar(content: Text('Error: $e')));
                                    }
                                  },
                                  icon: const Icon(Icons.upload_file),
                                  label:
                                      const Text('Agregar imágenes / talleres'),
                                )
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text('Acciones',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () async {
                                          final doctorId = perfil?['id'];
                                          Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (_) =>
                                                      AgregarEditarPacienteScreen(
                                                          doctorId:
                                                              doctorId is int
                                                                  ? doctorId
                                                                  : null)));
                                        },
                                        icon: const Icon(Icons.person_add),
                                        label: const Text(
                                            'Ver / Agregar paciente'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (_) =>
                                                      const CitasScreen()));
                                        },
                                        icon: const Icon(Icons.event),
                                        label: const Text('Ver citas'),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (_localOverrides != null &&
                                    _localOverrides!.isNotEmpty)
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 8),
                                      Text('Nota: cambios locales pendientes',
                                          style: TextStyle(
                                              color: Colors.orange[800])),
                                      TextButton(
                                        onPressed: () async {
                                          final id = perfil?['id'];
                                          if (id == null) return;
                                          await LocalProfileOverrides
                                              .clearForUser(id is int
                                                  ? id
                                                  : int.tryParse(
                                                          id.toString()) ??
                                                      0);
                                          await _load();
                                        },
                                        child: const Text(
                                            'Borrar cambios locales'),
                                      )
                                    ],
                                  )
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
    );
  }

  Future<void> _openEditDialog(BuildContext context) async {
    final id = perfil?['id'];
    final nombreInit = perfil?['nombre']?.toString() ?? '';
    final especialidadInit = perfil?['especialidad']?.toString() ?? '';
    final nombreCtrl = TextEditingController(text: nombreInit);
    final espCtrl = TextEditingController(text: especialidadInit);
    final apellidoCtrl =
        TextEditingController(text: perfil?['apellido']?.toString() ?? '');
    final direccionCtrl =
        TextEditingController(text: perfil?['direccion']?.toString() ?? '');
    final telefonoCtrl =
        TextEditingController(text: perfil?['telefono']?.toString() ?? '');
    final emailCtrl = TextEditingController(
        text: perfil?['email']?.toString() ??
            perfil?['correo']?.toString() ??
            '');
    final bioCtrl =
        TextEditingController(text: perfil?['bio']?.toString() ?? '');
    String? pickedImagePath;
    bool uploadImage = true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (c, setS) {
        final avatarProv = _resolveAvatarProvider(
            perfil?['avatar'] ?? perfil?['avatar_url'] ?? perfil?['imagen'],
            pickedImagePath);
        return AlertDialog(
          title: const Text('Editar perfil'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: nombreCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre')),
                TextField(
                    controller: apellidoCtrl,
                    decoration: const InputDecoration(labelText: 'Apellido')),
                TextField(
                    controller: espCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Especialidad')),
                TextField(
                    controller: direccionCtrl,
                    decoration: const InputDecoration(labelText: 'Dirección')),
                TextField(
                    controller: telefonoCtrl,
                    decoration: const InputDecoration(labelText: 'Teléfono')),
                TextField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(labelText: 'Email')),
                TextField(
                    controller: bioCtrl,
                    decoration: const InputDecoration(labelText: 'Biografía'),
                    maxLines: 3),
                const SizedBox(height: 8),
                CheckboxListTile(
                    value: uploadImage,
                    onChanged: (v) => setS(() => uploadImage = v ?? true),
                    title: const Text('Intentar subir la imagen al servidor'),
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true),
                const SizedBox(height: 6),
                Row(children: [
                  if (avatarProv != null)
                    CircleAvatar(radius: 22, backgroundImage: avatarProv)
                  else
                    const CircleAvatar(radius: 22),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        final result = await FilePicker.platform.pickFiles(
                            type: FileType.image, allowMultiple: false);
                        if (result != null && result.files.isNotEmpty) {
                          final p = result.files.first.path;
                          if (p != null) setS(() => pickedImagePath = p);
                        }
                      } catch (_) {}
                    },
                    child: const Text('Seleccionar imagen'),
                  )
                ]),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    if (!mounted) return;
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      final res = await FilePicker.platform
                          .pickFiles(type: FileType.image, allowMultiple: true);
                      if (!mounted) return;
                      if (res != null && res.files.isNotEmpty) {
                        final paths = res.files
                            .map((f) => f.path)
                            .whereType<String>()
                            .toList();
                        if (paths.isNotEmpty) {
                          final userIdRaw = perfil?['user_id'] ??
                              perfil?['usuario_id'] ??
                              perfil?['userId'] ??
                              perfil?['usuarioId'] ??
                              perfil?['id'];
                          int? docUid;
                          if (userIdRaw != null) {
                            docUid = userIdRaw is int
                                ? userIdRaw
                                : int.tryParse(userIdRaw.toString());
                          }
                          if (docUid == null) {
                            messenger.showSnackBar(const SnackBar(
                                content: Text(
                                    'ID de usuario no disponible para subir documentos')));
                            return;
                          }
                          final up = await ApiService.subirDocumentosDoctor(
                              docUid, paths);
                          if (!mounted) return;
                          if ((up['ok'] ?? false) == true) {
                            messenger.showSnackBar(const SnackBar(
                                content:
                                    Text('Documentos subidos correctamente')));
                          } else {
                            messenger.showSnackBar(SnackBar(
                                content: Text(
                                    'Error subiendo documentos: ${up['error'] ?? up['body'] ?? up}')));
                          }
                        }
                      }
                    } catch (e) {
                      if (!mounted) return;
                      messenger
                          .showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Subir documentos'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancelar')),
            ElevatedButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Guardar')),
          ],
        );
      }),
    );

    if (!context.mounted) return;
    if (ok != true) return;
    final messenger = ScaffoldMessenger.of(context);
    if (id == null) {
      messenger.showSnackBar(
          const SnackBar(content: Text('ID de doctor no disponible')));
      return;
    }

    final profileIdRaw = id;
    final userIdRaw = perfil?['user_id'] ??
        perfil?['usuario_id'] ??
        perfil?['userId'] ??
        perfil?['usuarioId'] ??
        perfil?['user_id'];
    int uid;
    if (userIdRaw != null) {
      uid = userIdRaw is int
          ? userIdRaw
          : int.tryParse(userIdRaw.toString()) ?? 0;
    } else {
      uid = profileIdRaw is int
          ? profileIdRaw
          : int.tryParse(profileIdRaw?.toString() ?? '') ?? 0;
    }

    final profilePayload = <String, dynamic>{
      'nombre': nombreCtrl.text.trim(),
      'especialidad': espCtrl.text.trim(),
      'specialty': espCtrl.text.trim(),
      'profesion': espCtrl.text.trim(),
      'apellido': apellidoCtrl.text.trim(),
      'direccion': direccionCtrl.text.trim(),
      'telefono': telefonoCtrl.text.trim(),
      'email': emailCtrl.text.trim(),
      'bio': bioCtrl.text.trim(),
    };

    bool saved = false;
    while (!saved) {
      final resp = await ApiService.actualizarPerfilDoctor(uid, profilePayload);
      if ((resp['ok'] ?? false) == true) {
        try {
          final data = resp['data'];
          if (data is Map<String, dynamic>) {
            perfil = {...?perfil, ...Map<String, dynamic>.from(data)};
            perfil?['id'] = perfil?['user_id'] ?? perfil?['id'];
          }
        } catch (_) {}

        if (pickedImagePath != null &&
            pickedImagePath!.isNotEmpty &&
            uploadImage) {
          final file = File(pickedImagePath!);
          if (file.existsSync()) {
            Map<String, dynamic> up =
                await ApiService.subirAvatarDoctor(uid, pickedImagePath!);
            if (!((up['ok'] ?? false) == true)) {
              up = await ApiService.subirImagenPerfil(uid, pickedImagePath!);
            }
            if ((up['ok'] ?? false) == true) {
              try {
                final avatarUrl = up['data'] is Map
                    ? up['data']['avatar_url'] ?? up['data']['avatar']
                    : up['avatar_url'] ?? up['data'];
                if (avatarUrl != null) perfil?['avatar'] = avatarUrl;
              } catch (_) {}
              try {
                await LocalProfileOverrides.removeFieldsForUser(
                    uid, ['imagePath']);
              } catch (_) {}
            }
          }
        }

        try {
          await LocalProfileOverrides.removeFieldsForUser(uid, [
            'nombre',
            'apellido',
            'especialidad',
            'direccion',
            'telefono',
            'email',
            'bio',
            'imagePath'
          ]);
        } catch (_) {}
        if (mounted) {
          messenger.showSnackBar(
              const SnackBar(content: Text('Perfil actualizado en servidor')));
          // No re-fetch here: algunas rutas públicas devuelven campos parciales.
          // Preferir los datos que ya devolvió `actualizarPerfilDoctor`.
          setState(() {});
          // Invalidate cached public profile so other screens fetch fresh data
          try {
            ApiService.invalidateProfileCache(uid);
          } catch (_) {}
          // Notify global listeners so lists refresh (avatar/name/specialty may have changed)
          globalRefreshNotifier.value = globalRefreshNotifier.value + 1;
        }
        saved = true;
        break;
      } else {
        if (!context.mounted) return;
        final choice = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Error guardando en servidor'),
            content: const SingleChildScrollView(
                child: Text(
                    'No fue posible guardar el perfil en el servidor. ¿Qué deseas hacer?')),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, 'cancel'),
                  child: const Text('Cancelar')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, 'saveLocal'),
                  child: const Text('Guardar localmente')),
              ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, 'retry'),
                  child: const Text('Reintentar')),
            ],
          ),
        );

        if (!context.mounted) return;
        if (choice == 'retry') continue;
        if (choice == 'saveLocal') {
          try {
            final Map<String, dynamic> toSave = {...profilePayload};
            if (pickedImagePath != null &&
                File(pickedImagePath!).existsSync()) {
              toSave['imagePath'] = pickedImagePath;
            }
            await LocalProfileOverrides.saveForUser(uid, toSave);
            if (!mounted) return;
            setState(() {
              _localOverrides = toSave;
              perfil?.addAll(_localOverrides!);
              if (toSave.containsKey('imagePath')) {
                _localImagePath = toSave['imagePath'];
              }
            });
            if (mounted) {
              messenger.showSnackBar(
                  const SnackBar(content: Text('Guardado localmente')));
            }
          } catch (_) {
            if (mounted) {
              messenger.showSnackBar(
                  const SnackBar(content: Text('Error guardando localmente')));
            }
          }
          break;
        }
        break;
      }
    }
  }
}
