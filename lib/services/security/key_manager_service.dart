import 'dart:convert';
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
/// Decides between LMK (Local Master Key) and UMK (User Master Key)
/// Handles bootstrap, migration, and key lifecycle
class KeyManagerService {
  KeyManagerService._();
  static final KeyManagerService instance = KeyManagerService._();

  final KeyStorageService _storage = KeyStorageService();
  final KeyDerivationService _kdf = KeyDerivationService.instance;
  final SessionKeyService _session = SessionKeyService.instance;
  final EncryptionService _encryption = EncryptionService.instance;

  KeyMode? _currentMode;
  KeyMode? get currentMode => _currentMode;

  /// ========================================================================
  /// INITIALIZATION - Call on app startup
  /// ========================================================================

  /// Bootstrap: decide which mode to use and load the corresponding key
  Future<void> initialize() async {
    // 1. Check if a key is already stored
    final hasStoredKey = await _storage.hasMasterKey();
    
    if (!hasStoredKey) {
      // First time: default to local mode
      await _initializeLocalMode();
      return;
    }

    // 2. Load the stored key (don't care if it's LMK or UMK)
    final mode = await _storage.getMode();
    
    if (mode == 'local') {
      await _loadLocalMasterKey();
    } else if (mode == 'user') {
      // Load UMK (it's stored encrypted, but we'll load it decrypted after unlock)
      // For now, this means user needs to login/unlock first
      // TODO: Auto-unlock if Supabase session exists
      await _loadUserMasterKey();
    } else {
      // Fallback: no mode saved, assume local
      await _loadLocalMasterKey();
    }
  }

  /// ========================================================================
  /// LOCAL MODE (No user account)
  /// ========================================================================

  /// Initialize local mode: generate new LMK
  Future<void> _initializeLocalMode() async {
    // Generate random 256-bit key
    final lmk = await AesGcm.with256bits().newSecretKey();
    final lmkBytes = await lmk.extractBytes();
    final lmkBase64 = base64Encode(lmkBytes);

    // Save to secure storage (unencrypted - device-bound)
    await _storage.saveMasterKey(lmkBase64);
    await _storage.saveMode('local');

    // Load into session
    _session.setKey(lmk);
    _currentMode = KeyMode.local;

    print('✅ Local mode initialized');
  }

  /// Load existing LMK from storage
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

  /// Load existing UMK from storage (stored as plaintext after migration)
  Future<void> _loadUserMasterKey() async {
    final umkBase64 = await _storage.getMasterKey();
    if (umkBase64 == null) {
      throw StateError('User master key not found');
    }

    // After migration, UMK is stored as plaintext (same as LMK)
    final umkBytes = base64Decode(umkBase64);
    final umk = SecretKey(umkBytes);

    _session.setKey(umk);
    _currentMode = KeyMode.user;

    print('✅ User master key loaded');
  }

  /// ========================================================================
  /// USER MODE (With account)
  /// ========================================================================

  /// Create new user account with encryption
  /// Called during sign-up (when user has NO local notes)
  Future<void> createUserAccount({
    required String password,
  }) async {
    // Generate UMK
    final umk = await AesGcm.with256bits().newSecretKey();
    final umkBytes = await umk.extractBytes();
    final umkBase64 = base64Encode(umkBytes);

    // Save UMK (plaintext, device-bound)
    await _storage.saveMasterKey(umkBase64);
    await _storage.saveMode('user');

    // Load into session
    _session.setKey(umk);
    _currentMode = KeyMode.user;

    print('✅ User account created with encryption');
  }

  /// Unlock user account with password
  /// (Currently not needed - UMK stored as plaintext)
  /// TODO: Implement when we add password-encrypted UMK
  Future<bool> unlockUserAccount({
    required String password,
  }) async {
    // For now, UMK is already loaded from storage
    // This will be needed when we encrypt UMK with password
    print('⚠️ Unlock not yet implemented - UMK already loaded');
    return _session.hasKey;
  }

  /// ========================================================================
  /// MIGRATION: Local → User
  /// ========================================================================

  /// Migrate from local mode to user mode
  /// Called when user creates account after using local mode
  /// CRITICAL: Re-encrypts all notes with UMK without data loss
  Future<void> migrateLocalToUser({
    required String password,
    required Future<void> Function(SecretKey oldKey, SecretKey newKey) reencryptNotes,
  }) async {
    if (_currentMode != KeyMode.local) {
      throw StateError('Can only migrate from local mode');
    }

    print('🔄 Starting migration: Local → User');

    // 1. Keep reference to old LMK
    final oldLmk = _session.key;

    // 2. Generate new UMK
    final umk = await AesGcm.with256bits().newSecretKey();

    // 3. Re-encrypt all notes (LMK → UMK) in transaction
    print('🔄 Re-encrypting notes...');
    await reencryptNotes(oldLmk, umk);
    print('✅ Notes re-encrypted in DB');

    // 4. IMMEDIATELY update session key
    _session.setKey(umk);
    print('✅ Session key updated to UMK');

    // 5. REPLACE LMK with UMK in storage (as plaintext, device-bound)
    final umkBytes = await umk.extractBytes();
    final umkBase64 = base64Encode(umkBytes);
    
    await _storage.saveMasterKey(umkBase64); // Store as plaintext (device-bound)
    await _storage.saveMode('user');
    _currentMode = KeyMode.user;

    // Note: We're NOT encrypting UMK with password for now
    // UMK is stored plaintext, relying on device security
    // TODO: Encrypt UMK with password for true E2EE

    print('✅ Migration complete: Local → User');
  }

  /// ========================================================================
  /// RECOVERY PHRASE (Future enhancement)
  /// ========================================================================

  /// Generate 12-word recovery phrase
  /// Called once during user account creation
  Future<List<String>> generateRecoveryPhrase() async {
    // TODO: Implement BIP39 mnemonic generation
    // For now, return placeholder
    throw UnimplementedError('Recovery phrase generation not yet implemented');
  }

  /// Recover account using recovery phrase
  Future<bool> recoverWithPhrase({
    required List<String> words,
  }) async {
    // TODO: Derive alternative key from phrase to decrypt UMK
    throw UnimplementedError('Recovery not yet implemented');
  }

  /// ========================================================================
  /// LIFECYCLE
  /// ========================================================================

  /// Lock the app (clear session key from memory)
  /// User must unlock again
  void lock() {
    _session.clear();
    print('🔒 App locked');
  }

  /// Logout (clear everything)
  Future<void> logout() async {
    await _storage.clearAll();
    _session.clear();
    _currentMode = null;
    print('👋 Logged out');
  }

  /// Check if app is currently unlocked
  bool get isUnlocked => _session.hasKey;
}