class Usuario {
  final String id;
  final String nombre;
  final String email;
  final String rol; // ejemplo: admin, medico, enfermero
  final String? clinicaId;
  final bool dueno;

  Usuario({
    required this.id,
    required this.nombre,
    required this.email,
    required this.rol,
    this.clinicaId,
    this.dueno = false,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) => Usuario(
        id: json['id'].toString(),
        nombre: json['nombre'] ?? '',
        email: json['email'] ?? '',
        rol: json['rol'] ?? '',
        clinicaId: json['clinicaId']?.toString(),
        dueno: json['dueno'] == 1 || json['dueno'] == true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'email': email,
        'rol': rol,
        if (clinicaId != null) 'clinicaId': clinicaId,
        'dueno': dueno,
      };
}
