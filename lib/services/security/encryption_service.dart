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
    // 1. Encriptamos (el algoritmo genera su propio nonce y MAC internamente)
    final secretBox = await _algorithm.encrypt(
      utf8.encode(plainText),
      secretKey: key,
    );

    // 2. IMPORTANTE: Guardamos todo junto (Nonce + MAC + CipherText)
    // El método concatenation() ya lo hace por ti de forma estándar
    return base64Encode(secretBox.concatenation());
  }

  Future<String> decrypt({
    required String cipherText,
    required SecretKey key,
  }) async {
    final combined = base64Decode(cipherText);

    // 3. Reconstruimos el SecretBox usando la concatenación
    // AesGcm usa 12 bytes para nonce y 16 para MAC por defecto
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