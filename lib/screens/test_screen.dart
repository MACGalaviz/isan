import 'package:flutter/material.dart';
import 'package:isan/models/note.dart';
import 'package:isan/services/database_service.dart';
import 'package:uuid/uuid.dart';

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  // Controller to handle text input
  final TextEditingController _textController = TextEditingController();
  final DatabaseService _dbService = DatabaseService();
  
  // Logic to create and save a new note
  void _addNote() {
    if (_textController.text.isEmpty) return;

    final newNote = Note()
      ..uuid = const Uuid().v4() // Generates a unique string ID
      ..userId = "local_user"
      ..title = "Note ${DateTime.now().second}" // Temporary title
      ..content = _textController.text
      ..updatedAt = DateTime.now()
      ..isSynced = false;

    // Save to Isar Database
    _dbService.saveNote(newNote);
    
    // Clear input
    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Isan DB Test 🛠️")),
      body: Column(
        children: [
          // --- INPUT AREA ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: "Write something to save...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _addNote,
                  child: const Text("SAVE"),
                ),
              ],
            ),
          ),

          // --- LIST AREA (Real-time updates) ---
          Expanded(
            child: StreamBuilder<List<Note>>(
              stream: _dbService.listenToNotes(), // Listen to the DB changes
              builder: (context, snapshot) {
                // Loading state
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final notes = snapshot.data ?? [];

                // Empty state
                if (notes.isEmpty) {
                  return const Center(child: Text("Database is empty. Add a note!"));
                }

                // List of notes
                return ListView.builder(
                  itemCount: notes.length,
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    return ListTile(
                      leading: const Icon(Icons.note),
                      title: Text(note.content),
                      subtitle: Text("Updated: ${note.updatedAt.toString()}"),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          // Delete from DB
                          _dbService.deleteNote(note.id);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
