import 'package:flutter/material.dart';

class NextAppointments extends StatelessWidget {
  final List<dynamic> appointments;
  const NextAppointments({super.key, required this.appointments});

  @override
  Widget build(BuildContext context) {
    if (appointments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12.0),
        child: Text('No hay próximas citas'),
      );
    }

    return Column(
      children: appointments.map((a) {
        // a is expected to have .fecha (DateTime) and paciente/doctor fields or map keys
        String time = '';
        String title = '';
        try {
          final fecha = a.fecha ?? a['fecha'];
          if (fecha is DateTime) {
            time =
                '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
          } else if (fecha is String) {
            time = fecha;
          }
        } catch (_) {}
        try {
          title = a.paciente?.nombre ??
              a['paciente'] ??
              a['paciente_nombre'] ??
              a['patient_name'] ??
              '';
        } catch (_) {}
        if (title == '') {
          try {
            title = a['paciente_nombre'] ?? a['nombre'] ?? a['patient'] ?? '';
          } catch (_) {}
        }

        return ListTile(
          dense: true,
          leading:
              Text(time, style: const TextStyle(fontWeight: FontWeight.w600)),
          title: Text(title.isNotEmpty ? title : 'Paciente'),
          subtitle: Text(a.doctor?.toString() ?? a['doctor']?.toString() ?? ''),
        );
      }).toList(),
    );
  }
}
