import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../widgets/bank_transfer_card.dart';
import '../../services/pago_servicios.dart';

class SolicitarPagoScreen extends StatefulWidget {
  final PagoServicios pagoServicios;
  final int userId;
  const SolicitarPagoScreen(
      {super.key, required this.pagoServicios, required this.userId});

  @override
  State<SolicitarPagoScreen> createState() => _SolicitarPagoScreenState();
}

class _SolicitarPagoScreenState extends State<SolicitarPagoScreen> {
  File? _image;
  bool _loading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? picked =
        await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200);
    if (picked != null) {
      if (!mounted) return;
      setState(() {
        _image = File(picked.path);
      });
    }
  }

  Future<void> _submit() async {
    if (_image == null) return;
    setState(() => _loading = true);
    final res =
        await widget.pagoServicios.solicitarPago(_image!, widget.userId);
    if (!mounted) return;
    setState(() => _loading = false);
    if (res['ok'] == true) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Solicitud enviada')));
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar: ${res['status'] ?? ''}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Solicitar pago')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const BankTransferCard(),
            const SizedBox(height: 12),
            _image == null
                ? const Placeholder(fallbackHeight: 200)
                : Image.file(_image!, height: 200),
            const SizedBox(height: 12),
            ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.photo),
                label: const Text('Seleccionar comprobante')),
            const SizedBox(height: 12),
            ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('Enviar'))
          ],
        ),
      ),
    );
  }
}
