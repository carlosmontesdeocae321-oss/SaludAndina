import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:clinica_app/services/local_db.dart';
import 'package:clinica_app/services/sync_service.dart';
import 'package:clinica_app/services/api_client.dart';

class MockUploadReturnsFiles implements ApiClient {
  @override
  Future<bool> agendarCita(Map<String, dynamic> data) async => true;

  @override
  Future<bool> crearHistorial(
          Map<String, String> fields, List<String> archivos) async =>
      true;

  @override
  Future<Map<String, dynamic>> crearPaciente(Map<String, dynamic> data) async =>
      {
        'ok': true,
        'data': {'id': 5000, ...data}
      };

  @override
  Future<Map<String, dynamic>?> buscarPacientePorCedula(String cedula) async =>
      null;

  @override
  Future<Map<String, dynamic>> subirDocumentosDoctor(
      int uid, List<String> attachments) async {
    return {
      'ok': true,
      'files': attachments
          .map((a) =>
              'https://server.test/files/${Uri.file(a).pathSegments.last}')
          .toList()
    };
  }
}

class MockUploadAlwaysFails implements ApiClient {
  @override
  Future<bool> agendarCita(Map<String, dynamic> data) async => true;

  @override
  Future<bool> crearHistorial(
          Map<String, String> fields, List<String> archivos) async =>
      true;

  @override
  Future<Map<String, dynamic>> crearPaciente(Map<String, dynamic> data) async =>
      {
        'ok': true,
        'data': {'id': 6000, ...data}
      };

  @override
  Future<Map<String, dynamic>?> buscarPacientePorCedula(String cedula) async =>
      null;

  @override
  Future<Map<String, dynamic>> subirDocumentosDoctor(
      int uid, List<String> attachments) async {
    return {'ok': false, 'error': 'network'};
  }
}

class MockUploadFlaky implements ApiClient {
  int _calls = 0;
  final int failUntil; // number of failed calls before success
  final int serverId;

  MockUploadFlaky(this.failUntil, {this.serverId = 7001});

  @override
  Future<bool> agendarCita(Map<String, dynamic> data) async => true;

  @override
  Future<bool> crearHistorial(
          Map<String, String> fields, List<String> archivos) async =>
      true;

  @override
  Future<Map<String, dynamic>> crearPaciente(Map<String, dynamic> data) async =>
      {
        'ok': true,
        'data': {'id': serverId, ...data}
      };

  @override
  Future<Map<String, dynamic>?> buscarPacientePorCedula(String cedula) async =>
      null;

  @override
  Future<Map<String, dynamic>> subirDocumentosDoctor(
      int uid, List<String> attachments) async {
    _calls += 1;
    if (_calls <= failUntil) {
      return {'ok': false, 'error': 'transient'};
    }
    return {
      'ok': true,
      'files': attachments
          .map((a) =>
              'https://server.test/files/${Uri.file(a).pathSegments.last}')
          .toList()
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final tmp = await Directory.systemTemp.createTemp('hive_sync_uploads');
    Hive.init(tmp.path);
    await Hive.openBox('patients_box');
    await Hive.openBox('local_meta');
    await Hive.openBox('consultas_box');
    await Hive.openBox('citas_box');
  });

  test('SyncService persists file URLs returned by subirDocumentosDoctor',
      () async {
    final paciente = {
      'nombres': 'UploadFiles',
      'apellidos': 'Test',
      'cedula': 'UPLOAD-1',
      'attachments': <String>['/tmp/a.jpg', '/tmp/b.jpg'],
    };

    final localId = await LocalDb.savePatient(paciente);
    expect(localId, isNotNull);

    SyncService.api = MockUploadReturnsFiles();

    await SyncService.instance.syncPending();

    // After sync, patient should be marked as synced and attachments updated (should include server URLs)
    final rec = await LocalDb.getPatientById('5000');
    expect(rec, isNotNull);
    final attachments = List<String>.from(
        rec!['attachments'] ?? rec['data']?['attachments'] ?? []);
    expect(attachments.length, greaterThanOrEqualTo(2));
    expect(
        attachments
            .any((a) => a.toString().contains('https://server.test/files/')),
        isTrue);
  });

  test('SyncService marks patient error after 3 failed upload attempts',
      () async {
    final paciente = {
      'nombres': 'UploadFail',
      'apellidos': 'Test',
      'cedula': 'UPLOAD-FAIL',
      'attachments': <String>['/tmp/c.jpg'],
    };

    final localId = await LocalDb.savePatient(paciente);
    expect(localId, isNotNull);

    SyncService.api = MockUploadAlwaysFails();

    // run sync 3 times to simulate retries
    await SyncService.instance.syncPending();
    await SyncService.instance.syncPending();
    await SyncService.instance.syncPending();

    final rec = await LocalDb.getPatientById(localId);
    expect(rec, isNotNull);
    expect(rec!['syncStatus'], 'error');
    expect(rec['lastError'], contains('Upload failed'));
  });

  test('SyncService succeeds after transient upload failures (backoff)',
      () async {
    final paciente = {
      'nombres': 'UploadFlaky',
      'apellidos': 'Test',
      'cedula': 'UPLOAD-FLAKY',
      'attachments': <String>['/tmp/d.jpg'],
    };

    final localId = await LocalDb.savePatient(paciente);
    expect(localId, isNotNull);

    SyncService.api = MockUploadFlaky(2, serverId: 7001);

    // Single syncPending should internally retry with backoff
    await SyncService.instance.syncPending();

    final rec = await LocalDb.getPatientById('7001');
    expect(rec, isNotNull);
    expect(rec!['syncStatus'], 'synced');
    final attachments = List<String>.from(
        rec['attachments'] ?? rec['data']?['attachments'] ?? []);
    expect(attachments.any((a) => a.contains('https://server.test/files/')),
        isTrue);
  });
}
