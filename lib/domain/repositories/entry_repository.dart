import '../../data/models/travel_entry.dart';

/// Contrato de acceso a las entradas del diario.
///
/// Principio de Inversión de Dependencias (la "D" de SOLID): las pantallas
/// dependen de esta abstracción y no de SQLite. Si mañana los datos se
/// guardaran en la nube, solo se escribiría otra implementación.
///
/// Todas las operaciones lanzan `StorageException` si algo falla.
abstract interface class EntryRepository {
  /// Todas las entradas, de la más reciente a la más antigua.
  /// Si [tripName] no es nulo, filtra por ese viaje.
  Future<List<TravelEntry>> getAll({String? tripName});

  /// Una entrada por su id, o `null` si ya no existe.
  Future<TravelEntry?> getById(int id);

  /// Nombres de viaje distintos, ordenados alfabéticamente.
  Future<List<String>> getTripNames();

  /// Inserta una entrada nueva y la regresa con su `id` asignado.
  Future<TravelEntry> create(TravelEntry entry);

  /// Actualiza una entrada existente.
  Future<TravelEntry> update(TravelEntry entry);

  /// Elimina la entrada y sus archivos asociados (foto y nota de voz).
  Future<void> delete(TravelEntry entry);
}
