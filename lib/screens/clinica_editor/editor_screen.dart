import 'package:flutter/material.dart';
import '../../services/editor_macros.dart';
import '../../utils/editor_utils.dart';
import '../../widgets/clinica_editor/macro_bar.dart';

import '../../models/consulta.dart';

class EditorScreen extends StatefulWidget {
  final String pacienteId;
  const EditorScreen({super.key, required this.pacienteId});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  // Basic fields (expand as needed)
  final sexoCtrl = TextEditingController(text: 'FEMENINO');
  final edadCtrl = TextEditingController();
  final diaCtrl = TextEditingController();
  final areaCtrl = TextEditingController();

  final appCtrl = TextEditingController();
  final apfCtrl = TextEditingController();
  final alergiasCtrl = TextEditingController();

  final tiempoCtrl = TextEditingController();
  final evolucionCtrl = TextEditingController();

  final examenCtrl = TextEditingController();
  final labsCtrl = TextEditingController();
  final analisisCtrl = TextEditingController();
  final dxCtrl = TextEditingController();
  final planCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

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
    labsCtrl.dispose();
    analisisCtrl.dispose();
    dxCtrl.dispose();
    planCtrl.dispose();
    super.dispose();
  }

  String buildHtml({bool includeStructuredSections = true}) {
    // Build a simple HTML representation of the form contents
    final buffer = StringBuffer();
    buffer.writeln('<div>');
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
      buffer.writeln('<h4>Evolución</h4>');
      buffer.writeln('<p>${tiempoCtrl.text} ${evolucionCtrl.text}</p>');
    }

    if (examenCtrl.text.trim().isNotEmpty) {
      buffer.writeln('<h4>Examen físico</h4>');
      buffer.writeln('<p>${examenCtrl.text.replaceAll('\n', '<br>')}</p>');
    }

    if (labsCtrl.text.trim().isNotEmpty) {
      buffer.writeln('<h4>Pruebas</h4>');
      buffer.writeln('<pre>${labsCtrl.text}</pre>');
    }

    if (analisisCtrl.text.trim().isNotEmpty) {
      buffer.writeln('<h4>Análisis clínico</h4>');
      buffer.writeln('<p>${analisisCtrl.text}</p>');
    }

    if (includeStructuredSections) {
      if (dxCtrl.text.trim().isNotEmpty) {
        buffer.writeln('<h4>Diagnósticos</h4>');
        buffer.writeln('<p><strong>${dxCtrl.text}</strong></p>');
      }

      if (planCtrl.text.trim().isNotEmpty) {
        buffer.writeln('<h4>Plan de manejo</h4>');
        buffer.writeln('<p>${planCtrl.text}</p>');
      }
    }

    buffer.writeln('</div>');
    return buffer.toString();
  }

  void openPreview() {
    final html = buildHtml();
    Navigator.of(context)
        .pushNamed('/clinica_preview', arguments: {'html': html});
  }

  Future<void> _guardarConsulta() async {
    final now = DateTime.now();
    final consulta = Consulta(
      id: now.microsecondsSinceEpoch.toString(),
      motivo: evolucionCtrl.text.isNotEmpty ? evolucionCtrl.text : 'Consulta',
      peso: 0,
      estatura: 0,
      imc: 0,
      presion: '',
      frecuenciaCardiaca: 0,
      frecuenciaRespiratoria: 0,
      temperatura: 0,
      diagnostico: dxCtrl.text,
      tratamiento: planCtrl.text,
      receta: '',
      imagenes: const [],
      fecha: now,
    );

    Navigator.of(context).pop(consulta);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editor Clínico')),
      body: LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        final editor = SingleChildScrollView(
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
                    onChanged: (v) => setState(() => sexoCtrl.text = v ?? ''),
                    decoration: const InputDecoration(labelText: 'Sexo'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: edadCtrl,
                    decoration: const InputDecoration(labelText: 'Edad'),
                    keyboardType: TextInputType.number,
                  ),
                ),
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
              ]),
              const SizedBox(height: 12),
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
              ]),
              const SizedBox(height: 12),
              const Text('Examen físico',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              MacroBar(
                  macros: examMacros,
                  onInsert: (t) => insertTextAtSelection(examenCtrl, t)),
              TextFormField(
                  controller: examenCtrl,
                  maxLines: null,
                  minLines: 3,
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(labelText: 'Hallazgos')),
              const SizedBox(height: 12),
              const Text('Labs / Dx / Plan',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              MacroBar(
                  macros: labMacros,
                  onInsert: (t) => insertTextAtSelection(labsCtrl, t)),
              TextFormField(
                  controller: labsCtrl,
                  maxLines: null,
                  minLines: 3,
                  keyboardType: TextInputType.multiline,
                  decoration:
                      const InputDecoration(labelText: 'Laboratorio / Imagen')),
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
              MacroBar(
                  macros: indiMacros,
                  onInsert: (t) => insertTextAtSelection(planCtrl, t)),
              TextFormField(
                  controller: planCtrl,
                  maxLines: null,
                  minLines: 2,
                  decoration:
                      const InputDecoration(labelText: 'Plan de manejo')),
              const SizedBox(height: 16),
              Row(children: [
                ElevatedButton.icon(
                    onPressed: openPreview,
                    icon: const Icon(Icons.remove_red_eye),
                    label: const Text('Vista previa')),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                    onPressed: _guardarConsulta,
                    icon: const Icon(Icons.save),
                    label: const Text('Guardar')),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                    onPressed: () => setState(() {
                          appCtrl.clear();
                          apfCtrl.clear();
                          alergiasCtrl.clear();
                          examenCtrl.clear();
                          labsCtrl.clear();
                          dxCtrl.clear();
                          planCtrl.clear();
                        }),
                    icon: const Icon(Icons.delete),
                    label: const Text('Limpiar')),
              ])
            ],
          ),
        );

        if (isWide) {
          // side-by-side preview
          return Row(children: [
            Expanded(flex: 1, child: editor),
            Expanded(
                flex: 1,
                child: Navigator(
                    onGenerateRoute: (settings) => MaterialPageRoute(
                        builder: (_) => const SizedBox.shrink()))),
          ]);
        }

        return editor;
      }),
    );
  }
}
