import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/cita.dart';
import '../models/consulta.dart';
import '../models/paciente.dart';

class PdfHelper {
  static const PdfColor _accent = PdfColor.fromInt(0xFF00897B);
  static const PdfColor _accentDark = PdfColor.fromInt(0xFF00695C);
  static const PdfColor _chipBg = PdfColor.fromInt(0xFFE0F2F1);
  static const PdfColor _chipBorder = PdfColor.fromInt(0xFF80CBC4);
  static const PdfColor _panelBg = PdfColor.fromInt(0xFFF5F7FA);
  static const PdfColor _textStrong = PdfColor.fromInt(0xFF37474F);
  static const PdfColor _textMuted = PdfColor.fromInt(0xFF607D8B);
  static const PdfColor _borderSoft = PdfColor.fromInt(0xFFE0E0E0);
  static const PdfColor _upcomingBg = PdfColor.fromInt(0xFFE8F5E9);
  static const PdfColor _upcomingBorder = PdfColor.fromInt(0xFFB2DFDB);

  // Genera un PDF con la info del paciente y sus consultas y abre el diálogo de compartir/imprimir
  static Future<void> generarYCompartirPdf({
    required Paciente paciente,
    required List<Consulta> consultas,
    List<Cita> citas = const [],
  }) async {
    final logoBytes = await _loadLogoBytes();
    final dateFmt = DateFormat('dd/MM/yyyy');
    final nacimientoFmt = _formatBirthDate(paciente.fechaNacimiento);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final upcomingCitas =
        citas.where((c) => !c.fecha.toLocal().isBefore(today)).toList()
          ..sort(
            (a, b) => a.fecha.toLocal().compareTo(b.fecha.toLocal()),
          );

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 40),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 8),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (logoBytes != null)
                  pw.Container(
                    width: 56,
                    height: 56,
                    decoration: pw.BoxDecoration(
                      borderRadius: pw.BorderRadius.circular(12),
                      border: pw.Border.all(color: _accent, width: 1.2),
                      image: pw.DecorationImage(
                        image: pw.MemoryImage(logoBytes),
                        fit: pw.BoxFit.cover,
                      ),
                    ),
                  ),
                if (logoBytes != null) _hGap(16),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // ignore: prefer_const_constructors
                    pw.Text(
                      'SaludAndina',
                      style:
                          // ignore: prefer_const_constructors
                          pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: _accentDark,
                      ),
                    ),
                    // ignore: prefer_const_constructors
                    pw.Text(
                      'Reporte de historial médico',
                      style:
                          // ignore: prefer_const_constructors
                          pw.TextStyle(color: _textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _vGap(16),
          pw.Container(
            decoration: pw.BoxDecoration(
              color: _panelBg,
              borderRadius: pw.BorderRadius.circular(12),
              border: pw.Border.all(color: _borderSoft, width: 0.8),
            ),
            padding: const pw.EdgeInsets.all(14),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // ignore: prefer_const_constructors
                pw.Text(
                  'Datos del paciente',
                  style:
                      // ignore: prefer_const_constructors
                      pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: _accentDark,
                  ),
                ),
                _vGap(8),
                _infoRow('Nombre', '${paciente.nombres} ${paciente.apellidos}',
                    _textStrong, _textMuted),
                _infoRow(
                    'Cédula',
                    paciente.cedula.isEmpty ? 'N/D' : paciente.cedula,
                    _textStrong,
                    _textMuted),
                _infoRow(
                    'Teléfono',
                    paciente.telefono.isEmpty ? 'N/D' : paciente.telefono,
                    _textStrong,
                    _textMuted),
                _infoRow(
                    'Dirección',
                    paciente.direccion.isEmpty ? 'N/D' : paciente.direccion,
                    _textStrong,
                    _textMuted),
                _infoRow('Nacimiento', nacimientoFmt, _textStrong, _textMuted),
              ],
            ),
          ),
          if (upcomingCitas.isNotEmpty) ...[
            _vGap(20),
            // ignore: prefer_const_constructors
            pw.Text(
              'Próximas citas',
              style:
                  // ignore: prefer_const_constructors
                  pw.TextStyle(
                fontSize: 15,
                fontWeight: pw.FontWeight.bold,
                color: _accentDark,
              ),
            ),
            _vGap(10),
            ...upcomingCitas.map((cita) {
              final fechaStr = dateFmt.format(cita.fecha.toLocal());
              final horaStr = cita.hora.trim();
              final motivo =
                  cita.motivo.isEmpty ? 'Consulta programada' : cita.motivo;
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                decoration: pw.BoxDecoration(
                  color: _upcomingBg,
                  borderRadius: pw.BorderRadius.circular(12),
                  border: pw.Border.all(
                    color: _upcomingBorder,
                    width: 0.8,
                  ),
                ),
                padding: const pw.EdgeInsets.all(12),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // ignore: prefer_const_constructors
                    pw.Text(
                      motivo,
                      style:
                          // ignore: prefer_const_constructors
                          pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: _accentDark,
                      ),
                    ),
                    _vGap(4),
                    // ignore: prefer_const_constructors
                    pw.Text(
                      'Fecha: $fechaStr',
                      style:
                          // ignore: prefer_const_constructors
                          pw.TextStyle(fontSize: 11, color: _textMuted),
                    ),
                    if (horaStr.isNotEmpty) ...[
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 2),
                        child: pw.Text(
                          'Hora: $horaStr',
                          style: const pw.TextStyle(
                            fontSize: 11,
                            color: _textMuted,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 1),
                        child: pw.Text(
                          'Hora local de la clínica',
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: _textMuted,
                          ),
                        ),
                      ),
                    ],
                    if (cita.estado.isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 4),
                        child:
                            // ignore: prefer_const_constructors
                            pw.Text(
                          'Estado: ${cita.estado}',
                          style:
                              // ignore: prefer_const_constructors
                              pw.TextStyle(fontSize: 11, color: _textStrong),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
          _vGap(20),
          // ignore: prefer_const_constructors
          pw.Text(
            'Consultas (${consultas.length})',
            style:
                // ignore: prefer_const_constructors
                pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
          ),
          _vGap(12),
          ...consultas.map((c) {
            final fechaStr = dateFmt.format(c.fecha);

            pw.Widget metric(String label, String value) {
              return pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: _chipBg,
                  borderRadius: pw.BorderRadius.circular(999),
                  border: pw.Border.all(color: _chipBorder, width: 0.6),
                ),
                child: pw.Text('$label: $value',
                    style: const pw.TextStyle(fontSize: 10)),
              );
            }

            final metrics = <pw.Widget>[];
            if (c.peso > 0) {
              metrics.add(metric('Peso', '${c.peso.toStringAsFixed(1)} kg'));
            }
            if (c.estatura > 0) {
              metrics.add(
                  metric('Estatura', '${c.estatura.toStringAsFixed(2)} m'));
            }
            if (c.imc > 0) {
              metrics.add(metric('IMC', c.imc.toStringAsFixed(1)));
            }
            if (c.presion.isNotEmpty) {
              metrics.add(metric('Presión', c.presion));
            }
            if (c.frecuenciaCardiaca > 0) {
              metrics.add(metric('FC', '${c.frecuenciaCardiaca} bpm'));
            }
            if (c.frecuenciaRespiratoria > 0) {
              metrics.add(metric('FR', '${c.frecuenciaRespiratoria} rpm'));
            }
            if (c.temperatura > 0) {
              metrics.add(
                  metric('Temp', '${c.temperatura.toStringAsFixed(1)} °C'));
            }

            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              decoration: pw.BoxDecoration(
                borderRadius: pw.BorderRadius.circular(12),
                border: pw.Border.all(color: _borderSoft, width: 0.8),
              ),
              padding: const pw.EdgeInsets.all(12),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          // ignore: prefer_const_constructors
                          pw.Text(
                            c.motivo.isEmpty ? 'Consulta' : c.motivo,
                            style:
                                // ignore: prefer_const_constructors
                                pw.TextStyle(
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold,
                              color: _accentDark,
                            ),
                          ),
                          _vGap(2),
                          // ignore: prefer_const_constructors
                          pw.Text('Fecha: $fechaStr',
                              style:
                                  // ignore: prefer_const_constructors
                                  pw.TextStyle(
                                      fontSize: 10, color: _textMuted)),
                        ],
                      ),
                      if (metrics.isNotEmpty)
                        pw.Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: metrics,
                        ),
                    ],
                  ),
                  _vGap(10),
                  if (c.diagnostico.isNotEmpty)
                    _sectionBlock(
                        'Diagnóstico', c.diagnostico, _textStrong, _textMuted),
                  if (c.tratamiento.isNotEmpty)
                    _sectionBlock(
                        'Tratamiento', c.tratamiento, _textStrong, _textMuted),
                  if (c.receta.isNotEmpty)
                    _sectionBlock('Receta', c.receta, _textStrong, _textMuted),
                ],
              ),
            );
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

  static final DateFormat _birthFormat = DateFormat('dd/MM/yyyy');

  static String _formatBirthDate(String raw) {
    if (raw.trim().isEmpty) return 'N/D';
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) {
      return _birthFormat.format(parsed);
    }
    try {
      final manual = _birthFormat.parse(raw);
      return _birthFormat.format(manual);
    } catch (_) {
      return raw;
    }
  }

  static pw.Widget _infoRow(
      String label, String value, PdfColor strongColor, PdfColor mutedColor) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 90,
            padding: const pw.EdgeInsets.only(top: 1),
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: strongColor,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(color: mutedColor),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _sectionBlock(
      String title, String content, PdfColor strongColor, PdfColor mutedColor) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: strongColor,
            ),
          ),
          pw.Divider(color: _borderSoft, height: 6, thickness: 0.4),
          pw.Text(
            content,
            style: pw.TextStyle(fontSize: 11, color: mutedColor),
          ),
        ],
      ),
    );
  }

  static pw.Widget _vGap(double height) {
    // ignore: prefer_const_constructors
    return pw.SizedBox(height: height);
  }

  static pw.Widget _hGap(double width) {
    // ignore: prefer_const_constructors
    return pw.SizedBox(width: width);
  }

  static Future<Uint8List?> _loadLogoBytes() async {
    try {
      final data = await rootBundle.load('assets/images/logo.png');
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }
}
