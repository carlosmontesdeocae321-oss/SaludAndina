import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalClinicOverrides {
  static String _keyFor(int clinicId) => 'clinic_overrides_$clinicId';

  static Future<Map<String, dynamic>?> loadForClinic(int clinicId) async {
    final sp = await SharedPreferences.getInstance();
    final s = sp.getString(_keyFor(clinicId));
    if (s == null) return null;
    try {
      return jsonDecode(s) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveForClinic(
      int clinicId, Map<String, dynamic> fields) async {
    final sp = await SharedPreferences.getInstance();
    final existingRaw = sp.getString(_keyFor(clinicId));
    final existing = existingRaw != null
        ? (jsonDecode(existingRaw) as Map<String, dynamic>)
        : <String, dynamic>{};
    existing.addAll(fields);
    await sp.setString(_keyFor(clinicId), jsonEncode(existing));
  }

  static Future<void> clearForClinic(int clinicId) async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_keyFor(clinicId));
  }

  static Future<void> removeFieldsForClinic(
      int clinicId, List<String> keys) async {
    final sp = await SharedPreferences.getInstance();
    final existingRaw = sp.getString(_keyFor(clinicId));
    if (existingRaw == null) return;
    final existing = jsonDecode(existingRaw) as Map<String, dynamic>;
    for (final k in keys) {
      existing.remove(k);
    }
    if (existing.isEmpty) {
      await sp.remove(_keyFor(clinicId));
    } else {
      await sp.setString(_keyFor(clinicId), jsonEncode(existing));
    }
  }
}
