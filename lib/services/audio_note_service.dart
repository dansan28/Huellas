import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import '../core/errors/app_exceptions.dart';
import 'media_storage_service.dart';

/// Graba notas de voz con el micrófono (formato AAC/.m4a).
///
/// Cada widget que graba crea su propia instancia y la libera con [dispose].
class AudioRecorderService {
  AudioRecorderService(this._storage);

  final MediaStorageService _storage;
  final AudioRecorder _recorder = AudioRecorder();

  /// Inicia la grabación en un archivo nuevo dentro de la app.
  Future<void> start() async {
    try {
      if (!await _recorder.hasPermission(request: false)) {
        throw const MediaException('Falta el permiso del micrófono.');
      }
      final path = await _storage.newAudioPath();
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 96000, sampleRate: 44100),
        path: path,
      );
    } on MediaException {
      rethrow;
    } catch (e) {
      throw MediaException('No se pudo iniciar la grabación.', cause: e);
    }
  }

  /// Detiene la grabación y regresa la ruta del archivo.
  Future<String?> stop() async {
    try {
      return await _recorder.stop();
    } catch (e) {
      throw MediaException('No se pudo guardar la nota de voz.', cause: e);
    }
  }

  /// Descarta una grabación en curso.
  Future<void> cancel() async {
    try {
      await _recorder.cancel();
    } catch (e) {
      debugPrint('cancel grabación: $e');
    }
  }

  /// Nivel de entrada del micrófono (para animar la UI).
  Stream<Amplitude> amplitude() => _recorder.onAmplitudeChanged(const Duration(milliseconds: 150));

  Future<void> dispose() => _recorder.dispose();
}

/// Reproduce una nota de voz guardada.
class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();

  Stream<PlayerState> get onStateChanged => _player.onPlayerStateChanged;
  Stream<Duration> get onPosition => _player.onPositionChanged;
  Stream<Duration> get onDuration => _player.onDurationChanged;

  Future<void> play(String path) async {
    try {
      await _player.play(DeviceFileSource(path));
    } catch (e) {
      throw MediaException('No se pudo reproducir la nota de voz.', cause: e);
    }
  }

  Future<void> pause() => _player.pause();
  Future<void> stop() => _player.stop();
  Future<void> dispose() => _player.dispose();
}
