import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/di/app_dependencies.dart';
import 'core/routes/app_routes.dart';

/// Punto de entrada de Huellas.
///
/// 1. Instala manejadores globales de errores para que un fallo inesperado
///    se registre en lugar de cerrar la app.
/// 2. Construye las dependencias (repositorio SQLite y servicios).
/// 3. Decide la ruta inicial según la preferencia de biometría.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Errores dentro del framework (build, layout, pintado).
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };
  // Errores asíncronos no capturados (Futures, plugins nativos).
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Error no capturado: $error\n$stack');
    return true; // marcado como manejado: la app sigue viva
  };
  // En lugar de la "pantalla roja", un mensaje amable si un widget falla.
  ErrorWidget.builder = (details) => const Material(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Algo salió mal al mostrar esta sección.', textAlign: TextAlign.center),
          ),
        ),
      );

  await initializeDateFormatting('es');

  final dependencies = AppDependencies.production();

  var biometricEnabled = true;
  try {
    biometricEnabled = await dependencies.preferences.isBiometricEnabled();
  } catch (e) {
    debugPrint('No se pudo leer preferencias, se usa el valor seguro: $e');
  }

  runApp(DependencyScope(
    dependencies: dependencies,
    child: HuellasApp(initialRoute: biometricEnabled ? AppRoutes.login : AppRoutes.home),
  ));
}
