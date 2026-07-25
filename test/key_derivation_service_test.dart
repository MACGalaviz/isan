import 'package:flutter_test/flutter_test.dart';
import 'package:isan/services/security/key_derivation_service.dart';

void main() {
  final service = KeyDerivationService.instance;

  test('derives the same key from the same secret and salt', () async {
    // Login depends on this: the salt comes back from the cloud and the
    // password must rebuild the exact same PDK.
    final salt = service.generateSalt();

    final a = await service.deriveKey(secret: 'password', salt: salt);
    final b = await service.deriveKey(secret: 'password', salt: salt);

    expect(await a.extractBytes(), await b.extractBytes());
  });

  test('derives a different key per salt', () async {
    final a = await service.deriveKey(
      secret: 'password',
      salt: service.generateSalt(),
    );
    final b = await service.deriveKey(
      secret: 'password',
      salt: service.generateSalt(),
    );

    expect(await a.extractBytes(), isNot(equals(await b.extractBytes())));
  });

  test('derives a different key per secret', () async {
    final salt = service.generateSalt();

    final a = await service.deriveKey(secret: 'password', salt: salt);
    final b = await service.deriveKey(secret: 'Password', salt: salt);

    expect(await a.extractBytes(), isNot(equals(await b.extractBytes())));
  });

  test('derives a 256-bit key', () async {
    final key = await service.deriveKey(
      secret: 'password',
      salt: service.generateSalt(),
    );

    expect((await key.extractBytes()).length, 32);
  });

  test('generates a 16-byte random salt', () {
    final a = service.generateSalt();
    final b = service.generateSalt();

    expect(a.length, 16);
    expect(a, isNot(equals(b)));
  });
}
