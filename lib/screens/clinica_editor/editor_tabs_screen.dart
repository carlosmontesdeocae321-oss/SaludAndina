import 'package:flutter/material.dart';
import '../../services/editor_macros.dart';
import '../../utils/editor_utils.dart';
import '../../widgets/clinica_editor/macro_bar.dart';
import '../../models/consulta.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../services/api_services.dart';
import '../../services/local_db.dart';
import '../../services/connectivity_service.dart';
import '../../services/sync_service.dart';
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

  String _pacienteNombres = '';
  String _pacienteApellidos = '';

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
      svFcCtrl.text =
          c.frecuenciaCardiaca > 0 ? c.frecuenciaCardiaca.toString() : '';
      svFrCtrl.text = c.frecuenciaRespiratoria > 0
          ? c.frecuenciaRespiratoria.toString()
          : '';
      svTempCtrl.text = c.temperatura > 0 ? c.temperatura.toString() : '';
      if (c.otros.isNotEmpty) medidasCtrl.text = c.otros;

      // Map explicit examen fields returned by backend
      pielCtrl.text = c.examenPiel;
      cabezaCtrl.text = c.examenCabeza;
      ojosCtrl.text = c.examenOjos;
      narizCtrl.text = c.examenNariz;
      bocaCtrl.text = c.examenBoca;
      oidosCtrl.text = c.examenOidos;
      orofaringeCtrl.text = c.examenOrofaringe;
      cuelloCtrl.text = c.examenCuello;
      toraxCtrl.text = c.examenTorax;
      camposPulmCtrl.text = c.examenCamposPulm;
      ruidosCardCtrl.text = c.examenRuidosCard;
      abdomenCtrl.text = c.examenAbdomen;
      extremidadesCtrl.text = c.examenExtremidades;
      neuroCtrl.text = c.examenNeuro;

      // Try to extract structured parts from notasHtml when available
      if (c.notasHtml.isNotEmpty) {
        final examenGeneral =
            _extractAfterHeading(c.notasHtml, 'Examen físico');
        examenCtrl.text =
            examenGeneral.isNotEmpty ? examenGeneral : _stripHtml(c.notasHtml);

        final pruebas = _extractTagContent(c.notasHtml, 'pre');
        if (pruebas.isNotEmpty) labsCtrl.text = pruebas;

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

        final m = _extractStrongField(c.notasHtml, 'Medidas generales');
        final h = _extractStrongField(c.notasHtml, 'Hidratación / Nutrición');
        final md = _extractStrongField(c.notasHtml, 'Medicación');
        if (m.isNotEmpty) {
          medidasCtrl.text = m;
        }
        if (h.isNotEmpty) {
          hidratacionCtrl.text = h;
        }
        if (md.isNotEmpty) {
          medicacionCtrl.text = md;
        }

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
          final sexo = (map['sexo'] ?? map['genero'] ?? '').toString();

          setState(() {
            _pacienteNombres = nombres;
            _pacienteApellidos = apellidos;
            if (sexo.isNotEmpty) sexoCtrl.text = sexo;
          });
        }
      });
    }
  }

  String _stripHtml(String s) {
    return s
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .trim();
  }

  String _extractTagContent(String html, String tag) {
    try {
      final re = RegExp(
          '<${RegExp.escape(tag)}[^>]*>([\\s\\S]*?)</${RegExp.escape(tag)}>',
          caseSensitive: false);
      final m = re.firstMatch(html);
      if (m != null) return _stripHtml(m.group(1) ?? '');
    } catch (e, st) {
      debugPrint('Error extracting <$tag> content: $e\n$st');
    }
    return '';
  }

  String _extractStrongField(String html, String label) {
    // Look for patterns like: <p> <strong>Label:</strong> value </p>
    try {
      final esc = RegExp.escape(label);
      final patterns = <RegExp>[
        RegExp(
            '<p[^>]*>\\s*<strong>\\s*$esc\\s*:?\\s*<\\/strong>\\s*(.*?)<\\/p>',
            caseSensitive: false),
        RegExp('<strong>\\s*$esc\\s*:?\\s*<\\/strong>\\s*(.*?)<\\/p>',
            caseSensitive: false),
      ];
      for (final re in patterns) {
        final m = re.firstMatch(html);
        if (m != null) return _stripHtml(m.group(1) ?? '');
      }
    } catch (e, st) {
      debugPrint('Error extracting strong field "$label": $e\n$st');
    }
    return '';
  }

  String _extractAfterHeading(String html, String heading) {
    try {
      final esc = RegExp.escape(heading);
      final re = RegExp(
          '<h4[^>]*>\\s*$esc\\s*<\\/h4>([\\s\\S]*?)(?:<h4[^>]*>|\\z)',
          caseSensitive: false);
      final m = re.firstMatch(html);
      if (m != null) {
        final content = m.group(1) ?? '';
        // collect paragraph content inside the captured block
        final pRe = RegExp('<p[^>]*>([\\s\\S]*?)<\\/p>', caseSensitive: false);
        final parts = <String>[];
        for (final pm in pRe.allMatches(content)) {
          parts.add(_stripHtml(pm.group(1) ?? ''));
        }
        return parts.isEmpty ? _stripHtml(content) : parts.join('\n\n');
      }
    } catch (e, st) {
      debugPrint('Error extracting after heading "$heading": $e\n$st');
    }
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

    // If offline, save locally and return immediately
    try {
      final online = ConnectivityService.isOnline.value;
      if (!online) {
        // If editing an existing consulta, update the local record instead
        // of creating a new one to avoid duplicates.
        String? existingLocalId = widget.consulta?.localId;
        String? existingServerId = widget.consulta?.id;
        final localId = await LocalDb.upsertConsultaLocal(data,
            localId: existingLocalId,
            serverId: existingServerId,
            attachments: archivos);
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Consulta guardada localmente (pendiente)')));
        final c = Consulta(
          id: (existingServerId != null && existingServerId.isNotEmpty)
              ? existingServerId
              : localId,
          localId: localId,
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
        if (!mounted) return;
        Navigator.of(context).pop(c);
        return;
      }

      // Online: attempt remote save. To avoid duplicates we create a local
      // consulta first and include `client_local_id` in the request so the
      // server can echo it and we can reconcile immediately.
      bool ok = false;
      String? createdLocalId;
      if (widget.consulta != null) {
        ok = await ApiService.editarHistorial(
            widget.consulta!.id, data, archivos);
      } else {
        // create local record first
        createdLocalId =
            await LocalDb.saveConsultaLocal(data, attachments: archivos);
        try {
          await LocalDb.setConsultaSyncing(createdLocalId);
        } catch (_) {}
        data['client_local_id'] = createdLocalId;
        ok = await ApiService.crearHistorial(data, archivos);
      }

      if (!mounted) return;

      if (ok) {
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Consulta guardada')));
        // Refresh remote consultas cache for this patient so they're available offline
        try {
          final raw =
              await ApiService.obtenerConsultasPacienteRaw(widget.pacienteId);
          await LocalDb.saveOrUpdateRemoteConsultasBatch(raw);
        } catch (_) {}

        // If we created a local record, attempt to mark it as synced immediately
        if (createdLocalId != null) {
          try {
            final created = ApiService.lastCreatedHistorial;
            if (created != null &&
                (created['client_local_id']?.toString() ?? '') ==
                    createdLocalId) {
              final srvId = created['id']?.toString() ?? '';
              await LocalDb.markConsultaAsSynced(
                  createdLocalId, srvId, created);
            } else {
              // Let the SyncService reconcile any remaining pending items
              await SyncService.instance.syncPending();
            }
          } catch (e) {
            debugPrint('Reconciliation error after crearHistorial: $e');
          }
        }

        final c = Consulta(
          id: createdLocalId ?? now.microsecondsSinceEpoch.toString(),
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
        return;
      }

      // Remote call failed: fallback to local save or update
      final err = ApiService.lastErrorBody;
      final msg = (err == null || err.isEmpty)
          ? 'Error al guardar la consulta (se guardará localmente)'
          : 'Error al guardar (se guardará localmente): ${err.length > 300 ? '${err.substring(0, 300)}…' : err}';
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      final localId = await LocalDb.upsertConsultaLocal(data,
          localId: widget.consulta?.localId,
          serverId: widget.consulta?.id,
          attachments: archivos);
      final hasServer =
          widget.consulta != null && widget.consulta!.id.isNotEmpty;
      final cLocal = Consulta(
        id: hasServer ? widget.consulta!.id : localId,
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
      if (!mounted) return;
      Navigator.of(context).pop(cLocal);
    } catch (e, st) {
      debugPrint('Error saving consulta: $e\n$st');
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error guardando la consulta')));
    }
  }

  void openPreview() {
    final html = buildHtml();
    Navigator.of(context)
        .pushNamed('/clinica_preview', arguments: {'html': html});
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Builder(builder: (context) {
        final mq = MediaQuery.of(context);
        final isSmall = mq.size.width < 600;
        // Create a compact dark theme for this screen aligned with the global navy+teal theme
        final localDark = ThemeData.dark().copyWith(
          colorScheme: ThemeData.dark().colorScheme.copyWith(
                primary: const Color(0xFF0B2B3A),
                onPrimary: Colors.white,
                surface: const Color(0xFF0E2A37),
                onSurface: Colors.white,
                secondary: const Color(0xFF06B6D4),
              ),
          scaffoldBackgroundColor: const Color(0xFF071620),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF0B2B3A),
            foregroundColor: Colors.white,
          ),
          tabBarTheme: const TabBarTheme(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicator: UnderlineTabIndicator(
              borderSide: BorderSide(color: Color(0xFF06B6D4), width: 2),
            ),
          ),
        );

        return Theme(
          data: localDark,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Consulta'),
              actions: [
                IconButton(
                    onPressed: autoFillDemo,
                    icon: const Icon(Icons.auto_fix_high))
              ],
              bottom: const PreferredSize(
                preferredSize: Size.fromHeight(kToolbarHeight),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(left: 0.0, bottom: 6.0),
                    child: TabBar(
                      isScrollable: true,
                      labelPadding: EdgeInsets.symmetric(horizontal: 8.0),
                      indicatorPadding: EdgeInsets.zero,
                      tabs: [
                        Tab(text: 'Paciente'),
                        Tab(text: 'Historia'),
                        Tab(text: 'Signos'),
                        Tab(text: 'Examen'),
                        Tab(text: 'Labs/Dx'),
                        Tab(text: 'Indicaciones'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: TabBarView(children: [
              // Paciente
              SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                            onChanged: (v) =>
                                setState(() => sexoCtrl.text = v ?? ''),
                            decoration:
                                const InputDecoration(labelText: 'Sexo'),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                            child: TextFormField(
                                controller: edadCtrl,
                                decoration:
                                    const InputDecoration(labelText: 'Edad'),
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Colors.white))),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                            child: TextFormField(
                                controller: diaCtrl,
                                decoration: const InputDecoration(
                                    labelText: 'Día estancia'),
                                style: const TextStyle(color: Colors.white))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: TextFormField(
                                controller: areaCtrl,
                                decoration:
                                    const InputDecoration(labelText: 'Área'),
                                style: const TextStyle(color: Colors.white))),
                      ])
                    ]),
              ),

              // Historia
              SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Historia',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextFormField(
                          controller: appCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                              labelText: 'Personales (APP)'),
                          style: const TextStyle(color: Colors.white)),
                      const SizedBox(height: 6),
                      TextFormField(
                          controller: apfCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                              labelText: 'Familiares (APF)'),
                          style: const TextStyle(color: Colors.white)),
                      const SizedBox(height: 6),
                      TextFormField(
                          controller: alergiasCtrl,
                          maxLines: 1,
                          decoration:
                              const InputDecoration(labelText: 'Alergias'),
                          style: const TextStyle(color: Colors.white)),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                            child: TextFormField(
                                controller: tiempoCtrl,
                                decoration: const InputDecoration(
                                    labelText: 'Tiempo de evolución'),
                                style: const TextStyle(color: Colors.white))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: TextFormField(
                                controller: evolucionCtrl,
                                decoration: const InputDecoration(
                                    labelText: 'Cuadro clínico'),
                                style: const TextStyle(color: Colors.white))),
                      ])
                    ]),
              ),

              // Signos
              SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Signos Vitales',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                            child: TextFormField(
                                controller: svTaCtrl,
                                decoration: const InputDecoration(
                                    labelText: 'TA (mmHg)'))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: TextFormField(
                                controller: svFcCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'FC (lpm)'))),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                            child: TextFormField(
                                controller: svFrCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'FR (rpm)'))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: TextFormField(
                                controller: svTempCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'Temp (°C)'))),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                            child: TextFormField(
                                controller: svSatCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'SatO2 (%)'),
                                style: const TextStyle(color: Colors.white))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: TextFormField(
                                controller: svGliCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'Glicemia (mg/dL)'),
                                style: const TextStyle(color: Colors.white))),
                      ])
                    ]),
              ),

              // Examen
              SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Examen físico',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Row(children: [
                              TextButton(
                                  onPressed: () {
                                    setState(() {
                                      examenCtrl.text =
                                          examMacros.values.join('\n');
                                      // fill detailed fields from macros if available
                                      pielCtrl.text = examMacros['PIEL'] ?? '';
                                      cabezaCtrl.text =
                                          examMacros['CABEZA'] ?? '';
                                      ojosCtrl.text = examMacros['OJOS'] ?? '';
                                      narizCtrl.text =
                                          examMacros['NARIZ'] ?? '';
                                      bocaCtrl.text = examMacros['BOCA'] ?? '';
                                      oidosCtrl.text =
                                          examMacros['OIDOS'] ?? '';
                                      orofaringeCtrl.text =
                                          examMacros['OROFARINGE'] ?? '';
                                      cuelloCtrl.text =
                                          examMacros['CUELLO'] ?? '';
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
                                      abdomenCtrl.text =
                                          examMacros['ABDOMEN'] ?? '';
                                      extremidadesCtrl.text =
                                          examMacros['EXTREMIDADES'] ?? '';
                                      neuroCtrl.text =
                                          examMacros['NEURO'] ?? '';
                                    });
                                  },
                                  child: const Text('Todo Normal'))
                            ]),
                          ]),
                      MacroBar(
                          macros: examMacros,
                          onInsert: (t) =>
                              insertTextAtSelection(examenCtrl, t)),
                      const SizedBox(height: 8),
                      TextFormField(
                          controller: examenCtrl,
                          maxLines: null,
                          minLines: 3,
                          keyboardType: TextInputType.multiline,
                          decoration: const InputDecoration(
                              labelText: 'Hallazgos (texto libre)'),
                          style: const TextStyle(color: Colors.white)),
                      const SizedBox(height: 10),
                      // Detailed fields
                      TextFormField(
                          controller: pielCtrl,
                          decoration: const InputDecoration(labelText: 'Piel'),
                          style: const TextStyle(color: Colors.white)),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                            child: TextFormField(
                                controller: cabezaCtrl,
                                decoration:
                                    const InputDecoration(labelText: 'Cabeza'),
                                style: const TextStyle(color: Colors.white))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: TextFormField(
                                controller: ojosCtrl,
                                decoration:
                                    const InputDecoration(labelText: 'Ojos'),
                                style: const TextStyle(color: Colors.white))),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                            child: TextFormField(
                                controller: narizCtrl,
                                decoration:
                                    const InputDecoration(labelText: 'Nariz'),
                                style: const TextStyle(color: Colors.white))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: TextFormField(
                                controller: bocaCtrl,
                                decoration:
                                    const InputDecoration(labelText: 'Boca'),
                                style: const TextStyle(color: Colors.white))),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                            child: TextFormField(
                                controller: oidosCtrl,
                                decoration:
                                    const InputDecoration(labelText: 'Oídos'),
                                style: const TextStyle(color: Colors.white))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: TextFormField(
                                controller: orofaringeCtrl,
                                decoration: const InputDecoration(
                                    labelText: 'Orofaringe'),
                                style: const TextStyle(color: Colors.white))),
                      ]),
                      const SizedBox(height: 8),
                      TextFormField(
                          controller: cuelloCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Cuello'),
                          style: const TextStyle(color: Colors.white)),
                      const SizedBox(height: 8),
                      TextFormField(
                          controller: toraxCtrl,
                          decoration: const InputDecoration(labelText: 'Tórax'),
                          style: const TextStyle(color: Colors.white)),
                      const SizedBox(height: 8),
                      TextFormField(
                          controller: camposPulmCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Campos pulmonares'),
                          style: const TextStyle(color: Colors.white)),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                            child: TextFormField(
                                controller: ruidosCardCtrl,
                                decoration: const InputDecoration(
                                    labelText: 'Ruidos cardíacos'),
                                style: const TextStyle(color: Colors.white))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: TextFormField(
                                controller: abdomenCtrl,
                                decoration:
                                    const InputDecoration(labelText: 'Abdomen'),
                                style: const TextStyle(color: Colors.white))),
                      ]),
                      const SizedBox(height: 8),
                      TextFormField(
                          controller: extremidadesCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Extremidades'),
                          style: const TextStyle(color: Colors.white)),
                      const SizedBox(height: 8),
                      TextFormField(
                          controller: neuroCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Sistema neurológico')),
                    ]),
              ),

              // Labs/Dx
              SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                          decoration: const InputDecoration(
                              labelText: 'Laboratorio / Imagen')),
                      const SizedBox(height: 8),
                      Row(children: [
                        ElevatedButton.icon(
                          onPressed: _pickImages,
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Seleccionar imágenes'),
                        ),
                        const SizedBox(width: 12),
                        if (_imagenesGuardadas.isNotEmpty)
                          Text(
                              '${_imagenesGuardadas.length} imágenes guardadas'),
                        if (_imagenes.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Text(
                                '${_imagenes.length} imágenes seleccionadas'),
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
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
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
                                            width: 120,
                                            height: 100,
                                            fit: BoxFit.cover)
                                        : Image.file(File(raw),
                                            width: 120,
                                            height: 100,
                                            fit: BoxFit.cover),
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
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (ctx, i) {
                              final f = _imagenes[i];
                              return Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(File(f.path),
                                        width: 120,
                                        height: 100,
                                        fit: BoxFit.cover),
                                  ),
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: GestureDetector(
                                      onTap: () =>
                                          setState(() => _imagenes.removeAt(i)),
                                      child: Container(
                                        color: const Color.fromARGB(
                                            214, 5, 35, 59),
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
                          decoration: const InputDecoration(
                              labelText: 'Análisis clínico'),
                          style: const TextStyle(color: Colors.white)),
                      const SizedBox(height: 8),
                      TextFormField(
                          controller: dxCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                              labelText: 'Diagnósticos presuntivos'),
                          style: const TextStyle(color: Colors.white)),
                      const SizedBox(height: 8),
                      TextFormField(
                          controller: planCtrl,
                          maxLines: null,
                          minLines: 2,
                          decoration: const InputDecoration(
                              labelText: 'Plan de manejo'),
                          style: const TextStyle(color: Colors.white)),
                    ]),
              ),

              // Indicaciones
              SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
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
                                    if (hidratacionCtrl.text
                                        .trim()
                                        .isNotEmpty) {
                                      parts.add(
                                          'HIDRATACIÓN / NUTRICIÓN:\n${hidratacionCtrl.text.trim()}');
                                    }
                                    if (medicacionCtrl.text.trim().isNotEmpty) {
                                      parts.add(
                                          'MEDICACIÓN:\n${medicacionCtrl.text.trim()}');
                                    }
                                    final combined = parts.join('\n\n');
                                    Clipboard.setData(
                                        ClipboardData(text: combined));
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
                          final cs = Theme.of(context).colorScheme;
                          final chipBg = cs.secondary;
                          const chipFg = Colors.white;
                          return TextButton.icon(
                            icon: const Icon(Icons.flash_on,
                                size: 16, color: Colors.white),
                            label: Text(display,
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600)),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              backgroundColor: chipBg,
                              foregroundColor: chipFg,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                    color: cs.secondary.withOpacity(0.24)),
                              ),
                            ),
                            onPressed: () {
                              if (k == 'HIDRA_1000') {
                                insertTextAtSelection(
                                    hidratacionCtrl, macroText);
                              } else {
                                insertTextAtSelection(
                                    medicacionCtrl, macroText);
                              }
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
                                  labelText: 'Medidas generales'),
                              style: const TextStyle(color: Colors.white)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.redAccent),
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
                                  labelText: 'Hidratación / Nutrición'),
                              style: const TextStyle(color: Colors.white)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.redAccent),
                          tooltip: 'Limpiar hidratación',
                          onPressed: () =>
                              setState(() => hidratacionCtrl.clear()),
                        )
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                          child: TextFormField(
                              controller: medicacionCtrl,
                              maxLines: null,
                              minLines: 3,
                              decoration: const InputDecoration(
                                  labelText: 'Medicación'),
                              style: const TextStyle(color: Colors.white)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.redAccent),
                          tooltip: 'Limpiar medicación',
                          onPressed: () =>
                              setState(() => medicacionCtrl.clear()),
                        )
                      ]),
                    ]),
              ),
            ]),
            floatingActionButton: Builder(builder: (ctx) {
              if (isSmall) {
                return FloatingActionButton(
                    heroTag: 'save_fab_small',
                    onPressed: () {
                      // open bottom sheet with actions
                      showModalBottomSheet(
                          context: ctx,
                          backgroundColor: const Color(0xFF0E2A37),
                          shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(12))),
                          builder: (bctx) {
                            return Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                      leading: const Icon(Icons.remove_red_eye,
                                          color: Colors.white),
                                      title: const Text('Vista previa',
                                          style:
                                              TextStyle(color: Colors.white)),
                                      onTap: () {
                                        Navigator.of(bctx).pop();
                                        openPreview();
                                      }),
                                  ListTile(
                                      leading: const Icon(Icons.save,
                                          color: Colors.white),
                                      title: const Text('Guardar',
                                          style:
                                              TextStyle(color: Colors.white)),
                                      onTap: () {
                                        Navigator.of(bctx).pop();
                                        _guardarConsultaLocal();
                                      }),
                                ],
                              ),
                            );
                          });
                    },
                    child: const Icon(Icons.save));
              }

              return Row(mainAxisSize: MainAxisSize.min, children: [
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
              ]);
            }),
          ),
        );
      }),
    );
  }
}
