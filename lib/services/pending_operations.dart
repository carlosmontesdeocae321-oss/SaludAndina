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
