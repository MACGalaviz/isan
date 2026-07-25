import 'package:flutter_test/flutter_test.dart';
import 'package:isan/services/security/note_lock_service.dart';

void main() {
  final service = NoteLockService.instance;

  test('accepts the correct password', () async {
    final hash = await service.hashPassword('correct horse');
    expect(await service.verifyPassword('correct horse', hash), isTrue);
  });

  test('rejects a wrong password', () async {
    final hash = await service.hashPassword('correct horse');
    expect(await service.verifyPassword('wrong horse', hash), isFalse);
  });

  test('uses a fresh salt per hash', () async {
    final a = await service.hashPassword('same');
    final b = await service.hashPassword('same');
    expect(a, isNot(equals(b)));
    expect(await service.verifyPassword('same', b), isTrue);
  });

  test('rejects a malformed stored hash', () async {
    expect(await service.verifyPassword('any', 'not-a-hash'), isFalse);
  });
}
