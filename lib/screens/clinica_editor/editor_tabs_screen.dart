import 'package:flutter/material.dart';
import '../../services/editor_macros.dart';
import '../../utils/editor_utils.dart';
import '../../widgets/clinica_editor/macro_bar.dart';
import '../../models/consulta.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../services/api_services.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class EditorTabsScreen extends StatefulWidget {
  final String pacienteId;
  final Consulta? consulta;
  const EditorTabsScreen({super.key, required this.pacienteId, this.consulta});

  @override
  State<EditorTabsScreen> createState() => _EditorTabsScreenState();
}

class _EditorTabsScreenState extends State<EditorTabsScreen> {
  // Patient
  final sexoCtrl = TextEditingController(text: 'FEMENINO');
  final edadCtrl = TextEditingController();
  final diaCtrl = TextEditingController();
  final areaCtrl = TextEditingController();

  // Historia
  final appCtrl = TextEditingController();
  final apfCtrl = TextEditingController();
  final alergiasCtrl = TextEditingController();
  final tiempoCtrl = TextEditingController();
  final evolucionCtrl = TextEditingController();

  // Examen / labs / dx / plan
  final examenCtrl = TextEditingController();
  // Detailed examen fields
  final pielCtrl = TextEditingController();
  final cabezaCtrl = TextEditingController();
  final ojosCtrl = TextEditingController();
  final narizCtrl = TextEditingController();
  final bocaCtrl = TextEditingController();
  final oidosCtrl = TextEditingController();
  final orofaringeCtrl = TextEditingController();
  final cuelloCtrl = TextEditingController();
  final toraxCtrl = TextEditingController();
  final camposPulmCtrl = TextEditingController();
  final ruidosCardCtrl = TextEditingController();
  final abdomenCtrl = TextEditingController();
  final extremidadesCtrl = TextEditingController();
  final neuroCtrl = TextEditingController();
  final labsCtrl = TextEditingController();
  final analisisCtrl = TextEditingController();
  final dxCtrl = TextEditingController();
  final planCtrl = TextEditingController();

  // Signos vitales
  final svTaCtrl = TextEditingController();
  final svFcCtrl = TextEditingController();
  final svFrCtrl = TextEditingController();
  final svTempCtrl = TextEditingController();
  final svSatCtrl = TextEditingController();
  final svGliCtrl = TextEditingController();

  // Indicaciones
  final medidasCtrl = TextEditingController();
  final hidratacionCtrl = TextEditingController();
  final medicacionCtrl = TextEditingController();

  // Imágenes (labs / imágenes)
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _imagenes = [];
  // images already stored on backend (paths)
  final List<String> _imagenesGuardadas = [];
  final List<String> _imagenesParaEliminar = [];

