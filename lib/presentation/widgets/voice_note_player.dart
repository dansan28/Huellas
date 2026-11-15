import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../core/errors/app_exceptions.dart';
import '../../core/utils/formatters.dart';
import '../../services/audio_note_service.dart';
import 'state_views.dart';

/// Reproductor compacto de una nota de voz guardada.
class VoiceNotePlayer extends StatefulWidget {
  const VoiceNotePlayer({super.key, required this.path, this.trailing});

  final String path;

  /// Acción extra a la derecha (ej. botón de borrar en el formulario).
  final Widget? trailing;

  @override
  State<VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<VoiceNotePlayer> {
  final _player = AudioPlayerService();
  final _subs = <StreamSubscription<dynamic>>[];
  PlayerState _state = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _subs
      ..add(_player.onStateChanged.listen((s) {
        if (!mounted) return;
        setState(() {
          _state = s;
          if (s == PlayerState.completed) _position = Duration.zero;
        });
      }))
      ..add(_player.onPosition.listen((p) => mounted ? setState(() => _position = p) : null))
      ..add(_player.onDuration.listen((d) => mounted ? setState(() => _duration = d) : null));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    try {
      if (_state == PlayerState.playing) {
        await _player.pause();
      } else {
        await _player.play(widget.path);
      }
    } on AppException catch (e) {
      if (mounted) context.showSnack(e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!File(widget.path).existsSync()) {
      return ListTile(
        leading: const Icon(Icons.error_outline),
        title: const Text('La nota de voz ya no está disponible'),
        trailing: widget.trailing,
      );
    }
    final playing = _state == PlayerState.playing;
    final progress = _duration.inMilliseconds == 0 ? 0.0 : _position.inMilliseconds / _duration.inMilliseconds;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(40),
      ),
      child: Row(
        children: [
          IconButton.filled(
            onPressed: _toggle,
            tooltip: playing ? 'Pausar' : 'Reproducir nota de voz',
            icon: Icon(playing ? Icons.pause : Icons.play_arrow),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nota de voz'),
                const SizedBox(height: 4),
                LinearProgressIndicator(value: progress.clamp(0, 1), borderRadius: BorderRadius.circular(4)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(Formatters.duration(playing || _position > Duration.zero ? _position : _duration)),
          ?widget.trailing,
        ],
      ),
    );
  }
}
