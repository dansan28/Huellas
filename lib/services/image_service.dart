import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../core/errors/app_exceptions.dart';
import 'media_storage_service.dart';

/// Origen de la foto.
enum PhotoSource { camera, gallery }

/// Toma una foto con la cámara o la elige de la galería y la guarda de forma
/// permanente dentro de la app.
class ImageService {
  ImageService(this._storage, [ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final MediaStorageService _storage;
  final ImagePicker _picker;

  /// Regresa la ruta permanente de la imagen, o `null` si el usuario canceló.
  Future<String?> pick(PhotoSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source == PhotoSource.camera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1920,
        imageQuality: 85, // reduce el tamaño sin pérdida visible
      );
      if (file == null) return null;
      return await _storage.persistImage(file.path);
    } on PlatformException catch (e) {
      debugPrint('image_picker: ${e.code} ${e.message}');
      if (e.code.contains('access_denied')) {
        throw MediaException(
          source == PhotoSource.camera
              ? 'No hay permiso para usar la cámara.'
              : 'No hay permiso para acceder a tus fotos.',
          cause: e,
        );
      }
      throw MediaException('No se pudo obtener la imagen.', cause: e);
    } on MediaException {
      rethrow;
    } catch (e) {
      throw MediaException('No se pudo obtener la imagen.', cause: e);
    }
  }
}
