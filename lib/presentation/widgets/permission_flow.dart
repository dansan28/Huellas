import 'package:flutter/material.dart';

import '../../core/di/app_dependencies.dart';
import '../../services/permission_service.dart';
import 'state_views.dart';

/// Flujo completo y amable para obtener un permiso.
///
/// 1. Si ya está concedido, continúa sin molestar.
/// 2. Si no, primero explica para qué se usa (diálogo propio) y luego
///    muestra el diálogo del sistema.
/// 3. Si el usuario lo negó permanentemente, ofrece abrir los ajustes.
/// 4. Si lo negó esta vez, informa qué función quedará desactivada.
///
/// Regresa `true` solo si el permiso quedó concedido. Nunca lanza excepción:
/// negar un permiso jamás debe cerrar la app.
Future<bool> ensurePermission(BuildContext context, AppPermission permission) async {
  final service = DependencyScope.of(context).permissions;
  try {
    var outcome = await service.check(permission);
    if (outcome == PermissionOutcome.granted) return true;
    if (!context.mounted) return false;

    if (outcome == PermissionOutcome.denied) {
      final accepted = await _showRationale(context, permission);
      if (!accepted) {
        if (context.mounted) {
          context.showSnack('Sin permiso de ${permission.label} no podrás ${permission.purpose}.');
        }
        return false;
      }
      outcome = await service.request(permission);
    }

    if (outcome == PermissionOutcome.granted) return true;
    if (!context.mounted) return false;

    if (outcome == PermissionOutcome.permanentlyDenied) {
      await _showOpenSettings(context, permission, service);
    } else {
      context.showSnack('Permiso de ${permission.label} denegado. Puedes seguir usando la app sin esta función.');
    }
    return false;
  } catch (e) {
    if (context.mounted) {
      context.showSnack('No se pudo verificar el permiso de ${permission.label}.', isError: true);
    }
    return false;
  }
}

IconData _iconFor(AppPermission p) => switch (p) {
      AppPermission.camera => Icons.photo_camera_outlined,
      AppPermission.microphone => Icons.mic_none,
      AppPermission.location => Icons.location_on_outlined,
    };

Future<bool> _showRationale(BuildContext context, AppPermission permission) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(_iconFor(permission)),
      title: Text('Permitir ${permission.label}'),
      content: Text('Huellas usa tu ${permission.label} para ${permission.purpose}. '
          'Puedes cambiar esto cuando quieras desde los ajustes del teléfono.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Ahora no')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continuar')),
      ],
    ),
  );
  return result ?? false;
}

Future<void> _showOpenSettings(
  BuildContext context,
  AppPermission permission,
  PermissionService service,
) async {
  final open = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(_iconFor(permission)),
      title: Text('Permiso de ${permission.label} bloqueado'),
      content: Text('Negaste este permiso de forma permanente. Para ${permission.purpose}, '
          'actívalo en Ajustes > Aplicaciones > Huellas > Permisos.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton.icon(
          onPressed: () => Navigator.pop(ctx, true),
          icon: const Icon(Icons.settings_outlined),
          label: const Text('Abrir ajustes'),
        ),
      ],
    ),
  );
  if (open == true) await service.openSettings();
}
