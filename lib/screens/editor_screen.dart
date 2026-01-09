import 'package:flutter/material.dart';
import 'package:isan/models/note.dart';
import 'package:isan/services/database_service.dart';
import 'package:isan/services/auth_service.dart';
import 'package:uuid/uuid.dart';

class EditorScreen extends StatefulWidget {
  final Note? note;

  const EditorScreen({super.key, this.note});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _dbService = DatabaseService();
  final _authService = AuthService();
  
  final FocusNode _titleFocus = FocusNode();
  final FocusNode _contentFocus = FocusNode();

  late Note _note; 
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    if (widget.note != null) {
      _note = widget.note!;
      _titleController.text = _note.title;
      _contentController.text = _note.content;
    } else {
      // Create mode: Check if a user is logged in
      final currentUser = _authService.currentUser;
      final userId = currentUser?.id ?? "local_user";

      _note = Note(id: -1)
        ..uuid = const Uuid().v4()
        ..userId = userId
        ..title = ""
        ..content = ""
        ..isSynced = false;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _titleFocus.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  Future<bool> _saveOrDelete() async {
    if (_isSaving) return false;
    _isSaving = true;

    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    // No changes at all
    if (_note.title == title && _note.content == content) {
      _isSaving = false;
      return false; 
    }
    
    // Empty note -> Delete
    if (title.isEmpty && content.isEmpty) {
      if (_note.id != -1) { 
        await _dbService.deleteNote(_note.id);
        _isSaving = false;
        return true; 
      }
      _isSaving = false;
      return false; // Was empty and never saved, do nothing
    }

    // Save changes
    _note
      ..title = title
      ..content = content
      ..updatedAt = DateTime.now().toUtc()
      ..isSynced = false;

    final savedId = await _dbService.saveNote(_note);
    
    // Update the local ID if we were in create mode
    if (_note.id == -1) {
       _note = Note(id: savedId)
        ..uuid = _note.uuid
        ..userId = _note.userId
        ..title = _note.title
        ..content = _note.content
        ..updatedAt = _note.updatedAt
        ..isSynced = _note.isSynced
        ..isLocked = _note.isLocked;
    }
    
    _isSaving = false;
    return true; 
  }

  void _deleteNote() async {
    if (_note.id != -1) { 
      await _dbService.deleteNote(_note.id);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return PopScope(
      // IMPORTANT CORRECTION: canPop set to false to intercept the gesture
      canPop: false, 
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // 1. Save changes
        await _saveOrDelete(); 

        // 2. Now close manually
        if (context.mounted) {
          Navigator.of(context).pop(result);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          actions: [
            // Save Button (Manual)
            IconButton(
              onPressed: () async {
                FocusScope.of(context).unfocus(); // Close keyboard
                bool saved = await _saveOrDelete();
                
                if (saved && context.mounted) {
                  setState(() {}); 
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text("Note saved"), 
                      duration: const Duration(seconds: 1),
                      backgroundColor: primaryColor,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.check),
            ),
            
            // Delete Button
            if (_note.id != -1)
              IconButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text("Delete Note?"),
                      content: const Text("This action cannot be undone."),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: TextButton.styleFrom(foregroundColor: textColor),
                          child: const Text("Cancel"),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _deleteNote();
                          },
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
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
                onSubmitted: (_) {
                  FocusScope.of(context).requestFocus(_contentFocus);
                },
                textInputAction: TextInputAction.next, 
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                decoration: const InputDecoration(
                  hintText: 'Title',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TextField(
                  controller: _contentController,
                  focusNode: _contentFocus,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.5,
                    fontSize: 18,
                  ),
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    hintText: 'Start typing...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
