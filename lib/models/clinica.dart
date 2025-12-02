class Clinica {
  final int id;
  final String nombre;
  final String? direccion;
  final String? imagenUrl;
  final String? telefonoContacto;
  final int? pacientes;
  final int? doctores;
  final int? capacidad;

  Clinica({
    required this.id,
    required this.nombre,
    this.direccion,
    this.imagenUrl,
    this.telefonoContacto,
    this.pacientes,
    this.doctores,
    this.capacidad,
  });

  factory Clinica.fromJson(Map<String, dynamic> json) {
    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is double) return value.round();
      return int.tryParse(value.toString());
    }

    String? parseString(dynamic value) {
      if (value == null) return null;
      final str = value.toString().trim();
      return str.isEmpty ? null : str;
    }

    final rawId = json['id'] ?? json['clinica_id'] ?? json['clinicaId'];
    final id = parseInt(rawId) ?? 0;
    final nombre =
        parseString(json['nombre'] ?? json['name'] ?? 'Clínica') ?? 'Clínica';

    return Clinica(
      id: id,
      nombre: nombre,
      direccion: parseString(
          json['direccion'] ?? json['address'] ?? json['ubicacion']),
      imagenUrl: parseString(
        json['imagen_url'] ??
            json['imagenUrl'] ??
            json['imagen'] ??
            json['logo'] ??
            json['logo_url'],
      ),
      telefonoContacto: parseString(
        json['telefono_contacto'] ??
            json['telefono'] ??
            json['phone'] ??
            json['telefonoClinica'],
      ),
      pacientes: parseInt(
        json['pacientes'] ??
            json['pacientes_count'] ??
            json['patients'] ??
            json['patients_count'],
      ),
      doctores: parseInt(
        json['doctores'] ??
            json['doctors'] ??
            json['doctores_count'] ??
            json['doctors_count'],
      ),
      capacidad: parseInt(
        json['slots_total'] ??
            json['capacidad'] ??
            json['capacity'] ??
            json['limite_pacientes'],
      ),
    );
  }
}
