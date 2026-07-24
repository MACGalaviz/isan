import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
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

  /// ========================================================================
  /// INITIALIZATION - Call on app startup
  /// ========================================================================

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

  /// ========================================================================
  /// LOCAL MODE
  /// ========================================================================

  Future<void> _initializeLocalMode() async {
    final lmk = await AesGcm.with256bits().newSecretKey();
    final lmkBytes = await lmk.extractBytes();
    final lmkBase64 = base64Encode(lmkBytes);

    await _storage.saveMasterKey(lmkBase64);
    await _storage.saveMode('local');

    _session.setKey(lmk);
    _currentMode = KeyMode.local;

    print('✅ Local mode initialized');
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

    print('✅ Local master key loaded');
  }

  /// ========================================================================
  /// USER MODE
  /// ========================================================================

  Future<void> _loadUserMasterKey() async {
    final umkBase64 = await _storage.getMasterKey();
    if (umkBase64 == null) {
      throw StateError('User master key not found');
    }

    final umkBytes = base64Decode(umkBase64);
    final umk = SecretKey(umkBytes);

    _session.setKey(umk);
    _currentMode = KeyMode.user;

    print('✅ User master key loaded');
  }

  /// ========================================================================
  /// SIGNUP - Create account with encrypted UMK
  /// ========================================================================

  Future<void> createUserAccount({
    required String password,
  }) async {
    // 1. Generate UMK
    final umk = await AesGcm.with256bits().newSecretKey();
    final umkBytes = await umk.extractBytes();
    final umkBase64 = base64Encode(umkBytes);

    // 2. Generate recovery phrase (12 words)
    _cachedRecoveryPhrase = _generateRecoveryPhrase();
    print('🔑 Recovery phrase generated (SHOW TO USER)');

    // 3. Derive keys from password and recovery phrase
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

    // 4. Encrypt UMK with both keys
    final encryptedWithPassword = await _encryption.encrypt(
      plainText: umkBase64,
      key: pdk,
    );

    final encryptedWithRecovery = await _encryption.encrypt(
      plainText: umkBase64,
      key: rdk,
    );

    // 5. Upload to Supabase
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

    // 6. Save UMK locally (plaintext cache)
    await _storage.saveMasterKey(umkBase64);
    await _storage.saveMode('user');

    // 7. Load into session
    _session.setKey(umk);
    _currentMode = KeyMode.user;

    print('✅ User account created with cloud-synced encrypted UMK');
  }

  /// ========================================================================
  /// LOGIN - Download and decrypt UMK
  /// ========================================================================

  Future<bool> loginWithPassword({
    required String password,
  }) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw StateError('No authenticated user');

      // 1. Download encrypted UMK from Supabase
      final response = await Supabase.instance.client
          .from('user_keys')
          .select()
          .eq('user_id', user.id)
          .single();

      final encryptedUmk = response['encrypted_umk_password'] as String;
      final saltBase64 = response['salt_password'] as String;
      final salt = base64Decode(saltBase64);

      // 2. Derive key from password
      final pdk = await _kdf.deriveKey(
        secret: password,
        salt: salt,
      );

      // 3. Decrypt UMK
      final umkBase64 = await _encryption.decrypt(
        cipherText: encryptedUmk,
        key: pdk,
      );

      final umkBytes = base64Decode(umkBase64);
      final umk = SecretKey(umkBytes);

      // 4. Save locally (cache)
      await _storage.saveMasterKey(umkBase64);
      await _storage.saveMode('user');

      // 5. Load into session
      _session.setKey(umk);
      _currentMode = KeyMode.user;

      print('✅ Logged in with password');
      return true;
    } catch (e) {
      print('❌ Login failed: $e');
      return false;
    }
  }

  /// ========================================================================
  /// RECOVERY - Recover with phrase
  /// ========================================================================

  Future<bool> recoverWithPhrase({
    required String recoveryPhrase,
  }) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw StateError('No authenticated user');

      // 1. Download encrypted UMK from Supabase
      final response = await Supabase.instance.client
          .from('user_keys')
          .select()
          .eq('user_id', user.id)
          .single();

      final encryptedUmk = response['encrypted_umk_recovery'] as String;
      final saltBase64 = response['salt_recovery'] as String;
      final salt = base64Decode(saltBase64);

      // 2. Derive key from recovery phrase
      final rdk = await _kdf.deriveKey(
        secret: recoveryPhrase,
        salt: salt,
      );

      // 3. Decrypt UMK
      final umkBase64 = await _encryption.decrypt(
        cipherText: encryptedUmk,
        key: rdk,
      );

      final umkBytes = base64Decode(umkBase64);
      final umk = SecretKey(umkBytes);

      // 4. Save locally (cache)
      await _storage.saveMasterKey(umkBase64);
      await _storage.saveMode('user');

      // 5. Load into session
      _session.setKey(umk);
      _currentMode = KeyMode.user;

      print('✅ Recovered with phrase');
      return true;
    } catch (e) {
      print('❌ Recovery failed: $e');
      return false;
    }
  }

  /// ========================================================================
  /// MIGRATION
  /// ========================================================================

  Future<void> migrateLocalToUser({
    required String password,
    required Future<void> Function(SecretKey oldKey, SecretKey newKey) reencryptNotes,
  }) async {
    if (_currentMode != KeyMode.local) {
      throw StateError('Can only migrate from local mode');
    }

    print('🔄 Starting migration: Local → User');

    final oldLmk = _session.key;
    final umk = await AesGcm.with256bits().newSecretKey();

    print('🔄 Re-encrypting notes...');
    await reencryptNotes(oldLmk, umk);
    print('✅ Notes re-encrypted in DB');

    _session.setKey(umk);
    print('✅ Session key updated to UMK');

    // Generate recovery phrase
    _cachedRecoveryPhrase = _generateRecoveryPhrase();
    print('🔑 Recovery phrase generated (SHOW TO USER)');

    // Encrypt and upload UMK
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

    print('✅ Migration complete: Local → User');
  }

  /// ========================================================================
  /// UTILITIES
  /// ========================================================================

  /// Generate 12-word recovery phrase
  String _generateRecoveryPhrase() {
    // Simple wordlist (in production, use BIP39)
    final words = [
      'apple', 'banana', 'cherry', 'dog', 'elephant', 'fish', 'grape', 'house',
      'ice', 'jungle', 'kite', 'lemon', 'monkey', 'night', 'ocean', 'piano',
      'queen', 'river', 'star', 'tree', 'umbrella', 'volcano', 'water', 'xylophone',
      'yellow', 'zebra', 'garden', 'mountain', 'cloud', 'bridge', 'castle', 'diamond'
    ];

    final random = Random.secure();
    final phrase = List.generate(12, (_) => words[random.nextInt(words.length)]);
    return phrase.join(' ');
  }

  void clearRecoveryPhrase() {
    _cachedRecoveryPhrase = null;
  }

  /// Lock the app
  void lock() {
    _session.clear();
    print('🔒 App locked');
  }

  /// Logout
  Future<void> logout() async {
    await _storage.clearAll();
    _session.clear();
    _currentMode = null;
    _cachedRecoveryPhrase = null;
    print('👋 Logged out');
  }

  bool get isUnlocked => _session.hasKey;
}