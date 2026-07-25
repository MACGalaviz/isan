import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:isan/services/auth_service.dart';
import 'package:isan/services/supabase_service.dart';
import 'package:isan/services/security/key_manager_service.dart';
import 'package:isan/services/database_service.dart';
import 'package:isan/services/security/encryption_service.dart';
import 'package:isan/services/security/session_key_service.dart';
import 'package:isan/models/note.dart';
import 'package:isan/db/database.dart';
import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' hide Column;

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _isLogin = true;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please fill in all fields")),
        );
      }
      return;
    }

    if (mounted) setState(() => _isLoading = true);

    String? errorMessage;
    String? warning;

    if (_isLogin) {

      // Local-mode notes are encrypted with the device LMK. Signing in swaps
      // the session key for the account UMK, so they must be re-encrypted or
      // they become unreadable. Hold on to the LMK until that's done.
      SecretKey? localKeyToMigrate;

      if (KeyManagerService.instance.currentMode == KeyMode.local) {
        final localNotes = await DatabaseService().db.select(DatabaseService().db.notes).get();
        if (localNotes.isNotEmpty) {
          final migrate = await _confirmMigrateOnLogin(localNotes.length);
          if (migrate != true) {
            errorMessage = "Sign in cancelled. Your local notes are untouched.";
          } else {
            localKeyToMigrate = SessionKeyService.instance.key;
          }
        }
      }

      errorMessage ??= await _authService.signIn(email: email, password: password);

      if (errorMessage == null) {
        // Download and decrypt the account UMK (multi-device unlock)
        var unlocked =
            await KeyManagerService.instance.loginWithPassword(password: password);

        if (!unlocked) {
          // Password can't unwrap the UMK (e.g. after an email password reset).
          // Offer recovery via the 12-word phrase, then re-wrap for next time.
          unlocked = await _recoverWithPhraseFlow(password);
          if (!unlocked) {
            errorMessage = "Could not unlock your notes.";
            await _authService.signOut();
          }
        }

        if (unlocked) {
          if (localKeyToMigrate != null) {
            try {
              await _reencryptAllNotes(
                localKeyToMigrate,
                SessionKeyService.instance.key,
              );
            } catch (e) {
              // The notes are still LMK-encrypted, so undo the sign-in rather
              // than leave the session holding a key that can't read them.
              await KeyManagerService.instance.restoreLocalMode(localKeyToMigrate);
              await _authService.signOut();
              errorMessage = "Could not migrate your local notes: $e";
            }

            if (errorMessage == null) {
              try {
                await _uploadAllNotesToCloud();
              } catch (e) {
                // Re-encryption landed, so the notes are readable on this
                // device; only the cloud copy is missing.
                warning = "Signed in, but some notes couldn't upload yet.";
              }
            }
          }

          if (errorMessage == null) {
            await DatabaseService().syncFromCloud();
          }
        }
      }
    } else {
      final isLocal = KeyManagerService.instance.currentMode == KeyMode.local;
      
      errorMessage = await _authService.signUp(email: email, password: password);
      
      if (errorMessage == null) {
        // Wait for Supabase session to be fully established
        await Future.delayed(const Duration(milliseconds: 500));
        
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) {
          errorMessage = "Authentication failed - no user session";
        } else {
          debugPrint('✅ User authenticated: ${user.id}');
          
          // Auth succeeded, now setup encryption
          if (isLocal) {
            // User had local notes → migrate them
            try {
              await KeyManagerService.instance.migrateLocalToUser(
                password: password,
                reencryptNotes: _reencryptAllNotes,
              );

              // Upload separately: once the migration lands the notes are
              // readable under the UMK, so a failed upload is not a failed
              // migration.
              try {
                await _uploadAllNotesToCloud();
              } catch (e, stackTrace) {
                debugPrint("❌ Upload after migration failed: $e\n$stackTrace");
                warning = "Account created, but some notes couldn't upload yet.";
              }
            } catch (e, stackTrace) {
              // The message alone never says which call threw.
              // ignore: avoid_print
              print("❌ Migration failed: $e\n$stackTrace"); // TEMP: release debug
              debugPrint("❌ Migration failed: $e\n$stackTrace");
              errorMessage = "Migration failed: $e";
              await _authService.signOut();
            }
          } else {
            // Fresh user → just create UMK
            try {
              await KeyManagerService.instance.createUserAccount(password: password);
            } catch (e, stackTrace) {
              debugPrint("❌ Encryption setup failed: $e\n$stackTrace");
              errorMessage = "Failed to create encryption: $e";
              await _authService.signOut();
            }
          }
        }
      }
    }

    if (mounted) setState(() => _isLoading = false);

    if (errorMessage != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } else {
      // Signup: show the recovery phrase once before closing
      if (!_isLogin) {
        final phrase = KeyManagerService.instance.recoveryPhrase;
        if (phrase != null && mounted) {
          await _showRecoveryPhrase(phrase);
          KeyManagerService.instance.clearRecoveryPhrase();
        }
      }

      if (mounted) {
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              warning ?? (_isLogin ? "Welcome back!" : "Account created!"),
            ),
          ),
        );
      }
    }
  }

  /// Shows the recovery phrase after signup. The user must acknowledge it.
  Future<void> _showRecoveryPhrase(String phrase) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          title: const Text("Save your recovery phrase"),
          content: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "If you forget your password, this phrase is the ONLY way to "
                  "recover your notes. Write it down and keep it somewhere safe.",
                ),
                const SizedBox(height: 16),
                _recoveryGrid(theme, phrase.split(' ')),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: phrase));
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text("Phrase copied")),
                  );
                }
              },
              child: const Text("Copy"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("I saved it"),
            ),
          ],
        );
      },
    );
  }

  /// Read-only 3-column grid (3 × 4) showing the numbered recovery words.
  Widget _recoveryGrid(ThemeData theme, List<String> words) {
    const cols = 3;
    final rows = (words.length / cols).ceil();
    return Column(
      children: [
        for (var r = 0; r < rows; r++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                for (var c = 0; c < cols; c++) ...[
                  Expanded(
                    child: (r * cols + c) < words.length
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${r * cols + c + 1}. ${words[r * cols + c]}',
                              style: theme.textTheme.titleSmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          )
                        : const SizedBox(),
                  ),
                  if (c < cols - 1) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
      ],
    );
  }

  /// Recovery flow: ask for the phrase, unlock the UMK, then re-wrap the
  /// password slot so future logins with the current password work.
  Future<bool> _recoverWithPhraseFlow(String password) async {
    final phrase = await _promptRecoveryPhrase();
    if (phrase == null) return false;

    final canonical =
        phrase.trim().toLowerCase().split(RegExp(r'\s+')).join(' ');
    if (canonical.isEmpty) return false;

    final ok = await KeyManagerService.instance
        .recoverWithPhrase(recoveryPhrase: canonical);
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid recovery phrase")),
        );
      }
      return false;
    }

    await KeyManagerService.instance.rewrapPasswordSlot(password: password);
    await DatabaseService().syncFromCloud();
    return true;
  }

  /// Prompts the user to type their 12-word recovery phrase.
  Future<String?> _promptRecoveryPhrase() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Recover with phrase"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Your password couldn't unlock your notes. Enter your 12-word "
              "recovery phrase to restore access.",
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 2,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: "word1 word2 word3 ...",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text("Recover"),
          ),
        ],
      ),
    );
  }

  /// Sends a password reset email. After resetting, the user logs in with the
  /// new password and is prompted for their recovery phrase to unlock notes.
  Future<void> _forgotPassword() async {
    final controller = TextEditingController(text: _emailController.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reset password"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "We'll email you a reset link. After resetting, log in with your "
              "new password — you'll then be asked for your recovery phrase to "
              "unlock your notes.",
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text("Send"),
          ),
        ],
      ),
    );

    if (email == null || email.isEmpty) return;

    final err = await _authService.resetPassword(email: email);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err ?? "Reset link sent. Check your email.")),
      );
    }
  }

  /// Asks before pulling device-local notes into the account being signed in.
  Future<bool?> _confirmMigrateOnLogin(int noteCount) {
    final label = noteCount == 1 ? "note" : "notes";

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Move your local notes?"),
        content: Text(
          "You have $noteCount $label on this device that aren't in any "
          "account. Signing in will move them into this one.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Move them"),
          ),
        ],
      ),
    );
  }

  /// Re-encrypt all notes from old key to new key
  Future<void> _reencryptAllNotes(SecretKey oldKey, SecretKey newKey) async {
    final db = DatabaseService().db;
    
    final allNotes = await db.select(db.notes).get();
    
    debugPrint('🔄 Re-encrypting ${allNotes.length} notes...');
    
    final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? 'local_user';
    
    // Process in a transaction to avoid stream updates during migration
    await db.transaction(() async {
      for (final note in allNotes) {
        try {
          // Decrypt title + content with old key (LMK)
          final plainTitle = await EncryptionService.instance.decrypt(
            cipherText: note.title,
            key: oldKey,
          );
          final plaintext = await EncryptionService.instance.decrypt(
            cipherText: note.content,
            key: oldKey,
          );

          // Encrypt with new key (UMK)
          final newTitle = await EncryptionService.instance.encrypt(
            plainText: plainTitle,
            key: newKey,
          );
          final newCiphertext = await EncryptionService.instance.encrypt(
            plainText: plaintext,
            key: newKey,
          );

          // Update in DB with new userId and encrypted title/content
          await (db.update(db.notes)..where((t) => t.id.equals(note.id)))
              .write(NotesCompanion(
                title: Value(newTitle),
                content: Value(newCiphertext),
                userId: Value(currentUserId), // Update userId
                isSynced: const Value(false), // Mark for re-sync
              ));
              
          debugPrint('✅ Re-encrypted: ${note.title}');
        } catch (e) {
          debugPrint('❌ Failed to re-encrypt note ${note.id}: $e');
          rethrow; // Fail the entire transaction if one note fails
        }
      }
    });
    
    debugPrint('✅ Re-encrypted ${allNotes.length} notes successfully');
  }

  /// Upload all notes to Supabase after migration
  Future<void> _uploadAllNotesToCloud() async {
    final db = DatabaseService().db;
    final supabaseService = SupabaseService();
    
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      debugPrint('❌ Cannot upload - no authenticated user');
      throw Exception('User not authenticated');
    }
    
    debugPrint('✅ Uploading as user: ${currentUser.id}');
    
    final allNotes = await db.select(db.notes).get();
    
    debugPrint('☁️ Uploading ${allNotes.length} notes to Supabase...');
    
    int uploaded = 0;
    int failed = 0;
    
    for (final noteDb in allNotes) {
      try {
        final note = Note(
          id: noteDb.id,
          uuid: noteDb.uuid,
          userId: currentUser.id, // Use real user ID
          title: noteDb.title,
          content: noteDb.content, // Already encrypted
          createdAt: noteDb.createdAt,
          updatedAt: noteDb.updatedAt,
          isSynced: false,
          type: NoteType.fromName(noteDb.noteType),
          isLocked: noteDb.isLocked,
          passwordHash: noteDb.passwordHash,
        );

        await supabaseService.syncNote(note);
        
        await (db.update(db.notes)..where((t) => t.id.equals(noteDb.id)))
            .write(NotesCompanion(
              isSynced: const Value(true),
              userId: Value(currentUser.id), // Update userId in DB too
            ));
        
        uploaded++;
        debugPrint('✅ Uploaded: ${noteDb.title}');
      } catch (e) {
        failed++;
        debugPrint('❌ Failed to upload ${noteDb.title}: $e');
      }
    }
    
    debugPrint('✅ Upload complete: $uploaded successful, $failed failed');

    if (failed > 0) {
      throw Exception('$failed of ${allNotes.length} notes failed to upload');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Using Padding instead of Scaffold for better Modal integration
    return Padding(
      // Add padding for keyboard visibility (avoid obstruction)
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24, 
        right: 24, 
        top: 24
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min, // Wrap content height
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            
            const Icon(Icons.lock_person_outlined, size: 60),
            const SizedBox(height: 16),
            
            Text(
              _isLogin ? "Welcome Back" : "Create Account",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),

            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                )
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_isLogin ? "Login" : "Sign Up"),
            ),
            const SizedBox(height: 16),

            TextButton(
              onPressed: () {
                setState(() {
                  _isLogin = !_isLogin;
                });
              },
              child: Text(
                _isLogin
                ? "Don't have an account? Sign Up"
                : "Already have an account? Login"
              ),
            ),

            if (_isLogin)
              TextButton(
                onPressed: _isLoading ? null : _forgotPassword,
                child: const Text("Forgot password?"),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}