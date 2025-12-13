import 'dart:convert';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'package:uuid/uuid.dart';

class PendingOperation {
  final String id;
  final String resourceType;
  final String method;
  final Map<String, dynamic> payload;
  final String idempotencyKey;
  final String status;
  final int createdAt;

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
  static const _dbName = 'clinica_pending_ops.db';
  static const _storeName = 'pending_operations';

  final Database _db;
  final StoreRef<String, Map<String, dynamic>> _store;

  PendingOperationsStore._(this._db, this._store);

  static Future<PendingOperationsStore> getInstance() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, _dbName);
    final db = await databaseFactoryIo.openDatabase(dbPath);
    final store = stringMapStoreFactory.store(_storeName);
    return PendingOperationsStore._(db, store);
  }

  Future<List<PendingOperation>> listAll() async {
    final records = await _store.find(_db);
    return records
        .map((r) => PendingOperation.fromJson(r.value))
        .toList(growable: false);
  }

  Future<PendingOperation> add(String resourceType, String method, Map<String, dynamic> payload) async {
    final u = Uuid();
    final id = u.v4();
    final idemp = u.v4();
    final op = PendingOperation(
      id: id,
      resourceType: resourceType,
      method: method,
      payload: payload,
      idempotencyKey: idemp,
      status: 'pending',
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _store.record(id).put(_db, op.toJson());
    return op;
  }

  Future<void> remove(String id) async {
    await _store.record(id).delete(_db);
  }

  Future<void> updateStatus(String id, String status) async {
    final rec = await _store.record(id).get(_db) as Map<String, dynamic>?;
    if (rec == null) return;
    rec['status'] = status;
    await _store.record(id).put(_db, rec);
  }
}
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
        import 'dart:convert';

        import 'package:drift/drift.dart';
        import 'package:drift/native.dart';
        import 'package:drift/drift_web.dart';
        import 'package:path_provider/path_provider.dart';
        import 'package:path/path.dart' as p;
        import 'dart:io';

        part 'pending_operations.g.dart';

        class PendingOperations extends Table {
          TextColumn get id => text()();
          TextColumn get resourceType => text()();
          TextColumn get method => text()();
          TextColumn get payload => text()();
          TextColumn get idempotencyKey => text()();
          TextColumn get status => text().withDefault(const Constant('pending'))();
          IntColumn get createdAt => integer()();

          @override
          Set<Column> get primaryKey => {id};
        }

        @DriftDatabase(tables: [PendingOperations])
        class AppDatabase extends _$AppDatabase {
          AppDatabase() : super(_openConnection());

          @override
          int get schemaVersion => 1;

          Future<List<PendingOperationRecord>> listAllOps() async {
            final rows = await select(pendingOperations).get();
            return rows.map((r) => PendingOperationRecord.fromData(r)).toList();
          }

          Future<void> addOp(PendingOperationsCompanion entry) async {
            await into(pendingOperations).insert(entry);
          }

          Future<void> removeOp(String id) async {
            await (delete(pendingOperations)..where((t) => t.id.equals(id))).go();
          }

          Future<void> updateStatus(String id, String status) async {
            await (update(pendingOperations)..where((t) => t.id.equals(id))).write(PendingOperationsCompanion(status: Value(status)));
          }
        }

        class PendingOperationRecord {
          final String id;
          final String resourceType;
          final String method;
          final Map<String, dynamic> payload;
          final String idempotencyKey;
          final String status;
          final int createdAt;

          PendingOperationRecord({
            required this.id,
            required this.resourceType,
            required this.method,
            required this.payload,
            required this.idempotencyKey,
            required this.status,
            required this.createdAt,
          });

          factory PendingOperationRecord.fromData(PendingOperationsData d) => PendingOperationRecord(
                id: d.id,
                resourceType: d.resourceType,
                method: d.method,
                payload: json.decode(d.payload) as Map<String, dynamic>,
                idempotencyKey: d.idempotencyKey,
                status: d.status,
                createdAt: d.createdAt,
              );
        }

        LazyDatabase _openConnection() {
          return LazyDatabase(() async {
            if (kIsWeb) {
              return WebDatabase('clinica_app_db');
            }
            final dbFolder = await getApplicationDocumentsDirectory();
            final file = File(p.join(dbFolder.path, 'clinica_app.sqlite'));
            return NativeDatabase(file);
          });
        }
