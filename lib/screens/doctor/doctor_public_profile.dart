import 'package:flutter/material.dart';
import '../../services/api_services.dart';
import '../../route_refresh_mixin.dart';
// formato_fecha removed — not needed after compacting details card

class DoctorPublicProfile extends StatefulWidget {
  final int doctorId;
  const DoctorPublicProfile({super.key, required this.doctorId});

  @override
  State<DoctorPublicProfile> createState() => _DoctorPublicProfileState();
}

class _DoctorPublicProfileState extends State<DoctorPublicProfile>
    with RouteRefreshMixin<DoctorPublicProfile> {
  Map<String, dynamic>? perfil;
  bool loading = true;
  List<Map<String, dynamic>> documents = [];
  // This is a public profile screen: no owner actions here

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void onRouteRefreshed() {
    try {
      _load();
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final auth = await ApiService.isAuthenticated();

      // fetch base profile: public endpoint when unauthenticated, otherwise general getter
      if (!auth) {
        final pub = await ApiService.obtenerPerfilDoctorPublic(widget.doctorId);
        if (pub != null) {
          perfil = Map<String, dynamic>.from(pub);
        } else {
          perfil = null;
        }
        // Try to merge public doctor_profiles data if the backend exposes it
        try {
          final extra = await ApiService.obtenerPerfilDoctorExtendidoPublic(
              widget.doctorId);
          if (extra != null) {
            perfil = {...?perfil, ...extra};
          }
        } catch (_) {}
      } else {
        final p = await ApiService.obtenerPerfilDoctor(widget.doctorId);
        if ((p['ok'] ?? false) == true) {
          final data = p['data'];
          if (data is Map<String, dynamic>) {
            perfil = Map<String, dynamic>.from(data);
          }
        } else {
          perfil = null;
        }
      }

      // If authenticated, try to merge protected extended profile and my-data fallbacks
      if (perfil != null && auth) {
        try {
          final ext =
              await ApiService.obtenerPerfilDoctorExtendido(widget.doctorId);
          if (ext != null) {
            try {
              perfil = {...?perfil, ...Map<String, dynamic>.from(ext)};
            } catch (_) {}
          }
        } catch (_) {}

        try {
          if (perfil?['totalPacientes'] == null ||
              perfil?['clinic_capacity'] == null) {
            final me = await ApiService.obtenerMisDatos();
            if (me != null) {
              try {
                final Map<String, dynamic> mm = Map<String, dynamic>.from(me);
                if (mm['totalPacientes'] != null) {
                  perfil?['totalPacientes'] = mm['totalPacientes'];
                }
                if (mm['limite'] != null) {
                  perfil?['clinic_capacity'] = mm['limite'];
                }
              } catch (_) {}
            }
          }
        } catch (_) {}
      }

      // try load associated documents/photos (attempt even if public)
      try {
        final docs = await ApiService.obtenerDocumentosDoctor(widget.doctorId);
        try {
          documents = List<Map<String, dynamic>>.from(docs);
        } catch (_) {
          documents = [];
        }
      } catch (_) {
        documents = [];
      }
    } catch (_) {
      perfil = null;
    }

    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil del Doctor')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : perfil == null
              ? const Center(child: Text('Perfil no disponible'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top card with avatar, name and specialization
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(48),
                                child: Container(
                                  width: 96,
                                  height: 96,
                                  color: Colors.grey[200],
                                  child: (() {
                                    final raw = perfil!['avatar_url'] ??
                                        perfil!['avatar'] ??
                                        perfil!['imagen'];
                                    if (raw == null) {
                                      return const Icon(Icons.person, size: 48);
                                    }
                                    String s = raw.toString();
                                    if (s.startsWith('/')) {
                                      s = ApiService.baseUrl + s;
                                    }
                                    if (s.startsWith('file:///')) {
                                      s = ApiService.baseUrl +
                                          s.replaceFirst('file://', '');
                                    }
                                    return Image.network(s,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.broken_image));
                                  })(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        perfil!['nombre'] ??
                                            perfil!['usuario'] ??
                                            'Doctor',
                                        style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 6),
                                    // Specialization(s) as chips
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: (() {
                                        final List<Widget> chips = [];
                                        final sp = perfil!['especialidades'] ??
                                            perfil!['especialidad'] ??
                                            perfil!['especialidad_medica'] ??
                                            perfil!['specialty'];
                                        if (sp == null) {
                                          // nothing
                                        } else if (sp is List) {
                                          for (final e in sp) {
                                            chips.add(Chip(
                                                label: Text(e.toString())));
                                          }
                                        } else {
                                          chips.add(
                                              Chip(label: Text(sp.toString())));
                                        }
                                        return chips;
                                      })(),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(children: [
                                      if ((perfil!['telefono'] ??
                                              perfil!['telefono_movil']) !=
                                          null)
                                        Row(children: [
                                          const Icon(Icons.phone,
                                              size: 16, color: Colors.grey),
                                          const SizedBox(width: 6),
                                          Text((perfil!['telefono'] ??
                                                  perfil!['telefono_movil'])
                                              .toString())
                                        ]),
                                      const SizedBox(width: 12),
                                      if ((perfil!['email'] ??
                                              perfil!['correo']) !=
                                          null)
                                        Row(children: [
                                          const Icon(Icons.email,
                                              size: 16, color: Colors.grey),
                                          const SizedBox(width: 6),
                                          Text((perfil!['email'] ??
                                                  perfil!['correo'])
                                              .toString())
                                        ]),
                                    ])
                                  ],
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (perfil!['bio'] != null)
                        Card(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Text(perfil!['bio'].toString()),
                          ),
                        ),

                      const SizedBox(height: 12),
                      // Detalles adicionales del doctor
                      Card(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8.0, horizontal: 10.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Detalles',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              if (perfil!['apellido'] != null)
                                Text('Apellido: ${perfil!['apellido']}'),
                              if (perfil!['direccion'] != null)
                                Text('Dirección: ${perfil!['direccion']}'),
                              // Teléfono y Email mostrados en el header; se omiten aquí

                              // Especialidad (mostrar debajo del email si existe)
                              if (perfil!['especialidad'] != null ||
                                  perfil!['specialty'] != null ||
                                  perfil!['especialidades'] != null)
                                Text(
                                    'Especialidad: ${perfil!['especialidad'] ?? perfil!['specialty'] ?? (perfil!['especialidades'] is List ? (perfil!['especialidades'] as List).join(', ') : perfil!['especialidades'])}'),

                              const SizedBox(height: 6),
                              // Mostrar solo Pacientes aquí (no mostrar Capacidad)
                              Text(
                                  'Pacientes: ${perfil?['totalPacientes'] ?? perfil?['patients'] ?? perfil?['total_pacientes'] ?? perfil?['pacientes'] ?? perfil?['total'] ?? perfil?['totalPatients'] ?? '-'}'),

                              const SizedBox(height: 6),
                              if (perfil!['profesion'] != null)
                                Text('Profesión: ${perfil!['profesion']}'),
                              const SizedBox(height: 6),
                              // Títulos / talleres
                              (() {
                                final tw = perfil!['titulos'] ??
                                    perfil!['talleres'] ??
                                    perfil!['certificaciones'];
                                if (tw == null) return const SizedBox.shrink();
                                if (tw is List) {
                                  return Wrap(
                                      spacing: 8,
                                      children: tw
                                          .map<Widget>((t) =>
                                              Chip(label: Text(t.toString())))
                                          .toList());
                                }
                                return Text('Títulos: ${tw.toString()}');
                              })(),
                              const SizedBox(height: 6),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Documents / gallery (horizontal)
                      if (documents.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Galería',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 140,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: documents.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, i) {
                                  final doc = documents[i];
                                  String? url;
                                  if (doc['url'] != null) {
                                    url = doc['url'].toString();
                                  }
                                  if (url == null && doc['path'] != null) {
                                    url = doc['path'].toString();
                                  }
                                  if (url == null && doc['file'] != null) {
                                    url = doc['file'].toString();
                                  }
                                  if (url != null && url.startsWith('/')) {
                                    url = ApiService.baseUrl + url;
                                  }
                                  final title = doc['title'] ??
                                      doc['titulo'] ??
                                      doc['name'] ??
                                      '';
                                  return GestureDetector(
                                    onTap: url != null
                                        ? () => showDialog(
                                            context: context,
                                            builder: (ctx) => Dialog(
                                                child: InteractiveViewer(
                                                    child: Image.network(url!,
                                                        fit: BoxFit.contain,
                                                        errorBuilder: (_, __,
                                                                ___) =>
                                                            const Icon(Icons
                                                                .broken_image)))))
                                        : null,
                                    child: Column(
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: Container(
                                            width: 160,
                                            height: 100,
                                            color: Colors.grey[200],
                                            child: url != null
                                                ? Image.network(url,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (c, e, s) =>
                                                        const Icon(
                                                            Icons.broken_image))
                                                : const Center(
                                                    child: Icon(Icons
                                                        .insert_drive_file)),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        SizedBox(
                                            width: 160,
                                            child: Text(title.toString(),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1)),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),

                      // Public profile: no upload/edit controls here.
                    ],
                  ),
                ),
    );
  }
}
