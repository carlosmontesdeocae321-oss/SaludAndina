import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Servicio pequeño que encapsula el flujo de autenticación con Google
/// y enlaza la sesión resultante con FirebaseAuth.
class GoogleAuthService {
  GoogleAuthService()
      : _googleSignIn = GoogleSignIn(
          scopes: const ['email', 'profile'],
        );

  final GoogleSignIn _googleSignIn;

  bool get _canUseFirebase {
    try {
      final apps = Firebase.apps;
      return apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  bool get _supportsGoogleSignIn {
    if (kIsWeb) {
      return true;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return true;
      default:
        return false;
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    if (!_canUseFirebase) {
      throw UnsupportedError('firebase_not_available');
    }

    if (!_supportsGoogleSignIn) {
      throw UnsupportedError('google_sign_in_not_supported');
    }

    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return FirebaseAuth.instance.signInWithCredential(credential);
    } on MissingPluginException {
      throw UnsupportedError('google_sign_in_plugin_missing');
    } on PlatformException catch (pe) {
      // Common plugin/platform errors from GoogleSignIn show as PlatformException
      debugPrint(
          'PlatformException during GoogleSignIn - code: ${pe.code}, message: ${pe.message}, details: ${pe.details}');
      // Special-case the 12500 / sign_in_failed which often maps to OAuth config (SHA-1 / client id)
      if ((pe.message ?? '').contains('12500') ||
          pe.code.contains('sign_in_failed')) {
        debugPrint(
            'Google Sign-In error 12500 detected: verifica SHA-1 en Firebase Console, google-services.json y el client ID en Google Cloud Console.');
      }
      rethrow;
    } catch (e) {
      debugPrint('Error Google Sign-In: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    if (_canUseFirebase) {
      try {
        await FirebaseAuth.instance.signOut();
      } catch (e) {
        debugPrint('Error FirebaseAuth signOut: $e');
      }
    }

    if (_supportsGoogleSignIn) {
      try {
        await _googleSignIn.signOut();
      } on MissingPluginException {
        debugPrint('GoogleSignIn plugin no disponible para signOut.');
      } catch (e) {
        debugPrint('Error GoogleSignIn signOut: $e');
      }
    }
  }
}
