import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../widgets/bank_transfer_card.dart';
import '../../services/api_services.dart';
import '../../services/auth_servicios.dart';
import '../../refresh_notifier.dart';
import '../login/login_screen.dart';

class PromocionesScreen extends StatelessWidget {
  final List<Map<String, dynamic>> promociones = [
    {
      'titulo': 'Doctor Individual (Freemium)',
      'precio': 'Gratis',
      'detalles': [
        'Hasta 20 pacientes y 1 doctor',
        'Paciente extra: \$1 (pago único)',
        'Todas las funciones disponibles excepto soporte premium',
      ],
    },
    {
      'titulo': 'Clínica Pequeña',
      'precio': '\$20/mes',
      'detalles': [
        '165 pacientes y 2 doctores',
        'Paciente extra: \$1 (pago único)',
        'Doctor extra: \$5 (pago único)',
        'Todas las funciones disponibles',
      ],
    },
    {
      'titulo': 'Clínica Mediana',
      'precio': '\$40/mes',
      'detalles': [
        '300 pacientes y 5 doctores',
        'Paciente extra: \$1 (pago único)',
        'Doctor extra: \$5 (pago único)',
        'Todas las funciones disponibles',
      ],
    },
    {
      'titulo': 'Clínica Grande',
      'precio': '\$100/mes',
      'detalles': [
        'Pacientes y doctores ilimitados',
        'Todas las funciones y soporte premium',
      ],
    },
    {
      'titulo': 'Combo VIP Multi-Sucursal',
      'precio': '\$150/mes',
      'detalles': [
        'Incluye 2 clínicas vinculadas (sucursales)',
        'Pacientes compartidos entre sucursales',
        'Agregar más sucursales por \$50 cada una (solo con Combo VIP)',
        'Pacientes y doctores ilimitados',
        'Prioridad en soporte',
        'Todas las funciones sin límites',
      ],
    },
  ];

  PromocionesScreen({super.key});

