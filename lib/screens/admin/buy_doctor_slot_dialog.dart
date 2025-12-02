import 'package:flutter/material.dart';
import '../../services/api_services.dart';

class BuyDoctorSlotDialog extends StatefulWidget {
  final int clinicaId;
  final double precio;
  final String initialTab; // 'vincular' or 'crear'
  final int? doctorId;

  const BuyDoctorSlotDialog(
      {super.key,
      required this.clinicaId,
      required this.precio,
      this.initialTab = 'vincular',
      this.doctorId});

  @override
  State<BuyDoctorSlotDialog> createState() => _BuyDoctorSlotDialogState();
}

class _BuyDoctorSlotDialogState extends State<BuyDoctorSlotDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController doctorIdCtrl = TextEditingController();
  final TextEditingController usuarioCtrl = TextEditingController();
  final TextEditingController claveCtrl = TextEditingController();
  bool processing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.initialTab == 'crear') _tabController.index = 1;
    if (widget.doctorId != null) doctorIdCtrl.text = widget.doctorId.toString();
  }

  @override
  void dispose() {
    _tabController.dispose();
    doctorIdCtrl.dispose();
    usuarioCtrl.dispose();
    claveCtrl.dispose();
    super.dispose();
  }

  Future<bool> _simulatePayment(double amount) async {
    // Show a simple modal to simulate payment. Returns true if simulated success.
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Simulación de pago'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Simular pago de \$${amount.toStringAsFixed(2)}'),
            const SizedBox(height: 12),
            const Text('Presiona "Simular pago exitoso" para continuar.'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Simular pago exitoso')),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _handleVincular() async {
    // Show inline modal to collect doctor id and confirm $10
    final tmpCtrl = TextEditingController(text: doctorIdCtrl.text);
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar vinculacion'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                'Se cobrará \$10 por la vinculacion. Clínica ID: ${widget.clinicaId}'),
            const SizedBox(height: 12),
            TextField(
                controller: tmpCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'ID del doctor a vincular')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () {
                doctorIdCtrl.text = tmpCtrl.text;
                Navigator.pop(ctx, true);
              },
              child: const Text('Pagar \$10 y vincular')),
        ],
      ),
    );
    if (confirmed != true) return;

    // Simulate payment
    final paid = await _simulatePayment(10.0);
    if (!mounted) return;
    if (!paid) return;

    setState(() => processing = true);
    // Call purchase endpoint with monto=10.0
    final compra = await ApiService.comprarSlotDoctor(
        clinicaId: widget.clinicaId, monto: 10.0);
    if (!mounted) return;
    if (compra['ok'] != true) {
      final msg = compra['error'] ??
          compra['message'] ??
          'No se pudo procesar la compra';
      setState(() => processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error en la compra: ${msg.toString()}')));
      return;
    }

    final doctorId = int.tryParse(doctorIdCtrl.text.trim());
    if (doctorId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ID inválido')));
      setState(() => processing = false);
      return;
    }

    final linkRes =
        await ApiService.vincularDoctorConCompra(doctorId, widget.clinicaId);
    if (!mounted) return;
    setState(() => processing = false);
    if ((linkRes['ok'] ?? false) == true) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Doctor vinculado correctamente')));
      Navigator.pop(context, true);
    } else {
      final msg = linkRes['error'] ??
          'No se pudo vincular el doctor. Intenta nuevamente o contacta soporte.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _handleCrear() async {
    final usuario = usuarioCtrl.text.trim();
    final clave = claveCtrl.text.trim();
    if (usuario.isEmpty || clave.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Usuario o clave vacío')));
      return;
    }

    // Simulate payment for the creation (use widget.precio)
    final paid = await _simulatePayment(widget.precio);
    if (!mounted) return;
    if (!paid) return;

    setState(() => processing = true);
    final disponible = await ApiService.verificarUsuarioDisponible(usuario);
    if (!mounted) return;
    if (!disponible) {
      setState(() => processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El nombre de usuario ya está en uso')));
      return;
    }
    final res = await ApiService.comprarDoctorExtra(
        clinicaId: widget.clinicaId, usuario: usuario, clave: clave);
    if (!mounted) return;
    setState(() => processing = false);
    if ((res['ok'] ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Doctor creado y asociado correctamente')));
      Navigator.pop(context, true);
    } else {
      final msg =
          res['error'] ?? res['message'] ?? 'No se pudo completar la operación';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SizedBox(
        width: 560,
        height: 420,
        child: Column(
          children: [
            Container(
              color: Theme.of(context).primaryColor,
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                tabs: const [Tab(text: 'Vincular'), Tab(text: 'Crear')],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Clínica ID: ${widget.clinicaId}'),
                        const SizedBox(height: 8),
                        const Text('Precio: \$10.00 (vinculación)'),
                        const SizedBox(height: 12),
                        TextField(
                            controller: doctorIdCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'ID del doctor')),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                                child: ElevatedButton(
                                    onPressed:
                                        processing ? null : _handleVincular,
                                    child: processing
                                        ? const CircularProgressIndicator(
                                            color: Colors.white)
                                        : const Text('Pagar \$10 y Vincular')))
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Clínica ID: ${widget.clinicaId}'),
                        const SizedBox(height: 8),
                        Text('Precio: \$${widget.precio.toStringAsFixed(2)}'),
                        const SizedBox(height: 12),
                        TextField(
                            controller: usuarioCtrl,
                            decoration:
                                const InputDecoration(labelText: 'Usuario')),
                        const SizedBox(height: 8),
                        TextField(
                            controller: claveCtrl,
                            decoration:
                                const InputDecoration(labelText: 'Clave'),
                            obscureText: true),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                                child: ElevatedButton(
                                    onPressed: processing ? null : _handleCrear,
                                    child: processing
                                        ? const CircularProgressIndicator(
                                            color: Colors.white)
                                        : const Text('Pagar y Crear')))
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cerrar')),
            )
          ],
        ),
      ),
    );
  }
}
