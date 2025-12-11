import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:clinica_app/services/local_db.dart';
import 'package:clinica_app/services/sync_service.dart';
import 'package:clinica_app/services/api_client.dart';

// Mock API that simulates successful crearHistorial but does NOT expose the
// created consulta via obtenerConsultasPacienteRaw (returns empty list).
class MockNoResolveConsulta implements ApiClient {
  @override
  Future<bool> agendarCita(Map<String, dynamic> data) async => true;

  @override
  Future<bool> crearHistorial(
      Map<String, String> fields, List<String> archivos) async {
    // Simulate server accepted the create but server list will not show it yet
    return true;
  }

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

  @override
  Future<bool> eliminarPaciente(String id) async => true;

  @override
  Future<List<Map<String, dynamic>>> obtenerConsultasPacienteRaw(
      String pacienteId) async {
    // Return empty to simulate server doesn't expose created consulta yet
    return [];
  }

  @override
  Future<bool> eliminarHistorial(String id) async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final tmp = await Directory.systemTemp.createTemp('hive_repro_consulta');
    Hive.init(tmp.path);
    await Hive.openBox('patients_box');
    await Hive.openBox('local_meta');
    await Hive.openBox('consultas_box');
    await Hive.openBox('citas_box');
  });

  test(
      'Repro: crear consulta offline, syncPending, mostrar estado local y remoto',
      () async {
    // Arrange: create a consulta offline
    final consulta = {
      'motivo': 'Repro Test',
      'paciente_id': 'P-REPRO',
      'fecha': DateTime.now().toIso8601String(),
      'imagenes': <String>[],
    };

    final localId = await LocalDb.saveConsultaLocal(consulta);
    print('Created local consulta localId=$localId');

    // Show local before sync
    final before = await LocalDb.getConsultasByPacienteId('P-REPRO');
    print('Local consultas before sync:');
    for (final r in before) {
      print(
          '  localId=${r['localId']} server=${r['serverId']} status=${r['syncStatus']} lastError=${r['lastError']} attempts=${r['attempts'] ?? 0}');
    }

    // Use mock API that does not expose the created consulta on list
    SyncService.api = MockNoResolveConsulta();

    // Act: force sync
    await SyncService.instance.syncPending();

    // Show local after sync
    final after = await LocalDb.getConsultasByPacienteId('P-REPRO');
    print('Local consultas after sync:');
    for (final r in after) {
      print(
          '  localId=${r['localId']} server=${r['serverId']} status=${r['syncStatus']} lastError=${r['lastError']} attempts=${r['attempts'] ?? 0}');
    }

    // Show remote list for that paciente id according to API
    final remote = await SyncService.api.obtenerConsultasPacienteRaw('P-REPRO');
    print('Remote consultas for paciente P-REPRO: ${remote.length} items');
    for (final it in remote) {
      print('  remote: ${it}');
    }

    // Assert minimal expectations for the repro: local record exists and remote empty
    final rec =
        after.firstWhere((r) => r['localId'] == localId, orElse: () => {});
    expect(rec, isNotNull);
    // It should either be pending (preferred) or error if create failed; remote should be empty
    expect(rec['syncStatus'], anyOf('pending', 'error'));
    expect(remote, isEmpty);
  });
}
