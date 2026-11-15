import 'package:flutter/material.dart';

/// Botón de micrófono que "late" mientras escucha, para que el usuario
/// sepa claramente que el dictado está activo.
class PulsingMicButton extends StatefulWidget {
  const PulsingMicButton({
    super.key,
    required this.isListening,
    required this.onPressed,
    this.enabled = true,
  });

  final bool isListening;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  State<PulsingMicButton> createState() => _PulsingMicButtonState();
}

class _PulsingMicButtonState extends State<PulsingMicButton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.isListening) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(PulsingMicButton old) {
    super.didUpdateWidget(old);
    if (widget.isListening && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isListening && _controller.isAnimating) {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = widget.isListening;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: active
                ? [BoxShadow(color: scheme.error.withValues(alpha: 0.35), blurRadius: 6 + 14 * t, spreadRadius: 2 * t)]
                : null,
          ),
          child: child,
        );
      },
      child: IconButton.filled(
        tooltip: active ? 'Detener dictado' : 'Dictar con la voz',
        style: IconButton.styleFrom(
          backgroundColor: active ? scheme.error : scheme.primaryContainer,
          foregroundColor: active ? scheme.onError : scheme.onPrimaryContainer,
        ),
        onPressed: widget.enabled ? widget.onPressed : null,
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
          child: Icon(active ? Icons.stop_rounded : Icons.mic, key: ValueKey(active)),
        ),
      ),
    );
  }
}
