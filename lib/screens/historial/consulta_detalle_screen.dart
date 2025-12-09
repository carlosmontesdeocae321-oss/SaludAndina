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
    // Use full HTML when available (notasHtmlFull), otherwise fallback to notasHtml.
    final sourceHtml = (consulta.notasHtmlFull.isNotEmpty)
        ? consulta.notasHtmlFull
        : consulta.notasHtml;
    // Preprocess sourceHtml: extract img srcs and clean the HTML to avoid duplicates
    final extracted = _extractImagesAndCleanHtml(sourceHtml);
    // Keep the HTML content largely intact (we only remove image tags); further
    // sanitization that removes duplicated headings is applied but patient card
    // headings remain.
    final cleanedNotasHtml = _sanitizeNotasHtml(extracted['html'] ?? '');
    final notasImagesFromHtml = List<String>.from(extracted['images'] ?? []);
    // Merge consulta.imagenes and notasImagesFromHtml, keeping order and uniqueness
    final mergedImages = <String>[];
    final seen = <String>{};
    for (final u in [...consulta.imagenes, ...notasImagesFromHtml]) {
      var normalized = u;
      if (normalized.startsWith('/')) {
        normalized = ApiService.baseUrl + normalized;
      }
      if (!seen.contains(normalized)) {
        seen.add(normalized);
        mergedImages.add(normalized);
      }
    }
    // Extract only the first top-level <div> content if present (the editor wraps
    // the card inside a div). This ensures we render only the card inside
    // 'Notas detalladas' and not other surrounding UI elements.
    final displayedHtml = _extractFirstDivContent(cleanedNotasHtml).trim();
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
                        // If the cleaned notas detalladas exists, show ONLY that
                        if (cleanedNotasHtml.isNotEmpty) ...[
                          _buildSectionTitle(context, 'Notas detalladas'),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0B1626),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.35),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                )
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 20),
                            child: Html(
                              data: displayedHtml.isNotEmpty
                                  ? displayedHtml
                                  : cleanedNotasHtml,
                              style: {
                                "body": Style(
                                  color: Colors.white70,
                                  fontSize: FontSize(15.0),
                                  lineHeight: LineHeight.number(1.45),
                                ),
                                "h2": Style(
                                  color: Colors.white,
                                  fontSize: FontSize(20.0),
                                  fontWeight: FontWeight.w800,
                                ),
                                "h3": Style(
                                  color: Colors.white70,
                                  fontSize: FontSize(16.0),
                                  fontWeight: FontWeight.w700,
                                ),
                                "p": Style(
                                  color: Colors.white70,
                                  fontSize: FontSize(14.0),
                                ),
                                "strong": Style(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              },
                            ),
                          ),
                          if (mergedImages.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _buildSectionTitle(context, 'Imágenes adjuntas'),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 140,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemBuilder: (ctx, i) {
                                  final displayUrl = mergedImages[i];
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
                                    onTap: () =>
                                        _openImage(context, displayUrl),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: Image.file(
                                        File(displayUrl),
                                        width: 170,
                                        height: 140,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  );
                                },
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 12),
                                itemCount: mergedImages.length,
                              ),
                            ),
                          ],
                        ] else ...[
                          // Fallback: render original structured fields and original notasHtml/images
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
                          _buildDetailBlock(
                            context,
                            title: 'Diagnóstico',
                            value: consulta.diagnostico,
                          ),
                          _buildDetailBlock(
                            context,
                            title: 'Tratamiento',
                            value: consulta.tratamiento,
                          ),
                          _buildDetailBlock(
                            context,
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
                                data: _sanitizeNotasHtml(consulta.notasHtml),
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

  String _sanitizeNotasHtml(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    var html = raw;
    // Remove duplicate headings that are shown separately in the UI.
    // This is a simple heuristic: remove sections starting with common headings
    // like <h2>Diagnóstico</h2>, <h2>Tratamiento</h2>, <h2>Receta</h2> and their content.
    final patterns = [
      RegExp(r'<h\d[^>]*>\s*diagnostico\b[^<]*<\/h\d>.*?(?=(<h\d|$))',
          caseSensitive: false, dotAll: true),
      RegExp(r'<h\d[^>]*>\s*tratamiento\b[^<]*<\/h\d>.*?(?=(<h\d|$))',
          caseSensitive: false, dotAll: true),
      RegExp(r'<h\d[^>]*>\s*receta\b[^<]*<\/h\d>.*?(?=(<h\d|$))',
          caseSensitive: false, dotAll: true),
    ];
    for (final p in patterns) {
      html = html.replaceAll(p, '');
    }
    // Trim excessive whitespace/newlines
    html = html.replaceAll(RegExp(r'\n{2,}'), '\n').trim();
    return html;
  }

  /// Extracts the inner HTML of the first top-level <div> found in [html].
  /// If no <div> is present or an error occurs, returns the original [html].
  String _extractFirstDivContent(String html) {
    if (html.trim().isEmpty) return '';
    try {
      final openTagRe = RegExp(r'<div\b[^>]*>', caseSensitive: false);
      final openMatch = openTagRe.firstMatch(html);
      if (openMatch == null) return html;
      final openStart = openMatch.start;
      final openEnd = openMatch.end;

      final tagFinder = RegExp(r'<\/?div\b', caseSensitive: false);
      final matches = tagFinder.allMatches(html).toList();
      int i = 0;
      while (i < matches.length && matches[i].start < openStart) {
        i++;
      }
      if (i >= matches.length) return html;

      int depth = 0;
      for (int j = i; j < matches.length; j++) {
        final m = matches[j];
        final isClosing = (html.length >= m.start + 2 &&
            html.substring(m.start, m.start + 2) == '</');
        if (!isClosing) {
          depth++;
        } else {
          depth--;
        }
        if (depth == 0) {
          final closeTagStart = m.start;
          final closeTagEnd = html.indexOf('>', closeTagStart);
          if (closeTagEnd == -1) return html;
          final inner = html.substring(openEnd, closeTagStart);
          return inner;
        }
      }
    } catch (e, st) {
      debugPrint(
          'consulta_detalle_screen._extractFirstDivContent error: $e\n$st');
    }
    return html;
  }

  /// Extracts all <img src="..."> URLs from the provided HTML and returns
  /// a map with keys 'images' (List<String>) and 'html' (the HTML with <img> tags removed).
  Map<String, dynamic> _extractImagesAndCleanHtml(String? raw) {
    if (raw == null || raw.isEmpty) return {'images': <String>[], 'html': ''};
    var html = raw;
    final images = <String>[];
    try {
      final re = RegExp('<img[^>]*src=["\']([^"\']+)["\'][^>]*>',
          caseSensitive: false);
      html = html.replaceAllMapped(re, (m) {
        try {
          var src = m.group(1) ?? '';
          if (src.startsWith('/')) src = ApiService.baseUrl + src;
          images.add(src);
        } catch (e, st) {
          debugPrint(
              'consulta_detalle_screen._extractImagesAndCleanHtml mapping error: $e\n$st');
        }
        return ''; // remove the image tag from HTML
      });
    } catch (e, st) {
      debugPrint(
          'consulta_detalle_screen._extractImagesAndCleanHtml error: $e\n$st');
    }
    return {'images': images, 'html': html};
  }

  bool _hasExamData(Consulta c) {
    if (c.peso > 0 || c.estatura > 0 || c.imc > 0) return true;
    if (c.presion.isNotEmpty ||
        c.frecuenciaCardiaca > 0 ||
        c.frecuenciaRespiratoria > 0 ||
        c.temperatura > 0) return true;
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
    if (c.notasHtml.isNotEmpty &&
        c.notasHtml.toLowerCase().contains('examen')) {
      return true;
    }
    return false;
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final accent = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
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

  Widget _buildDetailBlock(BuildContext context,
      {required String title, required String value}) {
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
