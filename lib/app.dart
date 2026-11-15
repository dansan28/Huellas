import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';

/// Widget raíz: tema, idioma y sistema de rutas con nombre.
class HuellasApp extends StatelessWidget {
  const HuellasApp({super.key, required this.initialRoute});

  /// [AppRoutes.login] si la protección biométrica está activa,
  /// [AppRoutes.home] si no.
  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Huellas',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      locale: const Locale('es', 'MX'),
      supportedLocales: const [Locale('es', 'MX'), Locale('es'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      initialRoute: initialRoute,
      onGenerateInitialRoutes: AppRoutes.initialRoutes,
      onGenerateRoute: AppRoutes.onGenerateRoute,
      navigatorObservers: [AppRoutes.observer],
    );
  }
}
