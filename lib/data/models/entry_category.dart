import 'package:flutter/material.dart';

/// Categoría de una entrada del diario de viaje.
///
/// Se guarda en SQLite por su [name] (texto estable), no por su índice, para
/// que reordenar el enum en el futuro no corrompa los datos guardados.
enum EntryCategory {
  paisaje('Paisaje', Icons.landscape_outlined),
  comida('Comida', Icons.restaurant_outlined),
  alojamiento('Alojamiento', Icons.hotel_outlined),
  actividad('Actividad', Icons.hiking_outlined),
  transporte('Transporte', Icons.directions_bus_outlined),
  cultura('Cultura', Icons.museum_outlined),
  otro('Otro', Icons.push_pin_outlined);

  const EntryCategory(this.label, this.icon);

  /// Texto visible en la interfaz.
  final String label;

  /// Icono representativo.
  final IconData icon;

  /// Convierte el texto guardado en la base de datos a la categoría.
  /// Si el valor no se reconoce, regresa [EntryCategory.otro] en lugar de fallar.
  static EntryCategory fromName(String? name) => EntryCategory.values.firstWhere(
        (c) => c.name == name,
        orElse: () => EntryCategory.otro,
      );
}
