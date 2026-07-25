import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage for encryption keys and metadata
/// Stores:
/// - Master key (LMK or UMK, both in plaintext)
/// - Salt (for key derivation)
/// - Mode (local or user)
class KeyStorageService {
  static const _storage = FlutterSecureStorage();

  // Storage keys
  static const _masterKeyKey = 'master_key';
  static const _saltKey = 'key_salt';
  static const _modeKey = 'key_mode';

  /// ========================================================================
  /// MASTER KEY
  /// ========================================================================

  /// Save master key (base64 encoded)
  ///
  /// Plaintext in both modes — the OS keystore is the only barrier here. The
  /// password-wrapped copy of the UMK lives in the cloud (`user_keys`); this
  /// cache exists so the app opens offline without asking for the password.
  Future<void> saveMasterKey(String base64Key) async {
    await _storage.write(
      key: _masterKeyKey,
      value: base64Key,
    );
  }

  /// Get master key (base64 encoded)
  Future<String?> getMasterKey() async {
    return await _storage.read(key: _masterKeyKey);
  }

  /// Check if master key exists
  Future<bool> hasMasterKey() async {
    final key = await getMasterKey();
    return key != null && key.isNotEmpty;
  }

  /// ========================================================================
  /// SALT
  /// ========================================================================

  /// Save salt for key derivation (base64 encoded)
  /// Used in user mode to derive PDK from password
  Future<void> saveSalt(String base64Salt) async {
    await _storage.write(
      key: _saltKey,
      value: base64Salt,
    );
  }

  /// Get salt (base64 encoded)
  Future<String?> getSalt() async {
    return await _storage.read(key: _saltKey);
  }

  /// ========================================================================
  /// MODE
  /// ========================================================================

  /// Save current mode ('local' or 'user')
  Future<void> saveMode(String mode) async {
    if (mode != 'local' && mode != 'user') {
      throw ArgumentError('Mode must be "local" or "user"');
    }
    await _storage.write(
      key: _modeKey,
      value: mode,
    );
  }

  /// Get current mode
  Future<String?> getMode() async {
    return await _storage.read(key: _modeKey);
  }

  /// ========================================================================
  /// CLEANUP
  /// ========================================================================

  /// Clear master key only
  Future<void> clearMasterKey() async {
    await _storage.delete(key: _masterKeyKey);
  }

  /// Clear all encryption data
  /// Called on logout
  Future<void> clearAll() async {
    await _storage.delete(key: _masterKeyKey);
    await _storage.delete(key: _saltKey);
    await _storage.delete(key: _modeKey);
  }
}