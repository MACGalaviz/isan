import 'dart:convert';
import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter/foundation.dart';
import 'package:cryptography/cryptography.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:isan/services/security/encryption_service.dart';
import 'package:isan/services/security/key_derivation_service.dart';
import 'package:isan/services/security/key_storage_service.dart';
import 'package:isan/services/security/session_key_service.dart';

/// Operation modes for key management
enum KeyMode { local, user }

/// Central orchestrator for ISAN's encryption keys
/// Handles cloud-synced encrypted UMK with password and recovery phrase
class KeyManagerService {
  KeyManagerService._();
  static final KeyManagerService instance = KeyManagerService._();

  final KeyStorageService _storage = KeyStorageService();
  final KeyDerivationService _kdf = KeyDerivationService.instance;
  final SessionKeyService _session = SessionKeyService.instance;
  final EncryptionService _encryption = EncryptionService.instance;

  KeyMode? _currentMode;
  KeyMode? get currentMode => _currentMode;

  String? _cachedRecoveryPhrase; // Store temporarily during signup
  String? get recoveryPhrase => _cachedRecoveryPhrase;

  // INITIALIZATION - Call on app startup

  Future<void> initialize() async {
    final hasStoredKey = await _storage.hasMasterKey();
    
    if (!hasStoredKey) {
      await _initializeLocalMode();
      return;
    }

    final mode = await _storage.getMode();
    
    if (mode == 'local') {
      await _loadLocalMasterKey();
    } else if (mode == 'user') {
      await _loadUserMasterKey();
    } else {
      await _loadLocalMasterKey();
    }
  }

  // LOCAL MODE

  Future<void> _initializeLocalMode() async {
    final lmk = await AesGcm.with256bits().newSecretKey();
    final lmkBytes = await lmk.extractBytes();
    final lmkBase64 = base64Encode(lmkBytes);

    await _storage.saveMasterKey(lmkBase64);
    await _storage.saveMode('local');

    _session.setKey(lmk);
    _currentMode = KeyMode.local;

    debugPrint('✅ Local mode initialized');
  }

  Future<void> _loadLocalMasterKey() async {
    final lmkBase64 = await _storage.getMasterKey();
    if (lmkBase64 == null) {
      throw StateError('Local master key not found');
    }

    final lmkBytes = base64Decode(lmkBase64);
    final lmk = SecretKey(lmkBytes);

    _session.setKey(lmk);
    _currentMode = KeyMode.local;

    debugPrint('✅ Local master key loaded');
  }

  // USER MODE

  Future<void> _loadUserMasterKey() async {
    final umkBase64 = await _storage.getMasterKey();
    if (umkBase64 == null) {
      throw StateError('User master key not found');
    }

    final umkBytes = base64Decode(umkBase64);
    final umk = SecretKey(umkBytes);

    _session.setKey(umk);
    _currentMode = KeyMode.user;

    debugPrint('✅ User master key loaded');
  }

  // SIGNUP - Create account with encrypted UMK

  Future<void> createUserAccount({
    required String password,
  }) async {
    final umk = await AesGcm.with256bits().newSecretKey();
    final umkBytes = await umk.extractBytes();
    final umkBase64 = base64Encode(umkBytes);

    _cachedRecoveryPhrase = _generateRecoveryPhrase();
    debugPrint('🔑 Recovery phrase generated (SHOW TO USER)');

    final saltPassword = _kdf.generateSalt();
    final saltRecovery = _kdf.generateSalt();

    final pdk = await _kdf.deriveKey(
      secret: password,
      salt: saltPassword,
    );

    final rdk = await _kdf.deriveKey(
      secret: _cachedRecoveryPhrase!,
      salt: saltRecovery,
    );

    final encryptedWithPassword = await _encryption.encrypt(
      plainText: umkBase64,
      key: pdk,
    );

    final encryptedWithRecovery = await _encryption.encrypt(
      plainText: umkBase64,
      key: rdk,
    );

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw StateError('No authenticated user');

    await Supabase.instance.client.from('user_keys').upsert({
      'user_id': user.id,
      'encrypted_umk_password': encryptedWithPassword,
      'encrypted_umk_recovery': encryptedWithRecovery,
      'salt_password': base64Encode(saltPassword),
      'salt_recovery': base64Encode(saltRecovery),
      'updated_at': DateTime.now().toIso8601String(),
    });

    // Cached in the clear so the app opens offline
    await _storage.saveMasterKey(umkBase64);
    await _storage.saveMode('user');

    _session.setKey(umk);
    _currentMode = KeyMode.user;

    debugPrint('✅ User account created with cloud-synced encrypted UMK');
  }

  // LOGIN - Download and decrypt UMK

  Future<bool> loginWithPassword({
    required String password,
  }) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw StateError('No authenticated user');

      final response = await Supabase.instance.client
          .from('user_keys')
          .select()
          .eq('user_id', user.id)
          .single();

      final encryptedUmk = response['encrypted_umk_password'] as String;
      final saltBase64 = response['salt_password'] as String;
      final salt = base64Decode(saltBase64);

      final pdk = await _kdf.deriveKey(
        secret: password,
        salt: salt,
      );

      final umkBase64 = await _encryption.decrypt(
        cipherText: encryptedUmk,
        key: pdk,
      );

