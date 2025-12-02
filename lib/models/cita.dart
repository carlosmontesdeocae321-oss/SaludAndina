class Cita {
  final String id;
  final String pacienteId;
  final DateTime fecha;
  final String hora;
  final String motivo;
  final String estado; // pendiente, confirmada, cancelada
  final String? nombres;
  final String? apellidos;
  final int? clinicaId;
  final int? doctorId;

  Cita({
    required this.id,
    required this.pacienteId,
    required this.fecha,
    required this.hora,
    required this.motivo,
    required this.estado,
    this.nombres,
    this.apellidos,
    this.clinicaId,
    this.doctorId,
  });

  factory Cita.fromJson(Map<String, dynamic> json) => Cita(
        id: json['id'].toString(),
        pacienteId:
            (json['paciente_id'] ?? json['paciente'] ?? json['pacienteId'])
                .toString(),
        fecha: DateTime.parse(json['fecha']),
        hora: json['hora'],
        motivo: json['motivo'] ?? '',
        estado: json['estado'] ?? '',
        nombres: json['nombres']?.toString(),
        apellidos: json['apellidos']?.toString(),
        clinicaId: json['clinica_id'] != null
            ? int.tryParse(json['clinica_id'].toString())
            : (json['clinicaId'] != null
                ? int.tryParse(json['clinicaId'].toString())
                : null),
        doctorId: json['doctor_id'] != null
            ? int.tryParse(json['doctor_id'].toString())
            : (json['doctorId'] != null
                ? int.tryParse(json['doctorId'].toString())
                : null),
      );
}
