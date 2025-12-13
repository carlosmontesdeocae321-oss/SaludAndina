import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'pending_operations.dart';

class PatientRepository {
  final Dio _dio;
  final AppDatabase _db;

  PatientRepository(this._dio, this._db);

  /// Create a patient. If offline, this enqueues the operation and returns a
  /// minimal local record. When synced, the server id will be available.
  Future<Map<String, dynamic>> createPatient(Map<String, dynamic> data) async {
    try {
      // Try network first
      final resp = await _dio.post('/api/pacientes', data: data);
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        return Map<String, dynamic>.from(resp.data);
      }
    } catch (e) {
      // network failed, fallthrough to enqueue
    }

    // enqueue offline using Drift
    final u = Uuid();
    final id = u.v4();
    final idemp = u.v4();
    final companion = PendingOperationsCompanion.insert(
      id: id,
      resourceType: 'paciente',
      method: 'POST',
      payload: json.encode(data),
      idempotencyKey: idemp,
      status: 'pending',
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _db.addOp(companion);
    final op = (await _db.listAllOps()).firstWhere((e) => e.id == id);
    // create a lightweight local representation
    final local = Map<String, dynamic>.from(data);
    local['local_id'] = op.id;
    local['__pending'] = true;
    // store in SharedPreferences simple cache for UI listing
    final prefs = await SharedPreferences.getInstance();
    final key = 'local_pacientes_v1';
    final list = prefs.getStringList(key) ?? [];
    list.add(json.encode(local));
    await prefs.setStringList(key, list);
    return local;
  }

  Future<List<Map<String, dynamic>>> listLocalPatients() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'local_pacientes_v1';
    final list = prefs.getStringList(key) ?? [];
    return list
        .map((s) =>
            Map<String, dynamic>.from(json.decode(s) as Map<String, dynamic>))
        .toList();
  }
}
