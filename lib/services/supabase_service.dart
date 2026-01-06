import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:isan/models/note.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

class SupabaseService {
  // Access the global Supabase client
  final SupabaseClient _client = Supabase.instance.client;

  /// Uploads or Updates a note in the Cloud (Upsert).
  /// "Upsert" checks the Primary Key (UUID):
  /// - If it exists -> Update.
  /// - If it doesn't -> Insert.
  Future<void> syncNote(Note note) async {
    try {
      // Convert Note object to SQL-compatible JSON Map
      final noteData = {
        'id': note.uuid,          // Matches the UUID column in Postgres
        'user_id': note.userId,
        'title': note.title,
        'content': note.content,
        'updated_at': note.updatedAt.toIso8601String(), // Send UTC ISO string
      };

      // Perform the Upsert operation
      await _client.from('notes').upsert(noteData);
      
      debugPrint("☁️ Cloud: Note synced successfully (${note.title})");
      
    } catch (e) {
      debugPrint("❌ Cloud Error (Sync): $e");
      // Future TODO: Handle offline queue here
    }
  }

  /// Deletes a note from the Cloud based on its UUID.
  Future<void> deleteNote(String uuid) async {
    try {
      await _client.from('notes').delete().eq('id', uuid);
      debugPrint("🗑️ Cloud: Note deleted successfully");
    } catch (e) {
      debugPrint("❌ Cloud Error (Delete): $e");
    }
  }

  Future<List<Map<String, dynamic>>> fetchNotes() async {
    try {
      // 'select' without arguments gets all columns for all rows
      final data = await _client.from('notes').select();
      
      // Supabase returns a List<dynamic>, we cast it to List<Map>
      return List<Map<String, dynamic>>.from(data);
      
    } catch (e) {
      debugPrint("❌ Cloud Error (Fetch): $e");
      return [];
    }
  }

}
