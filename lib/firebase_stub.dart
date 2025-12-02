// Lightweight stub for Firebase APIs so Windows builds can succeed
// This file is intended for development / desktop testing when
// `firebase_core` and `firebase_messaging` packages are not available
// or when native SDKs cause link errors. The implementations are
// no-ops that mimic the minimal API surface used in the app.

import 'dart:async';

class Firebase {
  static Future<void> initializeApp() async {
    // no-op for desktop stub
    return Future.value();
  }
}

class RemoteMessage {
  final Map<String, dynamic> data;
  final RemoteNotification? notification;
  RemoteMessage({Map<String, dynamic>? data, this.notification})
      : data = data ?? {};
}

class RemoteNotification {
  final String? title;
  final String? body;
  RemoteNotification({this.title, this.body});
}

class FirebaseMessaging {
  FirebaseMessaging._internal();

  static final FirebaseMessaging instance = FirebaseMessaging._internal();

  static final StreamController<RemoteMessage> _onMessageController =
      StreamController<RemoteMessage>.broadcast();

  /// Stream that mimics [FirebaseMessaging.onMessage]
  static Stream<RemoteMessage> get onMessage => _onMessageController.stream;

  /// No-op subscription method
  Future<void> subscribeToTopic(String topic) async {
    // no-op in stub
    return Future.value();
  }

  /// Helper to emit a fake message while testing on desktop
  void emitTestMessage(RemoteMessage msg) {
    _onMessageController.add(msg);
  }
}
