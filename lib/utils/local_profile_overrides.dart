import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalProfileOverrides {
  static String _keyFor(int userId) => 'profile_overrides_$userId';

  static Future<Map<String, dynamic>?> loadForUser(int userId) async {
    final sp = await SharedPreferences.getInstance();
    final s = sp.getString(_keyFor(userId));
    if (s == null) return null;
    try {
      final decoded = jsonDecode(s) as Map<String, dynamic>;
      return decoded;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveForUser(
      int userId, Map<String, dynamic> fields) async {
    final sp = await SharedPreferences.getInstance();
    final existing = await loadForUser(userId) ?? <String, dynamic>{};
    existing.addAll(fields);
    await sp.setString(_keyFor(userId), jsonEncode(existing));
  }

  static Future<void> clearForUser(int userId) async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_keyFor(userId));
  }

  static Future<void> removeFieldsForUser(int userId, List<String> keys) async {
    final sp = await SharedPreferences.getInstance();
    final existing = await loadForUser(userId);
    if (existing == null) return;
    for (final k in keys) {
      existing.remove(k);
    }
    if (existing.isEmpty) {
      await sp.remove(_keyFor(userId));
    } else {
      await sp.setString(_keyFor(userId), jsonEncode(existing));
    }
  }
}
