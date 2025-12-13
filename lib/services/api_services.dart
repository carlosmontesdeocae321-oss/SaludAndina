import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import '../models/paciente.dart';
import '../models/consulta.dart';
import '../models/cita.dart';
import '../models/clinica.dart';

class ApiService {
  static Future<Map<String, dynamic>> registrarDoctorIndividual(
      String usuario, String clave) async {
    final url = Uri.parse('$baseUrl/api/usuarios');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'usuario': usuario,
        'clave': clave,
        'rol': 'doctor',
        // No se asocia a una clínica, es individual
      }),
    );
    if (res.statusCode == 201) {
      return {'ok': true};
    } else {
      try {
        final data = jsonDecode(res.body);
        return {
          'ok': false,
          'error': data['error'] ?? data['message'] ?? 'Error desconocido'
        };
      } catch (e) {
        return {'ok': false, 'error': 'Error desconocido'};
      }
    }
  }

  static Future<Map<String, dynamic>> syncGoogleUser({
    required String idToken,
    required String firebaseUid,
    String? email,
    String? displayName,
  }) async {
    final url = Uri.parse('$baseUrl/api/usuarios/google-auth');
    try {
      final res = await http.post(
        url,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'idToken': idToken,
          'email': email,
          'displayName': displayName,
          'firebaseUid': firebaseUid,
        }),
      );

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        final ok = decoded['ok'] == true;
        return {
          'ok': ok,
          'data': decoded['data'],
          'message': decoded['message'],
        };
      }

      try {
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        return {
          'ok': false,
          'message': decoded['message'] ??
              decoded['error'] ??
              'Error al registrar con Google.',
        };
      } catch (_) {
        return {
          'ok': false,
          'message': 'Error al registrar con Google. Código ${res.statusCode}',
        };
      }
    } catch (e) {
      return {
        'ok': false,
        'message': 'No se pudo contactar al servidor: $e',
      };
    }
  }

  static Future<bool> eliminarUsuario(String id) async {
    final url = Uri.parse('$baseUrl/api/usuarios/$id');
    final headers = await _getHeaders();
    final res = await http.delete(url, headers: headers);
    return res.statusCode == 200;
  }

  static Future<bool> eliminarClinica(int id) async {
    final url = Uri.parse('$baseUrl/api/clinicas/$id');
    final headers = await _getHeaders();
    final res = await http.delete(url, headers: headers);
    return res.statusCode == 200;
  }

  // Use a compile-time define so we can override with --dart-define=BASE_URL="https://..."
  // Default points to the deployed backend for quick testing.
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://saludandina.onrender.com',
  );

  // Simple in-memory cache for profile lookups to avoid repeated network churn
  static final Map<int, Map<String, dynamic>> _profileCache = {};

  static void _log(String message) {
    developer.log(message, name: 'ApiService');
  }

  // Last raw response body from create/edit calls (for UI debugging)
  static String? lastErrorBody;

  // Invalidate cached profile for a user id (use after updates)
  static void invalidateProfileCache(int usuarioId) {
    try {
      _profileCache.remove(usuarioId);
    } catch (_) {}
  }

  // 🔹 Obtener headers con rol y usuario
  static Future<Map<String, String>> _getHeaders(
      {bool jsonType = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final usuario = prefs.getString('usuario') ?? '';
    String? clave;
    try {
      const _secure = FlutterSecureStorage();
      clave = await _secure.read(key: 'clave');
    } catch (_) {
      clave = prefs.getString('clave') ?? '';
    }
    final firebaseUid = prefs.getString('firebaseUid') ?? '';

    // El backend espera headers con prefijo `x-` (ver middleware auth.js)
    final headers = <String, String>{};
    if (usuario.isNotEmpty) headers['x-usuario'] = usuario;
    if (clave != null && clave.isNotEmpty) headers['x-clave'] = clave;
    if (firebaseUid.isNotEmpty) headers['x-firebase-uid'] = firebaseUid;

    if (jsonType) {
      headers['Content-Type'] = 'application/json';
    }

    return headers;
  }

  static bool _hasAuthHeaders(Map<String, String> headers) {
    return headers.containsKey('x-usuario') ||
        headers.containsKey('x-clave') ||
        headers.containsKey('x-firebase-uid');
  }

  // Returns true if stored credentials exist (basic check for x-usuario/x-clave)
  static Future<bool> isAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    final usuario = prefs.getString('usuario') ?? '';
    final clave = prefs.getString('clave') ?? '';
    final firebaseUid = prefs.getString('firebaseUid') ?? '';
    if (firebaseUid.isNotEmpty) return true;
    return usuario.isNotEmpty && clave.isNotEmpty;
  }

  // Obtener perfil público sin enviar headers (para vistas públicas)
  static Future<Map<String, dynamic>?> obtenerPerfilDoctorPublic(
      int doctorId) async {
    try {
      final cached = _profileCache[doctorId];
      if (cached != null) return Map<String, dynamic>.from(cached);
    } catch (_) {}
    try {
      final pub = Uri.parse('$baseUrl/api/usuarios/public/$doctorId');
      _log('📌 obtenerPerfilDoctorPublic - GET $pub');
      final res = await http.get(pub);
      _log('📌 obtenerPerfilDoctorPublic - status: ${res.statusCode}');
      if (res.statusCode == 200) {
        try {
          final decoded = jsonDecode(res.body);
          Map<String, dynamic>? map;
          if (decoded is Map<String, dynamic>) {
            if (decoded.length == 1 &&
                decoded.containsKey('data') &&
                decoded['data'] is Map<String, dynamic>) {
              map = Map<String, dynamic>.from(decoded['data']);
            } else {
              map = Map<String, dynamic>.from(decoded);
            }
          } else if (decoded is List && decoded.isNotEmpty) {
            final first = decoded.first;
            if (first is Map<String, dynamic>) {
              map = Map<String, dynamic>.from(first);
            }
          }
          if (map != null) {
            // Some public payloads do not expose specialty/patient count; attempt to
            // merge doctor_profiles when available (unauthenticated GET is allowed).
            try {
              final ext = await obtenerPerfilDoctorExtendidoPublic(doctorId);
              if (ext != null) map.addAll(ext);
            } catch (_) {}

            try {
              _profileCache[doctorId] = Map<String, dynamic>.from(map);
            } catch (_) {}
            _log('📌 obtenerPerfilDoctorPublic - keys: ${map.keys}');
            return map;
          }
        } catch (_) {
          return null;
        }
      }
    } catch (e) {
      _log('❌ obtenerPerfilDoctorPublic - error: $e');
    }
    return null;
  }

  // view: 'individual' | 'clinica' | 'both' | null
  static Future<List<Paciente>> obtenerPacientesPorClinica(
      {String? view}) async {
    final prefs = await SharedPreferences.getInstance();
    final clinicaId = prefs.getString('clinicaId') ?? '';

    String endpoint;
    if (clinicaId.isEmpty) {
      // Doctor individual -> pedir al endpoint general; el backend usa headers para saber el usuario
      endpoint = '$baseUrl/api/pacientes';
      if (view != null && view.isNotEmpty) {
        endpoint += '?view=${Uri.encodeComponent(view)}';
      }
    } else {
      // Para usuarios con clínica, llamamos al endpoint general y el middleware
      // `filtroClinica` asignará req.clinica_id; usamos query param view
      endpoint = '$baseUrl/api/pacientes';
      if (view != null && view.isNotEmpty) {
        endpoint += '?view=${Uri.encodeComponent(view)}';
      }
    }

    final url = Uri.parse(endpoint);
    final headers = await _getHeaders();

    _log("📌 Cargando pacientes desde $endpoint");
    _log("📌 Headers enviados: $headers");

    final res = await http.get(url, headers: headers);

    _log("📌 Respuesta (${res.statusCode}): ${res.body}");

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as List<dynamic>;
      return data.map((json) => Paciente.fromJson(json)).toList();
    }

    _log("📌 Error al cargar pacientes: ${res.statusCode}");
    return [];
  }

  static Future<Map<String, dynamic>?> buscarPacientePorCedula(
      String cedula) async {
    final url = Uri.parse('$baseUrl/api/pacientes/cedula/$cedula');
    final headers = await _getHeaders();

    _log('📌 buscarPacientePorCedula - GET $url');
    _log('📌 Headers: $headers');
    final res = await http.get(url, headers: headers);
    _log('📌 Response: ${res.statusCode} ${res.body}');

    final status = res.statusCode;
    try {
      final parsed = jsonDecode(res.body);
      if (status == 200 && parsed is Map<String, dynamic>) {
        return {'ok': true, 'status': status, 'data': parsed};
      }
      return {'ok': false, 'status': status, 'body': parsed};
    } catch (e) {
      return {'ok': false, 'status': status, 'body': res.body};
    }
  }

  static Future<Map<String, dynamic>?> buscarPacientePorCedulaGlobal(
      String cedula) async {
    final url = Uri.parse('$baseUrl/api/pacientes/cedula/$cedula/global');
    final headers = await _getHeaders();
    _log('📌 buscarPacientePorCedulaGlobal - GET $url');
    _log('📌 Headers: $headers');
    final res = await http.get(url, headers: headers);
    _log('📌 Response: ${res.statusCode} ${res.body}');

    final status = res.statusCode;
    try {
      final parsed = jsonDecode(res.body);
      if (status == 200 && parsed is Map<String, dynamic>) {
        return {'ok': true, 'status': status, 'data': parsed};
      }
      return {'ok': false, 'status': status, 'body': parsed};
    } catch (e) {
      return {'ok': false, 'status': status, 'body': res.body};
    }
  }

  static Future<Map<String, dynamic>> crearPaciente(
      Map<String, dynamic> data) async {
    final url = Uri.parse('$baseUrl/api/pacientes');
    final headers = await _getHeaders(jsonType: true);
    // Attach an Idempotency-Key to avoid duplicate creations from retries/offline sync
    try {
      final id = const Uuid().v4();
      headers['Idempotency-Key'] = id;
      _log('📌 crearPaciente - Idempotency-Key: $id');
    } catch (_) {}
    try {
      final body = jsonEncode(data);
      _log('📤 crearPaciente - POST $url');
      _log('📤 Headers: $headers');
      _log('📤 Body: $body');

      final res = await http.post(url, headers: headers, body: body);
      _log('📥 crearPaciente - status: ${res.statusCode} body: ${res.body}');
      if (res.statusCode == 200 || res.statusCode == 201) {
        return {'ok': true, 'message': 'Paciente creado correctamente'};
      } else {
        try {
          final d = jsonDecode(res.body);
          return {
            'ok': false,
            'message': d['error'] ?? d['message'] ?? 'Error desconocido'
          };
        } catch (_) {
          return {'ok': false, 'message': 'Error desconocido'};
        }
      }
    } catch (e) {
      return {'ok': false, 'message': e.toString()};
    }
  }

  static Future<bool> editarPaciente(
      String id, Map<String, dynamic> data) async {
    final url = Uri.parse('$baseUrl/api/pacientes/$id');
    final headers = await _getHeaders(jsonType: true);
    final res = await http.put(url, headers: headers, body: jsonEncode(data));
    return res.statusCode == 200;
  }

  static Future<bool> eliminarPaciente(String id) async {
    try {
      final url = Uri.parse('$baseUrl/api/pacientes/$id');
      final headers = await _getHeaders();

      final res = await http.delete(url, headers: headers);
      _log('📌 Eliminar paciente $id -> ${res.statusCode} ${res.body}');
      return res.statusCode == 200;
    } catch (e) {
      _log('❌ Error eliminarPaciente: $e');
      return false;
    }
  }

  // ===================== HISTORIAL / CONSULTAS =====================
  static Future<List<Consulta>> obtenerConsultasPaciente(
      String pacienteId) async {
    final url = Uri.parse('$baseUrl/api/historial/paciente/$pacienteId');
    final headers = await _getHeaders();

    if (!_hasAuthHeaders(headers)) {
      _log(
          '📌 obtenerConsultasPaciente - sin headers de autenticación, usando fallback local');
      return [];
    }

    _log('📌 obtenerConsultasPaciente - GET $url');
    _log('📌 Headers: $headers');

    final res = await http.get(url, headers: headers);
    _log(
        '📌 obtenerConsultasPaciente - status: ${res.statusCode} body: ${res.body}');

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as List<dynamic>;
      return data.map((json) => Consulta.fromJson(json)).toList();
    }
    return [];
  }

  static Future<Consulta?> obtenerConsultaPorId(String id) async {
    final url = Uri.parse('$baseUrl/api/historial/detalle/$id');
    final headers = await _getHeaders();
    final res = await http.get(url, headers: headers);

    if (res.statusCode == 200) {
      return Consulta.fromJson(jsonDecode(res.body));
    }
    return null;
  }

  static Future<Map<String, dynamic>?> obtenerPacientePorId(String id) async {
    try {
      final url = Uri.parse('$baseUrl/api/pacientes/$id');
      final headers = await _getHeaders();
      final res = await http.get(url, headers: headers);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      _log('❌ obtenerPacientePorId - error: $e');
    }
    return null;
  }

  static Future<bool> crearHistorial(
      Map<String, String> data, List<String> archivos) async {
    final url = Uri.parse('$baseUrl/api/historial');
    final request = http.MultipartRequest('POST', url);
    final headers = await _getHeaders();
    // Generate and attach an Idempotency-Key so server-side idempotency can work
    try {
      final id = const Uuid().v4();
      headers['Idempotency-Key'] = id;
      _log('📤 crearHistorial - Idempotency-Key: $id');
    } catch (_) {}
    request.headers.addAll(headers);

    // Depuración: imprimir lo que vamos a enviar
    _log('📤 crearHistorial - fields: $data');
    _log('📤 crearHistorial - archivos: $archivos');

    data.forEach((k, v) => request.fields[k] = v);
    for (var f in archivos) {
      request.files.add(await http.MultipartFile.fromPath('imagenes', f));
    }

    final streamed = await request.send();
    final respBody = await streamed.stream.bytesToString();
    _log('📥 crearHistorial - status: ${streamed.statusCode} body: $respBody');

    if (streamed.statusCode == 200 || streamed.statusCode == 201) {
      lastErrorBody = null;
      return true;
    }
    // store body for UI debugging
    lastErrorBody = respBody;
    return false;
  }

  static Future<bool> editarHistorial(
      String id, Map<String, String> data, List<String> archivos) async {
    final url = Uri.parse('$baseUrl/api/historial/$id');
    final request = http.MultipartRequest('PUT', url);
    final headers = await _getHeaders();
    request.headers.addAll(headers);

    data.forEach((k, v) => request.fields[k] = v);
    for (var f in archivos) {
      request.files.add(await http.MultipartFile.fromPath('imagenes', f));
    }

    final res = await request.send();
    final respBody = await res.stream.bytesToString();
    if (res.statusCode == 200) {
      lastErrorBody = null;
      return true;
    }
    lastErrorBody = respBody;
    _log('📥 editarHistorial - status: ${res.statusCode} body: $respBody');
    return false;
  }

  static Future<bool> eliminarHistorial(String id) async {
    final url = Uri.parse('$baseUrl/api/historial/$id');
    final headers = await _getHeaders();
    final res = await http.delete(url, headers: headers);
    return res.statusCode == 200;
  }

  // ===================== CITAS - acciones administrativas =====================
  static Future<bool> actualizarCita(
      String id, Map<String, dynamic> data) async {
    final url = Uri.parse('$baseUrl/api/citas/$id');
    final headers = await _getHeaders(jsonType: true);

    _log('📌 actualizarCita - PUT $url');
    _log('📤 Payload: $data');

    final res = await http.put(url, headers: headers, body: jsonEncode(data));
    _log('📥 actualizarCita - status: ${res.statusCode} body: ${res.body}');
    return res.statusCode == 200;
  }

  static Future<Map<String, dynamic>?> obtenerCitaPorId(String id) async {
    final url = Uri.parse('$baseUrl/api/citas/$id');
    final headers = await _getHeaders();
    _log('📌 obtenerCitaPorId - GET $url');
    final res = await http.get(url, headers: headers);
    _log('📥 obtenerCitaPorId - status: ${res.statusCode} body: ${res.body}');
    if (res.statusCode == 200) {
      try {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return data;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  static Future<bool> eliminarCita(String id) async {
    final url = Uri.parse('$baseUrl/api/citas/$id');
    final headers = await _getHeaders();

    _log('📌 eliminarCita - DELETE $url');
    final res = await http.delete(url, headers: headers);
    _log('📥 eliminarCita - status: ${res.statusCode} body: ${res.body}');
    return res.statusCode == 200;
  }

  // ===================== CITAS =====================
  static Future<List<Cita>> obtenerCitasPaciente(String pacienteId) async {
    // El backend no expone una ruta específica por paciente en todas las versiones,
    // así que obtenemos todas las citas y filtramos por `paciente_id` en cliente.
    final todas = await obtenerCitas();
    return todas.where((c) => c.pacienteId == pacienteId).toList();
  }

  static Future<List<Cita>> obtenerCitas() async {
    final url = Uri.parse('$baseUrl/api/citas');
    final headers = await _getHeaders();

    if (!_hasAuthHeaders(headers)) {
      _log(
          '📌 obtenerCitas - sin headers de autenticación, retornando lista vacía');
      return [];
    }

    _log('📌 obtenerCitas - GET $url');
    _log('📌 obtenerCitas - Headers: $headers');
    final res = await http.get(url, headers: headers);
    _log('📌 obtenerCitas - status: ${res.statusCode}');
    // Log body for debugging when API returns unexpected content (HTML/404 etc.)
    _log('📌 obtenerCitas - body: ${res.body}');

    if (res.statusCode == 200) {
      try {
        final data = jsonDecode(res.body) as List<dynamic>;
        _log('📌 obtenerCitas - total recibidas: ${data.length}');
        return data.map((json) => Cita.fromJson(json)).toList();
      } catch (e) {
        _log('❌ obtenerCitas - error parseando JSON: $e');
        return [];
      }
    }
    return [];
  }

  static Future<bool> agendarCita(Map<String, dynamic> data) async {
    final url = Uri.parse('$baseUrl/api/citas');
    final headers = await _getHeaders(jsonType: true);
    // Add Idempotency-Key to protect against duplicate POST retries
    try {
      final id = const Uuid().v4();
      headers['Idempotency-Key'] = id;
      _log('📌 agendarCita - Idempotency-Key: $id');
    } catch (_) {}

    _log('📌 agendarCita - POST $url');
    _log('📌 Headers: $headers');
    _log('📤 Payload: $data');

    final res = await http.post(url, headers: headers, body: jsonEncode(data));
    _log('📥 agendarCita - status: ${res.statusCode} body: ${res.body}');

    // El backend devuelve 201 al crear correctamente
    return res.statusCode == 200 || res.statusCode == 201;
  }

  static Future<List<Clinica>> obtenerClinicas() async {
    final url = Uri.parse('$baseUrl/api/clinicas');
    final headers = await _getHeaders();
    _log('📌 GET $url');
    final res = await http.get(url, headers: headers);
    _log('📌 Respuesta (${res.statusCode}): ${res.body}');
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as List<dynamic>;
      return data.map((json) => Clinica.fromJson(json)).toList();
    }
    _log('📌 Error al cargar clínicas: ${res.statusCode}');
    return [];
  }

  // Devuelve la respuesta raw (lista de mapas) tal como viene del backend.
  // Útil cuando se necesita acceder a campos no mapeados por la clase `Clinica`.
  static Future<List<Map<String, dynamic>>> obtenerClinicasRaw() async {
    final url = Uri.parse('$baseUrl/api/clinicas');
    final headers = await _getHeaders();
    _log('📌 GET (raw) $url');
    try {
      final res = await http.get(url, headers: headers);
      _log('📌 Respuesta raw (${res.statusCode}): ${res.body}');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List<dynamic>;
        return List<Map<String, dynamic>>.from(
            data.map((e) => Map<String, dynamic>.from(e as Map)));
      }
    } catch (e) {
      _log('❌ obtenerClinicasRaw - error: $e');
    }
    return [];
  }

  // Obtener mis compras de promociones (usuario autenticado)
  static Future<List<Map<String, dynamic>>> obtenerMisCompras() async {
    final url = Uri.parse('$baseUrl/api/compras_promociones/mis');
    final headers = await _getHeaders();
    _log('📌 obtenerMisCompras - GET $url');
    final res = await http.get(url, headers: headers);
    _log('📌 obtenerMisCompras - status: ${res.statusCode} body: ${res.body}');
    if (res.statusCode == 200) {
      try {
        final data = jsonDecode(res.body) as List<dynamic>;
        return List<Map<String, dynamic>>.from(
            data.map((e) => Map<String, dynamic>.from(e as Map)));
      } catch (e) {
        _log('❌ obtenerMisCompras parse error: $e');
      }
    }
    return [];
  }

  static Future<bool> cancelarCompraPromocion(int compraId) async {
    final url = Uri.parse('$baseUrl/api/compras_promociones/$compraId');
    final headers = await _getHeaders();
    _log('📌 cancelarCompraPromocion - DELETE $url');
    try {
      final res = await http.delete(url, headers: headers);
      _log(
          '📌 cancelarCompraPromocion - status: ${res.statusCode} body: ${res.body}');
      return res.statusCode == 200 ||
          res.statusCode == 204 ||
          res.statusCode == 202;
    } catch (e) {
      _log('❌ cancelarCompraPromocion - exception: $e');
      return false;
    }
  }

  // Enviar datos adicionales para una compra (ej: nombre_clinica, direccion, telefono, foto)
  static Future<bool> enviarDatosCompra(int compraId, Map<String, dynamic> data,
      {String? imagePath}) async {
    final url = Uri.parse('$baseUrl/api/compras_promociones/$compraId/datos');
    _log('📌 enviarDatosCompra - POST $url imagePath: $imagePath');
    try {
      if (imagePath != null && imagePath.isNotEmpty) {
        final request = http.MultipartRequest('POST', url);
        final headers = await _getHeaders();
        try {
          final id = const Uuid().v4();
          headers['Idempotency-Key'] = id;
          _log('📌 enviarDatosCompra (multipart) - Idempotency-Key: $id');
        } catch (_) {}
        request.headers.addAll(headers);
        data.forEach((k, v) {
          if (v != null) request.fields[k] = v.toString();
        });
        try {
          request.files
              .add(await http.MultipartFile.fromPath('foto', imagePath));
        } catch (e) {
          _log('❌ enviarDatosCompra - error attaching image: $e');
        }
        final streamed = await request.send();
        final body = await streamed.stream.bytesToString();
        _log(
            '📌 enviarDatosCompra - multipart status: ${streamed.statusCode} body: $body');
        return streamed.statusCode == 200 || streamed.statusCode == 201;
      } else {
        final headers = await _getHeaders(jsonType: true);
        final res =
            await http.post(url, headers: headers, body: jsonEncode(data));
        _log(
            '📌 enviarDatosCompra - status: ${res.statusCode} body: ${res.body}');
        return res.statusCode == 200 || res.statusCode == 201;
      }
    } catch (e) {
      _log('❌ enviarDatosCompra - exception: $e');
      return false;
    }
  }

  // Obtener estadísticas agregadas de una clínica
  static Future<Map<String, dynamic>?> obtenerEstadisticasClinica(
      int clinicaId) async {
    final url = Uri.parse('$baseUrl/api/clinicas/$clinicaId/estadisticas');
    final headers = await _getHeaders();
    _log('📌 obtenerEstadisticasClinica - GET $url');
    final res = await http.get(url, headers: headers);
    _log(
        '📌 obtenerEstadisticasClinica - status: ${res.statusCode} body: ${res.body}');
    if (res.statusCode == 200) {
      try {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }
    }
    // Fallback: try to GET the clinic resource and return some basic info if available
    try {
      final altUrl = Uri.parse('$baseUrl/api/clinicas/$clinicaId');
      final altRes = await http.get(altUrl, headers: headers);
      _log(
          '📌 obtenerEstadisticasClinica - fallback GET $altUrl -> ${altRes.statusCode}');
      if (altRes.statusCode == 200) {
        try {
          final d = jsonDecode(altRes.body) as Map<String, dynamic>;
          // Map a few common keys into a stats-like map
          return {
            'clinic': d,
            'patients': d['patients_count'] ?? d['pacientes'],
            'doctors': d['doctors_count'] ?? d['doctores'],
            'slots_total': d['slots_total'] ?? d['capacity'],
          };
        } catch (_) {
          return null;
        }
      }
    } catch (_) {}

    // Último recurso: si el endpoint de estadísticas/clínica no existe,
    // intentamos usar `mis-datos` para extraer información de la clínica
    try {
      final me = await obtenerMisDatos();
      if (me != null) {
        final cid = me['clinicaId'] ??
            me['clinica_id'] ??
            me['clinic_id'] ??
            me['clinica'];
        final cname =
            me['clinica_nombre'] ?? me['clinic_name'] ?? me['clinicaName'];
        if (cid != null) {
          return {
            'clinic': {'id': cid, 'name': cname ?? 'Mi Clínica'},
            'patients': me['totalPacientes'] ?? me['patients'],
            'doctors': me['totalDoctores'] ?? me['doctors'],
            'note':
                'Datos obtenidos desde /api/usuarios/mis-datos como fallback'
          };
        }
      }
    } catch (_) {}

    return null;
  }

  // Obtener info básica de una clínica por ID
  static Future<Map<String, dynamic>?> obtenerClinica(int clinicaId) async {
    final url = Uri.parse('$baseUrl/api/clinicas/$clinicaId');
    final headers = await _getHeaders();
    try {
      final res = await http.get(url, headers: headers);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  // Obtener lista de usuario_ids que fueron comprados/vinculados por una clínica
  static Future<List<int>> obtenerUsuariosCompradosPorClinica(
      int clinicaId) async {
    final url = Uri.parse('$baseUrl/api/compras_doctores/usuarios/$clinicaId');
    final headers = await _getHeaders();
    _log('📌 obtenerUsuariosCompradosPorClinica - GET $url');
    final res = await http.get(url, headers: headers);
    _log(
        '📌 obtenerUsuariosCompradosPorClinica - status: ${res.statusCode} body: ${res.body}');
    if (res.statusCode == 200) {
      try {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final list = data['usuarios'] as List<dynamic>? ?? [];
        return list
            .map((e) => int.tryParse(e.toString()) ?? 0)
            .where((v) => v != 0)
            .toList();
      } catch (e) {
        _log('❌ error parseando usuarios comprados: $e');
      }
    }
    return [];
  }

  static Future<Map<String, dynamic>> actualizarPerfilClinica({
    required int clinicaId,
    String? direccion,
    String? telefonoContacto,
    String? imagenUrl,
    String? imagenPath,
  }) async {
    final uri = Uri.parse('$baseUrl/api/clinicas/$clinicaId/perfil');
    final headers = await _getHeaders();
    final request = http.MultipartRequest('PUT', uri);
    request.headers.addAll(headers);

    if (direccion != null) request.fields['direccion'] = direccion;
    if (telefonoContacto != null) {
      request.fields['telefono_contacto'] = telefonoContacto;
    }
    if (imagenUrl != null) request.fields['imagen_url'] = imagenUrl;
    if (imagenPath != null) {
      try {
        request.files
            .add(await http.MultipartFile.fromPath('imagen', imagenPath));
      } catch (_) {}
    }

    try {
      final streamed = await request.send();
      final body = await streamed.stream.bytesToString();
      if (streamed.statusCode == 200) {
        try {
          final data = jsonDecode(body) as Map<String, dynamic>;
          return {'ok': true, 'data': data};
        } catch (_) {
          return {'ok': true, 'raw': body};
        }
      }
      return {'ok': false, 'status': streamed.statusCode, 'body': body};
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    }
  }

  // Obtener perfil público/completo de un doctor por ID
  static Future<Map<String, dynamic>> obtenerPerfilDoctor(int doctorId) async {
    final headers = await _getHeaders();

    // Return cached profile if present
    try {
      final cached = _profileCache[doctorId];
      if (cached != null) return {'ok': true, 'data': cached};
    } catch (_) {}
    // Intentamos la ruta preferida primero
    final primary = Uri.parse('$baseUrl/api/usuarios/$doctorId/perfil');
    _log('📌 obtenerPerfilDoctor - GET $primary');
    var res = await http.get(primary, headers: headers);
    _log('📌 obtenerPerfilDoctor - status: ${res.statusCode}');
    if (res.statusCode == 200) {
      try {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        // cache and return
        try {
          _profileCache[doctorId] = Map<String, dynamic>.from(data);
        } catch (_) {}
        return {'ok': true, 'data': data};
      } catch (_) {
        return {
          'ok': false,
          'status': res.statusCode,
          'body': res.body,
          'url': primary.toString()
        };
      }
    }

    // Si la ruta no existe (404) o devuelve otro error, probamos rutas alternativas
    // Alternativa 1: /api/usuarios/perfil/{id}
    try {
      final alt1 = Uri.parse('$baseUrl/api/usuarios/perfil/$doctorId');
      _log('📌 obtenerPerfilDoctor - intentando alternativa $alt1');
      res = await http.get(alt1, headers: headers);
      _log('📌 alt1 status: ${res.statusCode}');
      if (res.statusCode == 200) {
        try {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          try {
            _profileCache[doctorId] = Map<String, dynamic>.from(data);
          } catch (_) {}
          return {'ok': true, 'data': data};
        } catch (_) {
          return {
            'ok': false,
            'status': res.statusCode,
            'body': res.body,
            'url': alt1.toString()
          };
        }
      }
    } catch (_) {}

    // Alternativa 2: /api/usuarios/$id  (el backend puede devolver todo el usuario)
    try {
      final alt2 = Uri.parse('$baseUrl/api/usuarios/$doctorId');
      _log('📌 obtenerPerfilDoctor - intentando alternativa $alt2');
      res = await http.get(alt2, headers: headers);
      _log('📌 alt2 status: ${res.statusCode}');
      if (res.statusCode == 200) {
        try {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          try {
            _profileCache[doctorId] = Map<String, dynamic>.from(data);
          } catch (_) {}
          return {'ok': true, 'data': data};
        } catch (_) {
          return {
            'ok': false,
            'status': res.statusCode,
            'body': res.body,
            'url': alt2.toString()
          };
        }
      }
    } catch (_) {}

    // Si las rutas protegidas devolvieron 401, intentar endpoint público
    try {
      final pub = Uri.parse('$baseUrl/api/usuarios/public/$doctorId');
      _log('📌 obtenerPerfilDoctor - intentando pública $pub');
      final resPub = await http.get(pub);
      _log('📌 public status: ${resPub.statusCode}');
      if (resPub.statusCode == 200) {
        try {
          final data = jsonDecode(resPub.body) as Map<String, dynamic>;
          try {
            _profileCache[doctorId] = Map<String, dynamic>.from(data);
          } catch (_) {}
          return {'ok': true, 'data': data};
        } catch (_) {
          return {
            'ok': false,
            'status': resPub.statusCode,
            'body': resPub.body,
            'url': pub.toString()
          };
        }
      }
    } catch (e) {
      _log('❌ obtenerPerfilDoctor pública - error: $e');
    }

    // Ninguna ruta devolvió 200: devolver diagnóstico para la UI
    // Antes de devolver error, intentamos usar `mis-datos` como último recurso.
    try {
      final me = await obtenerMisDatos();
      if (me != null) {
        // Si `mis-datos` tiene un id y coincide con el solicitado, úsalo.
        final myId = me['id'] ?? me['usuarioId'] ?? me['userId'];
        if (myId != null && myId.toString() == doctorId.toString()) {
          return {'ok': true, 'data': me};
        }
        // Si no coincide, pero el usuario autenticado es un doctor sin clínica
        // y su rol indica doctor, devolvemos sus datos para que pueda verse.
        final rol = me['rol'] ?? me['role'];
        if (rol != null && rol.toString().toLowerCase().contains('doctor')) {
          return {'ok': true, 'data': me};
        }
      }
    } catch (_) {}

    return {
      'ok': false,
      'status': res.statusCode,
      'body': res.body,
      'url': res.request?.url.toString() ??
          '$baseUrl/api/usuarios/$doctorId/perfil'
    };
  }

  // Verificar si un usuario (nombre) está disponible
  static Future<bool> verificarUsuarioDisponible(String usuario) async {
    final url = Uri.parse(
        '$baseUrl/api/usuarios/check?usuario=${Uri.encodeComponent(usuario)}');
    final headers = await _getHeaders();
    final res = await http.get(url, headers: headers);
    if (res.statusCode == 200) {
      try {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return !(data['exists'] == true);
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  // ===================== COMPRAS DE PROMOCIONES =====================
  static Future<Map<String, dynamic>> comprarPromocion({
    required String titulo,
    required double monto,
    int cantidad = 1,
    int? clinicaId,
    Map<String, dynamic>? metadata,
  }) async {
    final url = Uri.parse('$baseUrl/api/compras_promociones/crear');
    final headers = await _getHeaders(jsonType: true);
    final payload = <String, dynamic>{
      'titulo': titulo,
      'monto': monto,
      'cantidad': cantidad,
    };
    if (clinicaId != null) {
      payload['clinica_id'] = clinicaId;
    }
    if (metadata != null && metadata.isNotEmpty) {
      payload['metadata'] = metadata;
    }
    final body = jsonEncode(payload);
    _log('📌 comprarPromocion - POST $url');
    _log('📤 Payload: $body');
    final res = await http.post(url, headers: headers, body: body);
    _log(
        '📥 comprarPromocion (con headers) - status: ${res.statusCode} body: ${res.body}');
    if (res.statusCode == 201) {
      return {'ok': true, 'data': jsonDecode(res.body)};
    }

    // Si el servidor responde 401 (faltan credenciales) intentamos una segunda
    // llamada sin headers para permitir la compra desde usuarios no autenticados.
    if (res.statusCode == 401) {
      try {
        _log(
            '📌 comprarPromocion - intento fallback SIN headers (usuario no autenticado)');
        final res2 = await http.post(url,
            headers: {'Content-Type': 'application/json'}, body: body);
        _log(
            '📥 comprarPromocion (sin headers) - status: ${res2.statusCode} body: ${res2.body}');
        if (res2.statusCode == 201) {
          return {'ok': true, 'data': jsonDecode(res2.body)};
        }
        // si no fue 201, continuamos y devolvemos el error del segundo intento
        try {
          final d2 = jsonDecode(res2.body);
          return {
            'ok': false,
            'error': d2['message'] ?? d2['error'] ?? 'Error desconocido'
          };
        } catch (_) {
          return {'ok': false, 'error': 'Error desconocido'};
        }
      } catch (e) {
        _log('❌ comprarPromocion fallback error: $e');
        // seguir con el parseo del primer error abajo
      }
    }

    try {
      final d = jsonDecode(res.body);
      return {
        'ok': false,
        'error': d['message'] ?? d['error'] ?? 'Error desconocido'
      };
    } catch (_) {
      return {'ok': false, 'error': 'Error desconocido'};
    }
  }

  // Subir comprobante para una compra (promoción). Intentará varios endpoints candidatos
  // y devolverá {'ok': true} si alguno responde 200/201.
  static Future<Map<String, dynamic>> subirComprobanteCompra(
      String compraId, String filePath) async {
    final headers = await _getHeaders();
    final candidates = [
      Uri.parse('$baseUrl/api/compras_promociones/$compraId/comprobante'),
      Uri.parse('$baseUrl/api/compras_promociones/$compraId/upload'),
      Uri.parse(
          '$baseUrl/api/compras_promociones/$compraId/comprobante_upload'),
      Uri.parse(
          '$baseUrl/api/compras_promociones/comprobante?compraId=$compraId'),
    ];

    String? lastBody;
    int? lastStatus;

    for (final uri in candidates) {
      try {
        _log('📌 subirComprobanteCompra - intentando $uri');
        final req = http.MultipartRequest('POST', uri);
        req.headers.addAll(headers);
        try {
          req.files
              .add(await http.MultipartFile.fromPath('comprobante', filePath));
        } catch (_) {
          try {
            req.files.add(await http.MultipartFile.fromPath('file', filePath));
          } catch (_) {}
        }

        final streamed = await req.send();
        final body = await streamed.stream.bytesToString();
        _log(
            '📌 subirComprobanteCompra - respuesta ${streamed.statusCode} desde $uri');
        _log('📌 subirComprobanteCompra - body: $body');
        lastBody = body;
        lastStatus = streamed.statusCode;
        if (streamed.statusCode == 200 || streamed.statusCode == 201) {
          try {
            final parsed = jsonDecode(body);
            return {'ok': true, 'data': parsed};
          } catch (_) {
            return {'ok': true, 'body': body};
          }
        }
      } catch (e) {
        lastBody = e.toString();
      }
    }

    // Fallback: algunos backends usan el endpoint /api/pagos/solicitar
    // que crea una solicitud de pago (tabla `pagos`) y notifica a los admins.
    // Intentamos subir ahí pasando userId y productoId=compraId para que el
    // admin lo vea en el listado de pagos pendientes.
    try {
      _log(
          '📌 subirComprobanteCompra - intentando fallback a /api/pagos/solicitar');
      final me = await obtenerMisDatos();
      final userId =
          me != null ? (me['id'] ?? me['usuarioId'] ?? me['userId']) : null;
      final uri = Uri.parse('$baseUrl/api/pagos/solicitar');
      final req = http.MultipartRequest('POST', uri);
      // Do not include auth headers: endpoint permite crear solicitudes abiertamente,
      // but include if we have them to help identify the user in some setups.
      final headers = await _getHeaders();
      if (headers.isNotEmpty) req.headers.addAll(headers);
      if (userId != null) req.fields['userId'] = userId.toString();
      req.fields['productoId'] = compraId;
      try {
        req.files
            .add(await http.MultipartFile.fromPath('comprobante', filePath));
      } catch (_) {
        try {
          req.files.add(await http.MultipartFile.fromPath('file', filePath));
        } catch (_) {}
      }
      final streamed = await req.send();
      final body = await streamed.stream.bytesToString();
      _log(
          '📌 subirComprobanteCompra - fallback /api/pagos/solicitar respuesta ${streamed.statusCode}');
      _log('📌 subirComprobanteCompra - body: $body');
      if (streamed.statusCode == 200 || streamed.statusCode == 201) {
        try {
          final parsed = jsonDecode(body);
          return {'ok': true, 'data': parsed};
        } catch (_) {
          return {'ok': true, 'body': body};
        }
      }
      lastBody = body;
      lastStatus = streamed.statusCode;
    } catch (e) {
      lastBody = e.toString();
    }

    return {
      'ok': false,
      'error':
          'No se pudo subir el comprobante a ninguno de los endpoints candidatos',
      'status': lastStatus,
      'body': lastBody
    };
  }

  static Future<bool> confirmarCompraPromocion(String compraId) async {
    final url = Uri.parse('$baseUrl/api/compras_promociones/confirmar');
    final headers = await _getHeaders(jsonType: true);
    final res = await http.post(url,
        headers: headers, body: jsonEncode({'compraId': compraId}));
    return res.statusCode == 200;
  }

  static Future<Map<String, dynamic>> crearClinica(
      String nombre, String direccion) async {
    final url = Uri.parse('$baseUrl/api/clinicas');
    final headers = await _getHeaders(jsonType: true);
    final res = await http.post(
      url,
      headers: headers,
      body: jsonEncode({'nombre': nombre, 'direccion': direccion}),
    );
    if (res.statusCode == 201) {
      try {
        final d = jsonDecode(res.body);
        return {'ok': true, 'data': d};
      } catch (_) {
        return {'ok': true, 'data': null};
      }
    }
    try {
      final d = jsonDecode(res.body);
      return {
        'ok': false,
        'error': d['error'] ?? d['message'] ?? 'Error desconocido'
      };
    } catch (_) {
      return {'ok': false, 'error': 'Error desconocido'};
    }
  }

  static Future<List<Map<String, dynamic>>> obtenerUsuariosAdmin() async {
    final url = Uri.parse('$baseUrl/api/usuarios_admin');
    final headers = await _getHeaders();
    _log('📌 obtenerUsuariosAdmin - GET $url');
    _log('📌 Headers: $headers');
    try {
      final res = await http.get(url, headers: headers);
      _log(
          '📌 obtenerUsuariosAdmin - status: ${res.statusCode} body: ${res.body}');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List<dynamic>;
        return List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      _log('❌ obtenerUsuariosAdmin - error: $e');
    }

    // Fallback 1: try /api/usuarios/public (public doctor list)
    try {
      final pub = Uri.parse('$baseUrl/api/usuarios/public');
      _log('📌 obtenerUsuariosAdmin - intentando alternativa pública $pub');
      final resPub = await http.get(pub, headers: headers);
      _log('📌 pub status: ${resPub.statusCode} body: ${resPub.body}');
      if (resPub.statusCode == 200) {
        final data = jsonDecode(resPub.body) as List<dynamic>;
        return List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      _log('❌ obtenerUsuariosAdmin pub - error: $e');
    }

    // Fallback 2: try /api/usuarios
    try {
      final alt = Uri.parse('$baseUrl/api/usuarios');
      _log('📌 obtenerUsuariosAdmin - intentando alternativa $alt');
      final res2 = await http.get(alt, headers: headers);
      _log('📌 alt status: ${res2.statusCode} body: ${res2.body}');
      if (res2.statusCode == 200) {
        final data = jsonDecode(res2.body) as List<dynamic>;
        return List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      _log('❌ obtenerUsuariosAdmin alt - error: $e');
    }

    return [];
  }

  static Future<bool> crearUsuarioAdmin({
    required String nombre,
    required String email,
    required String password,
    required int clinicaId,
    required String rol,
  }) async {
    final url = Uri.parse('$baseUrl/api/usuarios_admin');
    final headers = await _getHeaders(jsonType: true);
    final res = await http.post(
      url,
      headers: headers,
      body: jsonEncode({
        'nombre': nombre,
        'email': email,
        'password': password,
        'clinicaId': clinicaId,
        'rol': rol,
      }),
    );
    return res.statusCode == 201;
  }

  static Future<List<Map<String, dynamic>>> obtenerUsuariosPorClinica(
      int clinicaId) async {
    final url = Uri.parse('$baseUrl/api/usuarios/clinica/$clinicaId');
    final headers = await _getHeaders();
    final res = await http.get(url, headers: headers);
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as List<dynamic>;
      return List<Map<String, dynamic>>.from(data);
    }
    return [];
  }

  // Obtener datos del usuario autenticado (mis-datos)
  static Future<Map<String, dynamic>?> obtenerMisDatos() async {
    final url = Uri.parse('$baseUrl/api/usuarios/mis-datos');
    final headers = await _getHeaders();
    _log('📌 obtenerMisDatos - GET $url');
    _log('📌 Headers: $headers');
    final res = await http.get(url, headers: headers);
    _log('📥 obtenerMisDatos - status: ${res.statusCode} body: ${res.body}');
    if (res.statusCode == 200) {
      try {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  // Comprar 1 paciente extra para la clínica del usuario autenticado
  static Future<Map<String, dynamic>> comprarPacienteExtra() async {
    // Obtener clinicaId desde mis-datos
    final datos = await obtenerMisDatos();
    if (datos == null) {
      return {'ok': false, 'error': 'No autenticado'};
    }
    final clinicaId = datos['clinicaId'] ?? datos['clinica_id'];

    final url = Uri.parse('$baseUrl/api/compras_pacientes/comprar');
    final headers = await _getHeaders(jsonType: true);
    // Si no tiene clinicaId, asumimos doctor individual: el backend usará req.user para identificar al doctor
    final body = clinicaId == null
        ? jsonEncode({'monto': 1.0})
        : jsonEncode({'clinica_id': clinicaId, 'monto': 1.0});
    final res = await http.post(url, headers: headers, body: body);
    if (res.statusCode == 201) {
      try {
        return {'ok': true, 'data': jsonDecode(res.body)};
      } catch (_) {
        return {'ok': true, 'data': null};
      }
    }
    try {
      final d = jsonDecode(res.body);
      return {
        'ok': false,
        'error': d['error'] ?? d['message'] ?? 'Error desconocido'
      };
    } catch (_) {
      return {'ok': false, 'error': 'Error desconocido'};
    }
  }

  // Comprar un cupo individual para un doctor específico (forzar doctor_id)
  static Future<Map<String, dynamic>> comprarPacienteIndividual(int doctorId,
      {double monto = 1.0}) async {
    final url = Uri.parse('$baseUrl/api/compras_pacientes/comprar');
    final headers = await _getHeaders(jsonType: true);
    final body = jsonEncode({'doctor_id': doctorId, 'monto': monto});
    final res = await http.post(url, headers: headers, body: body);
    if (res.statusCode == 201) {
      try {
        return {'ok': true, 'data': jsonDecode(res.body)};
      } catch (_) {
        return {'ok': true, 'data': null};
      }
    }
    try {
      final d = jsonDecode(res.body);
      return {
        'ok': false,
        'error': d['error'] ?? d['message'] ?? 'Error desconocido'
      };
    } catch (_) {
      return {'ok': false, 'error': 'Error desconocido'};
    }
  }

  static Future<bool> vincularDoctorComoDueno(
      int doctorId, int clinicaId) async {
    final url = Uri.parse('$baseUrl/api/usuarios/vincular-dueno');
    final headers = await _getHeaders(jsonType: true);
    final res = await http.post(url,
        headers: headers,
        body: jsonEncode({'doctorId': doctorId, 'clinicaId': clinicaId}));
    return res.statusCode == 200 || res.statusCode == 201;
  }

  // Vincula al doctor con la clínica (asume que la compra ya fue realizada/confirmada)
  static Future<Map<String, dynamic>> vincularDoctorConCompra(
      int doctorId, int clinicaId) async {
    final url = Uri.parse('$baseUrl/api/vinculacion_doctor/vincular-doctor');
    final headers = await _getHeaders(jsonType: true);
    final res = await http.post(url,
        headers: headers,
        body: jsonEncode({'doctor_id': doctorId, 'clinica_id': clinicaId}));
    if (res.statusCode == 200 || res.statusCode == 201) {
      return {'ok': true};
    }
    try {
      final d = jsonDecode(res.body);
      return {
        'ok': false,
        'error': d['error'] ?? d['message'] ?? 'Error al vincular doctor'
      };
    } catch (_) {
      return {'ok': false, 'error': 'Error al vincular doctor'};
    }
  }

  // Comprar un slot de doctor (registro de compra sin crear usuario)
  static Future<Map<String, dynamic>> comprarSlotDoctor(
      {required int clinicaId, double monto = 5.0}) async {
    final url = Uri.parse('$baseUrl/api/compras_doctores/comprar-slot');
    final headers = await _getHeaders(jsonType: true);
    final body = jsonEncode({'clinica_id': clinicaId, 'monto': monto});
    final res = await http.post(url, headers: headers, body: body);
    if (res.statusCode == 201) {
      try {
        return {'ok': true, 'data': jsonDecode(res.body)};
      } catch (_) {
        return {'ok': true, 'data': null};
      }
    }
    try {
      final d = jsonDecode(res.body);
      return {
        'ok': false,
        'error': d['error'] ?? d['message'] ?? 'Error desconocido'
      };
    } catch (_) {
      return {'ok': false, 'error': 'Error desconocido'};
    }
  }

  static Future<Map<String, dynamic>> validarAgregarPacientesClinica(
      int clinicaId) async {
    final url = Uri.parse('$baseUrl/api/compras_pacientes/validar/$clinicaId');
    final headers = await _getHeaders();
    try {
      final res = await http.get(url, headers: headers);
      if (res.statusCode == 200) {
        try {
          final data = jsonDecode(res.body);
          if (data is Map<String, dynamic>) {
            return Map<String, dynamic>.from(data);
          }
        } catch (_) {}
      }
      return {'ok': false, 'permitido': false};
    } catch (e) {
      return {'ok': false, 'error': e.toString(), 'permitido': false};
    }
  }

  static Future<bool> desvincularDoctor() async {
    final url = Uri.parse('$baseUrl/api/vinculacion_doctor/desvincular-doctor');
    final headers = await _getHeaders(jsonType: true);
    final res = await http.post(url, headers: headers, body: jsonEncode({}));
    return res.statusCode == 200 || res.statusCode == 201;
  }

  // Crear clínica y usuario admin en un solo endpoint (post-compra)
  static Future<Map<String, dynamic>> crearClinicaConAdmin({
    required String nombre,
    required String direccion,
    required String usuario,
    required String clave,
  }) async {
    final url = Uri.parse('$baseUrl/api/compras_promociones/crear-clinica');
    final headers = await _getHeaders(jsonType: true);
    final body = jsonEncode({
      'nombre': nombre,
      'direccion': direccion,
      'usuario': usuario,
      'clave': clave
    });
    final res = await http.post(url, headers: headers, body: body);
    if (res.statusCode == 201) {
      try {
        return {'ok': true, 'data': jsonDecode(res.body)};
      } catch (_) {
        return {'ok': true, 'data': null};
      }
    }
    try {
      final d = jsonDecode(res.body);
      return {
        'ok': false,
        'error': d['message'] ?? d['error'] ?? 'Error desconocido'
      };
    } catch (_) {
      return {'ok': false, 'error': 'Error desconocido'};
    }
  }

  // Validar si se puede agregar un doctor a la clínica
  static Future<Map<String, dynamic>> validarAgregarDoctor(
      int clinicaId) async {
    final url = Uri.parse('$baseUrl/api/compras_doctores/validar/$clinicaId');
    final headers = await _getHeaders();
    final res = await http.get(url, headers: headers);
    if (res.statusCode == 200) {
      try {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        return {'permitido': false};
      }
    }
    return {'permitido': false};
  }

  static Future<Map<String, dynamic>> crearUsuarioClinica({
    required String usuario,
    required String clave,
    required String rol,
    required int clinicaId,
  }) async {
    // Use admin endpoint to create a clinic user (requires auth headers)
    final url = Uri.parse('$baseUrl/api/usuarios_admin');
    final headers = await _getHeaders(jsonType: true);
    final res = await http.post(
      url,
      headers: headers,
      body: jsonEncode({
        'nombre': usuario,
        'password': clave,
        'clinicaId': clinicaId,
        'rol': rol,
      }),
    );
    if (res.statusCode == 201) {
      try {
        final d = jsonDecode(res.body);
        return {'ok': true, 'data': d};
      } catch (_) {
        return {'ok': true, 'data': null};
      }
    }
    try {
      final d = jsonDecode(res.body);
      return {
        'ok': false,
        'error': d['error'] ?? d['message'] ?? 'Error desconocido'
      };
    } catch (_) {
      return {'ok': false, 'error': 'Error desconocido'};
    }
  }

  // Intento de actualizar campos del usuario (perfil).
  // No todos los backends pueden soportar esta ruta; es un intento razonable.
  static Future<Map<String, dynamic>> editarPerfilUsuario(
      int usuarioId, Map<String, dynamic> data) async {
    final url = Uri.parse('$baseUrl/api/usuarios/$usuarioId');
    final headers = await _getHeaders(jsonType: true);
    try {
      final res = await http.put(url, headers: headers, body: jsonEncode(data));
      if (res.statusCode == 200 || res.statusCode == 201) {
        try {
          return {'ok': true, 'data': jsonDecode(res.body)};
        } catch (_) {
          return {'ok': true};
        }
      }
      try {
        final d = jsonDecode(res.body);
        return {'ok': false, 'error': d['error'] ?? d['message'] ?? res.body};
      } catch (_) {
        return {'ok': false, 'error': res.body};
      }
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    }
  }

  // Intento seguro y tolerante de subir una imagen de perfil para un usuario.
  // Probará varios endpoints candidatos y no lanzará excepciones hacia el llamador.
  static Future<Map<String, dynamic>> subirImagenPerfil(
      int usuarioId, String filePath) async {
    final headers = await _getHeaders();
    // No incluimos Content-Type porque MultipartRequest lo gestionará
    final candidates = [
      Uri.parse('$baseUrl/api/usuarios/$usuarioId/avatar'),
      Uri.parse('$baseUrl/api/usuarios/$usuarioId/imagen'),
      Uri.parse('$baseUrl/api/usuarios/$usuarioId/foto'),
      Uri.parse('$baseUrl/api/usuarios/$usuarioId/upload-avatar'),
    ];

    String? lastBody;
    int? lastStatus;
    for (final uri in candidates) {
      try {
        _log('📌 subirImagenPerfil - intentando $uri');
        final req = http.MultipartRequest('POST', uri);
        req.headers.addAll(headers);
        // Try common field names the backend might expect
        try {
          req.files.add(await http.MultipartFile.fromPath('imagen', filePath));
        } catch (_) {
          try {
            req.files.add(await http.MultipartFile.fromPath('image', filePath));
          } catch (_) {}
        }
        final streamed = await req.send();
        final body = await streamed.stream.bytesToString();
        _log(
            '📌 subirImagenPerfil - respuesta ${streamed.statusCode} desde $uri');
        _log('📌 subirImagenPerfil - body: $body');
        lastBody = body;
        lastStatus = streamed.statusCode;
        if (streamed.statusCode == 200 || streamed.statusCode == 201) {
          try {
            final parsed = jsonDecode(body);
            return {
              'ok': true,
              'status': streamed.statusCode,
              'data': parsed,
              'url': uri.toString()
            };
          } catch (_) {
            return {
              'ok': true,
              'status': streamed.statusCode,
              'body': body,
              'url': uri.toString()
            };
          }
        }
      } catch (e) {
        lastBody = e.toString();
      }
    }

    return {
      'ok': false,
      'error':
          'No se pudo subir la imagen a ninguno de los endpoints candidatos',
      'status': lastStatus,
      'body': lastBody
    };
  }

  // Obtener perfil extendido (doctor_profiles)
  static Future<Map<String, dynamic>?> obtenerPerfilDoctorExtendido(
      int usuarioId) async {
    final url = Uri.parse('$baseUrl/api/doctor_profiles/$usuarioId');
    final headers = await _getHeaders();
    try {
      _log('📌 obtenerPerfilDoctorExtendido - GET $url');
      final res = await http.get(url, headers: headers);
      _log(
          '📌 obtenerPerfilDoctorExtendido - status: ${res.statusCode} body: ${res.body}');
      if (res.statusCode == 200) {
        try {
          return jsonDecode(res.body) as Map<String, dynamic>;
        } catch (_) {
          return null;
        }
      }
    } catch (e) {
      _log('❌ obtenerPerfilDoctorExtendido - error: $e');
    }
    return null;
  }

  // Public (no headers) fetch for doctor_profiles. Backend should allow GET without auth for public data.
  static Future<Map<String, dynamic>?> obtenerPerfilDoctorExtendidoPublic(
      int usuarioId) async {
    final url = Uri.parse('$baseUrl/api/doctor_profiles/$usuarioId/public');
    try {
      _log('📌 obtenerPerfilDoctorExtendidoPublic - GET $url');
      final res = await http.get(url);
      _log('📌 obtenerPerfilDoctorExtendidoPublic - status: ${res.statusCode}');
      if (res.statusCode == 200) {
        try {
          final decoded = jsonDecode(res.body);
          if (decoded is Map<String, dynamic>) {
            return decoded;
          }
          if (decoded is List &&
              decoded.isNotEmpty &&
              decoded.first is Map<String, dynamic>) {
            return Map<String, dynamic>.from(
                decoded.first as Map<String, dynamic>);
          }
        } catch (_) {
          return null;
        }
      }
    } catch (e) {
      _log('❌ obtenerPerfilDoctorExtendidoPublic - error: $e');
    }
    return null;
  }

  // Actualizar/crear perfil en doctor_profiles
  static Future<Map<String, dynamic>> actualizarPerfilDoctor(
      int usuarioId, Map<String, dynamic> data) async {
    final url = Uri.parse('$baseUrl/api/doctor_profiles/$usuarioId');
    final headers = await _getHeaders(jsonType: true);
    try {
      _log('📌 actualizarPerfilDoctor - PUT $url');
      _log('📌 actualizarPerfilDoctor - body: $data');
      final res = await http.put(url, headers: headers, body: jsonEncode(data));
      _log(
          '📌 actualizarPerfilDoctor - status: ${res.statusCode} body: ${res.body}');
      if (res.statusCode == 200 || res.statusCode == 201) {
        try {
          return {'ok': true, 'data': jsonDecode(res.body)};
        } catch (_) {
          return {'ok': true};
        }
      }
      try {
        final d = jsonDecode(res.body);
        return {'ok': false, 'error': d['message'] ?? d['error'] ?? res.body};
      } catch (_) {
        return {'ok': false, 'error': res.body};
      }
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    }
  }

  // Subir avatar usando endpoint específico creado en el backend
  static Future<Map<String, dynamic>> subirAvatarDoctor(
      int usuarioId, String filePath) async {
    final url = Uri.parse('$baseUrl/api/doctor_profiles/$usuarioId/avatar');
    final headers = await _getHeaders();
    try {
      _log('📌 subirAvatarDoctor - POST $url');
      final req = http.MultipartRequest('POST', url);
      req.headers.addAll(headers);
      req.files.add(await http.MultipartFile.fromPath('avatar', filePath));
      final streamed = await req.send();
      final body = await streamed.stream.bytesToString();
      _log('📌 subirAvatarDoctor - status: ${streamed.statusCode} body: $body');
      if (streamed.statusCode == 200 || streamed.statusCode == 201) {
        try {
          return {'ok': true, 'data': jsonDecode(body)};
        } catch (_) {
          return {'ok': true, 'body': body};
        }
      }
      return {'ok': false, 'status': streamed.statusCode, 'body': body};
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    }
  }

  // Obtener documentos/fotos públicos o privados asociados a un doctor
  static Future<List<Map<String, dynamic>>> obtenerDocumentosDoctor(
      int usuarioId) async {
    final headers = await _getHeaders();
    final candidates = [
      Uri.parse('$baseUrl/api/usuarios/$usuarioId/documentos'),
      Uri.parse('$baseUrl/api/usuarios/$usuarioId/photos'),
      Uri.parse('$baseUrl/api/doctor_profiles/$usuarioId/documents'),
      Uri.parse('$baseUrl/api/doctor_profiles/$usuarioId/photos'),
    ];
    for (final uri in candidates) {
      try {
        _log('📌 obtenerDocumentosDoctor - GET $uri');
        final res = await http.get(uri, headers: headers);
        _log(
            '📌 obtenerDocumentosDoctor - status: ${res.statusCode} body: ${res.body}');
        if (res.statusCode == 200) {
          try {
            final data = jsonDecode(res.body);
            if (data is List<dynamic>) {
              return List<Map<String, dynamic>>.from(data);
            } else if (data is Map && data['documents'] is List) {
              return List<Map<String, dynamic>>.from(data['documents']);
            }
          } catch (_) {}
        }
      } catch (e) {
        _log('❌ obtenerDocumentosDoctor - error: $e');
      }
    }
    return [];
  }

  // Subir múltiples documentos/fotos para un doctor. Esta operación intenta
  // varios endpoints candidatos y no cambia campos del perfil.
  static Future<Map<String, dynamic>> subirDocumentosDoctor(
      int usuarioId, List<String> filePaths) async {
    final headers = await _getHeaders();
    final candidates = [
      Uri.parse('$baseUrl/api/usuarios/$usuarioId/documentos'),
      Uri.parse('$baseUrl/api/usuarios/$usuarioId/photos'),
      Uri.parse('$baseUrl/api/doctor_profiles/$usuarioId/documents'),
      Uri.parse('$baseUrl/api/doctor_profiles/$usuarioId/photos'),
    ];

    String? lastBody;
    int? lastStatus;

    for (final uri in candidates) {
      try {
        _log('📌 subirDocumentosDoctor - intentando $uri');
        final req = http.MultipartRequest('POST', uri);
        req.headers.addAll(headers);
        // Try common field names and support multiple files
        for (final path in filePaths) {
          try {
            req.files.add(await http.MultipartFile.fromPath('files', path));
          } catch (_) {
            try {
              req.files
                  .add(await http.MultipartFile.fromPath('documentos', path));
            } catch (_) {
              try {
                req.files
                    .add(await http.MultipartFile.fromPath('images', path));
              } catch (_) {}
            }
          }
        }
        final streamed = await req.send();
        final body = await streamed.stream.bytesToString();
        _log(
            '📌 subirDocumentosDoctor - respuesta ${streamed.statusCode} desde $uri');
        _log('📌 subirDocumentosDoctor - body: $body');
        lastBody = body;
        lastStatus = streamed.statusCode;
        if (streamed.statusCode == 200 || streamed.statusCode == 201) {
          try {
            final parsed = jsonDecode(body);
            return {'ok': true, 'status': streamed.statusCode, 'data': parsed};
          } catch (_) {
            return {'ok': true, 'status': streamed.statusCode, 'body': body};
          }
        }
      } catch (e) {
        lastBody = e.toString();
      }
    }

    return {
      'ok': false,
      'error':
          'No se pudo subir los documentos a ninguno de los endpoints candidatos',
      'status': lastStatus,
      'body': lastBody
    };
  }

  static Future<Map<String, dynamic>> comprarDoctorExtra({
    required int clinicaId,
    required String usuario,
    required String clave,
    double monto = 5.0,
  }) async {
    final url = Uri.parse('$baseUrl/api/compras_doctores/comprar');
    final headers = await _getHeaders(jsonType: true);
    final body = jsonEncode({
      'clinica_id': clinicaId,
      'usuario': usuario,
      'clave': clave,
      'monto': monto,
      'usuario_id': null
    });
    final res = await http.post(url, headers: headers, body: body);
    if (res.statusCode == 201) {
      try {
        final d = jsonDecode(res.body);
        return {'ok': true, 'data': d};
      } catch (_) {
        return {'ok': true, 'data': null};
      }
    }
    try {
      final d = jsonDecode(res.body);
      return {
        'ok': false,
        'error': d['error'] ?? d['message'] ?? 'Error desconocido'
      };
    } catch (_) {
      return {'ok': false, 'error': 'Error desconocido'};
    }
  }
}
