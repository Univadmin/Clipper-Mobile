import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class AuthService {
  ValueListenable<bool?> get signedIn;
  Future<void> signIn(String username, String password);
  Future<void> signOut();
}

class LocalAuthService implements AuthService {
  LocalAuthService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage() {
    _restore();
  }

  final FlutterSecureStorage _storage;
  final ValueNotifier<bool?> _state = ValueNotifier(null);
  static const _username = String.fromEnvironment('CLIPPER_USERNAME');
  static const _salt = String.fromEnvironment('CLIPPER_PASSWORD_SALT');
  static const _hash = String.fromEnvironment('CLIPPER_PASSWORD_HASH');
  static const _iterations = int.fromEnvironment(
    'CLIPPER_PASSWORD_ITERATIONS',
    defaultValue: 120000,
  );
  static const _storageKey = 'iclip.unlock.session.v1';

  @override
  ValueListenable<bool?> get signedIn => _state;

  bool get _configured =>
      _username.isNotEmpty &&
      _salt.isNotEmpty &&
      _hash.isNotEmpty &&
      _iterations >= 100000;

  Future<String> _sessionMarker() async {
    final digest = await Sha256().hash(
      utf8.encode('$_username:$_salt:$_hash:$_iterations'),
    );
    return base64Encode(digest.bytes);
  }

  Future<void> _restore() async {
    try {
      _state.value =
          _configured &&
          await _storage.read(key: _storageKey) == await _sessionMarker();
    } catch (_) {
      _state.value = false;
    }
  }

  @override
  Future<void> signIn(String username, String password) async {
    if (!_configured) throw StateError('Giriş yapılandırması eksik');
    final valid = await compute(verifyLogin, <String, Object>{
      'username': username,
      'password': password,
      'expectedUsername': _username,
      'salt': _salt,
      'expectedHash': _hash,
      'iterations': _iterations,
    });
    if (!valid) throw StateError('Giriş başarısız');
    // Login still works if device storage is temporarily unavailable; it will
    // simply require another login when the app next starts.
    try {
      await _storage.write(key: _storageKey, value: await _sessionMarker());
    } catch (_) {
      /* Never persist the password as a fallback. */
    }
    _state.value = true;
  }

  @override
  Future<void> signOut() async {
    await _storage.delete(key: _storageKey);
    _state.value = false;
  }
}

// Runs away from the UI isolate. This is an application lock, not Firebase
// authentication and not a replacement for database-side access rules.
Future<bool> verifyLogin(Map<String, Object> input) async {
  final algorithm = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: input['iterations']! as int,
    bits: 256,
  );
  final key = await algorithm.deriveKey(
    secretKey: SecretKey(utf8.encode(input['password']! as String)),
    nonce: base64Decode(input['salt']! as String),
  );
  final actual = await key.extractBytes();
  final expected = base64Decode(input['expectedHash']! as String);
  var difference = actual.length ^ expected.length;
  for (var i = 0; i < actual.length && i < expected.length; i++) {
    difference |= actual[i] ^ expected[i];
  }
  return difference == 0 &&
      (input['username']! as String).trim().toLowerCase() ==
          (input['expectedUsername']! as String).toLowerCase();
}
