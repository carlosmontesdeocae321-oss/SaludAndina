import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/consulta.dart';
import '../../services/api_services.dart';
import 'package:flutter_html/flutter_html.dart';

class ConsultaDetalleScreen extends StatelessWidget {
  final Consulta consulta;
  const ConsultaDetalleScreen({super.key, required this.consulta});

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF1BD1C2);
    const overlayColor = Color(0xFF101D32);
    final baseTheme = Theme.of(context);

    final themed = baseTheme.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: baseTheme.colorScheme.copyWith(
        primary: accentColor,
        secondary: accentColor,
        surface: overlayColor,
        surfaceContainerHigh: overlayColor.withOpacity(0.88),
        onPrimary: const Color(0xFF062026),
        onSurface: Colors.white,
        onSurfaceVariant: Colors.white70,
      ),
      textTheme: baseTheme.textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      iconTheme: const IconThemeData(color: Colors.white70),
      appBarTheme: baseTheme.appBarTheme.copyWith(
        backgroundColor: const Color(0xFF0B1626).withOpacity(0.95),
        elevation: 0,
        titleTextStyle: baseTheme.textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: Colors.white70),
      ),
      dividerColor: Colors.white24,
      dialogTheme: baseTheme.dialogTheme.copyWith(
        backgroundColor: overlayColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: baseTheme.textTheme.titleMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: baseTheme.textTheme.bodyMedium?.copyWith(
          color: Colors.white70,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: const Color(0xFF062026),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF02060F), Color(0xFF0B1F36)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -110,
            right: -80,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentColor.withOpacity(0.18), Colors.transparent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Theme(
            data: themed,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(title: const Text('Detalle de consulta')),
              body: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 32),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: overlayColor.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: Colors.white.withOpacity(0.04)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 28,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 24, 22, 26),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          consulta.motivo.isNotEmpty
                              ? consulta.motivo
                              : 'Consulta sin motivo registrado',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (consulta.pacienteFullName.isNotEmpty)
                          Text(
                            consulta.pacienteFullName,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        const SizedBox(height: 10),
                        Text(
                          'Fecha: ${consulta.fecha.toLocal().toString().split(' ')[0]} · Hora: ${consulta.fecha.toLocal().toString().split(' ')[1].split('.').first}',
                          style: const TextStyle(
                            color: Colors.white60,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Mostrar sección de examen sólo si hay métricas o campos detallados
                        if (_hasExamData(consulta)) ...[
                          _buildSectionTitle(context, 'Examen físico'),
                          const SizedBox(height: 10),
                          Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            if (consulta.peso > 0)
                              _buildMetricChip('Peso: ${consulta.peso} kg'),
                            if (consulta.estatura > 0)
                              _buildMetricChip(
                                  'Estatura: ${consulta.estatura} m'),
                            if (consulta.imc > 0)
                              _buildMetricChip('IMC: ${consulta.imc}'),
                            if (consulta.presion.isNotEmpty)
                              _buildMetricChip(
                                  'Presión arterial: ${consulta.presion}'),
                            if (consulta.frecuenciaCardiaca > 0)
                              _buildMetricChip(
                                  'Frecuencia cardiaca: ${consulta.frecuenciaCardiaca}'),
                            if (consulta.frecuenciaRespiratoria > 0)
                              _buildMetricChip(
                                  'Frecuencia respiratoria: ${consulta.frecuenciaRespiratoria}'),
                            if (consulta.temperatura > 0)
                              _buildMetricChip(
                                  'Temperatura: ${consulta.temperatura}°C'),
                          ],
                          ),
                        ],
                        const SizedBox(height: 20),
                        _buildDetailBlock(context,
                          title: 'Diagnóstico',
                          value: consulta.diagnostico,
                        ),
                        _buildDetailBlock(context,
                          title: 'Tratamiento',
                          value: consulta.tratamiento,
                        ),
                        _buildDetailBlock(context,
                          title: 'Receta',
                          value: consulta.receta,
                        ),
                        if (consulta.notasHtml.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _buildSectionTitle(context, 'Notas detalladas'),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white10),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Html(
                              data: consulta.notasHtml,
                              style: {
                                "body": Style(
                                  color: Colors.white70,
                                  fontSize: FontSize(14.0),
                                  lineHeight: LineHeight.number(1.4),
                                ),
                              },
                            ),
                          ),
                        ],
                        if (consulta.imagenes.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _buildSectionTitle(context, 'Imágenes adjuntas'),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 140,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemBuilder: (ctx, i) {
                                final rawUrl = consulta.imagenes[i];
                                String displayUrl = rawUrl;
                                if (rawUrl.startsWith('/')) {
                                  displayUrl = ApiService.baseUrl + rawUrl;
                                }
                                if (displayUrl.startsWith('http')) {
                                  return GestureDetector(
                                    onTap: () =>
                                        _openImage(context, displayUrl),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: Image.network(
                                        displayUrl,
                                        width: 170,
                                        height: 140,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  );
                                }
                                return GestureDetector(
                                  onTap: () => _openImage(context, rawUrl),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Image.file(
                                      File(rawUrl),
                                      width: 170,
                                      height: 140,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                );
                              },
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 12),
                              itemCount: consulta.imagenes.length,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _hasExamData(Consulta c) {
    if (c.peso > 0 || c.estatura > 0 || c.imc > 0) return true;
    if (c.presion.isNotEmpty || c.frecuenciaCardiaca > 0 || c.frecuenciaRespiratoria > 0 || c.temperatura > 0) return true;
    final examFields = [
      c.examenPiel,
      c.examenCabeza,
      c.examenOjos,
      c.examenNariz,
      c.examenBoca,
      c.examenOidos,
      c.examenOrofaringe,
      c.examenCuello,
      c.examenTorax,
      c.examenCamposPulm,
      c.examenRuidosCard,
      c.examenAbdomen,
      c.examenExtremidades,
      c.examenNeuro,
    ];
    for (final s in examFields) {
      if (s.trim().isNotEmpty) return true;
    }
    if (c.notasHtml.isNotEmpty && c.notasHtml.toLowerCase().contains('examen')) return true;
    return false;
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final accent = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 84,
          height: 4,
          decoration: BoxDecoration(
            color: accent.withOpacity(0.18),
            borderRadius: BorderRadius.circular(3),
          ),
        )
      ],
    );
  }

  Widget _buildMetricChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 13,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildDetailBlock(BuildContext context, {required String title, required String value}) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(context, title),
          const SizedBox(height: 8),
          Text(
            trimmed,
            style: const TextStyle(
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _openImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black.withOpacity(0.9),
        insetPadding: const EdgeInsets.all(12),
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: InteractiveViewer(
            panEnabled: true,
            minScale: 0.5,
            maxScale: 4.0,
            child: url.startsWith('http')
                ? Image.network(url)
                : Image.file(File(url)),
          ),
        ),
      ),
    );
  }
}
