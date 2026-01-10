import 'package:flutter/material.dart';
import 'package:isan/models/note.dart';
import 'package:isan/services/database_service.dart';
import 'package:isan/services/auth_service.dart';
import 'package:uuid/uuid.dart'; // Asegúrate de tener uuid en pubspec.yaml
import 'package:supabase_flutter/supabase_flutter.dart'; // Para obtener el usuario actual

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
      // EDIT MODE
      _note = widget.note!;
      _titleController.text = _note.title;
      _contentController.text = _note.content;
    } else {
      // CREATE MODE
      // Obtenemos el ID del usuario de Supabase (o 'local_user' si no hay sesión)
      final userId = Supabase.instance.client.auth.currentUser?.id ?? "local_user";

      // Inicializamos con TODOS los campos obligatorios
      _note = Note(
        id: -1, // -1 indica que aún no existe en SQLite
        uuid: const Uuid().v4(), // Generamos UUID único ahora mismo
        userId: userId,
        title: "",
        content: "",
        updatedAt: DateTime.now(), // Drift maneja DateTime nativo
        isSynced: false,
        isLocked: false,
      );
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

    // 1. Check if there are no changes
    if (_note.title == title && _note.content == content) {
      _isSaving = false;
      return false; 
    }
    
    // 2. Empty note -> Delete
    if (title.isEmpty && content.isEmpty) {
      if (_note.id != -1) { 
        await _dbService.deleteNote(_note.id);
        _isSaving = false;
        return true; 
      }
      _isSaving = false;
      return false; // Was empty and never saved, do nothing
    }

    // 3. Save changes
    // IMPORTANTE: Note es inmutable, usamos copyWith para crear la versión actualizada
    final updatedNote = _note.copyWith(
      title: title,
      content: content,
      updatedAt: DateTime.now().toUtc(), // Guardamos en UTC para evitar líos de zona horaria
      isSynced: false, // Marcamos como no sincronizado para que el Sync Engine lo suba
    );

    // Guardamos en DB (Drift devolverá el ID numérico insertado/actualizado)
    final savedId = await _dbService.saveNote(updatedNote);
    
    // 4. Update local state
    // Actualizamos nuestra variable local con el ID definitivo (útil si era una nota nueva)
    _note = updatedNote.copyWith(id: savedId);
    
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
            // Save Button (Manual)
            IconButton(
              onPressed: () async {
                FocusScope.of(context).unfocus();
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
            
            // Delete Button (Only if it's an existing note)
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