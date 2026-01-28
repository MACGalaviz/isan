import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:isan/services/auth_service.dart';
import 'package:isan/services/supabase_service.dart';
import 'package:isan/services/security/key_manager_service.dart';
import 'package:isan/services/database_service.dart';
import 'package:isan/services/security/encryption_service.dart';
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

    if (_isLogin) {
      // LOGIN FLOW
      errorMessage = await _authService.signIn(email: email, password: password);
      // Key already loaded from storage on app start
    } else {
      // SIGN UP FLOW
      final isLocal = KeyManagerService.instance.currentMode == KeyMode.local;
      
      errorMessage = await _authService.signUp(email: email, password: password);
      
      if (errorMessage == null) {
        // Wait for Supabase session to be fully established
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Verify user is authenticated
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) {
          errorMessage = "Authentication failed - no user session";
        } else {
          print('✅ User authenticated: ${user.id}');
          
          // Auth succeeded, now setup encryption
          if (isLocal) {
            // User had local notes → migrate them
            try {
              await KeyManagerService.instance.migrateLocalToUser(
                password: password,
                reencryptNotes: _reencryptAllNotes,
              );
              
              // After migration, sync all notes to cloud
              print('☁️ Uploading migrated notes to cloud...');
              await _uploadAllNotesToCloud();
              
            } catch (e) {
              errorMessage = "Migration failed: $e";
              await _authService.signOut();
            }
          } else {
            // Fresh user → just create UMK
            try {
              await KeyManagerService.instance.createUserAccount(password: password);
            } catch (e) {
              errorMessage = "Failed to create encryption: $e";
              await _authService.signOut();
            }
          }
        }
      }
    }

    if (mounted) setState(() => _isLoading = false);

    if (errorMessage != null) {
      // Error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } else {
      // Success - close modal and show message
      if (mounted) {
        Navigator.of(context).pop(); 
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isLogin ? "Welcome back!" : "Account created!")),
        );
      }
    }
  }

  /// Re-encrypt all notes from old key to new key
  Future<void> _reencryptAllNotes(SecretKey oldKey, SecretKey newKey) async {
    final db = DatabaseService().db;
    
    // Get snapshot of all notes (not a stream)
    final allNotes = await db.select(db.notes).get();
    
    print('🔄 Re-encrypting ${allNotes.length} notes...');
    
    // Get current user ID from Supabase
    final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? 'local_user';
    
    // Process in a transaction to avoid stream updates during migration
    await db.transaction(() async {
      for (final note in allNotes) {
        try {
          // Decrypt with old key (LMK)
          final plaintext = await EncryptionService.instance.decrypt(
            cipherText: note.content,
            key: oldKey,
          );
          
          // Encrypt with new key (UMK)
          final newCiphertext = await EncryptionService.instance.encrypt(
            plainText: plaintext,
            key: newKey,
          );
          
          // Update in DB with new userId and encrypted content
          await (db.update(db.notes)..where((t) => t.id.equals(note.id)))
              .write(NotesCompanion(
                content: Value(newCiphertext),
                userId: Value(currentUserId), // Update userId
                isSynced: const Value(false), // Mark for re-sync
              ));
              
          print('✅ Re-encrypted: ${note.title}');
        } catch (e) {
          print('❌ Failed to re-encrypt note ${note.id}: $e');
          rethrow; // Fail the entire transaction if one note fails
        }
      }
    });
    
    print('✅ Re-encrypted ${allNotes.length} notes successfully');
  }

  /// Upload all notes to Supabase after migration
  Future<void> _uploadAllNotesToCloud() async {
    final db = DatabaseService().db;
    final supabaseService = SupabaseService();
    
    // Verify user is authenticated
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      print('❌ Cannot upload - no authenticated user');
      throw Exception('User not authenticated');
    }
    
    print('✅ Uploading as user: ${currentUser.id}');
    
    // Get all notes
    final allNotes = await db.select(db.notes).get();
    
    print('☁️ Uploading ${allNotes.length} notes to Supabase...');
    
    int uploaded = 0;
    int failed = 0;
    
    for (final noteDb in allNotes) {
      try {
        // Convert to Note model
        final note = Note(
          id: noteDb.id,
          uuid: noteDb.uuid,
          userId: currentUser.id, // Use real user ID
          title: noteDb.title,
          content: noteDb.content, // Already encrypted
          createdAt: noteDb.createdAt,
          updatedAt: noteDb.updatedAt,
          isSynced: false,
          isLocked: noteDb.isLocked,
        );
        
        // Upload to Supabase
        await supabaseService.syncNote(note);
        
        // Mark as synced in local DB
        await (db.update(db.notes)..where((t) => t.id.equals(noteDb.id)))
            .write(NotesCompanion(
              isSynced: const Value(true),
              userId: Value(currentUser.id), // Update userId in DB too
            ));
        
        uploaded++;
        print('✅ Uploaded: ${noteDb.title}');
      } catch (e) {
        failed++;
        print('❌ Failed to upload ${noteDb.title}: $e');
      }
    }
    
    print('✅ Upload complete: $uploaded successful, $failed failed');
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
            // Handle bar indicator
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
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}