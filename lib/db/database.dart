import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

// Esta línea dará error hasta que corramos el generador de código. ¡Es normal!
part 'database.g.dart';

// 1. Definición de la Tabla (Equivalente a tu antiguo NoteSchema)
@DataClassName('NoteDb') // La clase generada se llamará NoteDb
class Notes extends Table {
  // ID Local (Auto-incremental)
  IntColumn get id => integer().autoIncrement()();
  
  // UUID de Supabase (Único)
  TextColumn get uuid => text().unique()();
  
  // ID del usuario propietario
  TextColumn get userId => text()();
  
  // Contenido de la nota
  TextColumn get title => text()();
  TextColumn get content => text()();
  
  // Fechas y Estados
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  BoolColumn get isLocked => boolean().withDefault(const Constant(false))();
}

// 2. Definición de la Base de Datos
@DriftDatabase(tables: [Notes])
class AppDatabase extends _$AppDatabase {
  // Constructor que usa la configuración automática de drift_flutter
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // Configuración de conexión (Automática para Web y Nativo)
  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'isan_notes_db',
      native: const DriftNativeOptions(
        // Opciones nativas (Android/Windows) - Por defecto está bien
      ),
      // ⚠️ AQUÍ ESTABA EL ERROR: Es obligatorio definir esto para Web
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  }
}