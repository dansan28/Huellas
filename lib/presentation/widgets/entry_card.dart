import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../data/models/travel_entry.dart';
import 'entry_image.dart';

/// Tarjeta de una entrada en la lista.
///
/// La miniatura está envuelta en un [Hero] con la misma etiqueta que la
/// imagen grande del detalle, así la foto "vuela" entre ambas pantallas.
class EntryCard extends StatelessWidget {
  const EntryCard({super.key, required this.entry, required this.onTap, this.index = 0});

  final TravelEntry entry;
  final VoidCallback onTap;

  /// Posición en la lista, para escalonar la animación de entrada.
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final card = Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: entry.heroTag,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 96,
                    height: 96,
                    child: EntryImage(entry: entry, cacheWidth: 300, iconSize: 32),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.place_outlined, size: 14, color: scheme.primary),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            entry.location?.displayName ?? 'Sin ubicación',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(color: scheme.primary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(entry.content,
                        maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(entry.category.icon, size: 14, color: scheme.outline),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(entry.category.label,
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelSmall),
                        ),
                        if (entry.hasAudio) ...[
                          Icon(Icons.graphic_eq, size: 14, color: scheme.outline),
                          const SizedBox(width: 6),
                        ],
                        Text(Formatters.shortDate(entry.createdAt),
                            style: theme.textTheme.labelSmall?.copyWith(color: scheme.outline)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Aparición escalonada: cada tarjeta entra un poco después que la anterior.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + (index.clamp(0, 8) * 60)),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 24 * (1 - t)), child: child),
      ),
      child: card,
    );
  }
}
