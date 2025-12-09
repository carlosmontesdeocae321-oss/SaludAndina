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

  InputDecoration _dec(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFF1C2733),
      labelStyle: const TextStyle(color: Colors.white70),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFF4DA3FF), width: 1.4),
        borderRadius: BorderRadius.circular(10),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
        borderRadius: BorderRadius.circular(10),
      ),
      border: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  String buildHtml({bool includeStructuredSections = true}) {
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
    const scaffoldBg = Color(0xFF0F1720);
    const fg = Colors.white;

    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: scaffoldBg,
        canvasColor: scaffoldBg,
        primaryColor: const Color(0xFF4DA3FF),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0E1A27),
          foregroundColor: Colors.white,
          elevation: 2,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(title: const Text("Editor Clínico")),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;

            final editor = Container(
              color: scaffoldBg,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Datos del paciente",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: sexoCtrl.text,
                          dropdownColor: const Color(0xFF1E2935),
                          items: const [
                            DropdownMenuItem(
                                value: 'FEMENINO',
                                child: Text('Femenino',
                                    style: TextStyle(color: Colors.white))),
                            DropdownMenuItem(
                                value: 'MASCULINO',
                                child: Text('Masculino',
                                    style: TextStyle(color: Colors.white))),
                          ],
                          onChanged: (v) =>
                              setState(() => sexoCtrl.text = v ?? ''),
                          decoration: _dec("Sexo"),
                          style: const TextStyle(color: fg),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: edadCtrl,
                          decoration: _dec("Edad"),
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: fg),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          controller: diaCtrl,
                          decoration: _dec("Día estancia"),
                          style: const TextStyle(color: fg),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: areaCtrl,
                          decoration: _dec("Área"),
                          style: const TextStyle(color: fg),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 22),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 12),
                    const Text("Historia clínica",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    const SizedBox(height: 12),
                    TextFormField(
                        controller: appCtrl,
                        maxLines: 2,
                        decoration: _dec("Personales (APP)"),
                        style: const TextStyle(color: fg)),
                    const SizedBox(height: 12),
                    TextFormField(
                        controller: apfCtrl,
                        maxLines: 2,
                        decoration: _dec("Familiares (APF)"),
                        style: const TextStyle(color: fg)),
                    const SizedBox(height: 12),
                    TextFormField(
                        controller: alergiasCtrl,
                        maxLines: 1,
                        decoration: _dec("Alergias"),
                        style: const TextStyle(color: fg)),
                    const SizedBox(height: 22),
                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          controller: tiempoCtrl,
                          decoration: _dec("Tiempo de evolución"),
                          style: const TextStyle(color: fg),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: evolucionCtrl,
                          decoration: _dec("Cuadro clínico"),
                          style: const TextStyle(color: fg),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 22),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 12),
                    const Text("Examen físico",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    const SizedBox(height: 8),
                    MacroBar(
                        macros: examMacros,
                        onInsert: (t) => insertTextAtSelection(examenCtrl, t)),
                    TextFormField(
                        controller: examenCtrl,
                        maxLines: null,
                        minLines: 3,
                        decoration: _dec("Hallazgos"),
                        style: const TextStyle(color: fg)),
                    const SizedBox(height: 22),
                    const Text("Labs / Dx / Plan",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    const SizedBox(height: 8),
                    MacroBar(
                        macros: labMacros,
                        onInsert: (t) => insertTextAtSelection(labsCtrl, t)),
                    TextFormField(
                        controller: labsCtrl,
                        maxLines: null,
                        minLines: 3,
                        decoration: _dec("Laboratorio / Imagen"),
                        style: const TextStyle(color: fg)),
                    const SizedBox(height: 12),
                    TextFormField(
                        controller: analisisCtrl,
                        maxLines: 2,
                        decoration: _dec("Análisis clínico"),
                        style: const TextStyle(color: fg)),
                    const SizedBox(height: 12),
                    TextFormField(
                        controller: dxCtrl,
                        maxLines: 2,
                        decoration: _dec("Diagnósticos presuntivos"),
                        style: const TextStyle(color: fg)),
                    const SizedBox(height: 12),
                    MacroBar(
                        macros: indiMacros,
                        onInsert: (t) => insertTextAtSelection(planCtrl, t)),
                    TextFormField(
                        controller: planCtrl,
                        maxLines: null,
                        minLines: 2,
                        decoration: _dec("Plan de manejo"),
                        style: const TextStyle(color: fg)),
                    const SizedBox(height: 22),
                    Row(children: [
                      ElevatedButton.icon(
                        onPressed: openPreview,
                        icon: const Icon(Icons.remove_red_eye),
                        label: const Text("Vista previa"),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4DA3FF),
                            foregroundColor: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _guardarConsulta,
                        icon: const Icon(Icons.save),
                        label: const Text("Guardar"),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4DA3FF),
                            foregroundColor: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          appCtrl.clear();
                          apfCtrl.clear();
                          alergiasCtrl.clear();
                          examenCtrl.clear();
                          labsCtrl.clear();
                          dxCtrl.clear();
                          planCtrl.clear();
                        },
                        icon: const Icon(Icons.delete, color: fg),
                        label: const Text("Limpiar", style: TextStyle(color: fg)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1C2733),
                        ),
                      ),
                    ])
                  ],
                ),
              ),
            );

            if (isWide) {
              return Row(children: [
                Expanded(flex: 1, child: editor),
                const Expanded(flex: 1, child: SizedBox.shrink())
              ]);
            }

            return editor;
          },
        ),
      ),
    );
  }
}
