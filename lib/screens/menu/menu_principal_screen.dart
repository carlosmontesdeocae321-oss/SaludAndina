import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../services/api_services.dart';
import '../../services/local_db.dart';
import '../../route_refresh_mixin.dart';
import '../admin/buy_doctor_slot_dialog.dart';
import '../../utils/formato_fecha.dart';
import '../../models/paciente.dart';
import '../paciente/agregar_editar_paciente_screen.dart';
import '../paciente/consultas_screen.dart';
import '../paciente/agendar_cita_screen.dart';
import '../login/login_screen.dart';
import '../citas/citas_screen.dart';
import '../doctor/profile_screen.dart';
import '../dueno/dashboard_screen.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/bank_transfer_card.dart';
import '../../services/auth_servicios.dart';
import '../inicio_screen.dart';

class MenuPrincipalScreen extends StatefulWidget {
  const MenuPrincipalScreen({super.key});

  @override
  State<MenuPrincipalScreen> createState() => _MenuPrincipalScreenState();
}

class _MenuPrincipalScreenState extends State<MenuPrincipalScreen>
    with RouteRefreshMixin<MenuPrincipalScreen> {
  bool cargando = true;
  int totalPacientes = 0;
  int limitePacientes = 0;
  String? clinicaNombre;
  String? usuarioNombre;
  bool esDueno = false;
  bool esVinculado = false; // true si el doctor fue vinculado mediante compra
  List<Map<String, dynamic>> doctores = [];
  bool isDoctor = false;
  int? doctorIdState;
  String selectedView = 'clinica'; // 'individual' | 'clinica' | 'both'
  int? clinicaIdState;
  Timer? _autoRefreshTimer;
  bool _isRefreshing = false;
  DateTime? _lastRefreshTime;

  static const Duration _autoRefreshInterval = Duration(minutes: 5);
  static const String _lastRefreshPrefKey = 'menu_principal_last_refresh';

  @override
  void initState() {
    super.initState();
    _loadLastRefreshTime();
    _initDatos();
    _scheduleAutoRefresh();
    // Listen to local pending patients changes to refresh list/UI
    try {
      LocalDb.pendingPatientsCount.addListener(_onPendingPatientsChanged);
    } catch (_) {}
  }

  void _onPendingPatientsChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _showBankTransferPurchase({
    required String titulo,
    required double monto,
    required int cantidad,
    String? descripcion,
    int? clinicaId,
    Map<String, dynamic>? metadata,
  }) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    final creation = await ApiService.comprarPromocion(
      titulo: titulo,
      monto: monto,
      cantidad: cantidad,
      clinicaId: clinicaId,
      metadata: metadata,
    );

    if (!mounted) return;
    if (creation['ok'] != true) {
      final message = creation['error'] ?? 'No se pudo iniciar la compra.';
      messenger.showSnackBar(SnackBar(content: Text(message.toString())));
      return;
    }

    final data = creation['data'] is Map<String, dynamic>
        ? creation['data'] as Map<String, dynamic>
        : <String, dynamic>{};
    final rawCompraId = data['compraId'] ?? data['id'];
    final compraId = rawCompraId == null
        ? null
        : rawCompraId.toString().trim().isEmpty
            ? null
            : rawCompraId.toString();

    if (compraId == null) {
      messenger.showSnackBar(const SnackBar(
          content: Text(
              'La compra se generó pero no devolvió un identificador. Contacta soporte.')));
      return;
    }

    String? receiptPath;
    bool uploadInProgress = false;

    final sent = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            Future<void> pickReceipt() async {
              try {
                final picker = ImagePicker();
                final XFile? picked = await picker.pickImage(
                    source: ImageSource.gallery, maxWidth: 1600);
                if (picked != null) {
                  setDialogState(() {
                    receiptPath = picked.path;
                  });
                }
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(SnackBar(
                    content: Text('No se pudo seleccionar la imagen: $e')));
              }
            }

            Future<void> submitReceipt() async {
              if (receiptPath == null || uploadInProgress) return;
              setDialogState(() {
                uploadInProgress = true;
              });
              try {
                final res = await ApiService.subirComprobanteCompra(
                    compraId, receiptPath!);
                if (!dialogCtx.mounted) {
                  return;
                }
                if (res['ok'] == true) {
                  Navigator.of(dialogCtx).pop(true);
                  return;
                }
                if (!mounted) return;
                final msg = res['error'] ??
                    res['body'] ??
                    'No se pudo subir el comprobante.';
                messenger.showSnackBar(SnackBar(content: Text(msg.toString())));
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(SnackBar(
                    content: Text('Error al subir el comprobante: $e')));
              }
              setDialogState(() {
                uploadInProgress = false;
              });
            }

            return AlertDialog(
              title: Text('Pago - $titulo'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Monto: \$${monto.toStringAsFixed(2)}'),
                    if (cantidad > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('Cantidad: $cantidad'),
                      ),
                    if (descripcion != null && descripcion.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(descripcion),
                    ],
                    const SizedBox(height: 12),
                    const Text('Instrucciones de transferencia:'),
                    const SizedBox(height: 8),
                    const BankTransferCard(),
                    const SizedBox(height: 12),
                    const Text(
                        'El ID de compra aparecerá en "Mis compras" una vez que el administrador valide tu pago.'),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.receipt_long),
                      label: Text(receiptPath == null
                          ? 'Seleccionar comprobante'
                          : 'Cambiar comprobante'),
                      onPressed: uploadInProgress ? null : pickReceipt,
                    ),
                    if (receiptPath != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Archivo seleccionado: ${receiptPath!.split(RegExp(r"[/\\]")).last}',
                      ),
                    ],
                    if (receiptPath != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Image.file(
                          File(receiptPath!),
                          height: 160,
                          fit: BoxFit.cover,
                        ),
                      ),
                    const SizedBox(height: 12),
                    const Text(
                        'Después de subir el comprobante, el equipo validará manualmente tu pago.'),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: uploadInProgress
                      ? null
                      : () => Navigator.of(dialogCtx).pop(false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: (receiptPath == null || uploadInProgress)
                      ? null
                      : submitReceipt,
                  child: uploadInProgress
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Subir comprobante'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted) return;

    if (sent == true) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Comprobante enviado. Espera la validación.')));
    } else {
      messenger.showSnackBar(const SnackBar(
          content: Text(
              'Compra registrada. Puedes subir el comprobante más tarde desde la sección "Mis compras".')));
    }
  }

  void _scheduleAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer =
        Timer.periodic(_autoRefreshInterval, (_) => cargarMisDatos());
  }

  void _cancelAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  Future<void> _loadLastRefreshTime() async {
    final prefs = await SharedPreferences.getInstance();
    final storedMillis = prefs.getInt(_lastRefreshPrefKey);
    if (!mounted) return;
    if (storedMillis != null) {
      final stored =
          DateTime.fromMillisecondsSinceEpoch(storedMillis).toLocal();
      setState(() {
        _lastRefreshTime = stored;
      });
    }
  }

  Future<void> _markRefreshTimestamp() async {
    final now = DateTime.now();
    if (mounted) {
      setState(() {
        _lastRefreshTime = now;
      });
    } else {
      _lastRefreshTime = now;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastRefreshPrefKey, now.millisecondsSinceEpoch);
  }

  String _buildLastRefreshLabel(DateTime timestamp) {
    final local = timestamp.toLocal();
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return 'Actualizado ${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }

  Future<void> _mostrarEquipoDialog(BuildContext context) async {
    if (!mounted) return;
    final teamMembers = doctores;
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Equipo de la clínica'),
          content: SizedBox(
            width: double.maxFinite,
            child: teamMembers.isEmpty
                ? const Text('No hay integrantes registrados.')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: teamMembers.length,
                    itemBuilder: (_, index) {
                      final doctor = teamMembers[index];
                      final nombre = (doctor['nombre'] ??
                              doctor['nombres'] ??
                              doctor['displayName'] ??
                              '')
                          .toString();
                      final usuario =
                          (doctor['usuario'] ?? doctor['username'] ?? '')
                              .toString();
                      final correo = (doctor['email'] ?? doctor['correo'] ?? '')
                          .toString();
                      final extras = <String>[];
                      if (usuario.isNotEmpty) {
                        extras.add('Usuario: $usuario');
                      }
                      if (correo.isNotEmpty) {
                        extras.add(correo);
                      }
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.person_outline),
                        title: Text(
                          nombre.isEmpty ? 'Doctor ${index + 1}' : nombre,
                        ),
                        subtitle:
                            extras.isEmpty ? null : Text(extras.join('\n')),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _cancelAutoRefresh();
    try {
      LocalDb.pendingPatientsCount.removeListener(_onPendingPatientsChanged);
    } catch (_) {}
    super.dispose();
  }

  @override
  void onRouteRefreshed() {
    cargarMisDatos();
  }

  Future<void> _requestDoctorLinkingPurchase() async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    final datos = await ApiService.obtenerMisDatos();
    if (!mounted) return;
    final dynamic rawClinica = datos?['clinicaId'] ?? datos?['clinica_id'];
    final int? clinicaId = rawClinica is int
        ? rawClinica
        : rawClinica == null
            ? null
            : int.tryParse(rawClinica.toString());
    if (clinicaId == null) {
      messenger.showSnackBar(const SnackBar(
          content: Text('No se encontró la clínica asociada a tu cuenta.')));
      return;
    }

    bool linkingPurchaseCreated = false;
    bool receiptUploaded = false;

    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        bool generating = false;
        bool instructionsReady = false;
        bool includesSlotCharge = false;
        String? compraId;
        String? receiptPath;
        bool uploading = false;
        String? error;
        const double defaultLinkPrice = 10.0;
        double monto = defaultLinkPrice;
        double slotPrice = 5.0;
        double baseLinkPrice = defaultLinkPrice;
        String? infoMessage;

        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            Future<void> generateInstructions() async {
              setDialogState(() {
                generating = true;
                error = null;
                includesSlotCharge = false;
                infoMessage = null;
              });

              Map<String, dynamic> validation;
              try {
                validation = await ApiService.validarAgregarDoctor(clinicaId);
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                        content: Text('No se pudo validar la vinculación: $e')),
                  );
                }
                setDialogState(() {
                  generating = false;
                });
                return;
              }

              double precio = defaultLinkPrice;
              final dynamic rawPrecio = validation['precioVinculacion'] ??
                  validation['precio_vinculacion'] ??
                  validation['precio_vinculo'] ??
                  validation['precioDoctorSlot'] ??
                  validation['precio'];
              if (rawPrecio is num) {
                final candidate = rawPrecio.toDouble();
                if (candidate >= defaultLinkPrice) {
                  precio = candidate;
                }
              } else if (rawPrecio is String) {
                final parsedPrecio = double.tryParse(rawPrecio);
                if (parsedPrecio != null && parsedPrecio >= defaultLinkPrice) {
                  precio = parsedPrecio;
                }
              }

              if (precio < defaultLinkPrice) {
                precio = defaultLinkPrice;
              }

              baseLinkPrice = precio;
              final dynamic rawSlotPrice = validation['precioDoctorSlot'];
              if (rawSlotPrice is num) {
                slotPrice = rawSlotPrice.toDouble();
              } else if (rawSlotPrice is String) {
                final parsedSlot = double.tryParse(rawSlotPrice);
                if (parsedSlot != null) slotPrice = parsedSlot;
              }

              final bool slotRequired = validation['permitido'] != true;
              final String? motivo = validation['message'] ??
                  validation['error'] ??
                  validation['reason'];

              if (!slotRequired &&
                  motivo != null &&
                  motivo.toString().trim().isNotEmpty) {
                if (mounted) {
                  messenger
                      .showSnackBar(SnackBar(content: Text(motivo.toString())));
                }
              }

              if (slotRequired) {
                final motivoTexto = motivo?.toString().trim();
                final mensajeBase =
                    (motivoTexto != null && motivoTexto.isNotEmpty)
                        ? motivoTexto
                        : 'No hay slots disponibles en tu plan actual.';
                infoMessage =
                    '$mensajeBase Se añadirá un slot adicional por \$${slotPrice.toStringAsFixed(2)} en esta compra.';
              }

              final double totalAmount = slotRequired
                  ? double.parse((precio + slotPrice).toStringAsFixed(2))
                  : double.parse(precio.toStringAsFixed(2));

              final metadata = <String, dynamic>{
                'tipo': 'vinculacion_doctor',
                'precioBaseVinculacion':
                    double.parse(precio.toStringAsFixed(2)),
                'slotIncluido': slotRequired,
                'montoTotal': totalAmount,
                if (validation['totalDoctores'] is num)
                  'totalDoctores': (validation['totalDoctores'] as num).toInt(),
                if (validation['limite'] is num)
                  'limiteDoctores': (validation['limite'] as num).toInt(),
                if (validation['plan'] is Map &&
                    validation['plan']['nombre'] != null)
                  'planNombre': validation['plan']['nombre'].toString(),
                if (slotRequired)
                  'precioSlotDoctor':
                      double.parse(slotPrice.toStringAsFixed(2)),
                if (motivo != null && motivo.toString().isNotEmpty)
                  'mensajeValidacion': motivo.toString(),
              };

              Map<String, dynamic> creation;
              try {
                creation = await ApiService.comprarPromocion(
                  titulo: slotRequired
                      ? 'Vinculación de doctor + slot (solicitud)'
                      : 'Vinculación de doctor (solicitud)',
                  monto: totalAmount,
                  clinicaId: clinicaId,
                  metadata: metadata,
                );
              } catch (e) {
                creation = {
                  'ok': false,
                  'error': 'No se pudo iniciar la compra: ${e.toString()}',
                };
              }

              if (creation['ok'] != true) {
                final message =
                    creation['error'] ?? 'No se pudo iniciar la compra.';
                setDialogState(() {
                  error = message.toString();
                  generating = false;
                });
                return;
              }

              final data = creation['data'] is Map<String, dynamic>
                  ? Map<String, dynamic>.from(creation['data'])
                  : <String, dynamic>{};
              final rawCompra = data['compraId'] ?? data['id'];
              final generatedId = rawCompra == null
                  ? null
                  : rawCompra.toString().trim().isEmpty
                      ? null
                      : rawCompra.toString();

              if (generatedId == null) {
                setDialogState(() {
                  error =
                      'La compra se generó pero no devolvió identificador. Contacta soporte.';
                  generating = false;
                });
                return;
              }

              final String? messageForState = slotRequired ? infoMessage : null;

              setDialogState(() {
                monto = totalAmount;
                baseLinkPrice = double.parse(precio.toStringAsFixed(2));
                compraId = generatedId;
                instructionsReady = true;
                generating = false;
                error = null;
                receiptPath = null;
                includesSlotCharge = slotRequired;
                infoMessage = messageForState;
              });
              linkingPurchaseCreated = true;
            }

            Future<void> pickReceipt() async {
              try {
                final picker = ImagePicker();
                final XFile? picked = await picker.pickImage(
                    source: ImageSource.gallery, maxWidth: 1600);
                if (picked != null) {
                  setDialogState(() {
                    receiptPath = picked.path;
                  });
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                      SnackBar(content: Text('No se pudo seleccionar: $e')));
                }
              }
            }

            Future<void> submitReceipt() async {
              if (compraId == null || receiptPath == null || uploading) {
                return;
              }
              setDialogState(() {
                uploading = true;
              });
              try {
                final res = await ApiService.subirComprobanteCompra(
                    compraId!, receiptPath!);
                if (!dialogCtx.mounted) {
                  return;
                }
                if (res['ok'] == true) {
                  receiptUploaded = true;
                  Navigator.of(dialogCtx).pop(true);
                  return;
                }
                if (!mounted) return;
                final msg = res['error'] ??
                    res['body'] ??
                    'No se pudo subir el comprobante.';
                messenger.showSnackBar(SnackBar(content: Text(msg.toString())));
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(
                    SnackBar(content: Text('Error al subir: $e')));
              }
              setDialogState(() {
                uploading = false;
              });
            }

            return AlertDialog(
              title: const Text('Pago - Vincular doctor'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                        'Completa la compra y, una vez validada por el administrador, podrás registrar el ID del doctor desde "Mis compras".'),
                    const SizedBox(height: 12),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    if (!instructionsReady) ...[
                      ElevatedButton.icon(
                        icon: generating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.receipt_long),
                        label: Text(generating
                            ? 'Generando…'
                            : 'Generar instrucciones'),
                        onPressed: generating ? null : generateInstructions,
                      ),
                    ] else ...[
                      Text('Monto total: \$${monto.toStringAsFixed(2)}'),
                      const SizedBox(height: 8),
                      if (includesSlotCharge) ...[
                        Text(
                          'Desglose: vinculación \$${baseLinkPrice.toStringAsFixed(2)} + slot \$${slotPrice.toStringAsFixed(2)}',
                        ),
                        const SizedBox(height: 8),
                      ] else ...[
                        Text(
                          'Esta compra cubre la solicitud de vinculación (\$${baseLinkPrice.toStringAsFixed(2)}).',
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (infoMessage != null) ...[
                        Text(
                          infoMessage!,
                          style: const TextStyle(color: Colors.orange),
                        ),
                        const SizedBox(height: 12),
                      ] else
                        const SizedBox(height: 12),
                      const Text('Instrucciones de transferencia:'),
                      const SizedBox(height: 8),
                      const BankTransferCard(),
                      const SizedBox(height: 12),
                      const Text(
                          'El ID de compra se mostrará en "Mis compras" después de que el administrador valide el pago.'),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.receipt_long),
                        label: Text(receiptPath == null
                            ? 'Seleccionar comprobante'
                            : 'Cambiar comprobante'),
                        onPressed: uploading ? null : pickReceipt,
                      ),
                      if (receiptPath != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Archivo seleccionado: ${receiptPath!.split(RegExp(r"[/\\]")).last}',
                        ),
                      ],
                      const SizedBox(height: 12),
                      const Text(
                          'Al subir el comprobante, el equipo activará la vinculación manualmente.'),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: uploading || generating
                      ? null
                      : () => Navigator.of(dialogCtx).pop(false),
                  child: const Text('Cancelar'),
                ),
                if (instructionsReady)
                  ElevatedButton(
                    onPressed: (receiptPath == null || uploading)
                        ? null
                        : submitReceipt,
                    child: uploading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Subir comprobante'),
                  ),
              ],
            );
          },
        );
      },
    );

    if (!mounted) return;

    if (receiptUploaded) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Comprobante enviado. Espera la validación.')));
    } else if (linkingPurchaseCreated) {
      messenger.showSnackBar(const SnackBar(
          content: Text(
              'Compra registrada. Puedes subir el comprobante después desde "Mis compras".')));
    }
  }

  Future<void> _initDatos() async {
    await cargarMisDatos();
    if (!mounted) return;
    setState(() {
      cargando = false;
    });
  }

  Future<void> cargarMisDatos() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      final datos = await ApiService.obtenerMisDatos();
      if (!mounted || datos == null) return;
      setState(() {
        totalPacientes = (datos['totalPacientes'] is int)
            ? datos['totalPacientes']
            : int.tryParse('${datos['totalPacientes']}') ?? 0;
        limitePacientes = (datos['limite'] is int)
            ? datos['limite']
            : int.tryParse('${datos['limite']}') ?? 0;
        clinicaNombre = datos['clinica']?.toString();
        usuarioNombre = datos['usuario']?.toString();
        esDueno = datos['dueno'] == true;
        final rawClinica = datos['clinicaId'] ?? datos['clinica_id'];
        if (rawClinica == null) {
          clinicaIdState = null;
        } else if (rawClinica is int) {
          clinicaIdState = rawClinica;
        } else {
          clinicaIdState = int.tryParse(rawClinica.toString());
        }
        if (datos['doctores'] is List) {
          doctores = List<Map<String, dynamic>>.from(datos['doctores']);
        } else {
          doctores = [];
        }
        esVinculado = datos['esVinculado'] == true;
        // Resolver doctorId: puede venir como doctorId/doctor_id/id
        var potentialDoctorId =
            datos['doctorId'] ?? datos['doctor_id'] ?? datos['id'];
        // Si el usuario está en una clínica y mis-datos incluye 'doctores' y el nombre de usuario,
        // intentar localizar el id del doctor actual mediante el usuario (username).
        if (potentialDoctorId == null) {
          try {
            final usuarioActual = datos['usuario']?.toString();
            final listaDoctores = datos['doctores'];
            if (usuarioActual != null && listaDoctores is List) {
              for (final d in listaDoctores) {
                try {
                  if (d != null && d['usuario'] == usuarioActual) {
                    potentialDoctorId = d['id'];
                    break;
                  }
                } catch (_) {}
              }
            }
          } catch (_) {}
        }
        // Guardar en estado el doctorId si se resolvió
        if (potentialDoctorId != null) {
          if (potentialDoctorId is int) {
            doctorIdState = potentialDoctorId;
          } else {
            doctorIdState = int.tryParse(potentialDoctorId.toString());
          }
        } else {
          doctorIdState = null;
        }
        // Guardar si el usuario autenticado es doctor
        isDoctor = (datos['rol'] == 'doctor');
      });
      await _markRefreshTimestamp();
    } finally {
      _isRefreshing = false;
    }
  }

  void cerrarSesion(BuildContext context) {
    // Clear stored credentials and navigate to the public inicio screen
    AuthService.logout().then((_) {
      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const InicioScreen()),
          (route) => false);
    });
  }

  Widget _buildPacienteListForView(String view) {
    final viewToSend =
        (clinicaIdState == null && view != 'individual') ? 'individual' : view;
    const accentColor = Color(0xFF1BD1C2);
    const cardColor = Color(0xFF101D32);
    return FutureBuilder<List<Paciente>>(
      future: _loadPatientsForView(viewToSend),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return const Center(child: Text('No hay pacientes registrados'));
        }
        return RefreshIndicator(
          color: accentColor,
          backgroundColor: const Color(0xFF0A1727),
          onRefresh: () async {
            await cargarMisDatos();
            if (!mounted) return;
            setState(() {});
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final p = items[index];
              return GestureDetector(
                onLongPress: () async {
                  final itemContext = context;
                  final messenger = ScaffoldMessenger.of(itemContext);
                  final confirm = await showDialog<bool>(
                    context: itemContext,
                    builder: (dialogCtx) => AlertDialog(
                      title: const Text('Eliminar paciente'),
                      content: Text(
                          '¿Seguro que deseas eliminar a ${p.nombres} ${p.apellidos}?'),
                      actions: [
                        TextButton(
                            child: const Text('Cancelar'),
                            onPressed: () => Navigator.pop(dialogCtx, false)),
                        TextButton(
                            child: const Text('Eliminar',
                                style: TextStyle(color: Colors.red)),
                            onPressed: () => Navigator.pop(dialogCtx, true)),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    // If this is a local (pending) patient, allow local delete even offline
                    final pid = p.id.toString();
                    final conn = await (Connectivity().checkConnectivity());
                    if (pid.contains('-')) {
                      final removed = await LocalDb.deleteLocalPatient(pid);
                      if (!itemContext.mounted) return;
                      if (removed) {
                        messenger.showSnackBar(const SnackBar(
                            content: Text('Paciente eliminado localmente')));
                        if (!mounted) return;
                        setState(() {});
                      } else {
                        messenger.showSnackBar(const SnackBar(
                            content: Text('Error eliminando paciente local')));
                      }
                    } else if (conn == ConnectivityResult.none) {
                      // Do not allow deleting synced patients while offline
                      messenger.showSnackBar(const SnackBar(
                          content: Text(
                              'No se puede eliminar paciente sincronizado sin conexión')));
                    } else {
                      // Online and patient is server-side -> call API
                      final ok = await ApiService.eliminarPaciente(pid);
                      if (!itemContext.mounted) return;
                      if (ok) {
                        messenger.showSnackBar(
                            const SnackBar(content: Text('Paciente eliminado')));
                        if (!mounted) return;
                        setState(() {});
                      } else {
                        messenger.showSnackBar(const SnackBar(
                            content: Text('Error al eliminar paciente')));
                      }
                    }
                  }
                },
                child: Card(
                  color: cardColor.withOpacity(0.92),
                  elevation: 10,
                  shadowColor: Colors.black.withOpacity(0.45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: Colors.white.withOpacity(0.05),
                    ),
                  ),
                  margin: const EdgeInsets.only(bottom: 18),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text('${p.nombres} ${p.apellidos}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  )),
                            ),
                            // If id looks like a local UUID (contains '-') show pending badge
                            if (p.id.contains('-'))
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade700,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text('Pendiente',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 12)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Cédula: ${p.cedula.isEmpty ? 'No registrada' : p.cedula}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        Text(
                          'Teléfono: ${p.telefono.isEmpty ? 'No registrado' : p.telefono}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        Text(
                          'Dirección: ${p.direccion.isEmpty ? 'No registrada' : p.direccion}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 6),
                        Text('Nacimiento: ${fechaConEdad(p.fechaNacimiento)}',
                            style: const TextStyle(color: Colors.white60)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.calendar_today),
                              label: const Text('Agendar cita'),
                              onPressed: () async {
                                final itemContext = context;
                                final messenger =
                                    ScaffoldMessenger.of(itemContext);
                                final added = await Navigator.push<bool>(
                                  itemContext,
                                  MaterialPageRoute(
                                    builder: (_) => AgendarCitaScreen(
                                      pacienteId: p.id,
                                    ),
                                  ),
                                );
                                if (!itemContext.mounted) return;
                                if (added == true) {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                        content: Text('Cita agendada')),
                                  );
                                }
                              },
                            ),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.medical_information),
                              label: const Text('Consultas'),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ConsultasScreen(
                                      pacienteId: p.id,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.edit),
                              label: const Text('Editar'),
                              onPressed: () async {
                                final itemContext = context;
                                final updated = await Navigator.push<bool>(
                                  itemContext,
                                  MaterialPageRoute(
                                    builder: (_) => AgregarEditarPacienteScreen(
                                      paciente: p,
                                    ),
                                  ),
                                );
                                if (!mounted) return;
                                if (updated == true) setState(() {});
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// Load patients from server and merge local pending patients so they are visible in the list.
  Future<List<Paciente>> _loadPatientsForView(String viewToSend) async {
    try {
      final serverList =
          await ApiService.obtenerPacientesPorClinica(view: viewToSend);
      final serverMapByCedula = <String, Paciente>{};
      for (final s in serverList) {
        final ced = s.cedula;
        if (ced.isNotEmpty) serverMapByCedula[ced] = s;
      }

      // Load local patients (both synced and pending) and merge where server doesn't have them
      final local = await LocalDb.getPatients(onlySynced: false);
      final out = <Paciente>[];
      out.addAll(serverList);
      for (final rec in local) {
        try {
          final map = Map<String, dynamic>.from(rec.cast<String, dynamic>());
          final data = Map<String, dynamic>.from(map['data'] ?? {});
          final ced = data['cedula']?.toString() ?? '';
          final serverId = (map['serverId'] ?? '')?.toString() ?? '';
          // If server already has this cedula or serverId, skip to avoid duplicate
          if ((ced.isNotEmpty && serverMapByCedula.containsKey(ced)) ||
              (serverId.isNotEmpty && serverList.any((s) => s.id == serverId))) {
            continue;
          }

          // create a Paciente object from local data but ensure id is localId so UI can detect
          final localId = map['localId']?.toString() ?? '';
          final pseudo = Map<String, dynamic>.from(data);
          pseudo['id'] = localId.isNotEmpty ? localId : (pseudo['id']?.toString() ?? localId);
          final p = Paciente.fromJson(pseudo);
          out.insert(0, p); // put local records on top
        } catch (_) {}
      }

      return out;
    } catch (e) {
      debugPrint('Load patients merge error: $e');
      // If the remote call failed (likely offline), fallback to local DB so
      // pending patients are still visible in the main list.
      try {
        final local = await LocalDb.getPatients(onlySynced: false);
        final out = <Paciente>[];
        for (final rec in local) {
          try {
            final map = Map<String, dynamic>.from(rec.cast<String, dynamic>());
            final data = Map<String, dynamic>.from(map['data'] ?? {});
            final localId = map['localId']?.toString() ?? '';
            final pseudo = Map<String, dynamic>.from(data);
            pseudo['id'] = localId.isNotEmpty
                ? localId
                : (pseudo['id']?.toString() ?? localId);
            out.add(Paciente.fromJson(pseudo));
          } catch (_) {}
        }
        return out;
      } catch (e2) {
        debugPrint('Fallback local load failed: $e2');
        return [];
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Decidir si se muestran las vistas
    // Un doctor individual (sin `clinicaId`) NO debe ver la pestaña 'Clínica'.
    // Un doctor vinculado (`esVinculado == true`) ve ambas pestañas.
    // Un doctor creado por la clínica (tiene `clinicaId` y `esVinculado == false`) ve solo 'Clínica'.
    final bool showIndividual = (clinicaIdState == null) || esVinculado == true;
    // Mostrar vista clínica solo si el usuario aún pertenece a una clínica o es dueño.
    // No forzar la vista clínica solo por el flag `esVinculado` cuando `clinicaIdState` ya es null.
    final bool showClinica = (clinicaIdState != null) || esDueno == true;
    // Ajustar selectedView si una vista no está disponible
    if (!showIndividual && selectedView == 'individual') {
      selectedView = showClinica ? 'clinica' : 'individual';
    }
    if (!showClinica && selectedView == 'clinica') {
      selectedView = showIndividual ? 'individual' : 'clinica';
    }

    final String? lastRefreshLabel = _lastRefreshTime == null
        ? null
        : _buildLastRefreshLabel(_lastRefreshTime!);

    // Preparar stacks reutilizables
    final individualStack = Stack(
      children: [
        Positioned.fill(child: _buildPacienteListForView('individual')),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
              decoration: BoxDecoration(
                color: const Color(0xFF0B1626).withOpacity(0.92),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 26,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.person_add),
                label: const Text('Agregar paciente individual'),
                onPressed: () async {
                  final buttonContext = context;
                  final messenger = ScaffoldMessenger.of(buttonContext);
                  // Evitar bloqueo si no hay conectividad: usar SharedPreferences como fallback
                  Map<String, dynamic>? datos;
                  final conn = await (Connectivity().checkConnectivity());
                  if (conn == ConnectivityResult.none) {
                    final prefs = await SharedPreferences.getInstance();
                    final userIdStr = prefs.getString('userId');
                    final clinicaIdStr = prefs.getString('clinicaId');
                    datos = {
                      'id': userIdStr != null ? int.tryParse(userIdStr) : null,
                      'doctorId':
                          userIdStr != null ? int.tryParse(userIdStr) : null,
                      'clinicaId': clinicaIdStr != null
                          ? int.tryParse(clinicaIdStr)
                          : null,
                      // Valores conservadores para permitir creación offline
                      'totalPacientes': 0,
                      'limite': 999999,
                    };
                  } else {
                    datos = await ApiService.obtenerMisDatos();
                  }
                  if (!buttonContext.mounted || !mounted) return;
                  // Debug: mostrar qué retorna mis-datos y qué id de doctor vamos a pasar
                  final potentialDoctorId =
                      datos?['doctorId'] ?? datos?['doctor_id'] ?? datos?['id'];
                  debugPrint(
                      'DEBUG before add individual - obtenerMisDatos: $datos');
                  debugPrint(
                      'DEBUG before add individual - resolved doctorId: $potentialDoctorId');
                  if ((datos?['totalPacientes'] ?? 0) >=
                      (datos?['limite'] ?? 0)) {
                    messenger.showSnackBar(const SnackBar(
                        content: Text(
                            'Límite de pacientes alcanzado. Debe comprar cupos extra.')));
                    return;
                  }
                  final added = await Navigator.push<bool>(
                    buttonContext,
                    MaterialPageRoute(
                      builder: (_) => AgregarEditarPacienteScreen(
                        paciente: null,
                        doctorId: potentialDoctorId is int
                            ? potentialDoctorId
                            : (int.tryParse(
                                potentialDoctorId?.toString() ?? '')),
                        clinicaId: null,
                      ),
                    ),
                  );
                  if (!buttonContext.mounted || !mounted) return;
                  if (added == true) await cargarMisDatos();
                },
              ),
            ),
          ),
        ),
      ],
    );

    final List<Widget> clinicActionButtons = [
      ElevatedButton.icon(
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Agregar paciente a la clínica'),
        onPressed: () async {
          final buttonContext = context;
          final messenger = ScaffoldMessenger.of(buttonContext);
          final datos = await ApiService.obtenerMisDatos();
          if (!buttonContext.mounted || !mounted) return;
          if ((datos?['totalPacientes'] ?? 0) >= (datos?['limite'] ?? 0)) {
            messenger.showSnackBar(const SnackBar(
                content: Text(
                    'Límite de pacientes alcanzado. Debe comprar cupos extra.')));
            return;
          }
          final added = await Navigator.push<bool>(
            buttonContext,
            MaterialPageRoute(
              builder: (_) => AgregarEditarPacienteScreen(
                paciente: null,
                doctorId: null,
                clinicaId: datos?['clinicaId'] ?? datos?['clinica_id'],
              ),
            ),
          );
          if (!buttonContext.mounted || !mounted) return;
          if (added == true) await cargarMisDatos();
        },
      ),
      ElevatedButton.icon(
        icon: const Icon(Icons.medical_services),
        label: const Text('Agregar doctor'),
        onPressed: esDueno
            ? () async {
                final parentContext = context;
                final messenger = ScaffoldMessenger.of(parentContext);
                final datos = await ApiService.obtenerMisDatos();
                if (!parentContext.mounted || !mounted) return;
                final clinicaId = clinicaIdState ??
                    datos?['clinicaId'] ??
                    datos?['clinica_id'];
                if (clinicaId == null) {
                  messenger.showSnackBar(const SnackBar(
                      content: Text('No se encontró la clínica')));
                  return;
                }
                final valid =
                    await ApiService.validarAgregarDoctor(clinicaId as int);
                if (!parentContext.mounted || !mounted) return;
                debugPrint('DEBUG validarAgregarDoctor: $valid');
                if ((valid['permitido'] ?? false) == true) {
                  final nameCtrl = TextEditingController();
                  final passCtrl = TextEditingController();
                  final ok = await showDialog<bool>(
                    context: parentContext,
                    builder: (_) => AlertDialog(
                      title: const Text('Crear doctor en la clínica'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                              controller: nameCtrl,
                              decoration:
                                  const InputDecoration(labelText: 'Usuario')),
                          TextField(
                              controller: passCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'Contraseña'),
                              obscureText: true),
                        ],
                      ),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancelar')),
                        ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Crear')),
                      ],
                    ),
                  );
                  if (!parentContext.mounted || !mounted) return;
                  if (ok == true) {
                    final nombre = nameCtrl.text.trim();
                    final clave = passCtrl.text.trim();
                    if (nombre.isEmpty || clave.isEmpty) {
                      messenger.showSnackBar(const SnackBar(
                          content: Text('Debe ingresar usuario y contraseña')));
                      return;
                    }
                    messenger.showSnackBar(
                        const SnackBar(content: Text('Creando doctor...')));
                    final resp = await ApiService.crearUsuarioClinica(
                      usuario: nombre,
                      clave: clave,
                      rol: 'doctor',
                      clinicaId: clinicaId,
                    );
                    debugPrint('DEBUG crearUsuarioClinica resp: $resp');
                    if (!parentContext.mounted || !mounted) return;
                    if ((resp['ok'] ?? false)) {
                      messenger.showSnackBar(const SnackBar(
                          content: Text('Doctor creado correctamente')));
                      await cargarMisDatos();
                    } else {
                      final msg = resp['error'] ??
                          resp['message'] ??
                          'No se pudo completar la operación';
                      messenger.showSnackBar(
                          SnackBar(content: Text(msg.toString())));
                    }
                  }
                } else {
                  final motivo =
                      valid['message'] ?? valid['error'] ?? valid['reason'];
                  if (motivo != null && motivo.toString().isNotEmpty) {
                    messenger.showSnackBar(
                        SnackBar(content: Text(motivo.toString())));
                  }
                  double precio = 5.0;
                  try {
                    final v = await ApiService.validarAgregarDoctor(clinicaId);
                    if (v['precioDoctorSlot'] != null) {
                      final p = v['precioDoctorSlot'];
                      if (p is num) precio = p.toDouble();
                    }
                  } catch (_) {}

                  if (!parentContext.mounted || !mounted) return;

                  final result = await showDialog<bool>(
                    context: parentContext,
                    builder: (_) => BuyDoctorSlotDialog(
                        clinicaId: clinicaId,
                        precio: precio,
                        initialTab: 'crear'),
                  );
                  if (!parentContext.mounted || !mounted) return;
                  if (result == true) await cargarMisDatos();
                }
              }
            : null,
      ),
    ];

    if (clinicaIdState != null) {
      clinicActionButtons.add(
        ElevatedButton.icon(
          icon: const Icon(Icons.apartment),
          label: const Text('Cupo para paciente clínica'),
          onPressed: () async {
            final parentContext = context;
            final messenger = ScaffoldMessenger.of(parentContext);
            final datos = await ApiService.obtenerMisDatos();
            if (!parentContext.mounted || !mounted) return;
            if (datos == null) {
              final goLogin = await showDialog<bool>(
                context: parentContext,
                builder: (_) => AlertDialog(
                  title: const Text('Necesita iniciar sesión'),
                  content: const Text(
                      'Para comprar cupos para la clínica debe iniciar sesión.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar')),
                    ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Iniciar sesión')),
                  ],
                ),
              );
              if (!parentContext.mounted || !mounted) return;
              if (goLogin == true) {
                if (!parentContext.mounted || !mounted) return;
                Navigator.push(parentContext,
                    MaterialPageRoute(builder: (_) => const LoginScreen()));
              }
              return;
            }

            final clinicaId = datos['clinicaId'] ?? datos['clinica_id'];
            if (clinicaId == null) {
              messenger.showSnackBar(const SnackBar(
                  content: Text('No se encontró la clínica asociada')));
              return;
            }

            const double unitPrice = 1.0;
            final quantityCtrl = TextEditingController(text: '1');
            final int? quantity = await showDialog<int>(
              context: parentContext,
              barrierDismissible: false,
              builder: (dialogCtx) {
                String? error;
                return StatefulBuilder(
                  builder: (ctx, setState) {
                    return AlertDialog(
                      title: const Text('Comprar cupos para la clínica'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                              'Ingresa la cantidad de cupos para pacientes de la clínica que deseas solicitar.'),
                          const SizedBox(height: 12),
                          TextField(
                            controller: quantityCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Cantidad',
                              hintText: 'Ej. 5',
                              errorText: error,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                              'Precio unitario: \$${unitPrice.toStringAsFixed(2)}'),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx, null),
                          child: const Text('Cancelar'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            final raw = quantityCtrl.text.trim();
                            final parsed = int.tryParse(raw);
                            if (parsed == null || parsed <= 0) {
                              setState(() {
                                error = 'Ingresa una cantidad válida (>=1).';
                              });
                              return;
                            }
                            Navigator.pop(dialogCtx, parsed);
                          },
                          child: const Text('Continuar'),
                        ),
                      ],
                    );
                  },
                );
              },
            );
            if (!parentContext.mounted || !mounted) {
              quantityCtrl.dispose();
              return;
            }
            quantityCtrl.dispose();
            if (quantity == null) return;

            final double total = unitPrice * quantity;
            final targetClinica = clinicaIdState is int
                ? clinicaIdState
                : int.tryParse(clinicaIdState?.toString() ?? '');
            await _showBankTransferPurchase(
              titulo: 'Cupo paciente adicional para la clínica',
              monto: total,
              cantidad: quantity,
              descripcion:
                  'Solicita $quantity cupo(s) adicionales para la clínica. Precio unitario: \$${unitPrice.toStringAsFixed(2)}. Los cupos se habilitarán una vez validado el comprobante.',
              clinicaId: targetClinica,
              metadata: {
                'tipo': 'paciente_clinica',
                'cantidadSolicitada': quantity,
                'precioUnitario': unitPrice,
                if (targetClinica != null) 'clinicaId': targetClinica,
                if (datos['totalPacientes'] is num)
                  'totalPacientesAntesCompra':
                      (datos['totalPacientes'] as num).toInt(),
                if (datos['limite'] is num)
                  'limitePacientesActual': (datos['limite'] as num).toInt(),
              },
            );
          },
        ),
      );
    }

    if (esDueno) {
      clinicActionButtons.add(
        ElevatedButton.icon(
          icon: const Icon(Icons.link),
          label: const Text('Vincular doctor'),
          onPressed: () async {
            await _requestDoctorLinkingPurchase();
          },
        ),
      );
    }

    if (!esDueno && esVinculado == true) {
      clinicActionButtons.add(
        ElevatedButton.icon(
          icon: const Icon(Icons.link_off),
          label: const Text('Desvincularme de la clínica'),
          onPressed: () async {
            final parentContext = context;
            final messenger = ScaffoldMessenger.of(parentContext);
            final confirm = await showDialog<bool>(
              context: parentContext,
              builder: (_) => AlertDialog(
                title: const Text('Desvincularme'),
                content: const Text(
                    '¿Estás seguro que deseas desvincularte de la clínica? Tus pacientes permanecerán en la clínica.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar')),
                  ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Desvincular')),
                ],
              ),
            );
            if (confirm != true || !mounted) return;
            messenger.showSnackBar(
                const SnackBar(content: Text('Procesando desvinculación...')));
            final ok = await ApiService.desvincularDoctor();
            if (!mounted) return;
            if (ok) {
              messenger.showSnackBar(
                  const SnackBar(content: Text('Desvinculación realizada')));
              await cargarMisDatos();
            } else {
              messenger.showSnackBar(
                  const SnackBar(content: Text('Error al desvincularse')));
            }
          },
        ),
      );
    }

    final clinicStack = Stack(
      children: [
        Positioned.fill(child: _buildPacienteListForView('clinica')),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
              decoration: BoxDecoration(
                color: const Color(0xFF0B1626).withOpacity(0.92),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 26,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: clinicActionButtons,
              ),
            ),
          ),
        ),
      ],
    );

    final theme = Theme.of(context);
    const overlayColor = Color(0xFF101D32);
    const accentColor = Color(0xFF1BD1C2);

    List<Tab> tabsList;
    List<Widget> views;
    if (showIndividual && showClinica) {
      tabsList = const [Tab(text: 'Individual'), Tab(text: 'Clínica')];
      views = [individualStack, clinicStack];
    } else if (showIndividual && !showClinica) {
      tabsList = const [Tab(text: 'Individual')];
      views = [individualStack];
    } else {
      tabsList = const [Tab(text: 'Clínica')];
      views = [clinicStack];
    }

    final initialIndex = (showIndividual && showClinica)
        ? (selectedView == 'clinica' ? 1 : 0)
        : 0;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF02060F), Color(0xFF0B1F36)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -140,
            right: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentColor.withOpacity(0.15), Colors.transparent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -160,
            left: -100,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Theme(
            data: theme.copyWith(
              scaffoldBackgroundColor: Colors.transparent,
              colorScheme: theme.colorScheme.copyWith(
                primary: accentColor,
                secondary: accentColor,
                surface: overlayColor,
                surfaceContainerHigh: overlayColor.withOpacity(0.88),
                onPrimary: const Color(0xFF062026),
                onSurface: Colors.white,
              ),
              textTheme: theme.textTheme.apply(
                bodyColor: Colors.white,
                displayColor: Colors.white,
              ),
              iconTheme: const IconThemeData(color: Colors.white70),
              appBarTheme: theme.appBarTheme.copyWith(
                backgroundColor: overlayColor.withOpacity(0.92),
                elevation: 0,
                titleTextStyle: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                toolbarHeight: 70,
                iconTheme: const IconThemeData(color: Colors.white70),
              ),
              tabBarTheme: theme.tabBarTheme.copyWith(
                indicator: const UnderlineTabIndicator(
                  borderSide: BorderSide(color: accentColor, width: 3),
                ),
                labelColor: accentColor,
                unselectedLabelColor: Colors.white70,
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: const Color(0xFF062026),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                ),
              ),
              dividerColor: Colors.white24,
              snackBarTheme: theme.snackBarTheme.copyWith(
                backgroundColor: overlayColor.withOpacity(0.95),
                contentTextStyle:
                    theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
              ),
            ),
            child: DefaultTabController(
              length: tabsList.length,
              initialIndex: initialIndex,
              child: Scaffold(
                backgroundColor: Colors.transparent,
                drawer: const AppDrawer(),
                appBar: AppBar(
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Menú Principal'),
                      if (clinicaNombre != null && selectedView == 'clinica')
                        Text(
                          'Clínica: $clinicaNombre',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      if (usuarioNombre != null && selectedView == 'individual')
                        Text(
                          'Doctor: $usuarioNombre',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      if (lastRefreshLabel != null)
                        Text(
                          lastRefreshLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white54,
                          ),
                        ),
                    ],
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.group),
                      tooltip: 'Equipo',
                      onPressed: () async {
                        await _mostrarEquipoDialog(context);
                      },
                    ),
                    if (selectedView == 'individual')
                      IconButton(
                        icon: const Icon(Icons.person),
                        tooltip: 'Perfil',
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final datos = await ApiService.obtenerMisDatos();
                          if (!context.mounted || !mounted) return;
                          var doctorId = datos?['doctorId'] ??
                              datos?['doctor_id'] ??
                              datos?['id'];
                          if (doctorId == null) {
                            try {
                              final usuarioActual =
                                  datos?['usuario']?.toString();
                              final lista = datos?['doctores'];
                              if (usuarioActual != null && lista is List) {
                                for (final d in lista) {
                                  try {
                                    if (d != null &&
                                        d['usuario'] == usuarioActual) {
                                      doctorId = d['id'];
                                      break;
                                    }
                                  } catch (_) {}
                                }
                              }
                            } catch (_) {}
                          }
                          if (doctorId == null) {
                            messenger.showSnackBar(const SnackBar(
                                content: Text(
                                    'No se pudo resolver el ID del doctor')));
                            return;
                          }
                          final id = doctorId is int
                              ? doctorId
                              : int.tryParse(doctorId.toString());
                          if (id == null) {
                            messenger.showSnackBar(const SnackBar(
                                content: Text('ID de doctor inválido')));
                            return;
                          }
                          if (!context.mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PerfilDoctorScreen(doctorId: id),
                            ),
                          );
                        },
                      ),
                    if (selectedView == 'individual' && isDoctor)
                      IconButton(
                        icon: const Icon(Icons.person_add_alt_1),
                        tooltip: 'Comprar cupo individual',
                        onPressed: () async {
                          const double unitPrice = 1.0;
                          final quantityCtrl = TextEditingController(text: '1');
                          final int? quantity = await showDialog<int>(
                            context: context,
                            barrierDismissible: false,
                            builder: (dialogCtx) {
                              String? error;
                              return StatefulBuilder(
                                builder: (ctx, setState) {
                                  return AlertDialog(
                                    title: const Text(
                                        'Comprar cupos individuales'),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                            'Ingresa la cantidad de cupos individuales que deseas solicitar.'),
                                        const SizedBox(height: 12),
                                        TextField(
                                          controller: quantityCtrl,
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            labelText: 'Cantidad',
                                            hintText: 'Ej. 5',
                                            errorText: error,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                            'Precio unitario: \$${unitPrice.toStringAsFixed(2)}'),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogCtx, null),
                                        child: const Text('Cancelar'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          final raw = quantityCtrl.text.trim();
                                          final parsed = int.tryParse(raw);
                                          if (parsed == null || parsed <= 0) {
                                            setState(() {
                                              error =
                                                  'Ingresa una cantidad válida (>=1).';
                                            });
                                            return;
                                          }
                                          Navigator.pop(dialogCtx, parsed);
                                        },
                                        child: const Text('Continuar'),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          );
                          quantityCtrl.dispose();
                          if (quantity == null) return;

                          final double total = unitPrice * quantity;
                          Map<String, dynamic>? datos;
                          int? doctorIdMeta = doctorIdState;
                          try {
                            datos = await ApiService.obtenerMisDatos();
                            final rawDoctor = datos?['doctorId'] ??
                                datos?['doctor_id'] ??
                                datos?['id'];
                            if (rawDoctor is int) {
                              doctorIdMeta = rawDoctor;
                            } else if (rawDoctor != null) {
                              final parsed = int.tryParse(rawDoctor.toString());
                              if (parsed != null) doctorIdMeta = parsed;
                            }
                          } catch (_) {}
                          await _showBankTransferPurchase(
                            titulo: 'Cupo paciente individual',
                            monto: total,
                            cantidad: quantity,
                            descripcion:
                                'Solicita $quantity cupo(s) individual(es) para tu cuenta. Precio unitario: \$${unitPrice.toStringAsFixed(2)}. Una vez validado el pago el equipo activará los cupos solicitados.',
                            metadata: {
                              'tipo': 'paciente_individual',
                              'cantidadSolicitada': quantity,
                              'precioUnitario': unitPrice,
                              if (doctorIdMeta != null)
                                'doctorId': doctorIdMeta,
                              if (datos?['limite'] is num)
                                'limiteActual':
                                    (datos!['limite'] as num).toInt(),
                              if (datos?['totalPacientes'] is num)
                                'totalPacientesAntesCompra':
                                    (datos!['totalPacientes'] as num).toInt(),
                            },
                          );
                        },
                      ),
                    if (esDueno)
                      IconButton(
                        icon: const Icon(Icons.dashboard),
                        tooltip: 'Dashboard',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DashboardDuenoScreen(),
                            ),
                          );
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.event),
                      tooltip: 'Ver citas',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CitasScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                  bottom: TabBar(
                    tabs: tabsList,
                    onTap: (i) {
                      setState(() {
                        if (showIndividual && showClinica) {
                          selectedView = i == 0 ? 'individual' : 'clinica';
                        } else if (showIndividual) {
                          selectedView = 'individual';
                        } else {
                          selectedView = 'clinica';
                        }
                      });
                    },
                  ),
                ),
                body: TabBarView(children: views),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
