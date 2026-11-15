import 'package:flutter/foundation.dart';

import 'entry_category.dart';
import 'entry_location.dart';

/// Entrada del diario de viaje: el modelo central de la app.
///
/// Tiene dos formas de serialización:
/// * [toMap] / [TravelEntry.fromMap]: formato de filas para SQLite
///   (columnas planas; la ubicación va como texto JSON).
/// * [toJson] / [TravelEntry.fromJson]: formato JSON completo, usado para
///   exportar el diario como respaldo.
@immutable
class TravelEntry {
  const TravelEntry({
    this.id,
    required this.title,
    required this.content,
    required this.tripName,
    required this.category,
    required this.createdAt,
    required this.updatedAt,
    this.imagePath,
    this.audioPath,
    this.location,
  });

  /// Identificador autoincremental de SQLite (`null` si aún no se guarda).
  final int? id;
  final String title;
  final String content;

  /// Viaje al que pertenece la entrada (ej. "Oaxaca 2026").
  final String tripName;
  final EntryCategory category;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Ruta absoluta de la foto dentro de la carpeta de documentos de la app.
  final String? imagePath;

  /// Ruta absoluta de la nota de voz (.m4a).
  final String? audioPath;

  /// Ubicación GPS capturada al guardar.
  final EntryLocation? location;

  bool get hasImage => imagePath != null && imagePath!.isNotEmpty;
  bool get hasAudio => audioPath != null && audioPath!.isNotEmpty;
  bool get hasLocation => location != null;

  /// Etiqueta única para la animación Hero entre lista y detalle.
  String get heroTag => 'entry-image-$id';

  /// Copia con cambios. Los parámetros `clearX` permiten quitar campos opcionales.
  TravelEntry copyWith({
    int? id,
    String? title,
    String? content,
    String? tripName,
    EntryCategory? category,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? imagePath,
    String? audioPath,
    EntryLocation? location,
    bool clearImage = false,
    bool clearAudio = false,
    bool clearLocation = false,
  }) {
    return TravelEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      tripName: tripName ?? this.tripName,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      imagePath: clearImage ? null : (imagePath ?? this.imagePath),
      audioPath: clearAudio ? null : (audioPath ?? this.audioPath),
      location: clearLocation ? null : (location ?? this.location),
    );
  }

  // ---------------------------------------------------------------------------
  // SQLite
  // ---------------------------------------------------------------------------

  /// Convierte la entrada a una fila de la tabla `entries`.
  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'content': content,
        'trip_name': tripName,
        'category': category.name,
        'image_path': imagePath,
        'audio_path': audioPath,
        'location_json': location?.encode(),
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  /// Construye la entrada a partir de una fila de SQLite.
  factory TravelEntry.fromMap(Map<String, Object?> map) {
    final locationJson = map['location_json'] as String?;
    return TravelEntry(
      id: map['id'] as int?,
      title: map['title'] as String? ?? '',
      content: map['content'] as String? ?? '',
      tripName: map['trip_name'] as String? ?? '',
      category: EntryCategory.fromName(map['category'] as String?),
      imagePath: map['image_path'] as String?,
      audioPath: map['audio_path'] as String?,
      location: (locationJson == null || locationJson.isEmpty)
          ? null
          : EntryLocation.decode(locationJson),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  // ---------------------------------------------------------------------------
  // JSON (exportación / respaldo)
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'tripName': tripName,
        'category': category.name,
        'imagePath': imagePath,
        'audioPath': audioPath,
        'location': location?.toJson(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory TravelEntry.fromJson(Map<String, dynamic> json) => TravelEntry(
        id: json['id'] as int?,
        title: json['title'] as String,
        content: json['content'] as String,
        tripName: json['tripName'] as String,
        category: EntryCategory.fromName(json['category'] as String?),
        imagePath: json['imagePath'] as String?,
        audioPath: json['audioPath'] as String?,
        location: json['location'] == null
            ? null
            : EntryLocation.fromJson(json['location'] as Map<String, dynamic>),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}
