import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/api_services.dart';

class DoctorDocumentsUploadScreen extends StatefulWidget {
  final int doctorId;
  const DoctorDocumentsUploadScreen({super.key, required this.doctorId});

  @override
  State<DoctorDocumentsUploadScreen> createState() =>
      _DoctorDocumentsUploadScreenState();
}

class _DoctorDocumentsUploadScreenState
    extends State<DoctorDocumentsUploadScreen> {
  List<String> paths = [];
  bool uploading = false;
  String? resultMessage;

  Future<void> pickFiles() async {
    try {
      final res = await FilePicker.platform
          .pickFiles(type: FileType.image, allowMultiple: true);
      if (res != null && res.files.isNotEmpty) {
        setState(() {
          paths = res.files.map((f) => f.path).whereType<String>().toList();
        });
      }
    } catch (e) {
      setState(() => resultMessage = 'Error seleccionando archivos: $e');
    }
  }

  Future<void> upload() async {
    if (paths.isEmpty) return;
    setState(() {
      uploading = true;
      resultMessage = null;
    });
    try {
      final resp =
          await ApiService.subirDocumentosDoctor(widget.doctorId, paths);
      if ((resp['ok'] ?? false) == true) {
        setState(() {
          resultMessage = 'Subida completada correctamente';
          paths = [];
        });
      } else {
        setState(() {
          resultMessage =
              'Error al subir: ${resp['error'] ?? resp['body'] ?? resp}';
        });
      }
    } catch (e) {
      setState(() {
        resultMessage = 'Excepción: $e';
      });
    } finally {
      setState(() {
        uploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subir documentos')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Documentos / certificaciones (imágenes)'),
            const SizedBox(height: 12),
            ElevatedButton.icon(
                onPressed: pickFiles,
                icon: const Icon(Icons.photo_library),
                label: const Text('Seleccionar imágenes')),
            const SizedBox(height: 12),
            if (paths.isNotEmpty)
              Expanded(
                child: ListView.separated(
                  itemCount: paths.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, i) {
                    final p = paths[i];
                    return ListTile(
                      leading: const Icon(Icons.image),
                      title: Text(p.split(RegExp(r'[\\/]')).last),
                      subtitle: Text(p),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_forever),
                        onPressed: () => setState(() => paths.removeAt(i)),
                      ),
                    );
                  },
                ),
              )
            else
              const Text('No hay archivos seleccionados'),
            const SizedBox(height: 12),
            if (resultMessage != null) Text(resultMessage!),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: uploading ? null : upload,
                  icon: uploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.upload_file),
                  label: const Text('Subir'),
                ),
                const SizedBox(width: 12),
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cerrar'))
              ],
            )
          ],
        ),
      ),
    );
  }
}
