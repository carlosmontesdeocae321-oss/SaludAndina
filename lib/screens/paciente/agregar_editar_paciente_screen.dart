import 'package:flutter/material.dart';
import '../../models/paciente.dart';
import '../../services/api_services.dart';

class AgregarEditarPacienteScreen extends StatefulWidget {
  final Paciente? paciente; // Si es null → agregar, si no → editar
  final int? doctorId;
  final int? clinicaId;
  const AgregarEditarPacienteScreen(
      {super.key, this.paciente, this.doctorId, this.clinicaId});

  @override
  State<AgregarEditarPacienteScreen> createState() =>
      _AgregarEditarPacienteScreenState();
}

class _AgregarEditarPacienteScreenState
    extends State<AgregarEditarPacienteScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nombresController;
  late TextEditingController _apellidosController;
  late TextEditingController _cedulaController;
  late TextEditingController _fechaNacimientoController;
  late TextEditingController _telefonoController;
  late TextEditingController _direccionController;

  bool cargando = false;

  Future<void> _pickFecha() async {
    DateTime initialDate = DateTime.now();
    try {
      if (_fechaNacimientoController.text.isNotEmpty) {
        initialDate = DateTime.parse(_fechaNacimientoController.text);
      }
    } catch (_) {}

    final fecha = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (!mounted) return;
    if (fecha != null) {
      // Guardar en formato YYYY-MM-DD
      final formatted = '${fecha.year.toString().padLeft(4, '0')}-'
          '${fecha.month.toString().padLeft(2, '0')}-'
          '${fecha.day.toString().padLeft(2, '0')}';
      _fechaNacimientoController.text = formatted;
    }
  }

  @override
  void initState() {
    super.initState();
    _nombresController =
        TextEditingController(text: widget.paciente?.nombres ?? '');
    _apellidosController =
        TextEditingController(text: widget.paciente?.apellidos ?? '');
    _cedulaController =
        TextEditingController(text: widget.paciente?.cedula ?? '');
    // Normalizar fecha para mostrar solo YYYY-MM-DD si viene con time info
    String initialFecha = '';
    try {
      final raw = widget.paciente?.fechaNacimiento ?? '';
      if (raw.isNotEmpty) {
        final dt = DateTime.parse(raw);
        initialFecha = '${dt.year.toString().padLeft(4, '0')}-'
            '${dt.month.toString().padLeft(2, '0')}-'
            '${dt.day.toString().padLeft(2, '0')}';
      }
    } catch (_) {
      initialFecha = widget.paciente?.fechaNacimiento ?? '';
    }
    _fechaNacimientoController = TextEditingController(text: initialFecha);
    _telefonoController =
        TextEditingController(text: widget.paciente?.telefono ?? '');
    _direccionController =
        TextEditingController(text: widget.paciente?.direccion ?? '');

    // Validación de seguridad: cuando se quiere AGREGAR un paciente (widget.paciente == null)
    // debemos recibir al menos `doctorId` o `clinicaId`. Si ambos son null, informar y cerrar.
    if (widget.paciente == null &&
        widget.doctorId == null &&
        widget.clinicaId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final navigator = Navigator.of(context);
        showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Contexto incompleto'),
            content: const Text(
                'No se recibió ni `doctorId` ni `clinicaId`. Abre el formulario desde la vista adecuada (Individual o Clínica).'),
            actions: [
              ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Aceptar')),
            ],
          ),
        ).then((_) {
          if (!mounted) return;
          navigator.pop(false);
        });
      });
    }
  }

  @override
  void dispose() {
    _nombresController.dispose();
    _apellidosController.dispose();
    _cedulaController.dispose();
    _fechaNacimientoController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    super.dispose();
  }

  Future<void> _guardarPaciente() async {
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => cargando = true);

    final data = {
      "nombres": _nombresController.text.trim(),
      "apellidos": _apellidosController.text.trim(),
      "cedula": _cedulaController.text.trim(),
      "fecha_nacimiento": _fechaNacimientoController.text.trim(),
      "telefono": _telefonoController.text.trim(),
      "direccion": _direccionController.text.trim(),
    };
    // Asignar doctorId o clinicaId según contexto
    if (widget.doctorId != null) {
      data["doctor_id"] = widget.doctorId!.toString();
    }
    if (widget.clinicaId != null) {
      data["clinica_id"] = widget.clinicaId!.toString();
    }

    // Debug: mostrar qué ids tiene el widget y qué payload vamos a enviar
    debugPrint(
        'DEBUG _guardarPaciente - widget.doctorId: ${widget.doctorId}, widget.clinicaId: ${widget.clinicaId}');
    debugPrint('DEBUG _guardarPaciente - payload before request: $data');

    bool exito = false;
    String mensaje = '';
    // Validación extra: la cédula debe ser única. Consultar al backend.
    try {
      final cedulaTrim = _cedulaController.text.trim();
      if (cedulaTrim.isNotEmpty) {
        final found = await ApiService.buscarPacientePorCedula(cedulaTrim);
        if (!mounted) return;
        if (found != null && found['ok'] == true && found['data'] != null) {
          final existing = found['data'];
          final existingId =
              (existing['id'] ?? existing['paciente_id'] ?? existing['user_id'])
                  ?.toString();
          // Si estamos creando (widget.paciente == null) -> cualquier coincidencia es error
          // Si estamos editando -> si la coincidencia corresponde a otro paciente (id distinto) es error
          if (widget.paciente == null) {
            messenger.showSnackBar(const SnackBar(
                content:
                    Text('La cédula ya está registrada para otro paciente')));
            if (!mounted) return;
            setState(() => cargando = false);
            return;
          } else if (existingId != null &&
              existingId != widget.paciente!.id.toString()) {
            messenger.showSnackBar(const SnackBar(
                content:
                    Text('La cédula ya está registrada para otro paciente')));
            if (!mounted) return;
            setState(() => cargando = false);
            return;
          }
        }
      }
    } catch (e) {
      // Si falla la verificación de unicidad no bloqueamos el guardado, pero lo registramos
      debugPrint('⚠️ Error comprobando unicidad de cédula: $e');
    }

    if (widget.paciente == null) {
      // AGREGAR
      final resp = await ApiService.crearPaciente(data);
      exito = resp['ok'] == true;
      mensaje = resp['message'] ?? '';
    } else {
      // EDITAR
      exito = await ApiService.editarPaciente(widget.paciente!.id, data);
      mensaje = exito ? 'Paciente actualizado' : 'Error al actualizar paciente';
    }

    if (!mounted) return;
    setState(() => cargando = false);

    if (exito) {
      messenger.showSnackBar(
        SnackBar(
            content:
                Text(widget.paciente == null ? "Paciente agregado" : mensaje)),
      );
      navigator.pop(true); // Retorna true para recargar listado
      return;
    }

    // Si el error es por límite de pacientes, ofrecer compra de 1 paciente extra
    final lower = mensaje.toString().toLowerCase();
    if (lower.contains('límite') ||
        lower.contains('limite') ||
        lower.contains('alcanzado')) {
      final comprar = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Límite de pacientes alcanzado'),
          content: const Text(
              'Has alcanzado el límite de pacientes. ¿Deseas comprar 1 paciente extra por \$1?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar')),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Comprar')),
          ],
        ),
      );

      if (!mounted) return;
      if (comprar == true) {
        // Simular pago de $1 antes de procesar la compra real
        final paid = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Simulación de pago'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [Text('Simular pago de \$1 por paciente extra')],
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
        if (!mounted) return;
        if (paid != true) return;

        messenger.showSnackBar(
            const SnackBar(content: Text('Procesando compra...')));
        final compraRes = await ApiService.comprarPacienteExtra();
        if (!mounted) return;
        if (compraRes['ok'] == true) {
          // Intentar crear paciente nuevamente
          final retry = await ApiService.crearPaciente(data);
          if (!mounted) return;
          if (retry['ok'] == true) {
            messenger.showSnackBar(
                const SnackBar(content: Text('Paciente creado tras compra')));
            navigator.pop(true);
            return;
          } else {
            messenger.showSnackBar(SnackBar(
                content: Text(retry['message'] ??
                    'Error al crear paciente tras compra')));
            return;
          }
        } else {
          final msg = compraRes['error'] ??
              compraRes['message'] ??
              'Error al procesar la compra';
          messenger.showSnackBar(
              SnackBar(content: Text('Error compra: ${msg.toString()}')));
          return;
        }
      }
    }

    messenger.showSnackBar(
      SnackBar(
          content:
              Text(mensaje.isNotEmpty ? mensaje : "Error al guardar paciente")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titulo =
        widget.paciente == null ? "Agregar Paciente" : "Editar Paciente";

    // Etiqueta que indica dónde se guardará el paciente
    final destinoLabel = widget.clinicaId != null
        ? 'Clínica (ID: ${widget.clinicaId})'
        : (widget.doctorId != null
            ? 'Individual (doctor ID: ${widget.doctorId})'
            : 'Destino desconocido');

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldTextColor = isDark ? Colors.white : Colors.black87;
    final fieldLabelColor = isDark ? Colors.white70 : Colors.black54;
    final fieldHintColor = isDark ? Colors.white54 : Colors.black45;
    final fieldFillColor = isDark ? const Color(0xFF0B1626) : Colors.white;

    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Indicar destino de guardado (Individual / Clínica)
                    Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.place, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text('Destino: $destinoLabel',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    TextFormField(
                      controller: _nombresController,
                      style: TextStyle(color: fieldTextColor),
                      decoration: InputDecoration(
                        labelText: "Nombres",
                        labelStyle: TextStyle(color: fieldLabelColor),
                        hintStyle: TextStyle(color: fieldHintColor),
                        filled: true,
                        fillColor: fieldFillColor,
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? "Ingresa nombres" : null,
                    ),
                    TextFormField(
                      controller: _apellidosController,
                      style: TextStyle(color: fieldTextColor),
                      decoration: InputDecoration(
                        labelText: "Apellidos",
                        labelStyle: TextStyle(color: fieldLabelColor),
                        hintStyle: TextStyle(color: fieldHintColor),
                        filled: true,
                        fillColor: fieldFillColor,
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? "Ingresa apellidos" : null,
                    ),
                    TextFormField(
                      controller: _cedulaController,
                      style: TextStyle(color: fieldTextColor),
                      decoration: InputDecoration(
                        labelText: "Cédula",
                        labelStyle: TextStyle(color: fieldLabelColor),
                        hintStyle: TextStyle(color: fieldHintColor),
                        filled: true,
                        fillColor: fieldFillColor,
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? "Ingresa cédula" : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _telefonoController,
                      style: TextStyle(color: fieldTextColor),
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: "Teléfono",
                        labelStyle: TextStyle(color: fieldLabelColor),
                        hintStyle: TextStyle(color: fieldHintColor),
                        filled: true,
                        fillColor: fieldFillColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _direccionController,
                      style: TextStyle(color: fieldTextColor),
                      decoration: InputDecoration(
                        labelText: "Dirección",
                        labelStyle: TextStyle(color: fieldLabelColor),
                        hintStyle: TextStyle(color: fieldHintColor),
                        filled: true,
                        fillColor: fieldFillColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _fechaNacimientoController,
                      readOnly: true,
                      style: TextStyle(color: fieldTextColor),
                      decoration: InputDecoration(
                          labelText: "Fecha de nacimiento (YYYY-MM-DD)",
                          labelStyle: TextStyle(color: fieldLabelColor),
                          hintStyle: TextStyle(color: fieldHintColor),
                          filled: true,
                          fillColor: fieldFillColor),
                      onTap: _pickFecha,
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return "Ingresa fecha de nacimiento";
                        }
                        try {
                          DateTime.parse(v);
                        } catch (_) {
                          return "Formato inválido";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _guardarPaciente,
                      child: Text(
                          widget.paciente == null ? "Agregar" : "Actualizar"),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
