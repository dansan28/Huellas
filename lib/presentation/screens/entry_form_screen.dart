import 'package:flutter/material.dart';

import '../../core/di/app_dependencies.dart';
import '../../core/errors/app_exceptions.dart';
import '../../data/models/entry_category.dart';
import '../../data/models/entry_location.dart';
import '../../data/models/travel_entry.dart';
import '../../services/image_service.dart';
import '../../services/permission_service.dart';
import '../widgets/entry_image.dart';
import '../widgets/permission_flow.dart';
import '../widgets/pulsing_mic_button.dart';
import '../widgets/state_views.dart';
import '../widgets/voice_note_recorder.dart';

/// Formulario para crear o editar una entrada.
///
/// Integra los tres gadgets:
/// * Cámara / galería para la foto.
/// * Micrófono: dictado de voz a texto y nota de voz.
/// * GPS: la ubicación se captura al momento de guardar.
///
/// Al cerrar devuelve la entrada guardada con `Navigator.pop(entry)`.
class EntryFormScreen extends StatefulWidget {
  const EntryFormScreen({super.key, this.initialEntry});

  /// `null` para una entrada nueva.
  final TravelEntry? initialEntry;

  @override
  State<EntryFormScreen> createState() => _EntryFormScreenState();
}

class _EntryFormScreenState extends State<EntryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _tripCtrl;
  late final TextEditingController _contentCtrl;

  late EntryCategory _category;
  String? _imagePath;
  String? _audioPath;
  bool _updateLocation = false;

  /// Archivos creados en esta sesión del formulario; si el usuario descarta
  /// los cambios se borran para no dejar basura en el teléfono.
  final Set<String> _createdFiles = {};

  List<String> _knownTrips = const [];
  bool _dirty = false;
  bool _saved = false;
  bool _listening = false;
  bool _recording = false;
  String? _savingStep; // no nulo = guardando (muestra overlay)
  String _dictationBase = '';

  bool get _isEditing => widget.initialEntry != null;

  /// Se guarda en [didChangeDependencies] porque en `dispose` ya no es seguro
  /// consultar el árbol de widgets.
  late AppDependencies _deps;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _deps = DependencyScope.of(context);
  }

  @override
  void initState() {
    super.initState();
    final e = widget.initialEntry;
    _titleCtrl = TextEditingController(text: e?.title);
    _tripCtrl = TextEditingController(text: e?.tripName);
    _contentCtrl = TextEditingController(text: e?.content);
    _category = e?.category ?? EntryCategory.paisaje;
    _imagePath = e?.imagePath;
    _audioPath = e?.audioPath;
    for (final c in [_titleCtrl, _tripCtrl, _contentCtrl]) {
      c.addListener(_markDirty);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSuggestions());
  }

  Future<void> _loadSuggestions() async {
    try {
      final trips = await _deps.entries.getTripNames();
      final last = await _deps.preferences.lastTripName();
      if (!mounted) return;
      setState(() => _knownTrips = trips);
      if (!_isEditing && _tripCtrl.text.isEmpty && last != null) {
        _tripCtrl.text = last;
        _dirty = false;
      }
    } catch (_) {
      // Las sugerencias son opcionales: si fallan, el formulario sigue igual.
    }
  }

  @override
  void dispose() {
    final speech = _deps.speech;
    speech
      ..onError = null
      ..onListeningChanged = null;
    speech.cancel();
    _titleCtrl.dispose();
    _tripCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) _dirty = true;
  }

  // ---------------------------------------------------------------------------
  // Foto (cámara o galería)
  // ---------------------------------------------------------------------------

  Future<void> _pickPhoto(PhotoSource source) async {
    // La galería usa el selector del sistema y no requiere permiso.
    if (source == PhotoSource.camera && !await ensurePermission(context, AppPermission.camera)) {
      return;
    }
    try {
      final path = await _deps.images.pick(source);
      if (path == null || !mounted) return; // el usuario canceló
      setState(() {
        _createdFiles.add(path);
        _imagePath = path;
        _dirty = true;
      });
    } on AppException catch (e) {
      if (mounted) context.showSnack(e.message, isError: true);
    }
  }

  Future<void> _choosePhotoSource() async {
    final source = await showModalBottomSheet<PhotoSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(ctx, PhotoSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(ctx, PhotoSource.gallery),
            ),
            if (_imagePath != null)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Quitar foto'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _imagePath = null;
                    _dirty = true;
                  });
                },
              ),
          ],
        ),
      ),
    );
    if (source != null) await _pickPhoto(source);
  }

  // ---------------------------------------------------------------------------
  // Dictado por voz
  // ---------------------------------------------------------------------------

  Future<void> _toggleDictation() async {
    final speech = _deps.speech;
    if (_listening) {
      await speech.stop();
      setState(() => _listening = false);
      return;
    }
    if (!await ensurePermission(context, AppPermission.microphone)) return;

    speech
      ..onError = (msg) {
        if (mounted) context.showSnack(msg, isError: true);
      }
      ..onListeningChanged = (listening) {
        if (mounted && _listening != listening) setState(() => _listening = listening);
      };

    // El texto dictado se agrega al final de lo que ya estaba escrito.
    _dictationBase = _contentCtrl.text.trimRight();
    try {
      setState(() => _listening = true);
      await speech.start(onText: (text, _) {
        if (!mounted) return;
        final joined = _dictationBase.isEmpty ? text : '$_dictationBase $text';
        _contentCtrl.value = TextEditingValue(
          text: joined,
          selection: TextSelection.collapsed(offset: joined.length),
        );
      });
    } on AppException catch (e) {
      if (mounted) {
        setState(() => _listening = false);
        context.showSnack(e.message, isError: true);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Guardado (con captura de GPS)
  // ---------------------------------------------------------------------------

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_recording) {
      context.showSnack('Detén la grabación de la nota de voz antes de guardar.');
      return;
    }
    if (_listening) {
      await _deps.speech.stop();
      if (!mounted) return;
      setState(() => _listening = false);
    }

    final original = widget.initialEntry;
    EntryLocation? location = original?.location;

    // 1. Ubicación GPS (siempre en entradas nuevas; opcional al editar).
    if (!_isEditing || _updateLocation) {
      setState(() => _savingStep = 'Obteniendo tu ubicación GPS…');
      final outcome = await _captureLocation();
      if (!mounted) return;
      if (outcome.cancelled) {
        setState(() => _savingStep = null);
        return;
      }
      location = outcome.location ?? (_isEditing ? original?.location : null);
    }

    // 2. Persistencia en SQLite.
    setState(() => _savingStep = 'Guardando entrada…');
    final now = DateTime.now();
    final draft = TravelEntry(
      id: original?.id,
      title: _titleCtrl.text.trim(),
      content: _contentCtrl.text.trim(),
      tripName: _tripCtrl.text.trim(),
      category: _category,
      imagePath: _imagePath,
      audioPath: _audioPath,
      location: location,
      createdAt: original?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      final repo = _deps.entries;
      final saved = _isEditing ? await repo.update(draft) : await repo.create(draft);
      await _deps.preferences.setLastTripName(saved.tripName);
      await _cleanupAfterSave(saved);
      _saved = true;
      if (!mounted) return;
      context.showSnack(_isEditing ? 'Cambios guardados' : 'Entrada guardada en tu diario');
      Navigator.pop(context, saved);
    } on AppException catch (e) {
      if (mounted) context.showSnack(e.message, isError: true);
    } finally {
      if (mounted && !_saved) setState(() => _savingStep = null);
    }
  }

  /// Obtiene la ubicación manejando permisos, GPS apagado y tiempos de espera.
  /// El usuario decide si reintentar, guardar sin ubicación o cancelar.
  Future<_LocationOutcome> _captureLocation() async {
    while (true) {
      if (!mounted) return const _LocationOutcome.cancelled();
      final granted = await ensurePermission(context, AppPermission.location);
      if (!mounted) return const _LocationOutcome.cancelled();
      if (!granted) {
        return await _askSaveWithout('No tenemos permiso para usar tu ubicación.')
            ? const _LocationOutcome.none()
            : const _LocationOutcome.cancelled();
      }
      try {
        final loc = await _deps.location.getCurrentLocation();
        if (mounted && loc.isApproximate) {
          context.showSnack('El GPS tardó demasiado: se usó tu última ubicación conocida.');
        }
        return _LocationOutcome.found(loc);
      } on LocationException catch (e) {
        if (!mounted) return const _LocationOutcome.cancelled();
        final choice = await _locationErrorDialog(e);
        switch (choice) {
          case _LocationChoice.retry:
            continue;
          case _LocationChoice.openSettings:
            await _deps.location.openLocationSettings();
            if (!mounted) return const _LocationOutcome.cancelled();
            continue;
          case _LocationChoice.saveWithout:
            return const _LocationOutcome.none();
          case _LocationChoice.cancel || null:
            return const _LocationOutcome.cancelled();
        }
      }
    }
  }

  Future<bool> _askSaveWithout(String reason) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.location_off_outlined),
        title: const Text('Sin ubicación'),
        content: Text('$reason ¿Quieres guardar la entrada sin ubicación?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar sin ubicación')),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<_LocationChoice?> _locationErrorDialog(LocationException e) {
    return showDialog<_LocationChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.gps_off),
        title: const Text('No se obtuvo la ubicación'),
        content: Text(e.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _LocationChoice.saveWithout),
            child: const Text('Guardar sin ubicación'),
          ),
          if (e.serviceDisabled)
            FilledButton(
              onPressed: () => Navigator.pop(ctx, _LocationChoice.openSettings),
              child: const Text('Activar GPS'),
            )
          else
            FilledButton(
              onPressed: () => Navigator.pop(ctx, _LocationChoice.retry),
              child: const Text('Reintentar'),
            ),
        ],
      ),
    );
  }

  /// Borra archivos que ya no se usan: fotos/audios descartados en esta
  /// sesión y los originales que fueron reemplazados.
  Future<void> _cleanupAfterSave(TravelEntry saved) async {
    final media = _deps.media;
    final keep = {saved.imagePath, saved.audioPath};
    final original = widget.initialEntry;
    final toDelete = {
      ..._createdFiles.where((f) => !keep.contains(f)),
      if (original?.imagePath != null && !keep.contains(original!.imagePath)) original.imagePath!,
      if (original?.audioPath != null && !keep.contains(original!.audioPath)) original.audioPath!,
    };
    for (final f in toDelete) {
      await media.deleteFile(f);
    }
  }

  Future<void> _discardCreatedFiles() async {
    final media = _deps.media;
    for (final f in _createdFiles) {
      await media.deleteFile(f);
    }
    _createdFiles.clear();
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Descartar cambios?'),
        content: const Text('Perderás lo que escribiste, la foto y la nota de voz de esta entrada.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Seguir editando')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Descartar')),
        ],
      ),
    );
    return discard ?? false;
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final saving = _savingStep != null;

    return PopScope<TravelEntry>(
      canPop: (!_dirty || _saved) && !saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          if (!_saved) await _discardCreatedFiles();
          return;
        }
        if (saving) return;
        if (await _confirmDiscard()) {
          await _discardCreatedFiles();
          if (context.mounted) {
            _dirty = false;
            Navigator.pop(context);
          }
        }
      },
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              title: Text(_isEditing ? 'Editar entrada' : 'Nueva entrada'),
              actions: [
                IconButton(onPressed: saving ? null : _save, icon: const Icon(Icons.check), tooltip: 'Guardar'),
              ],
            ),
            body: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  _PhotoSection(
                    imagePath: _imagePath,
                    category: _category,
                    onTap: _choosePhotoSource,
                    onCamera: () => _pickPhoto(PhotoSource.camera),
                    onGallery: () => _pickPhoto(PhotoSource.gallery),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _titleCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'Título',
                      hintText: 'Ej. Atardecer en el malecón',
                      prefixIcon: Icon(Icons.title),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Escribe un título' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _tripCtrl,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Viaje',
                      hintText: 'Ej. Oaxaca 2026',
                      prefixIcon: Icon(Icons.flight_takeoff),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? '¿De qué viaje es esta entrada?' : null,
                  ),
                  if (_knownTrips.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final trip in _knownTrips.take(6))
                          ActionChip(
                            label: Text(trip),
                            onPressed: () => _tripCtrl.text = trip,
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text('Categoría', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in EntryCategory.values)
                        ChoiceChip(
                          avatar: Icon(c.icon, size: 18),
                          label: Text(c.label),
                          selected: _category == c,
                          onSelected: (_) => setState(() {
                            _category = c;
                            _dirty = true;
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: Text('¿Qué viviste hoy?', style: theme.textTheme.titleSmall)),
                      PulsingMicButton(
                        isListening: _listening,
                        enabled: !_recording && !saving,
                        onPressed: _toggleDictation,
                      ),
                    ],
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    child: _listening
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(children: [
                              Icon(Icons.graphic_eq, color: theme.colorScheme.error, size: 18),
                              const SizedBox(width: 6),
                              Text('Escuchando… habla con naturalidad',
                                  style: TextStyle(color: theme.colorScheme.error)),
                            ]),
                          )
                        : const SizedBox.shrink(),
                  ),
                  TextFormField(
                    controller: _contentCtrl,
                    minLines: 5,
                    maxLines: 12,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Escribe o toca el micrófono para dictar…',
                      alignLabelWithHint: true,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Cuenta algo de este momento' : null,
                  ),
                  const SizedBox(height: 20),
                  Text('Nota de voz (opcional)', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  VoiceNoteRecorder(
                    audioPath: _audioPath,
                    enabled: !_listening && !saving,
                    onFileCreated: _createdFiles.add,
                    onRecordingChanged: (r) {
                      if (mounted) setState(() => _recording = r);
                    },
                    onChanged: (p) => setState(() {
                      _audioPath = p;
                      _dirty = true;
                    }),
                  ),
                  const SizedBox(height: 20),
                  _LocationInfo(
                    existing: widget.initialEntry?.location,
                    isEditing: _isEditing,
                    updateLocation: _updateLocation,
                    onUpdateChanged: (v) => setState(() => _updateLocation = v),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: saving ? null : _save,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_isEditing ? 'Guardar cambios' : 'Guardar entrada'),
                  ),
                ],
              ),
            ),
          ),
          if (saving) _SavingOverlay(message: _savingStep!),
        ],
      ),
    );
  }
}

