import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../core/errors/app_exceptions.dart';

/// Dictado por voz: captura audio del micrófono y lo convierte a texto.
///
/// Usa el reconocedor de voz del sistema (en Android, el de Google) a través
/// de `speech_to_text`. Prefiere español de México y, si no existe, cualquier
/// variante de español instalada.
class SpeechService {
  SpeechService([SpeechToText? speech]) : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  bool _initialized = false;
  String? _localeId;

  /// Último error reportado por el motor durante la escucha.
  void Function(String message)? onError;

  /// Cambios de estado ("listening", "notListening", "done").
  void Function(bool isListening)? onListeningChanged;

  bool get isListening => _speech.isListening;

  /// Inicializa el motor una sola vez. Lanza [SpeechException] si el
  /// reconocimiento no está disponible en el dispositivo.
  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    try {
      final available = await _speech.initialize(
        onError: _handleError,
        onStatus: (status) => onListeningChanged?.call(status == SpeechToText.listeningStatus),
      );
      if (!available) {
        throw const SpeechException(
          'El reconocimiento de voz no está disponible. Verifica que la app de Google esté instalada y actualizada.',
        );
      }
      _initialized = true;
      _localeId = await _pickSpanishLocale();
    } on SpeechException {
      rethrow;
    } catch (e) {
      throw SpeechException('No se pudo iniciar el dictado por voz.', cause: e);
    }
  }

  Future<String?> _pickSpanishLocale() async {
    try {
      final locales = await _speech.locales();
      String? find(bool Function(String id) test) =>
          locales.map((l) => l.localeId).where(test).firstOrNull;
      return find((id) => id.replaceAll('-', '_') == 'es_MX') ??
          find((id) => id.toLowerCase().startsWith('es'));
    } catch (_) {
      return null; // se usará el idioma del sistema
    }
  }

  /// Comienza a escuchar. [onText] recibe el texto reconocido hasta el
  /// momento (resultados parciales) y [isFinal] indica el resultado final.
  Future<void> start({required void Function(String text, bool isFinal) onText}) async {
    await _ensureInitialized();
    try {
      await _speech.listen(
        onResult: (SpeechRecognitionResult r) => onText(r.recognizedWords, r.finalResult),
        listenOptions: SpeechListenOptions(
          localeId: _localeId,
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
          listenFor: const Duration(minutes: 1),
          pauseFor: const Duration(seconds: 5),
          autoPunctuation: true,
        ),
      );
    } catch (e) {
      throw SpeechException('No se pudo comenzar a escuchar.', cause: e);
    }
  }

  /// Detiene la escucha y conserva lo reconocido.
  Future<void> stop() async {
    if (_speech.isListening) await _speech.stop();
  }

  /// Cancela la escucha.
  Future<void> cancel() async {
    if (_speech.isListening) await _speech.cancel();
  }

  void _handleError(SpeechRecognitionError error) {
    debugPrint('Dictado: ${error.errorMsg} (permanente: ${error.permanent})');
    final message = switch (error.errorMsg) {
      'error_no_match' || 'error_speech_timeout' => 'No te escuché. Intenta hablar más cerca del micrófono.',
      'error_network' || 'error_network_timeout' || 'error_server' =>
        'El dictado necesita conexión a internet en este teléfono.',
      'error_permission' || 'error_insufficient_permissions' => 'Falta el permiso del micrófono.',
      'error_busy' => 'El reconocedor de voz está ocupado. Intenta de nuevo.',
      _ => 'Error en el dictado (${error.errorMsg}).',
    };
    onListeningChanged?.call(false);
    onError?.call(message);
  }
}
