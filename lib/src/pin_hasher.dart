import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// A PIN hashed with PBKDF2-HMAC-SHA256.
class PinHash {
  /// Creates a stored hash.
  const PinHash({
    required this.hash,
    required this.salt,
    required this.iterations,
  });

  /// Base64 of the derived key.
  final String hash;

  /// Base64 of the random salt.
  final String salt;

  /// PBKDF2 iteration count used to derive [hash].
  final int iterations;

  /// Hashes [pin] with a fresh random salt.
  static Future<PinHash> create(String pin, {required int iterations}) async {
    final random = Random.secure();
    final salt = Uint8List.fromList(
      List.generate(16, (_) => random.nextInt(256)),
    );
    return PinHash(
      hash: base64Encode(await _derive(pin, salt, iterations)),
      salt: base64Encode(salt),
      iterations: iterations,
    );
  }

  /// Whether [pin] matches this hash, compared in constant time.
  Future<bool> verify(String pin) async {
    final expected = base64Decode(hash);
    final actual = await _derive(pin, base64Decode(salt), iterations);
    if (actual.length != expected.length) return false;
    var diff = 0;
    for (var i = 0; i < actual.length; i++) {
      diff |= actual[i] ^ expected[i];
    }
    return diff == 0;
  }

  // PBKDF2 is pure CPU work, so a real iteration count runs on a background
  // isolate to keep the keypad responsive; tiny test counts stay inline
  static Future<List<int>> _derive(String pin, List<int> salt, int iterations) {
    if (iterations < 1000) return _deriveNow(pin, salt, iterations);
    return Isolate.run(() => _deriveNow(pin, salt, iterations));
  }

  static Future<List<int>> _deriveNow(
    String pin,
    List<int> salt,
    int iterations,
  ) async {
    final key = await Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    ).deriveKeyFromPassword(password: pin, nonce: salt);
    return key.extractBytes();
  }
}
