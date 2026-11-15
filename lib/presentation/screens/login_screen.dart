import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/di/app_dependencies.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../services/biometric_service.dart';

/// Pantalla de desbloqueo con biometría (huella / rostro / PIN del sistema).
///
/// El diario guarda dónde has estado y dónde te hospedas; por eso se protege
/// con la autenticación del sistema operativo. Al entrar se usa
/// `pushReplacementNamed`, así el botón "atrás" nunca regresa al login.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _authenticating = false;
  BiometricResult? _lastResult;
  bool _hasFace = false;

  @override
  void initState() {
    super.initState();
    // Lanza el diálogo biométrico en cuanto la pantalla termina de dibujarse.
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final types = await DependencyScope.of(context).biometrics.availableBiometrics();
    if (mounted) setState(() => _hasFace = types.contains(BiometricType.face));
    await _authenticate();
  }

  Future<void> _authenticate() async {
    if (_authenticating) return;
    setState(() => _authenticating = true);
    final result = await DependencyScope.of(context).biometrics.authenticate();
    if (!mounted) return;
    setState(() {
      _authenticating = false;
      _lastResult = result;
    });
    if (result.isSuccess) _enter();
  }

  void _enter() => Navigator.of(context).pushReplacementNamed(AppRoutes.home);

  /// Sin bloqueo de pantalla configurado no hay nada contra qué autenticar;
  /// se permite entrar avisando del riesgo en lugar de dejar al usuario fuera.
  bool get _canBypass => switch (_lastResult?.status) {
        BiometricStatus.notConfigured || BiometricStatus.unsupported => true,
        _ => false,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = _lastResult;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.seed, Color(0xFF0E4F5C)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                const Spacer(flex: 2),
                const Icon(Icons.travel_explore, size: 88, color: Colors.white),
                const SizedBox(height: 16),
                Text('Huellas',
                    style: theme.textTheme.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('Tu diario de viajes, solo para ti',
                    style: theme.textTheme.titleMedium?.copyWith(color: Colors.white70)),
                const Spacer(flex: 2),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _authenticating
                      ? const SizedBox(
                          key: ValueKey('loading'),
                          height: 88,
                          child: Center(child: CircularProgressIndicator(color: Colors.white)),
                        )
                      : InkResponse(
                          key: const ValueKey('button'),
                          onTap: _authenticate,
                          radius: 56,
                          child: Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white54, width: 2),
                            ),
                            child: Icon(_hasFace ? Icons.face_unlock_outlined : Icons.fingerprint,
                                size: 52, color: Colors.white),
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                Text(
                  result == null || result.isSuccess ? 'Toca para desbloquear' : result.message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
                ),
                const Spacer(),
                if (_canBypass)
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    onPressed: _enter,
                    icon: const Icon(Icons.warning_amber_rounded),
                    label: const Text('Entrar sin protección (configura un bloqueo de pantalla)'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