  Future<void> _handleGoogleRegistration(BuildContext context) async {
    final navigator = Navigator.of(context);
    var dialogClosed = false;
    void closeDialog() {
      if (!dialogClosed) {
        dialogClosed = true;
        if (navigator.canPop()) {
          navigator.pop();
        }
      }
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    ).whenComplete(() => dialogClosed = true);

    try {
      final credential = await AuthService.signInWithGoogle();
      closeDialog();
      if (!context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      if (credential != null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Sesión iniciada con Google.')),
        );
      } else {
        final message = AuthService.lastGoogleSignInError ??
            'Se canceló el inicio con Google.';
        messenger.showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      closeDialog();
      if (!context.mounted) return;
      final message = AuthService.lastGoogleSignInError ??
          'No se pudo completar la operación: $e';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _showManualRegistrationSheet(BuildContext context) async {
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_add_alt_1),
              title: const Text('Doctor individual (gratis)'),
              subtitle: const Text('Crea tu cuenta con usuario y clave'),
              onTap: () async {
                Navigator.pop(sheetCtx);
                await showDialog<void>(
                  context: context,
                  builder: (_) => _DoctorIndividualDialog(),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.local_hospital),
              title: const Text('Clínica (admin)'),
              subtitle:
                  const Text('Registra una clínica y un usuario administrador'),
              onTap: () async {
                Navigator.pop(sheetCtx);
                final created = await showDialog<bool>(
                  context: context,
                  builder: (_) => _CrearClinicaDialog(),
                );
                if (!context.mounted) return;
                if (created == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Clínica creada y usuario administrador registrados.'),
                    ),
                  );
                }
              },
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(sheetCtx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              child: const Text('Ya tengo cuenta, iniciar sesión'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessCard(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.94),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1BD1C2).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.verified_user,
                  color: Color(0xFF1BD1C2),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Regístrate o inicia sesión',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Elige cómo deseas continuar para contratar un plan o registrar tu clínica.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => _handleGoogleRegistration(context),
            icon: const Icon(Icons.account_circle),
            label: const Text('Registrarme con Google'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _showManualRegistrationSheet(context),
            icon: const Icon(Icons.badge_outlined),
            label: const Text('Registro con usuario y clave'),
          ),
        ],
      ),
    );
  }

  Widget _buildPromocionCard(BuildContext context, Map<String, dynamic> promo) {
    final theme = Theme.of(context);
    final title = promo['titulo']?.toString() ?? '';
    final price = promo['precio']?.toString() ?? '';
    final details = (promo['detalles'] as List).cast<String>();

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.94),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 5,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1BD1C2), Color(0xFF1E88E5)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1BD1C2).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.local_offer,
                        color: Color(0xFF1BD1C2),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1BD1C2).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              price,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF0F1C2C),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final detail in details)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              size: 18,
                              color: Color(0xFF1E88E5),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                detail,
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(fontSize: 15),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.shopping_cart),
                    label: const Text('Contratar'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () async {
                      if (title == 'Doctor Individual (Freemium)') {
                        await showDialog(
                          context: context,
                          builder: (ctx) => _DoctorIndividualDialog(),
                        );
                        return;
                      }

                      final regex = RegExp(r"\d+(?:\.\d+)?");
                      final match = regex.firstMatch(price);
                      double monto = 0;
                      if (match != null) {
                        monto = double.tryParse(match.group(0) ?? '0') ?? 0;
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Iniciando compra...')),
                      );

                      final res = await ApiService.comprarPromocion(
                        titulo: title,
                        monto: monto,
                      );

                      if (!context.mounted) return;

                      if (res['ok'] == true) {
                        final data = res['data'] as Map<String, dynamic>;
                        final paymentUrl = data['payment_url'];
                        final compraId = data['compraId'].toString();

                        final sent = await showDialog<bool>(
                          context: context,
                          builder: (_) => _TransferirDialog(
                            compraId: compraId,
                            paymentUrl: paymentUrl,
                            titulo: title,
                          ),
                        );

                        if (!context.mounted) return;
                        if (sent == true) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Comprobante enviado. Pendiente de validación por el admin.',
                              ),
                            ),
                          );
                        }
                        return;
                      }

                      final err = (res['error'] ?? '').toString();
                      if (err.toLowerCase().contains('credencial') ||
                          err.toLowerCase().contains('faltan')) {
                        final created = await showDialog<bool>(
                          context: context,
                          builder: (_) => _CrearClinicaDialog(),
                        );
                        if (!context.mounted) return;
                        if (created == true) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Clínica creada y usuario dueño generado',
                              ),
                            ),
                          );
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: ${res['error']}')),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Promociones y Combos')),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F1C2C), Color(0xFF1B2D47)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Positioned(
            top: -120,
            right: -60,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                color: Colors.tealAccent.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -90,
            left: -40,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
            ),
          ),
          ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            itemCount: promociones.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildAccessCard(context);
              }
              final promo = promociones[index - 1];
              final isFirstPromo = index == 1;
              final isLastPromo = index == promociones.length;
              return Padding(
                padding: EdgeInsets.only(
                  top: isFirstPromo ? 18 : 0,
                  bottom: isLastPromo ? 0 : 18,
                ),
                child: _buildPromocionCard(context, promo),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CrearClinicaDialog extends StatefulWidget {
  @override
  State<_CrearClinicaDialog> createState() => _CrearClinicaDialogState();
}

class _CrearClinicaDialogState extends State<_CrearClinicaDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _usuarioCtrl = TextEditingController();
  final _claveCtrl = TextEditingController();
  bool cargando = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Crear clínica y usuario admin'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre clínica'),
                validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
              ),
              TextFormField(
                controller: _direccionCtrl,
                decoration: const InputDecoration(labelText: 'Dirección'),
              ),
              const SizedBox(height: 12),
              const Text('Usuario administrador'),
              TextFormField(
                controller: _usuarioCtrl,
                decoration: const InputDecoration(labelText: 'Usuario'),
                validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
              ),
              TextFormField(
                controller: _claveCtrl,
                decoration: const InputDecoration(labelText: 'Clave'),
                obscureText: true,
                validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: cargando
              ? null
              : () async {
                  if (_formKey.currentState?.validate() != true) return;
                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context);
                  setState(() => cargando = true);

                  final res = await ApiService.crearClinicaConAdmin(
                      nombre: _nombreCtrl.text.trim(),
                      direccion: _direccionCtrl.text.trim(),
                      usuario: _usuarioCtrl.text.trim(),
                      clave: _claveCtrl.text.trim());
                  if (!context.mounted) return;
                  setState(() => cargando = false);
                  if (!(res['ok'] ?? false)) {
                    final msg = res['error'] ??
                        res['message'] ??
                        'No se pudo crear la clínica';
                    messenger.showSnackBar(
                      SnackBar(content: Text(msg.toString())),
                    );
                  } else {
                    globalRefreshNotifier.value =
                        globalRefreshNotifier.value + 1;
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Clínica creada correctamente.'),
                      ),
                    );
                    navigator.pop(true);
                  }
                },
          child: cargando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.6),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _direccionCtrl.dispose();
    _usuarioCtrl.dispose();
    _claveCtrl.dispose();
    super.dispose();
  }
}

