import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/errors/app_exceptions.dart';

/// Administra los archivos multimedia dentro de la carpeta privada de la app.
///
/// `image_picker` entrega las fotos en una carpeta temporal o de caché que
/// el sistema puede borrar. Para que las fotos sobrevivan a un reinicio, se
/// copian a `Documents/images` y en SQLite solo se guarda la ruta final.
class MediaStorageService {
  Future<Directory> _subdir(String name) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, name));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Copia una imagen temporal a almacenamiento permanente y regresa la nueva ruta.
  Future<String> persistImage(String tempPath) async {
    try {
      final dir = await _subdir('images');
      final ext = p.extension(tempPath).isEmpty ? '.jpg' : p.extension(tempPath);
      final target = p.join(dir.path, 'img_${DateTime.now().millisecondsSinceEpoch}$ext');
      final copy = await File(tempPath).copy(target);
      return copy.path;
    } catch (e) {
      throw MediaException('No se pudo guardar la imagen en el teléfono', cause: e);
    }
  }

  /// Ruta nueva y única donde grabar una nota de voz.
  Future<String> newAudioPath() async {
    final dir = await _subdir('audio');
    return p.join(dir.path, 'voz_${DateTime.now().millisecondsSinceEpoch}.m4a');
  }

  /// Borra un archivo si existe. Nunca lanza excepción: un archivo que no se
  /// pudo borrar no debe impedir que el usuario siga usando la app.
  Future<void> deleteFile(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('No se pudo borrar $path: $e');
    }
  }

  /// `true` si el archivo sigue existiendo (por ejemplo, para mostrar un
  /// marcador de "imagen no disponible" en lugar de un error).
  bool exists(String? path) => path != null && path.isNotEmpty && File(path).existsSync();
}
