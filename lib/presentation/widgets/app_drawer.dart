import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';

/// Menú lateral compartido por las pantallas principales.
///
/// Resalta la sección actual ([currentRoute]) para que el usuario siempre
/// sepa dónde está, y navega sin ensuciar la pila:
/// * "Mis entradas" regresa a la lista en lugar de apilarla otra vez.
/// * Entre secciones secundarias se usa `pushReplacementNamed`.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.currentRoute});

  final String currentRoute;

  void _go(BuildContext context, String route) {
    // Se obtiene el Navigator antes de cerrar el drawer: después, este
    // context empieza a desmontarse y ya no es seguro usarlo.
    final nav = Navigator.of(context);
    nav.pop(); // cierra el drawer
    if (route == currentRoute) return;
    if (route == AppRoutes.home) {
      nav.popUntil(ModalRoute.withName(AppRoutes.home));
    } else if (currentRoute == AppRoutes.home || route == AppRoutes.entryForm) {
      nav.pushNamed(route);
    } else {
      nav.pushReplacementNamed(route);
    }
  }

  void _lock(BuildContext context) {
    final nav = Navigator.of(context);
    nav.pop();
    nav.pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return NavigationDrawer(
      selectedIndex: switch (currentRoute) {
        AppRoutes.home => 0,
        AppRoutes.travelMap => 2,
        AppRoutes.settings => 3,
        _ => null,
      },
      onDestinationSelected: (i) => _go(context, const [
        AppRoutes.home,
        AppRoutes.entryForm,
        AppRoutes.travelMap,
        AppRoutes.settings,
      ][i]),
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [AppTheme.seed, Color(0xFF14A098)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.travel_explore, color: Colors.white, size: 40),
              const SizedBox(height: 12),
              Text('Huellas',
                  style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
              Text('Tu diario de viajes',
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70)),
            ],
          ),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.auto_stories_outlined),
          selectedIcon: Icon(Icons.auto_stories),
          label: Text('Mis entradas'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.add_location_alt_outlined),
          label: Text('Nueva entrada'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.map_outlined),
          selectedIcon: Icon(Icons.map),
          label: Text('Mapa de viajes'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: Text('Ajustes'),
        ),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 28, vertical: 8), child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            leading: const Icon(Icons.lock_outline),
            title: const Text('Bloquear diario'),
            onTap: () => _lock(context),
          ),
        ),
      ],
    );
  }
}