class _DoctorIndividualDialog extends StatefulWidget {
  @override
  State<_DoctorIndividualDialog> createState() =>
      _DoctorIndividualDialogState();
}

class _DoctorIndividualDialogState extends State<_DoctorIndividualDialog> {
  final _formKey = GlobalKey<FormState>();
  final _usuarioCtrl = TextEditingController();
  final _claveCtrl = TextEditingController();
  bool cargando = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Crear cuenta individual'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _usuarioCtrl,
              decoration: const InputDecoration(labelText: 'Usuario'),
              validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
            ),
            TextFormField(
              controller: _claveCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Clave'),
              validator: (v) =>
                  v == null || v.length < 6 ? 'Mínimo 6 caracteres' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: cargando
              ? null
              : () async {
                  if (_formKey.currentState?.validate() != true) return;
                  final messenger = ScaffoldMessenger.of(context);
                  setState(() => cargando = true);
                  final res = await ApiService.registrarDoctorIndividual(
                    _usuarioCtrl.text.trim(),
                    _claveCtrl.text.trim(),
                  );
                  if (!context.mounted) return;
                  setState(() => cargando = false);
                  if (res['ok'] == true) {
                    globalRefreshNotifier.value =
                        globalRefreshNotifier.value + 1;
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Cuenta creada. Ahora inicia sesión.'),
                      ),
                    );
                    Navigator.pop(context);
                  } else {
                    final msg = res['error'] ?? 'No se pudo registrar';
                    messenger.showSnackBar(
                      SnackBar(content: Text(msg.toString())),
                    );
                  }
                },
          child: cargando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.6),
                )
              : const Text('Crear cuenta'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _usuarioCtrl.dispose();
    _claveCtrl.dispose();
    super.dispose();
  }
}

class _TransferirDialog extends StatefulWidget {
  final String compraId;
  final String? paymentUrl;
  final String titulo;

  const _TransferirDialog({
    required this.compraId,
    required this.titulo,
    this.paymentUrl,
  });

  @override
  State<_TransferirDialog> createState() => _TransferirDialogState();
}

class _TransferirDialogState extends State<_TransferirDialog> {
  XFile? _comprobante;
  bool _subiendo = false;

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source, imageQuality: 70);
    if (image != null) {
      setState(() => _comprobante = image);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BankTransferCard(),
            const SizedBox(height: 12),
            if (widget.paymentUrl != null && widget.paymentUrl!.isNotEmpty)
              Card(
                margin: EdgeInsets.zero,
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceVariant,
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.link),
                  title: const Text('Enlace de pago'),
                  subtitle: SelectableText(widget.paymentUrl!),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: widget.paymentUrl!),
                      );
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Enlace copiado al portapapeles'),
                        ),
                      );
                    },
                  ),
                ),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _pickImage(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(
                _comprobante == null
                    ? 'Subir comprobante'
                    : 'Cambiar comprobante',
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _pickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Tomar foto'),
            ),
            if (_comprobante != null) ...[
              const SizedBox(height: 8),
              Text(
                'Archivo seleccionado: ${_comprobante!.name}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
            const SizedBox(height: 6),
            const Text(
              'El equipo confirmará la activación del plan una vez validado el comprobante.',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cerrar'),
        ),
        FilledButton(
          onPressed: _subiendo || _comprobante == null
              ? null
              : () async {
                  setState(() => _subiendo = true);
                  final res = await ApiService.subirComprobanteCompra(
                    widget.compraId,
                    _comprobante!.path,
                  );
                  if (!context.mounted) return;
                  setState(() => _subiendo = false);
                  if (res['ok'] == true) {
                    globalRefreshNotifier.value =
                        globalRefreshNotifier.value + 1;
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(context, true);
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Comprobante enviado. Espera la validación.',
                        ),
                      ),
                    );
                  } else {
                    final msg = res['error'] ?? 'No se pudo subir';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(msg.toString())),
                    );
                  }
                },
          child: _subiendo
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.6),
                )
              : const Text('Enviar comprobante'),
        ),
      ],
    );
  }
}