  @override
  void dispose() {
    sexoCtrl.dispose();
    edadCtrl.dispose();
    diaCtrl.dispose();
    areaCtrl.dispose();
    appCtrl.dispose();
    apfCtrl.dispose();
    alergiasCtrl.dispose();
    tiempoCtrl.dispose();
    evolucionCtrl.dispose();
    examenCtrl.dispose();
    pielCtrl.dispose();
    cabezaCtrl.dispose();
    ojosCtrl.dispose();
    narizCtrl.dispose();
    bocaCtrl.dispose();
    oidosCtrl.dispose();
    orofaringeCtrl.dispose();
    cuelloCtrl.dispose();
    toraxCtrl.dispose();
    camposPulmCtrl.dispose();
    ruidosCardCtrl.dispose();
    abdomenCtrl.dispose();
    extremidadesCtrl.dispose();
    neuroCtrl.dispose();
    labsCtrl.dispose();
    analisisCtrl.dispose();
    dxCtrl.dispose();
    planCtrl.dispose();
    svTaCtrl.dispose();
    svFcCtrl.dispose();
    svFrCtrl.dispose();
    svTempCtrl.dispose();
    svSatCtrl.dispose();
    svGliCtrl.dispose();
    medidasCtrl.dispose();
    hidratacionCtrl.dispose();
    medicacionCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // If an existing consulta is provided, prefill the fields for editing
    final c = widget.consulta;
    if (c != null) {
      // Basic mapping - fill the controls with available data
      evolucionCtrl.text = c.motivo;
      dxCtrl.text = c.diagnostico;
      planCtrl.text = c.tratamiento;
      medicacionCtrl.text = c.receta;
      // vital signs
      svTaCtrl.text = c.presion;
      svFcCtrl.text =
          c.frecuenciaCardiaca > 0 ? c.frecuenciaCardiaca.toString() : '';
      svFrCtrl.text = c.frecuenciaRespiratoria > 0
          ? c.frecuenciaRespiratoria.toString()
          : '';
      svTempCtrl.text = c.temperatura > 0 ? c.temperatura.toString() : '';
      // map other basic fields if present
      if (c.otros.isNotEmpty) medidasCtrl.text = c.otros;
      // images (if backend returned paths) - we won't convert to XFile, but keep paths
      // for preview in the list we keep Consulta.imagenes. For editing, user can add new images.
      if (c.imagenes.isNotEmpty) _imagenesGuardadas.addAll(c.imagenes);
      // Prefill detailed examen fields if the backend returned them separately
      if (c.examenPiel.isNotEmpty) pielCtrl.text = c.examenPiel;
      if (c.examenCabeza.isNotEmpty) cabezaCtrl.text = c.examenCabeza;
      if (c.examenOjos.isNotEmpty) ojosCtrl.text = c.examenOjos;
      if (c.examenNariz.isNotEmpty) narizCtrl.text = c.examenNariz;
      if (c.examenBoca.isNotEmpty) bocaCtrl.text = c.examenBoca;
      if (c.examenOidos.isNotEmpty) oidosCtrl.text = c.examenOidos;
      if (c.examenOrofaringe.isNotEmpty) {
        orofaringeCtrl.text = c.examenOrofaringe;
      }
      if (c.examenCuello.isNotEmpty) cuelloCtrl.text = c.examenCuello;
      if (c.examenTorax.isNotEmpty) toraxCtrl.text = c.examenTorax;
      if (c.examenCamposPulm.isNotEmpty) {
        camposPulmCtrl.text = c.examenCamposPulm;
      }
      if (c.examenRuidosCard.isNotEmpty) {
        ruidosCardCtrl.text = c.examenRuidosCard;
      }
      if (c.examenAbdomen.isNotEmpty) abdomenCtrl.text = c.examenAbdomen;
      if (c.examenExtremidades.isNotEmpty) {
        extremidadesCtrl.text = c.examenExtremidades;
      }
      if (c.examenNeuro.isNotEmpty) neuroCtrl.text = c.examenNeuro;
      // If the backend returned notasHtml, try to populate more fields from it
      if (c.notasHtml.isNotEmpty) {
        // Try to extract structured parts from notasHtml instead of dumping all text
        // 1) Examen físico general (after <h4>Examen físico</h4>)
        final examenGeneral =
            _extractAfterHeading(c.notasHtml, 'Examen físico');
        if (examenGeneral.isNotEmpty) {
          examenCtrl.text = examenGeneral;
        } else {
          // fallback: plain text
          examenCtrl.text = _stripHtml(c.notasHtml);
        }

        // 2) Pruebas (inside <pre>..</pre>)
        final pruebas = _extractTagContent(c.notasHtml, 'pre');
        if (pruebas.isNotEmpty) {
          labsCtrl.text = pruebas;
        }

        // 3) Diagnóstico / Tratamiento / Receta (Plan)
        final dxFromHtml = _extractAfterHeading(c.notasHtml, 'Diagnóstico');
        final planFromHtml =
            _extractAfterHeading(c.notasHtml, 'Plan de manejo').isNotEmpty
                ? _extractAfterHeading(c.notasHtml, 'Plan de manejo')
                : _extractAfterHeading(c.notasHtml, 'Plan');
        final recetaFromHtml = _extractAfterHeading(c.notasHtml, 'Receta');
        if (dxFromHtml.isNotEmpty && dxCtrl.text.isEmpty) {
          dxCtrl.text = dxFromHtml;
        }
        if (planFromHtml.isNotEmpty && planCtrl.text.isEmpty) {
          planCtrl.text = planFromHtml;
        }
        if (recetaFromHtml.isNotEmpty && medicacionCtrl.text.isEmpty) {
          medicacionCtrl.text = recetaFromHtml;
        }

        // 4) Indicaciones: buscar párrafos con etiquetas <strong>Medidas generales:, Hidratación / Nutrición:, Medicación:
        final m = _extractStrongField(c.notasHtml, 'Medidas generales');
        final h = _extractStrongField(c.notasHtml, 'Hidratación / Nutrición');
        final md = _extractStrongField(c.notasHtml, 'Medicación');
        if (m.isNotEmpty) medidasCtrl.text = m;
        if (h.isNotEmpty) hidratacionCtrl.text = h;
        if (md.isNotEmpty) medicacionCtrl.text = md;

        // 4b) Historia: intentar extraer campos comunes (Personales, Familiares, Alergias, Tiempo/Evolución)
        final personales = _extractStrongField(c.notasHtml, 'Personales');
        final familiares = _extractStrongField(c.notasHtml, 'Familiares');
        final alergias = _extractStrongField(c.notasHtml, 'Alergias');
        final tiempo = _extractStrongField(c.notasHtml, 'Tiempo');
        final evolucionFromHtml =
            _extractAfterHeading(c.notasHtml, 'Evolución');
        if (personales.isNotEmpty && appCtrl.text.isEmpty) {
          appCtrl.text = personales;
        }
        if (familiares.isNotEmpty && apfCtrl.text.isEmpty) {
          apfCtrl.text = familiares;
        }
        if (alergias.isNotEmpty && alergiasCtrl.text.isEmpty) {
          alergiasCtrl.text = alergias;
        }
        if (tiempo.isNotEmpty && tiempoCtrl.text.isEmpty) {
          tiempoCtrl.text = tiempo;
        }
        if (evolucionFromHtml.isNotEmpty && evolucionCtrl.text.isEmpty) {
          evolucionCtrl.text = evolucionFromHtml;
        }

        // 5) Detailed examen parts (Piel, Cabeza, etc.) using strong-labeled <p><strong>Label:</strong>
        final candidates = {
          'Piel': (String v) => pielCtrl.text = v,
          'Cabeza': (String v) => cabezaCtrl.text = v,
          'Ojos': (String v) => ojosCtrl.text = v,
          'Nariz': (String v) => narizCtrl.text = v,
          'Boca': (String v) => bocaCtrl.text = v,
          'Oídos': (String v) => oidosCtrl.text = v,
          'Orofaringe': (String v) => orofaringeCtrl.text = v,
          'Cuello': (String v) => cuelloCtrl.text = v,
          'Tórax': (String v) => toraxCtrl.text = v,
          'Campos pulmonares': (String v) => camposPulmCtrl.text = v,
          'Ruidos cardíacos': (String v) => ruidosCardCtrl.text = v,
          'Abdomen': (String v) => abdomenCtrl.text = v,
          'Extremidades': (String v) => extremidadesCtrl.text = v,
          'Sistema neurológico': (String v) => neuroCtrl.text = v,
        };
        candidates.forEach((label, setter) {
          final val = _extractStrongField(c.notasHtml, label);
          if (val.isNotEmpty) setter(val);
        });
      }
    }

    // Fetch patient name to include in notas_html header when possible
    if (widget.pacienteId.isNotEmpty) {
      ApiService.obtenerPacientePorId(widget.pacienteId).then((map) {
        if (map != null && mounted) {
          final nombres = (map['nombres'] ?? '').toString();
          final apellidos = (map['apellidos'] ?? '').toString();
          // Rellenar nombre y apellidos
          // También intentar rellenar sexo y edad si vienen en el payload
          final sexo = (map['sexo'] ?? map['genero'] ?? '').toString();
          final fechaNac =
              (map['fecha_nacimiento'] ?? map['fechaNacimiento'] ?? '')
                  .toString();
          String edadText = '';
          try {
            if (fechaNac.isNotEmpty) {
              final dt = DateTime.parse(fechaNac);
              final now = DateTime.now();
              int years = now.year - dt.year;
              if (now.month < dt.month ||
                  (now.month == dt.month && now.day < dt.day)) years--;
              edadText = years > 0 ? years.toString() : '';
            }
          } catch (e) {}

          setState(() {
            _pacienteNombres = nombres;
            _pacienteApellidos = apellidos;
            if (sexo.isNotEmpty) sexoCtrl.text = sexo.toUpperCase();
            if (edadText.isNotEmpty) edadCtrl.text = edadText;
          });
        }
      });
    }
  }

