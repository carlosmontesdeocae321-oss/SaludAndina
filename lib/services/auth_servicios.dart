import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../google_auth_service.dart';
import 'api_services.dart';

class AuthService {
  AuthService._();

  static final GoogleAuthService _googleAuth = GoogleAuthService();
  static String? lastGoogleSignInError;

  // Mantener la constante para reutilizar los endpoints existentes mientras
  // completamos la migración a Firestore.
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://saludandina.onrender.com',
  );

  static bool get _hasFirebaseInstance {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static User? get currentUser {
    if (!_hasFirebaseInstance) {
      return null;
    }
    try {
      return FirebaseAuth.instance.currentUser;
    } catch (_) {
      return null;
    }
  }

  static Future<UserCredential?> signInWithGoogle() async {
    lastGoogleSignInError = null;
    try {
      final credential = await _googleAuth.signInWithGoogle();
      if (credential == null) {
        lastGoogleSignInError ??= 'Se canceló el inicio de sesión con Google.';
        return null;
      }

      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        lastGoogleSignInError =
            'No se pudo obtener la información del usuario de Google.';
        return null;
      }

      final idToken = await firebaseUser.getIdToken(true);
      if (idToken == null || idToken.isEmpty) {
        await _googleAuth.signOut();
        lastGoogleSignInError =
            'No se obtuvo un token válido de Firebase para Google Sign-In.';
        return null;
      }

      final syncRes = await ApiService.syncGoogleUser(
        idToken: idToken,
        firebaseUid: firebaseUser.uid,
        email: firebaseUser.email,
        displayName: firebaseUser.displayName,
      );

      if (syncRes['ok'] != true) {
        await _googleAuth.signOut();
        lastGoogleSignInError = syncRes['message']?.toString() ??
            'No se pudo registrar en el backend.';
        return null;
      }

      final backendData = (syncRes['data'] as Map?) ?? {};
      await _persistUser(firebaseUser, backendData: backendData);
      return credential;
    } on UnsupportedError catch (e) {
      final code = e.message?.toString() ?? '';
      switch (code) {
        case 'firebase_not_available':
          lastGoogleSignInError =
              'Firebase no está inicializado; revisa la configuración antes de usar Google.';
          break;
        case 'google_sign_in_not_supported':
        case 'google_sign_in_plugin_missing':
          lastGoogleSignInError =
              'Esta plataforma no cuenta con soporte para Google Sign-In.';
          break;
        default:
          lastGoogleSignInError =
              'El inicio de sesión con Google no está disponible.';
      }
    } catch (e) {
      lastGoogleSignInError = 'Ocurrió un problema con Google: $e';
    }
    return null;
  }

  static Future<Map<String, dynamic>> loginWithCredentials(
      String usuario, String clave) async {
    final uri = Uri.parse('$baseUrl/api/usuarios/login');
    try {
      final response = await http.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'usuario': usuario, 'clave': clave}),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        await _persistBackendSession(
          usuario: usuario,
          clave: clave,
          payload: decoded,
        );
        return {'ok': true, 'data': decoded};
      }

      String? message;
      try {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        message =
            decoded['message']?.toString() ?? decoded['error']?.toString();
      } catch (_) {
        message = null;
      }

      return {
        'ok': false,
        'message':
            message ?? 'No se pudo iniciar sesión. (${response.statusCode})'
      };
    } catch (e) {
      return {
        'ok': false,
        'message': 'Ocurrió un error intentando iniciar sesión: $e'
      };
    }
  }

  static Future<void> logout() async {
    try {
      await _googleAuth.signOut();
    } catch (e) {
      debugPrint('Error cerrando sesión de Google: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static Future<bool> isAuthenticated() async {
    try {
      if (_hasFirebaseInstance && FirebaseAuth.instance.currentUser != null) {
        return true;
      }
    } catch (_) {
      // Ignoramos ya que el estado se resolverá con la sesión local.
    }

    final prefs = await SharedPreferences.getInstance();
    final usuario = prefs.getString('usuario');
    final clave = prefs.getString('clave');
    final firebaseUid = prefs.getString('firebaseUid');
    final hasCredenciales = usuario != null &&
        usuario.isNotEmpty &&
        clave != null &&
        clave.isNotEmpty;
    final hasFirebase = firebaseUid != null && firebaseUid.isNotEmpty;
    return hasCredenciales || hasFirebase;
  }

  /// Try to login offline: returns true if there are cached credentials or a cached
  /// firebase UID allowing the app to function in offline mode.
  static Future<bool> tryOfflineLogin() async {
    // For now we consider the same check as isAuthenticated. We can extend this
    // later to require PIN/biometrics or session freshness checks.
    return await isAuthenticated();
  }

  static Future<void> _persistUser(User? user,
      {Map<dynamic, dynamic>? backendData}) async {
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('firebaseUid', user.uid);
    await prefs.setString('email', user.email ?? '');
    await prefs.setString('displayName', user.displayName ?? '');
    await prefs.setString('photoUrl', user.photoURL ?? '');

    if (backendData != null && backendData.isNotEmpty) {
      final map =
          backendData.map((key, value) => MapEntry(key.toString(), value));
      if (map['usuario'] != null) {
        await prefs.setString('usuario', map['usuario']!.toString());
      }
      if (map['rol'] != null) {
        await prefs.setString('rol', map['rol']!.toString());
      }
      if (map['clinicaId'] != null && map['clinicaId'].toString().isNotEmpty) {
        await prefs.setString('clinicaId', map['clinicaId']!.toString());
      } else {
        await prefs.remove('clinicaId');
      }
      if (map['id'] != null) {
        await prefs.setString('userId', map['id']!.toString());
      }
      if (map['dueno'] != null) {
        await prefs.setBool(
            'dueno', map['dueno'] == true || map['dueno'] == 'true');
      }
      if (map['authType'] != null) {
        await prefs.setString('authType', map['authType']!.toString());
      } else {
        await prefs.setString('authType', 'google');
      }
      await prefs.remove('clave');
    }
  }

  static Future<void> _persistBackendSession({
    required String usuario,
    required String clave,
    required Map<String, dynamic> payload,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('usuario', usuario);
    await prefs.setString('clave', clave);

    final rawUserId = payload['id'];
    if (rawUserId != null && rawUserId.toString().isNotEmpty) {
      await prefs.setString('userId', rawUserId.toString());
    } else {
      await prefs.remove('userId');
    }

    final rawRol = payload['rol'];
    if (rawRol != null && rawRol.toString().isNotEmpty) {
      await prefs.setString('rol', rawRol.toString());
    } else {
      await prefs.remove('rol');
    }

    final rawClinica = payload['clinicaId'];
    if (rawClinica != null && rawClinica.toString().isNotEmpty) {
      await prefs.setString('clinicaId', rawClinica.toString());
    } else {
      await prefs.remove('clinicaId');
    }

    await prefs.setBool('dueno', payload['dueno'] == true);
    await prefs.setString('authType', 'credentials');
    await prefs.remove('firebaseUid');
  }
}
