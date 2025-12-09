import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:clinica_app/services/local_db.dart';
import 'package:clinica_app/services/sync_service.dart';
import 'package:clinica_app/services/api_client.dart';

// Mocks for consultas/citas
class MockConsultaFail implements ApiClient {
  @override
  Future<bool> agendarCita(Map<String, dynamic> data) async => true;

  @override
  Future<bool> crearHistorial(
          Map<String, String> fields, List<String> archivos) async =>
      false;

  @override
  Future<Map<String, dynamic>> crearPaciente(Map<String, dynamic> data) async =>
      {
        'ok': true,
        'data': {'id': 1, ...data}
      };

  @override
  Future<Map<String, dynamic>?> buscarPacientePorCedula(String cedula) async =>
      null;

  @override
  Future<Map<String, dynamic>> subirDocumentosDoctor(
          int uid, List<String> attachments) async =>
      {'ok': true};
}

class MockConsultaOK implements ApiClient {
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
        'data': {'id': 2, ...data}
      };

  @override
  Future<Map<String, dynamic>?> buscarPacientePorCedula(String cedula) async =>
      null;

  @override
  Future<Map<String, dynamic>> subirDocumentosDoctor(
          int uid, List<String> attachments) async =>
      {'ok': true};
}

class MockCitaFail implements ApiClient {
  @override
  Future<bool> agendarCita(Map<String, dynamic> data) async => false;

  @override
  Future<bool> crearHistorial(
          Map<String, String> fields, List<String> archivos) async =>
      true;

  @override
  Future<Map<String, dynamic>> crearPaciente(Map<String, dynamic> data) async =>
      {
        'ok': true,
        'data': {'id': 3, ...data}
      };

  @override
  Future<Map<String, dynamic>?> buscarPacientePorCedula(String cedula) async =>
      null;

  @override
  Future<Map<String, dynamic>> subirDocumentosDoctor(
          int uid, List<String> attachments) async =>
      {'ok': true};
}

class MockCitaOK implements ApiClient {
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
        'data': {'id': 4, ...data}
      };

  @override
  Future<Map<String, dynamic>?> buscarPacientePorCedula(String cedula) async =>
      null;

  @override
  Future<Map<String, dynamic>> subirDocumentosDoctor(
          int uid, List<String> attachments) async =>
      {'ok': true};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final tmp =
        await Directory.systemTemp.createTemp('hive_sync_test_consultas');
    Hive.init(tmp.path);
    await Hive.openBox('patients_box');
    await Hive.openBox('local_meta');
    await Hive.openBox('consultas_box');
    await Hive.openBox('citas_box');
  });

  test(
      'SyncService.syncPending marks consulta as error when crearHistorial fails',
      () async {
    // Arrange
    final consulta = {
      'motivo': 'Dolor',
      'paciente_id': 'P-1',
      'imagenes': <String>[],
    };

    final localId = await LocalDb.saveConsultaLocal(consulta);
    expect(localId, isNotNull);

    SyncService.api = MockConsultaFail();

    // Act
    await SyncService.instance.syncPending();

    // Assert: consulta should be marked as error
    final rec = (await LocalDb.getConsultasByPacienteId('P-1'))
        .firstWhere((r) => r['localId'] == localId, orElse: () => {});
    expect(rec, isNotNull);
    expect(rec['syncStatus'], 'error');
    expect(rec['lastError'], isNotNull);
  });

  test('SyncService.syncPending marks cita as error when agendarCita fails',
      () async {
    // Arrange
    final cita = {
      'fecha': '2025-12-10',
      'hora': '09:00',
      'paciente_id': 'P-2',
    };

    final localId = await LocalDb.saveCitaLocal(cita);
    expect(localId, isNotNull);

    SyncService.api = MockCitaFail();

    // Act
    await SyncService.instance.syncPending();

    // Assert: cita should be marked as error
    final rec = (await LocalDb.getCitasByPacienteId('P-2'))
        .firstWhere((r) => r['localId'] == localId, orElse: () => {});
    expect(rec, isNotNull);
    expect(rec['syncStatus'], 'error');
    expect(rec['lastError'], isNotNull);
  });

  test('SyncService.syncPending applies success for consulta and cita',
      () async {
    // Arrange consulta
    final consulta = {
      'motivo': 'Chequeo',
      'paciente_id': 'P-3',
      'imagenes': <String>[],
    };
    final consultaId = await LocalDb.saveConsultaLocal(consulta);
    expect(consultaId, isNotNull);

    // Arrange cita
    final cita = {
      'fecha': '2025-12-11',
      'hora': '10:00',
      'paciente_id': 'P-3',
    };
    final citaId = await LocalDb.saveCitaLocal(cita);
    expect(citaId, isNotNull);

    SyncService.api = MockConsultaOK();

    // Act
    await SyncService.instance.syncPending();

    // Assert: both should no longer be pending and should be synced
    final consultRec = (await LocalDb.getConsultasByPacienteId('P-3'))
        .firstWhere((r) => r['localId'] == consultaId, orElse: () => {});
    final citaRec = (await LocalDb.getCitasByPacienteId('P-3'))
        .firstWhere((r) => r['localId'] == citaId, orElse: () => {});
    expect(consultRec, isNotNull);
    expect(citaRec, isNotNull);
    expect(consultRec['syncStatus'], 'synced');
    expect(citaRec['syncStatus'], 'synced');
  });
}
