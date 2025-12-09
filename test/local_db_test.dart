import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:clinica_app/services/local_db.dart';
import 'package:hive/hive.dart';

void main() {
  setUpAll(() async {
    // Inicializar Hive en un directorio temporal para pruebas (evita plugins)
    final tmp = await Directory.systemTemp.createTemp('hive_test');
    Hive.init(tmp.path);
    // Abrir cajas usadas por LocalDb
    await Hive.openBox('patients_box');
    await Hive.openBox('local_meta');
    await Hive.openBox('consultas_box');
    await Hive.openBox('citas_box');
  });

  test('Guardar paciente local y sincronización básica', () async {
    final paciente = {
      'nombres': 'Prueba',
      'apellidos': 'Local',
      'cedula': 'TEST-0001',
      'telefono': '999999999',
    };

    final localId = await LocalDb.savePatient(paciente);
    expect(localId, isNotNull);

    final pendientes = await LocalDb.getPending('patients');
    expect(pendientes.any((p) => p['localId'] == localId), isTrue);

    final porCedula = await LocalDb.getPatientByCedula('TEST-0001');
    expect(porCedula, isNotNull);
    expect(porCedula!['data']['nombres'], 'Prueba');

    // Marcar como sincronizado (simulando serverId)
    await LocalDb.markAsSynced(
        localId, '9999', {'id': 9999, 'nombres': 'Prueba'});

    final buscadoPorServer = await LocalDb.getPatientById('9999');
    expect(buscadoPorServer, isNotNull);
    expect(buscadoPorServer!['syncStatus'], 'synced');
  });
}
