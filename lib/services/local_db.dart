import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'sync_notifier.dart';

class LocalDb {
  LocalDb._();

  static const String _patientsBox = 'patients_box';
  static const String _metaBox = 'local_meta';
  static const String _consultasBox = 'consultas_box';
  static const String _citasBox = 'citas_box';

  static Future<void> init() async {
    await Hive.initFlutter();
    // Open boxes if not opened
    if (!Hive.isBoxOpen(_patientsBox)) await Hive.openBox(_patientsBox);
    if (!Hive.isBoxOpen(_metaBox)) await Hive.openBox(_metaBox);
    if (!Hive.isBoxOpen(_consultasBox)) await Hive.openBox(_consultasBox);
    if (!Hive.isBoxOpen(_citasBox)) await Hive.openBox(_citasBox);
    // Initialize pending counters
    try {
      await _recomputePendingCounts();
    } catch (_) {}
  }

  // ----------------------- DOCTORES / CLINICAS CACHE -----------------------
  static Future<void> saveDoctors(List<Map<String, dynamic>> doctors) async {
    final box = Hive.box(_metaBox);
    try {
      await box.put('doctors', doctors);
    } catch (e) {
      debugPrint('LocalDb.saveDoctors error: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getDoctors() async {
    final box = Hive.box(_metaBox);
    final raw = box.get('doctors');
    if (raw is List) {
      return raw
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  static Future<void> saveClinics(List<Map<String, dynamic>> clinics) async {
    final box = Hive.box(_metaBox);
    try {
      await box.put('clinics', clinics);
    } catch (e) {
      debugPrint('LocalDb.saveClinics error: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getClinics() async {
    final box = Hive.box(_metaBox);
    final raw = box.get('clinics');
    if (raw is List) {
      return raw
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  static String _newId() => const Uuid().v4();

  // Reactive notifier for pending patients count (UI can listen to this)
  static final ValueNotifier<int> pendingPatientsCount = ValueNotifier<int>(0);

  static Future<void> _recomputePendingCounts() async {
    try {
      final box = Hive.box(_patientsBox);
      int cnt = 0;
      for (final key in box.keys) {
        final v = box.get(key);
        if (v is Map) {
          final map = Map<String, dynamic>.from(v.cast<String, dynamic>());
          if (map['syncStatus'] == 'pending') cnt += 1;
        }
      }
      pendingPatientsCount.value = cnt;
      // Also refresh global sync notifier so drawer/other UI elements stay in sync
      try {
        SyncNotifier.instance.refresh();
      } catch (_) {}
    } catch (e) {
      debugPrint('LocalDb._recomputePendingCounts error: $e');
    }
  }

  // Save patient locally. Returns localId
  static Future<String> savePatient(Map<String, dynamic> patient,
      {String? localId}) async {
    final box = Hive.box(_patientsBox);
    final id = localId ?? _newId();
    final now = DateTime.now().toIso8601String();
    final record = {
      'localId': id,
      'serverId': patient['serverId']?.toString(),
      'data': patient,
      'syncStatus': 'pending',
      'createdAt': patient['createdAt'] ?? now,
      'updatedAt': patient['updatedAt'] ?? now,
      'attachments': patient['attachments'] ?? [],
      'lastError': null,
    };
    await box.put(id, record);
    // Update reactive pending counter
    await _recomputePendingCounts();
    return id;
  }

  static Future<List<Map<String, dynamic>>> getPatients(
      {bool onlySynced = false}) async {
    final box = Hive.box(_patientsBox);
    final List<Map<String, dynamic>> out = [];
    for (final key in box.keys) {
      final v = box.get(key);
      if (v is Map) {
        final map = Map<String, dynamic>.from(v.cast<String, dynamic>());
        if (onlySynced) {
          if (map['syncStatus'] == 'synced') out.add(map);
        } else {
          out.add(map);
        }
      }
    }
    return out;
  }

  /// Buscar paciente local por cédula. Retorna el mapa del registro local (incluye 'data').
  static Future<Map<String, dynamic>?> getPatientByCedula(String cedula) async {
    final box = Hive.box(_patientsBox);
    for (final key in box.keys) {
      final v = box.get(key);
      if (v is Map) {
        final map = Map<String, dynamic>.from(v.cast<String, dynamic>());
        final data = map['data'] as Map<String, dynamic>?;
        if (data != null) {
          final c = (data['cedula'] ?? data['ci'] ?? data['dni'])?.toString();
          if (c != null && c == cedula) return map;
        }
      }
    }
    return null;
  }

  /// Buscar paciente local por serverId o localId
  static Future<Map<String, dynamic>?> getPatientById(String id) async {
    final box = Hive.box(_patientsBox);
    // First try by serverId
    for (final key in box.keys) {
      final v = box.get(key);
      if (v is Map) {
        final map = Map<String, dynamic>.from(v.cast<String, dynamic>());
        final srv = map['serverId']?.toString() ?? '';
        if (srv.isNotEmpty && srv == id) return map;
      }
    }
    // Then try by localId
    final v = box.get(id);
    if (v is Map) return Map<String, dynamic>.from(v.cast<String, dynamic>());
    return null;
  }

  /// Save or update a patient record received from the server into local DB.
  /// Marks the record as `synced` and stores `serverId`.
  static Future<void> saveOrUpdateRemotePatient(
      Map<String, dynamic> serverObj) async {
    final box = Hive.box(_patientsBox);
    final serverId = serverObj['id']?.toString() ?? '';
    final now = DateTime.now().toIso8601String();

    try {
      // 1) If server provided a client_local_id, try to match the local record
      final clientLocalId = serverObj['client_local_id']?.toString() ??
          serverObj['clientLocalId']?.toString();
      if (clientLocalId != null && clientLocalId.isNotEmpty) {
        // 1a) Direct key match (local record stored under localId)
        final v = box.get(clientLocalId);
        if (v is Map) {
          final map = Map<String, dynamic>.from(v.cast<String, dynamic>());
          map['data'] = serverObj;
          map['syncStatus'] = 'synced';
          map['serverId'] = serverId;
          map['updatedAt'] = now;
          await box.put(clientLocalId, map);
          return;
        }

        // 1b) Search through records: some local records may not use the
        // localId as Hive key but still contain client_local_id inside data.
        for (final key in box.keys) {
          try {
            final candidate = box.get(key);
            if (candidate is Map) {
              final map =
                  Map<String, dynamic>.from(candidate.cast<String, dynamic>());
              final data = Map<String, dynamic>.from(map['data'] ?? {});
              final localClient = (data['client_local_id']?.toString() ??
                      data['clientLocalId']?.toString() ??
                      '')
                  .toString();
              if (localClient.isNotEmpty && localClient == clientLocalId) {
                // Merge server info into existing local record
                try {
                  final existing = Map<String, dynamic>.from(map['data'] ?? {});
                  existing.addAll(serverObj);
                  map['data'] = existing;
                } catch (_) {
                  map['data'] = serverObj;
                }
                map['syncStatus'] = 'synced';
                map['serverId'] = serverId;
                map['updatedAt'] = now;
                await box.put(key, map);
                return;
              }
            }
          } catch (_) {}
        }
      }

      // 2) Try to find by serverId (existing synced record)
      for (final key in box.keys) {
        final v = box.get(key);
        if (v is Map) {
          final map = Map<String, dynamic>.from(v.cast<String, dynamic>());
          if ((map['serverId']?.toString() ?? '') == serverId &&
              serverId.isNotEmpty) {
            map['data'] = serverObj;
            map['syncStatus'] = 'synced';
            map['updatedAt'] = now;
            await box.put(key, map);
            return;
          }
        }
      }

      // 3) Try to find a local record with same cedula (common duplicate source)
      try {
        final ced = (serverObj['cedula'] ?? serverObj['dni'] ?? serverObj['ci'])
                ?.toString() ??
            '';
        if (ced.isNotEmpty) {
          for (final key in box.keys) {
            final v = box.get(key);
            if (v is Map) {
              final map = Map<String, dynamic>.from(v.cast<String, dynamic>());
              final data = Map<String, dynamic>.from(map['data'] ?? {});
              final localCed =
                  (data['cedula'] ?? data['dni'] ?? data['ci'])?.toString() ??
                      '';
              if (localCed.isNotEmpty && localCed == ced) {
                // Merge: prefer server data, but preserve localId
                map['data'] = serverObj;
                map['syncStatus'] = 'synced';
                map['serverId'] = serverId;
                map['updatedAt'] = now;
                await box.put(key, map);
                return;
              }
            }
          }
        }
      } catch (_) {}

      // 4) Not found -> create new local record marked as synced
      final id = _newId();
      debugPrint(
          'LocalDb: creating new local patient from server (serverId=$serverId client_local_id=${serverObj['client_local_id'] ?? serverObj['clientLocalId']})');
      final record = {
        'localId': id,
        'serverId': serverId,
        'data': serverObj,
        'syncStatus': 'synced',
        'createdAt': now,
        'updatedAt': now,
        'attachments': serverObj['attachments'] ?? [],
        'lastError': null,
      };
      await box.put(id, record);
    } catch (e) {
      debugPrint('LocalDb.saveOrUpdateRemotePatient error: $e');
    }
  }

  /// Save multiple server patient objects into local DB (best-effort, non-blocking).
  static Future<void> saveOrUpdateRemotePatientsBatch(
      List<dynamic> serverList) async {
    try {
      for (final item in serverList) {
        if (item is Map<String, dynamic>) {
          await saveOrUpdateRemotePatient(item);
        } else if (item is Map) {
          await saveOrUpdateRemotePatient(Map<String, dynamic>.from(item));
        }
      }
    } catch (e) {
      debugPrint('LocalDb.saveOrUpdateRemotePatientsBatch error: $e');
    }
  }

  // ----------------------- CONSULTAS -----------------------
  static Future<void> saveOrUpdateRemoteConsulta(
      Map<String, dynamic> serverObj) async {
    final box = Hive.box(_consultasBox);
    final serverId = serverObj['id']?.toString() ?? '';
    final pacienteId = serverObj['paciente_id']?.toString() ??
        serverObj['pacienteId']?.toString();
    final now = DateTime.now().toIso8601String();
    try {
      // 0) If server provided a client_local_id, try to match the local record
      // so we don't create duplicates when a locally-created consulta is later
      // returned by the server.
      final clientLocal = serverObj['client_local_id']?.toString() ??
          serverObj['clientLocalId']?.toString() ??
          '';
      if (clientLocal.isNotEmpty) {
        final localRec = box.get(clientLocal);
        if (localRec is Map) {
          final map =
              Map<String, dynamic>.from(localRec.cast<String, dynamic>());
          // Merge server object into existing local data instead of replacing it.
          try {
            final existing = Map<String, dynamic>.from(map['data'] ?? {});
            existing.addAll(serverObj);
            map['data'] = existing;
          } catch (_) {
            map['data'] = serverObj;
          }
          map['syncStatus'] = 'synced';
          map['serverId'] = serverId;
          map['updatedAt'] = now;
          await box.put(clientLocal, map);
          return;
        }
        // Also try to find by local record whose data.client_local_id equals this
        for (final key in box.keys) {
          final v = box.get(key);
          if (v is Map) {
            final m = Map<String, dynamic>.from(v.cast<String, dynamic>());
            final data = Map<String, dynamic>.from(m['data'] ?? {});
            if ((data['client_local_id']?.toString() ?? '') == clientLocal) {
              m['data'] = serverObj;
              m['syncStatus'] = 'synced';
              m['serverId'] = serverId;
              m['updatedAt'] = now;
              await box.put(key, m);
              return;
            }
          }
        }
      }

      // 2) Try to find by serverId (existing synced record)
      for (final key in box.keys) {
        final v = box.get(key);
        if (v is Map) {
          final map = Map<String, dynamic>.from(v.cast<String, dynamic>());
          if ((map['serverId']?.toString() ?? '') == serverId &&
              serverId.isNotEmpty) {
            // Merge instead of overwrite to preserve local-only fields
            try {
              final existing = Map<String, dynamic>.from(map['data'] ?? {});
              existing.addAll(serverObj);
              map['data'] = existing;
            } catch (_) {
              map['data'] = serverObj;
            }
            map['syncStatus'] = 'synced';
            map['updatedAt'] = now;
            await box.put(key, map);
            return;
          }
        }
      }

      // 3) Heuristic: try to match a pending local consulta by pacienteId + fecha + motivo
      try {
        final srvFecha = (serverObj['fecha'] ?? '')?.toString() ?? '';
        final srvMotivo =
            (serverObj['motivo'] ?? serverObj['motivo_consulta'] ?? '')
                    ?.toString() ??
                '';
        if (srvFecha.isNotEmpty &&
            srvMotivo.isNotEmpty &&
            (pacienteId?.isNotEmpty ?? false)) {
          for (final key in box.keys) {
            final v = box.get(key);
            if (v is Map) {
              final m = Map<String, dynamic>.from(v.cast<String, dynamic>());
              final status = (m['syncStatus'] ?? '')?.toString() ?? '';
              if (status != 'pending') continue;
              final data = Map<String, dynamic>.from(m['data'] ?? {});
              final localPid =
                  (m['pacienteId'] ?? data['paciente_id'] ?? data['pacienteId'])
                          ?.toString() ??
                      '';
              if (localPid.isEmpty) continue;
              var matchesPaciente = false;
              try {
                // If localPid looks like a localId (uuid with dash), try to
                // resolve the local patient's serverId and compare.
                if (localPid.contains('-')) {
                  final localPatient = await getPatientById(localPid);
                  if (localPatient != null) {
                    final localSrv =
                        (localPatient['serverId']?.toString() ?? '');
                    if (localSrv.isNotEmpty && localSrv == (pacienteId ?? '')) {
                      matchesPaciente = true;
                    }
                  }
                }
              } catch (_) {}
              // Fallback: direct compare (both strings are server ids or pre-resolved)
              if (!matchesPaciente) {
                if (localPid != (pacienteId ?? '')) continue;
              }
              final localFecha = (data['fecha'] ?? '')?.toString() ?? '';
              final localMotivo =
                  (data['motivo'] ?? data['motivo_consulta'] ?? '')
                          ?.toString() ??
                      '';
              if (localFecha == srvFecha && localMotivo == srvMotivo) {
                // Match found: merge server object into this pending local record
                try {
                  final existing = Map<String, dynamic>.from(m['data'] ?? {});
                  existing.addAll(serverObj);
                  m['data'] = existing;
                } catch (_) {
                  m['data'] = serverObj;
                }
                m['syncStatus'] = 'synced';
                m['serverId'] = serverId;
                m['updatedAt'] = now;
                await box.put(key, m);
                return;
              }
            }
          }
        }
      } catch (_) {}

      // 2) Not found -> create new local record marked as synced
      // If server provided client_local_id but we didn't match it above,
      // log for telemetry to help diagnose missing matches.
      final clientLocalWarn = serverObj['client_local_id']?.toString() ??
          serverObj['clientLocalId']?.toString() ??
          '';
      if (clientLocalWarn.isNotEmpty) {
        debugPrint(
            'LocalDb: server returned client_local_id but no local match found: client_local_id=$clientLocalWarn serverId=$serverId');
      }

      final id = _newId();
      final record = {
        'localId': id,
        'serverId': serverId,
        'pacienteId': pacienteId,
        'data': serverObj,
        'syncStatus': 'synced',
        'createdAt': now,
        'updatedAt': now,
      };
      await box.put(id, record);
    } catch (e) {
      debugPrint('LocalDb.saveOrUpdateRemoteConsulta error: $e');
    }
  }

  static Future<void> saveOrUpdateRemoteConsultasBatch(
      List<dynamic> serverList) async {
    try {
      for (final item in serverList) {
        if (item is Map<String, dynamic>) {
          await saveOrUpdateRemoteConsulta(item);
        } else if (item is Map) {
          await saveOrUpdateRemoteConsulta(Map<String, dynamic>.from(item));
        }
      }
    } catch (e) {
      debugPrint('LocalDb.saveOrUpdateRemoteConsultasBatch error: $e');
    }
  }

  /// Save a consulta locally as pending (created offline).
  /// Returns generated localId.
  static Future<String> saveConsultaLocal(Map<String, dynamic> consulta,
      {String? localId, List<String>? attachments}) async {
    final box = Hive.box(_consultasBox);
    final id = localId ?? _newId();
    final now = DateTime.now().toIso8601String();
    // Normalize paciente id: prefer explicit keys, ensure it's a non-empty string
    String? pacienteId =
        (consulta['paciente_id'] ?? consulta['pacienteId'])?.toString();
    if (pacienteId == null || pacienteId.trim().isEmpty) {
      // Attempt alternate keys
      pacienteId = (consulta['paciente'] ?? consulta['patient_id'])?.toString();
    }
    if (pacienteId == null || pacienteId.trim().isEmpty) {
      // As a defensive fallback, store a non-empty marker so this record does
      // not accidentally match other patients. Use the local id to keep it
      // unique and traceable.
      pacienteId = 'local-paciente-$id';
      try {
        // also write it into the data payload for consistency
        consulta['paciente_id'] = pacienteId;
      } catch (_) {}
    }
    // Ensure client_local_id exists in the consulta payload so remote
    // objects that later include it can be matched deterministically.
    try {
      consulta['client_local_id'] = consulta['client_local_id'] ?? id;
    } catch (_) {}
    final record = {
      'localId': id,
      'serverId': consulta['id']?.toString(),
      'pacienteId': pacienteId,
      'data': consulta,
      'syncStatus': 'pending',
      'createdAt': consulta['createdAt'] ?? now,
      'updatedAt': consulta['updatedAt'] ?? now,
      'attachments': attachments ?? consulta['imagenes'] ?? [],
      'lastError': null,
    };
    await box.put(id, record);
    // If the consulta references a local patient, ensure pending counts recomputed
    try {
      await _recomputePendingCounts();
    } catch (_) {}
    return id;
  }

  /// Upsert a local consulta: if `localId` exists update that record; else
  /// if `serverId` provided try to update the matching record by serverId;
  /// otherwise create a new local pending consulta. Returns the localId.
  static Future<String> upsertConsultaLocal(Map<String, dynamic> consulta,
      {String? localId, String? serverId, List<String>? attachments}) async {
    final box = Hive.box(_consultasBox);
    try {
      // Try update by explicit localId
      if (localId != null && localId.isNotEmpty) {
        final v = box.get(localId);
        if (v is Map) {
          final map = Map<String, dynamic>.from(v.cast<String, dynamic>());
          map['data'] = consulta;
          map['attachments'] = attachments ?? map['attachments'] ?? [];
          map['updatedAt'] = DateTime.now().toIso8601String();
          map['syncStatus'] = 'pending';
          await box.put(localId, map);
          try {
            await SyncNotifier.instance.refresh();
          } catch (_) {}
          return localId;
        }
      }

      // Try update by serverId
      if (serverId != null && serverId.isNotEmpty) {
        for (final key in box.keys) {
          final v = box.get(key);
          if (v is Map) {
            final map = Map<String, dynamic>.from(v.cast<String, dynamic>());
            if ((map['serverId']?.toString() ?? '') == serverId) {
              map['data'] = consulta;
              map['attachments'] = attachments ?? map['attachments'] ?? [];
              map['updatedAt'] = DateTime.now().toIso8601String();
              map['syncStatus'] = 'pending';
              await box.put(key, map);
              try {
                await SyncNotifier.instance.refresh();
              } catch (_) {}
              return key.toString();
            }
          }
        }
      }

      // Not found: create new local record
      return await saveConsultaLocal(consulta,
          localId: localId, attachments: attachments);
    } catch (e) {
      debugPrint('LocalDb.upsertConsultaLocal error: $e');
      return await saveConsultaLocal(consulta,
          localId: localId, attachments: attachments);
    }
  }

  static Future<List<Map<String, dynamic>>> getConsultasByPacienteId(
      String pacienteId) async {
    final box = Hive.box(_consultasBox);
    final out = <Map<String, dynamic>>[];
    for (final key in box.keys) {
      final v = box.get(key);
      if (v is Map) {
        final map = Map<String, dynamic>.from(v.cast<String, dynamic>());
        String pid = '';
        try {
          final top = map['pacienteId'];
          if (top != null) pid = top.toString();
        } catch (_) {}
        if (pid.isEmpty) {
          try {
            final data = map['data'];
            if (data is Map) {
              pid =
                  (data['paciente_id'] ?? data['pacienteId'] ?? '').toString();
            }
          } catch (_) {}
        }
        pid = pid.trim();
        if (pid.isNotEmpty && pid == pacienteId) out.add(map);
      }
    }
    return out;
  }

  // ----------------------- CITAS -----------------------
  static Future<void> saveOrUpdateRemoteCita(
      Map<String, dynamic> serverObj) async {
    final box = Hive.box(_citasBox);
    final serverId = serverObj['id']?.toString() ?? '';
    final pacienteId = serverObj['paciente_id']?.toString() ??
        serverObj['pacienteId']?.toString();
    final now = DateTime.now().toIso8601String();
    try {
      for (final key in box.keys) {
        final v = box.get(key);
        if (v is Map) {
          final map = Map<String, dynamic>.from(v.cast<String, dynamic>());
          if ((map['serverId']?.toString() ?? '') == serverId) {
            map['data'] = serverObj;
            map['syncStatus'] = 'synced';
            map['updatedAt'] = now;
            await box.put(key, map);
            return;
          }
        }
      }
      final id = _newId();
      final record = {
        'localId': id,
        'serverId': serverId,
        'pacienteId': pacienteId,
        'data': serverObj,
        'syncStatus': 'synced',
        'createdAt': now,
        'updatedAt': now,
      };
      await box.put(id, record);
    } catch (e) {
      debugPrint('LocalDb.saveOrUpdateRemoteCita error: $e');
    }
  }

  static Future<void> saveOrUpdateRemoteCitasBatch(
      List<dynamic> serverList) async {
    try {
      for (final item in serverList) {
        if (item is Map<String, dynamic>) {
          await saveOrUpdateRemoteCita(item);
        } else if (item is Map) {
          await saveOrUpdateRemoteCita(Map<String, dynamic>.from(item));
        }
      }
    } catch (e) {
      debugPrint('LocalDb.saveOrUpdateRemoteCitasBatch error: $e');
    }
  }

  /// Save a cita locally as pending (created offline).
  /// Returns generated localId.
  static Future<String> saveCitaLocal(Map<String, dynamic> cita,
      {String? localId}) async {
    final box = Hive.box(_citasBox);
    final id = localId ?? _newId();
    final now = DateTime.now().toIso8601String();
    final pacienteId = (cita['paciente_id'] ?? cita['pacienteId'])?.toString();
    final record = {
      'localId': id,
      'serverId': cita['id']?.toString(),
      'pacienteId': pacienteId ?? '',
      'data': cita,
      'syncStatus': 'pending',
      'createdAt': cita['createdAt'] ?? now,
      'updatedAt': cita['updatedAt'] ?? now,
      'lastError': null,
    };
    await box.put(id, record);
    return id;
  }

  static Future<List<Map<String, dynamic>>> getCitasByPacienteId(
      String pacienteId) async {
    final box = Hive.box(_citasBox);
    final out = <Map<String, dynamic>>[];
    for (final key in box.keys) {
      final v = box.get(key);
      if (v is Map) {
        final map = Map<String, dynamic>.from(v.cast<String, dynamic>());
        final pid = (map['pacienteId'] ??
                    map['data']?['paciente_id'] ??
                    map['data']?['pacienteId'])
                ?.toString() ??
            '';
        if (pid == pacienteId) out.add(map);
      }
    }
    return out;
  }

  /// Return all local citas (both pending and synced) as raw maps.
  static Future<List<Map<String, dynamic>>> getAllCitas() async {
    final out = <Map<String, dynamic>>[];
    try {
      final box = Hive.box(_citasBox);
      for (final key in box.keys) {
        final v = box.get(key);
        if (v is Map) {
          out.add(Map<String, dynamic>.from(v.cast<String, dynamic>()));
        }
      }
    } catch (e) {
      debugPrint('LocalDb.getAllCitas error: $e');
    }
    return out;
  }

  static Future<List<Map<String, dynamic>>> getPending(String type) async {
    final List<Map<String, dynamic>> out = [];
    try {
      if (type == 'patients' || type == 'all') {
        final box = Hive.box(_patientsBox);
        for (final key in box.keys) {
          final v = box.get(key);
          if (v is Map) {
            final map = Map<String, dynamic>.from(v.cast<String, dynamic>());
            if (map['syncStatus'] == 'pending') out.add(map);
          }
        }
      }

      if (type == 'consultas' || type == 'all') {
        final box = Hive.box(_consultasBox);
        for (final key in box.keys) {
          final v = box.get(key);
          if (v is Map) {
            final map = Map<String, dynamic>.from(v.cast<String, dynamic>());
            if (map['syncStatus'] == 'pending') out.add(map);
          }
        }
      }

      if (type == 'citas' || type == 'all') {
        final box = Hive.box(_citasBox);
        for (final key in box.keys) {
          final v = box.get(key);
          if (v is Map) {
            final map = Map<String, dynamic>.from(v.cast<String, dynamic>());
            if (map['syncStatus'] == 'pending') out.add(map);
          }
        }
      }
    } catch (e) {
      debugPrint('LocalDb.getPending error: $e');
    }
    return out;
  }

  static Future<void> markAsSynced(
      String localId, String serverId, Map<String, dynamic>? serverObj) async {
    final box = Hive.box(_patientsBox);
    final v = box.get(localId);
    if (v is Map) {
      final map = Map<String, dynamic>.from(v.cast<String, dynamic>());
      map['syncStatus'] = 'synced';
      map['serverId'] = serverId;
      map['updatedAt'] = DateTime.now().toIso8601String();
      if (serverObj != null) {
        // Merge server-provided fields into existing local data instead of
        // replacing the whole object. This preserves local properties
        // (e.g. cedula, attachments) when the server returns a minimal
        // response (e.g. only {id: ...}).
        try {
          final existing = Map<String, dynamic>.from(map['data'] ?? {});
          existing.addAll(serverObj);
          map['data'] = existing;
        } catch (_) {
          map['data'] = serverObj;
        }
      }
      await box.put(localId, map);
      try {
        await _recomputePendingCounts();
      } catch (_) {}
    }
  }

  /// Mark a patient local record as 'syncing' to avoid duplicate concurrent uploads.
  static Future<void> setPatientSyncing(String localId) async {
    final box = Hive.box(_patientsBox);
    final v = box.get(localId);
    if (v is Map) {
      final map = Map<String, dynamic>.from(v.cast<String, dynamic>());
      map['syncStatus'] = 'syncing';
      map['updatedAt'] = DateTime.now().toIso8601String();
      await box.put(localId, map);
      try {
        await _recomputePendingCounts();
      } catch (_) {}
    }
  }

  /// Mark a consulta local record as 'syncing' to avoid duplicate concurrent uploads.
  static Future<void> setConsultaSyncing(String localId) async {
    final box = Hive.box(_consultasBox);
    final v = box.get(localId);
    if (v is Map) {
      final map = Map<String, dynamic>.from(v.cast<String, dynamic>());
      map['syncStatus'] = 'syncing';
      map['updatedAt'] = DateTime.now().toIso8601String();
      await box.put(localId, map);
      try {
        await SyncNotifier.instance.refresh();
      } catch (_) {}
    }
  }

  /// Set consulta status back to pending (used when immediate resolution failed).
  static Future<void> setConsultaPending(String localId) async {
    final box = Hive.box(_consultasBox);
    final v = box.get(localId);
    if (v is Map) {
      final map = Map<String, dynamic>.from(v.cast<String, dynamic>());
      map['syncStatus'] = 'pending';
      map['updatedAt'] = DateTime.now().toIso8601String();
      await box.put(localId, map);
      try {
        await SyncNotifier.instance.refresh();
      } catch (_) {}
    }
  }

  static Future<void> updateLocalError(String localId, String message) async {
    final box = Hive.box(_patientsBox);
    final v = box.get(localId);
    if (v is Map) {
      final map = Map<String, dynamic>.from(v.cast<String, dynamic>());
      map['syncStatus'] = 'error';
      map['lastError'] = message;
      map['updatedAt'] = DateTime.now().toIso8601String();
      await box.put(localId, map);
      try {
        await _recomputePendingCounts();
      } catch (_) {}
    }
  }

  /// Mark a consulta local record as error with message
  static Future<void> updateConsultaError(
      String localId, String message) async {
    final box = Hive.box(_consultasBox);
    final v = box.get(localId);
    if (v is Map) {
      final map = Map<String, dynamic>.from(v.cast<String, dynamic>());
      map['syncStatus'] = 'error';
      map['lastError'] = message;
      map['updatedAt'] = DateTime.now().toIso8601String();
      await box.put(localId, map);
      try {
        await SyncNotifier.instance.refresh();
      } catch (_) {}
    }
  }

  /// Mark a cita local record as error with message
  static Future<void> updateCitaError(String localId, String message) async {
    final box = Hive.box(_citasBox);
    final v = box.get(localId);
    if (v is Map) {
      final map = Map<String, dynamic>.from(v.cast<String, dynamic>());
      map['syncStatus'] = 'error';
      map['lastError'] = message;
      map['updatedAt'] = DateTime.now().toIso8601String();
      await box.put(localId, map);
      try {
        await SyncNotifier.instance.refresh();
      } catch (_) {}
    }
  }

  /// Increment an attempts counter for a local record (patients/consultas/citas)
  /// Returns the new attempts count.
  static Future<int> incrementAttempts(String type, String localId) async {
    try {
      if (type == 'patients') {
        final box = Hive.box(_patientsBox);
        final v = box.get(localId);
        if (v is Map) {
          final map = Map<String, dynamic>.from(v.cast<String, dynamic>());
          final cur = (map['attempts'] ?? 0) as int;
          map['attempts'] = cur + 1;
          map['lastAttemptAt'] = DateTime.now().toIso8601String();
          await box.put(localId, map);
          return map['attempts'];
        }
      } else if (type == 'consultas') {
        final box = Hive.box(_consultasBox);
        final v = box.get(localId);
        if (v is Map) {
          final map = Map<String, dynamic>.from(v.cast<String, dynamic>());
          final cur = (map['attempts'] ?? 0) as int;
          map['attempts'] = cur + 1;
          map['lastAttemptAt'] = DateTime.now().toIso8601String();
          await box.put(localId, map);
          return map['attempts'];
        }
      } else if (type == 'citas') {
        final box = Hive.box(_citasBox);
        final v = box.get(localId);
        if (v is Map) {
          final map = Map<String, dynamic>.from(v.cast<String, dynamic>());
          final cur = (map['attempts'] ?? 0) as int;
          map['attempts'] = cur + 1;
          map['lastAttemptAt'] = DateTime.now().toIso8601String();
          await box.put(localId, map);
          return map['attempts'];
        }
      }
    } catch (e) {
      debugPrint('LocalDb.incrementAttempts error: $e');
    }
    return 0;
  }

  /// Update attachments list for a patient local record
  static Future<void> updatePatientAttachments(
      String localId, List<String> urls) async {
    final box = Hive.box(_patientsBox);
    final v = box.get(localId);
    if (v is Map) {
      final map = Map<String, dynamic>.from(v.cast<String, dynamic>());
      final existing = List<String>.from(map['attachments'] ?? []);
      final merged = [...existing];
      for (final u in urls) {
        if (!merged.contains(u)) merged.add(u);
      }
      map['attachments'] = merged;
      // also update data.attachments if present
      final data = (map['data'] as Map<String, dynamic>?);
      if (data != null) {
        data['attachments'] = merged;
        map['data'] = data;
      }
      map['updatedAt'] = DateTime.now().toIso8601String();
      await box.put(localId, map);
    }
  }

  /// Delete a local patient record by localId (only affects local DB).
  /// Returns true if removed.
  static Future<bool> deleteLocalPatient(String localId) async {
    try {
      final box = Hive.box(_patientsBox);
      if (box.containsKey(localId)) {
        await box.delete(localId);
        try {
          await _recomputePendingCounts();
        } catch (_) {}
        return true;
      }
    } catch (e) {
      debugPrint('LocalDb.deleteLocalPatient error: $e');
    }
    return false;
  }

  /// Delete a local consulta record by localId. Returns true if removed.
  static Future<bool> deleteLocalConsulta(String localId) async {
    try {
      final box = Hive.box(_consultasBox);
      if (box.containsKey(localId)) {
        await box.delete(localId);
        try {
          await SyncNotifier.instance.refresh();
        } catch (_) {}
        return true;
      }
      // try to find by serverId
      final keysToRemove = <dynamic>[];
      for (final key in box.keys) {
        final v = box.get(key);
        if (v is Map) {
          final map = Map<String, dynamic>.from(v.cast<String, dynamic>());
          if ((map['serverId']?.toString() ?? '') == localId) {
            keysToRemove.add(key);
          }
        }
      }
      if (keysToRemove.isNotEmpty) {
        for (final k in keysToRemove) {
          await box.delete(k);
        }
        try {
          await SyncNotifier.instance.refresh();
        } catch (_) {}
        return true;
      }
    } catch (e) {
      debugPrint('LocalDb.deleteLocalConsulta error: $e');
    }
    return false;
  }

  /// Mark a consulta local record for deletion. If the record exists and has
  /// a serverId, it will be removed remotely when online. Returns true if
  /// the record was found and marked.
  static Future<bool> markConsultaForDelete(String localId) async {
    try {
      final box = Hive.box(_consultasBox);
      final v = box.get(localId);
      if (v is Map) {
        final map = Map<String, dynamic>.from(v.cast<String, dynamic>());
        map['toDelete'] = true;
        map['syncStatus'] = 'pending_delete';
        map['updatedAt'] = DateTime.now().toIso8601String();
        await box.put(localId, map);
        try {
          await SyncNotifier.instance.refresh();
        } catch (_) {}
        return true;
      }
      // try to find by serverId
      for (final key in box.keys) {
        final v2 = box.get(key);
        if (v2 is Map) {
          final map2 = Map<String, dynamic>.from(v2.cast<String, dynamic>());
          if ((map2['serverId']?.toString() ?? '') == localId) {
            map2['toDelete'] = true;
            map2['syncStatus'] = 'pending_delete';
            map2['updatedAt'] = DateTime.now().toIso8601String();
            await box.put(key, map2);
            return true;
          }
        }
      }
    } catch (e) {
      debugPrint('LocalDb.markConsultaForDelete error: $e');
    }
    return false;
  }

  /// Return consultas marked for deletion.
  static Future<List<Map<String, dynamic>>> getPendingConsultaDeletes() async {
    final out = <Map<String, dynamic>>[];
    try {
      final box = Hive.box(_consultasBox);
      for (final key in box.keys) {
        final v = box.get(key);
        if (v is Map) {
          final map = Map<String, dynamic>.from(v.cast<String, dynamic>());
          if (map['toDelete'] == true) out.add(map);
        }
      }
    } catch (e) {
      debugPrint('LocalDb.getPendingConsultaDeletes error: $e');
    }
    return out;
  }

  /// Mark a local patient record for deletion. The record remains in the DB
  /// and will be processed by `SyncService` when online. Returns true if
  /// the record existed and was marked.
  static Future<bool> markPatientForDelete(String localId) async {
    try {
      final box = Hive.box(_patientsBox);
      final v = box.get(localId);
      if (v is Map) {
        final map = Map<String, dynamic>.from(v.cast<String, dynamic>());
        map['toDelete'] = true;
        map['syncStatus'] = 'pending_delete';
        map['updatedAt'] = DateTime.now().toIso8601String();
        await box.put(localId, map);
        try {
          await _recomputePendingCounts();
        } catch (_) {}
        return true;
      }
    } catch (e) {
      debugPrint('LocalDb.markPatientForDelete error: $e');
    }
    return false;
  }

  /// Return patients marked for deletion.
  static Future<List<Map<String, dynamic>>> getPendingDeletes() async {
    final out = <Map<String, dynamic>>[];
    try {
      final box = Hive.box(_patientsBox);
      for (final key in box.keys) {
        final v = box.get(key);
        if (v is Map) {
          final map = Map<String, dynamic>.from(v.cast<String, dynamic>());
          if (map['toDelete'] == true) out.add(map);
        }
      }
    } catch (e) {
      debugPrint('LocalDb.getPendingDeletes error: $e');
    }
    return out;
  }

  // Mark a consulta local record as synced
  static Future<void> markConsultaAsSynced(
      String localId, String serverId, Map<String, dynamic>? serverObj) async {
    final box = Hive.box(_consultasBox);
    final v = box.get(localId);
    if (v is Map) {
      final map = Map<String, dynamic>.from(v.cast<String, dynamic>());
      // If server object is provided, prefer creating/updating a canonical
      // synced record based on the server response and remove the local
      // pending record to avoid re-insertion or duplicate creates.
      if (serverObj != null) {
        // Merge server object into existing local data to avoid discarding
        // local-only fields (e.g. attached file paths or temporary values).
        try {
          final existing = Map<String, dynamic>.from(map['data'] ?? {});
          existing.addAll(serverObj);
          map['data'] = existing;
        } catch (_) {
          map['data'] = serverObj;
        }
        map['syncStatus'] = 'synced';
        map['serverId'] = serverId;
        map['updatedAt'] = DateTime.now().toIso8601String();
        // Save merged record under the same localId so UI edits/local refs stay valid
        await box.put(localId, map);

        // Remove any other local records that reference the same serverId
        try {
          final keysToRemove = <dynamic>[];
          for (final key in box.keys) {
            if (key == localId) continue;
            final v2 = box.get(key);
            if (v2 is Map) {
              final m2 = Map<String, dynamic>.from(v2.cast<String, dynamic>());
              final s2 = (m2['serverId']?.toString() ?? '');
              if (s2.isNotEmpty && s2 == serverId) {
                keysToRemove.add(key);
                continue;
              }
            }
          }
          for (final k in keysToRemove) {
            await box.delete(k);
          }
        } catch (e) {
          debugPrint('LocalDb.markConsultaAsSynced: cleanup error: $e');
        }
      } else {
        // No server object: just mark existing local record as synced
        map['syncStatus'] = 'synced';
        map['serverId'] = serverId;
        map['updatedAt'] = DateTime.now().toIso8601String();
        await box.put(localId, map);
      }

      // Ensure global pending counter is refreshed so UI badges update
      try {
        await SyncNotifier.instance.refresh();
      } catch (_) {}
    }
  }

  // Mark a cita local record as synced
  static Future<void> markCitaAsSynced(
      String localId, String serverId, Map<String, dynamic>? serverObj) async {
    final box = Hive.box(_citasBox);
    final v = box.get(localId);
    if (v is Map) {
      final map = Map<String, dynamic>.from(v.cast<String, dynamic>());
      map['syncStatus'] = 'synced';
      map['serverId'] = serverId;
      map['updatedAt'] = DateTime.now().toIso8601String();
      if (serverObj != null) map['data'] = serverObj;
      await box.put(localId, map);
      try {
        await SyncNotifier.instance.refresh();
      } catch (_) {}
    }
  }
}
