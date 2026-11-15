import 'package:flutter/material.dart';

import '../../data/models/travel_entry.dart';
import '../widgets/entry_image.dart';

/// Visor de la foto a pantalla completa con zoom (pellizcar para acercar).
/// Comparte la etiqueta Hero con el detalle para una transición continua.
class PhotoViewerScreen extends StatelessWidget {
  const PhotoViewerScreen({super.key, required this.entry});

  final TravelEntry entry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(entry.title, style: const TextStyle(color: Colors.white)),
      ),
      body: InteractiveViewer(
        minScale: 1,
        maxScale: 5,
        child: Center(
          child: Hero(tag: entry.heroTag, child: EntryImage(entry: entry, fit: BoxFit.contain)),
        ),
      ),
    );
  }
}
