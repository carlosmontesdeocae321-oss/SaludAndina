import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:clinica_app/services/local_db.dart';
import 'package:clinica_app/services/sync_service_impl_new.dart';
import 'package:clinica_app/services/api_client.dart';

class MockApiClientPatient implements ApiClient {
  final int mode; // 1: echo client_local_id; 2: return match; 3: no match
  MockApiClientPatient(this.mode);

  @override
  Future<bool> agendarCita(Map<String, dynamic> data) async => true;

  @override
  Future<Map<String, dynamic>> crearPaciente(Map<String, dynamic> data) async {
    if (mode == 1) {
      // return created object echoing client_local_id
      return {
        'ok': true,
        'data': {'id': '9000', 'client_local_id': data['client_local_id'] ?? ''}
      };
    }
    if (mode == 2) {
      // return created object without client_local_id but with id
      return {
        'ok': true,
        'data': {'id': '9001'}
      };
    }
    // mode 3: simulate server not returning created object
    return {'ok': false};
  }

  @override
  Future<bool> eliminarHistorial(String id) async => true;

  @override
  Future<bool> eliminarPaciente(String id) async => true;

  @override
  Future<Map<String, dynamic>?> buscarPacientePorCedula(String cedula) async {
    // In mode 3 we simulate no match
    return null;
  }

  @override
  Future<Map<String, dynamic>> subirDocumentosDoctor(
          int uid, List<String> attachments) async =>
      {'ok': true, 'files': []};

  @override
  Future<bool> crearHistorial(
          Map<String, String> fields, List<String> archivos) async =>
      true;

  @override
  Future<List<Map<String, dynamic>>> obtenerConsultasPacienteRaw(
          String pacienteId) async =>
      [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmpDir;

  setUpAll(() async {
    tmpDir = await Directory.systemTemp.createTemp('clinica_test_');
    Hive.init(tmpDir.path);
    await Hive.openBox('patients_box');
    await Hive.openBox('consultas_box');
    await Hive.openBox('local_meta');
    await Hive.openBox('citas_box');
  });

  tearDownAll(() async {
    try {
      await Hive.box('patients_box').clear();
      await Hive.box('consultas_box').clear();
      await Hive.box('local_meta').clear();
      await Hive.box('citas_box').clear();
      await Hive.box('patients_box').close();
      await Hive.box('consultas_box').close();
      await Hive.box('local_meta').close();
      await Hive.box('citas_box').close();
      await tmpDir.delete(recursive: true);
    } catch (_) {}
  });

  test('Patient duplication when server returns no match', () async {
    await Hive.box('patients_box').clear();

    final patient = {
      'cedula': 'TEST-123',
      'nombres': 'Dup',
      'apellidos': 'Test',
    };
    final localId = await LocalDb.savePatient(patient);
    expect(localId, isNotNull);

    final mock = MockApiClientPatient(3);
    SyncService.api = mock;

    await SyncService.instance.syncPending();

    // Simulate server later returning the patient in a list fetch
    final serverObj = {
      'id': '5000',
      'cedula': 'TEST-123',
      'nombres': 'Dup',
      'apellidos': 'Test'
    };
    await LocalDb.saveOrUpdateRemotePatient(serverObj);

    final all = Hive.box('patients_box').values.toList();
    expect(all.length, greaterThanOrEqualTo(1));
    if (all.length > 1) {
      final statuses =
          all.map((e) => (e as Map)['syncStatus'] as String).toSet();
      expect(statuses.contains('synced'), isTrue);
      expect(
          statuses.contains('pending') || statuses.contains('syncing'), isTrue);
    }
  });
}
