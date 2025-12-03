import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../models/paciente.dart';
import '../../models/consulta.dart';
import '../../models/cita.dart';
import '../../services/api_services.dart';
import '../../utils/formato_fecha.dart';
import '../../utils/pdf_helper.dart';
import '../../route_refresh_mixin.dart';
import '../historial/consulta_detalle_screen.dart';
import '../../widgets/google_calendar_login.dart';
import '../../utils/google_calendar_helper.dart';

class VistaPacienteScreen extends StatefulWidget {
  final Paciente paciente;
  const VistaPacienteScreen({super.key, required this.paciente});

  @override
  State<VistaPacienteScreen> createState() => _VistaPacienteScreenState();
}

class _VistaPacienteScreenState extends State<VistaPacienteScreen>
    with RouteRefreshMixin<VistaPacienteScreen> {
  List<Consulta> consultas = [];
  List<Cita> citas = [];
  bool cargando = true;
  GoogleSignInAccount? _googleUser;

  @override
  void initState() {
    super.initState();
    cargarDatos();
  }

  @override
  void onRouteRefreshed() {
    try {
      cargarDatos();
    } catch (_) {}
  }

  Future<void> cargarDatos() async {
    setState(() => cargando = true);
    List<Consulta> cons = widget.paciente.historial;
    List<Cita> cit = widget.paciente.citas;

    try {
      final fetched =
          await ApiService.obtenerConsultasPaciente(widget.paciente.id);
      if (fetched.isNotEmpty) {
        cons = fetched;
      }
    } catch (e) {
      debugPrint(
          '⚠️ Error cargando consultas de paciente ${widget.paciente.id}: $e');
    }

    try {
      final fetchedCitas =
          await ApiService.obtenerCitasPaciente(widget.paciente.id);
      if (fetchedCitas.isNotEmpty) {
        cit = fetchedCitas;
      }
    } catch (e) {
      debugPrint(
          '⚠️ Error cargando citas de paciente ${widget.paciente.id}: $e');
    }
    if (!mounted) return;
    setState(() {
      consultas = cons;
      citas = cit;
      cargando = false;
    });
  }

  int calcularEdad(String fechaNacimiento) {
    final fecha = DateTime.parse(fechaNacimiento);
    final hoy = DateTime.now();
    int edad = hoy.year - fecha.year;
    if (hoy.month < fecha.month ||
        (hoy.month == fecha.month && hoy.day < fecha.day)) {
      edad--;
    }
    return edad;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.paciente.nombres} ${widget.paciente.apellidos}"),
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Card con datos del paciente
                  Card(
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.paciente.nombres} ${widget.paciente.apellidos}',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                              'Cédula: ${widget.paciente.cedula.isEmpty ? 'No registrada' : widget.paciente.cedula}'),
                          Text(
                              'Teléfono: ${widget.paciente.telefono.isEmpty ? 'No registrado' : widget.paciente.telefono}'),
                          Text(
                              'Dirección: ${widget.paciente.direccion.isEmpty ? 'No registrada' : widget.paciente.direccion}'),
                          Text(
                              'Nacimiento: ${fechaConEdad(widget.paciente.fechaNacimiento)}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Historial de consultas
                  const Text("Historial de consultas",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  consultas.isEmpty
                      ? const Text("No hay consultas registradas")
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: consultas.length,
                          itemBuilder: (_, index) {
                            final c = consultas[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            c.motivo.isNotEmpty
                                                ? c.motivo
                                                : '(Sin motivo)',
                                            style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        TextButton.icon(
                                          icon: const Icon(Icons.visibility,
                                              color: Colors.green),
                                          label: const Text('Ver historial'),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    ConsultaDetalleScreen(
                                                        consulta: c),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      children: [
                                        ElevatedButton.icon(
                                          icon:
                                              const Icon(Icons.picture_as_pdf),
                                          label: const Text('Generar PDF'),
                                          onPressed: () async {
                                            final messenger =
                                                ScaffoldMessenger.of(context);
                                            try {
                                              await PdfHelper
                                                  .generarYCompartirPdf(
                                                      paciente: widget.paciente,
                                                      consultas: [c]);
                                            } catch (e) {
                                              if (!context.mounted) return;
                                              messenger.showSnackBar(SnackBar(
                                                  content: Text(
                                                      'Error generando PDF: $e')));
                                            }
                                          },
                                        ),
                                        if (c.receta.isNotEmpty)
                                          ElevatedButton.icon(
                                            icon:
                                                const Icon(Icons.receipt_long),
                                            label: const Text('Ver receta'),
                                            onPressed: () {
                                              showDialog(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                  title: const Text('Receta'),
                                                  content: Text(c.receta),
                                                  actions: [
                                                    TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(ctx),
                                                        child: const Text(
                                                            'Cerrar')),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        if (c.diagnostico.isNotEmpty)
                                          ElevatedButton.icon(
                                            icon: const Icon(Icons.medication),
                                            label:
                                                const Text('Ver diagnóstico'),
                                            onPressed: () {
                                              showDialog(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                  title:
                                                      const Text('Diagnóstico'),
                                                  content: Text(c.diagnostico),
                                                  actions: [
                                                    TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(ctx),
                                                        child: const Text(
                                                            'Cerrar')),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                  const SizedBox(height: 16),
                  // Citas próximas
                  const Text("Citas próximas",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  citas.isEmpty
                      ? const Text("No hay citas registradas")
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: citas.length,
                          itemBuilder: (_, index) {
                            final cita = citas[index];
                            return Card(
                              child: ListTile(
                                title: Text(cita.motivo),
                                subtitle: Text(
                                    "Fecha: ${cita.fecha.toLocal().toString().split(' ')[0]} - Hora: ${cita.hora}"),
                              ),
                            );
                          },
                        ),
                  const SizedBox(height: 16),
                  // Integración Google Calendar
                  Column(
                    children: [
                      GoogleCalendarLogin(
                        onLogin: (user) {
                          setState(() => _googleUser = user);
                        },
                      ),
                      ElevatedButton(
                        onPressed: _googleUser == null
                            ? null
                            : () async {
                                // Aquí debes obtener los datos de la cita
                                const titulo = 'Cita médica';
                                final fechaInicio = DateTime.now()
                                    .add(const Duration(days: 1)); // ejemplo
                                final fechaFin =
                                    fechaInicio.add(const Duration(hours: 1));
                                const descripcion =
                                    'Consulta médica en la clínica';
                                final ok =
                                    await GoogleCalendarHelper.crearEvento(
                                  user: _googleUser!,
                                  titulo: titulo,
                                  fechaInicio: fechaInicio,
                                  fechaFin: fechaFin,
                                  descripcion: descripcion,
                                );
                                if (!context.mounted) return;
                                final messenger = ScaffoldMessenger.of(context);
                                if (ok) {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Cita agendada en Google Calendar')),
                                  );
                                } else {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Error al agendar cita en Google Calendar')),
                                  );
                                }
                              },
                        child: const Text('Agendar en Google Calendar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
