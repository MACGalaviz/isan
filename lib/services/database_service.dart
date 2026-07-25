import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

    if (!SessionKeyService.instance.hasKey) {
      debugPrint('⚠️ No encryption key available - skipping cloud sync');
      debugPrint('⚠️ User must unlock to access notes');
      return; // Don't crash, just skip sync
    }

    await _syncFromCloud();
  }

  Future<int> saveNote(Note note) async {
    int savedId;

    final key = SessionKeyService.instance.key;
    final encryptedTitle = await EncryptionService.instance.encrypt(
      plainText: note.title,
      key: key,
    );
    final encrypted = await EncryptionService.instance.encrypt(
      plainText: note.content,
      key: key,
    );

    final companion = NotesCompanion(
      id: note.id == -1 ? const Value.absent() : Value(note.id),
      uuid: Value(note.uuid),
      userId: Value(note.userId),
      title: Value(encryptedTitle),
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
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final noteToSync = note.copyWith(
          id: savedId,
          title: encryptedTitle,
          content: encrypted,
        );
        await _supabaseService.syncNote(noteToSync);
      } else {
        debugPrint('⚠️ Skipping cloud sync - no authenticated user');
      }
    } catch (e) {
      debugPrint('⚠️ Sync failed (offline?): $e');
    }

    return savedId;
  }

  Stream<List<Note>> listenToNotes({String query = ''}) {
    // Search runs in memory over decrypted notes:
    // title/content are stored encrypted, so SQL LIKE can't match plaintext.
    final selectQuery = db.select(db.notes)
      ..orderBy([
        (t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)
      ]);

    return selectQuery.watch().asyncMap((rows) async {
      final notes = await Future.wait(rows.map(_mapToModel));
      if (query.isEmpty) return notes;

      final q = query.toLowerCase();
      // Locked notes match by title only: matching their content would let
      // the search box confirm words hidden behind the lock.
      return notes
          .where((n) =>
              n.title.toLowerCase().contains(q) ||
              (!n.isProtected && n.content.toLowerCase().contains(q)))
          .toList();
    });
  }

  /// Sets or clears the per-note password lock.
  ///
  /// Narrow write path on purpose: the lock is UI-only state, so it must not
  /// re-encrypt title/content (new nonce) nor bump [Note.updatedAt].
  /// Pass a null [passwordHash] to remove the lock.
  Future<void> setNoteLock(int id, String? passwordHash) async {
    await (db.update(db.notes)..where((t) => t.id.equals(id))).write(
      NotesCompanion(
        isLocked: Value(passwordHash != null),
        passwordHash: Value(passwordHash),
        isSynced: const Value(false),
      ),
    );

    final row = await (db.select(db.notes)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return;

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await _supabaseService.syncNoteLock(
          uuid: row.uuid,
          isLocked: row.isLocked,
          passwordHash: row.passwordHash,
        );
      }
    } catch (e) {
      debugPrint('⚠️ Lock sync failed (offline?): $e');
    }
  }

  Future<void> deleteNote(int id) async {
    final noteDb =
        await (db.select(db.notes)..where((t) => t.id.equals(id)))
            .getSingleOrNull();

    await (db.delete(db.notes)..where((t) => t.id.equals(id))).go();

    if (noteDb?.uuid != null) {
      try {
        await _supabaseService.deleteNote(noteDb!.uuid);
      } catch (e) {
        debugPrint('⚠️ Failed to delete from cloud: $e');
      }
    }
  }

  Future<void> cleanDb() async {
    await db.delete(db.notes).go();
  }

  /// Public cloud sync trigger.
  /// Called after login once the UMK is available in session.
  Future<void> syncFromCloud() async {
    if (!SessionKeyService.instance.hasKey) {
      debugPrint('⚠️ No encryption key available - skipping cloud sync');
      return;
    }
    await _syncFromCloud();
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
          content: Value(map['content'] ?? ''), // Already encrypted from cloud
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
      final key = SessionKeyService.instance.key;
      final title = await EncryptionService.instance.decrypt(
        cipherText: row.title,
        key: key,
      );
      final content = await EncryptionService.instance.decrypt(
        cipherText: row.content,
        key: key,
      );

      return Note(
        id: row.id,
        uuid: row.uuid,
        userId: row.userId,
        title: title,
        content: content,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        isSynced: row.isSynced,
        isLocked: row.isLocked,
        passwordHash: row.passwordHash,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Decryption error: $e');
      debugPrint('Stack: $stackTrace');

      // Fallback for corrupted notes
      return Note(
        id: row.id,
        uuid: row.uuid,
        userId: row.userId,
        title: '🔒 Locked / corrupted',
        content: '🔒 Locked / corrupted note',
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        isSynced: row.isSynced,
        isLocked: true,
      );
    }
  }
}