import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'login_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({
    required this.auth,
    required this.signedInBuilder,
    super.key,
  });
  final AuthService auth;
  final Widget Function(BuildContext, VoidCallback) signedInBuilder;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool?>(
    valueListenable: auth.signedIn,
    builder: (context, signedIn, _) {
      if (signedIn == null) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (!signedIn) return LoginPage(auth: auth);
      return signedInBuilder(context, () async {
        try {
          await auth.signOut();
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Oturum kapatılamadı. Tekrar deneyin.'),
              ),
            );
          }
        }
      });
    },
  );
}
