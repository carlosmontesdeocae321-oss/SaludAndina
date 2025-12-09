import 'package:flutter/foundation.dart';
import 'local_db.dart';

/// Simple singleton notifier that exposes the number of pending local records.
class SyncNotifier {
  SyncNotifier._internal();

  static final SyncNotifier instance = SyncNotifier._internal();

  final ValueNotifier<int> count = ValueNotifier<int>(0);

  /// Refresh the pending count from the LocalDb.
  Future<void> refresh() async {
    try {
      final list = await LocalDb.getPending('all');
      count.value = list.length;
    } catch (_) {
      // ignore; keep previous value
    }
  }
}
