import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase configuration for the different build targets of the app.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
          'Configuración Firebase para Web no está definida.');
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'Plataforma ${defaultTargetPlatform.name} no configurada para Firebase.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBgjF_0dDUWzNf8ByTfO5IGpnkPCXpF3go',
    appId: '1:306084030452:android:de0ad4dbba925887b23ba1',
    messagingSenderId: '306084030452',
    projectId: 'saludandina-f0fad',
    storageBucket: 'saludandina-f0fad.firebasestorage.app',
  );
}
