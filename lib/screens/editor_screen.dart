import 'package:flutter/material.dart';
import 'package:isan/models/note.dart';
import 'package:isan/services/database_service.dart';
import 'package:isan/services/security/note_lock_service.dart';
import 'package:isan/services/security/key_manager_service.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditorScreen extends StatefulWidget {
  final Note? note;

  const EditorScreen({super.key, this.note});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _unlockController = TextEditingController();
  final _dbService = DatabaseService();
  
  final FocusNode _titleFocus = FocusNode();
  final FocusNode _contentFocus = FocusNode();

  late Note _note;
  bool _isSaving = false;

  /// Per-note lock gate: content stays hidden until the password is entered.
  bool _unlocked = true;

  @override
  void initState() {
    super.initState();

    if (widget.note != null) {
      // EDIT MODE
      _note = widget.note!;
      _titleController.text = _note.title;
      _contentController.text = _note.content;
      _unlocked = !_note.isProtected;
    } else {
      // CREATE MODE
      final userId = Supabase.instance.client.auth.currentUser?.id ?? "local_user";

      _note = Note(
        id: -1, // Not in SQLite yet
        uuid: const Uuid().v4(),
        userId: userId,
        title: "",
        content: "",
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isSynced: false,
        isLocked: false,
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _unlockController.dispose();
    _titleFocus.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  Future<bool> _saveOrDelete() async {
    if (_isSaving) return false;
    // Locked and never unlocked: the editor holds no user intent, so saving
    // (and worse, the empty-note delete below) must not run.
    if (!_unlocked) return false;
    _isSaving = true;

    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (_note.title == title && _note.content == content) {
      _isSaving = false;
      return false;
    }

    // An emptied note is a deletion
    if (title.isEmpty && content.isEmpty) {
      if (_note.id != -1) {
        await _dbService.deleteNote(_note.id);
        _isSaving = false;
        return true;
      }
      _isSaving = false;
      return false;
    }

    final updatedNote = _note.copyWith(
      title: title,
      content: content,
      updatedAt: DateTime.now().toUtc(), // UTC to keep timezones out of sync
      isSynced: false,
    );

    final savedId = await _dbService.saveNote(updatedNote);

    // Carries the real id back for notes that were just created
    _note = updatedNote.copyWith(id: savedId);
    
    _isSaving = false;
    return true; 
  }

  Future<void> _unlockNote() async {
    final ok = await NoteLockService.instance
        .verifyPassword(_unlockController.text, _note.passwordHash!);

    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Wrong password")),
      );
      return;
    }

    _unlockController.clear();
    setState(() => _unlocked = true);
  }

  /// Asks for a new password (twice) and locks the note.
  Future<void> _addLock() async {
    // The lock is stored per row, so the note must exist first.
    await _saveOrDelete();
    if (_note.id == -1) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Write something before locking")),
        );
      }
      return;
    }

    final password = await _askNewPassword();
    if (password == null) return;

    final hash = await NoteLockService.instance.hashPassword(password);
    await _dbService.setNoteLock(_note.id, hash);

    if (!mounted) return;
    setState(() {
      _note = _note.copyWith(isLocked: true, passwordHash: hash);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Note locked")),
    );
  }

  /// Removes the lock. Requires the note password, unless it was already
  /// unlocked in this session.
  Future<void> _removeLock() async {
    if (!_unlocked) {
      final password = await _askPassword(title: "Remove lock");
      if (password == null) return;

      final ok = await NoteLockService.instance
          .verifyPassword(password, _note.passwordHash!);
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Wrong password")),
          );
        }
        return;
      }
    }

    await _dbService.setNoteLock(_note.id, null);

    if (!mounted) return;
    setState(() {
      _note = _note.withoutLock();
      _unlocked = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Lock removed")),
    );
  }

  /// Recovery: the lock is a UI gate over a note already encrypted with the
  /// UMK, so the account password is enough to reset it. Asking for it (instead
  /// of a one-tap removal) keeps whoever holds an unlocked device out.
  Future<void> _forgotPassword() async {
    final accountPassword = await _askPassword(
      title: "Forgot note password?",
      label: "Account password",
      helper: "Enter your account password to remove the lock.",
    );
    if (accountPassword == null || accountPassword.isEmpty) return;

    // Verifies against the cloud-wrapped UMK, so it needs a connection.
    final ok = await KeyManagerService.instance.loginWithPassword(
      password: accountPassword,
    );

    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Wrong account password (or no connection)"),
        ),
      );
      return;
    }

    await _dbService.setNoteLock(_note.id, null);

    if (!mounted) return;
    setState(() {
      _note = _note.withoutLock();
      _unlocked = true;
    });
  }

  Future<String?> _askPassword({
    required String title,
    String label = "Note password",
    String? helper,
  }) {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (helper != null) ...[
              Text(helper, style: Theme.of(ctx).textTheme.bodyMedium),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(labelText: label),
              onSubmitted: (value) => Navigator.pop(ctx, value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }

  Future<String?> _askNewPassword() {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    String? error;

    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          void submit() {
            final password = passwordController.text;
            if (password.isEmpty) {
              setDialogState(() => error = "Password can't be empty");
              return;
            }
            if (password != confirmController.text) {
              setDialogState(() => error = "Passwords don't match");
              return;
            }
            Navigator.pop(ctx, password);
          }

          return AlertDialog(
            title: const Text("Lock note"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: "Password"),
                ),
                TextField(
                  controller: confirmController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: "Confirm password",
                    errorText: error,
                  ),
                  onSubmitted: (_) => submit(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              TextButton(onPressed: submit, child: const Text("Lock")),
            ],
          );
        },
      ),
    );
  }

  void _deleteNote() async {
    if (_note.id != -1) { 
      await _dbService.deleteNote(_note.id);
    }
    if (mounted) Navigator.pop(context);
  }

  Widget _buildLockedView(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_outline,
            size: 56,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text("This note is locked", style: theme.textTheme.titleMedium),
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: TextField(
              controller: _unlockController,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: "Note password",
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => _unlockNote(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _unlockNote, child: const Text("Unlock")),
          TextButton(
            onPressed: _forgotPassword,
            child: const Text("Forgot password?"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false, 
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // Auto-save on exit
        await _saveOrDelete(); 

        if (context.mounted) {
          Navigator.of(context).pop(result);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              onPressed: _note.isProtected ? _removeLock : _addLock,
              icon: Icon(
                _note.isProtected ? Icons.lock : Icons.lock_open_outlined,
              ),
              tooltip: _note.isProtected ? 'Remove lock' : 'Lock note',
            ),

            if (_unlocked)
            IconButton(
              onPressed: () async {
                FocusScope.of(context).unfocus();
                bool saved = await _saveOrDelete();
                
                if (saved && context.mounted) {
                  setState(() {}); 
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text("Note saved"), 
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.check),
            ),
            
            if (_unlocked && _note.id != -1)
              IconButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(
                        "Delete Note?",
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                      content: Text(
                        "This action cannot be undone.",
                        style: theme.textTheme.bodyLarge,
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          
                          child: const Text("Cancel"),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _deleteNote();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: theme.colorScheme.error,
                          ),
                          child: const Text("Delete"),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.delete_outline), 
              ),
            const SizedBox(width: 8),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            children: [
              TextField(
                controller: _titleController,
                focusNode: _titleFocus,
                enabled: _unlocked, // Title stays visible, editing does not
                onSubmitted: (_) {
                  FocusScope.of(context).requestFocus(_contentFocus);
                },
                textInputAction: TextInputAction.next,
                style: Theme.of(context).textTheme.titleLarge,
                decoration: InputDecoration(
                  hintText: 'Title',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 8),
              if (_unlocked)
                Expanded(
                  child: TextField(
                    controller: _contentController,
                    focusNode: _contentFocus,
                    style: Theme.of(context).textTheme.bodyLarge,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: const InputDecoration(
                      hintText: 'Start typing...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                )
              else
                Expanded(child: _buildLockedView(theme)),
            ],
          ),
        ),
      ),
    );
  }
}