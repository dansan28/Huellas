import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';

/// Capa de teselas de OpenStreetMap (no requiere clave de API).
TileLayer osmTileLayer() => TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'mx.edu.anahuac.huellas',
    );

/// Atribución obligatoria de OpenStreetMap.
Widget osmAttribution() => RichAttributionWidget(
      attributions: [
        TextSourceAttribution(
          'OpenStreetMap contributors',
          onTap: () => launchUrl(Uri.parse('https://openstreetmap.org/copyright')),
        ),
      ],
    );

/// Pin de mapa de la marca.
class MapPin extends StatelessWidget {
  const MapPin({super.key, this.label});
  final String? label;

  @override
  Widget build(BuildContext context) {
    if (label == null) {
      return const Icon(Icons.location_on, color: AppTheme.accent, size: 44,
          shadows: [Shadow(blurRadius: 6, color: Colors.black38)]);
    }
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.accent,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
      ),
      child: Text(label!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }
}

/// Mapa interactivo (zoom y desplazamiento) centrado en una ubicación.
class LocationMap extends StatelessWidget {
  const LocationMap({super.key, required this.latitude, required this.longitude, this.height = 220});

  final double latitude;
  final double longitude;
  final double height;

  @override
  Widget build(BuildContext context) {
    final point = LatLng(latitude, longitude);
    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: point,
            initialZoom: 15,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            osmTileLayer(),
            MarkerLayer(markers: [
              Marker(point: point, width: 44, height: 44, alignment: Alignment.topCenter, child: const MapPin()),
            ]),
            osmAttribution(),
          ],
        ),
      ),
    );
  }
}
