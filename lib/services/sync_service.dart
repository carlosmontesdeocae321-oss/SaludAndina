import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'pending_operations.dart';

class SyncService {
  final Dio dio;
  final AppDatabase db;
  StreamSubscription<ConnectivityResult>? _sub;
  bool _running = false;

  SyncService({required this.dio, required this.db});

  void start() {
    if (_running) return;
    _running = true;
    _sub = Connectivity().onConnectivityChanged.listen((status) async {
      if (status != ConnectivityResult.none) {
        await runSync();
      }
    });
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _running = false;
  }

  Future<void> runSync() async {
    final ops = await db.listAllOps();
    for (final op in ops) {
      try {
        await db.updateStatus(op.id, 'processing');
        final headers = {'Idempotency-Key': op.idempotencyKey};
        Response resp;
        if (op.resourceType == 'paciente' && op.method == 'POST') {
          resp = await dio.post('/api/pacientes',
              data: op.payload, options: Options(headers: headers));
        } else if (op.resourceType == 'cita' && op.method == 'POST') {
          resp = await dio.post('/api/citas',
              data: op.payload, options: Options(headers: headers));
        } else if (op.resourceType == 'historial' && op.method == 'POST') {
          resp = await dio.post('/api/historial',
              data: op.payload, options: Options(headers: headers));
        } else {
          // unsupported operation for now
          await db.updateStatus(op.id, 'failed');
          continue;
        }

        if (resp.statusCode == 200 || resp.statusCode == 201) {
          await db.removeOp(op.id);
        } else {
          await db.updateStatus(op.id, 'failed');
        }
      } catch (e) {
        await db.updateStatus(op.id, 'failed');
      }
    }
  }
}
