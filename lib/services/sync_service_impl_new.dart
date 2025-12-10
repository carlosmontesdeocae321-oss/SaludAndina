import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'local_db.dart';
import 'api_client.dart';
import 'api_service_adapter.dart';
import 'sync_notifier.dart';

/// Clean implementation of the SyncService (new file).
class SyncService {
  /// The ApiClient used by SyncService. Tests can override this value.
  static ApiClient api = ApiServiceAdapter();

  // Upload/backoff configuration (public and adjustable).
  static int uploadMaxAttempts = 3;
  static double uploadBaseDelaySeconds = 1.0;
  static double uploadMaxDelaySeconds = 30.0;
  static double uploadJitterFraction = 0.5;

  /// Configure upload retry/backoff parameters.
  /// Any parameter left null will keep the current value.
  static void configureUploadBackoff({
    int? maxAttempts,
    double? baseDelaySeconds,
    double? maxDelaySeconds,
    double? jitterFraction,
  }) {
    if (maxAttempts != null) uploadMaxAttempts = maxAttempts;
    if (baseDelaySeconds != null) uploadBaseDelaySeconds = baseDelaySeconds;
    if (maxDelaySeconds != null) uploadMaxDelaySeconds = maxDelaySeconds;
    if (jitterFraction != null) uploadJitterFraction = jitterFraction;
  }

  SyncService._() {
    _startConnectivityListener();
    // Seed the notifier asynchronously so the drawer badge has an initial value.
    // Fire-and-forget is acceptable here; errors are swallowed inside refresh().
    SyncNotifier.instance.refresh();
  }

  static final _instance = SyncService._();
  static SyncService get instance => _instance;

  final _statusController = StreamController<String>.broadcast();
  bool _syncInProgress = false;
  StreamSubscription<ConnectivityResult>? _connSub;

  Stream<String> get statusStream => _statusController.stream;

  void _startConnectivityListener() {
    try {
      _connSub = Connectivity().onConnectivityChanged.listen((result) async {
        if (result != ConnectivityResult.none) {
          _statusController.add('connected');
          await syncPending();
        } else {
          _statusController.add('disconnected');
        }
      });
    } catch (e) {
      debugPrint('SyncService connectivity listener error: $e');
    }
  }

  Future<void> dispose() async {
    await _connSub?.cancel();
    await _statusController.close();
  }

  Future<void> onLogin() async {
    _statusController.add('starting');
    try {
      await syncPending();
      _statusController.add('idle');
    } catch (e) {
      _statusController.add('error');
      debugPrint('SyncService.onLogin error: $e');
    }
  }

