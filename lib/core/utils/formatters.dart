import 'package:intl/intl.dart';

/// Formatos de fecha en español usados en toda la interfaz.
abstract final class Formatters {
  static final _longDate = DateFormat("EEEE d 'de' MMMM 'de' y", 'es');
  static final _shortDate = DateFormat("d MMM y", 'es');
  static final _time = DateFormat('HH:mm', 'es');

  /// "sábado 14 de noviembre de 2026"
  static String longDate(DateTime d) => _longDate.format(d);

  /// "14 nov 2026"
  static String shortDate(DateTime d) => _shortDate.format(d);

  /// "18:42"
  static String time(DateTime d) => _time.format(d);

  /// "01:05" a partir de una duración.
  static String duration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
