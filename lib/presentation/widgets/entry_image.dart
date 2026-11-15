import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/models/travel_entry.dart';

/// Imagen de una entrada con respaldo visual.
///
/// Si la entrada no tiene foto, o el archivo ya no existe, muestra un
/// fondo degradado con el icono de su categoría en lugar de un error.
class EntryImage extends StatelessWidget {
  const EntryImage({
    super.key,
    required this.entry,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.iconSize = 40,
  });

  final TravelEntry entry;
  final BoxFit fit;

  /// Ancho de decodificación para miniaturas (ahorra memoria en la lista).
  final int? cacheWidth;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    if (!entry.hasImage) return _placeholder(context);
    return Image.file(
      File(entry.imagePath!),
      fit: fit,
      cacheWidth: cacheWidth,
      gaplessPlayback: true,
      errorBuilder: (context, _, _) => _placeholder(context, broken: true),
    );
  }

  Widget _placeholder(BuildContext context, {bool broken = false}) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primaryContainer, scheme.tertiaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          broken ? Icons.broken_image_outlined : entry.category.icon,
          size: iconSize,
          color: scheme.onPrimaryContainer.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}
