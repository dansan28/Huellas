import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/di/app_dependencies.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/travel_entry.dart';
import '../widgets/app_drawer.dart';
import '../widgets/entry_image.dart';
import '../widgets/location_map.dart';
import '../widgets/state_views.dart';

/// Mapa de todas las entradas con ubicación, unidas en orden cronológico
/// para ver la ruta del viaje. Se puede filtrar por viaje.
class TravelMapScreen extends StatefulWidget {
  const TravelMapScreen({super.key});

  @override
  State<TravelMapScreen> createState() => _TravelMapScreenState();
}

class _TravelMapScreenState extends State<TravelMapScreen> {
  late Future<List<TravelEntry>> _future;
  String? _trip;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<TravelEntry>> _load() => DependencyScope.of(context).entries.getAll();

  void _reload() => setState(() => _future = _load());

  Future<void> _showPreview(TravelEntry entry) async {
    final open = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(width: 72, height: 72, child: EntryImage(entry: entry, cacheWidth: 220)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.title, style: Theme.of(ctx).textTheme.titleMedium),
                        Text(entry.location?.displayName ?? '', style: Theme.of(ctx).textTheme.bodySmall),
                        Text(Formatters.shortDate(entry.createdAt), style: Theme.of(ctx).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ver entrada')),
            ],
          ),
        ),
      ),
    );
    if (open == true && mounted) {
      await Navigator.pushNamed(context, AppRoutes.entryDetail, arguments: entry);
      _reload(); // pudo editarse o eliminarse
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mapa de mis viajes')),
      drawer: const AppDrawer(currentRoute: AppRoutes.travelMap),
      body: FutureBuilder<List<TravelEntry>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done && !snapshot.hasData) {
            return const LoadingView(message: 'Ubicando tus recuerdos…');
          }
          if (snapshot.hasError) {
            final e = snapshot.error;
            return ErrorView(message: e is AppException ? e.message : 'No se pudo cargar el mapa.', onRetry: _reload);
          }
          final all = snapshot.data!.where((e) => e.hasLocation).toList()
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
          if (all.isEmpty) {
            return const EmptyView(
              icon: Icons.map_outlined,
              title: 'Aún no hay lugares',
              message: 'Las entradas que guardes con ubicación aparecerán aquí formando la ruta de tu viaje.',
            );
          }
          final trips = all.map((e) => e.tripName).toSet().toList()..sort();
          final visible = _trip == null ? all : all.where((e) => e.tripName == _trip).toList();
          return Column(
            children: [
              SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    ChoiceChip(
                      label: const Text('Todos'),
                      selected: _trip == null,
                      onSelected: (_) => setState(() => _trip = null),
                    ),
                    for (final t in trips) ...[
                      const SizedBox(width: 8),
                      ChoiceChip(label: Text(t), selected: _trip == t, onSelected: (_) => setState(() => _trip = t)),
                    ],
                  ],
                ),
              ),
              Expanded(child: _RouteMap(key: ValueKey(_trip), entries: visible, onTap: _showPreview)),
            ],
          );
        },
      ),
    );
  }
}

class _RouteMap extends StatelessWidget {
  const _RouteMap({super.key, required this.entries, required this.onTap});

  final List<TravelEntry> entries;
  final ValueChanged<TravelEntry> onTap;

  @override
  Widget build(BuildContext context) {
    final points = [for (final e in entries) LatLng(e.location!.latitude, e.location!.longitude)];
    return FlutterMap(
      options: MapOptions(
        initialCameraFit: CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.all(60),
          maxZoom: 15,
        ),
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
      ),
      children: [
        osmTileLayer(),
        if (points.length > 1)
          PolylineLayer(polylines: [
            Polyline(points: points, strokeWidth: 4, color: AppTheme.seed.withValues(alpha: 0.8)),
          ]),
        MarkerLayer(markers: [
          for (var i = 0; i < entries.length; i++)
            Marker(
              point: points[i],
              width: 34,
              height: 34,
              child: GestureDetector(onTap: () => onTap(entries[i]), child: MapPin(label: '${i + 1}')),
            ),
        ]),
        osmAttribution(),
      ],
    );
  }
}
