import 'package:drift/drift.dart';
import 'package:isan/db/database.dart';
import 'package:isan/models/note.dart';
import 'package:isan/services/supabase_service.dart';
import 'package:isan/services/security/encryption_service.dart';
import 'package:isan/services/security/session_key_service.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  late AppDatabase db;
  final SupabaseService _supabaseService = SupabaseService();

  Future<void> initialize() async {
    db = AppDatabase();
    await _syncFromCloud();
  }

  Future<int> saveNote(Note note) async {
    int savedId;

    final encrypted = await EncryptionService.instance.encrypt(
      plainText: note.content,
      key: SessionKeyService.instance.key,
    );
    print('ENCRYPTED CONTENT TO SAVE: $encrypted');

    final companion = NotesCompanion(
      id: note.id == -1 ? const Value.absent() : Value(note.id),
      uuid: Value(note.uuid),
      userId: Value(note.userId),
      title: Value(note.title),
      content: Value(encrypted),
      createdAt: Value(note.createdAt),
      updatedAt: Value(note.updatedAt),
      isSynced: Value(note.isSynced),
      isLocked: Value(note.isLocked),
      passwordHash: Value(note.passwordHash),
    );

    if (note.id == -1) {
      savedId = await db.into(db.notes).insert(companion);
    } else {
      await db.into(db.notes).insertOnConflictUpdate(companion);
      savedId = note.id;
    }

    try {
      final noteToSync = note.copyWith(
        id: savedId,
        content: encrypted,
      );
      await _supabaseService.syncNote(noteToSync);
    } catch (_) {}

    return savedId;
  }

  Stream<List<Note>> listenToNotes({String query = ''}) {
    final selectQuery = query.isEmpty
        ? (db.select(db.notes)
          ..orderBy([
            (t) => OrderingTerm(
                expression: t.updatedAt, mode: OrderingMode.desc)
          ]))
        : (db.select(db.notes)
          ..where(
              (t) => t.title.contains(query) | t.content.contains(query))
          ..orderBy([
            (t) => OrderingTerm(
                expression: t.updatedAt, mode: OrderingMode.desc)
          ]));

    return selectQuery.watch().asyncMap(
          (rows) => Future.wait(rows.map(_mapToModel)),
        );
  }

  Future<void> deleteNote(int id) async {
    final noteDb =
        await (db.select(db.notes)..where((t) => t.id.equals(id)))
            .getSingleOrNull();

    await (db.delete(db.notes)..where((t) => t.id.equals(id))).go();

    if (noteDb?.uuid != null) {
      try {
        await _supabaseService.deleteNote(noteDb!.uuid);
      } catch (_) {}
    }
  }

  Future<void> cleanDb() async {
    await db.delete(db.notes).go();
  }

  Future<void> _syncFromCloud() async {
    final cloudNotesData = await _supabaseService.fetchNotes();
    if (cloudNotesData.isEmpty) return;

    await db.transaction(() async {
      for (var map in cloudNotesData) {
        final uuid = map['id'];
        if (uuid == null || uuid is! String) continue;

        final createdAt = map['created_at'] != null
            ? DateTime.parse(map['created_at']).toLocal()
            : DateTime.now();

        final updatedAt = map['updated_at'] != null
            ? DateTime.parse(map['updated_at']).toLocal()
            : createdAt;

        final existing = await (db.select(db.notes)
              ..where((t) => t.uuid.equals(uuid)))
            .getSingleOrNull();

        final companion = NotesCompanion(
          id: existing != null ? Value(existing.id) : const Value.absent(),
          uuid: Value(uuid),
          userId: Value(map['user_id'] ?? 'local_user'),
          title: Value(map['title'] ?? ''),
          content: Value(map['content'] ?? ''),
          createdAt: Value(createdAt),
          updatedAt: Value(updatedAt),
          isSynced: const Value(true),
          isLocked: Value(map['is_locked'] ?? false),
          passwordHash: Value(map['password_hash']),
        );

        await db.into(db.notes).insertOnConflictUpdate(companion);
      }
    });
  }

  Future<Note> _mapToModel(NoteDb row) async {
    try {
      final content = await EncryptionService.instance.decrypt(
        cipherText: row.content,
        key: SessionKeyService.instance.key,
      );
      print('decrypted content: $content');
      return Note(
        id: row.id,
        uuid: row.uuid,
        userId: row.userId,
        title: row.title,
        content: content,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        isSynced: row.isSynced,
        isLocked: row.isLocked,
      );
    } catch (e, stackTrace) {
      print('❌ Error real: $e');
      print('Stack: $stackTrace');
      print('❌❌❌: $row.title');
      print('❌❌❌: $row.content');
      // fallback TEMPORAL
      return Note(
        id: row.id,
        uuid: row.uuid,
        userId: row.userId,
        title: row.title,
        content: '🔒 Locked / corrupted note',
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        isSynced: row.isSynced,
        isLocked: true,
      );
    }
  }

}