  String _pacienteNombres = '';
  String _pacienteApellidos = '';

  String _stripHtml(String html) {
    if (html.isEmpty) return '';
    var s = html.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    s = s.replaceAll(RegExp(r'<[^>]+>'), '');
    s = s.replaceAll(RegExp(r'\n\s*\n'), '\n\n');
    return s.trim();
  }

  String _extractTagContent(String html, String tag) {
    try {
      final re = RegExp(
          '<${RegExp.escape(tag)}[^>]*>([\s\S]*?)<\/${RegExp.escape(tag)}>',
          caseSensitive: false);
      final m = re.firstMatch(html);
      if (m != null) return _stripHtml(m.group(1) ?? '');
    } catch (e) {}
    return '';
  }

  String _extractStrongField(String html, String label) {
    try {
      final esc = RegExp.escape(label);
      final re = RegExp(
          '<p[^>]*>\s*<strong>\s*${esc}\s*:?\s*<\\/strong>\s*(.*?)<\\/p>',
          caseSensitive: false);
      final m = re.firstMatch(html);
      if (m != null) return _stripHtml(m.group(1) ?? '');
    } catch (e) {}
    // fallback: search for '<strong>Label:</strong>' pattern
    try {
      final esc = RegExp.escape(label);
      final re2 = RegExp(
          '<strong>\s*${esc}\s*:?\s*<\\/strong>\s*(.*?)<\\/p>',
          caseSensitive: false);
      final m2 = re2.firstMatch(html);
      if (m2 != null) return _stripHtml(m2.group(1) ?? '');
    } catch (e) {}
    return '';
  }

  String _extractAfterHeading(String html, String heading) {
    try {
      final esc = RegExp.escape(heading);
      // Match <h4>Heading</h4> and capture everything until next <h4> or end
      final re = RegExp(
          '<h4[^>]*>s*' + esc + r'\s*<\/h4>([\s\S]*?)(?:<h4[^>]*>|\z)',
          caseSensitive: false);
      final m = re.firstMatch(html);
      if (m != null) {
        final content = m.group(1) ?? '';
        // extract text from paragraphs inside the captured block
        final pRe = RegExp('<p[^>]*>([sS]*?)</p>', caseSensitive: false);
        final parts = <String>[];
        for (final pm in pRe.allMatches(content)) {
          parts.add(_stripHtml(pm.group(1) ?? ''));
        }
        // if no <p> found, fallback to stripping the captured block
        if (parts.isEmpty) return _stripHtml(content);
        return parts.join('\n\n');
      }
    } catch (e) {}
    return '';
  }

  Future<void> _pickImages() async {
    try {
      final imgs = await _picker.pickMultiImage(imageQuality: 80);
      if (!mounted) return;
      if (imgs.isNotEmpty) setState(() => _imagenes.addAll(imgs));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error seleccionando imágenes: $e')));
    }
  }

