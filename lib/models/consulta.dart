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
  final String notasHtml;
  final String notasHtmlFull;
  final String pacienteNombres;
  final String pacienteApellidos;
  // Examen físico fields (parsed individually when available)
  final String examenPiel;
  final String examenCabeza;
  final String examenOjos;
  final String examenNariz;
  final String examenBoca;
  final String examenOidos;
  final String examenOrofaringe;
  final String examenCuello;
  final String examenTorax;
  final String examenCamposPulm;
  final String examenRuidosCard;
  final String examenAbdomen;
  final String examenExtremidades;
  final String examenNeuro;
  final String
      otros; // campos adicionales como medidas generales / observaciones
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
    this.notasHtml = '',
    this.notasHtmlFull = '',
    this.pacienteNombres = '',
    this.pacienteApellidos = '',
    this.examenPiel = '',
    this.examenCabeza = '',
    this.examenOjos = '',
    this.examenNariz = '',
    this.examenBoca = '',
    this.examenOidos = '',
    this.examenOrofaringe = '',
    this.examenCuello = '',
    this.examenTorax = '',
    this.examenCamposPulm = '',
    this.examenRuidosCard = '',
    this.examenAbdomen = '',
    this.examenExtremidades = '',
    this.examenNeuro = '',
    this.otros = '',
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
        notasHtml: json['notas_html'] ?? json['notasHtml'] ?? '',
        notasHtmlFull: json['notas_html_full'] ?? json['notasHtmlFull'] ?? '',
        pacienteNombres: json['nombres'] ?? json['paciente_nombres'] ?? '',
        pacienteApellidos:
            json['apellidos'] ?? json['paciente_apellidos'] ?? '',
        examenPiel: json['examen_piel'] ?? json['examenPiel'] ?? '',
        examenCabeza: json['examen_cabeza'] ?? json['examenCabeza'] ?? '',
        examenOjos: json['examen_ojos'] ?? json['examenOjos'] ?? '',
        examenNariz: json['examen_nariz'] ?? json['examenNariz'] ?? '',
        examenBoca: json['examen_boca'] ?? json['examenBoca'] ?? '',
        examenOidos: json['examen_oidos'] ?? json['examenOidos'] ?? '',
        examenOrofaringe:
            json['examen_orofaringe'] ?? json['examenOrofaringe'] ?? '',
        examenCuello: json['examen_cuello'] ?? json['examenCuello'] ?? '',
        examenTorax: json['examen_torax'] ?? json['examenTorax'] ?? '',
        examenCamposPulm:
            json['examen_campos_pulm'] ?? json['examenCamposPulm'] ?? '',
        examenRuidosCard:
            json['examen_ruidos_card'] ?? json['examenRuidosCard'] ?? '',
        examenAbdomen: json['examen_abdomen'] ?? json['examenAbdomen'] ?? '',
        examenExtremidades:
            json['examen_extremidades'] ?? json['examenExtremidades'] ?? '',
        examenNeuro: json['examen_neuro'] ?? json['examenNeuro'] ?? '',
        otros: json['otros'] ?? json['medidas'] ?? '',
        fecha: _parseDate(json['fecha']),
      );
}

extension ConsultaHelpers on Consulta {
  String get pacienteFullName {
    final n = pacienteNombres.trim();
    final a = pacienteApellidos.trim();
    if (n.isEmpty && a.isEmpty) return '';
    if (n.isEmpty) return a;
    if (a.isEmpty) return n;
    return '$n $a';
  }
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
