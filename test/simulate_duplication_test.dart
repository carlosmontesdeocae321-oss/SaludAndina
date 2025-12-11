import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:clinica_app/services/local_db.dart';
import 'package:clinica_app/services/sync_service_impl_new.dart';
import 'package:clinica_app/services/api_client.dart';
import 'package:clinica_app/services/api_services.dart';

class MockApiClient implements ApiClient {
  final int
      mode; // 1: echo client_local_id; 2: return list with match; 3: no match
  Map<String, dynamic>? lastCreated;
  MockApiClient(this.mode);

  @override
  Future<bool> agendarCita(Map<String, dynamic> data) async => true;

  @override
  Future<bool> crearHistorial(
      Map<String, String> fields, List<String> archivos) async {
    // Simulate server create
    final now = DateTime.now();
    final created = <String, dynamic>{
      'id': (1000 + now.millisecondsSinceEpoch % 1000).toString(),
      'fecha': fields['fecha'] ?? now.toIso8601String().split('T')[0],
      'motivo': fields['motivo'] ?? fields['motivo_consulta'] ?? '',
    };
    if (mode == 1) {
      // echo client_local_id
      created['client_local_id'] = fields['client_local_id'] ?? '';
    }
    lastCreated = created;
    ApiService.lastCreatedHistorial = Map<String, dynamic>.from(created);
    return true;
  }

  @override
  Future<Map<String, dynamic>> crearPaciente(Map<String, dynamic> data) async =>
      {'ok': false};

  @override
  Future<bool> eliminarHistorial(String id) async => true;

  @override
  Future<bool> eliminarPaciente(String id) async => true;

  @override
  Future<Map<String, dynamic>?> buscarPacientePorCedula(String cedula) async =>
      null;

  @override
  Future<Map<String, dynamic>> subirDocumentosDoctor(
          int uid, List<String> attachments) async =>
      {'ok': true, 'files': []};

  @override
  Future<List<Map<String, dynamic>>> obtenerConsultasPacienteRaw(
      String pacienteId) async {
    if (mode == 2 && lastCreated != null) {
      // Return a list containing a matching item (but maybe without client_local_id)
      return [Map<String, dynamic>.from(lastCreated!)];
    }
    // mode 1: ApiService.lastCreatedHistorial already set and SyncService prefers it.
    // mode 3: return empty list -> will cause potential duplication
    return [];
  }
}

void main() {
  // Ensure Flutter bindings for platform channels (connectivity, etc.)
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmpDir;
  setUpAll(() async {
    tmpDir = await Directory.systemTemp.createTemp('clinica_test_');
    Hive.init(tmpDir.path);
    await Hive.openBox('consultas_box');
    await Hive.openBox('patients_box');
    await Hive.openBox('local_meta');
    await Hive.openBox('citas_box');
  });

  tearDownAll(() async {
    try {
      await Hive.box('consultas_box').clear();
      await Hive.box('patients_box').clear();
      await Hive.box('local_meta').clear();
      await Hive.box('citas_box').clear();
      await Hive.box('consultas_box').close();
      await Hive.box('patients_box').close();
      await Hive.box('local_meta').close();
      await Hive.box('citas_box').close();
      await tmpDir.delete(recursive: true);
    } catch (_) {}
  });

  test('Sync with server echoing client_local_id does not duplicate', () async {
    await Hive.box('consultas_box').clear();
    final consulta = {
      'paciente_id': 'P-TEST-1',
      'motivo_consulta': 'Dolor test A',
      'diagnostico': 'Dx A',
      'notas_html': '<p>A</p>',
      'fecha': DateTime.now().toIso8601String().split('T')[0],
    };
    final localId = await LocalDb.saveConsultaLocal(consulta);
    expect(localId, isNotNull);

    final mock = MockApiClient(1);
    SyncService.api = mock;
    // ensure lastCreated cleared
    ApiService.lastCreatedHistorial = null;

    await SyncService.instance.syncPending();

    // After sync, there should be a single local record and it should be synced
    final all = Hive.box('consultas_box').values.toList();
    expect(all.length, 1);
    final rec = all.first as Map;
    expect(rec['localId'], localId);
    expect(rec['syncStatus'], 'synced');
  });

  test('Sync with server list-match by fecha+motivo does not duplicate',
      () async {
    await Hive.box('consultas_box').clear();
    final consulta = {
      'paciente_id': 'P-TEST-2',
      'motivo_consulta': 'Dolor test B',
      'diagnostico': 'Dx B',
      'notas_html': '<p>B</p>',
      'fecha': DateTime.now().toIso8601String().split('T')[0],
    };
    final localId = await LocalDb.saveConsultaLocal(consulta);
    expect(localId, isNotNull);

    final mock = MockApiClient(2);
    SyncService.api = mock;
    ApiService.lastCreatedHistorial = null;

    await SyncService.instance.syncPending();

    final all = Hive.box('consultas_box').values.toList();
    // Should still be one record marked synced
    expect(all.length, 1);
    final rec = all.first as Map;
    expect(rec['localId'], localId);
    expect(rec['syncStatus'], 'synced');
  });

  test('Sync when server returns no matching item may duplicate', () async {
    await Hive.box('consultas_box').clear();
    final consulta = {
      'paciente_id': 'P-TEST-3',
      'motivo_consulta': 'Dolor test C',
      'diagnostico': 'Dx C',
      'notas_html': '<p>C</p>',
      'fecha': DateTime.now().toIso8601String().split('T')[0],
    };
    final localId = await LocalDb.saveConsultaLocal(consulta);
    expect(localId, isNotNull);

    final mock = MockApiClient(3);
    SyncService.api = mock;
    ApiService.lastCreatedHistorial = null;

    await SyncService.instance.syncPending();

    final all = Hive.box('consultas_box').values.toList();
    // In this simulated mode we expect duplication (pending + created local copy)
    expect(all.length, greaterThanOrEqualTo(1));
    // If duplication happened there will be more than 1 record
    if (all.length > 1) {
      // ensure at least one is synced and one is pending
      final statuses =
          all.map((e) => (e as Map)['syncStatus'] as String).toSet();
      expect(statuses.contains('synced'), isTrue);
      expect(
          statuses.contains('pending') || statuses.contains('syncing'), isTrue);
    }
  });
}
