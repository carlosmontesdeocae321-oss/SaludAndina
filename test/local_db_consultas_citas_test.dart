import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:clinica_app/services/local_db.dart';

void main() {
  setUpAll(() async {
    final tmp = await Directory.systemTemp.createTemp('hive_test_cc');
    Hive.init(tmp.path);
    await Hive.openBox('patients_box');
    await Hive.openBox('local_meta');
    await Hive.openBox('consultas_box');
    await Hive.openBox('citas_box');
  });

  test('Guardar consulta local y marcar como synced', () async {
    final consulta = {
      'motivo': 'Dolor de cabeza',
      'paciente_id': 'P-100',
      'fecha': DateTime.now().toIso8601String(),
    };

    final localId = await LocalDb.saveConsultaLocal(consulta);
    expect(localId, isNotNull);

    final pendientes = await LocalDb.getPending('consultas');
    expect(pendientes.any((c) => c['localId'] == localId), isTrue);

    await LocalDb.markConsultaAsSynced(localId, 'C-500', {'id': 'C-500'});
    final byId = await LocalDb.getConsultasByPacienteId('P-100');
    expect(byId, isNotEmpty);
    final rec = byId.firstWhere((r) => r['localId'] == localId);
    expect(rec['syncStatus'], 'synced');
  });

  test('Guardar cita local y marcar como synced', () async {
    final cita = {
      'paciente_id': 'P-200',
      'fecha': DateTime.now().toIso8601String(),
      'hora': '10:00',
    };
    final localId = await LocalDb.saveCitaLocal(cita);
    expect(localId, isNotNull);

    final pendientes = await LocalDb.getPending('citas');
    expect(pendientes.any((c) => c['localId'] == localId), isTrue);

    await LocalDb.markCitaAsSynced(localId, 'CT-900', {'id': 'CT-900'});
    final byId = await LocalDb.getCitasByPacienteId('P-200');
    expect(byId, isNotEmpty);
    final rec = byId.firstWhere((r) => r['localId'] == localId);
    expect(rec['syncStatus'], 'synced');
  });
}
