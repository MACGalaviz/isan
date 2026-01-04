import 'package:flutter/material.dart';
import 'package:isar/isar.dart'; 
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

  late Note _note; 

  @override
  void initState() {
    super.initState();
    
    if (widget.note != null) {
      _note = widget.note!;
      _titleController.text = _note.title;
      _contentController.text = _note.content;
    } else {
      _note = Note()
        ..uuid = const Uuid().v4()
        ..userId = "local_user"
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

  // FIX 1: Convertimos esto a Future para poder esperar a la base de datos
  Future<bool> _saveOrDelete() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (_note.title == title && _note.content == content) {
      return false; 
    }
    
    if (title.isEmpty && content.isEmpty) {
      if (_note.id != Isar.autoIncrement) {
        await _dbService.deleteNote(_note.id); // Await añadido
        return true; 
      }
      return false; 
    }

    _note
      ..title = title
      ..content = content
      ..updatedAt = DateTime.now().toUtc()
      ..isSynced = false;

    // FIX 2: Esperamos a que Isar asigne el ID antes de continuar
    await _dbService.saveNote(_note);
    
    return true; 
  }

  void _deleteNote() async {
    if (_note.id != Isar.autoIncrement) {
      await _dbService.deleteNote(_note.id);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _saveOrDelete(); // Aquí no necesitamos esperar
      },
      child: Scaffold(
        appBar: AppBar(
          actions: [
            // Save Button
            IconButton(
              onPressed: () async { // FIX 3: Hacemos el botón async
                // Esperamos a que termine de guardar en BD
                bool saved = await _saveOrDelete();
                
                if (saved && context.mounted) {
                  // Ahora sí, el ID ya existe, redibujamos la pantalla
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
            
            // Delete Button (Solo si tiene ID real)
            if (_note.id != Isar.autoIncrement)
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