      final umkBytes = base64Decode(umkBase64);
      final umk = SecretKey(umkBytes);

      await _storage.saveMasterKey(umkBase64);
      await _storage.saveMode('user');

      _session.setKey(umk);
      _currentMode = KeyMode.user;

      debugPrint('✅ Logged in with password');
      return true;
    } catch (e) {
      debugPrint('❌ Login failed: $e');
      return false;
    }
  }

  // RECOVERY - Recover with phrase

  Future<bool> recoverWithPhrase({
    required String recoveryPhrase,
  }) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw StateError('No authenticated user');

      final response = await Supabase.instance.client
          .from('user_keys')
          .select()
          .eq('user_id', user.id)
          .single();

      final encryptedUmk = response['encrypted_umk_recovery'] as String;
      final saltBase64 = response['salt_recovery'] as String;
      final salt = base64Decode(saltBase64);

      final rdk = await _kdf.deriveKey(
        secret: recoveryPhrase,
        salt: salt,
      );

      final umkBase64 = await _encryption.decrypt(
        cipherText: encryptedUmk,
        key: rdk,
      );

      final umkBytes = base64Decode(umkBase64);
      final umk = SecretKey(umkBytes);

      await _storage.saveMasterKey(umkBase64);
      await _storage.saveMode('user');

      _session.setKey(umk);
      _currentMode = KeyMode.user;

      debugPrint('✅ Recovered with phrase');
      return true;
    } catch (e) {
      debugPrint('❌ Recovery failed: $e');
      return false;
    }
  }

  // RE-WRAP PASSWORD SLOT

  /// Re-encrypt the current session UMK under a (new) password.
  /// Called after recovering with the phrase so future password logins work
  /// again — closes the "password changed by email reset" gap.
  Future<void> rewrapPasswordSlot({
    required String password,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw StateError('No authenticated user');

    final umkBytes = await _session.key.extractBytes();
    final umkBase64 = base64Encode(umkBytes);

    final saltPassword = _kdf.generateSalt();
    final pdk = await _kdf.deriveKey(secret: password, salt: saltPassword);
    final encryptedWithPassword =
        await _encryption.encrypt(plainText: umkBase64, key: pdk);

    await Supabase.instance.client.from('user_keys').update({
      'encrypted_umk_password': encryptedWithPassword,
      'salt_password': base64Encode(saltPassword),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('user_id', user.id);

    debugPrint('✅ Password slot re-wrapped');
  }

  // MIGRATION

  Future<void> migrateLocalToUser({
    required String password,
    required Future<void> Function(SecretKey oldKey, SecretKey newKey) reencryptNotes,
  }) async {
    if (_currentMode != KeyMode.local) {
      throw StateError('Can only migrate from local mode');
    }

    debugPrint('🔄 Starting migration: Local → User');

    final oldLmk = _session.key;
    final umk = await AesGcm.with256bits().newSecretKey();

    debugPrint('🔄 Re-encrypting notes...');
    await reencryptNotes(oldLmk, umk);
    debugPrint('✅ Notes re-encrypted in DB');

    _session.setKey(umk);
    debugPrint('✅ Session key updated to UMK');

    _cachedRecoveryPhrase = _generateRecoveryPhrase();
    debugPrint('🔑 Recovery phrase generated (SHOW TO USER)');

    final umkBytes = await umk.extractBytes();
    final umkBase64 = base64Encode(umkBytes);

    final saltPassword = _kdf.generateSalt();
    final saltRecovery = _kdf.generateSalt();

    final pdk = await _kdf.deriveKey(secret: password, salt: saltPassword);
    final rdk = await _kdf.deriveKey(secret: _cachedRecoveryPhrase!, salt: saltRecovery);

    final encryptedWithPassword = await _encryption.encrypt(plainText: umkBase64, key: pdk);
    final encryptedWithRecovery = await _encryption.encrypt(plainText: umkBase64, key: rdk);

    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      await Supabase.instance.client.from('user_keys').upsert({
        'user_id': user.id,
        'encrypted_umk_password': encryptedWithPassword,
        'encrypted_umk_recovery': encryptedWithRecovery,
        'salt_password': base64Encode(saltPassword),
        'salt_recovery': base64Encode(saltRecovery),
      });
    }

    await _storage.saveMasterKey(umkBase64);
    await _storage.saveMode('user');
    _currentMode = KeyMode.user;

    debugPrint('✅ Migration complete: Local → User');
  }

  // UTILITIES

  /// Generate a BIP39 12-word recovery phrase (128-bit entropy)
  String _generateRecoveryPhrase() {
    return bip39.generateMnemonic(); // defaults to 128-bit strength = 12 words
  }

  void clearRecoveryPhrase() {
    _cachedRecoveryPhrase = null;
  }

  /// Lock the app
  void lock() {
    _session.clear();
    debugPrint('🔒 App locked');
  }

  /// Logout
  Future<void> logout() async {
    await _storage.clearAll();
    _session.clear();
    _cachedRecoveryPhrase = null;

    // Back to fresh-install state: without a new LMK the app has no key at all
    // and every save throws until the next restart.
    await _initializeLocalMode();

    debugPrint('👋 Logged out');
  }

  bool get isUnlocked => _session.hasKey;
}