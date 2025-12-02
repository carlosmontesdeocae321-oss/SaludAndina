import 'package:flutter/material.dart';
import '../../services/api_services.dart';
import 'doctor_public_profile.dart';
import '../../route_observer.dart';
import '../../refresh_notifier.dart';

class DoctorListScreen extends StatefulWidget {
  const DoctorListScreen({super.key});

  @override
  State<DoctorListScreen> createState() => _DoctorListScreenState();
}

class _DoctorListScreenState extends State<DoctorListScreen> with RouteAware {
  bool loading = true;
  List<Map<String, dynamic>> doctors = [];
  // Full unfiltered user list (used to derive clinic-linked doctors/patients)
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> clinics = [];
  // Set of usuario IDs that were purchased/vinculados a una clínica
  Set<int> _purchasedDoctorUserIds = <int>{};
  // Set of user IDs that are owners (admin_id) of clinics
  Set<int> _clinicOwnerIds = <int>{};
  bool _isAuthenticated = false;
  final Map<int, bool> _detailsLoading = {};
  final Map<int, bool> _detailsFetched = {};
  final Map<int, Map<String, dynamic>> _clinicStats = {};
  final Map<int, bool> _clinicStatsLoading = {};
  // Persist scroll controllers so reloads don't reset the visible position
  late final ScrollController _doctorsScrollController;
  late final ScrollController _clinicsScrollController;

  @override
  void initState() {
    super.initState();
    _doctorsScrollController = ScrollController();
    _clinicsScrollController = ScrollController();
    _load();
    // Listen to global refresh events (e.g. after creating a doctor)
    globalRefreshNotifier.addListener(_onGlobalRefresh);
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
    try {
      globalRefreshNotifier.removeListener(_onGlobalRefresh);
    } catch (_) {}
    try {
      _doctorsScrollController.dispose();
    } catch (_) {}
    try {
      _clinicsScrollController.dispose();
    } catch (_) {}
    super.dispose();
  }

  @override
  void didPopNext() {
    // The screen became visible again (returned from another route)
    _load();
  }

