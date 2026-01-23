import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class KeyDerivationService {
  KeyDerivationService._();

  static final KeyDerivationService instance = KeyDerivationService._();

  /// PBKDF2 with SHA-256
  /// - 150k iterations
  /// - 256-bit key
  final Pbkdf2 _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 150000,
    bits: 256,
  );

  /// Derives a master encryption key from a password or recovery phrase
  Future<SecretKey> deriveKey({
    required String secret,
    required Uint8List salt,
  }) async {
    return _pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(secret)),
      nonce: salt,
    );
  }

  /// Generates a cryptographically secure random salt
  Uint8List generateSalt({int length = 16}) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }
}