  /// Sync pending local records: patients, consultas and citas.
  Future<void> syncPending() async {
    if (_syncInProgress) {
      debugPrint(
          'SyncService: sync already in progress, skipping concurrent call');
      return;
    }
    _syncInProgress = true;
    _statusController.add('syncing');
    try {
      // --- PATIENTS ---
      final pendingPatients = await LocalDb.getPending('patients');
      for (final rec in pendingPatients) {
        final localId = rec['localId'] as String;
        final data = Map<String, dynamic>.from(rec['data'] ?? {});
        try {
          final existingServerId = rec['serverId']?.toString() ?? '';
          if (existingServerId.isNotEmpty) {
            // If we already have a serverId, assume synced (or update remote if needed).
            await LocalDb.markAsSynced(localId, existingServerId, null);
            // refresh badge
            SyncNotifier.instance.refresh();
            continue;
          }

          // Mark record as syncing to avoid race conditions / duplicate creates
          await LocalDb.setPatientSyncing(localId);

          // Pre-check: try resolving an existing server record by cedula to avoid duplicates
          try {
            final ced = data['cedula']?.toString();
            if (ced != null && ced.isNotEmpty) {
              final lookup = await api.buscarPacientePorCedula(ced);
              if (lookup != null &&
                  lookup['ok'] == true &&
                  lookup['data'] != null) {
                final srv = Map<String, dynamic>.from(lookup['data']);
                final serverId = srv['id']?.toString() ?? '';
                if (serverId.isNotEmpty) {
                  await LocalDb.markAsSynced(localId, serverId, srv);
                  SyncNotifier.instance.refresh();
                  continue;
                }
              }
            }
          } catch (e) {
            debugPrint('SyncService: pre-lookup error: $e');
          }

          // Include a client-side id to help server detect duplicate creates
          try {
            data['client_local_id'] = localId;
          } catch (_) {}
          debugPrint(
              'SyncService: creating patient localId=$localId payload=$data');
          final res = await api.crearPaciente(data);
          debugPrint(
              'SyncService: create patient result localId=$localId -> $res');
          if (res['ok'] == true) {
            String serverId = '';
            Map<String, dynamic>? srvObj;

            if (res['data'] != null && res['data'] is Map<String, dynamic>) {
              srvObj = Map<String, dynamic>.from(res['data']);
              serverId = srvObj['id']?.toString() ?? '';
            } else {
              // fallback: try resolve by cedula
              try {
                final ced = data['cedula']?.toString();
                if (ced != null && ced.isNotEmpty) {
                  final lookup = await api.buscarPacientePorCedula(ced);
                  if (lookup != null &&
                      lookup['ok'] == true &&
                      lookup['data'] != null) {
                    final srv = Map<String, dynamic>.from(lookup['data']);
                    serverId = srv['id']?.toString() ?? '';
                    srvObj = srv;
                  }
                }
              } catch (e) {
                debugPrint('SyncService: error resolving serverId: $e');
              }
            }

            // upload attachments if any (with exponential backoff)
            try {
              final attachments = List<String>.from(rec['attachments'] ?? []);

              if (serverId.isEmpty) {
                // cannot upload without server id
                if (attachments.isEmpty) {
                  await LocalDb.updateLocalError(
                      localId, 'Missing serverId and no attachments');
                } else {
                  await LocalDb.updateLocalError(
                      localId, 'Missing serverId for upload');
                }
                // refresh badge on error
                SyncNotifier.instance.refresh();
                continue;
              }

              if (attachments.isEmpty) {
                // nothing to upload, mark as synced
                await LocalDb.markAsSynced(localId, serverId, srvObj);
                // refresh badge
                SyncNotifier.instance.refresh();
              } else {
                final uid = int.tryParse(serverId);
                if (uid != null) {
                  final up =
                      await _uploadWithBackoff(uid, attachments, localId);
                  if (up['ok'] == true) {
                    if (up['files'] is List) {
                      final files = List<String>.from(up['files']);
                      await LocalDb.updatePatientAttachments(localId, files);
                      if (srvObj != null) {
                        final merged = Map<String, dynamic>.from(srvObj);
                        merged['attachments'] = files;
                        await LocalDb.markAsSynced(localId, serverId, merged);
                      } else {
                        await LocalDb.markAsSynced(localId, serverId, null);
                      }
                      // refresh badge after successful upload and mark
                      SyncNotifier.instance.refresh();
                    } else {
                      if (srvObj != null) {
                        await LocalDb.markAsSynced(localId, serverId, srvObj);
                      } else {
                        await LocalDb.markAsSynced(localId, serverId, null);
                      }
                      SyncNotifier.instance.refresh();
                    }
                  } else {
                    // _uploadWithBackoff already incremented attempts and set error if exhausted
                    debugPrint(
                        'SyncService: upload result not ok: ${up['error'] ?? up}');
                    // ensure badge updated if upload exhausted
                    SyncNotifier.instance.refresh();
                  }
                }
              }
            } catch (e) {
              debugPrint(
                  'SyncService: error uploading patient attachments: $e');
              final attempts =
                  await LocalDb.incrementAttempts('patients', localId);
              if (attempts >= uploadMaxAttempts) {
                await LocalDb.updateLocalError(
                    localId, 'Upload failed after $attempts attempts');
              }
              // refresh badge on error
              SyncNotifier.instance.refresh();
            }
          } else {
            final msg = res['message']?.toString() ?? 'Error creating patient';
            await LocalDb.updateLocalError(localId, msg);
            // refresh badge on error
            SyncNotifier.instance.refresh();
          }
        } catch (e) {
          debugPrint('SyncService: error syncing patient $localId -> $e');
          await LocalDb.updateLocalError(localId, e.toString());
          // refresh badge on error
          SyncNotifier.instance.refresh();
        }
      }

      // --- CONSULTAS ---
      final pendingConsultas = await LocalDb.getPending('consultas');
      for (final rec in pendingConsultas) {
        final localId = rec['localId'] as String;
        final data = Map<String, dynamic>.from(rec['data'] ?? {});
        final archivos = List<String>.from(rec['attachments'] ?? []);
        try {
          // Resolve paciente reference: if the consulta references a local patient
          // (localId UUID) try to find serverId by checking local patient record
          // or by querying the API by cédula. This avoids creating duplicate
          // patients on the server and links the consulta to the existing one.
          String pacienteRef = (rec['pacienteId'] ??
                  data['paciente_id'] ?? data['pacienteId'])
              ?.toString() ?? '';

          String resolvedPacienteServerId = '';
          try {
            if (pacienteRef.contains('-')) {
              // localId reference -> check local DB for serverId
              final localPatient = await LocalDb.getPatientById(pacienteRef);
              if (localPatient != null) {
                final srv = localPatient['serverId']?.toString() ?? '';
                if (srv.isNotEmpty) {
                  resolvedPacienteServerId = srv;
                } else {
                  // no serverId yet -> try to lookup by cedula on server
                  final localData = Map<String, dynamic>.from(localPatient['data'] ?? {});
                  final ced = (localData['cedula'] ?? localData['dni'] ?? localData['ci'])?.toString() ?? '';
                  if (ced.isNotEmpty) {
                    try {
                      final lookup = await api.buscarPacientePorCedula(ced);
                      if (lookup != null && lookup['ok'] == true && lookup['data'] != null) {
                        final srvObj = Map<String, dynamic>.from(lookup['data']);
                        final serverId = srvObj['id']?.toString() ?? '';
                        if (serverId.isNotEmpty) {
                          // update local patient as synced to avoid duplicates
                          await LocalDb.markAsSynced(pacienteRef, serverId, srvObj);
                          resolvedPacienteServerId = serverId;
                        }
                      }
                    } catch (e) {
                      debugPrint('SyncService: consulta pre-lookup error: $e');
                    }
                  }
                }
              }
            } else if (pacienteRef.isEmpty) {
              // No patient id provided in consulta, but maybe cedula present in data
              final ced = (data['cedula'] ?? data['paciente_cedula'])?.toString() ?? '';
              if (ced.isNotEmpty) {
                try {
                  final lookup = await api.buscarPacientePorCedula(ced);
                  if (lookup != null && lookup['ok'] == true && lookup['data'] != null) {
                    final srvObj = Map<String, dynamic>.from(lookup['data']);
                    final serverId = srvObj['id']?.toString() ?? '';
                    if (serverId.isNotEmpty) {
                      resolvedPacienteServerId = serverId;
                    }
                  }
                } catch (e) {
                  debugPrint('SyncService: consulta cedula lookup error: $e');
                }
              }
            }
          } catch (e) {
            debugPrint('SyncService: error resolving paciente for consulta $localId -> $e');
          }

          // Prepare fields as strings for crearHistorial. If we resolved a server
          // paciente id, ensure we set it in the payload so the consulta links
          // to the correct server patient.
          final fields = <String, String>{};
          data.forEach((k, v) {
            if (v != null) fields[k.toString()] = v.toString();
          });
          if (resolvedPacienteServerId.isNotEmpty) {
            fields['paciente_id'] = resolvedPacienteServerId;
          }
          debugPrint(
              'SyncService: creating consulta localId=$localId paciente=${data['paciente_id']} attachments=${archivos.length}');
          final ok = await api.crearHistorial(fields, archivos);
          debugPrint(
              'SyncService: create consulta result localId=$localId -> $ok');
          if (ok == true) {
            await LocalDb.markConsultaAsSynced(localId, '', null);
            // refresh badge after successful sync
            SyncNotifier.instance.refresh();
          } else {
            await LocalDb.updateConsultaError(
                localId, 'Error creating historial');
            // refresh badge on error
            SyncNotifier.instance.refresh();
          }
        } catch (e) {
          debugPrint('SyncService: error syncing consulta $localId -> $e');
          await LocalDb.updateConsultaError(localId, e.toString());
          // refresh badge on error
          SyncNotifier.instance.refresh();
        }
      }

      // --- CITAS ---
      final pendingCitas = await LocalDb.getPending('citas');
      for (final rec in pendingCitas) {
        final localId = rec['localId'] as String;
        final data = Map<String, dynamic>.from(rec['data'] ?? {});
        try {
          final ok = await api.agendarCita(data);
          if (ok == true) {
            await LocalDb.markCitaAsSynced(localId, '', null);
            // refresh badge after successful sync
            SyncNotifier.instance.refresh();
          } else {
            await LocalDb.updateCitaError(localId, 'Error agendando cita');
            // refresh badge on error
            SyncNotifier.instance.refresh();
          }
        } catch (e) {
          debugPrint('SyncService: error syncing cita $localId -> $e');
          await LocalDb.updateCitaError(localId, e.toString());
          // refresh badge on error
          SyncNotifier.instance.refresh();
        }
      }
    } catch (e) {
      debugPrint('SyncService.syncPending error: $e');
    } finally {
      _statusController.add('done');
      // ensure badge reflects final state
      SyncNotifier.instance.refresh();
    }
  }