  String buildHtml({bool includeStructuredSections = true}) {
    final buffer = StringBuffer();
    buffer.writeln('<div>');
    // Include patient full name if available
    if ((_pacienteNombres.trim().isNotEmpty) ||
        (_pacienteApellidos.trim().isNotEmpty)) {
      final full =
          '${_pacienteNombres.trim()} ${_pacienteApellidos.trim()}'.trim();
      buffer.writeln('<h2>Paciente: $full</h2>');
    }
    buffer.writeln('<h3>Paciente</h3>');
    buffer.writeln('<p><strong>Sexo:</strong> ${sexoCtrl.text}</p>');
    buffer.writeln('<p><strong>Edad:</strong> ${edadCtrl.text}</p>');
    if (diaCtrl.text.trim().isNotEmpty) {
      final ordinal = calcularOrdinalFromInt(int.tryParse(diaCtrl.text) ?? 0);
      buffer.writeln('<p><strong>Día de estancia:</strong> $ordinal</p>');
    }
    if (areaCtrl.text.trim().isNotEmpty) {
      buffer.writeln('<p><strong>Área:</strong> ${areaCtrl.text}</p>');
    }

    buffer.writeln('<h4>Historia</h4>');
    buffer.writeln(
        '<p><strong>Personales:</strong> ${appCtrl.text.isEmpty ? 'NIEGA' : appCtrl.text}</p>');
    buffer.writeln(
        '<p><strong>Familiares:</strong> ${apfCtrl.text.isEmpty ? 'NIEGA' : apfCtrl.text}</p>');
    buffer.writeln(
        '<p><strong>Alergias:</strong> ${alergiasCtrl.text.isEmpty ? 'NIEGA' : alergiasCtrl.text}</p>');

    if (tiempoCtrl.text.trim().isNotEmpty ||
        evolucionCtrl.text.trim().isNotEmpty) {
      buffer.writeln(
          '<h4>Evolución</h4><p>${tiempoCtrl.text} ${evolucionCtrl.text}</p>');
    }

    if (svTaCtrl.text.isNotEmpty || svFcCtrl.text.isNotEmpty) {
      buffer.writeln('<h4>Signos vitales</h4>');
      final sv = <String>[];
      if (svTaCtrl.text.isNotEmpty) sv.add('TA: ${svTaCtrl.text}');
      if (svFcCtrl.text.isNotEmpty) sv.add('FC: ${svFcCtrl.text}');
      if (svFrCtrl.text.isNotEmpty) sv.add('FR: ${svFrCtrl.text}');
      if (svTempCtrl.text.isNotEmpty) sv.add('Temp: ${svTempCtrl.text}');
      if (svSatCtrl.text.isNotEmpty) sv.add('SatO2: ${svSatCtrl.text}');
      if (svGliCtrl.text.isNotEmpty) sv.add('Glicemia: ${svGliCtrl.text}');
      buffer.writeln('<p>${sv.join(' - ')}</p>');
    }

    if (examenCtrl.text.trim().isNotEmpty) {
      buffer.writeln(
          '<h4>Examen físico</h4><p>${examenCtrl.text.replaceAll('\n', '<br>')}</p>');
    }
    // Detailed examen fields
    if (pielCtrl.text.trim().isNotEmpty) {
      buffer.writeln('<p><strong>Piel:</strong> ${pielCtrl.text}</p>');
    }
    if (cabezaCtrl.text.trim().isNotEmpty) {
      buffer.writeln('<p><strong>Cabeza:</strong> ${cabezaCtrl.text}</p>');
    }
    if (ojosCtrl.text.trim().isNotEmpty) {
      buffer.writeln('<p><strong>Ojos:</strong> ${ojosCtrl.text}</p>');
    }
    if (narizCtrl.text.trim().isNotEmpty) {
      buffer.writeln('<p><strong>Nariz:</strong> ${narizCtrl.text}</p>');
    }
    if (bocaCtrl.text.trim().isNotEmpty) {
      buffer.writeln('<p><strong>Boca:</strong> ${bocaCtrl.text}</p>');
    }
    if (oidosCtrl.text.trim().isNotEmpty) {
      buffer.writeln('<p><strong>Oídos:</strong> ${oidosCtrl.text}</p>');
    }
    if (orofaringeCtrl.text.trim().isNotEmpty) {
      buffer.writeln(
          '<p><strong>Orofaringe:</strong> ${orofaringeCtrl.text}</p>');
    }
    if (cuelloCtrl.text.trim().isNotEmpty) {
      buffer.writeln('<p><strong>Cuello:</strong> ${cuelloCtrl.text}</p>');
    }
    if (toraxCtrl.text.trim().isNotEmpty) {
      buffer.writeln('<p><strong>Tórax:</strong> ${toraxCtrl.text}</p>');
    }
    if (camposPulmCtrl.text.trim().isNotEmpty) {
      buffer.writeln(
          '<p><strong>Campos pulmonares:</strong> ${camposPulmCtrl.text}</p>');
    }
    if (ruidosCardCtrl.text.trim().isNotEmpty) {
      buffer.writeln(
          '<p><strong>Ruidos cardíacos:</strong> ${ruidosCardCtrl.text}</p>');
    }
    if (abdomenCtrl.text.trim().isNotEmpty) {
      buffer.writeln('<p><strong>Abdomen:</strong> ${abdomenCtrl.text}</p>');
    }
    if (extremidadesCtrl.text.trim().isNotEmpty) {
      buffer.writeln(
          '<p><strong>Extremidades:</strong> ${extremidadesCtrl.text}</p>');
    }
    if (neuroCtrl.text.trim().isNotEmpty) {
      buffer.writeln(
          '<p><strong>Sistema neurológico:</strong> ${neuroCtrl.text}</p>');
    }
    if (labsCtrl.text.trim().isNotEmpty) {
      buffer.writeln('<h4>Pruebas</h4><pre>${labsCtrl.text}</pre>');
    }
    // Imágenes seleccionadas localmente
    if (includeStructuredSections && _imagenesGuardadas.isNotEmpty) {
      buffer.writeln('<h4>Imágenes (guardadas)</h4>');
      for (var raw in _imagenesGuardadas) {
        final uri = raw.toString();
        var display = uri;
        if (display.startsWith('/')) display = ApiService.baseUrl + display;
        buffer.writeln(
            '<p><img src="$display" style="max-width:360px;max-height:240px;"/></p>');
      }
    }
    if (includeStructuredSections && _imagenes.isNotEmpty) {
      buffer.writeln('<h4>Imágenes</h4>');
      for (var f in _imagenes) {
        final uri = Uri.file(f.path).toString();
        buffer.writeln(
            '<p><img src="$uri" style="max-width:360px;max-height:240px;"/></p>');
      }
    }
    if (analisisCtrl.text.trim().isNotEmpty) {
      buffer.writeln('<h4>Análisis clínico</h4><p>${analisisCtrl.text}</p>');
    }
    if (includeStructuredSections) {
      if (dxCtrl.text.trim().isNotEmpty) {
        buffer.writeln(
            '<h4>Diagnósticos</h4><p><strong>${dxCtrl.text}</strong></p>');
      }
      if (planCtrl.text.trim().isNotEmpty) {
        buffer.writeln('<h4>Plan de manejo</h4><p>${planCtrl.text}</p>');
      }
    }

    if (includeStructuredSections &&
        (medidasCtrl.text.trim().isNotEmpty ||
            hidratacionCtrl.text.trim().isNotEmpty ||
            medicacionCtrl.text.trim().isNotEmpty)) {
      buffer.writeln('<h4>Indicaciones</h4>');
      if (medidasCtrl.text.trim().isNotEmpty) {
        buffer.writeln(
            '<p><strong>Medidas generales:</strong> ${medidasCtrl.text}</p>');
      }
      if (hidratacionCtrl.text.trim().isNotEmpty) {
        buffer.writeln(
            '<p><strong>Hidratación / Nutrición:</strong> ${hidratacionCtrl.text}</p>');
      }
      if (medicacionCtrl.text.trim().isNotEmpty) {
        buffer.writeln(
            '<p><strong>Medicación:</strong> ${medicacionCtrl.text}</p>');
      }
    }

    buffer.writeln('</div>');
    return buffer.toString();
  }

