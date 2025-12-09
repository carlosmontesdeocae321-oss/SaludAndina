import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_services.dart';
import 'package:http/http.dart' as http;

class PreviewScreen extends StatefulWidget {
  const PreviewScreen({super.key});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  String _doctorName = '';
  String _doctorLastName = '';
  String _doctorSpecialty = '';
  String _doctorPhone = '';
  // stored image url (if needed in future)
  Uint8List? _doctorImageBytes;
  String _doctorExtra = '';

  @override
  void initState() {
    super.initState();
    _loadDoctorInfo();
  }

  Future<void> _loadDoctorInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userIdRaw = prefs.getString('userId') ?? '';
      int? userId = int.tryParse(userIdRaw);

      Map<String, dynamic>? perfil;
      if (userId != null && userId > 0) {
        try {
          perfil = await ApiService.obtenerPerfilDoctorPublic(userId);
        } catch (e) {
          perfil = null;
        }
      }

      String name = prefs.getString('displayName') ?? '';
      String usuario = prefs.getString('usuario') ?? '';

      if (perfil != null) {
        final nombre =
            (perfil['nombre'] ?? perfil['usuario'] ?? '').toString().trim();
        final apellido =
            (perfil['apellido'] ?? perfil['apellidos'] ?? '').toString().trim();
        final especial = (perfil['especialidad'] ??
            perfil['specialty'] ??
            perfil['especialidades']);
        String especialTxt = '';
        if (especial != null) {
          if (especial is List) {
            especialTxt = especial.join(', ');
          } else {
            especialTxt = especial.toString();
          }
        }
        final telefono = (perfil['telefono'] ??
                perfil['telefono_movil'] ??
                perfil['phone'] ??
                '')
            .toString();
        String imageUrl = '';
        final rawImg = perfil['avatar_url'] ??
            perfil['avatar'] ??
            perfil['imagen'] ??
            perfil['foto'] ??
            perfil['photo'];
        if (rawImg != null) imageUrl = rawImg.toString();

        // normalize image url
        if (imageUrl.startsWith('/')) imageUrl = ApiService.baseUrl + imageUrl;

        // fetch image bytes if url available
        Uint8List? imgBytes;
        if (imageUrl.isNotEmpty) {
          try {
            final res = await http.get(Uri.parse(imageUrl));
            if (res.statusCode == 200) imgBytes = res.bodyBytes;
          } catch (_) {
            imgBytes = null;
          }
        }

        if (mounted) {
          setState(() {
            _doctorName =
                nombre.isNotEmpty ? nombre : (name.isNotEmpty ? name : usuario);
            _doctorLastName = apellido;
            _doctorSpecialty = especialTxt;
            _doctorPhone = telefono;
            _doctorImageBytes = imgBytes;
            _doctorExtra = [
              if (especialTxt.isNotEmpty) especialTxt,
              if (telefono.isNotEmpty) telefono
            ].join(' • ');
          });
        }
        return;
      }

