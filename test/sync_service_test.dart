import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:clinica_app/services/local_db.dart';
import 'package:clinica_app/services/sync_service.dart';
import 'package:clinica_app/services/api_client.dart';

class MockApiClient implements ApiClient {
  @override
  Future<bool> agendarCita(Map<String, dynamic> data) async {
    return true;
  }

  @override
  Future<bool> crearHistorial(
      Map<String, String> fields, List<String> archivos) async {
    return true;
  }

  @override
  Future<Map<String, dynamic>> crearPaciente(Map<String, dynamic> data) async {
    // Simulate server returning created object with id
    return {
      'ok': true,
      'data': {'id': 12345, ...data}
    };
  }

  @override
  Future<Map<String, dynamic>?> buscarPacientePorCedula(String cedula) async {
    return {
      'ok': true,
      'data': {'id': 12345, 'cedula': cedula}
    };
  }

  @override
  Future<Map<String, dynamic>> subirDocumentosDoctor(
      int uid, List<String> attachments) async {
    return {'ok': true};
  }

  @override
  Future<bool> eliminarPaciente(String id) async => true;

  @override
  Future<List<Map<String, dynamic>>> obtenerConsultasPacienteRaw(
      String pacienteId) async {
    return [];
  }

  @override
  Future<bool> eliminarHistorial(String id) async => true;
}

// Mock that simulates crearPaciente failing with a message
class MockFailCreate implements ApiClient {
  @override
  Future<bool> agendarCita(Map<String, dynamic> data) async => true;

  @override
  Future<bool> crearHistorial(
          Map<String, String> fields, List<String> archivos) async =>
      true;

  @override
  Future<Map<String, dynamic>> crearPaciente(Map<String, dynamic> data) async {
    return {'ok': false, 'message': 'duplicate cedula'};
  }

  @override
  Future<Map<String, dynamic>?> buscarPacientePorCedula(String cedula) async =>
      null;

  @override
  Future<Map<String, dynamic>> subirDocumentosDoctor(
          int uid, List<String> attachments) async =>
      {'ok': true};
  @override
  Future<bool> eliminarPaciente(String id) async => true;

  @override
  Future<List<Map<String, dynamic>>> obtenerConsultasPacienteRaw(
      String pacienteId) async {
    return [];
  }

  @override
  Future<bool> eliminarHistorial(String id) async => true;
}

// Mock that simulates crearPaciente success but attachment upload fails
class MockFailUpload implements ApiClient {
  @override
  Future<bool> agendarCita(Map<String, dynamic> data) async => true;

  @override
  Future<bool> crearHistorial(
          Map<String, String> fields, List<String> archivos) async =>
      true;

  @override
  Future<Map<String, dynamic>> crearPaciente(Map<String, dynamic> data) async {
    return {
      'ok': true,
      'data': {'id': 9999, ...data}
    };
  }

  @override
  Future<Map<String, dynamic>?> buscarPacientePorCedula(String cedula) async =>
      null;

  @override
  Future<Map<String, dynamic>> subirDocumentosDoctor(
      int uid, List<String> attachments) async {
    return {'ok': false, 'error': 'upload failed'};
  }

  @override
  Future<bool> eliminarPaciente(String id) async => true;

  @override
  Future<List<Map<String, dynamic>>> obtenerConsultasPacienteRaw(
      String pacienteId) async {
    return [];
  }

  @override
  Future<bool> eliminarHistorial(String id) async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final tmp = await Directory.systemTemp.createTemp('hive_sync_test');
    Hive.init(tmp.path);
    await Hive.openBox('patients_box');
    await Hive.openBox('local_meta');
    await Hive.openBox('consultas_box');
    await Hive.openBox('citas_box');
  });

  test('SyncService.syncPending uploads patient and marks as synced', () async {
    // Arrange
    final paciente = {
      'nombres': 'Sync',
      'apellidos': 'Test',
      'cedula': 'SYNC-123',
      'telefono': '000',
      'attachments': <String>[],
    };

    final localId = await LocalDb.savePatient(paciente);
    expect(localId, isNotNull);

    // Inject mock API client
    SyncService.api = MockApiClient();

    // Act
    await SyncService.instance.syncPending();

    // Assert: patient should be marked as synced (no longer pending)
    final pendientes = await LocalDb.getPending('patients');
    expect(pendientes.any((p) => p['localId'] == localId), isFalse);

    final byServer = await LocalDb.getPatientById('12345');
    expect(byServer, isNotNull);
    expect(byServer!['syncStatus'], 'synced');
  });

  test(
      'SyncService.syncPending marks patient as error when crearPaciente fails',
      () async {
    // Arrange
    final paciente = {
      'nombres': 'SyncFail',
      'apellidos': 'Test',
      'cedula': 'SYNC-FAIL-123',
      'telefono': '000',
      'attachments': <String>[],
    };

    final localId = await LocalDb.savePatient(paciente);
    expect(localId, isNotNull);

    // Inject mock API client that fails on crearPaciente
    SyncService.api = MockFailCreate();

    // Act
    await SyncService.instance.syncPending();

    // Assert: patient should no longer be pending and should be marked as error
    final pendientes = await LocalDb.getPending('patients');
    expect(pendientes.any((p) => p['localId'] == localId), isFalse);
    final rec = await LocalDb.getPatientById(localId);
    expect(rec, isNotNull);
    expect(rec!['syncStatus'], 'error');
    expect(rec['lastError'], contains('duplicate cedula'));
  });

  test('SyncService.syncPending marks patient error after upload retries',
      () async {
    // Arrange
    final paciente = {
      'nombres': 'SyncUploadFail',
      'apellidos': 'Test',
      'cedula': 'SYNC-UPFAIL-123',
      'telefono': '000',
      'attachments': <String>['/path/to/file1.jpg'],
    };

    final localId = await LocalDb.savePatient(paciente);
    expect(localId, isNotNull);

    // Inject mock API client that returns created patient but upload fails
    SyncService.api = MockFailUpload();

    // Act
    await SyncService.instance.syncPending();

    // Assert: since upload failed after retries, patient should be marked error
    final pendientes = await LocalDb.getPending('patients');
    expect(pendientes.any((p) => p['localId'] == localId), isFalse);

    final rec = await LocalDb.getPatientById(localId);
    expect(rec, isNotNull);
    expect(rec!['syncStatus'], 'error');
    expect(rec['lastError'], contains('Upload failed'));
    expect((rec['attempts'] ?? 0) as int, greaterThanOrEqualTo(3));
  });
}
