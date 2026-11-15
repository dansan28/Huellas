import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/datasources/database_helper.dart';
import '../../data/repositories/sqlite_entry_repository.dart';
import '../../domain/repositories/entry_repository.dart';
import '../../services/biometric_service.dart';
import '../../services/image_service.dart';
import '../../services/location_service.dart';
import '../../services/maps_launcher_service.dart';
import '../../services/media_storage_service.dart';
import '../../services/permission_service.dart';
import '../../services/preferences_service.dart';
import '../../services/speech_service.dart';

/// Contenedor de dependencias de la app (inyección de dependencias manual).
///
/// Se construye una sola vez en `main()` y se comparte con [DependencyScope].
/// Las pantallas piden lo que necesitan con `DependencyScope.of(context)` en
/// lugar de crear servicios por su cuenta, lo que facilita sustituirlos por
/// versiones falsas en pruebas.
class AppDependencies {
  AppDependencies({
    required this.entries,
    required this.media,
    required this.permissions,
    required this.biometrics,
    required this.location,
    required this.speech,
    required this.images,
    required this.preferences,
    required this.maps,
  });

  /// Arma el grafo de dependencias de producción.
  factory AppDependencies.production() {
    final media = MediaStorageService();
    return AppDependencies(
      entries: SqliteEntryRepository(DatabaseHelper(), media),
      media: media,
      permissions: PermissionService(),
      biometrics: BiometricService(),
      location: LocationService(),
      speech: SpeechService(),
      images: ImageService(media),
      preferences: PreferencesService(SharedPreferencesAsync()),
      maps: MapsLauncherService(),
    );
  }

  final EntryRepository entries;
  final MediaStorageService media;
  final PermissionService permissions;
  final BiometricService biometrics;
  final LocationService location;
  final SpeechService speech;
  final ImageService images;
  final PreferencesService preferences;
  final MapsLauncherService maps;
}

/// Hace disponibles las [AppDependencies] en todo el árbol de widgets.
class DependencyScope extends InheritedWidget {
  const DependencyScope({super.key, required this.dependencies, required super.child});

  final AppDependencies dependencies;

  static AppDependencies of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<DependencyScope>();
    assert(scope != null, 'No hay DependencyScope arriba en el árbol');
    return scope!.dependencies;
  }

  @override
  bool updateShouldNotify(DependencyScope oldWidget) => dependencies != oldWidget.dependencies;
}