  void autoFillDemo() {
    setState(() {
      sexoCtrl.text = 'FEMENINO';
      edadCtrl.text = '52';
      diaCtrl.text = '1';
      areaCtrl.text = 'Urgencias';

      appCtrl.text = 'HTA';
      apfCtrl.text = 'Madre con HTA';
      alergiasCtrl.text = 'Ninguna';

      tiempoCtrl.text = '48 horas';
      evolucionCtrl.text = 'Dolor abdominal progresivo';

      svTaCtrl.text = '120/80';
      svFcCtrl.text = '82';
      svFrCtrl.text = '18';
      svTempCtrl.text = '37.2';
      svSatCtrl.text = '97';
      svGliCtrl.text = '105';

      examenCtrl.text = examMacros.values.join('\n');
      labsCtrl.text = labMacros.values.join('\n\n');
      analisisCtrl.text = 'Sospecha de proceso inflamatorio';
      dxCtrl.text = 'Dolor abdominal inespecífico';
      planCtrl.text = 'Observación, analgesia, solicitar imágenes';

      // Fill detailed examen fields from macros when available
      pielCtrl.text = examMacros['PIEL'] ?? '';
      cabezaCtrl.text = examMacros['CABEZA'] ?? '';
      ojosCtrl.text = examMacros['OJOS'] ?? '';
      narizCtrl.text = examMacros['NARIZ'] ?? '';
      bocaCtrl.text = examMacros['BOCA'] ?? '';
      oidosCtrl.text = examMacros['OIDOS'] ?? '';
      orofaringeCtrl.text = examMacros['OROFARINGE'] ?? '';
      cuelloCtrl.text = examMacros['CUELLO'] ?? '';
      toraxCtrl.text = examMacros['TÓRAX'] ?? '';
      camposPulmCtrl.text = examMacros['CAMPOS_PULMONARES'] ?? '';
      ruidosCardCtrl.text = examMacros['RUIDOS_CARDIACOS'] ?? '';
      abdomenCtrl.text = examMacros['ABDOMEN'] ?? '';
      extremidadesCtrl.text = examMacros['EXTREMIDADES'] ?? '';
      neuroCtrl.text = examMacros['NEURO'] ?? '';

      medidasCtrl.text = 'Monitorizar signos; mantener NPO';
      hidratacionCtrl.text = 'Cloruro de sodio 0.9% 1000 ml IV a 64 ml/h';
      medicacionCtrl.text = 'Paracetamol 1 g IV PRN';
    });
  }

