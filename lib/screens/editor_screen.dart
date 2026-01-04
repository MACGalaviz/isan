import 'package:flutter/material.dart';
import 'package:isan/models/note.dart';
import 'package:isan/services/database_service.dart';
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
  
  final FocusNode _titleFocus = FocusNode();
  final FocusNode _contentFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.note != null) {
      _titleController.text = widget.note!.title;
      _contentController.text = widget.note!.content;
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

  // Smart Save/Delete Logic
  // Returns TRUE if an operation (save/delete) was performed, FALSE if nothing changed.
  bool _saveOrDelete() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    // CASE 0: No changes detected (Existing note)
    // If the note exists AND the text matches exactly what we started with -> Do nothing.
    if (widget.note != null && 
        widget.note!.title == title && 
        widget.note!.content == content) {
      return false; 
    }
    
    // CASE 1: Empty Note
    if (title.isEmpty && content.isEmpty) {
      if (widget.note != null) {
        _dbService.deleteNote(widget.note!.id);
        return true; // Deleted
      }
      return false; // Nothing to save
    }

    // CASE 2: Save valid note
    final noteToSave = widget.note ?? Note()
      ..uuid = const Uuid().v4()
      ..userId = "local_user"
      ..isSynced = false;

    noteToSave
      ..title = title
      ..content = content
      ..updatedAt = DateTime.now().toUtc();

    _dbService.saveNote(noteToSave);
    return true; // Saved
  }

  // Manual Delete
  void _deleteNote() {
    if (widget.note != null) {
      _dbService.deleteNote(widget.note!.id);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        // Auto-save when using the back gesture
        _saveOrDelete();
      },
      child: Scaffold(
        appBar: AppBar(
          actions: [
            // Manual SAVE button
            IconButton(
              onPressed: () {
                // We only show the SnackBar if a change actually happened
                bool saved = _saveOrDelete();
                
                if (saved) {
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
            
            // Delete button
            if (widget.note != null)
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
              // TITLE INPUT
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
              
              // CONTENT INPUT
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
