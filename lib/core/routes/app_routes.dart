import 'package:flutter/material.dart';

import '../../data/models/travel_entry.dart';
import '../../presentation/screens/entry_detail_screen.dart';
import '../../presentation/screens/entry_form_screen.dart';
import '../../presentation/screens/entry_list_screen.dart';
import '../../presentation/screens/login_screen.dart';
import '../../presentation/screens/photo_viewer_screen.dart';
import '../../presentation/screens/settings_screen.dart';
import '../../presentation/screens/travel_map_screen.dart';

/// Rutas con nombre de la app y su generador.
///
/// Centralizar los nombres evita errores de dedo con cadenas sueltas y
/// [onGenerateRoute] valida los argumentos de cada pantalla.
abstract final class AppRoutes {
  static const login = '/login';
  static const home = '/home';
  static const entryForm = '/entry/form';
  static const entryDetail = '/entry/detail';
  static const photoViewer = '/entry/photo';
  static const travelMap = '/map';
  static const settings = '/settings';

  /// Observador que permite a la lista recargarse al volver a ella.
  static final RouteObserver<ModalRoute<void>> observer = RouteObserver<ModalRoute<void>>();

  /// Ruta inicial única: evita que Flutter apile "/" debajo de la ruta
  /// inicial (comportamiento por defecto con nombres que empiezan con "/").
  static List<Route<dynamic>> initialRoutes(String initialRoute) => [
        onGenerateRoute(RouteSettings(name: initialRoute)),
      ];

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final args = settings.arguments;
    switch (settings.name) {
      case login:
        return _fade(settings, const LoginScreen());
      case home:
        return MaterialPageRoute(settings: settings, builder: (_) => const EntryListScreen());
      case entryForm:
        // null = nueva entrada; TravelEntry = edición.
        return _slideUp(settings, EntryFormScreen(initialEntry: args is TravelEntry ? args : null));
      case entryDetail:
        if (args is! TravelEntry) return _notFound(settings);
        return MaterialPageRoute(settings: settings, builder: (_) => EntryDetailScreen(entry: args));
      case photoViewer:
        if (args is! TravelEntry) return _notFound(settings);
        return _fade(settings, PhotoViewerScreen(entry: args));
      case travelMap:
        return MaterialPageRoute(settings: settings, builder: (_) => const TravelMapScreen());
      case AppRoutes.settings: // calificado: el parámetro también se llama settings
        return MaterialPageRoute(settings: settings, builder: (_) => const SettingsScreen());
      default:
        return _notFound(settings);
    }
  }

  /// Transición del formulario: sube desde abajo con desvanecimiento.
  static Route<T> _slideUp<T>(RouteSettings settings, Widget page) => PageRouteBuilder<T>(
        settings: settings,
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, _, _) => page,
        transitionsBuilder: (_, animation, _, child) {
          final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return SlideTransition(
            position: Tween(begin: const Offset(0, 0.12), end: Offset.zero).animate(curved),
            child: FadeTransition(opacity: curved, child: child),
          );
        },
      );

  static Route<T> _fade<T>(RouteSettings settings, Widget page) => PageRouteBuilder<T>(
        settings: settings,
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, _, _) => page,
        transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
      );

  static Route<dynamic> _notFound(RouteSettings settings) => MaterialPageRoute(
        settings: settings,
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Página no encontrada')),
          body: Center(child: Text('No existe la ruta "${settings.name}"')),
        ),
      );
}
