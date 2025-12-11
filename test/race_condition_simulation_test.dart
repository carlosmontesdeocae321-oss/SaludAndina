import 'dart:io';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:clinica_app/services/local_db.dart';
import 'package:clinica_app/services/sync_service_impl_new.dart';
import 'package:clinica_app/services/api_client.dart';

class SlowCreateApiClient implements ApiClient {
  final Duration delay;
  final List<Map<String, dynamic>> created = [];
  SlowCreateApiClient(this.delay);

  @override
  Future<Map<String, dynamic>> crearPaciente(Map<String, dynamic> data) async {
    // Simulate slow server create which returns success but with no body
    await Future.delayed(delay);
    // Simulate server created resource (server has the record but does not return it)
    final generatedId = DateTime.now().millisecondsSinceEpoch.toString();
    created.add({'id': generatedId, ...data});
    // Return success but no data (this triggers fallback behaviors)
    return {'ok': true};
  }

  @override
  Future<Map<String, dynamic>?> buscarPacientePorCedula(String cedula) async {
    // Mimic eventual consistency: after delay, server will have records
    return null;
  }

  // The rest are no-ops or simple returns for this test
  @override
  Future<bool> agendarCita(Map<String, dynamic> data) async => true;
  @override
  Future<bool> crearHistorial(
          Map<String, String> fields, List<String> archivos) async =>
      true;
  @override
  Future<bool> eliminarHistorial(String id) async => true;
  @override
  Future<bool> eliminarPaciente(String id) async => true;
  @override
  Future<Map<String, dynamic>> subirDocumentosDoctor(
          int uid, List<String> attachments) async =>
      {'ok': true, 'files': []};
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

  test('Race: syncPending (slow create) vs remote list merge', () async {
    // Create two local patients (pending)
    await Hive.box('patients_box').clear();
    final p1 = {'cedula': 'RACE-001', 'nombres': 'Ana', 'apellidos': 'One'};
    final p2 = {'cedula': 'RACE-002', 'nombres': 'Luis', 'apellidos': 'Two'};
    await LocalDb.savePatient(p1);
    await LocalDb.savePatient(p2);

    // Prepare slow API client (simulate slow server create)
    final slow = SlowCreateApiClient(const Duration(milliseconds: 800));
    SyncService.api = slow;

    // Start syncPending (will call crearPaciente with delay)
    final syncFuture = SyncService.instance.syncPending();

    // While sync is in progress, simulate remote list fetch that contains
    // server-side representations of the same patients (as if server had them)
    // This will call LocalDb.saveOrUpdateRemotePatientsBatch concurrently.
    final serverList = [
      {
        'id': 'S-100',
        'cedula': 'RACE-001',
        'nombres': 'Ana',
        'apellidos': 'One'
      },
      {
        'id': 'S-101',
        'cedula': 'RACE-002',
        'nombres': 'Luis',
        'apellidos': 'Two'
      },
    ];

    // Give a small window to ensure sync started
    await Future.delayed(const Duration(milliseconds: 100));

    // Perform remote merge concurrently
    await LocalDb.saveOrUpdateRemotePatientsBatch(serverList);

    // Wait for sync to finish
    await syncFuture;

    // Check resulting patients in local DB
    final all = Hive.box('patients_box').values.toList();
    // Expectation: No duplicate patients for same cedula (should be 2 records)
    expect(all.length, 2);
    final cedSet =
        all.map((e) => (e as Map)['data']?['cedula']?.toString() ?? '').toSet();
    expect(cedSet.contains('RACE-001'), isTrue);
    expect(cedSet.contains('RACE-002'), isTrue);
  });
}
