import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:isan/models/note.dart';

class DatabaseService {
  // Singleton Pattern
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  late Isar _isar;

  // Initialize Database
  Future<void> initialize() async {
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [NoteSchema], 
      directory: dir.path,
    );
  }

  // --- CRUD Operations ---

  // 1. CREATE / UPDATE
  Future<void> saveNote(Note note) async {
    await _isar.writeTxn(() async {
      await _isar.notes.put(note);
    });
  }

  // 2. READ (Stream with Search Logic)
  // Updated to accept a search query
  Stream<List<Note>> listenToNotes({String query = ''}) {
    // If query is empty, return all notes sorted by date
    if (query.isEmpty) {
      return _isar.notes
          .where()
          .sortByUpdatedAtDesc()
          .watch(fireImmediately: true);
    } 
    
    // If query exists, filter by Title OR Content
    // Case insensitive ensures "Buy" finds "buy"
    return _isar.notes
        .filter()
        .titleContains(query, caseSensitive: false)
        .or()
        .contentContains(query, caseSensitive: false)
        .sortByUpdatedAtDesc()
        .watch(fireImmediately: true);
  }

  // 3. DELETE
  Future<void> deleteNote(Id id) async {
    await _isar.writeTxn(() async {
      await _isar.notes.delete(id);
    });
  }
  
  // WIPE DB
  Future<void> cleanDb() async {
    await _isar.writeTxn(() async {
      await _isar.clear();
    });
  }
}
