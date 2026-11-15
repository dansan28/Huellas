import 'dart:convert';

/// Ubicación GPS capturada al guardar una entrada.
///
/// Es un objeto inmutable que se serializa a JSON para guardarse en una sola
/// columna de SQLite (`location_json`). Incluye metadatos además de las
/// coordenadas: precisión, nombre del lugar y momento de la captura.
class EntryLocation {
  const EntryLocation({
    required this.latitude,
    required this.longitude,
    required this.capturedAt,
    this.accuracyMeters,
    this.placeName,
    this.isApproximate = false,
  });

  final double latitude;
  final double longitude;

  /// Precisión reportada por el GPS, en metros.
  final double? accuracyMeters;

  /// Ciudad y país obtenidos por geocodificación inversa (puede ser nulo si
  /// no había internet al momento de guardar).
  final String? placeName;

  /// Momento en que se obtuvo la posición.
  final DateTime capturedAt;

  /// `true` si se usó la última ubicación conocida porque el GPS tardó demasiado.
  final bool isApproximate;

  /// Texto corto para mostrar: el nombre del lugar o, si no existe, las coordenadas.
  String get displayName => placeName ?? coordinatesText;

  /// Coordenadas con 5 decimales (~1 m de resolución).
  String get coordinatesText =>
      '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';

  EntryLocation copyWith({String? placeName}) => EntryLocation(
        latitude: latitude,
        longitude: longitude,
        capturedAt: capturedAt,
        accuracyMeters: accuracyMeters,
        placeName: placeName ?? this.placeName,
        isApproximate: isApproximate,
      );

  /// Serialización a un mapa compatible con JSON.
  Map<String, dynamic> toJson() => {
        'lat': latitude,
        'lng': longitude,
        'accuracy': accuracyMeters,
        'place': placeName,
        'capturedAt': capturedAt.toIso8601String(),
        'approximate': isApproximate,
      };

  /// Deserialización desde JSON. Lanza [FormatException] si faltan las
  /// coordenadas, para que el repositorio pueda detectar datos corruptos.
  factory EntryLocation.fromJson(Map<String, dynamic> json) {
    final lat = json['lat'];
    final lng = json['lng'];
    if (lat is! num || lng is! num) {
      throw const FormatException('Ubicación sin coordenadas válidas');
    }
    return EntryLocation(
      latitude: lat.toDouble(),
      longitude: lng.toDouble(),
      accuracyMeters: (json['accuracy'] as num?)?.toDouble(),
      placeName: json['place'] as String?,
      capturedAt: DateTime.tryParse(json['capturedAt'] as String? ?? '') ?? DateTime.now(),
      isApproximate: json['approximate'] as bool? ?? false,
    );
  }

  /// Codifica a texto JSON (para la columna de SQLite).
  String encode() => jsonEncode(toJson());

  /// Decodifica desde texto JSON.
  static EntryLocation decode(String source) =>
      EntryLocation.fromJson(jsonDecode(source) as Map<String, dynamic>);
}
