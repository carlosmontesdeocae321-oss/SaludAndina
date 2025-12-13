import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class PendingOperation {
  String id;
  String resourceType; // e.g. 'paciente', 'historial', 'cita'
  String method; // POST/PUT/DELETE
  Map<String, dynamic> payload;
  String idempotencyKey;
  String status; // pending, processing, done, failed
  int createdAt;

  PendingOperation({
    required this.id,
    required this.resourceType,
    required this.method,
    required this.payload,
    required this.idempotencyKey,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'resourceType': resourceType,
        'method': method,
        'payload': payload,
        'idempotencyKey': idempotencyKey,
        'status': status,
        'createdAt': createdAt,
      };

  factory PendingOperation.fromJson(Map<String, dynamic> j) => PendingOperation(
        id: j['id'] as String,
        resourceType: j['resourceType'] as String,
        method: j['method'] as String,
        payload: Map<String, dynamic>.from(j['payload'] ?? {}),
        idempotencyKey: j['idempotencyKey'] as String,
        status: j['status'] as String? ?? 'pending',
        createdAt: j['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      );
}

class PendingOperationsStore {
  static const _kKey = 'pending_operations_v1';

  final SharedPreferences _prefs;

  PendingOperationsStore._(this._prefs);

  static Future<PendingOperationsStore> getInstance() async {
    final p = await SharedPreferences.getInstance();
    return PendingOperationsStore._(p);
  }

  List<PendingOperation> _readList() {
    final raw = _prefs.getStringList(_kKey) ?? [];
    return raw.map((s) => PendingOperation.fromJson(json.decode(s) as Map<String, dynamic>)).toList();
  }

  Future<void> _writeList(List<PendingOperation> items) async {
    final raw = items.map((i) => json.encode(i.toJson())).toList();
    await _prefs.setStringList(_kKey, raw);
  }

  Future<List<PendingOperation>> listAll() async => _readList();

  Future<PendingOperation> add(String resourceType, String method, Map<String, dynamic> payload) async {
    final u = Uuid();
    final id = u.v4();
    final op = PendingOperation(
      id: id,
      resourceType: resourceType,
      method: method,
      payload: payload,
      idempotencyKey: u.v4(),
      status: 'pending',
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    final list = _readList();
    list.add(op);
    await _writeList(list);
    return op;
  }

  Future<void> remove(String id) async {
    final list = _readList();
    list.removeWhere((e) => e.id == id);
    await _writeList(list);
  }

  Future<void> updateStatus(String id, String status) async {
    final list = _readList();
    final idx = list.indexWhere((e) => e.id == id);
    if (idx != -1) {
      final item = list[idx];
      list[idx] = PendingOperation(
        id: item.id,
        resourceType: item.resourceType,
        method: item.method,
        payload: item.payload,
        idempotencyKey: item.idempotencyKey,
        status: status,
        createdAt: item.createdAt,
      );
      await _writeList(list);
    }
  }
}
