import 'package:drift/drift.dart';
import 'package:isan/db/database.dart'; // Importamos la DB que creaste
import 'package:isan/models/note.dart'; // Importamos tu modelo UI
import 'package:isan/services/supabase_service.dart';

class DatabaseService {
  // Singleton pattern
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  // Referencia a la base de datos Drift
  late AppDatabase db;
  
  final SupabaseService _supabaseService = SupabaseService();

  /// Initialize the database and launch the synchronization
  Future<void> initialize() async {
    // 1. Instanciamos Drift (se encarga solo de abrir archivos o web/wasm)
    db = AppDatabase();

    // 2. Synchronize
    await _syncFromCloud();
  }

  /// Save a note. Returns the ID of the saved note.
  Future<int> saveNote(Note note) async {
    int savedId;

    // Convertimos tu modelo UI (Note) a un modelo de inserción Drift (NotesCompanion)
    final companion = NotesCompanion(
      // Si el ID es -1, no lo enviamos (Value.absent) para que SQLite genere uno nuevo.
      // Si ya existe, lo enviamos para actualizar esa fila.
      id: note.id == -1 ? const Value.absent() : Value(note.id),
      uuid: Value(note.uuid),
      userId: Value(note.userId),
      title: Value(note.title),
      content: Value(note.content),
      createdAt: Value(note.createdAt),
      updatedAt: Value(note.updatedAt),
      isSynced: Value(note.isSynced),
      isLocked: Value(note.isLocked),
    );

    // Step 1: Save to Drift (Local)
    if (note.id == -1) {
      // INSERT: Crea una nueva
      savedId = await db.into(db.notes).insert(companion);
    } else {
      // UPDATE: Reemplaza si existe (conflicto en ID)
      await db.into(db.notes).insertOnConflictUpdate(companion);
      savedId = note.id;
    }

    // Step 2: Synchronize with Supabase (Cloud)
    try {
      // Reconstruct the object with the definitive ID
      final noteToSync = note.copyWith(id: savedId);
      await _supabaseService.syncNote(noteToSync);
      print("✅ Note uploaded to Supabase correctly.");
    } catch (e) {
      print("❌ Error uploading to Supabase: $e");
    }

    return savedId;
  }

  /// Stream of notes with optional search
  /// Drift soporta streams en WEB nativamente, ¡así que esto funcionará solo!
  Stream<List<Note>> listenToNotes({String query = ''}) {
    SimpleSelectStatement<$NotesTable, NoteDb> selectQuery;

    if (query.isEmpty) {
      // Select all, ordered by date
      selectQuery = db.select(db.notes)
        ..orderBy([(t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)]);
    } else {
      // Select with filter
      selectQuery = db.select(db.notes)
        ..where((t) => t.title.contains(query) | t.content.contains(query))
        ..orderBy([(t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)]);
    }

    // .watch() convierte la query en Stream.
    // .map() convierte la lista de 'NoteDb' (Drift) a tu lista de 'Note' (UI).
    return selectQuery.watch().map((rows) {
      return rows.map((row) => _mapToModel(row)).toList();
    });
  }

  /// Delete note
  Future<void> deleteNote(int id) async {
    // Get UUID before deleting (needed for cloud sync)
    final noteDb = await (db.select(db.notes)..where((t) => t.id.equals(id))).getSingleOrNull();
    final String? uuidToDelete = noteDb?.uuid;

    // 1. Local deletion
    await (db.delete(db.notes)..where((t) => t.id.equals(id))).go();

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
    await db.delete(db.notes).go();
  }

  /// Download notes from the cloud and save them locally
  Future<void> _syncFromCloud() async {
    final cloudNotesData = await _supabaseService.fetchNotes();
    if (cloudNotesData.isEmpty) return;

    // Drift Transaction: Ejecuta todo en bloque para mayor velocidad
    await db.transaction(() async {
      for (var map in cloudNotesData) {
        final rawId = map['id'];
        if (rawId == null || rawId is! String) continue;

        final uuid = rawId;

        final createdAtRaw = map['created_at'];
        final updatedAtRaw = map['updated_at'];

        final createdAt = createdAtRaw != null
            ? DateTime.parse(createdAtRaw).toLocal()
            : DateTime.now();

        final updatedAt = updatedAtRaw != null
            ? DateTime.parse(updatedAtRaw).toLocal()
            : createdAt;

        final existingNote = await (db.select(db.notes)
              ..where((t) => t.uuid.equals(uuid)))
            .getSingleOrNull();

        final companion = NotesCompanion(
          id: existingNote != null ? Value(existingNote.id) : const Value.absent(),
          uuid: Value(uuid),
          userId: Value(map['user_id'] ?? 'local_user'),
          title: Value(map['title'] ?? ''),
          content: Value(map['content'] ?? ''),
          createdAt: Value(createdAt),
          updatedAt: Value(updatedAt),
          isSynced: const Value(true),
          isLocked: Value(map['is_locked'] ?? false),
        );

        await db.into(db.notes).insertOnConflictUpdate(companion);
      }
    });
    
    print("🔄 Sync: Downloaded ${cloudNotesData.length} notes from cloud.");
  }

  // --- Helper: Mapper ---
  // Convierte el objeto interno de Drift (NoteDb) a tu objeto de UI (Note)
  Note _mapToModel(NoteDb row) {
    return Note(
      id: row.id,
      uuid: row.uuid,
      userId: row.userId,
      title: row.title,
      content: row.content,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      isSynced: row.isSynced,
      isLocked: row.isLocked,
    );
  }
}
