// Standard Dart class to be used in UI and logic (Domain Model).
// Detached from any specific database implementation.

class Note {
  Note({
    required this.id,
    required this.uuid,
    required this.userId,
    required this.title,
    required this.content,
    required this.updatedAt,
    this.isSynced = false,
    this.isLocked = false,
  });

  final int id;

  // Global Unique ID (UUID). Used for synchronization with Supabase.
  String uuid;

  // ID of the user who owns the note
  String userId;

  String title;
  
  String content;

  // Timestamp for the last modification
  DateTime updatedAt;

  // Sync Status: false = pending upload to cloud
  bool isSynced; 
  
  // UI Status: is the note locked with a password?
  bool isLocked;

  // Helper method to create a copy of the note with modified fields
  Note copyWith({
    int? id,
    String? uuid,
    String? userId,
    String? title,
    String? content,
    DateTime? updatedAt,
    bool? isSynced,
    bool? isLocked,
  }) {
    return Note(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      content: content ?? this.content,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      isLocked: isLocked ?? this.isLocked,
    );
  }
}
