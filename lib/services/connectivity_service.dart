import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

/// Simple connectivity service that exposes a reactive `isOnline` notifier.
/// Use `ConnectivityService.init()` early (e.g. in `main`) to start listening.
class ConnectivityService {
  ConnectivityService._();

  static final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);
  static StreamSubscription<ConnectivityResult>? _sub;

  /// Initialize the connectivity listener. Safe to call multiple times.
  static Future<void> init() async {
    try {
      // initial check
      await _updateOnlineStatus();
      _sub ??= Connectivity().onConnectivityChanged.listen((_) async {
        await _updateOnlineStatus();
      });
    } catch (e) {
      if (kDebugMode) debugPrint('ConnectivityService.init error: $e');
    }
  }

  static Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }

  static Future<void> _updateOnlineStatus() async {
    try {
      final conn = await Connectivity().checkConnectivity();
      if (conn == ConnectivityResult.none) {
        isOnline.value = false;
        return;
      }
      // Quick reachability check (fast) to confirm real internet access
      try {
        final res = await http
            .get(Uri.parse('https://clients3.google.com/generate_204'))
            .timeout(const Duration(seconds: 3));
        isOnline.value = (res.statusCode == 204 || res.statusCode == 200);
      } catch (_) {
        isOnline.value = false;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('ConnectivityService._update error: $e');
      isOnline.value = false;
    }
  }
}
