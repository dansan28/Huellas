import 'package:flutter/material.dart';

import '../../core/di/app_dependencies.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/routes/app_routes.dart';
import '../../data/models/travel_entry.dart';
import '../widgets/app_drawer.dart';
import '../widgets/entry_card.dart';
import '../widgets/state_views.dart';

/// Pantalla principal: lista de entradas del diario.
///
/// Carga los datos de SQLite con un [FutureBuilder] y muestra un estado
/// distinto para cada caso: cargando, error (con reintento), vacío y datos.
/// Implementa [RouteAware] para recargar automáticamente al volver de otra
/// pantalla (después de crear, editar o borrar una entrada).
class EntryListScreen extends StatefulWidget {
  const EntryListScreen({super.key});

  @override
  State<EntryListScreen> createState() => _EntryListScreenState();
}

class _EntryListScreenState extends State<EntryListScreen> with RouteAware {
  late Future<List<TravelEntry>> _future;
  String? _selectedTrip;
  bool _subscribed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_subscribed) {
      _future = _load();
      final route = ModalRoute.of(context);
      if (route != null) AppRoutes.observer.subscribe(this, route);
      _subscribed = true;
    }
  }

  @override
  void dispose() {
    AppRoutes.observer.unsubscribe(this);
    super.dispose();
  }

  /// Se llama cuando la pantalla que estaba encima se cierra.
  @override
  void didPopNext() => _reload();

  Future<List<TravelEntry>> _load() => DependencyScope.of(context).entries.getAll();

  void _reload() => setState(() => _future = _load());

  Future<void> _openForm() => Navigator.pushNamed(context, AppRoutes.entryForm);

  Future<void> _openDetail(TravelEntry entry) async {
    final deleted = await Navigator.pushNamed<bool>(context, AppRoutes.entryDetail, arguments: entry);
    if (deleted == true && mounted) context.showSnack('Entrada eliminada');
  }

  String _errorMessage(Object? error) =>
      error is AppException ? error.message : 'Algo salió mal al cargar tus entradas.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis entradas'),
        actions: [
          IconButton(
            tooltip: 'Ver mapa de mis viajes',
            icon: const Icon(Icons.map_outlined),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.travelMap),
          ),
        ],
      ),
      drawer: const AppDrawer(currentRoute: AppRoutes.home),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Nueva entrada'),
      ),
      body: FutureBuilder<List<TravelEntry>>(
        future: _future,
        builder: (context, snapshot) {
          final loading = snapshot.connectionState != ConnectionState.done;

          // Primera carga: indicador de progreso a pantalla completa.
          if (loading && !snapshot.hasData) {
            return const LoadingView(message: 'Cargando tus recuerdos…');
          }
          if (snapshot.hasError) {
            return ErrorView(message: _errorMessage(snapshot.error), onRetry: _reload);
          }

          final all = snapshot.data ?? const <TravelEntry>[];
          if (all.isEmpty) {
            return EmptyView(
              icon: Icons.luggage_outlined,
              title: 'Tu diario está vacío',
              message: 'Guarda tu primer recuerdo: una foto, lo que viviste y dónde estabas.',
              action: FilledButton.icon(
                onPressed: _openForm,
                icon: const Icon(Icons.add),
                label: const Text('Crear primera entrada'),
              ),
            );
          }

          final trips = all.map((e) => e.tripName).toSet().toList()..sort();
          if (_selectedTrip != null && !trips.contains(_selectedTrip)) _selectedTrip = null;
          final visible = _selectedTrip == null ? all : all.where((e) => e.tripName == _selectedTrip).toList();

          return Column(
            children: [
              // Recargas posteriores: barra delgada sin ocultar la lista.
              AnimatedOpacity(
                opacity: loading ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: const LinearProgressIndicator(minHeight: 2),
              ),
              _TripFilter(
                trips: trips,
                selected: _selectedTrip,
                onSelected: (t) => setState(() => _selectedTrip = t),
              ),
              _Summary(entries: visible),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    _reload();
                    await _future;
                  },
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => EntryCard(
                      key: ValueKey(visible[i].id),
                      entry: visible[i],
                      index: i,
                      onTap: () => _openDetail(visible[i]),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Chips horizontales para filtrar por viaje.
class _TripFilter extends StatelessWidget {
  const _TripFilter({required this.trips, required this.selected, required this.onSelected});

  final List<String> trips;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          ChoiceChip(
            label: const Text('Todos'),
            selected: selected == null,
            onSelected: (_) => onSelected(null),
          ),
          for (final trip in trips) ...[
            const SizedBox(width: 8),
            ChoiceChip(
              avatar: const Icon(Icons.flight_takeoff, size: 16),
              label: Text(trip),
              selected: selected == trip,
              onSelected: (_) => onSelected(trip),
            ),
          ],
        ],
      ),
    );
  }
}

/// Resumen numérico de lo que se está viendo.
class _Summary extends StatelessWidget {
  const _Summary({required this.entries});
  final List<TravelEntry> entries;

  @override
  Widget build(BuildContext context) {
    final places = entries.map((e) => e.location?.placeName).whereType<String>().toSet().length;
    final photos = entries.where((e) => e.hasImage).length;
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.outline);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: [
          Text('${entries.length} ${entries.length == 1 ? 'entrada' : 'entradas'}', style: style),
          Text('  ·  $photos fotos', style: style),
          Text('  ·  $places ${places == 1 ? 'lugar' : 'lugares'}', style: style),
        ],
      ),
    );
  }
}
