import 'package:url_launcher/url_launcher.dart';

import '../core/errors/app_exceptions.dart';
import '../data/models/entry_location.dart';

/// Abre una ubicación guardada en Google Maps (app o navegador).
class MapsLauncherService {
  /// URL universal de Google Maps: abre la app si está instalada y, si no,
  /// el navegador.
  Uri googleMapsUri(EntryLocation location) => Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': '${location.latitude},${location.longitude}',
      });

  Future<void> openInGoogleMaps(EntryLocation location) async {
    try {
      final ok = await launchUrl(googleMapsUri(location), mode: LaunchMode.externalApplication);
      if (!ok) throw const MediaException('No hay una app para abrir mapas.');
    } on AppException {
      rethrow;
    } catch (e) {
      throw MediaException('No se pudo abrir Google Maps.', cause: e);
    }
  }
}
