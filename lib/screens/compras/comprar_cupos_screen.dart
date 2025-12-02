import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_services.dart';
import '../../refresh_notifier.dart';
import '../../widgets/bank_transfer_card.dart';

class ComprarCuposScreen extends StatefulWidget {
  const ComprarCuposScreen({super.key});

  @override
  State<ComprarCuposScreen> createState() => _ComprarCuposScreenState();
}

class _ComprarCuposScreenState extends State<ComprarCuposScreen> {
  int _patientSlots = 0;
  int _newDoctors = 0;
  bool _linkToClinic = false;
  bool _loading = false;

  // Prices (kept local; can be moved to remote config later)
  static const double _pricePerPatient = 1.0; // pago único por cupo
  static const double _pricePerDoctor = 5.0; // pago único por doctor extra
  static const double _priceLinkClinic = 10.0; // tarifa única por vinculación

  double get _subtotalPatients => _patientSlots * _pricePerPatient;
  double get _subtotalDoctors => _newDoctors * _pricePerDoctor;
  double get _subtotalLink => _linkToClinic ? _priceLinkClinic : 0.0;
  double get _total => _subtotalPatients + _subtotalDoctors + _subtotalLink;

  Future<void> _comprar() async {
    if (_total <= 0) return;
    setState(() => _loading = true);
    const titulo = 'Compra cupos y servicios';
    final res =
        await ApiService.comprarPromocion(titulo: titulo, monto: _total);
    if (!mounted) return;
    setState(() => _loading = false);
    if (res['ok'] == true) {
      final data = res['data'];
      final paymentUrl = data['payment_url'];
      final compraId = data['compraId'].toString();
      // Open transfer dialog (reuse existing in promociones screen)
      final sent = await showDialog<bool>(
        context: context,
        builder: (_) => _TransferDialogForCompra(
            compraId: compraId, paymentUrl: paymentUrl, titulo: titulo),
      );

      if (!mounted) return;
      if (sent == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Comprobante enviado. Pendiente de validación por el admin.')));
        // Notify global listeners
        globalRefreshNotifier.value = globalRefreshNotifier.value + 1;
        Navigator.of(context).pop();
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al iniciar compra: ${res['error'] ?? ''}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comprar cupos y servicios')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Cupos de pacientes',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: _patientSlots <= 0
                              ? null
                              : () => setState(() => _patientSlots--),
                        ),
                        Text('$_patientSlots',
                            style: const TextStyle(fontSize: 18)),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => setState(() => _patientSlots++),
                        ),
                        const SizedBox(width: 12),
                        Text(
                            'Precio por cupo: \$${_pricePerPatient.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.black54)),
                      ],
                    ),
                    const Divider(),
                    const Text('Doctor(es) nuevos (vincular)',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: _newDoctors <= 0
                              ? null
                              : () => setState(() => _newDoctors--),
                        ),
                        Text('$_newDoctors',
                            style: const TextStyle(fontSize: 18)),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => setState(() => _newDoctors++),
                        ),
                        const SizedBox(width: 12),
                        Text(
                            'Precio por doctor: \$${_pricePerDoctor.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.black54)),
                      ],
                    ),
                    const Divider(),
                    Row(
                      children: [
                        Checkbox(
                            value: _linkToClinic,
                            onChanged: (v) =>
                                setState(() => _linkToClinic = v ?? false)),
                        const SizedBox(width: 8),
                        const Expanded(
                            child:
                                Text('Vinculación a clínica (tarifa única)')),
                        Text('\$${_priceLinkClinic.toStringAsFixed(2)}')
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                        'Total pacientes: $_patientSlots   Doctor(es): $_newDoctors',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text('Total a pagar: \$${_total.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _total <= 0 || _loading ? null : _comprar,
              icon: const Icon(Icons.shopping_cart),
              label: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Comprar'),
            ),
            const SizedBox(height: 12),
            const Text(
                'Notas: Pago único por cada cupo/doctor. El admin validará el comprobante y activará los cupos/usuarios correspondientes.'),
          ],
        ),
      ),
    );
  }
}

class _TransferDialogForCompra extends StatefulWidget {
  final String compraId;
  final String? paymentUrl;
  final String titulo;
  const _TransferDialogForCompra(
      {required this.compraId, this.paymentUrl, required this.titulo});

  @override
  State<_TransferDialogForCompra> createState() =>
      _TransferDialogForCompraState();
}

class _TransferDialogForCompraState extends State<_TransferDialogForCompra> {
  bool cargando = false;
  String? _pickedPath;

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final XFile? picked =
          await picker.pickImage(source: ImageSource.gallery, maxWidth: 1600);
      if (picked != null) {
        if (!mounted) return;
        setState(() {
          _pickedPath = picked.path;
        });
      }
    } catch (e) {
      debugPrint('pick image error: $e');
    }
  }

  Future<void> _upload() async {
    if (_pickedPath == null) return;
    setState(() => cargando = true);
    final res =
        await ApiService.subirComprobanteCompra(widget.compraId, _pickedPath!);
    if (!mounted) return;
    setState(() => cargando = false);
    if (res['ok'] == true) {
      Navigator.pop(context, true);
    } else {
      final err = res['error'] ?? res['body'] ?? 'Error al subir comprobante';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Pago - ${widget.titulo}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Instrucciones de transferencia:'),
            const SizedBox(height: 8),
            const SizedBox(height: 8),
            const SizedBox(height: 8),
            const SizedBox(height: 8),
            const SizedBox(height: 8),
            // Bank card
            const BankTransferCard(),
            const SizedBox(height: 12),
            if (widget.paymentUrl != null)
              Text('Si prefieres, abre este enlace: ${widget.paymentUrl}'),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.photo),
              label: Text(_pickedPath == null
                  ? 'Seleccionar comprobante'
                  : 'Cambiar comprobante'),
              onPressed: cargando ? null : _pickImage,
            ),
            if (_pickedPath != null) ...[
              const SizedBox(height: 8),
              Text(
                  'Archivo seleccionado: ${_pickedPath!.split(RegExp(r"[/\\]")).last}'),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar')),
        ElevatedButton(
            onPressed: (cargando || _pickedPath == null) ? null : _upload,
            child: cargando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Subir comprobante'))
      ],
    );
  }
}
