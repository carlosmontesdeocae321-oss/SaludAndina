import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/consulta.dart';
import '../../services/api_services.dart';

class ConsultaDetalleScreen extends StatelessWidget {
  final Consulta consulta;
  const ConsultaDetalleScreen({super.key, required this.consulta});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de consulta')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              consulta.motivo.isNotEmpty ? consulta.motivo : '(Sin motivo)',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
                'Fecha: ${consulta.fecha.toLocal().toString().split(' ')[0]}  Hora: ${consulta.fecha.toLocal().toString().split(' ')[1].split('.').first}'),
            const SizedBox(height: 12),
            const Text('Examen físico',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 6, children: [
              if (consulta.peso > 0) Text('Peso: ${consulta.peso} kg'),
              if (consulta.estatura > 0)
                Text('Estatura: ${consulta.estatura} m'),
              if (consulta.imc > 0) Text('IMC: ${consulta.imc}'),
              if (consulta.presion.isNotEmpty)
                Text('Presión: ${consulta.presion}'),
              if (consulta.frecuenciaCardiaca > 0)
                Text('FC: ${consulta.frecuenciaCardiaca}'),
              if (consulta.frecuenciaRespiratoria > 0)
                Text('FR: ${consulta.frecuenciaRespiratoria}'),
              if (consulta.temperatura > 0)
                Text('Temp: ${consulta.temperatura}°C'),
            ]),
            const SizedBox(height: 12),
            if (consulta.diagnostico.isNotEmpty) ...[
              const Text('Diagnóstico',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(consulta.diagnostico),
              const SizedBox(height: 12),
            ],
            if (consulta.tratamiento.isNotEmpty) ...[
              const Text('Tratamiento',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(consulta.tratamiento),
              const SizedBox(height: 12),
            ],
            if (consulta.receta.isNotEmpty) ...[
              const Text('Receta',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(consulta.receta),
              const SizedBox(height: 12),
            ],
            if (consulta.imagenes.isNotEmpty) ...[
              const Text('Imágenes',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
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
                        onTap: () => _openImage(context, displayUrl),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(displayUrl,
                              width: 160, height: 120, fit: BoxFit.cover),
                        ),
                      );
                    }
                    return GestureDetector(
                      onTap: () => _openImage(context, rawUrl),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(File(rawUrl),
                            width: 160, height: 120, fit: BoxFit.cover),
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemCount: consulta.imagenes.length,
                ),
              )
            ]
          ],
        ),
      ),
    );
  }

  void _openImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(8),
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