  /// Attempt uploads with exponential backoff and jitter.
  /// Returns the same shape as `api.subirDocumentosDoctor` (map with 'ok' and optional 'files').
  Future<Map<String, dynamic>> _uploadWithBackoff(
      int uid, List<String> attachments, String localId) async {
    final rand = Random();
    for (var attempt = 1; attempt <= uploadMaxAttempts; attempt++) {
      try {
        final res = await api.subirDocumentosDoctor(uid, attachments);
        if (res['ok'] == true) return res;
        // mark attempt
        final attempts = await LocalDb.incrementAttempts('patients', localId);
        debugPrint(
            'SyncService: upload attempt $attempt failed (attempts=$attempts)');
        if (attempts >= uploadMaxAttempts) {
          await LocalDb.updateLocalError(
              localId, 'Upload failed after $attempts attempts');
          // refresh badge on error
          SyncNotifier.instance.refresh();
          return res;
        }
      } catch (e) {
        final attempts = await LocalDb.incrementAttempts('patients', localId);
        debugPrint('SyncService: upload exception on attempt $attempts: $e');
        if (attempts >= uploadMaxAttempts) {
          await LocalDb.updateLocalError(
              localId, 'Upload failed after $attempts attempts');
          // refresh badge on error
          SyncNotifier.instance.refresh();
          return {'ok': false, 'error': e.toString()};
        }
      }

      // Delay with exponential backoff and jitter before next attempt
      final exp = uploadBaseDelaySeconds * pow(2, attempt - 1);
      final withoutCap = exp.clamp(0, uploadMaxDelaySeconds) as double;
      final jitter =
          (rand.nextDouble() * 2 - 1) * uploadJitterFraction; // -j..+j
      var delaySec = withoutCap * (1 + jitter);
      if (delaySec < 0) delaySec = 0.0;
      final ms = (delaySec * 1000).toInt();
      await Future.delayed(Duration(milliseconds: ms));
    }

    return {'ok': false, 'error': 'exhausted attempts'};
  }
}