/// Vista previa de la foto o botones para agregar una.
class _PhotoSection extends StatelessWidget {
  const _PhotoSection({
    required this.imagePath,
    required this.category,
    required this.onTap,
    required this.onCamera,
    required this.onGallery,
  });

  final String? imagePath;
  final EntryCategory category;
  final VoidCallback onTap;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: imagePath != null
          ? GestureDetector(
              key: ValueKey(imagePath),
              onTap: onTap,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      EntryImage(
                        entry: TravelEntry(
                          title: '',
                          content: '',
                          tripName: '',
                          category: category,
                          createdAt: DateTime(0),
                          updatedAt: DateTime(0),
                          imagePath: imagePath,
                        ),
                      ),
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: FilledButton.tonalIcon(
                          onPressed: onTap,
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Cambiar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : Container(
              key: const ValueKey('empty'),
              height: 170,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: scheme.outlineVariant, width: 1.5),
                color: scheme.surfaceContainerLow,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined, size: 36, color: scheme.primary),
                  const SizedBox(height: 8),
                  const Text('Ilustra tu día con una foto'),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: onCamera,
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Cámara'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: onGallery,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Galería'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

/// Explica cuándo se captura el GPS (y permite actualizarlo al editar).
class _LocationInfo extends StatelessWidget {
  const _LocationInfo({
    required this.existing,
    required this.isEditing,
    required this.updateLocation,
    required this.onUpdateChanged,
  });

  final EntryLocation? existing;
  final bool isEditing;
  final bool updateLocation;
  final ValueChanged<bool> onUpdateChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer.withValues(alpha: 0.5),
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.my_location, color: scheme.primary),
            title: Text(isEditing
                ? (existing?.displayName ?? 'Esta entrada no tiene ubicación')
                : 'Ubicación automática'),
            subtitle: Text(isEditing
                ? 'Ubicación guardada'
                : 'Al guardar se registrará tu posición GPS actual.'),
          ),
          if (isEditing)
            SwitchListTile(
              value: updateLocation,
              onChanged: onUpdateChanged,
              title: const Text('Usar mi ubicación actual al guardar'),
            ),
        ],
      ),
    );
  }
}

/// Capa que bloquea la pantalla y muestra el paso actual del guardado.
class _SavingOverlay extends StatelessWidget {
  const _SavingOverlay({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black45,
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Material(type: MaterialType.transparency, child: Text(message)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _LocationChoice { retry, openSettings, saveWithout, cancel }

/// Resultado de intentar capturar la ubicación.
class _LocationOutcome {
  const _LocationOutcome.found(this.location) : cancelled = false;
  const _LocationOutcome.none()
      : location = null,
        cancelled = false;
  const _LocationOutcome.cancelled()
      : location = null,
        cancelled = true;

  final EntryLocation? location;
  final bool cancelled;
}
