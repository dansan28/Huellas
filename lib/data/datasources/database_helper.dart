import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Abre y configura la base de datos SQLite de la app.
///
/// Responsabilidad única: crear el esquema y entregar una conexión. No
/// conoce el modelo de dominio; eso lo hace el repositorio.
class DatabaseHelper {
  DatabaseHelper({this.databaseName = 'huellas.db'});

  final String databaseName;

  /// Versión del esquema. Se incrementa al cambiar tablas (ver [_onUpgrade]).
  static const int _version = 1;

  static const String entriesTable = 'entries';

  Database? _database;

  /// Conexión perezosa: se abre la primera vez que se necesita y se reutiliza.
  Future<Database> get database async {
    final current = _database;
    if (current != null && current.isOpen) return current;
    final path = p.join(await getDatabasesPath(), databaseName);
    return _database = await openDatabase(
      path,
      version: _version,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Las fechas se guardan como milisegundos (INTEGER) para ordenar rápido.
    // La ubicación y sus metadatos se guardan serializados en JSON.
    await db.execute('''
      CREATE TABLE $entriesTable (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        title         TEXT    NOT NULL,
        content       TEXT    NOT NULL,
        trip_name     TEXT    NOT NULL,
        category      TEXT    NOT NULL,
        image_path    TEXT,
        audio_path    TEXT,
        location_json TEXT,
        created_at    INTEGER NOT NULL,
        updated_at    INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_entries_created_at ON $entriesTable(created_at DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_entries_trip_name ON $entriesTable(trip_name)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Punto de extensión para migraciones futuras (v1 es la primera versión).
  }

  /// Cierra la conexión (útil en pruebas).
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
