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
      isLocked: isLocked ?? this.isLocked,
      passwordHash: passwordHash ?? this.passwordHash,
    );
  }

  /// Convenience helpers
  bool get isProtected => isLocked && passwordHash != null;
}