  void _onGlobalRefresh() {
    // Debounce slightly by scheduling on next frame to avoid conflicts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void didPush() {
    // When first pushed - keep existing behavior (initState already calls _load)
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      _isAuthenticated = await ApiService.isAuthenticated();
      final d = await ApiService.obtenerUsuariosAdmin();
      // Si el backend no devuelve la lista ya ordenada, intentamos respetar
      // el flag `es_de_clinica` cuando esté presente para asegurar que los
      // usuarios de clínica/quienes son dueños queden al final.
      try {
        int flag(Map<String, dynamic> u) {
          final raw =
              u['es_de_clinica'] ?? u['esDeClinica'] ?? u['es_de_clinica'];
          if (raw == null) return 0;
          if (raw is int) return raw != 0 ? 1 : 0;
          if (raw is bool) return raw ? 1 : 0;
          if (raw is String) {
            final s = raw.toLowerCase().trim();
            if (s == '1' || s == 'true' || s == 'si' || s == 'yes') return 1;
            return 0;
          }
          return 0;
        }

        if (d.isNotEmpty) {
          try {
            d.sort((a, b) =>
                flag(Map<String, dynamic>.from(a)) -
                flag(Map<String, dynamic>.from(b)));
          } catch (_) {}
        }
      } catch (_) {}
      // keep a copy of the full user list (unfiltered) so we can compute
      // clinic-linked doctors/patient counts even when `doctors` is filtered
      try {
        _allUsers = d
            .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
            .toList();
        // Debug: print a sample of what the server returned so we can
        // verify fields used for sorting (clinica_id, dueno, es_de_clinica).
        try {} catch (_) {}
      } catch (_) {
        try {
          _allUsers = List<Map<String, dynamic>>.from(d);
        } catch (_) {
          _allUsers = <Map<String, dynamic>>[];
        }
      }
      final c = await ApiService.obtenerClinicasRaw();
      // Build a set of owner IDs from clinics so we can mark owners as clinic-linked
      final Set<int> ownerIds = <int>{};
      try {
        for (final clItem in c) {
          try {
            final map = clItem;
            final maybe = _asInt(map['admin_id'] ??
                map['adminId'] ??
                map['usuario_admin'] ??
                map['owner_id'] ??
                map['dueno_id'] ??
                map['admin'] ??
                map['owner']);
            if (maybe != null) ownerIds.add(maybe);
          } catch (_) {}
        }
      } catch (_) {}
      // Store owner ids in state so sorting logic can detect them
      _clinicOwnerIds = ownerIds;
      // Clear per-doctor detail caches so newly-fetched base list can re-trigger
      // detail fetches (otherwise _detailsFetched may prevent reloading fields).
      // Before building the visible `doctors` list, fetch purchased doctor
      // IDs for all clinics so we can differentiate linked vs created-by-clinic.
      final Set<int> purchasedIds = <int>{};
      try {
        for (final clItem in c) {
          try {
            final cid = _asInt(
                clItem['id'] ?? clItem['clinica_id'] ?? clItem['clinicaId']);
            if (cid == null) continue;
            final lista =
                await ApiService.obtenerUsuariosCompradosPorClinica(cid);
            for (final v in lista) {
              purchasedIds.add(v);
            }
          } catch (_) {}
        }
      } catch (_) {}
      _purchasedDoctorUserIds = purchasedIds;
      try {} catch (_) {}

      _detailsFetched.clear();
      _detailsLoading.clear();

      setState(() {
        // `d` is List<Map<String,dynamic>>; `c` is List<Clinica>
        // Include all doctor accounts (individual + vinculados). We'll show
        // the clinic in the tile subtitle if present. Build the visible
        // list first and then normalize/deduplicate + sort so that doctors
        // linked or created by a clinic appear at the end.
        final visible = d.where((u) {
          try {
            final roleRaw = (u['rol'] ?? u['role'] ?? u['roles']).toString();
            final r = roleRaw.toLowerCase();

            // Determine if this doctor is linked to a clinic and whether it was
            // created by the clinic. We only exclude doctors that are owners or
            // that are explicitly marked as created-by-clinic.
            final docClinicId = _clinicIdFromDoctor(u);
            // Nota: la detección de `isVinculado` se omitió intencionalmente
            // porque preferimos incluir aquí a todos los usuarios que tengan
            // `clinicaId` y dejar la lógica de ocultar owners/creados al
            // paso de merge/sort más abajo.

            // (Nota: la detección 'createdByClinic' no se usa aquí porque
            // ahora incluimos doctores creados por clínica en la lista visible
            // y los empujamos al final mediante _mergeAndSortDoctors.)

            // Basic exclusions first: exclude non-doctors only. Owners
            // (dueños) previously were excluded; now los incluimos en la
            // lista visible y los empujamos al final mediante el sorting.
            if (!r.contains('doctor')) {
              return false;
            }

            // If doctor is linked to a clinic, include them unless they're
            // explicitly created by the clinic. Preference order:
            // - if isVinculado == true -> include
            // - if isVinculado == false -> exclude
            // - if isVinculado == null (unknown) -> include unless isCreatedByClinic
            if (docClinicId != null) {
              // Si el perfil tiene `clinicaId`, lo incluimos en la lista visible.
              // No excluir aquí si `isVinculado` viene como `false` porque
              // queremos mostrar los doctores individuales que estén
              // vinculados a alguna clínica; la depuración/filtrado de
              // owners/creados-por-clínica se hace más abajo en el merge.
              return true;
            }

            // Individual doctor (no clinicId) -> include
            return true;
          } catch (_) {
            return false;
          }
        }).toList();
        // Normalize (merge duplicates) and ensure linked/clinic-created
        // doctors appear last in the final `doctors` list.
        doctors = _mergeAndSortDoctors(visible);
        clinics = c.map((raw) {
          final Map<String, dynamic> map = raw;
          return {
            'id':
                _asInt(map['id'] ?? map['clinica_id'] ?? map['clinicaId']) ?? 0,
            'nombre': map['nombre'] ?? map['name'] ?? '',
            'direccion': map['direccion'] ?? map['address'] ?? map['ubicacion'],
            'telefono_contacto': map['telefono_contacto'] ??
                map['telefono'] ??
                map['phone'] ??
                map['telefonoClinica'],
            'imagen_url': map['imagen_url'] ??
                map['imagenUrl'] ??
                map['imagen'] ??
                map['logo'] ??
                map['logo_url'],
            'pacientes': _asInt(map['pacientes'] ??
                map['pacientes_count'] ??
                map['patients'] ??
                map['patients_count']),
            'doctores': _asInt(map['doctores'] ??
                map['doctores_count'] ??
                map['doctors'] ??
                map['doctors_count']),
            'slots_total': _asInt(map['slots_total'] ??
                map['capacidad'] ??
                map['capacity'] ??
                map['limite_pacientes']),
          };
        }).toList();
      });
    } catch (e, st) {
      debugPrint('DoctorListScreen _loadInitialData error: $e\n$st');
    }
    setState(() => loading = false);
  }

  // Legacy _doctorTile removed (superseded by refreshed implementation below).

  Widget _buildAvatar(String? avatarUrl) {
    if (avatarUrl == null) {
      return const CircleAvatar(radius: 26, child: Icon(Icons.person));
    }
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[200],
      ),
      child: ClipOval(
        child: Image.network(
          avatarUrl,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.person),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _ensureClinicStats(int clinicId) async {
    if (!mounted) return;
    if (_clinicStatsLoading[clinicId] == true) return;

    setState(() {
      _clinicStatsLoading[clinicId] = true;
    });

    Map<String, dynamic> stats = {};
    try {
      final response = await ApiService.obtenerEstadisticasClinica(clinicId);
      if (response != null) {
        stats = Map<String, dynamic>.from(response);
      }
    } catch (_) {}

    final clinicSnapshot = clinics.firstWhere(
      (c) => _asInt(c['id']) == clinicId,
      orElse: () => <String, dynamic>{},
    );

    final Map<String, dynamic> statsClinic =
        stats['clinic'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(stats['clinic'])
            : <String, dynamic>{};

    void mergeInto(Map<String, dynamic> target, Map<String, dynamic> source) {
      source.forEach((key, value) {
        if (value == null) return;
        final str = value.toString();
        if (str.trim().isEmpty) return;
        target.putIfAbsent(key, () => value);
      });
    }

    final mergedClinic = <String, dynamic>{};
    mergeInto(mergedClinic, clinicSnapshot);
    mergeInto(mergedClinic, statsClinic);

    final doctorCount = _countDoctorsForClinic(clinicId);
    if (doctorCount != null) {
      stats['doctors'] = doctorCount;
      mergedClinic.putIfAbsent('doctores', () => doctorCount);
    }

    final patientCount = _derivePatientCountForClinic(clinicId, mergedClinic);
    if (patientCount != null) {
      stats['patients'] = patientCount;
      mergedClinic.putIfAbsent('pacientes', () => patientCount);
    }

    // If we couldn't derive patient count from doctor profiles, try deriving
    // it from appointments (unique pacienteId per clinic) as a fallback.
    int existingPatients = 0;
    try {
      existingPatients = _asInt(stats['patients']) ?? 0;
    } catch (_) {
      existingPatients = 0;
    }

    if (existingPatients == 0) {
      try {
        final allCitas = await ApiService.obtenerCitas();

        final pacientes = <String>{};
        // doctor IDs that belong to this clinic
        final clinicDoctorIds = <int>{};
        for (final u in _allUsers) {
          try {
            final did = _asInt(
                u['id'] ?? u['userId'] ?? u['usuarioId'] ?? u['usuario_id']);
            if (did != null && _clinicIdFromDoctor(u) == clinicId) {
              clinicDoctorIds.add(did);
            }
          } catch (e) {
            debugPrint('DoctorListScreen clinicDoctorIds parse error: $e');
          }
        }

        for (final c in allCitas) {
          try {
            if ((c.clinicaId != null && c.clinicaId == clinicId) ||
                (c.doctorId != null && clinicDoctorIds.contains(c.doctorId!))) {
              pacientes.add(c.pacienteId);
            }
          } catch (e) {
            debugPrint('DoctorListScreen cita parse error: $e');
          }
        }

        if (pacientes.isNotEmpty) {
          stats['patients'] = pacientes.length;
          mergedClinic.putIfAbsent('pacientes', () => pacientes.length);
        }
      } catch (e, st) {
        debugPrint(
            'DoctorListScreen _ensureClinicStats citas fetch error: $e\n$st');
      }
    }

    final capacity = _asInt(
      stats['slots_total'] ??
          stats['capacidad'] ??
          mergedClinic['slots_total'] ??
          mergedClinic['capacidad'],
    );
    if (capacity != null) {
      stats['slots_total'] = capacity;
      mergedClinic.putIfAbsent('slots_total', () => capacity);
      final available =
          stats['availablePatients'] ?? stats['pacientes_disponibles'];
      if (available == null && patientCount != null) {
        stats['availablePatients'] = capacity - patientCount;
      }
    }

    if (mergedClinic.isNotEmpty) {
      stats['clinic'] = mergedClinic;
    }

    if (!mounted) return;
    setState(() {
      _clinicStats[clinicId] = stats;
      _clinicStatsLoading[clinicId] = false;
    });
  }

  Widget _buildClinicImage(String? imageUrl) {
    final borderRadius = BorderRadius.circular(16);
    Widget placeholder() => Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
          ),
          child: Icon(
            Icons.local_hospital,
            size: 32,
            color: Theme.of(context).colorScheme.primary,
          ),
        );

    if (imageUrl == null) {
      return placeholder();
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: Image.network(
        imageUrl,
        width: 88,
        height: 88,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder(),
      ),
    );
  }

  Widget _buildClinicStatChip(IconData icon, String label) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return int.tryParse(trimmed);
    }
    return null;
  }

  String? _asString(dynamic value) {
    if (value == null) return null;
    final String text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return null;
    return text;
  }

  String _formatSpecialtyForTile(dynamic raw) {
    if (raw == null) return 'Especialidad pendiente';
    if (raw is List) {
      final items = raw
          .map((e) => _asString(e))
          .whereType<String>()
          .where((e) => e.isNotEmpty)
          .toList();
      if (items.isEmpty) return 'Especialidad pendiente';
      return items.join(' · ');
    }
    final value = _asString(raw);
    if (value == null) return 'Especialidad pendiente';
    if (value.contains(',')) {
      final parts = value
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (parts.length > 1) return parts.join(' · ');
    }
    return value;
  }

  String _formatCount(dynamic value) {
    num? parsed;
    if (value is num) {
      parsed = value;
    } else if (value is String) {
      parsed = num.tryParse(value.trim());
    }

    if (parsed == null) return '-';
    final num absValue = parsed.abs();
    String formatWithSuffix(num divisor, String suffix) {
      final result = parsed! / divisor;
      final bool whole = result % 1 == 0;
      return whole
          ? '${result.toStringAsFixed(0)}$suffix'
          : '${result.toStringAsFixed(1)}$suffix';
    }

    if (absValue >= 1000000) {
      return formatWithSuffix(1000000, 'M');
    }
    if (absValue >= 1000) {
      return formatWithSuffix(1000, 'K');
    }
    final bool whole = parsed % 1 == 0;
    return whole ? parsed.toStringAsFixed(0) : parsed.toStringAsFixed(1);
  }

  String? _resolveClinicImage(dynamic value) {
    final path = _asString(value);
    if (path == null) return null;
    if (path.startsWith('http')) return path;
    if (path.startsWith('data:')) return path;
    if (path.startsWith('/')) {
      return ApiService.baseUrl + path;
    }
    return '${ApiService.baseUrl}/$path';
  }

  int? _clinicIdFromDoctor(Map<String, dynamic> doc) {
    const keys = [
      'clinicaId',
      'clinica_id',
      'clinica',
      'clinic_id',
      'clinicId',
      'id_clinica',
      'idClinica',
      'clinicaUsuarioId',
      'clinica_usuario_id',
    ];
    for (final key in keys) {
      if (!doc.containsKey(key)) continue;
      final dynamic candidate = doc[key];
      if (candidate is Map<String, dynamic>) {
        final nested = _asInt(candidate['id']);
        if (nested != null) return nested;
      }
      final id = _asInt(candidate);
      if (id != null) return id;
    }
    return null;
  }

  List<Map<String, dynamic>> _mergeAndSortDoctors(
      List<Map<String, dynamic>> source) {
    final Map<int, Map<String, dynamic>> mergedById = {};
    final List<Map<String, dynamic>> withoutId = [];

    for (final entry in source) {
      final map = Map<String, dynamic>.from(entry);
      final id = _asInt(
            map['id'] ??
                map['userId'] ??
                map['usuarioId'] ??
                map['usuario_id'] ??
                map['id_usuario'],
          ) ??
          _asInt(map['doctor_id']);
      if (id == null) {
        withoutId.add(map);
        continue;
      }
      final existing = mergedById[id];
      if (existing == null) {
        mergedById[id] = map;
      } else {
        existing.addAll(map);
      }
    }

    int sortScore(Map<String, dynamic> doctor) {
      final doctorId = _asInt(doctor['id'] ??
              doctor['userId'] ??
              doctor['usuarioId'] ??
              doctor['usuario_id']) ??
          -1;
      final clinicId = _clinicIdFromDoctor(doctor);
      final bool isOwner = doctorId != -1 && _clinicOwnerIds.contains(doctorId);
      final bool isLinked = clinicId != null;
      final bool isPurchased =
          doctorId != -1 && _purchasedDoctorUserIds.contains(doctorId);

      int score = 0;
      if (isOwner) score += 4;
      if (isLinked) score += 2;
      if (isPurchased) score += 1;
      return score;
    }

    final merged = [
      ...mergedById.values,
      ...withoutId,
    ];

    merged.sort((a, b) {
      final scoreA = sortScore(a);
      final scoreB = sortScore(b);
      if (scoreA != scoreB) return scoreA - scoreB;

      final nameA = _asString(a['nombre'] ?? a['usuario'] ?? a['name']) ?? '';
      final nameB = _asString(b['nombre'] ?? b['usuario'] ?? b['name']) ?? '';
      final cmpName = nameA.toLowerCase().compareTo(nameB.toLowerCase());
      if (cmpName != 0) return cmpName;

      final idA =
          _asInt(a['id'] ?? a['userId'] ?? a['usuarioId'] ?? a['usuario_id']) ??
              0;
      final idB =
          _asInt(b['id'] ?? b['userId'] ?? b['usuarioId'] ?? b['usuario_id']) ??
              0;
      return idA.compareTo(idB);
    });

    return merged;
  }

  int? _countDoctorsForClinic(int clinicId) {
    int count = 0;
    for (final user in _allUsers) {
      try {
        final docClinicId = _clinicIdFromDoctor(user);
        if (docClinicId != null && docClinicId == clinicId) {
          count++;
        }
      } catch (_) {}
    }
    return count;
  }

  int? _derivePatientCountForClinic(
      int clinicId, Map<String, dynamic>? mergedClinic) {
    final direct = _asInt(mergedClinic?['pacientes'] ??
        mergedClinic?['patients'] ??
        mergedClinic?['pacientes_count'] ??
        mergedClinic?['patients_count'] ??
        mergedClinic?['totalPacientes']);
    if (direct != null && direct > 0) return direct;

    int total = 0;
    bool hasData = false;
    for (final user in _allUsers) {
      try {
        final docClinicId = _clinicIdFromDoctor(user);
        if (docClinicId != null && docClinicId == clinicId) {
          final count = _asInt(user['totalPacientes'] ??
              user['pacientes'] ??
              user['patients'] ??
              user['pacientes_count'] ??
              user['patients_count']);
          if (count != null) {
            total += count;
            hasData = true;
          }
        }
      } catch (_) {}
    }

    if (hasData) return total;
    return direct;
  }

  Future<void> _ensureDetails(int doctorId, int index) async {
    if (_detailsFetched[doctorId] == true) return;
    if (_detailsLoading[doctorId] == true) return;

    _detailsLoading[doctorId] = true;
    try {
      final Map<String, dynamic> response =
          await ApiService.obtenerPerfilDoctor(doctorId);

      final Map<String, dynamic> data = response['data'] is Map
          ? Map<String, dynamic>.from(response['data'] as Map)
          : Map<String, dynamic>.from(response);

      if (!mounted) return;
      if (index < 0 || index >= doctors.length) return;

      setState(() {
        final current = Map<String, dynamic>.from(doctors[index]);
        void mergeField(String key, dynamic value) {
          if (value == null) return;
          current[key] = value;
        }

        mergeField('especialidad', data['especialidad']);
        mergeField('especialidades', data['especialidades']);
        mergeField('specialty', data['specialty']);
        mergeField('email', data['email'] ?? data['correo']);
        mergeField('telefono', data['telefono']);

        final patients = _asInt(
            data['totalPacientes'] ?? data['pacientes'] ?? data['patients']);
        if (patients != null) {
          current['totalPacientes'] = patients;
        }

        doctors[index] = current;
      });
    } catch (_) {
    } finally {
      _detailsFetched[doctorId] = true;
      _detailsLoading[doctorId] = false;
    }
  }

  Widget _doctorTile(Map<String, dynamic> d, int index) {
    final name = d['nombre'] ?? d['usuario'] ?? d['name'] ?? 'Doctor';
    final id = d['id'] ?? d['userId'] ?? d['usuarioId'];
    final clinicRef = d['clinica'] ??
        d['clinica_nombre'] ??
        d['clinic_name'] ??
        d['clinicaId'] ??
        d['clinica_id'];

    final avatarRaw =
        d['avatar_url'] ?? d['avatar'] ?? d['photo_url'] ?? d['imagen'];
    String? avatarUrl;
    try {
      if (avatarRaw != null) {
        final raw = avatarRaw.toString();
        if (raw.startsWith('http')) {
          avatarUrl = raw;
        } else if (raw.startsWith('/')) {
          avatarUrl = ApiService.baseUrl + raw;
        } else if (raw.startsWith('file://')) {
          avatarUrl = raw.replaceFirst('file://', '');
        } else {
          avatarUrl =
              ApiService.baseUrl + (raw.startsWith('/') ? '' : '/') + raw;
        }
      }
    } catch (_) {
      avatarUrl = null;
    }

    String? clinicName;
    try {
      if (clinicRef != null) {
        if (clinicRef is int) {
          final found =
              clinics.firstWhere((c) => c['id'] == clinicRef, orElse: () => {});
          if (found.isNotEmpty) clinicName = found['nombre']?.toString();
        } else if (clinicRef is String && int.tryParse(clinicRef) != null) {
          final cid = int.parse(clinicRef);
          final found =
              clinics.firstWhere((c) => c['id'] == cid, orElse: () => {});
          if (found.isNotEmpty) clinicName = found['nombre']?.toString();
        } else {
          clinicName = clinicRef.toString();
        }
      }
    } catch (_) {}

    final patientCount = d['totalPacientes'] ??
        d['patients'] ??
        d['total_pacientes'] ??
        d['pacientes'] ??
        d['total'] ??
        d['totalPatients'];
    final specialty =
        d['especialidad'] ?? d['especialidades'] ?? d['specialty'];

    final idInt = id is int ? id : int.tryParse(id?.toString() ?? '');
    if (idInt != null && (patientCount == null || specialty == null)) {
      _ensureDetails(idInt, index);
    }

    final chipElements = <Widget>[
      _buildInfoChip(Icons.badge_outlined, _formatSpecialtyForTile(specialty)),
      _buildInfoChip(
          Icons.people_alt_outlined, 'Pacientes: ${patientCount ?? '-'}'),
    ];

    bool isClinicUser = false;
    bool isOwner = false;
    try {
      final esDeClinicaRaw =
          d['es_de_clinica'] ?? d['esDeClinica'] ?? d['es_de_clinica'];
      if (esDeClinicaRaw != null) {
        if (esDeClinicaRaw is int && esDeClinicaRaw != 0) isClinicUser = true;
        if (esDeClinicaRaw is String) {
          final s = esDeClinicaRaw.toLowerCase().trim();
          if (s == '1' || s == 'true' || s == 'si' || s == 'yes') {
            isClinicUser = true;
          }
        }
      }
      if (!isClinicUser && _clinicIdFromDoctor(d) != null) {
        isClinicUser = true;
      }
      final ownerRaw =
          d['dueno'] ?? d['es_dueno'] ?? d['owner'] ?? d['is_owner'];
      if (ownerRaw != null) {
        if (ownerRaw is bool && ownerRaw) isOwner = true;
        if (ownerRaw is int && ownerRaw != 0) isOwner = true;
        if (ownerRaw is String) {
          final s = ownerRaw.toLowerCase().trim();
          if (s == '1' || s == 'true' || s == 'si' || s == 'yes') {
            isOwner = true;
          }
        }
      }
    } catch (_) {}

    if (isClinicUser || isOwner) {
      chipElements.insert(
          0,
          _buildInfoChip(Icons.apartment_outlined,
              isOwner ? 'Dueño · Clínica' : 'Clínica'));
    }
    if (clinicName != null && clinicName.isNotEmpty) {
      chipElements.insert(
          0, _buildInfoChip(Icons.local_hospital_outlined, clinicName));
    }

    Future<void> openPreview() async {
      final doctorId = idInt;
      if (doctorId == null) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            content: FutureBuilder<Map<String, dynamic>?>(
              future: _fetchProfileForPreview(doctorId),
              builder: (dialogContext, snap) {
                if (!snap.hasData) {
                  return const SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final data = snap.data;
                if (data == null) {
                  return const Text('No se pudo cargar el perfil');
                }

                final displayName = data['nombre'] ??
                    data['usuario'] ??
                    data['name'] ??
                    'Doctor';
                final specialtyProfile =
                    data['especialidad'] ?? data['especialidad_medica'] ?? '';
                final email = data['email'] ?? data['correo'] ?? '';
                final avatarRaw =
                    data['avatar_url'] ?? data['avatar'] ?? data['photo_url'];
                String? avatar;
                if (avatarRaw != null && avatarRaw.toString().isNotEmpty) {
                  final raw = avatarRaw.toString();
                  if (raw.startsWith('http')) {
                    avatar = raw;
                  } else {
                    const prefix = ApiService.baseUrl;
                    avatar = prefix + (raw.startsWith('/') ? '' : '/') + raw;
                  }
                }
                final clinicLabel = data['clinica'] ??
                    data['clinica_nombre'] ??
                    data['clinic_name'];

                final dialogTheme = Theme.of(dialogContext);

                return SizedBox(
                  width: 360,
                  child: Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (avatar != null && avatar.isNotEmpty)
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.grey[200],
                                  ),
                                  child: ClipOval(
                                    child: Image.network(
                                      avatar,
                                      width: 64,
                                      height: 64,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.person, size: 32),
                                    ),
                                  ),
                                )
                              else
                                const CircleAvatar(
                                  radius: 32,
                                  child: Icon(Icons.person),
                                ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayName.toString(),
                                      style: dialogTheme.textTheme.titleMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w700),
                                    ),
                                    if (specialtyProfile
                                        .toString()
                                        .trim()
                                        .isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text('Especialidad: $specialtyProfile'),
                                    ],
                                    if (clinicLabel != null &&
                                        clinicLabel
                                            .toString()
                                            .trim()
                                            .isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        'Clínica: ${clinicLabel.toString()}',
                                        style: dialogTheme.textTheme.bodySmall
                                            ?.copyWith(
                                          color: dialogTheme
                                              .colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (email.toString().trim().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.email,
                                    size: 16, color: Colors.grey),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    email.toString(),
                                    style: dialogTheme.textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (data['telefono'] != null &&
                              data['telefono']
                                  .toString()
                                  .trim()
                                  .isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.phone,
                                    size: 16, color: Colors.grey),
                                const SizedBox(width: 6),
                                Text(
                                  data['telefono'].toString(),
                                  style: dialogTheme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ],
                          if (data['bio'] != null &&
                              data['bio'].toString().trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              data['bio'].toString(),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: dialogTheme.textTheme.bodySmall,
                            ),
                          ],
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                try {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DoctorPublicProfile(
                                          doctorId: doctorId),
                                    ),
                                  );
                                } catch (_) {}
                              },
                              child: const Text('Ver perfil completo'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cerrar'),
              ),
            ],
          );
        },
      );
    }

    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.96),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: openPreview,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primary.withOpacity(0.6),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAvatar(avatarUrl),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.toString(),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ID: ${idInt ?? '-'}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                letterSpacing: 0.2,
                              ),
                            ),
                            if (d['email'] != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                d['email'].toString(),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          color: Colors.grey, size: 20),
                    ],
                  ),
                  if (chipElements.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: chipElements,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper to fetch profile for preview: returns Map or null. Uses public endpoint when unauthenticated.
  Future<Map<String, dynamic>?> _fetchProfileForPreview(int id) async {
    try {
      final auth = await ApiService.isAuthenticated();
      if (auth) {
        final resp = await ApiService.obtenerPerfilDoctor(id);
        if ((resp['ok'] ?? false) == true) {
          final data = resp['data'];
          if (data is Map<String, dynamic>) {
            return Map<String, dynamic>.from(data);
          }
        }
        return null;
      } else {
        return await ApiService.obtenerPerfilDoctorPublic(id);
      }
    } catch (_) {
      return null;
    }
  }

  Widget _clinicTile(Map<String, dynamic> clinic) {
    final rawId = _asInt(clinic['id']);
    final clinicId = rawId != null && rawId > 0 ? rawId : null;
    if (clinicId != null &&
        !_clinicStats.containsKey(clinicId) &&
        !(_clinicStatsLoading[clinicId] ?? false)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ensureClinicStats(clinicId);
      });
    }

    final stats = clinicId != null ? _clinicStats[clinicId] : null;
    final statsClinic = stats != null && stats['clinic'] is Map
        ? Map<String, dynamic>.from(stats['clinic'] as Map)
        : null;

    final merged = <String, dynamic>{};
    void merge(Map<String, dynamic>? source) {
      if (source == null) return;
      source.forEach((key, value) {
        if (value == null) return;
        final str = value.toString();
        if (str.trim().isEmpty) return;
        merged[key] = value;
      });
    }

    merge(clinic);
    merge(statsClinic);

    final name =
        _asString(merged['nombre'] ?? merged['name']) ?? 'Clínica sin nombre';
    final direccion = _asString(merged['direccion'] ?? merged['address']);
    final telefono = _asString(
      merged['telefono_contacto'] ??
          merged['telefono'] ??
          merged['phone'] ??
          merged['telefonoClinica'],
    );
    final imageUrl = _resolveClinicImage(
      merged['imagen_url'] ??
          merged['imagenUrl'] ??
          merged['logo'] ??
          merged['imagen'],
    );

    final doctorCount =
        stats?['doctors'] ?? merged['doctores'] ?? merged['doctors'];
    final patientCount =
        stats?['patients'] ?? merged['pacientes'] ?? merged['patients'];
    final capacity = stats?['slots_total'] ??
        stats?['capacidad'] ??
        merged['slots_total'] ??
        merged['capacidad'];
    final available =
        stats?['availablePatients'] ?? stats?['pacientes_disponibles'];
    final appointmentsToday = stats?['appointments_today'] ??
        stats?['citas_hoy'] ??
        stats?['appointmentsToday'];

    final loadingStats =
        clinicId != null && (_clinicStatsLoading[clinicId] ?? false);

    // Resolve counts: prefer server stats, then merged values, then local derivation
    final resolvedDoctorCount = doctorCount ??
        (clinicId != null ? _countDoctorsForClinic(clinicId) : null);
    final resolvedPatientCount = patientCount ??
        (clinicId != null
            ? _derivePatientCountForClinic(clinicId, merged)
            : null);

    String patientLabel;
    if (resolvedPatientCount != null) {
      patientLabel = 'Pacientes: ${_formatCount(resolvedPatientCount)}';
    } else if (!_isAuthenticated) {
      patientLabel = 'Pacientes: Inicia sesión';
    } else {
      patientLabel = 'Pacientes: ${_formatCount(resolvedPatientCount)}';
    }

    final chips = <Widget>[
      _buildClinicStatChip(Icons.people_alt_outlined, patientLabel),
      _buildClinicStatChip(Icons.medical_information_outlined,
          'Doctores: ${_formatCount(resolvedDoctorCount)}'),
    ];

    if (capacity != null) {
      final capacityLabel = available != null
          ? 'Capacidad: ${_formatCount(capacity)} · Disponibles: ${_formatCount(available)}'
          : 'Capacidad: ${_formatCount(capacity)}';
      chips.add(
        _buildClinicStatChip(Icons.apartment_outlined, capacityLabel),
      );
    }

    if (appointmentsToday != null) {
      chips.add(
        _buildClinicStatChip(Icons.event_available_outlined,
            'Citas hoy: ${_formatCount(appointmentsToday)}'),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showClinicDoctorsDialog(clinic),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildClinicImage(imageUrl),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (clinicId != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'ID: $clinicId',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .outline
                                    .withOpacity(0.8),
                              ),
                            ),
                          ),
                        if (direccion != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
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
                                      fontSize: 13,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (telefono != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              children: [
                                const Icon(Icons.phone,
                                    size: 16, color: Colors.grey),
                                const SizedBox(width: 6),
                                Text(
                                  telefono,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (chips.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: chips,
                ),
              ],
              if (loadingStats) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Calculando estadísticas...'),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showClinicDoctorsDialog(Map<String, dynamic> clinic) {
    final rawId = _asInt(clinic['id']);
    final clinicId = rawId != null && rawId > 0 ? rawId : null;

    // Find doctors that belong to this clinic (vinculados o creados)
    final linkedDoctors = <Map<String, dynamic>>[];
    if (clinicId != null) {
      for (final d in _allUsers) {
        try {
          final docClinicId = _clinicIdFromDoctor(d);
          if (docClinicId != null && docClinicId == clinicId) {
            linkedDoctors.add(d);
          }
        } catch (_) {}
      }
    }

    final clinicPatientsCount = clinic['pacientes'] ??
        clinic['patients'] ??
        clinic['pacientes_count'] ??
        clinic['patients_count'];
    final resolvedPatientCount = clinicPatientsCount ??
        (clinicId != null
            ? _derivePatientCountForClinic(clinicId, clinic)
            : null);
    final patientCountLabel = _formatCount(resolvedPatientCount);
    final doctorCountLabel = linkedDoctors.isEmpty
        ? (clinicId != null
            ? (_countDoctorsForClinic(clinicId)?.toString() ?? '-')
            : '-')
        : linkedDoctors.length.toString();

    showDialog<void>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title:
                Text(_asString(clinic['nombre']) ?? 'Doctores de la clínica'),
            content: SizedBox(
              width: 360,
              height: 360,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                        'Pacientes: $patientCountLabel · Doctores: $doctorCountLabel',
                        style: TextStyle(
                            color:
                                Theme.of(context).textTheme.bodySmall?.color)),
                  ),
                  Expanded(
                    child: linkedDoctors.isEmpty
                        ? Center(
                            child: Text(clinicId == null
                                ? 'ID de clínica no disponible'
                                : 'No hay doctores vinculados a esta clínica.'),
                          )
                        : ListView.separated(
                            itemCount: linkedDoctors.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final doc = linkedDoctors[i];
                              final name = doc['nombre'] ??
                                  doc['usuario'] ??
                                  doc['name'] ??
                                  'Doctor';
                              final id = doc['id'] ??
                                  doc['userId'] ??
                                  doc['usuarioId'] ??
                                  doc['usuario_id'];
                              return ListTile(
                                title: Text(name.toString()),
                                subtitle: Text('ID: ${id ?? '-'}'),
                                dense: true,
                              );
                            },
                          ),
                  )
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cerrar'))
            ],
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Doctores y Clínicas'),
          bottom: const TabBar(
              tabs: [Tab(text: 'Doctores'), Tab(text: 'Clínicas')]),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  doctors.isEmpty
                      ? const Center(child: Text('No se encontraron doctores'))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            controller: _doctorsScrollController,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            itemBuilder: (_, i) => _doctorTile(doctors[i], i),
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemCount: doctors.length,
                          ),
                        ),
                  clinics.isEmpty
                      ? const Center(child: Text('No se encontraron clínicas'))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            controller: _clinicsScrollController,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            itemCount: clinics.length,
                            itemBuilder: (_, i) => _clinicTile(clinics[i]),
                          ),
                        ),
                ],
              ),
      ),
    );
  }
}
