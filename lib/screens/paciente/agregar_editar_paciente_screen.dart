import 'package:flutter/material.dart';
import '../../models/paciente.dart';
import '../../services/api_services.dart';
import '../../services/local_db.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

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
  List<Map<String, dynamic>> _clinics = [];
  List<Map<String, dynamic>> _doctors = [];
  int? _selectedClinicaId;
  int? _selectedDoctorId;

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

  // Quick HTTP check to verify real internet access (not just network link)
  Future<bool> _checkInternetAvailability() async {
    // Try two endpoints sequentially with a slightly longer timeout to
    // reduce false negatives on slow or captive networks.
    final endpoints = [
      'https://clients3.google.com/generate_204',
      '${ApiService.baseUrl.replaceAll(RegExp(r'\/$'), '')}/health'
    ];
    for (final url in endpoints) {
      try {
        final resp =
            await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
        debugPrint('connectivity check $url -> ${resp.statusCode}');
        if (resp.statusCode == 204 || resp.statusCode == 200) return true;
      } catch (e) {
        debugPrint('connectivity check failed for $url: $e');
        // try next endpoint
      }
    }
    return false;
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

    // Load cached clinics/doctors for dropdowns (best-effort)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final cl = await LocalDb.getClinics();
        final docs = await LocalDb.getDoctors();
        if (!mounted) return;
        setState(() {
          _clinics = cl;
          _doctors = docs;
        });
        // Try refresh clinics from API in background
        try {
          final fetched = await ApiService.obtenerClinicasRaw();
          if (fetched.isNotEmpty) {
            await LocalDb.saveClinics(fetched);
            if (!mounted) return;
            setState(() => _clinics = fetched);
          }
        } catch (_) {}
      } catch (_) {}
    });

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
    // Asignar doctorId o clinicaId según contexto (prioriza valores del widget)
    final resolvedDoctorId = widget.doctorId ?? _selectedDoctorId;
    final resolvedClinicaId = widget.clinicaId ?? _selectedClinicaId;
    if (resolvedDoctorId != null) {
      data["doctor_id"] = resolvedDoctorId.toString();
    }
    if (resolvedClinicaId != null) {
      data["clinica_id"] = resolvedClinicaId.toString();
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
        // Only try remote uniqueness check when we detect real internet access
        final conn = await (Connectivity().checkConnectivity());
        if (conn != ConnectivityResult.none) {
          bool hasInternet = false;
          try {
            hasInternet = await _checkInternetAvailability();
          } catch (_) {
            hasInternet = false;
          }
          if (hasInternet) {
            try {
              final found = await ApiService.buscarPacientePorCedula(cedulaTrim)
                  .timeout(const Duration(seconds: 8));
              if (!mounted) return;
              if (found != null &&
                  found['ok'] == true &&
                  found['data'] != null) {
                final existing = found['data'];
                final existingId = (existing['id'] ??
                        existing['paciente_id'] ??
                        existing['user_id'])
                    ?.toString();
                if (widget.paciente == null) {
                  messenger.showSnackBar(const SnackBar(
                      content: Text(
                          'La cédula ya está registrada para otro paciente')));
                  if (!mounted) return;
                  setState(() => cargando = false);
                  return;
                } else if (existingId != null &&
                    existingId != widget.paciente!.id.toString()) {
                  messenger.showSnackBar(const SnackBar(
                      content: Text(
                          'La cédula ya está registrada para otro paciente')));
                  if (!mounted) return;
                  setState(() => cargando = false);
                  return;
                }
              }
            } catch (e) {
              debugPrint('⚠️ Timeout/error comprobando unicidad de cédula: $e');
              // Do not block save if uniqueness check fails due to network/timeouts
            }
          }
        }
      }
    } catch (e) {
      // Si falla la verificación de unicidad no bloqueamos el guardado, pero lo registramos
      debugPrint('⚠️ Error comprobando unicidad de cédula: $e');
    }

    // Decide online vs offline using a quick reachability test
    final conn = await (Connectivity().checkConnectivity());
    bool hasInternet = false;
    if (conn != ConnectivityResult.none) {
      try {
        hasInternet = await _checkInternetAvailability();
      } catch (_) {
        hasInternet = false;
      }
    }

    if (!hasInternet) {
      // Save locally immediately (fast feedback)
      try {
        await LocalDb.savePatient(data);
        messenger.showSnackBar(const SnackBar(
            content: Text(
                'Paciente guardado localmente (pendiente de sincronización)')));
        if (!mounted) return;
        setState(() => cargando = false);
        navigator.pop(true);
        return;
      } catch (e) {
        debugPrint('Error guardando paciente localmente: $e');
        messenger.showSnackBar(const SnackBar(
            content: Text('Error guardando paciente localmente')));
        if (!mounted) return;
        setState(() => cargando = false);
        return;
      }
    }

    if (widget.paciente == null) {
      // AGREGAR (online) - use timeout and fallback to local save if network fails
      try {
        final resp = await ApiService.crearPaciente(data)
            .timeout(const Duration(seconds: 12));
        exito = resp['ok'] == true;
        mensaje = resp['message'] ?? '';
        // If server returned an explicit failure (ok == false), fallback to local save
        if (exito == false) {
          try {
            await LocalDb.savePatient(data);
            messenger.showSnackBar(const SnackBar(
                content: Text(
                    'Paciente guardado localmente (pendiente de sincronización)')));
            if (!mounted) return;
            setState(() => cargando = false);
            navigator.pop(true);
            return;
          } catch (e2) {
            debugPrint(
                'Error guardando paciente localmente tras fallo remoto: $e2');
            messenger.showSnackBar(const SnackBar(
                content: Text('Error guardando paciente localmente')));
            if (!mounted) return;
            setState(() => cargando = false);
            return;
          }
        }
      } catch (e) {
        debugPrint('Error creando paciente remotamente: $e');
        // Fallback: save locally as pending
        try {
          await LocalDb.savePatient(data);
          messenger.showSnackBar(const SnackBar(
              content: Text(
                  'Paciente guardado localmente (pendiente de sincronización)')));
          if (!mounted) return;
          setState(() => cargando = false);
          navigator.pop(true);
          return;
        } catch (e2) {
          debugPrint(
              'Error guardando paciente localmente tras fallo remoto: $e2');
          messenger.showSnackBar(const SnackBar(
              content: Text('Error guardando paciente localmente')));
          if (!mounted) return;
          setState(() => cargando = false);
          return;
        }
      }
    } else {
      // EDITAR
      final pid = widget.paciente!.id.toString();
      // If this is a local pending patient (localId UUID), allow local edit while offline
      if (pid.contains('-') && !hasInternet) {
        try {
          await LocalDb.savePatient(data, localId: pid);
          messenger.showSnackBar(const SnackBar(
              content: Text('Paciente actualizado localmente (pendiente)')));
          if (!mounted) return;
          setState(() => cargando = false);
          navigator.pop(true);
          return;
        } catch (e) {
          debugPrint('Error actualizando paciente localmente: $e');
          messenger.showSnackBar(const SnackBar(
              content: Text('Error al actualizar paciente localmente')));
          if (!mounted) return;
          setState(() => cargando = false);
          return;
        }
      }

      // Otherwise attempt online edit
      try {
        exito = await ApiService.editarPaciente(widget.paciente!.id, data)
            .timeout(const Duration(seconds: 12));
        mensaje =
            exito ? 'Paciente actualizado' : 'Error al actualizar paciente';
      } catch (e) {
        debugPrint('Error actualizando paciente remotamente: $e');
        messenger.showSnackBar(const SnackBar(
            content: Text('No fue posible actualizar en el servidor')));
        if (!mounted) return;
        setState(() => cargando = false);
        return;
      }
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
                    // If both doctorId and clinicaId are null allow user to pick cached options
                    if (widget.paciente == null &&
                        widget.doctorId == null &&
                        widget.clinicaId == null) ...[
                      if (_clinics.isNotEmpty)
                        DropdownButtonFormField<int>(
                          decoration: const InputDecoration(
                              labelText: 'Clínica (opcional)'),
                          items: _clinics.map((c) {
                            final id = c['id'] is int
                                ? c['id'] as int
                                : int.tryParse(c['id']?.toString() ?? '') ?? 0;
                            final name =
                                c['nombre'] ?? c['name'] ?? 'Clínica $id';
                            return DropdownMenuItem<int>(
                                value: id, child: Text(name.toString()));
                          }).toList(),
                          onChanged: (v) =>
                              setState(() => _selectedClinicaId = v),
                          value: _selectedClinicaId,
                        ),
                      if (_doctors.isNotEmpty)
                        DropdownButtonFormField<int>(
                          decoration: const InputDecoration(
                              labelText: 'Doctor (opcional)'),
                          items: _doctors.map((d) {
                            final id = d['id'] is int
                                ? d['id'] as int
                                : int.tryParse(d['id']?.toString() ?? '') ?? 0;
                            final name =
                                d['nombre'] ?? d['usuario'] ?? 'Doctor $id';
                            return DropdownMenuItem<int>(
                                value: id, child: Text(name.toString()));
                          }).toList(),
                          onChanged: (v) =>
                              setState(() => _selectedDoctorId = v),
                          value: _selectedDoctorId,
                        ),
                      const SizedBox(height: 8),
                    ],
                    TextFormField(
                      controller: _nombresController,
                      decoration: const InputDecoration(labelText: "Nombres"),
                      validator: (v) =>
                          v == null || v.isEmpty ? "Ingresa nombres" : null,
                    ),
                    TextFormField(
                      controller: _apellidosController,
                      decoration: const InputDecoration(labelText: "Apellidos"),
                      validator: (v) =>
                          v == null || v.isEmpty ? "Ingresa apellidos" : null,
                    ),
                    TextFormField(
                      controller: _cedulaController,
                      decoration: const InputDecoration(labelText: "Cédula"),
                      validator: (v) =>
                          v == null || v.isEmpty ? "Ingresa cédula" : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _telefonoController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: "Teléfono"),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _direccionController,
                      decoration: const InputDecoration(labelText: "Dirección"),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _fechaNacimientoController,
                      readOnly: true,
                      decoration: const InputDecoration(
                          labelText: "Fecha de nacimiento (YYYY-MM-DD)"),
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
