import 'package:flutter_test/flutter_test.dart';
import 'package:huellas/data/models/entry_category.dart';
import 'package:huellas/data/models/entry_location.dart';
import 'package:huellas/data/models/travel_entry.dart';

/// Pruebas de serialización: garantizan que una entrada sobrevive el viaje
/// ida y vuelta a SQLite (toMap/fromMap) y a JSON (toJson/fromJson).
void main() {
  final entry = TravelEntry(
    id: 7,
    title: 'Atardecer en el malecón',
    content: 'El cielo se puso naranja.',
    tripName: 'Mazatlán 2026',
    category: EntryCategory.paisaje,
    imagePath: '/data/img_1.jpg',
    audioPath: '/data/voz_1.m4a',
    location: EntryLocation(
      latitude: 23.2494,
      longitude: -106.4111,
      accuracyMeters: 8.5,
      placeName: 'Mazatlán, Sinaloa, México',
      capturedAt: DateTime(2026, 11, 14, 18, 30),
    ),
    createdAt: DateTime(2026, 11, 14, 18, 31),
    updatedAt: DateTime(2026, 11, 14, 18, 31),
  );

  test('toMap/fromMap conserva todos los campos (SQLite)', () {
    final copy = TravelEntry.fromMap(entry.toMap());
    expect(copy.toJson(), entry.toJson());
  });

  test('toJson/fromJson conserva todos los campos', () {
    final copy = TravelEntry.fromJson(entry.toJson());
    expect(copy.toJson(), entry.toJson());
  });

  test('la ubicación se guarda como texto JSON en SQLite', () {
    final map = entry.toMap();
    expect(map['location_json'], isA<String>());
    expect(EntryLocation.decode(map['location_json']! as String).latitude, 23.2494);
  });

  test('JSON de ubicación inválido lanza FormatException', () {
    expect(() => EntryLocation.decode('{"lat": "x"}'), throwsFormatException);
  });

  test('categoría desconocida cae en "otro" en lugar de fallar', () {
    expect(EntryCategory.fromName('inexistente'), EntryCategory.otro);
  });
}
