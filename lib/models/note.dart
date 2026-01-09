import 'package:isar_plus/isar_plus.dart';

part 'note.g.dart';

@collection
class Note {
  Note({ required this.id });

  final int id;

  // Global Unique ID (UUID). Used for synchronization with Supabase.
  // @Index makes searching by this ID instant.
  @Index(unique: true)
  late String uuid;

  // ID of the user who owns the note (for Auth later)
  late String userId;

  late String title;
  
  late String content;

  // Timestamp for the last modification (critical for sync logic)
  late DateTime updatedAt;

  // Sync Status: false = pending upload to cloud
  bool isSynced = false; 
  
  // UI Status: is the note locked with a password?
  bool isLocked = false;
}
