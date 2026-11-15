import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huellas/app.dart';
import 'package:huellas/core/di/app_dependencies.dart';
import 'package:huellas/core/routes/app_routes.dart';
import 'package:huellas/data/models/entry_category.dart';
import 'package:huellas/data/models/travel_entry.dart';
import 'package:huellas/domain/repositories/entry_repository.dart';
import 'package:huellas/services/biometric_service.dart';
import 'package:huellas/services/image_service.dart';
import 'package:huellas/services/location_service.dart';
import 'package:huellas/services/maps_launcher_service.dart';
import 'package:huellas/services/media_storage_service.dart';
import 'package:huellas/services/permission_service.dart';
import 'package:huellas/services/preferences_service.dart';
import 'package:huellas/services/speech_service.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Repositorio en memoria: demuestra que las pantallas dependen de la
/// abstracción [EntryRepository] y no de SQLite (principio de sustitución).
class InMemoryEntryRepository implements EntryRepository {
  InMemoryEntryRepository([List<TravelEntry>? seed]) : _items = [...?seed];
  final List<TravelEntry> _items;
  int _nextId = 100;

  @override
  Future<List<TravelEntry>> getAll({String? tripName}) async =>
      _items.where((e) => tripName == null || e.tripName == tripName).toList();
  @override
  Future<TravelEntry?> getById(int id) async => _items.where((e) => e.id == id).firstOrNull;
  @override
  Future<List<String>> getTripNames() async => _items.map((e) => e.tripName).toSet().toList();
  @override
  Future<TravelEntry> create(TravelEntry entry) async {
    final saved = entry.copyWith(id: _nextId++);
    _items.add(saved);
    return saved;
  }

  @override
  Future<TravelEntry> update(TravelEntry entry) async {
    _items[_items.indexWhere((e) => e.id == entry.id)] = entry;
    return entry;
  }

  @override
  Future<void> delete(TravelEntry entry) async => _items.removeWhere((e) => e.id == entry.id);
}

/// Pantalla de teléfono (360x800 lógicos) para que el formulario quepa.
void usePhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Widget buildApp(EntryRepository repo) {
  final media = MediaStorageService();
  return DependencyScope(
    dependencies: AppDependencies(
      entries: repo,
      media: media,
      permissions: PermissionService(),
      biometrics: BiometricService(),
      location: LocationService(),
      speech: SpeechService(),
      images: ImageService(media),
      preferences: PreferencesService(SharedPreferencesAsync()),
      maps: MapsLauncherService(),
    ),
    child: const HuellasApp(initialRoute: AppRoutes.home),
  );
}

void main() {
  setUpAll(() async {
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    await initializeDateFormatting('es');
  });

  final sample = TravelEntry(
    id: 1,
    title: 'Tlayudas en el mercado',
    content: 'La mejor comida del viaje.',
    tripName: 'Oaxaca 2026',
    category: EntryCategory.comida,
    createdAt: DateTime(2026, 11, 10, 14),
    updatedAt: DateTime(2026, 11, 10, 14),
  );

  testWidgets('lista vacía muestra estado vacío y el FAB abre el formulario', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(buildApp(InMemoryEntryRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Tu diario está vacío'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Ilustra tu día con una foto'), findsOneWidget);

    // Formulario sin cambios: "atrás" regresa sin pedir confirmación.
    await tester.tap(find.byTooltip('Atrás'));
    await tester.pumpAndSettle();
    expect(find.text('Tu diario está vacío'), findsOneWidget);
  });

  testWidgets('lista → detalle (Hero) → editar → regresar', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(buildApp(InMemoryEntryRepository([sample])));
    await tester.pumpAndSettle();

    expect(find.text('Tlayudas en el mercado'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is Hero && w.tag == sample.heroTag), findsOneWidget);

    await tester.tap(find.text('Tlayudas en el mercado'));
    await tester.pumpAndSettle();
    expect(find.text('Esta entrada no tiene ubicación'), findsOneWidget);

    await tester.tap(find.byTooltip('Editar'));
    await tester.pumpAndSettle();
    expect(find.text('Editar entrada'), findsOneWidget);
    expect(find.text('Tlayudas en el mercado'), findsOneWidget); // campo precargado

    await tester.tap(find.byTooltip('Atrás'));
    await tester.pumpAndSettle();
    expect(find.text('La mejor comida del viaje.'), findsOneWidget);
  });

  testWidgets('el Drawer resalta la sección y navega a Ajustes', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(buildApp(InMemoryEntryRepository([sample])));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DrawerButton));
    await tester.pumpAndSettle();
    expect(find.text('Mapa de viajes'), findsOneWidget);

    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    expect(find.text('Exportar diario (JSON)'), findsOneWidget);
  });
}
