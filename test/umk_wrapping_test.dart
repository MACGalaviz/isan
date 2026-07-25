import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isan/services/security/encryption_service.dart';
import 'package:isan/services/security/key_derivation_service.dart';

/// The UMK scheme without Supabase: `createUserAccount` wraps one master key
/// under two independent slots (password and recovery phrase), and
/// `loginWithPassword` / `recoverWithPhrase` unwrap them. These tests cover the
/// crypto those three methods rely on; the network and storage calls around it
/// are not exercised here.
void main() {
  final kdf = KeyDerivationService.instance;
  final encryption = EncryptionService.instance;

  const password = 'account-password';
  const phrase = 'legal winner thank year wave sausage worth useful legal '
      'winner thank yellow';

  late String umkBase64;

  setUp(() async {
    final umk = await AesGcm.with256bits().newSecretKey();
    umkBase64 = base64Encode(await umk.extractBytes());
  });

  test('both slots recover the same UMK', () async {
    final saltPassword = kdf.generateSalt();
    final saltRecovery = kdf.generateSalt();

    final wrappedWithPassword = await encryption.encrypt(
      plainText: umkBase64,
      key: await kdf.deriveKey(secret: password, salt: saltPassword),
    );
    final wrappedWithRecovery = await encryption.encrypt(
      plainText: umkBase64,
      key: await kdf.deriveKey(secret: phrase, salt: saltRecovery),
    );

    // Same key, two wrappings: the stored blobs must differ.
    expect(wrappedWithPassword, isNot(equals(wrappedWithRecovery)));

    final fromPassword = await encryption.decrypt(
      cipherText: wrappedWithPassword,
      key: await kdf.deriveKey(secret: password, salt: saltPassword),
    );
    final fromRecovery = await encryption.decrypt(
      cipherText: wrappedWithRecovery,
      key: await kdf.deriveKey(secret: phrase, salt: saltRecovery),
    );

    expect(fromPassword, umkBase64);
    expect(fromRecovery, umkBase64);
  });

  test('a wrong password cannot open the password slot', () async {
    final salt = kdf.generateSalt();
    final wrapped = await encryption.encrypt(
      plainText: umkBase64,
      key: await kdf.deriveKey(secret: password, salt: salt),
    );

    // loginWithPassword turns this failure into `false`.
    expect(
      () async => encryption.decrypt(
        cipherText: wrapped,
        key: await kdf.deriveKey(secret: 'wrong-password', salt: salt),
      ),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });

  test('re-wrapping the password slot leaves the recovery slot working',
      () async {
    // rewrapPasswordSlot: after an email reset the old password slot is dead,
    // so it is replaced with a new salt. The recovery slot is never touched.
    final saltRecovery = kdf.generateSalt();
    final wrappedWithRecovery = await encryption.encrypt(
      plainText: umkBase64,
      key: await kdf.deriveKey(secret: phrase, salt: saltRecovery),
    );

    const newPassword = 'new-account-password';
    final newSaltPassword = kdf.generateSalt();
    final rewrapped = await encryption.encrypt(
      plainText: umkBase64,
      key: await kdf.deriveKey(secret: newPassword, salt: newSaltPassword),
    );

    final fromNewPassword = await encryption.decrypt(
      cipherText: rewrapped,
      key: await kdf.deriveKey(secret: newPassword, salt: newSaltPassword),
    );
    final fromRecovery = await encryption.decrypt(
      cipherText: wrappedWithRecovery,
      key: await kdf.deriveKey(secret: phrase, salt: saltRecovery),
    );

    expect(fromNewPassword, umkBase64);
    expect(fromRecovery, umkBase64);
  });
}
