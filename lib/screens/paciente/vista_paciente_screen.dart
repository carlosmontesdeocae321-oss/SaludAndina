import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import '../../models/paciente.dart';
import '../../models/consulta.dart';
import '../../models/cita.dart';
import '../../services/api_services.dart';
import '../../services/local_db.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
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
  final DateFormat _fechaFormatter = DateFormat('dd/MM/yyyy');

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
    var cons = List<Consulta>.from(widget.paciente.historial);
    var cit = List<Cita>.from(widget.paciente.citas);
    // Try online first; fallback to local if offline or API fails
    final conn = await Connectivity().checkConnectivity();
    if (conn != ConnectivityResult.none) {
      try {
        // Use raw endpoint to cache original server JSON, then convert to models
        final fetchedRaw =
            await ApiService.obtenerConsultasPacienteRaw(widget.paciente.id);
        if (fetchedRaw.isNotEmpty) {
          try {
            await LocalDb.saveOrUpdateRemoteConsultasBatch(fetchedRaw);
          } catch (_) {}
          cons = fetchedRaw.map((j) => Consulta.fromJson(j)).toList();
        }
      } catch (e) {
        debugPrint(
            '⚠️ Error cargando consultas de paciente ${widget.paciente.id}: $e');
      }

      try {
        // Fetch raw citas and filter by paciente id, cache raw maps first
        final allCitasRaw = await ApiService.obtenerCitasRaw();
        final fetchedCitasRaw = allCitasRaw
            .where((m) => (m['paciente_id'] ?? m['paciente'] ?? m['pacienteId'])
                .toString()
                .toString()
                .contains(widget.paciente.id.toString()))
            .toList();
        if (fetchedCitasRaw.isNotEmpty) {
          try {
            await LocalDb.saveOrUpdateRemoteCitasBatch(fetchedCitasRaw);
          } catch (_) {}
          cit = fetchedCitasRaw.map((j) => Cita.fromJson(j)).toList();
        }
      } catch (e) {
        debugPrint(
            '⚠️ Error cargando citas de paciente ${widget.paciente.id}: $e');
      }
    } else {
      // Offline: load from LocalDb
      try {
        final localCons = await LocalDb.getConsultasByPacienteId(
            widget.paciente.id.toString());
        if (localCons.isNotEmpty) {
          cons = localCons
              .map((m) => Consulta.fromJson(
                  Map<String, dynamic>.from(m['data'] as Map)))
              .toList();
        }
      } catch (e) {
        debugPrint('Error cargando consultas locales: $e');
      }

      try {
        final localCitas =
            await LocalDb.getCitasByPacienteId(widget.paciente.id.toString());
        if (localCitas.isNotEmpty) {
          cit = localCitas
              .map((m) =>
                  Cita.fromJson(Map<String, dynamic>.from(m['data'] as Map)))
              .toList();
        }
      } catch (e) {
        debugPrint('Error cargando citas locales: $e');
      }
    }

    cons.sort((a, b) => b.fecha.compareTo(a.fecha));
    cit.sort((a, b) => a.fecha.compareTo(b.fecha));

    if (!mounted) return;
    setState(() {
      consultas = cons;
      citas = cit;
      cargando = false;
    });
  }

  int? calcularEdad(String rawDate) {
    final trimmed = rawDate.trim();
    if (trimmed.isEmpty) return null;
    final parsed = DateTime.tryParse(trimmed);
    if (parsed == null) return null;
    final today = DateTime.now();
    var years = today.year - parsed.year;
    final hasNotHadBirthday = today.month < parsed.month ||
        (today.month == parsed.month && today.day < parsed.day);
    if (hasNotHadBirthday) years -= 1;
    return years.clamp(0, 150);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final backgroundColor = Color.lerp(
          scheme.surface,
          Colors.black,
          theme.brightness == Brightness.dark ? 0.45 : 0.18,
        ) ??
        scheme.surface;
    final now = DateTime.now();
    final upcomingCitas =
        citas.where((cita) => !cita.fecha.isBefore(now)).toList();
    final citasParaMostrar =
        upcomingCitas.isNotEmpty ? upcomingCitas : List<Cita>.from(citas);
    final mostrandoHistorial = upcomingCitas.isEmpty;
    final nextCita = upcomingCitas.isNotEmpty ? upcomingCitas.first : null;
    final edad = widget.paciente.fechaNacimiento.isEmpty
        ? null
        : calcularEdad(widget.paciente.fechaNacimiento);

    final sections = <Widget>[
      _buildPatientOverview(context, edad, nextCita),
      const SizedBox(height: 24),
      ..._buildConsultasSection(context),
      const SizedBox(height: 24),
      ..._buildCitasSection(
        context,
        citasParaMostrar,
        mostrandoHistorial: mostrandoHistorial,
      ),
      const SizedBox(height: 24),
      _buildCalendarSection(context),
    ];

    final baseTheme = Theme.of(context);
    final appBarBg = baseTheme.appBarTheme.backgroundColor ?? scheme.surface;

    return IconTheme(
      data: const IconThemeData(color: Colors.black),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: appBarBg,
          iconTheme: const IconThemeData(color: Colors.black),
          title:
              Text('${widget.paciente.nombres} ${widget.paciente.apellidos}'),
        ),
        backgroundColor: backgroundColor,
        body: cargando
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: cargarDatos,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: sections,
                ),
              ),
      ),
    );
  }

  Widget _buildPatientOverview(
      BuildContext context, int? edad, Cita? nextCita) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name =
        '${widget.paciente.nombres} ${widget.paciente.apellidos}'.trim();
    final displayName = name.isEmpty ? 'Paciente sin nombre' : name;

    final infoBadges = <Widget>[
      _infoBadge(
        Icons.badge_outlined,
        widget.paciente.cedula.isEmpty ? 'Sin cédula' : widget.paciente.cedula,
        context,
      ),
      _infoBadge(
        Icons.phone_outlined,
        widget.paciente.telefono.isEmpty
            ? 'Sin teléfono'
            : widget.paciente.telefono,
        context,
      ),
      _infoBadge(
        Icons.location_on_outlined,
        widget.paciente.direccion.isEmpty
            ? 'Sin dirección'
            : widget.paciente.direccion,
        context,
      ),
      _infoBadge(
        Icons.cake_outlined,
        widget.paciente.fechaNacimiento.isEmpty
            ? 'Sin fecha de nacimiento'
            : fechaConEdad(widget.paciente.fechaNacimiento),
        context,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.lerp(scheme.surfaceContainerHighest, Colors.black, 0.25)!,
            Color.lerp(scheme.primaryContainer, Colors.black, 0.4)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.onSurface.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.14),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Color.lerp(scheme.primary, Colors.black, 0.2),
                child: Text(
                  _patientInitials(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    if (edad != null && edad > 0)
                      Text(
                        '$edad años',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onPrimaryContainer.withOpacity(0.75),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: infoBadges,
          ),
          if (nextCita != null) ...[
            const SizedBox(height: 18),
            _buildNextCitaBanner(context, nextCita),
          ],
        ],
      ),
    );
  }

  Widget _buildNextCitaBanner(BuildContext context, Cita cita) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dateText = _fechaFormatter.format(cita.fecha);
    final hourText = cita.hora.trim();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withOpacity(0.65),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.secondary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.event_available_outlined, color: Colors.black),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Próxima cita',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  cita.motivo.isEmpty ? 'Consulta programada' : cita.motivo,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSecondaryContainer,
                  ),
                ),
                Text(
                  'Fecha: $dateText',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSecondaryContainer.withOpacity(0.8),
                  ),
                ),
                if (hourText.isNotEmpty)
                  Text(
                    'Hora: $hourText',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSecondaryContainer.withOpacity(0.75),
                    ),
                  ),
              ],
            ),
          ),
          if (cita.estado.isNotEmpty)
            Chip(
              label: Text(_capitalize(cita.estado)),
              backgroundColor: scheme.secondary,
              labelStyle: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSecondary,
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildConsultasSection(BuildContext context) {
    if (consultas.isEmpty) {
      return [
        _sectionHeader(
          context,
          'Historial de consultas',
          icon: Icons.receipt_long_outlined,
        ),
        const SizedBox(height: 12),
        _emptyState(
          'No hay consultas registradas',
          Icons.medical_information_outlined,
          context,
        ),
      ];
    }

    return [
      _sectionHeader(
        context,
        'Historial de consultas',
        icon: Icons.receipt_long_outlined,
      ),
      const SizedBox(height: 12),
      ...consultas.map((consulta) => _buildConsultationCard(context, consulta)),
    ];
  }

  Widget _buildConsultationCard(BuildContext context, Consulta consulta) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dateText = _fechaFormatter.format(consulta.fecha);

    final metrics = <Widget>[];
    final fg =
        theme.brightness == Brightness.dark ? Colors.white : Colors.black;
    if (consulta.peso > 0) {
      metrics.add(
        _metricChip(
          context,
          'Peso',
          '${consulta.peso.toStringAsFixed(1)} kg',
        ),
      );
    }
    if (consulta.estatura > 0) {
      metrics.add(
        _metricChip(
          context,
          'Estatura',
          '${consulta.estatura.toStringAsFixed(2)} m',
        ),
      );
    }
    if (consulta.imc > 0) {
      metrics.add(
        _metricChip(context, 'IMC', consulta.imc.toStringAsFixed(1)),
      );
    }
    if (consulta.presion.isNotEmpty) {
      metrics.add(_metricChip(context, 'Presión', consulta.presion));
    }
    if (consulta.frecuenciaCardiaca > 0) {
      metrics.add(
        _metricChip(
          context,
          'FC',
          '${consulta.frecuenciaCardiaca} bpm',
        ),
      );
    }
    if (consulta.frecuenciaRespiratoria > 0) {
      metrics.add(
        _metricChip(
          context,
          'FR',
          '${consulta.frecuenciaRespiratoria} rpm',
        ),
      );
    }
    if (consulta.temperatura > 0) {
      metrics.add(
        _metricChip(
          context,
          'Temp',
          '${consulta.temperatura.toStringAsFixed(1)} °C',
        ),
      );
    }

    return Card(
      color: Color.lerp(
            scheme.surfaceContainerHighest,
            Colors.black,
            theme.brightness == Brightness.dark ? 0.5 : 0.25,
          ) ??
          scheme.surfaceContainerHighest,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Color.lerp(
                          scheme.primary,
                          Colors.black,
                          theme.brightness == Brightness.dark ? 0.7 : 0.5,
                        ) ??
                        scheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        dateText,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        consulta.motivo.isNotEmpty
                            ? consulta.motivo
                            : 'Consulta sin motivo',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Registrada el $dateText',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Ver detalle',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ConsultaDetalleScreen(consulta: consulta),
                      ),
                    );
                  },
                  icon: Icon(Icons.open_in_new, color: fg),
                ),
              ],
            ),
            if (metrics.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: metrics,
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(foregroundColor: fg),
                  icon: Icon(Icons.picture_as_pdf_outlined, color: fg),
                  label: const Text('Generar PDF'),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await PdfHelper.generarYCompartirPdf(
                        paciente: widget.paciente,
                        consultas: [consulta],
                        citas: citas,
                      );
                    } catch (e) {
                      if (!mounted) return;
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Error generando PDF: $e'),
                        ),
                      );
                    }
                  },
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: fg),
                  icon: Icon(Icons.visibility_outlined, color: fg),
                  label: const Text('Detalle'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ConsultaDetalleScreen(consulta: consulta),
                      ),
                    );
                  },
                ),
                if (consulta.receta.isNotEmpty)
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: fg),
                    icon: Icon(Icons.receipt_long_outlined, color: fg),
                    label: const Text('Ver receta'),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Receta'),
                          content: Text(consulta.receta),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cerrar'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                if (consulta.diagnostico.isNotEmpty)
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: fg),
                    icon: Icon(Icons.medical_information_outlined, color: fg),
                    label: const Text('Ver diagnóstico'),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Diagnóstico'),
                          content: Text(consulta.diagnostico),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cerrar'),
                            ),
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
  }

  List<Widget> _buildCitasSection(
    BuildContext context,
    List<Cita> citasParaMostrar, {
    bool mostrandoHistorial = false,
  }) {
    if (citasParaMostrar.isEmpty) {
      return [
        _sectionHeader(
          context,
          'Citas próximas',
          icon: Icons.event_available_outlined,
        ),
        const SizedBox(height: 12),
        _emptyState(
          'No hay citas programadas',
          Icons.event_busy_outlined,
          context,
        ),
      ];
    }

    return [
      _sectionHeader(
        context,
        'Citas próximas',
        icon: Icons.event_available_outlined,
        subtitle: mostrandoHistorial
            ? 'Sin citas futuras. Mostrando las más recientes registradas.'
            : 'Mantén control de las visitas futuras del paciente.',
      ),
      const SizedBox(height: 12),
      ...citasParaMostrar.map((cita) => _buildCitaCard(context, cita)),
    ];
  }

  Widget _buildCitaCard(BuildContext context, Cita cita) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dateText = _fechaFormatter.format(cita.fecha);
    final hourText = cita.hora.trim();
    final statusColor = _estadoColor(context, cita.estado);

    return Card(
      color: Color.lerp(
            scheme.surfaceContainerHighest,
            Colors.black,
            theme.brightness == Brightness.dark ? 0.5 : 0.22,
          ) ??
          scheme.surfaceContainerHighest,
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Color.lerp(
                      scheme.primary,
                      Colors.black,
                      theme.brightness == Brightness.dark ? 0.65 : 0.45,
                    ) ??
                    scheme.primary.withOpacity(0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.event_note, color: Colors.black),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cita.motivo.isEmpty ? 'Consulta programada' : cita.motivo,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Fecha: $dateText',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (hourText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Hora: $hourText',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (cita.estado.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Chip(
                      label: Text(_capitalize(cita.estado)),
                      backgroundColor: statusColor.withOpacity(0.15),
                      labelStyle: theme.textTheme.labelMedium?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarSection(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      color: Color.lerp(
            scheme.surfaceContainerHighest,
            Colors.black,
            theme.brightness == Brightness.dark ? 0.48 : 0.24,
          ) ??
          scheme.surfaceContainerHighest,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Color.lerp(
                          scheme.primary,
                          Colors.black,
                          theme.brightness == Brightness.dark ? 0.6 : 0.4,
                        ) ??
                        scheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      Icon(Icons.calendar_month_outlined, color: Colors.black),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Google Calendar',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Conecta tu cuenta para sincronizar próximas citas.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GoogleCalendarLogin(
              onLogin: (user) {
                setState(() => _googleUser = user);
              },
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Agendar en Google Calendar'),
                onPressed: _googleUser == null
                    ? null
                    : () async {
                        const titulo = 'Cita médica';
                        final fechaInicio =
                            DateTime.now().add(const Duration(days: 1));
                        final fechaFin =
                            fechaInicio.add(const Duration(hours: 1));
                        const descripcion = 'Consulta médica en la clínica';

                        final messenger = ScaffoldMessenger.of(context);
                        final ok = await GoogleCalendarHelper.crearEvento(
                          user: _googleUser!,
                          titulo: titulo,
                          fechaInicio: fechaInicio,
                          fechaFin: fechaFin,
                          descripcion: descripcion,
                        );

                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(ok
                                ? 'Cita agendada en Google Calendar'
                                : 'Error al agendar cita en Google Calendar'),
                          ),
                        );
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title,
      {IconData? icon, String? subtitle}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Color.lerp(
                    scheme.primary,
                    Colors.black,
                    theme.brightness == Brightness.dark ? 0.6 : 0.4,
                  ) ??
                  scheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.black),
          ),
        if (icon != null) const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _emptyState(String message, IconData icon, BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outline.withOpacity(0.25)),
        color: Color.lerp(
              scheme.surfaceContainerHighest,
              Colors.black,
              theme.brightness == Brightness.dark ? 0.45 : 0.25,
            ) ??
            scheme.surfaceContainerHighest.withOpacity(0.25),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: Colors.black),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricChip(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Color.lerp(
              scheme.surfaceContainerHighest,
              Colors.black,
              theme.brightness == Brightness.dark ? 0.5 : 0.3,
            ) ??
            scheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.primary.withOpacity(0.1)),
      ),
      child: Text(
        '$label: $value',
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
    );
  }

  Color _estadoColor(BuildContext context, String estado) {
    final normalized = estado.trim().toLowerCase();
    if (normalized.contains('confirm')) {
      return Colors.green;
    }
    if (normalized.contains('cancel')) {
      return Colors.redAccent;
    }
    if (normalized.contains('pend')) {
      return Colors.orange;
    }
    return Theme.of(context).colorScheme.primary;
  }

  String _capitalize(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    return '${trimmed[0].toUpperCase()}${trimmed.substring(1).toLowerCase()}';
  }

  Widget _infoBadge(IconData icon, String text, BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Color.lerp(
              scheme.surfaceContainerHighest,
              Colors.black,
              scheme.brightness == Brightness.dark ? 0.5 : 0.3,
            ) ??
            scheme.surfaceContainerHighest.withOpacity(
              scheme.brightness == Brightness.dark ? 0.4 : 0.2,
            ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.black),
          const SizedBox(width: 6),
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  String _patientInitials() {
    final firstName = widget.paciente.nombres.trim();
    final lastName = widget.paciente.apellidos.trim();
    final firstInitial = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final lastInitial = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    final combined = '$firstInitial$lastInitial';
    return combined.isNotEmpty ? combined : 'SA';
  }
}
