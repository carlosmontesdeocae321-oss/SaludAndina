import 'dart:convert';

class Consulta {
  final String id;
  final String motivo;
  final double peso;
  final double estatura;
  final double imc;
  final String presion;
  final int frecuenciaCardiaca;
  final int frecuenciaRespiratoria;
  final double temperatura;
  final String diagnostico;
  final String tratamiento;
  final String receta;
  final List<String> imagenes;
  final DateTime fecha;

  Consulta({
    required this.id,
    required this.motivo,
    required this.peso,
    required this.estatura,
    required this.imc,
    required this.presion,
    required this.frecuenciaCardiaca,
    required this.frecuenciaRespiratoria,
    required this.temperatura,
    required this.diagnostico,
    required this.tratamiento,
    required this.receta,
    this.imagenes = const [],
    required this.fecha,
  });

  factory Consulta.fromJson(Map<String, dynamic> json) => Consulta(
        id: json['id'].toString(),
        // Backend puede usar nombres con guion bajo (motivo_consulta, frecuencia_cardiaca, ...)
        motivo: json['motivo'] ?? json['motivo_consulta'] ?? '',
        peso: _toDouble(json['peso']),
        estatura: _toDouble(json['estatura']),
        imc: _toDouble(json['imc']),
        presion: json['presion'] ?? '',
        frecuenciaCardiaca:
            _toInt(json['frecuencia_cardiaca'] ?? json['frecuenciaCardiaca']),
        frecuenciaRespiratoria: _toInt(
            json['frecuencia_respiratoria'] ?? json['frecuenciaRespiratoria']),
        temperatura: _toDouble(json['temperatura']),
        diagnostico: json['diagnostico'] ?? '',
        tratamiento: json['tratamiento'] ?? '',
        receta: json['receta'] ?? '',
        imagenes: _parseImagenes(json['imagenes']),
        fecha: _parseDate(json['fecha']),
      );
}

List<String> _parseImagenes(dynamic raw) {
  if (raw == null) return [];
  if (raw is List) return raw.map((e) => e.toString()).toList();
  if (raw is String) {
    try {
      final decoded = raw.isEmpty ? [] : (jsonDecode(raw) as List<dynamic>);
      return decoded.map((e) => e.toString()).toList();
    } catch (e) {
      // Puede que venga como '[]' o como ruta simple
      return [raw];
    }
  }
  return [];
}

double _toDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is String) return double.tryParse(v.replaceAll(',', '.')) ?? 0.0;
  return 0.0;
}

int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) {
    return int.tryParse(v) ??
        (int.tryParse(double.tryParse(v.replaceAll(',', '.').toString())
                    ?.toString() ??
                '') ??
            0);
  }
  return 0;
}

DateTime _parseDate(dynamic v) {
  try {
    if (v == null) return DateTime.now();
    if (v is DateTime) return v;
    return DateTime.parse(v.toString());
  } catch (e) {
    return DateTime.now();
  }
}
