import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../core/errors/app_exceptions.dart' hide PermissionDeniedException;
import '../data/models/entry_location.dart';

/// Obtiene la posición GPS actual y el nombre del lugar.
///
/// Estrategia para que el GPS nunca deje al usuario esperando sin respuesta:
/// 1. Verifica que el GPS esté encendido (si no, error claro).
/// 2. Pide una posición precisa con límite de tiempo ([gpsTimeout]).
/// 3. Si se agota el tiempo, usa la última posición conocida y la marca
///    como aproximada.
/// 4. La geocodificación inversa (ciudad, país) es opcional: si no hay
///    internet, se guardan solo las coordenadas.
class LocationService {
  LocationService({
    this.gpsTimeout = const Duration(seconds: 15),
    this.geocodeTimeout = const Duration(seconds: 6),
  });

  final Duration gpsTimeout;
  final Duration geocodeTimeout;
  /// Se crea al primer uso (no al construir el servicio).
  late final Geocoding _geocoding = Geocoding();

  /// Abre los ajustes de ubicación del sistema (para encender el GPS).
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  /// Captura la ubicación actual. Lanza [LocationException] si no es posible.
  /// El permiso debe solicitarse antes con `PermissionService`.
  Future<EntryLocation> getCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(
        'El GPS está apagado. Actívalo para guardar dónde estás.',
        serviceDisabled: true,
      );
    }

    Position? position;
    var approximate = false;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: gpsTimeout,
        ),
      );
    } on TimeoutException {
      debugPrint('GPS sin respuesta en ${gpsTimeout.inSeconds}s; usando última posición');
      position = await _lastKnown();
      approximate = true;
    } on LocationServiceDisabledException catch (e) {
      throw LocationException('El GPS está apagado.', serviceDisabled: true, cause: e);
    } on PermissionDeniedException catch (e) {
      throw LocationException('No hay permiso de ubicación.', cause: e);
    } catch (e) {
      debugPrint('Error de GPS: $e');
      position = await _lastKnown();
      approximate = true;
    }

    if (position == null) {
      throw const LocationException(
        'No se pudo obtener tu ubicación. Intenta al aire libre o cerca de una ventana.',
      );
    }

    final location = EntryLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      capturedAt: position.timestamp,
      isApproximate: approximate,
    );
    return location.copyWith(placeName: await placeNameFor(location));
  }

  /// "Ciudad, País" para unas coordenadas, o `null` si no se puede obtener.
  Future<String?> placeNameFor(EntryLocation location) async {
    try {
      final marks = await _geocoding
          .placemarkFromCoordinates(location.latitude, location.longitude)
          .timeout(geocodeTimeout);
      if (marks.isEmpty) return null;
      final m = marks.first;
      final parts = <String?>[
        m.locality?.isNotEmpty == true ? m.locality : m.subAdministrativeArea,
        m.administrativeArea,
        m.country,
      ].where((s) => s != null && s.trim().isNotEmpty).cast<String>().toSet().toList();
      return parts.isEmpty ? null : parts.join(', ');
    } catch (e) {
      // Sin internet o servicio no disponible: no es un error crítico.
      debugPrint('Geocodificación no disponible: $e');
      return null;
    }
  }

  Future<Position?> _lastKnown() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }
}
