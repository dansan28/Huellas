import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/di/app_dependencies.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/routes/app_routes.dart';
import '../widgets/app_drawer.dart';
import '../widgets/state_views.dart';

/// Ajustes: protección biométrica, respaldo JSON y permisos.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<bool> _biometricFuture;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _biometricFuture = DependencyScope.of(context).preferences.isBiometricEnabled();
  }

  /// Activar o desactivar la protección exige autenticarse: así nadie que
  /// tome el teléfono desbloqueado puede quitarla.
  Future<void> _toggleBiometric(bool value) async {
    final deps = DependencyScope.of(context);
    setState(() => _busy = true);
    final result = await deps.biometrics.authenticate(
      reason: value ? 'Confirma para proteger tu diario' : 'Confirma para quitar la protección',
    );
    if (!mounted) return;
    if (result.isSuccess) {
      await deps.preferences.setBiometricEnabled(value);
      if (!mounted) return;
      setState(() {
        _biometricFuture = Future.value(value);
      });
      context.showSnack(value ? 'Diario protegido con biometría' : 'Protección desactivada');
    } else {
      context.showSnack(result.message, isError: true);
    }
    setState(() => _busy = false);
  }

  /// Serializa todo el diario a JSON y lo copia al portapapeles.
  Future<void> _exportJson() async {
    try {
      final entries = await DependencyScope.of(context).entries.getAll();
      final json = const JsonEncoder.withIndent('  ').convert({
        'app': 'Huellas',
        'exportedAt': DateTime.now().toIso8601String(),
        'entries': entries.map((e) => e.toJson()).toList(),
      });
      await Clipboard.setData(ClipboardData(text: json));
      if (mounted) context.showSnack('${entries.length} entradas copiadas como JSON al portapapeles');
    } on AppException catch (e) {
      if (mounted) context.showSnack(e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final deps = DependencyScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      drawer: const AppDrawer(currentRoute: AppRoutes.settings),
      body: ListView(
        children: [
          const _Header('Seguridad'),
          FutureBuilder<bool>(
            future: _biometricFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const ListTile(
                  leading: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                  title: Text('Cargando preferencia…'),
                );
              }
              return SwitchListTile(
                secondary: const Icon(Icons.fingerprint),
                title: const Text('Proteger con biometría'),
                subtitle: const Text('Pide huella, rostro o PIN al abrir la app'),
                value: snapshot.data!,
                onChanged: _busy ? null : _toggleBiometric,
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.admin_panel_settings_outlined),
            title: const Text('Permisos de la app'),
            subtitle: const Text('Cámara, micrófono y ubicación'),
            trailing: const Icon(Icons.open_in_new),
            onTap: deps.permissions.openSettings,
          ),
          const _Header('Datos'),
          ListTile(
            leading: const Icon(Icons.data_object),
            title: const Text('Exportar diario (JSON)'),
            subtitle: const Text('Copia un respaldo de tus entradas al portapapeles'),
            onTap: _exportJson,
          ),
          const _Header('Acerca de'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Huellas'),
            subtitle: const Text('Diario de viajes geolocalizado · v1.0.0'),
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'Huellas',
              applicationVersion: '1.0.0',
              applicationIcon: const Icon(Icons.travel_explore, size: 40),
              children: const [
                Text('Proyecto del Parcial 2 de Programación de Dispositivos Móviles. '
                    'Guarda tus recuerdos de viaje con foto, voz y ubicación, todo en tu teléfono.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(text,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary)),
    );
  }
}
