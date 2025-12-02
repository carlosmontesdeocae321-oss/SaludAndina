import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GoogleCalendarHelper {
  static Future<bool> crearEvento({
    required GoogleSignInAccount user,
    required String titulo,
    required DateTime fechaInicio,
    required DateTime fechaFin,
    String? descripcion,
  }) async {
    final authHeaders = await user.authHeaders;
    final accessToken =
        authHeaders['Authorization']?.replaceFirst('Bearer ', '');
    if (accessToken == null) return false;

    final evento = {
      'summary': titulo,
      'description': descripcion ?? '',
      'start': {
        'dateTime': fechaInicio.toIso8601String(),
        'timeZone': 'America/Guayaquil',
      },
      'end': {
        'dateTime': fechaFin.toIso8601String(),
        'timeZone': 'America/Guayaquil',
      },
    };

    final res = await http.post(
      Uri.parse(
          'https://www.googleapis.com/calendar/v3/calendars/primary/events'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(evento),
    );
    return res.statusCode == 200 || res.statusCode == 201;
  }
}
