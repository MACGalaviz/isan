import 'dart:convert';

import 'package:cryptography/cryptography.dart';
class EncryptionService {
  EncryptionService._();
  static final EncryptionService instance = EncryptionService._();

  final AesGcm _algorithm = AesGcm.with256bits();

  Future<String> encrypt({
    required String plainText,
    required SecretKey key,
  }) async {
    // AesGcm generates its own nonce and MAC
    final secretBox = await _algorithm.encrypt(
      utf8.encode(plainText),
      secretKey: key,
    );

    // Stored as nonce + MAC + ciphertext in one string
    return base64Encode(secretBox.concatenation());
  }

  Future<String> decrypt({
    required String cipherText,
    required SecretKey key,
  }) async {
    final combined = base64Decode(cipherText);

    // AesGcm defaults: 12-byte nonce, 16-byte MAC
    final secretBox = SecretBox.fromConcatenation(
      combined,
      nonceLength: 12,
      macLength: 16,
    );

    final clearBytes = await _algorithm.decrypt(
      secretBox,
      secretKey: key,
    );

    return utf8.decode(clearBytes);
  }
}