      // fallback to prefs-only values
      if (mounted) {
        setState(() {
          _doctorName = name.isNotEmpty ? name : usuario;
          _doctorExtra = '';
        });
      }
    } catch (e) {
      // ignore
    }
  }

  // --------------------------------------------------------
  //  LIMPIA Y MUEVE TODAS LAS IMÁGENES AL FINAL Y LAS HACE PEQUEÑAS
  // --------------------------------------------------------
  String _sanitizeImagesForPreview(String html) {
    final imageUrls = <String>[];

    final imageRegex = RegExp(
      r'<img[^>]+src="([^"]+)"[^>]*>',
      caseSensitive: false,
    );

    final matches = imageRegex.allMatches(html);
    for (var match in matches) {
      imageUrls.add(match.group(1)!);
    }

    html = html.replaceAll(imageRegex, '');

    if (imageUrls.isNotEmpty) {
      html += '<h3>Imágenes</h3>';
      for (final img in imageUrls) {
        html +=
            '<img src="$img" style="width:120px; margin-top:10px; margin-bottom:10px;"/>';
      }
    }

    return html;
  }

  /// Extracts <img src="..."> URLs from [html] and returns a map with
  /// cleaned HTML (images removed) and list of image URLs under 'images'.
  Map<String, dynamic> _extractImagesFromHtml(String html) {
    final images = <String>[];
    try {
      final re = RegExp(r'<img[^>]+src="([^\"]+)"[^>]*>', caseSensitive: false);
      final cleaned = html.replaceAllMapped(re, (m) {
        final src = m.group(1) ?? '';
        if (src.isNotEmpty) images.add(src);
        return '';
      });
      return {'images': images, 'html': cleaned};
    } catch (e) {
      return {'images': images, 'html': html};
    }
  }

  // --------------------------------------------------------
  //  GENERAR PDF CON TAMAÑO NORMAL E INCLUIR LOGO
  // --------------------------------------------------------
  Future<Uint8List> _buildPdfBytes(String html) async {
    final doc = pw.Document();

    // helper: load logo safely
    pw.MemoryImage? logoImage;
    try {
      final bd = await rootBundle.load('assets/images/logo.png');
      logoImage = pw.MemoryImage(bd.buffer.asUint8List());
    } catch (_) {
      logoImage = null;
    }

    // Extract embedded images from the HTML and fetch their bytes to include in PDF
    final extracted = _extractImagesFromHtml(html);
    final cleanedHtml = (extracted['html'] ?? html) as String;
    final imageUrls = List<String>.from(extracted['images'] ?? []);
    final List<pw.MemoryImage> pdfImages = [];
    for (final rawSrc in imageUrls) {
      try {
        var src = rawSrc;
        if (src.startsWith('/')) src = ApiService.baseUrl + src;
        Uint8List bytes;
        if (src.startsWith('file:')) {
          final path = Uri.parse(src).toFilePath();
          bytes = await File(path).readAsBytes();
        } else if (src.startsWith('http')) {
          final res = await http.get(Uri.parse(src));
          if (res.statusCode != 200) continue;
          bytes = res.bodyBytes;
        } else {
          final f = File(src);
          if (!await f.exists()) continue;
          bytes = await f.readAsBytes();
        }
        pdfImages.add(pw.MemoryImage(bytes));
      } catch (e) {
        // ignore individual image failures
      }
    }

    // Build header widget for pages
    pw.Widget header(pw.Context context) {
      final List<pw.Widget> left = [];
      if (logoImage != null) {
        left.add(
            pw.Container(width: 64, height: 64, child: pw.Image(logoImage)));
        left.add(pw.SizedBox(width: 10));
      }
      left.add(
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(
            (_doctorName +
                        (_doctorLastName.isNotEmpty ? ' $_doctorLastName' : ''))
                    .trim()
                    .isNotEmpty
                ? (_doctorName +
                        (_doctorLastName.isNotEmpty ? ' $_doctorLastName' : ''))
                    .trim()
                : 'Médico',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        if (_doctorSpecialty.isNotEmpty)
          pw.Text(_doctorSpecialty,
              style:
                  const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
        if (_doctorPhone.isNotEmpty)
          pw.Text(_doctorPhone,
              style:
                  const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
      ]));

      final right = <pw.Widget>[];
      if (_doctorImageBytes != null) {
        right.add(pw.Container(
            width: 48,
            height: 48,
            decoration: const pw.BoxDecoration(shape: pw.BoxShape.circle),
            child: pw.ClipOval(
                child: pw.Image(pw.MemoryImage(_doctorImageBytes!)))));
      }

      return pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(children: left),
          if (right.isNotEmpty) pw.Row(children: right)
        ],
      );
    }

    // Parse cleanedHtml into structured blocks (h3, h4, p) preserving order
    List<pw.Widget> contentBlocks() {
      final blocks = <pw.Widget>[];
      try {
        final re = RegExp(
            r'(<h3[^>]*>.*?<\/h3>)|(<h4[^>]*>.*?<\/h4>)|(<p[^>]*>.*?<\/p>)',
            dotAll: true,
            caseSensitive: false);
        final matches = re.allMatches(cleanedHtml);
        if (matches.isEmpty) {
          // Fallback: whole body as paragraph
          blocks.add(pw.Text(_stripHtmlTags(cleanedHtml),
              style: const pw.TextStyle(fontSize: 11)));
          return blocks;
        }

        for (final m in matches) {
          final match = m.group(0) ?? '';
          if (match.toLowerCase().startsWith('<h3')) {
            final text = _stripHtmlTags(match).trim();
            blocks.add(pw.Padding(
                padding: const pw.EdgeInsets.only(top: 8, bottom: 4),
                child: pw.Text(text,
                    style: pw.TextStyle(
                        fontSize: 16, fontWeight: pw.FontWeight.bold))));
          } else if (match.toLowerCase().startsWith('<h4')) {
            final text = _stripHtmlTags(match).trim();
            blocks.add(pw.Padding(
                padding: const pw.EdgeInsets.only(top: 6, bottom: 4),
                child: pw.Text(text,
                    style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey800))));
          } else if (match.toLowerCase().startsWith('<p')) {
            final text = _stripHtmlTags(match).trim();
            blocks.add(pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Text(text,
                    style: const pw.TextStyle(fontSize: 11, lineSpacing: 2))));
          }
        }
      } catch (e) {
        blocks.add(pw.Text(_stripHtmlTags(cleanedHtml),
            style: const pw.TextStyle(fontSize: 11)));
      }
      return blocks;
    }

    // Use MultiPage to support header/footer and pagination
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      header: header,
      footer: (pw.Context context) {
        return pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8.0),
          child: pw.Text('Página ${context.pageNumber} / ${context.pagesCount}',
              style: const pw.TextStyle(color: PdfColors.grey, fontSize: 9)),
        );
      },
      build: (pw.Context context) {
        final content = <pw.Widget>[];
        content.add(pw.SizedBox(height: 8));
        content.add(pw.Divider());
        content.add(pw.SizedBox(height: 8));
        content.addAll(contentBlocks());

        if (pdfImages.isNotEmpty) {
          content.add(pw.SizedBox(height: 12));
          content.add(pw.Text('Imágenes',
              style:
                  pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)));
          content.add(pw.SizedBox(height: 6));
          // layout images in rows of 3
          final rows = <pw.Widget>[];
          for (var i = 0; i < pdfImages.length; i += 3) {
            final rowImgs =
                pdfImages.sublist(i, (i + 3).clamp(0, pdfImages.length));
            rows.add(pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: rowImgs
                    .map((img) => pw.Container(
                        width: 150,
                        height: 110,
                        child: pw.Image(img, fit: pw.BoxFit.contain)))
                    .toList()));
            rows.add(pw.SizedBox(height: 8));
          }
          content.addAll(rows);
        }

        return content;
      },
    ));

    final res = await doc.save();
    return Uint8List.fromList(res);
  }

  // --------------------------------------------------------
  //  UI PRINCIPAL
  // --------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    var html = args != null && args['html'] is String
        ? args['html'] as String
        : '<p>Sin contenido</p>';

    html = _sanitizeImagesForPreview(html);

    return Scaffold(
      backgroundColor: const Color(0xFF0E1624),
      appBar: AppBar(
        backgroundColor: const Color(0xFF151F2E),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Vista previa',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await Clipboard.setData(ClipboardData(text: html));
              messenger.showSnackBar(
                const SnackBar(content: Text('Copiado')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                final bytes = await _buildPdfBytes(html);
                await Printing.layoutPdf(onLayout: (format) async => bytes);
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Error PDF: $e')),
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --------------------------------------------------------
            // TARJETA DOCTOR (ESTILO APP PRIVADA HOSPITALARIA)
            // --------------------------------------------------------
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF151F2E),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      "assets/images/logo.png",
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _doctorName.isNotEmpty ? _doctorName : 'Médico',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (_doctorExtra.isNotEmpty)
                        Text(
                          _doctorExtra,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                    ],
                  )
                ],
              ),
            ),

            const SizedBox(height: 25),

            // --------------------------------------------------------
            // CONTENIDO PRINCIPAL
            // --------------------------------------------------------
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF151F2E),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.20),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Html(
                data: html,
                style: {
                  "body": Style(
                    color: Colors.white,
                    fontSize: FontSize(15),
                    lineHeight: LineHeight.number(1.5),
                  ),

                  // SEPARADORES ENTRE SECCIONES
                  "h3": Style(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: FontSize(18),
                    margin: Margins.only(top: 20, bottom: 12),
                    padding: HtmlPaddings.zero,
                  ),

                  "h4": Style(
                    color: Colors.white70,
                    fontSize: FontSize(16),
                    margin: Margins.only(top: 16, bottom: 8),
                  ),

                  "p": Style(
                    margin: Margins.only(bottom: 14),
                  ),

                  "img": Style(
                    width: Width(120),
                    margin: Margins.only(top: 8, bottom: 8),
                  ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _stripHtmlTags(String s) {
  return s.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('&nbsp;', ' ');
}
