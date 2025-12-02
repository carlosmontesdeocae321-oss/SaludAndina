import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalAppointments {
  static String _keyForDoctor(int doctorId) => 'appointments_doctor_$doctorId';

  static Future<List<Map<String, dynamic>>> loadForDoctor(int doctorId) async {
    final sp = await SharedPreferences.getInstance();
    final s = sp.getString(_keyForDoctor(doctorId));
    if (s == null) return [];
    try {
      final decoded = jsonDecode(s) as List<dynamic>;
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveForDoctor(
      int doctorId, List<Map<String, dynamic>> items) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_keyForDoctor(doctorId), jsonEncode(items));
  }

  static Future<void> addForDoctor(
      int doctorId, Map<String, dynamic> item) async {
    final list = await loadForDoctor(doctorId);
    list.add(item);
    await saveForDoctor(doctorId, list);
  }

  static Future<void> clearForDoctor(int doctorId) async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_keyForDoctor(doctorId));
  }
}
