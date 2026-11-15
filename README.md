# Huellas — Diario de viajes geolocalizado

App Flutter para guardar recuerdos de viaje con **foto**, **texto dictado por voz**, **nota de voz** y **ubicación GPS**, protegida con **login biométrico** y almacenada localmente en **SQLite**.

Proyecto del Parcial 2 — Programación de Dispositivos Móviles.

## Funcionalidades

| Área | Qué hace |
|---|---|
| Login biométrico | Huella / rostro / PIN del sistema (`local_auth`) antes de mostrar el diario |
| Lista | Entradas por viaje con `FutureBuilder`, filtro por viaje, miniaturas con `Hero` |
| Nueva entrada | Foto con cámara o galería, dictado de voz a texto, nota de voz, categoría |
| GPS | Se captura al guardar; muestra el progreso, tiene límite de tiempo y una ubicación de respaldo |
| Detalle | Foto con `Hero`, mapa interactivo (OpenStreetMap) y botón **Abrir en Google Maps** |
| Mapa de viajes | Todas las entradas unidas en orden cronológico (la ruta del viaje) |
| Ajustes | Activar/desactivar biometría (requiere autenticarse) y exportar el diario en JSON |

## Arquitectura (por capas)

```
lib/
├── main.dart, app.dart        # arranque, manejo global de errores, MaterialApp
├── core/                      # rutas con nombre, tema, excepciones, DI, formatos
├── domain/repositories/       # EntryRepository (interfaz)
├── data/
│   ├── models/                # TravelEntry, EntryLocation, EntryCategory (JSON)
│   ├── datasources/           # DatabaseHelper (sqflite)
│   └── repositories/          # SqliteEntryRepository
├── services/                  # biometría, GPS, voz, cámara, audio, permisos, prefs
└── presentation/
    ├── screens/               # login, lista, formulario, detalle, mapa, ajustes
    └── widgets/               # drawer, tarjetas, grabador, mapa, flujos de permiso
```

## Ejecutar

Requisitos: Flutter 3.47+ y un teléfono Android 7.0 (API 24) o superior con depuración USB.

```bash
flutter pub get
flutter run
```

Para generar el APK:

```bash
flutter build apk --release
```

> El dictado usa el reconocedor de voz de Google; en algunos teléfonos necesita internet.
> El mapa usa teselas de OpenStreetMap (requiere internet para verse; las coordenadas se guardan sin conexión).

## Pruebas

```bash
flutter test
```

Verifican la serialización de `TravelEntry` y `EntryLocation` hacia SQLite y JSON.
