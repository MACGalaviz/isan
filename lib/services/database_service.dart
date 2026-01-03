import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:isan/models/note.dart';

class DatabaseService {
  // Singleton Pattern: Ensures we only have ONE connection to the DB in the entire app.
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  late Isar _isar;

  /// Initialize the Local Database
  /// This must be called in main.dart before running the app.
  Future<void> initialize() async {
    final dir = await getApplicationDocumentsDirectory();
    
    // Open the Isar database with the schemas defined in our models
    _isar = await Isar.open(
      [NoteSchema], // NoteSchema is generated automatically in note.g.dart
      directory: dir.path,
    );
  }

  // ---------------------------------------------------------------------------
  // CRUD OPERATIONS (Create, Read, Update, Delete)
  // ---------------------------------------------------------------------------

  /// SAVE (Create or Update)
  /// Isar handles ID collisions automatically. If the ID exists, it updates.
  Future<void> saveNote(Note note) async {
    // All write operations must be inside a transaction
    await _isar.writeTxn(() async {
      await _isar.notes.put(note);
    });
  }

  /// READ (Stream)
  /// Returns a live stream of notes. 
  /// The UI will rebuild automatically whenever the database changes.
  Stream<List<Note>> listenToNotes() {
    return _isar.notes
        .where()
        .sortByUpdatedAtDesc() // Sort by newest first
        .watch(fireImmediately: true);
  }

  /// DELETE
  /// Removes a note permanently from local storage.
  Future<void> deleteNote(Id id) async {
    await _isar.writeTxn(() async {
      await _isar.notes.delete(id);
    });
  }

  /// CLEAR ALL (Debug helper)
  /// Wipes the entire database. Use carefully.
  Future<void> cleanDb() async {
    await _isar.writeTxn(() async {
      await _isar.clear();
    });
  }
}
