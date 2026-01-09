import 'package:isar_plus/isar_plus.dart';
import 'package:isan/models/note.dart';
import 'package:path_provider/path_provider.dart';
import 'package:isan/services/supabase_service.dart';

class DatabaseService {
  // Singleton pattern
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  late Isar isar;
  
  final SupabaseService _supabaseService = SupabaseService();

  ///Initialize the database and launch the synchronization
  Future<void> initialize() async {
    final dir = await getApplicationDocumentsDirectory();
    
    // 1. Open Isar (Isar Plus syntax)
    isar = Isar.open(
      schemas: [NoteSchema],
      directory: dir.path,
    );

    // 2. Synchronize
    await _syncFromCloud();
  }

  /// Save a note. Returns the ID of the saved note.
  Future<int> saveNote(Note note) async {
    // Step 1: Save to Isar (Local)
    // Remove 'async' internally and 'awaits' because writeAsync runs in another synchronous thread
    final int savedId = await isar.writeAsync((isar) { 
      
      // If the ID is -1, it means it's a NEW note in memory
      if (note.id == -1) {
        final newId = isar.notes.autoIncrement();
        
        // Create a copy with the new ID
        final newNote = Note(id: newId)
          ..uuid = note.uuid
          ..userId = note.userId
          ..title = note.title
          ..content = note.content
          ..updatedAt = note.updatedAt
          ..isSynced = note.isSynced
          ..isLocked = note.isLocked;

        isar.notes.put(newNote); 
        return newId; // Return the int directly
      } else {
        // Normal update
        isar.notes.put(note);
        return note.id;
      }
    });

    // Step 2: Synchronize with Supabase (Cloud)
    // This is done OUTSIDE the writeAsync to avoid blocking the DB and to allow using await
    try {
      // Reconstruct the object to send it with the correct ID
      final noteToSync = Note(id: savedId)
          ..uuid = note.uuid
          ..userId = note.userId
          ..title = note.title
          ..content = note.content
          ..updatedAt = note.updatedAt
          ..isSynced = note.isSynced
          ..isLocked = note.isLocked;

      await _supabaseService.syncNote(noteToSync);
      print("✅ Note uploaded to Supabase correctly.");
    } catch (e) {
      print("❌ Error uploading to Supabase: $e");
    }

    return savedId;
  }

  /// Stream of notes with optional search
  Stream<List<Note>> listenToNotes({String query = ''}) async* {
    if (query.isEmpty) {
      yield* isar.notes.where()
          .sortByUpdatedAtDesc()
          .watch(fireImmediately: true);
    } else {
      yield* isar.notes.where()
          .titleContains(query, caseSensitive: false)
          .or()
          .contentContains(query, caseSensitive: false)
          .sortByUpdatedAtDesc()
          .watch(fireImmediately: true);
    }
  }

  /// Delete note
  Future<void> deleteNote(int id) async {
    // Get the UUID before deleting (Asynchronous read safe outside txn)
    final note = await isar.notes.getAsync(id); 
    final String? uuidToDelete = note?.uuid;

    // 1. Local deletion
    // CORRECTION: Remove 'async' here inside. It's mandatory in Isar Plus.
    await isar.writeAsync((isar) {
      isar.notes.delete(id); // Without await
    });

    // 2. Cloud deletion
    if (uuidToDelete != null) {
      try {
        await _supabaseService.deleteNote(uuidToDelete);
        print("🗑️ Note deleted from Supabase.");
      } catch (e) {
         print("❌ Error deleting from Supabase: $e");
      }
    }
  }
  
  /// Clean DB
  Future<void> cleanDb() async {
    // CORRECTION: Remove 'async' here inside.
    await isar.writeAsync((isar) {
      isar.clear(); // Without await
    });
  }

  /// Download notes from the cloud and save them locally
  Future<void> _syncFromCloud() async {
    final cloudNotesData = await _supabaseService.fetchNotes();

    if (cloudNotesData.isEmpty) return;

    // Correction: Remove 'async' here inside.
    await isar.writeAsync((isar) { 
      for (var map in cloudNotesData) {
        final String uuid = map['id'];

        // Correction: Use findFirst (synchronous)
        final existingNote = isar.notes
            .where()
            .uuidEqualTo(uuid)
            .findFirst(); 
        
        final int dbId = existingNote?.id ?? isar.notes.autoIncrement();

        final note = Note(id: dbId)
          ..uuid = uuid
          ..userId = map['user_id'] ?? 'local_user'
          ..title = map['title'] ?? ''
          ..content = map['content'] ?? ''
          ..isLocked = map['is_locked'] ?? false 
          ..updatedAt = DateTime.parse(map['updated_at']).toLocal()
          ..isSynced = true;

        isar.notes.put(note); 
      }
    });
    print("🔄 Sync: Downloaded ${cloudNotesData.length} notes from cloud.");
  }
}
