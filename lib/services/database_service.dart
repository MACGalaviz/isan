import 'dart:async';

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

  bool _isFlushing = false;

  Future<void> initialize() async {
    db = AppDatabase();

    if (!SessionKeyService.instance.hasKey) {
      debugPrint('⚠️ No encryption key available - skipping cloud sync');
      debugPrint('⚠️ User must unlock to access notes');
      return; // Don't crash, just skip sync
    }

    // Push before pulling: the pull overwrites local rows, so an edit made
    // offline would be lost if the cloud copy came down first.
    await flushPendingSyncs();
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
      noteType: Value(note.type.name),
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
        await _markSynced(savedId);

        // This upload proved there is a connection, so drain whatever earlier
        // saves left behind. Not awaited: closing the editor waits on this
        // call, and a backlog would freeze it.
        unawaited(flushPendingSyncs());
      } else {
        debugPrint('⚠️ Skipping cloud sync - no authenticated user');
      }
    } catch (e) {
      debugPrint('⚠️ Sync failed (offline?): $e');
    }

    return savedId;
  }

  /// Narrow write: only the sync flag, so the ciphertext keeps its nonce and
  /// [Note.updatedAt] stays put.
  Future<void> _markSynced(int id) async {
    await (db.update(db.notes)..where((t) => t.id.equals(id)))
        .write(const NotesCompanion(isSynced: Value(true)));
  }

  /// Replays what the app couldn't send while offline: deletions first, then
  /// uploads.
  ///
  /// Costs nothing but two local queries when there is nothing pending, and
  /// stops at the first failure so a dead connection means one request, not
  /// one per note. Never throws — callers fire it and forget.
  Future<void> flushPendingSyncs() async {
    if (_isFlushing) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final tombstones = await db.select(db.pendingDeletes).get();
    final pending =
        await (db.select(db.notes)..where((t) => t.isSynced.equals(false)))
            .get();
    if (tombstones.isEmpty && pending.isEmpty) return;

    _isFlushing = true;
    debugPrint(
      '☁️ Flushing ${pending.length} pending note(s), '
      '${tombstones.length} pending delete(s)',
    );

    try {
      // Deletions go first: uploading a note the user already deleted would
      // recreate the cloud row this is meant to remove.
      for (final tombstone in tombstones) {
        await _supabaseService.deleteNote(tombstone.uuid);
        await (db.delete(db.pendingDeletes)
              ..where((t) => t.uuid.equals(tombstone.uuid)))
            .go();
      }

      for (final row in pending) {
        // Straight from the row: title and content are already ciphertext.
        // Going through _mapToModel would upload plaintext — or overwrite a
        // note that merely failed to decrypt with the placeholder text.
        await _supabaseService.syncNote(
          Note(
            id: row.id,
            uuid: row.uuid,
            userId: row.userId,
            title: row.title,
            content: row.content,
            createdAt: row.createdAt,
            updatedAt: row.updatedAt,
            isSynced: true,
            type: NoteType.fromName(row.noteType),
            isLocked: row.isLocked,
            passwordHash: row.passwordHash,
          ),
        );
        await _markSynced(row.id);
      }
    } catch (e) {
      debugPrint('⚠️ Flush stopped, will retry on the next trigger: $e');
    } finally {
      _isFlushing = false;
    }
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
        // Otherwise a landed lock change leaves the row pending, and the next
        // flush re-uploads the whole note for nothing.
        await _markSynced(id);
      }
    } catch (e) {
      debugPrint('⚠️ Lock sync failed (offline?): $e');
    }
  }

  /// Switches how the note is presented.
  ///
  /// Narrow write for the same reason as [setNoteLock]: the type is metadata,
  /// so changing it must not re-encrypt the body nor bump [Note.updatedAt].
  Future<void> setNoteType(int id, NoteType type) async {
    await (db.update(db.notes)..where((t) => t.id.equals(id))).write(
      NotesCompanion(
        noteType: Value(type.name),
        isSynced: const Value(false),
      ),
    );

    final row = await (db.select(db.notes)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return;

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await _supabaseService.syncNoteType(uuid: row.uuid, type: type);
        await _markSynced(id);
      }
    } catch (e) {
      debugPrint('⚠️ Type sync failed (offline?): $e');
    }
  }

  Future<void> deleteNote(int id) async {
    final noteDb =
        await (db.select(db.notes)..where((t) => t.id.equals(id)))
            .getSingleOrNull();

    await (db.delete(db.notes)..where((t) => t.id.equals(id))).go();

    if (noteDb == null) return;

    // Local mode has no cloud row to delete, and no tombstone to record.
    if (Supabase.instance.client.auth.currentUser == null) return;

    try {
      await _supabaseService.deleteNote(noteDb.uuid);
    } catch (e) {
      debugPrint('⚠️ Failed to delete from cloud, queued: $e');

      // The cloud row outlived the local one, so the next pull would bring the
      // note back. The tombstone both blocks that and retries the delete.
      await db.into(db.pendingDeletes).insertOnConflictUpdate(
            PendingDeletesCompanion.insert(
              uuid: noteDb.uuid,
              deletedAt: DateTime.now().toUtc(),
            ),
          );
    }
  }

  Future<void> cleanDb() async {
    await db.delete(db.notes).go();
    await db.delete(db.pendingDeletes).go();
  }

  /// Public cloud sync trigger.
  /// Called after login once the UMK is available in session.
  Future<void> syncFromCloud() async {
    if (!SessionKeyService.instance.hasKey) {
      debugPrint('⚠️ No encryption key available - skipping cloud sync');
      return;
    }
    await flushPendingSyncs();
    await _syncFromCloud();
  }

  Future<void> _syncFromCloud() async {
    final cloudNotesData = await _supabaseService.fetchNotes();
    if (cloudNotesData.isEmpty) return;

    // Notes deleted offline: the cloud still has them until the next flush.
    final deletedUuids =
        (await db.select(db.pendingDeletes).get()).map((t) => t.uuid).toSet();

    await db.transaction(() async {
      for (var map in cloudNotesData) {
        final uuid = map['id'];
        if (uuid == null || uuid is! String) continue;

        if (deletedUuids.contains(uuid)) continue;

        final createdAt = map['created_at'] != null
            ? DateTime.parse(map['created_at']).toLocal()
            : DateTime.now();

        final updatedAt = map['updated_at'] != null
            ? DateTime.parse(map['updated_at']).toLocal()
            : createdAt;

        final existing = await (db.select(db.notes)
              ..where((t) => t.uuid.equals(uuid)))
            .getSingleOrNull();

        // A row still waiting to upload is newer than the cloud copy by
        // definition — let the next flush push it instead of overwriting it.
        if (existing != null && !existing.isSynced) continue;

        final companion = NotesCompanion(
          id: existing != null ? Value(existing.id) : const Value.absent(),
          uuid: Value(uuid),
          userId: Value(map['user_id'] ?? 'local_user'),
          title: Value(map['title'] ?? ''),
          content: Value(map['content'] ?? ''), // Already encrypted from cloud
          createdAt: Value(createdAt),
          updatedAt: Value(updatedAt),
          isSynced: const Value(true),
          noteType: Value(NoteType.fromName(map['note_type']).name),
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
        type: NoteType.fromName(row.noteType),
        isLocked: row.isLocked,
        passwordHash: row.passwordHash,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Decryption error: $e');
      debugPrint('Stack: $stackTrace');

      // Fallback for notes that failed to decrypt. Lock state mirrors the row:
      // a failed decrypt says nothing about the per-note lock, and faking one
      // here would drop the real password hash on the next save.
      return Note(
        id: row.id,
        uuid: row.uuid,
        userId: row.userId,
        title: '⚠️ Unreadable note',
        content: '⚠️ This note could not be decrypted.',
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        isSynced: row.isSynced,
        type: NoteType.fromName(row.noteType),
        isLocked: row.isLocked,
        passwordHash: row.passwordHash,
      );
    }
  }
}