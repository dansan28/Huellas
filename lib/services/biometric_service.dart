import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Resultado de un intento de autenticación.
enum BiometricStatus {
  /// El usuario se autenticó correctamente.
  success,

  /// El usuario canceló o la huella/rostro no coincidió.
  failed,

  /// El teléfono no tiene bloqueo de pantalla ni biometría configurados.
  notConfigured,

  /// El hardware no es compatible con autenticación local.
  unsupported,

  /// Demasiados intentos fallidos; el sistema bloqueó temporalmente la biometría.
  lockedOut,

  /// Otro error inesperado.
  error,
}

/// Resultado con el mensaje que se le muestra al usuario.
class BiometricResult {
  const BiometricResult(this.status, this.message);
  final BiometricStatus status;
  final String message;
  bool get isSuccess => status == BiometricStatus.success;
}

/// Envuelve `local_auth` para el login biométrico.
///
/// Se permite el respaldo con PIN/patrón del dispositivo (`biometricOnly:
/// false`): sigue siendo seguro porque lo valida el sistema operativo, y
/// evita que el usuario quede fuera de su diario si falla el sensor.
class BiometricService {
  BiometricService([LocalAuthentication? auth]) : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  /// `true` si el dispositivo soporta autenticación local (biometría o PIN).
  Future<bool> isSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (e) {
      debugPrint('isDeviceSupported falló: $e');
      return false;
    }
  }

  /// Tipos de biometría registrados (huella, rostro…), para adaptar el icono.
  Future<List<BiometricType>> availableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return const [];
    }
  }

  /// Muestra el diálogo del sistema y regresa el resultado.
  Future<BiometricResult> authenticate({
    String reason = 'Desbloquea tu diario de viajes',
  }) async {
    try {
      if (!await isSupported()) {
        return const BiometricResult(
          BiometricStatus.unsupported,
          'Este teléfono no permite autenticación biométrica.',
        );
      }
      final ok = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      return ok
          ? const BiometricResult(BiometricStatus.success, 'Bienvenido de vuelta')
          : const BiometricResult(BiometricStatus.failed, 'No se pudo verificar tu identidad.');
    } on LocalAuthException catch (e) {
      debugPrint('LocalAuthException: ${e.code} ${e.description}');
      return _fromCode(e.code);
    } on PlatformException catch (e) {
      debugPrint('PlatformException biométrica: $e');
      return BiometricResult(BiometricStatus.error, 'Error de autenticación: ${e.message ?? e.code}');
    } catch (e) {
      debugPrint('Error biométrico: $e');
      return const BiometricResult(BiometricStatus.error, 'Ocurrió un error al autenticar.');
    }
  }

  BiometricResult _fromCode(LocalAuthExceptionCode code) {
    return switch (code) {
      LocalAuthExceptionCode.userCanceled ||
      LocalAuthExceptionCode.systemCanceled ||
      LocalAuthExceptionCode.timeout =>
        const BiometricResult(BiometricStatus.failed, 'Autenticación cancelada.'),
      LocalAuthExceptionCode.noCredentialsSet ||
      LocalAuthExceptionCode.noBiometricsEnrolled =>
        const BiometricResult(
          BiometricStatus.notConfigured,
          'Tu teléfono no tiene bloqueo de pantalla ni huella configurados.',
        ),
      LocalAuthExceptionCode.noBiometricHardware =>
        const BiometricResult(BiometricStatus.unsupported, 'Este teléfono no tiene sensor biométrico.'),
      LocalAuthExceptionCode.temporaryLockout || LocalAuthExceptionCode.biometricLockout =>
        const BiometricResult(
          BiometricStatus.lockedOut,
          'Demasiados intentos. Espera un momento o usa tu PIN.',
        ),
      _ => BiometricResult(BiometricStatus.error, 'No se pudo autenticar (${code.name}).'),
    };
  }
}
