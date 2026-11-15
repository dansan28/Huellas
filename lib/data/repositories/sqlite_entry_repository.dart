import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/errors/app_exceptions.dart';
import '../../domain/repositories/entry_repository.dart';
import '../../services/media_storage_service.dart';
import '../datasources/database_helper.dart';
import '../models/travel_entry.dart';

/// Implementación de [EntryRepository] sobre SQLite (paquete sqflite).
///
/// Cada operación está envuelta en try-catch: los errores técnicos se
/// registran con `debugPrint` y se relanzan como [StorageException] con un
/// mensaje entendible, para que la UI nunca reciba una excepción cruda.
class SqliteEntryRepository implements EntryRepository {
  SqliteEntryRepository(this._dbHelper, this._mediaStorage);

  final DatabaseHelper _dbHelper;
  final MediaStorageService _mediaStorage;

  static const _table = DatabaseHelper.entriesTable;

  @override
  Future<List<TravelEntry>> getAll({String? tripName}) {
    return _guard('No se pudieron cargar tus entradas', () async {
      final db = await _dbHelper.database;
      final rows = await db.query(
        _table,
        where: tripName == null ? null : 'trip_name = ?',
        whereArgs: tripName == null ? null : [tripName],
        orderBy: 'created_at DESC',
      );
      return rows.map(_rowToEntry).whereType<TravelEntry>().toList();
    });
  }

  @override
  Future<TravelEntry?> getById(int id) {
    return _guard('No se pudo cargar la entrada', () async {
      final db = await _dbHelper.database;
      final rows = await db.query(_table, where: 'id = ?', whereArgs: [id], limit: 1);
      return rows.isEmpty ? null : _rowToEntry(rows.first);
    });
  }

  @override
  Future<List<String>> getTripNames() {
    return _guard('No se pudieron cargar los viajes', () async {
      final db = await _dbHelper.database;
      final rows = await db.rawQuery(
        'SELECT DISTINCT trip_name FROM $_table ORDER BY trip_name COLLATE NOCASE',
      );
      return rows.map((r) => r['trip_name'] as String).toList();
    });
  }

  @override
  Future<TravelEntry> create(TravelEntry entry) {
    return _guard('No se pudo guardar la entrada', () async {
      final db = await _dbHelper.database;
      final id = await db.insert(
        _table,
        entry.toMap()..remove('id'),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      return entry.copyWith(id: id);
    });
  }

  @override
  Future<TravelEntry> update(TravelEntry entry) {
    final id = entry.id;
    if (id == null) {
      throw const StorageException('No se puede actualizar una entrada sin id');
    }
    return _guard('No se pudieron guardar los cambios', () async {
      final db = await _dbHelper.database;
      final count = await db.update(_table, entry.toMap(), where: 'id = ?', whereArgs: [id]);
      if (count == 0) {
        throw const StorageException('La entrada ya no existe');
      }
      return entry;
    });
  }

  @override
  Future<void> delete(TravelEntry entry) async {
    final id = entry.id;
    if (id == null) return;
    await _guard('No se pudo eliminar la entrada', () async {
      final db = await _dbHelper.database;
      await db.delete(_table, where: 'id = ?', whereArgs: [id]);
    });
    // Los archivos se borran después del registro: si fallan, la entrada ya
    // no existe y solo queda un archivo huérfano (no se pierde consistencia).
    await _mediaStorage.deleteFile(entry.imagePath);
    await _mediaStorage.deleteFile(entry.audioPath);
  }

  /// Convierte una fila; si la ubicación JSON está corrupta conserva la
  /// entrada sin ubicación en vez de perder toda la lista.
  TravelEntry? _rowToEntry(Map<String, Object?> row) {
    try {
      return TravelEntry.fromMap(row);
    } on FormatException catch (e) {
      debugPrint('Ubicación corrupta en entrada ${row['id']}: $e');
      return TravelEntry.fromMap({...row, 'location_json': null});
    } catch (e) {
      debugPrint('Fila inválida ${row['id']} ignorada: $e');
      return null;
    }
  }

  /// Ejecuta [action] traduciendo cualquier error a [StorageException].
  Future<T> _guard<T>(String message, Future<T> Function() action) async {
    try {
      return await action();
    } on StorageException {
      rethrow;
    } on DatabaseException catch (e, st) {
      debugPrint('SQLite: $e\n$st');
      throw StorageException(message, cause: e);
    } catch (e, st) {
      debugPrint('Error de almacenamiento: $e\n$st');
      throw StorageException(message, cause: e);
    }
  }
}
