import 'package:isar/isar.dart';
import 'package:isan/models/note.dart';
import 'package:path_provider/path_provider.dart';
import 'package:isan/services/supabase_service.dart';

class DatabaseService {
  late Future<Isar> db;
  // Instanciamos el servicio de la nube
  final SupabaseService _supabaseService = SupabaseService();

  DatabaseService() {
    db = openDB();
  }

  // --- FIX 1: Agregamos el método initialize que main.dart busca ---
  Future<void> initialize() async {
    await db;
    await _syncFromCloud();
  }

  Future<Isar> openDB() async {
    if (Isar.instanceNames.isEmpty) {
      final dir = await getApplicationDocumentsDirectory();
      return await Isar.open(
        [NoteSchema],
        directory: dir.path,
        inspector: true,
      );
    }
    return Future.value(Isar.getInstance());
  }

  Future<void> saveNote(Note note) async {
    final isar = await db;
    
    // 1. Guardado Local
    await isar.writeTxn(() async {
      await isar.notes.put(note);
    });

    // 2. Sincronización Nube (Fuego y olvido)
    _supabaseService.syncNote(note);
  }

  // --- FIX 2: Simplificamos la query para evitar error de tipos ---
  Stream<List<Note>> listenToNotes({String query = ''}) async* {
    final isar = await db;
    
    // Caso A: Sin búsqueda (Retorna todo ordenado)
    if (query.isEmpty) {
      yield* isar.notes.where()
          .sortByUpdatedAtDesc()
          .watch(fireImmediately: true);
      return;
    }

    // Caso B: Con búsqueda (Aplica filtros directamente)
    yield* isar.notes.where()
        .filter()
        .titleContains(query, caseSensitive: false)
        .or()
        .contentContains(query, caseSensitive: false)
        .sortByUpdatedAtDesc()
        .watch(fireImmediately: true);
  }

  Future<void> deleteNote(Id id) async {
    final isar = await db;
    
    // Obtenemos el UUID antes de borrar para decirle a la nube qué eliminar
    final note = await isar.notes.get(id);
    final String? uuidToDelete = note?.uuid;

    // 1. Borrado Local
    await isar.writeTxn(() async {
      await isar.notes.delete(id);
    });

    // 2. Borrado Nube
    if (uuidToDelete != null) {
      _supabaseService.deleteNote(uuidToDelete);
    }
  }
  
  Future<void> cleanDb() async {
    final isar = await db;
    await isar.writeTxn(() => isar.clear());
  }

  /// Private method: Downloads notes from Cloud and saves them to Local DB
  Future<void> _syncFromCloud() async {
    final isar = await db;
    
    // 1. Get raw data from Supabase
    final cloudNotesData = await _supabaseService.fetchNotes();

    if (cloudNotesData.isEmpty) return;

    await isar.writeTxn(() async {
      for (var map in cloudNotesData) {
        // 2. Convert JSON back to Note object
        // Note: We need to ensure we don't overwrite newer local changes in a real complex app,
        // but for Phase 4.0, we will trust the cloud data.
        
        final note = Note()
          ..uuid = map['id'] 
          // FIX: Assign userId using the column name from Supabase ('user_id')
          ..userId = map['user_id'] ?? 'local_user' 
          ..title = map['title'] ?? ''
          ..content = map['content'] ?? ''
          // FIX: Assign isLocked (defaults to false if null)
          ..isLocked = map['is_locked'] ?? false 
          ..updatedAt = DateTime.parse(map['updated_at']).toLocal();

        // 3. Put matches by ID (Index). 
        // Problem: Isar uses int ID, Supabase uses String UUID.
        // We need to find if this UUID exists locally to get its int ID, otherwise create new.
        final existingNote = await isar.notes.filter().uuidMatches(note.uuid).findFirst();
        
        if (existingNote != null) {
          note.id = existingNote.id; // Keep the local ID so it updates, not inserts new
        }

        await isar.notes.put(note);
      }
    });
    print("🔄 Sync: Downloaded ${cloudNotesData.length} notes from cloud.");
  }

}
