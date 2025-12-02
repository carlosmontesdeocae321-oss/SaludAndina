import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import '../models/paciente.dart';
import '../models/consulta.dart';

class PdfHelper {
  // Genera un PDF con la info del paciente y sus consultas y abre el diálogo de compartir/imprimir
  static Future<void> generarYCompartirPdf({
    required Paciente paciente,
    required List<Consulta> consultas,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
              level: 0,
              child: pw.Text(
                  'Historial médico: ${paciente.nombres} ${paciente.apellidos}',
                  style: const pw.TextStyle(fontSize: 18))),
          pw.SizedBox(height: 8),
          pw.Text('Cédula: ${paciente.cedula}'),
          pw.Text('Teléfono: ${paciente.telefono}'),
          pw.Text('Dirección: ${paciente.direccion}'),
          pw.Text('Nacimiento: ${paciente.fechaNacimiento}'),
          pw.SizedBox(height: 12),
          pw.Text('Consultas (${consultas.length})',
              style: const pw.TextStyle(fontSize: 14)),
          pw.SizedBox(height: 8),
          ...consultas.map((c) {
            final fechaStr = c.fecha.toIso8601String().split('T')[0];
            final horaStr =
                c.fecha.toIso8601String().split('T')[1].split('.').first;

            return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 4),
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Fecha: $fechaStr  Hora: $horaStr',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 4),
                          pw.Text('Motivo: ${c.motivo}'),
                          pw.Text('Diagnóstico: ${c.diagnostico}'),
                          pw.Text('Tratamiento: ${c.tratamiento}'),
                          pw.Text('Receta: ${c.receta}'),
                        ]),
                  ),
                  pw.Divider()
                ]);
          })
        ],
      ),
    );

    try {
      final bytes = await doc.save();

      // Guardar temporalmente y abrir diálogo de compartir
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/historial_${paciente.id}.pdf');
      await file.writeAsBytes(bytes);

      await Printing.sharePdf(
          bytes: bytes, filename: 'historial_${paciente.id}.pdf');
    } catch (e) {
      rethrow;
    }
  }
}
