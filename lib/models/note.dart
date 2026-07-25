/// How the editor presents a note's content.
enum NoteType {
  /// Free text, shown as typed.
  plain,

  /// Markdown source with a rendered view.
  markdown,

  /// One copyable value per line.
  fields;

  /// Falls back to [plain] instead of throwing: an unknown name means the note
  /// comes from a newer version of the app, not that it is broken.
  static NoteType fromName(String? name) {
    return NoteType.values.firstWhere(
      (type) => type.name == name,
      orElse: () => NoteType.plain,
    );
  }
}

class Note {
  /// Local database ID (Drift / SQLite)
  final int id;

  /// Global unique ID (Supabase)
  final String uuid;

  /// Owner user ID
  final String userId;

  /// Content
  final String title;
  final String content;

  /// Timestamps (stored in UTC, shown in local time)
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Sync & state
  final bool isSynced;

  /// Presentation, not content: stored in the clear like [isLocked]
  final NoteType type;

  /// Lock state
  final bool isLocked;

  /// Password hash (nullable)
  /// - NULL => note is not protected
  /// - NOT NULL => note requires password
  final String? passwordHash;

  const Note({
    required this.id,
    required this.uuid,
    required this.userId,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    required this.isSynced,
    required this.type,
    required this.isLocked,
    this.passwordHash,
  });

  /// Factory from database / Supabase map
  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as int,
      uuid: map['uuid'] as String,
      userId: map['user_id'] as String,
      title: map['title'] as String? ?? '',
      content: map['content'] as String? ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      isSynced: map['is_synced'] as bool? ?? false,
      type: NoteType.fromName(map['note_type'] as String?),
      isLocked: map['is_locked'] as bool? ?? false,
      passwordHash: map['password_hash'] as String?,
    );
  }

  /// Map for database / cloud
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uuid': uuid,
      'user_id': userId,
      'title': title,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_synced': isSynced,
      'note_type': type.name,
      'is_locked': isLocked,
      'password_hash': passwordHash,
    };
  }

  /// Immutable update helper
  Note copyWith({
    int? id,
    String? uuid,
    String? userId,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
    NoteType? type,
    bool? isLocked,
    String? passwordHash,
  }) {
    return Note(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      type: type ?? this.type,
      isLocked: isLocked ?? this.isLocked,
      passwordHash: passwordHash ?? this.passwordHash,
    );
  }

  /// Clears the lock. Needed because [copyWith] can't set fields back to null.
  Note withoutLock() {
    return Note(
      id: id,
      uuid: uuid,
      userId: userId,
      title: title,
      content: content,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isSynced: false,
      type: type,
      isLocked: false,
    );
  }

  /// Convenience helpers
  bool get isProtected => isLocked && passwordHash != null;
}
