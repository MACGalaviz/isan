import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isan/services/security/session_key_service.dart';

void main() {
  final service = SessionKeyService.instance;

  // Singleton: each test owns the key state instead of inheriting it, so
  // 'throws before a key is set' can't be broken by test order.
  setUp(service.clear);
  tearDown(service.clear);

  test('throws before a key is set', () {
    expect(service.hasKey, isFalse);
    expect(() => service.key, throwsStateError);
  });

  test('holds the key it was given', () async {
    final key = await AesGcm.with256bits().newSecretKey();
    service.setKey(key);

    expect(service.hasKey, isTrue);
    expect(await service.key.extractBytes(), await key.extractBytes());
  });

  test('drops the key on clear', () async {
    service.setKey(await AesGcm.with256bits().newSecretKey());
    service.clear();

    expect(service.hasKey, isFalse);
    expect(() => service.key, throwsStateError);
  });
}
