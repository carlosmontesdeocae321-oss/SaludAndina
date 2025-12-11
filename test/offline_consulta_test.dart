import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:clinica_app/services/local_db.dart';

void main() {
  late Directory tmpDir;
  setUpAll(() async {
    // Use a temporary directory for Hive to avoid platform channel calls
    tmpDir = await Directory.systemTemp.createTemp('clinica_test_');
    Hive.init(tmpDir.path);
    // Open boxes used by LocalDb
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

  test('Guardar consulta local y recuperarla por pacienteId', () async {
    final consulta = {
      'paciente_id': 'P-TEST-1',
      'motivo_consulta': 'Dolor de cabeza',
      'diagnostico': 'Migraña',
      'tratamiento': 'Analgesia',
      'notas_html': '<p>Prueba</p>',
    };

    final localId = await LocalDb.saveConsultaLocal(consulta);
    expect(localId, isNotNull);

    final listas = await LocalDb.getConsultasByPacienteId('P-TEST-1');
    expect(listas, isNotEmpty);

    final found =
        listas.firstWhere((r) => r['localId'] == localId, orElse: () => {});
    expect(found, isNotEmpty);
    final data = Map<String, dynamic>.from(found['data'] ?? {});
    expect(data['diagnostico'], 'Migraña');
  });
}
