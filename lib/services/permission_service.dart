import 'package:permission_handler/permission_handler.dart';

/// Permisos del dispositivo que usa la app.
enum AppPermission {
  camera('cámara', 'tomar fotos de tu viaje'),
  microphone('micrófono', 'dictar tus entradas y grabar notas de voz'),
  location('ubicación', 'guardar dónde escribiste cada entrada');

  const AppPermission(this.label, this.purpose);

  /// Nombre legible del permiso.
  final String label;

  /// Para qué lo usa la app (se muestra al explicar por qué se pide).
  final String purpose;

  Permission get _native => switch (this) {
        AppPermission.camera => Permission.camera,
        AppPermission.microphone => Permission.microphone,
        AppPermission.location => Permission.locationWhenInUse,
      };
}

/// Resultado simplificado de pedir un permiso.
enum PermissionOutcome {
  /// Concedido (o concedido de forma limitada).
  granted,

  /// Negado esta vez; se puede volver a pedir.
  denied,

  /// Negado permanentemente ("No volver a preguntar"): solo se puede
  /// conceder desde los ajustes del sistema.
  permanentlyDenied,
}

/// Punto único para consultar y solicitar permisos (Responsabilidad Única).
///
/// Las pantallas no usan `permission_handler` directamente; así el manejo de
/// "permiso negado" es consistente en toda la app.
class PermissionService {
  /// Consulta el estado sin mostrar diálogos.
  Future<PermissionOutcome> check(AppPermission permission) async {
    final status = await permission._native.status;
    return _map(status);
  }

  /// Solicita el permiso (muestra el diálogo del sistema si aún es posible).
  Future<PermissionOutcome> request(AppPermission permission) async {
    final current = await permission._native.status;
    if (current.isGranted || current.isLimited) return PermissionOutcome.granted;
    if (current.isPermanentlyDenied || current.isRestricted) {
      return PermissionOutcome.permanentlyDenied;
    }
    return _map(await permission._native.request());
  }

  /// Abre la pantalla de ajustes de la app en el sistema operativo.
  Future<bool> openSettings() => openAppSettings();

  PermissionOutcome _map(PermissionStatus status) {
    if (status.isGranted || status.isLimited) return PermissionOutcome.granted;
    if (status.isPermanentlyDenied || status.isRestricted) {
      return PermissionOutcome.permanentlyDenied;
    }
    return PermissionOutcome.denied;
  }
}
