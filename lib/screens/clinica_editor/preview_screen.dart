import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;

class PreviewScreen extends StatelessWidget {
  const PreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    final html = args != null && args['html'] is String
        ? args['html'] as String
        : '<p>Sin contenido</p>';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vista previa'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: html));
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copiado al portapapeles')));
            },
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () async {
              try {
                final bytes = await _buildPdfBytes(html);
                await Printing.layoutPdf(onLayout: (format) async => bytes);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error generando PDF: $e')));
              }
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Html(data: html),
      ),
    );
  }

  String _stripHtmlTags(String s) {
    return s.replaceAll(RegExp(r'<[^>]*>'), '');
  }

  Future<Uint8List> _buildPdfBytes(String html) async {
    final doc = pw.Document();

    // Simple sequential parser: handle <h3>, <h4>, <p>, <pre>, <img>
    final tokenRe = RegExp(
        r'(<h3>.*?<\/h3>|<h4>.*?<\/h4>|<pre>.*?<\/pre>|<p>.*?<\/p>|<img[^>]+src="([^"]+)"[^>]*>)',
        caseSensitive: false,
        dotAll: true);

    final matches = tokenRe.allMatches(html);
    final List<pw.Widget> content = [];

    int lastEnd = 0;
    for (final m in matches) {
      // text between tags
      if (m.start > lastEnd) {
        final between = html.substring(lastEnd, m.start).trim();
        if (between.isNotEmpty) {
          final text = _stripHtmlTags(between).trim();
          if (text.isNotEmpty) content.add(pw.Text(text));
        }
      }

      final token = m.group(0) ?? '';
      if (token.toLowerCase().startsWith('<h3>')) {
        final inner =
            token.replaceAll(RegExp(r'<\/h3>|<h3>', caseSensitive: false), '');
        content.add(pw.SizedBox(height: 6));
        content.add(pw.Text(_stripHtmlTags(inner).trim(),
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)));
      } else if (token.toLowerCase().startsWith('<h4>')) {
        final inner =
            token.replaceAll(RegExp(r'<\/h4>|<h4>', caseSensitive: false), '');
        content.add(pw.SizedBox(height: 4));
        content.add(pw.Text(_stripHtmlTags(inner).trim(),
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)));
      } else if (token.toLowerCase().startsWith('<p>')) {
        final inner =
            token.replaceAll(RegExp(r'<\/p>|<p>', caseSensitive: false), '');
        final txt = _stripHtmlTags(inner).trim();
        if (txt.isNotEmpty) content.add(pw.Text(txt));
      } else if (token.toLowerCase().startsWith('<pre>')) {
        final inner = token.replaceAll(
            RegExp(r'<\/pre>|<pre>', caseSensitive: false), '');
        final txt = inner.replaceAll('&nbsp;', ' ').trim();
        if (txt.isNotEmpty)
          content.add(pw.Container(
              padding: const pw.EdgeInsets.all(6),
              decoration: pw.BoxDecoration(color: PdfColors.grey300),
              child:
                  pw.Text(txt, style: pw.TextStyle(font: pw.Font.courier()))));
      } else {
        // img
        final src = m.group(2) ?? '';
        if (src.isNotEmpty) {
          try {
            Uint8List bytes;
            if (src.startsWith('file:')) {
              final path = Uri.parse(src).toFilePath();
              bytes = await File(path).readAsBytes();
            } else if (src.startsWith('http') || src.startsWith('https')) {
              final res = await http.get(Uri.parse(src));
              if (res.statusCode != 200) continue;
              bytes = res.bodyBytes;
            } else if (src.startsWith('/')) {
              final uri = Uri.parse(src);
              final res = await http.get(uri);
              if (res.statusCode != 200) continue;
              bytes = res.bodyBytes;
            } else {
              final file = File(src);
              if (!await file.exists()) continue;
              bytes = await file.readAsBytes();
            }

            final image = pw.MemoryImage(bytes);
            content.add(pw.SizedBox(height: 8));
            content.add(pw.Center(
                child: pw.Image(image, fit: pw.BoxFit.contain, width: 420)));
          } catch (e) {
            // ignore
          }
        }
      }

      lastEnd = m.end;
    }

    // trailing text
    if (lastEnd < html.length) {
      final tail = html.substring(lastEnd).trim();
      if (tail.isNotEmpty) {
        final text = _stripHtmlTags(tail).trim();
        if (text.isNotEmpty) content.add(pw.Text(text));
      }
    }

    doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(18),
        build: (ctx) => content));
    return doc.save();
  }
}
