/// Jerarquía de excepciones propias de la app.
///
/// Cada capa traduce los errores técnicos (sqflite, plugins nativos, etc.)
/// a una [AppException] con un [message] legible para el usuario. Así la
/// capa de presentación solo necesita conocer este tipo y puede mostrar el
/// mensaje en un SnackBar o en una vista de error sin cerrar la app.
sealed class AppException implements Exception {
  const AppException(this.message, {this.cause});

  /// Mensaje en español pensado para mostrarse en la interfaz.
  final String message;

  /// Error original (útil para depuración y bitácoras).
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message${cause != null ? ' ($cause)' : ''}';
}

/// Fallo al leer o escribir en la base de datos local o en archivos.
class StorageException extends AppException {
  const StorageException(super.message, {super.cause});
}

/// El usuario negó un permiso del dispositivo.
class PermissionDeniedException extends AppException {
  const PermissionDeniedException(
    super.message, {
    this.permanentlyDenied = false,
    super.cause,
  });

  /// `true` cuando el sistema ya no mostrará el diálogo de permiso y la
  /// única opción es abrir los ajustes de la app.
  final bool permanentlyDenied;
}

/// Fallo al obtener la ubicación GPS.
class LocationException extends AppException {
  const LocationException(super.message, {this.serviceDisabled = false, super.cause});

  /// `true` si el GPS del teléfono está apagado.
  final bool serviceDisabled;
}

/// Fallo con la cámara, la galería o la grabación de audio.
class MediaException extends AppException {
  const MediaException(super.message, {super.cause});
}

/// Fallo con el reconocimiento de voz.
class SpeechException extends AppException {
  const SpeechException(super.message, {super.cause});
}
