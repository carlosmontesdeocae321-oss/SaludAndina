import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleCalendarLogin extends StatefulWidget {
  final void Function(GoogleSignInAccount?) onLogin;
  const GoogleCalendarLogin({super.key, required this.onLogin});

  @override
  State<GoogleCalendarLogin> createState() => _GoogleCalendarLoginState();
}

class _GoogleCalendarLoginState extends State<GoogleCalendarLogin> {
  GoogleSignInAccount? _currentUser;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/calendar.events',
    ],
  );

  Future<void> _handleSignIn() async {
    try {
      final user = await _googleSignIn.signIn();
      if (!mounted) return;
      setState(() => _currentUser = user);
      widget.onLogin(user);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al iniciar sesión: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _currentUser == null
        ? ElevatedButton.icon(
            icon: const Icon(Icons.calendar_today),
            label: const Text('Conectar con Google Calendar'),
            onPressed: _handleSignIn,
          )
        : ListTile(
            leading: CircleAvatar(
              backgroundImage: NetworkImage(_currentUser!.photoUrl ?? ''),
            ),
            title: Text(_currentUser!.displayName ?? ''),
            subtitle: Text(_currentUser!.email),
            trailing: IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await _googleSignIn.signOut();
                if (!mounted) return;
                setState(() => _currentUser = null);
                widget.onLogin(null);
              },
            ),
          );
  }
}
