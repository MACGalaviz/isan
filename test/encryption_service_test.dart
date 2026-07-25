import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isan/services/security/encryption_service.dart';

void main() {
  final service = EncryptionService.instance;

  late SecretKey key;

  setUp(() async {
    key = await AesGcm.with256bits().newSecretKey();
  });

  test('round-trips plain text', () async {
    final cipher = await service.encrypt(plainText: 'hello', key: key);
    expect(await service.decrypt(cipherText: cipher, key: key), 'hello');
  });

  test('round-trips an empty string', () async {
    // A note saved with a title and no content hits this path.
    final cipher = await service.encrypt(plainText: '', key: key);
    expect(await service.decrypt(cipherText: cipher, key: key), '');
  });

  test('round-trips multi-byte characters', () async {
    const text = '⚠️ Nota con acentós y emoji 🔒';
    final cipher = await service.encrypt(plainText: text, key: key);
    expect(await service.decrypt(cipherText: cipher, key: key), text);
  });

  test('uses a fresh nonce per encryption', () async {
    // Reusing a nonce under the same key breaks AES-GCM, so identical
    // plaintext must never produce identical ciphertext.
    final a = await service.encrypt(plainText: 'same', key: key);
    final b = await service.encrypt(plainText: 'same', key: key);
    expect(a, isNot(equals(b)));
  });

  test('rejects the wrong key', () async {
    final cipher = await service.encrypt(plainText: 'secret', key: key);
    final otherKey = await AesGcm.with256bits().newSecretKey();

    expect(
      () => service.decrypt(cipherText: cipher, key: otherKey),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });

  test('rejects tampered ciphertext', () async {
    final cipher = await service.encrypt(plainText: 'secret', key: key);

    // Concatenation is nonce(12) + ciphertext + mac(16); flipping a byte in
    // the payload must fail the MAC instead of returning garbage.
    final bytes = base64Decode(cipher);
    bytes[bytes.length ~/ 2] ^= 0xFF;

    expect(
      () => service.decrypt(cipherText: base64Encode(bytes), key: key),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });
}
