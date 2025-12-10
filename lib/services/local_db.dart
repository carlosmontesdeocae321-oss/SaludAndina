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
      }

      // 2) Try to find by serverId (existing synced record)
      for (final key in box.keys) {
        final v = box.get(key);
        if (v is Map) {
          final map = Map<String, dynamic>.from(v.cast<String, dynamic>());
          if ((map['serverId']?.toString() ?? '') == serverId && serverId.isNotEmpty) {
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
        final ced = (serverObj['cedula'] ?? serverObj['dni'] ?? serverObj['ci'])?.toString() ?? '';
        if (ced.isNotEmpty) {
          for (final key in box.keys) {
            final v = box.get(key);
            if (v is Map) {
              final map = Map<String, dynamic>.from(v.cast<String, dynamic>());
              final data = Map<String, dynamic>.from(map['data'] ?? {});
              final localCed = (data['cedula'] ?? data['dni'] ?? data['ci'])?.toString() ?? '';
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
      // ignore
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
    final pacienteId =
        (consulta['paciente_id'] ?? consulta['pacienteId'])?.toString();
    final record = {
      'localId': id,
      'serverId': consulta['id']?.toString(),
      'pacienteId': pacienteId ?? '',
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

  static Future<List<Map<String, dynamic>>> getConsultasByPacienteId(
      String pacienteId) async {
    final box = Hive.box(_consultasBox);
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
      if (serverObj != null) map['data'] = serverObj;
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

  // Mark a consulta local record as synced
  static Future<void> markConsultaAsSynced(
      String localId, String serverId, Map<String, dynamic>? serverObj) async {
    final box = Hive.box(_consultasBox);
    final v = box.get(localId);
    if (v is Map) {
      final map = Map<String, dynamic>.from(v.cast<String, dynamic>());
      map['syncStatus'] = 'synced';
      map['serverId'] = serverId;
      map['updatedAt'] = DateTime.now().toIso8601String();
      if (serverObj != null) map['data'] = serverObj;
      await box.put(localId, map);
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
    }
  }
}
