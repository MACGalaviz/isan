import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:isan/models/note.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Uploads or Updates a note in the Cloud (Upsert).
  /// "Upsert" checks the Primary Key (UUID):
  /// - If it exists -> Update.
  /// - If it doesn't -> Insert.
  Future<void> syncNote(Note note) async {
    try {
      final noteData = {
        'id': note.uuid,          // Matches the UUID column in Postgres
        'user_id': note.userId,
        'title': note.title,
        'content': note.content,
        'created_at': note.createdAt.toIso8601String(),
        'updated_at': note.updatedAt.toIso8601String(), // Send UTC ISO string
        'note_type': note.type.name,
        'is_locked': note.isLocked,
        'password_hash': note.passwordHash,
      };

      await _client.from('notes').upsert(noteData);

      debugPrint("☁️ Cloud: Note synced successfully");

    } catch (e) {
      debugPrint("❌ Cloud Error (Sync): $e");
      // Callers decide: saveNote tolerates offline, migration must not mark
      // a note as synced when the upload never landed.
      rethrow;
    }
  }

  /// Updates only the lock columns of an existing note.
  /// Used by the per-note lock so toggling it never touches the ciphertext.
  Future<void> syncNoteLock({
    required String uuid,
    required bool isLocked,
    required String? passwordHash,
  }) async {
    try {
      await _client.from('notes').update({
        'is_locked': isLocked,
        'password_hash': passwordHash,
      }).eq('id', uuid);

      debugPrint("☁️ Cloud: Note lock synced ($isLocked)");
    } catch (e) {
      debugPrint("❌ Cloud Error (Lock sync): $e");
      // Same contract as syncNote: the caller needs to know it never landed,
      // otherwise it marks the row as synced on a failed upload.
      rethrow;
    }
  }

  /// Updates only the presentation type of an existing note.
  Future<void> syncNoteType({
    required String uuid,
    required NoteType type,
  }) async {
    try {
      await _client
          .from('notes')
          .update({'note_type': type.name}).eq('id', uuid);

      debugPrint("☁️ Cloud: Note type synced (${type.name})");
    } catch (e) {
      debugPrint("❌ Cloud Error (Type sync): $e");
      rethrow;
    }
  }

  /// Deletes a note from the Cloud based on its UUID.
  Future<void> deleteNote(String uuid) async {
    try {
      await _client.from('notes').delete().eq('id', uuid);
      debugPrint("🗑️ Cloud: Note deleted successfully");
    } catch (e) {
      debugPrint("❌ Cloud Error (Delete): $e");
      // The caller records a tombstone when the delete never landed.
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchNotes() async {
    try {
      final data = await _client.from('notes').select();
      
      return List<Map<String, dynamic>>.from(data);
      
    } catch (e) {
      debugPrint("❌ Cloud Error (Fetch): $e");
      return [];
    }
  }

}
