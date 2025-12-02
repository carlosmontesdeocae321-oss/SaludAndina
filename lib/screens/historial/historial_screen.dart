import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/paciente.dart';
import '../../models/consulta.dart';
import '../../services/api_services.dart';
import '../../route_refresh_mixin.dart';
import 'agregar_editar_consulta_screen.dart';

class HistorialScreen extends StatefulWidget {
  final Paciente paciente;
  const HistorialScreen({super.key, required this.paciente});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen>
    with RouteRefreshMixin<HistorialScreen> {
  List<Consulta> consultas = [];
  bool cargando = true;
  final DateFormat _dateFormatter = DateFormat.yMMMMd('es');
  final DateFormat _timeFormatter = DateFormat.Hm();

  @override
  void initState() {
    super.initState();
    cargarConsultas();
  }

  @override
  void onRouteRefreshed() {
    try {
      cargarConsultas();
    } catch (_) {}
  }

  Future<void> cargarConsultas() async {
    setState(() => cargando = true);

    final data = await ApiService.obtenerConsultasPaciente(widget.paciente.id);
    setState(() {
      final ordered = List<Consulta>.from(data)
        ..sort((a, b) => b.fecha.compareTo(a.fecha));
      consultas = ordered;
      cargando = false;
    });
  }

  void irAgregarConsulta() async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AgregarEditarConsultaScreen(paciente: widget.paciente),
      ),
    );
    if (resultado == true) cargarConsultas();
  }

  void irEditarConsulta(Consulta c) async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AgregarEditarConsultaScreen(
          paciente: widget.paciente,
          consulta: c,
        ),
      ),
    );
    if (resultado == true) cargarConsultas();
  }

  void eliminarConsulta(Consulta c) async {
    final ok = await ApiService.eliminarHistorial(c.id);
    if (ok) cargarConsultas();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text("Historial de ${widget.paciente.nombres}"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: irAgregarConsulta,
          ),
        ],
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: cargarConsultas,
              edgeOffset: 120,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  SliverToBoxAdapter(child: _buildPatientSummary(theme)),
                  if (consultas.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(theme),
                    )
                  else ...[
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildConsultaTile(
                            context, consultas[index], index),
                        childCount: consultas.length,
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 32)),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildPatientSummary(ThemeData theme) {
    final paciente = widget.paciente;
    final total = consultas.length;
    final Consulta? lastConsulta =
        consultas.isNotEmpty ? consultas.first : null;

    final chips = <Widget>[];
    if (paciente.cedula.isNotEmpty) {
      chips
          .add(_buildSummaryChip(theme, Icons.badge_outlined, paciente.cedula));
    }
    if (paciente.telefono.isNotEmpty) {
      chips.add(
          _buildSummaryChip(theme, Icons.phone_outlined, paciente.telefono));
    }
    if (paciente.direccion.isNotEmpty) {
      chips.add(_buildSummaryChip(
          theme, Icons.location_on_outlined, paciente.direccion));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary.withOpacity(0.15),
                      theme.colorScheme.primary.withOpacity(0.04),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${paciente.nombres} ${paciente.apellidos}'.trim(),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    lastConsulta != null
                        ? 'Última consulta: ${_dateFormatter.format(lastConsulta.fecha)} · ${_timeFormatter.format(lastConsulta.fecha)}'
                        : 'Aún no registra consultas',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Consultas registradas',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$total',
                              style: theme.textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (lastConsulta != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Motivo',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 180),
                              child: Text(
                                lastConsulta.motivo.isEmpty
                                    ? 'Sin detalle'
                                    : lastConsulta.motivo,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  if (chips.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: chips,
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

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.medical_information_outlined,
              size: 72,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'No hay consultas registradas',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Agrega la primera consulta para llevar el historial clínico del paciente.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: irAgregarConsulta,
              icon: const Icon(Icons.add),
              label: const Text('Registrar consulta'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsultaTile(
      BuildContext context, Consulta consulta, int index) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final orderLabel = '#${consultas.length - index}';
    final patientName =
        ('${widget.paciente.nombres} ${widget.paciente.apellidos}').trim();
    final displayName =
        patientName.isEmpty ? 'Paciente sin nombre' : patientName;
    final initials = _buildInitials(displayName);
    final hasImages = consulta.imagenes.isNotEmpty;

    final metricChips = <Widget>[];
    if (consulta.peso > 0) {
      metricChips.add(_buildMetricChip(
          theme, Icons.monitor_weight, '${_formatNumber(consulta.peso)} kg'));
    }
    if (consulta.estatura > 0) {
      metricChips.add(_buildMetricChip(
          theme, Icons.straighten, '${_formatNumber(consulta.estatura)} m'));
    }
    if (consulta.imc > 0) {
      metricChips.add(_buildMetricChip(
          theme, Icons.fitness_center, 'IMC ${_formatNumber(consulta.imc)}'));
    }
    if (consulta.presion.isNotEmpty) {
      metricChips.add(_buildMetricChip(
          theme, Icons.monitor_heart, 'Presión: ${consulta.presion}'));
    }
    if (consulta.frecuenciaCardiaca > 0) {
      metricChips.add(_buildMetricChip(
          theme, Icons.favorite_outline, '${consulta.frecuenciaCardiaca} bpm'));
    }
    if (consulta.frecuenciaRespiratoria > 0) {
      metricChips.add(_buildMetricChip(
          theme, Icons.air, '${consulta.frecuenciaRespiratoria} rpm'));
    }
    if (consulta.temperatura > 0) {
      metricChips.add(_buildMetricChip(theme, Icons.thermostat,
          '${_formatNumber(consulta.temperatura)} °C'));
    }

    final headerBadges = <Widget>[
      _buildHeaderBadge(
          theme, Icons.event, _dateFormatter.format(consulta.fecha)),
      _buildHeaderBadge(
          theme, Icons.schedule, _timeFormatter.format(consulta.fecha)),
      if (hasImages)
        _buildHeaderBadge(
          theme,
          Icons.photo_outlined,
          '${consulta.imagenes.length} imagen${consulta.imagenes.length == 1 ? '' : 'es'}',
        ),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(16, index == 0 ? 0 : 4, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: accent.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                gradient: LinearGradient(
                  colors: [
                    accent.withOpacity(0.18),
                    accent.withOpacity(0.06),
                  ],
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: theme.colorScheme.primary,
                    child: Text(
                      initials,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: headerBadges,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildOrderBadge(theme, orderLabel),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailBlock(
                    theme: theme,
                    icon: Icons.chat_bubble_outline,
                    title: 'Motivo de consulta',
                    value: consulta.motivo,
                    emptyMessage: 'No especificado',
                  ),
                  const SizedBox(height: 12),
                  _buildDetailBlock(
                    theme: theme,
                    icon: Icons.assignment_outlined,
                    title: 'Diagnóstico',
                    value: consulta.diagnostico,
                    emptyMessage: 'Sin diagnóstico registrado',
                  ),
                  const SizedBox(height: 12),
                  _buildDetailBlock(
                    theme: theme,
                    icon: Icons.medical_services_outlined,
                    title: 'Plan de tratamiento',
                    value: consulta.tratamiento,
                    emptyMessage: 'Sin tratamiento indicado',
                  ),
                  const SizedBox(height: 12),
                  _buildDetailBlock(
                    theme: theme,
                    icon: Icons.receipt_long_outlined,
                    title: 'Receta',
                    value: consulta.receta,
                    emptyMessage: 'Sin receta registrada',
                  ),
                  if (metricChips.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: metricChips,
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => irEditarConsulta(consulta),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Editar'),
                        ),
                        TextButton.icon(
                          onPressed: () => eliminarConsulta(consulta),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Eliminar'),
                          style: TextButton.styleFrom(
                            foregroundColor: theme.colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderBadge(ThemeData theme, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onPrimary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildHeaderBadge(ThemeData theme, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailBlock({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String value,
    String? emptyMessage,
  }) {
    final trimmed = value.trim();
    final isEmpty = trimmed.isEmpty;
    final content = isEmpty ? (emptyMessage ?? 'Sin registrar') : trimmed;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  content,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.35,
                    fontWeight: isEmpty ? FontWeight.w500 : FontWeight.w600,
                    color: isEmpty
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _buildInitials(String fullName) {
    final parts = fullName
        .split(RegExp(r'\s+'))
        .where((segment) => segment.trim().isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';

    String initials = parts.first.substring(0, 1).toUpperCase();
    if (parts.length > 1) {
      initials += parts[1].substring(0, 1).toUpperCase();
    } else if (parts.first.length > 1) {
      initials += parts.first.substring(1, 2).toUpperCase();
    }
    return initials;
  }

  Widget _buildSummaryChip(ThemeData theme, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(ThemeData theme, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(num value) {
    if (value == 0) return '0';
    return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  }
}
