import 'consulta.dart';
import 'cita.dart';

class Paciente {
  final String id;
  final String nombres;
  final String apellidos;
  final String cedula;
  final String telefono;
  final String direccion;
  final String fechaNacimiento;
  final List<Consulta> historial;
  final List<Cita> citas;

  Paciente({
    required this.id,
    required this.nombres,
    required this.apellidos,
    required this.cedula,
    required this.telefono,
    required this.direccion,
    required this.fechaNacimiento,
    this.historial = const [],
    this.citas = const [],
  });

  factory Paciente.fromJson(Map<String, dynamic> json) => Paciente(
        id: json['id'].toString(),
        nombres: json['nombres'],
        apellidos: json['apellidos'],
        cedula: json['cedula'],
        telefono: json['telefono'] ?? '',
        direccion: json['direccion'] ?? '',
        fechaNacimiento: json['fecha_nacimiento'], // coincide con JSON
        historial: (json['historial'] as List<dynamic>?)
                ?.map((e) => Consulta.fromJson(e))
                .toList() ??
            [],
        citas: (json['citas'] as List<dynamic>?)
                ?.map((e) => Cita.fromJson(e))
                .toList() ??
            [],
      );
}
