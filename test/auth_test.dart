import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iclip/auth/auth_service.dart';
import 'package:iclip/auth/auth_gate.dart';

class FakeAuth implements AuthService {
  final state = ValueNotifier<bool?>(false);
  bool fail = false;
  int calls = 0;
  Completer<void>? pending;
  @override
  ValueNotifier<bool?> get signedIn => state;
  @override
  Future<void> signIn(String username, String password) async {
    calls++;
    await pending?.future;
    if (fail) throw StateError('Wrong credentials');
    state.value = true;
  }

  @override
  Future<void> signOut() async => state.value = false;
}

void main() {
  test(
    'Python PBKDF2 vector matches Dart; wrong password and username fail',
    () async {
      final vector = <String, Object>{
        'username': '  demo  ',
        'expectedUsername': 'demo',
        'password': 'test-password',
        'salt': 'dGVzdC1vbmx5LXNhbHQtMTY=',
        'expectedHash': 'rICYNY7ADXSaP9K7NjJtRLKIxQ04qw/S1TThKYhwUr0=',
        'iterations': 1000,
      };
      expect(await verifyLogin(vector), isTrue);
      expect(await verifyLogin({...vector, 'password': 'wrong'}), isFalse);
      expect(
        await verifyLogin({...vector, 'username': 'someone-else'}),
        isFalse,
      );
    },
  );
  testWidgets(
    'Collection is not created before login; login and logout change gate',
    (tester) async {
      final auth = FakeAuth();
      var collectionBuilds = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(
            auth: auth,
            signedInBuilder: (context, signOut) {
              collectionBuilds++;
              return Scaffold(
                body: TextButton(
                  onPressed: signOut,
                  child: const Text('Test logout'),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(collectionBuilds, 0);
      await tester.tap(find.text('Giriş yap'));
      await tester.pumpAndSettle();
      expect(find.text('Kullanıcı adını gir'), findsOneWidget);
      expect(auth.calls, 0);
      await tester.enterText(find.byType(TextFormField).first, 'demo');
      await tester.enterText(find.byType(TextFormField).last, 'test-password');
      await tester.tap(find.text('Giriş yap'));
      await tester.pumpAndSettle();
      expect(find.text('Test logout'), findsOneWidget);
      await tester.tap(find.text('Test logout'));
      await tester.pumpAndSettle();
      expect(find.text('Giriş yap'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Failed and duplicate login do not open collection or leak password',
    (tester) async {
      final auth = FakeAuth()
        ..fail = true
        ..pending = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(
            auth: auth,
            signedInBuilder: (_, __) => const Text('Private collection'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'demo');
      await tester.enterText(find.byType(TextFormField).last, 'test-password');
      await tester.tap(find.text('Giriş yap'));
      await tester.pump();
      expect(find.text('Private collection'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(auth.calls, 1);
      auth.pending!.complete();
      await tester.pumpAndSettle();
      expect(find.textContaining('Giriş yapılamadı'), findsOneWidget);
      expect(find.text('Private collection'), findsNothing);
      final field = tester.widget<TextField>(find.byType(TextField).last);
      expect(field.obscureText, isTrue);
    },
  );
  test('A source build without secret defines stays locked', () async {
    final auth = LocalAuthService();
    await Future<void>.delayed(Duration.zero);
    expect(auth.signedIn.value, isFalse);
    expect(() => auth.signIn('demo', 'test-password'), throwsStateError);
  });
}
