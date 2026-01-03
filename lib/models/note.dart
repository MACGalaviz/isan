import 'package:isar/isar.dart';

// This line connects this file with the auto-generated code
// It will show an error until we run the code generator. That is normal.
part 'note.g.dart';

@collection
class Note {
  // Internal Isar ID (auto-incrementing integer)
  Id id = Isar.autoIncrement;

  // Global Unique ID (UUID). Used for synchronization with Supabase.
  // @Index makes searching by this ID instant.
  @Index(unique: true, replace: true)
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