  Future<void> _guardarConsultaLocal() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() {});
    final now = DateTime.now();

    final data = <String, String>{
      'paciente_id': widget.pacienteId,
      'motivo_consulta':
          evolucionCtrl.text.isNotEmpty ? evolucionCtrl.text : dxCtrl.text,
      'peso': '0',
      'estatura': '0',
      'imc': '0',
      'presion': svTaCtrl.text,
      'frecuencia_cardiaca': svFcCtrl.text.isEmpty ? '0' : svFcCtrl.text,
      'frecuencia_respiratoria': svFrCtrl.text.isEmpty ? '0' : svFrCtrl.text,
      'temperatura': svTempCtrl.text.isEmpty ? '0' : svTempCtrl.text,
      'diagnostico': dxCtrl.text,
      'tratamiento': planCtrl.text,
      'receta': medicacionCtrl.text,
      'otros': medidasCtrl.text,
      // Detailed examen fields
      'examen_piel': pielCtrl.text,
      'examen_cabeza': cabezaCtrl.text,
      'examen_ojos': ojosCtrl.text,
      'examen_nariz': narizCtrl.text,
      'examen_boca': bocaCtrl.text,
      'examen_oidos': oidosCtrl.text,
      'examen_orofaringe': orofaringeCtrl.text,
      'examen_cuello': cuelloCtrl.text,
      'examen_torax': toraxCtrl.text,
      'examen_campos_pulm': camposPulmCtrl.text,
      'examen_ruidos_card': ruidosCardCtrl.text,
      'examen_abdomen': abdomenCtrl.text,
      'examen_extremidades': extremidadesCtrl.text,
      'examen_neuro': neuroCtrl.text,
      // Include the rich HTML: send both a cleaned version (no structured sections)
      // for storage/display and the full original HTML for backups/printing.
      'notas_html': buildHtml(includeStructuredSections: false),
      'notas_html_full': buildHtml(includeStructuredSections: true),
      'fecha': now.toIso8601String().split('T')[0],
    };

    // only upload newly picked images; saved images remain as paths on server
    final archivos = _imagenes.map((x) => x.path).toList();
    // Send existing saved images so backend can preserve them when editing
    if (_imagenesGuardadas.isNotEmpty) {
      data['imagenes'] = jsonEncode(_imagenesGuardadas);
    }
    if (_imagenesParaEliminar.isNotEmpty) {
      data['imagenes_eliminar'] = jsonEncode(_imagenesParaEliminar);
    }

    bool ok = false;
    if (widget.consulta != null) {
      // editar
      ok =
          await ApiService.editarHistorial(widget.consulta!.id, data, archivos);
    } else {
      ok = await ApiService.crearHistorial(data, archivos);
    }

    if (!mounted) return;

    if (ok) {
      messenger
          .showSnackBar(const SnackBar(content: Text('Consulta guardada')));
      final c = Consulta(
        id: now.microsecondsSinceEpoch.toString(),
        motivo: data['motivo_consulta'] ?? 'Consulta',
        peso: 0,
        estatura: 0,
        imc: 0,
        presion: data['presion'] ?? '',
        frecuenciaCardiaca:
            int.tryParse(data['frecuencia_cardiaca'] ?? '0') ?? 0,
        frecuenciaRespiratoria:
            int.tryParse(data['frecuencia_respiratoria'] ?? '0') ?? 0,
        temperatura: double.tryParse(data['temperatura'] ?? '0') ?? 0.0,
        diagnostico: data['diagnostico'] ?? '',
        tratamiento: data['tratamiento'] ?? '',
        receta: data['receta'] ?? '',
        imagenes: [..._imagenesGuardadas, ...archivos],
        notasHtml: data['notas_html'] ?? '',
        notasHtmlFull: data['notas_html_full'] ?? '',
        fecha: now,
      );
      Navigator.of(context).pop(c);
    } else {
      final err = ApiService.lastErrorBody;
      final msg = (err == null || err.isEmpty)
          ? 'Error al guardar la consulta'
          : 'Error al guardar: ' + (err.length > 300 ? err.substring(0, 300) + '…' : err);
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  void openPreview() {
    final html = buildHtml();
    Navigator.of(context)
        .pushNamed('/clinica_preview', arguments: {'html': html});
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final localTheme = baseTheme.copyWith(
      inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
        labelStyle: baseTheme.textTheme.bodyMedium?.copyWith(
          color: baseTheme.colorScheme.onSurfaceVariant,
        ),
        hintStyle: baseTheme.textTheme.bodyMedium?.copyWith(
          color: baseTheme.colorScheme.onSurfaceVariant,
        ),
        filled: true,
        fillColor: baseTheme.colorScheme.surface.withOpacity(0.02),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: baseTheme.colorScheme.onSurface.withOpacity(0.08)),
        ),
      ),
      textTheme: baseTheme.textTheme.apply(bodyColor: baseTheme.colorScheme.onSurface, displayColor: baseTheme.colorScheme.onSurface),
    );

    return DefaultTabController(
      length: 6,
      child: Theme(
        data: localTheme,
        child: Scaffold(
        appBar: AppBar(
          title: const Text('Consulta'),
          actions: [
            IconButton(
                onPressed: autoFillDemo, icon: const Icon(Icons.auto_fix_high))
          ],
          bottom: const TabBar(isScrollable: true, tabs: [
            Tab(text: 'Paciente'),
            Tab(text: 'Historia'),
            Tab(text: 'Signos'),
            Tab(text: 'Examen'),
            Tab(text: 'Labs/Dx'),
            Tab(text: 'Indicaciones'),
          ]),
        ),
        body: TabBarView(children: [
          // Paciente
          SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: sexoCtrl.text,
                    items: const [
                      DropdownMenuItem(
                          value: 'FEMENINO', child: Text('Femenino')),
                      DropdownMenuItem(
                          value: 'MASCULINO', child: Text('Masculino')),
                    ],
                    onChanged: (v) => setState(() => sexoCtrl.text = v ?? ''),
                    decoration: const InputDecoration(labelText: 'Sexo'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                    child: TextFormField(
                        controller: edadCtrl,
                        decoration: const InputDecoration(labelText: 'Edad'),
                        keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: TextFormField(
                        controller: diaCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Día estancia'))),
                const SizedBox(width: 8),
                Expanded(
                    child: TextFormField(
                        controller: areaCtrl,
                        decoration: const InputDecoration(labelText: 'Área'))),
              ])
            ]),
          ),

          // Historia
          SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Historia',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextFormField(
                  controller: appCtrl,
                  maxLines: 2,
                  decoration:
                      const InputDecoration(labelText: 'Personales (APP)')),
              const SizedBox(height: 6),
              TextFormField(
                  controller: apfCtrl,
                  maxLines: 2,
                  decoration:
                      const InputDecoration(labelText: 'Familiares (APF)')),
              const SizedBox(height: 6),
              TextFormField(
                  controller: alergiasCtrl,
                  maxLines: 1,
                  decoration: const InputDecoration(labelText: 'Alergias')),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: TextFormField(
                        controller: tiempoCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Tiempo de evolución'))),
                const SizedBox(width: 8),
                Expanded(
                    child: TextFormField(
                        controller: evolucionCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Cuadro clínico'))),
              ])
            ]),
          ),

          // Signos
          SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Signos Vitales',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: TextFormField(
                        controller: svTaCtrl,
                        decoration:
                            const InputDecoration(labelText: 'TA (mmHg)'))),
                const SizedBox(width: 8),
                Expanded(
                    child: TextFormField(
                        controller: svFcCtrl,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'FC (lpm)'))),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: TextFormField(
                        controller: svFrCtrl,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'FR (rpm)'))),
                const SizedBox(width: 8),
                Expanded(
                    child: TextFormField(
                        controller: svTempCtrl,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Temp (°C)'))),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: TextFormField(
                        controller: svSatCtrl,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'SatO2 (%)'))),
                const SizedBox(width: 8),
                Expanded(
                    child: TextFormField(
                        controller: svGliCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Glicemia (mg/dL)'))),
              ])
            ]),
          ),

          // Examen
          SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Examen físico',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Row(children: [
                  TextButton(
                      onPressed: () {
                        setState(() {
                          examenCtrl.text = examMacros.values.join('\n');
                          // fill detailed fields from macros if available
                          pielCtrl.text = examMacros['PIEL'] ?? '';
                          cabezaCtrl.text = examMacros['CABEZA'] ?? '';
                          ojosCtrl.text = examMacros['OJOS'] ?? '';
                          narizCtrl.text = examMacros['NARIZ'] ?? '';
                          bocaCtrl.text = examMacros['BOCA'] ?? '';
                          oidosCtrl.text = examMacros['OIDOS'] ?? '';
                          orofaringeCtrl.text = examMacros['OROFARINGE'] ?? '';
                          cuelloCtrl.text = examMacros['CUELLO'] ?? '';
                          toraxCtrl.text = examMacros['TÓRAX'] ??
                              examMacros['TÓRAX'] ??
                              examMacros['TÓRAX'] ??
                              '';
                          camposPulmCtrl.text =
                              examMacros['CAMPOS_PULMONARES'] ??
                                  examMacros['CAMPOS_PULM'] ??
                                  examMacros['CAMPOS_PULM'] ??
                                  '';
                          ruidosCardCtrl.text =
                              examMacros['RUIDOS_CARDIACOS'] ??
                                  examMacros['RUIDOS_CARD'] ??
                                  '';
                          abdomenCtrl.text = examMacros['ABDOMEN'] ?? '';
                          extremidadesCtrl.text =
                              examMacros['EXTREMIDADES'] ?? '';
                          neuroCtrl.text = examMacros['NEURO'] ?? '';
                        });
                      },
                      child: const Text('Todo Normal'))
                ]),
              ]),
              MacroBar(
                  macros: examMacros,
                  onInsert: (t) => insertTextAtSelection(examenCtrl, t)),
              const SizedBox(height: 8),
              TextFormField(
                  controller: examenCtrl,
                  maxLines: null,
                  minLines: 3,
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(
                      labelText: 'Hallazgos (texto libre)')),
              const SizedBox(height: 10),
              // Detailed fields
              TextFormField(
                  controller: pielCtrl,
                  decoration: const InputDecoration(labelText: 'Piel')),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: TextFormField(
                        controller: cabezaCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Cabeza'))),
                const SizedBox(width: 8),
                Expanded(
                    child: TextFormField(
                        controller: ojosCtrl,
                        decoration: const InputDecoration(labelText: 'Ojos'))),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: TextFormField(
                        controller: narizCtrl,
                        decoration: const InputDecoration(labelText: 'Nariz'))),
                const SizedBox(width: 8),
                Expanded(
                    child: TextFormField(
                        controller: bocaCtrl,
                        decoration: const InputDecoration(labelText: 'Boca'))),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: TextFormField(
                        controller: oidosCtrl,
                        decoration: const InputDecoration(labelText: 'Oídos'))),
                const SizedBox(width: 8),
                Expanded(
                    child: TextFormField(
                        controller: orofaringeCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Orofaringe'))),
              ]),
              const SizedBox(height: 8),
              TextFormField(
                  controller: cuelloCtrl,
                  decoration: const InputDecoration(labelText: 'Cuello')),
              const SizedBox(height: 8),
              TextFormField(
                  controller: toraxCtrl,
                  decoration: const InputDecoration(labelText: 'Tórax')),
              const SizedBox(height: 8),
              TextFormField(
                  controller: camposPulmCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Campos pulmonares')),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: TextFormField(
                        controller: ruidosCardCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Ruidos cardíacos'))),
                const SizedBox(width: 8),
                Expanded(
                    child: TextFormField(
                        controller: abdomenCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Abdomen'))),
              ]),
              const SizedBox(height: 8),
              TextFormField(
                  controller: extremidadesCtrl,
                  decoration: const InputDecoration(labelText: 'Extremidades')),
              const SizedBox(height: 8),
              TextFormField(
                  controller: neuroCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Sistema neurológico')),
            ]),
          ),

          // Labs/Dx
          SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Labs / Dx / Plan',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              MacroBar(
                  macros: labMacros,
                  onInsert: (t) => insertTextAtSelection(labsCtrl, t)),
              const SizedBox(height: 8),
              TextFormField(
                  controller: labsCtrl,
                  maxLines: null,
                  minLines: 3,
                  keyboardType: TextInputType.multiline,
                  decoration:
                      const InputDecoration(labelText: 'Laboratorio / Imagen')),
              const SizedBox(height: 8),
              Row(children: [
                ElevatedButton.icon(
                  onPressed: _pickImages,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Seleccionar imágenes'),
                ),
                const SizedBox(width: 12),
                if (_imagenesGuardadas.isNotEmpty)
                  Text('${_imagenesGuardadas.length} imágenes guardadas'),
                if (_imagenes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Text('${_imagenes.length} imágenes seleccionadas'),
                  )
              ]),
              const SizedBox(height: 8),
              // Show already saved images with option to mark for deletion
              if (_imagenesGuardadas.isNotEmpty)
                SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _imagenesGuardadas.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (ctx, i) {
                      final raw = _imagenesGuardadas[i];
                      String display = raw;
                      if (display.startsWith('/')) {
                        display = ApiService.baseUrl + display;
                      }
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: display.startsWith('http')
                                ? Image.network(display,
                                    width: 120, height: 100, fit: BoxFit.cover)
                                : Image.file(File(raw),
                                    width: 120, height: 100, fit: BoxFit.cover),
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: GestureDetector(
                              onTap: () {
                                // mark for deletion
                                setState(() {
                                  _imagenesGuardadas.removeAt(i);
                                  _imagenesParaEliminar.add(raw);
                                });
                              },
                              child: Container(
                                color: Colors.black54,
                                padding: const EdgeInsets.all(4),
                                child: const Icon(Icons.delete_outline,
                                    color: Colors.redAccent, size: 18),
                              ),
                            ),
                          )
                        ],
                      );
                    },
                  ),
                ),
              if (_imagenes.isNotEmpty)
                SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _imagenes.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (ctx, i) {
                      final f = _imagenes[i];
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(File(f.path),
                                width: 120, height: 100, fit: BoxFit.cover),
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _imagenes.removeAt(i)),
                              child: Container(
                                color: Colors.black54,
                                padding: const EdgeInsets.all(4),
                                child: const Icon(Icons.close,
                                    color: Colors.white, size: 16),
                              ),
                            ),
                          )
                        ],
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
              TextFormField(
                  controller: analisisCtrl,
                  maxLines: 2,
                  decoration:
                      const InputDecoration(labelText: 'Análisis clínico')),
              const SizedBox(height: 8),
              TextFormField(
                  controller: dxCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Diagnósticos presuntivos')),
              const SizedBox(height: 8),
              TextFormField(
                  controller: planCtrl,
                  maxLines: null,
                  minLines: 2,
                  decoration:
                      const InputDecoration(labelText: 'Plan de manejo')),
            ]),
          ),

          // Indicaciones
          SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Indicaciones',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Wrap(spacing: 8, children: [
                  TextButton(
                      onPressed: () {
                        setState(() {
                          medidasCtrl.text =
                              'MONITORIZACIÓN CONTINUA. CONTROL DE SIGNOS VITALES. DIETA NPO.';
                          hidratacionCtrl.text =
                              'CLORURO DE SODIO 0.9% 1000 ML PASAR IV 64 ML/HORA';
                          medicacionCtrl.text =
                              'OMEPRAZOL 40MG IV CADA 24 HORAS. PARACETAMOL 1 GR PRN.';
                        });
                      },
                      child: const Text('Estándar')),
                  TextButton(
                      onPressed: () {
                        // Copy combined Indicaciones to clipboard
                        final parts = <String>[];
                        if (medidasCtrl.text.trim().isNotEmpty) {
                          parts.add(
                              'MEDIDAS GENERALES:\n${medidasCtrl.text.trim()}');
                        }
                        if (hidratacionCtrl.text.trim().isNotEmpty) {
                          parts.add(
                              'HIDRATACIÓN / NUTRICIÓN:\n${hidratacionCtrl.text.trim()}');
                        }
                        if (medicacionCtrl.text.trim().isNotEmpty) {
                          parts.add(
                              'MEDICACIÓN:\n${medicacionCtrl.text.trim()}');
                        }
                        final combined = parts.join('\n\n');
                        Clipboard.setData(ClipboardData(text: combined));
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Indicaciones copiadas al portapapeles')));
                      },
                      child: const Text('Copiar Indicaciones')),
                ]),
              ]),
              const SizedBox(height: 8),
              // Terapias quick buttons (compact, insert into medicacion or hidratacion)
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: indiMacros.keys.map((k) {
                  final labelMap = {
                    'HIDRA_1000': 'Hidratación 1000ml',
                    'K_REP': 'Reposición K+',
                    'DOLOR': 'Bomba Dolor',
                    'ANTICONV': 'Anticonvulsivante',
                    'SEDACION': 'Sedación',
                    'ANALGESIA': 'Analgesia',
                    'VASO': 'Vasopresor'
                  };
                  final display = labelMap[k] ?? k;
                  final macroText = indiMacros[k] ?? '';
                  return OutlinedButton.icon(
                    icon: const Icon(Icons.flash_on,
                        size: 16, color: Color(0xFFF59F00)),
                    label: Text(display, style: const TextStyle(fontSize: 13)),
                    onPressed: () {
                      // HIDRA_1000 goes to hidratacion, others to medicacion
                      if (k == 'HIDRA_1000') {
                        insertTextAtSelection(hidratacionCtrl, macroText);
                      } else {
                        insertTextAtSelection(medicacionCtrl, macroText);
                      }
                      // ensure UI updates
                      setState(() {});
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              // Medidas generales with clear button
              Row(children: [
                Expanded(
                  child: TextFormField(
                      controller: medidasCtrl,
                      maxLines: null,
                      minLines: 3,
                      decoration: const InputDecoration(
                          labelText: 'Medidas generales')),
                ),
                IconButton(
                  icon:
                      const Icon(Icons.delete_outline, color: Colors.redAccent),
                  tooltip: 'Limpiar medidas',
                  onPressed: () => setState(() => medidasCtrl.clear()),
                )
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextFormField(
                      controller: hidratacionCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                          labelText: 'Hidratación / Nutrición')),
                ),
                IconButton(
                  icon:
                      const Icon(Icons.delete_outline, color: Colors.redAccent),
                  tooltip: 'Limpiar hidratación',
                  onPressed: () => setState(() => hidratacionCtrl.clear()),
                )
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextFormField(
                      controller: medicacionCtrl,
                      maxLines: null,
                      minLines: 3,
                      decoration:
                          const InputDecoration(labelText: 'Medicación')),
                ),
                IconButton(
                  icon:
                      const Icon(Icons.delete_outline, color: Colors.redAccent),
                  tooltip: 'Limpiar medicación',
                  onPressed: () => setState(() => medicacionCtrl.clear()),
                )
              ]),
            ]),
          ),
        ]),
        floatingActionButton: Row(mainAxisSize: MainAxisSize.min, children: [
          FloatingActionButton.extended(
              heroTag: 'preview_fab',
              onPressed: () => openPreview(),
              icon: const Icon(Icons.remove_red_eye),
              label: const Text('Vista previa')),
          const SizedBox(width: 8),
          FloatingActionButton.extended(
              heroTag: 'save_fab',
              onPressed: _guardarConsultaLocal,
              icon: const Icon(Icons.save),
              label: const Text('Guardar')),
        ]),
      ),
    );
  }
}
