import 'package:flutter/foundation.dart';

/// Increment this notifier to signal interested screens to refresh their data.
final ValueNotifier<int> globalRefreshNotifier = ValueNotifier<int>(0);
