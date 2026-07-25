import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

@DataClassName('NoteDb')
class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();

  // Shared with Supabase
  TextColumn get uuid => text().unique()();

  TextColumn get userId => text()();

  // Encrypted at rest with the session key
  TextColumn get title => text()();
  TextColumn get content => text()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  BoolColumn get isLocked => boolean().withDefault(const Constant(false))();
  TextColumn get passwordHash => text().nullable()();
}

/// Notes deleted locally whose cloud row is still alive.
///
/// Without this, deleting a note offline only removes the local copy and the
/// next cloud pull brings it back.
class PendingDeletes extends Table {
  TextColumn get uuid => text()();
  DateTimeColumn get deletedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {uuid};
}

@DriftDatabase(tables: [Notes, PendingDeletes])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(notes, notes.passwordHash);
      }
      if (from < 3) {
        await migrator.createTable(pendingDeletes);
      }
    },
  );

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'isan_notes_db',
      native: const DriftNativeOptions(),
      // Required on web: drift needs the wasm and worker assets
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  }
}