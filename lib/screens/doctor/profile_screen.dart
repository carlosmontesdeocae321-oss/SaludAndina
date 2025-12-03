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

  static const Color _accentColor = Color(0xFF1BD1C2);
  static const Color _overlayColor = Color(0xFF101D32);

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

  String? _cleanText(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return null;
    return text;
  }

  Widget _buildSection({
    required ThemeData theme,
    required String title,
    required List<Widget> children,
    Widget? trailing,
    EdgeInsetsGeometry? padding,
  }) {
    return Container(
      width: double.infinity,
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.55),
            blurRadius: 30,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(ThemeData theme, String label, String? value) {
    final safeValue = _cleanText(value) ?? '-';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withOpacity(0.68),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
          Expanded(
            child: Text(
              safeValue,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                height: 1.32,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: _accentColor),
          const SizedBox(width: 8),
          Text(
            '$label: $value',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileOverview(ThemeData theme) {
    final nombre = _cleanText(perfil?['nombre']) ?? 'Perfil del doctor';
    final especialidad =
        _cleanText(perfil?['especialidad']) ?? _cleanText(perfil?['specialty']);
    final avatarProv = _resolveAvatarProvider(
      perfil?['avatar'] ?? perfil?['avatar_url'] ?? perfil?['imagen'],
      _localImagePath,
    );

    final chips = <Widget>[];
    final totalPacientes = _cleanText(perfil?['totalPacientes']);
    final capacidad =
        _cleanText(perfil?['clinic_capacity'] ?? perfil?['limite']);

    if (totalPacientes != null) {
      chips.add(_buildMetricChip(
        theme,
        icon: Icons.people_alt_outlined,
        label: 'Pacientes',
        value: totalPacientes,
      ));
    }
    if (capacidad != null) {
      chips.add(_buildMetricChip(
        theme,
        icon: Icons.event_seat_outlined,
        label: 'Capacidad',
        value: capacidad,
      ));
    }

    String initials() {
      final raw = _cleanText(perfil?['nombre']);
      if (raw == null) return 'DR';
      final parts =
          raw.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
      if (parts.isEmpty) return 'DR';
      final buffer = StringBuffer();
      final first = parts.first.trim();
      if (first.isNotEmpty) buffer.write(first[0].toUpperCase());
      if (parts.length > 1) {
        final second = parts[1].trim();
        if (second.isNotEmpty) buffer.write(second[0].toUpperCase());
      }
      final result = buffer.toString();
      return result.isEmpty ? 'DR' : result;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF122643), Color(0xFF091526)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.55),
            blurRadius: 32,
            offset: const Offset(0, 26),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: Colors.white.withOpacity(0.14),
                backgroundImage: avatarProv,
                child: avatarProv == null
                    ? Text(
                        initials(),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    if (especialidad != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        especialidad,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: _accentColor,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 22),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: chips,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDocumentTile(
      BuildContext context, ThemeData theme, Map<String, dynamic> doc) {
    final title = _cleanText(
          doc['title'] ?? doc['titulo'] ?? doc['name'] ?? doc['filename'],
        ) ??
        'Sin título';

    String? url = doc['url']?.toString() ??
        doc['path']?.toString() ??
        doc['file']?.toString();
    if (url != null && url.startsWith('/')) {
      url = '${ApiService.baseUrl}$url';
    }
    final resolvedUrl = (url != null && url.isNotEmpty) ? url : null;

    Future<void> showPreview() async {
      if (resolvedUrl == null || !mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              color: Colors.black,
              padding: const EdgeInsets.all(12),
              child: InteractiveViewer(
                clipBehavior: Clip.hardEdge,
                child: Image.network(resolvedUrl, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: Colors.white.withOpacity(0.08),
          backgroundImage:
              resolvedUrl != null ? NetworkImage(resolvedUrl) : null,
          child: resolvedUrl != null
              ? null
              : const Icon(
                  Icons.insert_drive_file,
                  color: Colors.white70,
                  size: 22,
                ),
        ),
        title: Text(
          title,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: resolvedUrl != null
            ? Text(
                'Toca para previsualizar',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white60,
                ),
              )
            : null,
        onTap: resolvedUrl != null ? showPreview : null,
      ),
    );
  }

  Widget _buildDocumentsSection(BuildContext context, ThemeData theme) {
    return _buildSection(
      theme: theme,
      title: 'Imágenes y documentos',
      children: [
        if (_documents.isEmpty)
          Text(
            'No hay imágenes o documentos disponibles.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white60,
            ),
          )
        else
          ..._documents.map((d) => _buildDocumentTile(context, theme, d)),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => _handleAddDocuments(context),
            icon: const Icon(Icons.upload_file),
            label: const Text('Agregar imágenes / talleres'),
          ),
        ),
      ],
    );
  }

  Widget _buildActionsSection(BuildContext context, ThemeData theme) {
    final doctorId = perfil?['id'];
    int? parsedId;
    if (doctorId is int) {
      parsedId = doctorId;
    } else {
      final candidate = _cleanText(doctorId);
      if (candidate != null) {
        parsedId = int.tryParse(candidate);
      }
    }

    return _buildSection(
      theme: theme,
      title: 'Acciones',
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AgregarEditarPacienteScreen(
                        doctorId: parsedId,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Ver / Agregar paciente'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CitasScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.event),
                label: const Text('Ver citas'),
              ),
            ),
          ],
        ),
        if (_localOverrides != null && _localOverrides!.isNotEmpty) ...[
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.orange.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cambios locales pendientes',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.orange[200],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Existen actualizaciones guardadas localmente que aún no se han enviado al servidor.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.orange[100],
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () async {
                    if (parsedId == null) return;
                    await LocalProfileOverrides.clearForUser(parsedId);
                    await _load();
                  },
                  child: const Text('Borrar cambios locales'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildErrorContent(BuildContext context, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(0.95),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.redAccent.withOpacity(0.35)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.55),
                blurRadius: 34,
                offset: const Offset(0, 28),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: Colors.redAccent, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No se pudo cargar el perfil',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (lastError?['status'] != null)
                Text(
                  'Estado: ${lastError?['status']}',
                  style: theme.textTheme.bodyMedium,
                ),
              if (lastError?['error'] != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Detalle: ${lastError?['error']}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      showDialog<void>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Respuesta del servidor'),
                          content: SingleChildScrollView(
                            child: Text(
                              lastError?['body']?.toString() ?? 'Sin detalles',
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cerrar'),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('Ver respuesta'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleAddDocuments(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (!mounted) return;
      if (res == null || res.files.isEmpty) {
        return;
      }

      final paths = res.files.map((f) => f.path).whereType<String>().toList();
      if (paths.isEmpty) return;

      final userIdRaw = perfil?['user_id'] ??
          perfil?['usuario_id'] ??
          perfil?['userId'] ??
          perfil?['usuarioId'] ??
          perfil?['id'];
      int? uid;
      if (userIdRaw is int) {
        uid = userIdRaw;
      } else if (userIdRaw != null) {
        uid = int.tryParse(userIdRaw.toString());
      }

      if (uid == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('ID de usuario no disponible')),
        );
        return;
      }

      final response = await ApiService.subirDocumentosDoctor(uid, paths);
      if (!mounted) return;

      if ((response['ok'] ?? false) == true) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Documentos subidos')),
        );
        final docs = await ApiService.obtenerDocumentosDoctor(uid);
        if (!mounted) return;
        setState(() {
          _documents = docs;
        });
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Error subiendo: ${response['error'] ?? response['body'] ?? response}',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Widget _buildBody(BuildContext context, ThemeData theme) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (lastError != null) {
      return _buildErrorContent(context, theme);
    }

    if (perfil == null) {
      return Center(
        child: Text(
          'No se encontraron datos del perfil.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.white70,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildProfileOverview(theme),
          const SizedBox(height: 22),
          _buildSection(
            theme: theme,
            title: 'Información',
            children: [
              _buildInfoRow(theme, 'Apellido', perfil?['apellido']?.toString()),
              _buildInfoRow(
                  theme, 'Dirección', perfil?['direccion']?.toString()),
              _buildInfoRow(theme, 'Teléfono', perfil?['telefono']?.toString()),
              _buildInfoRow(
                theme,
                'Especialidad',
                perfil?['especialidad']?.toString() ??
                    perfil?['specialty']?.toString(),
              ),
              _buildInfoRow(
                theme,
                'Email',
                perfil?['email']?.toString() ?? perfil?['correo']?.toString(),
              ),
              const SizedBox(height: 18),
              Divider(color: theme.dividerColor),
              const SizedBox(height: 18),
              Text(
                'Biografía',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _cleanText(perfil?['bio']) ??
                    'No se ha proporcionado una biografía.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.85),
                  height: 1.45,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _buildDocumentsSection(context, theme),
          const SizedBox(height: 22),
          _buildActionsSection(context, theme),
          const SizedBox(height: 32),
        ],
      ),
    );
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
    final baseTheme = Theme.of(context);
    final safeTitle = _cleanText(perfil?['nombre']) ?? 'Perfil del doctor';

    final darkColorScheme = baseTheme.colorScheme.copyWith(
      brightness: Brightness.dark,
      primary: _accentColor,
      secondary: _accentColor,
      surface: _overlayColor,
      surfaceContainerHighest: _overlayColor.withOpacity(0.85),
      surfaceTint: Colors.transparent,
    );

    final darkTheme = baseTheme.copyWith(
      brightness: Brightness.dark,
      colorScheme: darkColorScheme,
      scaffoldBackgroundColor: Colors.transparent,
      dividerColor: Colors.white.withOpacity(0.12),
      appBarTheme: baseTheme.appBarTheme.copyWith(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        centerTitle: false,
      ),
      textTheme: baseTheme.textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentColor,
          foregroundColor: const Color(0xFF031928),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withOpacity(0.4)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: _accentColor),
      ),
      snackBarTheme: baseTheme.snackBarTheme.copyWith(
        backgroundColor: Colors.black.withOpacity(0.85),
        behavior: SnackBarBehavior.floating,
        contentTextStyle: baseTheme.textTheme.bodyMedium?.copyWith(
          color: Colors.white,
        ),
      ),
    );

    return Theme(
      data: darkTheme,
      child: Builder(
        builder: (themeContext) {
          final themed = Theme.of(themeContext);
          return Scaffold(
            extendBody: true,
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              title: Text(safeTitle),
              actions: [
                IconButton(
                  icon: const Icon(Icons.event),
                  tooltip: 'Ver citas',
                  onPressed: () {
                    Navigator.push(
                      themeContext,
                      MaterialPageRoute(builder: (_) => const CitasScreen()),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Editar perfil',
                  onPressed: perfil == null
                      ? null
                      : () => _openEditDialog(themeContext),
                ),
              ],
            ),
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF07142A), Color(0xFF030A18)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                child: _buildBody(themeContext, themed),
              ),
            ),
          );
        },
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
