import 'package:shared_preferences/shared_preferences.dart';

/// Ajustes simples del usuario guardados con SharedPreferences.
///
/// SharedPreferences se usa SOLO para preferencias clave-valor. Los registros
/// del diario viven en SQLite, que es la herramienta adecuada para datos
/// estructurados que crecen.
class PreferencesService {
  PreferencesService(this._prefs);

  final SharedPreferencesAsync _prefs;

  static const _kBiometricEnabled = 'biometric_enabled';
  static const _kLastTrip = 'last_trip_name';

  /// Si el diario está protegido con biometría (activado por defecto).
  Future<bool> isBiometricEnabled() async =>
      await _prefs.getBool(_kBiometricEnabled) ?? true;

  Future<void> setBiometricEnabled(bool value) => _prefs.setBool(_kBiometricEnabled, value);

  /// Último viaje usado, para precargarlo en la siguiente entrada.
  Future<String?> lastTripName() => _prefs.getString(_kLastTrip);

  Future<void> setLastTripName(String value) => _prefs.setString(_kLastTrip, value);
}
