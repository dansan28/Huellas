import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/di/app_dependencies.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/utils/formatters.dart';
import '../../services/audio_note_service.dart';
import '../../services/permission_service.dart';
import 'permission_flow.dart';
import 'state_views.dart';
import 'voice_note_player.dart';

/// Graba una nota de voz para la entrada (captura de audio del micrófono).
///
/// Notifica cada archivo nuevo con [onFileCreated] para que el formulario
/// pueda borrar grabaciones descartadas y no dejar archivos huérfanos.
class VoiceNoteRecorder extends StatefulWidget {
  const VoiceNoteRecorder({
    super.key,
    required this.audioPath,
    required this.onChanged,
    required this.onFileCreated,
    required this.onRecordingChanged,
    this.enabled = true,
  });

  final String? audioPath;
  final ValueChanged<String?> onChanged;
  final ValueChanged<String> onFileCreated;
  final ValueChanged<bool> onRecordingChanged;

  /// Se deshabilita mientras el dictado usa el micrófono.
  final bool enabled;

  @override
  State<VoiceNoteRecorder> createState() => _VoiceNoteRecorderState();
}

class _VoiceNoteRecorderState extends State<VoiceNoteRecorder> {
  static const _maxDuration = Duration(minutes: 2);

  AudioRecorderService? _recorder;
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  bool _recording = false;
  double _level = 0;
  StreamSubscription<dynamic>? _ampSub;

  AudioRecorderService get _rec =>
      _recorder ??= AudioRecorderService(DependencyScope.of(context).media);

  @override
  void dispose() {
    _timer?.cancel();
    _ampSub?.cancel();
    if (_recording) _recorder?.cancel();
    _recorder?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (!await ensurePermission(context, AppPermission.microphone)) return;
    try {
      await _rec.start();
      _ampSub = _rec.amplitude().listen((a) {
        // dBFS va de ~-60 (silencio) a 0 (máximo); se normaliza a 0..1.
        if (mounted) setState(() => _level = ((a.current + 60) / 60).clamp(0, 1));
      });
      setState(() {
        _recording = true;
        _elapsed = Duration.zero;
      });
      widget.onRecordingChanged(true);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _elapsed += const Duration(seconds: 1));
        if (_elapsed >= _maxDuration) _stop();
      });
    } on AppException catch (e) {
      if (mounted) context.showSnack(e.message, isError: true);
    }
  }

  Future<void> _stop() async {
    _timer?.cancel();
    await _ampSub?.cancel();
    try {
      final path = await _rec.stop();
      if (path != null) {
        widget.onFileCreated(path);
        widget.onChanged(path);
      }
    } on AppException catch (e) {
      if (mounted) context.showSnack(e.message, isError: true);
    } finally {
      if (mounted) setState(() => _recording = false);
      widget.onRecordingChanged(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_recording) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(40),
        ),
        child: Row(
          children: [
            Icon(Icons.fiber_manual_record, color: scheme.error),
            const SizedBox(width: 8),
            Text('Grabando  ${Formatters.duration(_elapsed)}'),
            const SizedBox(width: 12),
            Expanded(
              child: LinearProgressIndicator(
                value: _level,
                color: scheme.error,
                backgroundColor: scheme.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            IconButton(onPressed: _stop, icon: const Icon(Icons.stop_circle_outlined), tooltip: 'Detener'),
          ],
        ),
      );
    }

    final path = widget.audioPath;
    if (path != null) {
      return VoiceNotePlayer(
        key: ValueKey(path),
        path: path,
        trailing: IconButton(
          tooltip: 'Quitar nota de voz',
          icon: const Icon(Icons.delete_outline),
          onPressed: () => widget.onChanged(null),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: widget.enabled ? _start : null,
      icon: const Icon(Icons.keyboard_voice_outlined),
      label: const Text('Grabar nota de voz'),
    );
  }
}
