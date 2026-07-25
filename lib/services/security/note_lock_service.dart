import 'dart:convert';
import 'dart:typed_data';

import 'package:isan/services/security/key_derivation_service.dart';

/// Per-note password lock.
///
/// This is an app-level gate, NOT an extra crypto layer: the note is already
/// encrypted with the UMK like every other note. The hash only guards the UI,
/// which is what makes the lock recoverable for the account owner.
class NoteLockService {
  NoteLockService._();

  static final NoteLockService instance = NoteLockService._();

  /// Derives the stored representation of a note password: "salt:hash"
  /// (both base64).
  Future<String> hashPassword(String password) async {
    final salt = KeyDerivationService.instance.generateSalt();
    final hash = await _derive(password, salt);
    return '${base64Encode(salt)}:${base64Encode(hash)}';
  }

  /// Checks a password against the value produced by [hashPassword].
  Future<bool> verifyPassword(String password, String storedHash) async {
    final parts = storedHash.split(':');
    if (parts.length != 2) return false;

    final salt = Uint8List.fromList(base64Decode(parts[0]));
    final expected = base64Decode(parts[1]);
    final actual = await _derive(password, salt);

    if (actual.length != expected.length) return false;

    // Constant-time comparison
    var diff = 0;
    for (var i = 0; i < actual.length; i++) {
      diff |= actual[i] ^ expected[i];
    }
    return diff == 0;
  }

  Future<List<int>> _derive(String password, Uint8List salt) async {
    final key = await KeyDerivationService.instance.deriveKey(
      secret: password,
      salt: salt,
    );
    return key.extractBytes();
  }
}
