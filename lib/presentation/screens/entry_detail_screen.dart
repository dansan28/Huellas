import 'package:flutter/material.dart';

import '../../core/di/app_dependencies.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/routes/app_routes.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/entry_location.dart';
import '../../data/models/travel_entry.dart';
import '../widgets/entry_image.dart';
import '../widgets/location_map.dart';
import '../widgets/state_views.dart';
import '../widgets/voice_note_player.dart';

/// Detalle de una entrada: foto (Hero), texto, nota de voz y mapa.
///
/// Recibe la entrada desde la lista para que la animación Hero tenga la
/// imagen desde el primer cuadro (`initialData`), y en paralelo vuelve a
/// leerla de SQLite con un [FutureBuilder] para mostrar la versión más
/// reciente (por ejemplo, después de editarla).
class EntryDetailScreen extends StatefulWidget {
  const EntryDetailScreen({super.key, required this.entry});

  final TravelEntry entry;

  @override
  State<EntryDetailScreen> createState() => _EntryDetailScreenState();
}

class _EntryDetailScreenState extends State<EntryDetailScreen> {
  late Future<TravelEntry?> _future;
  late TravelEntry _latest = widget.entry;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<TravelEntry?> _load() => DependencyScope.of(context).entries.getById(widget.entry.id!);

  Future<void> _edit() async {
    final updated = await Navigator.pushNamed<TravelEntry>(context, AppRoutes.entryForm, arguments: _latest);
    if (updated != null && mounted) {
      setState(() {
        _latest = updated;
        _future = _load();
      });
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: const Text('¿Eliminar esta entrada?'),
        content: Text('"${_latest.title}" se borrará junto con su foto y nota de voz. '
            'Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await DependencyScope.of(context).entries.delete(_latest);
      if (mounted) Navigator.pop(context, true); // la lista muestra "Entrada eliminada"
    } on AppException catch (e) {
      if (mounted) context.showSnack(e.message, isError: true);
    }
  }

  Future<void> _openInMaps(EntryLocation location) async {
    try {
      await DependencyScope.of(context).maps.openInGoogleMaps(location);
    } on AppException catch (e) {
      if (mounted) context.showSnack(e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TravelEntry?>(
      future: _future,
      initialData: _latest,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final msg = snapshot.error is AppException
              ? (snapshot.error as AppException).message
              : 'No se pudo cargar la entrada.';
          return Scaffold(
            appBar: AppBar(),
            body: ErrorView(message: msg, onRetry: () => setState(() => _future = _load())),
          );
        }
        final entry = snapshot.data;
        if (entry == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyView(
              icon: Icons.search_off,
              title: 'Entrada no encontrada',
              message: 'Es posible que se haya eliminado.',
            ),
          );
        }
        _latest = entry;
        return _buildContent(context, entry);
      },
    );
  }

  Widget _buildContent(BuildContext context, TravelEntry entry) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            stretch: true,
            expandedHeight: 320,
            foregroundColor: Colors.white,
            backgroundColor: scheme.primary,
            actions: [
              IconButton(onPressed: _edit, icon: const Icon(Icons.edit_outlined), tooltip: 'Editar'),
              IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline), tooltip: 'Eliminar'),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: GestureDetector(
                onTap: entry.hasImage
                    ? () => Navigator.pushNamed(context, AppRoutes.photoViewer, arguments: entry)
                    : null,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(tag: entry.heroTag, child: EntryImage(entry: entry, iconSize: 80)),
                    // Degradado para que los iconos blancos se lean sobre la foto.
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.center,
                          colors: [Colors.black54, Colors.transparent],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            sliver: SliverList.list(
              children: [
                Text(entry.title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(avatar: const Icon(Icons.flight_takeoff, size: 18), label: Text(entry.tripName)),
                    Chip(avatar: Icon(entry.category.icon, size: 18), label: Text(entry.category.label)),
                    Chip(
                      avatar: const Icon(Icons.schedule, size: 18),
                      label: Text(Formatters.time(entry.createdAt)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(_capitalize(Formatters.longDate(entry.createdAt)),
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.outline)),
                const SizedBox(height: 20),
                SelectableText(entry.content, style: theme.textTheme.bodyLarge?.copyWith(height: 1.5)),
                if (entry.hasAudio) ...[
                  const SizedBox(height: 24),
                  VoiceNotePlayer(key: ValueKey(entry.audioPath), path: entry.audioPath!),
                ],
                const SizedBox(height: 28),
                Text('¿Dónde fue?', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                if (entry.location case final loc?)
                  _LocationSection(location: loc, onOpenMaps: () => _openInMaps(loc))
                else
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.location_off_outlined),
                      title: const Text('Esta entrada no tiene ubicación'),
                      subtitle: const Text('Edítala y activa "Usar mi ubicación actual".'),
                      onTap: _edit,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _LocationSection extends StatelessWidget {
  const _LocationSection({required this.location, required this.onOpenMaps});

  final EntryLocation location;
  final VoidCallback onOpenMaps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LocationMap(latitude: location.latitude, longitude: location.longitude),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.place, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(location.placeName ?? 'Lugar sin nombre', style: theme.textTheme.titleSmall),
                  Text(
                    [
                      location.coordinatesText,
                      if (location.accuracyMeters != null) '±${location.accuracyMeters!.round()} m',
                      if (location.isApproximate) 'aproximada',
                    ].join('  ·  '),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: onOpenMaps,
          icon: const Icon(Icons.map_outlined),
          label: const Text('Abrir en Google Maps'),
        ),
      ],
    );
  }
}
