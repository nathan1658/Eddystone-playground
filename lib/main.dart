import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'models/beacon_annotation.dart';
import 'models/beacon_device.dart';
import 'services/annotation_store.dart';
import 'services/beacon_advertiser.dart';
import 'services/beacon_scanner.dart';

void main() {
  runApp(const BeaconApp());
}

class BeaconApp extends StatelessWidget {
  const BeaconApp({
    super.key,
    this.scanner,
    this.annotationStore,
    this.advertiser,
  });

  final BeaconScanner? scanner;
  final BeaconAnnotationStore? annotationStore;
  final BeaconAdvertiser? advertiser;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xff006d77),
      secondary: const Color(0xff7a4e9a),
      tertiary: const Color(0xffc77d00),
      brightness: Brightness.light,
    );
    return MaterialApp(
      title: 'Eddystone Playground',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      ),
      home: BeaconHomePage(
        scanner: scanner,
        annotationStore: annotationStore,
        advertiser: advertiser,
      ),
    );
  }
}

class BeaconHomePage extends StatefulWidget {
  const BeaconHomePage({
    super.key,
    this.scanner,
    this.annotationStore,
    this.advertiser,
  });

  final BeaconScanner? scanner;
  final BeaconAnnotationStore? annotationStore;
  final BeaconAdvertiser? advertiser;

  @override
  State<BeaconHomePage> createState() => _BeaconHomePageState();
}

class _BeaconHomePageState extends State<BeaconHomePage> {
  late final BeaconScanner _scanner = widget.scanner ?? FlutterBeaconScanner();
  late final BeaconAnnotationStore _annotationStore =
      widget.annotationStore ?? SharedPreferencesAnnotationStore();
  late final BeaconAdvertiser _advertiser =
      widget.advertiser ?? MethodChannelBeaconAdvertiser();

  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_annotationStore.load());
    unawaited(_scanner.start());
  }

  @override
  void dispose() {
    if (widget.scanner == null) {
      _scanner.dispose();
    }
    if (widget.annotationStore == null) {
      _annotationStore.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = switch (_selectedIndex) {
      0 => ScanPage(scanner: _scanner, annotationStore: _annotationStore),
      _ => AdvertisePage(advertiser: _advertiser),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Eddystone Playground'),
        actions: [
          IconButton(
            tooltip: _scanner.isScanning ? 'Pause scan' : 'Start scan',
            onPressed: () {
              if (_scanner.isScanning) {
                unawaited(_scanner.stop());
              } else {
                unawaited(_scanner.start());
              }
            },
            icon: Icon(_scanner.isScanning ? Icons.pause : Icons.play_arrow),
          ),
        ],
      ),
      body: SafeArea(child: body),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.radar), label: 'Scan'),
          NavigationDestination(icon: Icon(Icons.sensors), label: 'Advertise'),
        ],
      ),
    );
  }
}

class ScanPage extends StatelessWidget {
  const ScanPage({
    super.key,
    required this.scanner,
    required this.annotationStore,
  });

  final BeaconScanner scanner;
  final BeaconAnnotationStore annotationStore;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([scanner, annotationStore]),
      builder: (context, _) {
        final devices = scanner.devices;
        return RefreshIndicator(
          onRefresh: scanner.refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _ScanStatusPanel(scanner: scanner, count: devices.length),
              const SizedBox(height: 12),
              if (devices.isEmpty)
                _EmptyScanState(scanner: scanner)
              else
                for (final device in devices) ...[
                  _BeaconTile(
                    device: device,
                    annotation: annotationStore.annotationFor(device.id),
                    onTap: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      builder: (_) => BeaconDetailSheet(
                        device: device,
                        annotationStore: annotationStore,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
            ],
          ),
        );
      },
    );
  }
}

class _ScanStatusPanel extends StatelessWidget {
  const _ScanStatusPanel({required this.scanner, required this.count});

  final BeaconScanner scanner;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              scanner.isScanning ? Icons.bluetooth_searching : Icons.bluetooth,
              color: scanner.isSupported ? colors.primary : colors.error,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scanner.statusText,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$count visible ${count == 1 ? 'device' : 'devices'}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Refresh scan',
              onPressed: scanner.refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyScanState extends StatelessWidget {
  const _EmptyScanState({required this.scanner});

  final BeaconScanner scanner;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.48,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.radar, size: 48, color: colors.tertiary),
            const SizedBox(height: 12),
            Text('No beacon packets yet', style: textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              scanner.isScanning ? 'Listening now' : 'Scan is paused',
              style: textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: scanner.refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BeaconTile extends StatelessWidget {
  const _BeaconTile({
    required this.device,
    required this.annotation,
    required this.onTap,
  });

  final BeaconDevice device;
  final BeaconAnnotation? annotation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final note = annotation?.note.trim();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _ProtocolBadge(kind: device.kind),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      device.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    if (note != null && note.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.label, size: 16, color: colors.secondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              note,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _RssiChip(rssi: device.rssi),
                  const SizedBox(height: 8),
                  Text(
                    _relativeAge(device.lastSeen),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  if (annotation?.imagePath != null) ...[
                    const SizedBox(height: 6),
                    Icon(Icons.image, size: 18, color: colors.primary),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProtocolBadge extends StatelessWidget {
  const _ProtocolBadge({required this.kind});

  final BeaconKind kind;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (icon, color) = switch (kind) {
      BeaconKind.iBeacon => (Icons.adjust, colors.primary),
      BeaconKind.eddystoneUid => (Icons.tag, colors.secondary),
      BeaconKind.eddystoneUrl => (Icons.link, colors.tertiary),
      BeaconKind.eddystoneTlm => (Icons.monitor_heart, colors.error),
      BeaconKind.ble => (Icons.bluetooth, colors.onSurfaceVariant),
    };
    return Tooltip(
      message: kind.label,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color),
      ),
    );
  }
}

class _RssiChip extends StatelessWidget {
  const _RssiChip({required this.rssi});

  final int rssi;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 60),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$rssi dBm',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}

class BeaconDetailSheet extends StatefulWidget {
  const BeaconDetailSheet({
    super.key,
    required this.device,
    required this.annotationStore,
  });

  final BeaconDevice device;
  final BeaconAnnotationStore annotationStore;

  @override
  State<BeaconDetailSheet> createState() => _BeaconDetailSheetState();
}

class _BeaconDetailSheetState extends State<BeaconDetailSheet> {
  late final TextEditingController _noteController;
  final ImagePicker _imagePicker = ImagePicker();
  String? _imagePath;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final annotation = widget.annotationStore.annotationFor(widget.device.id);
    _noteController = TextEditingController(text: annotation?.note ?? '');
    _imagePath = annotation?.imagePath;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ProtocolBadge(kind: widget.device.kind),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.device.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        widget.device.kind.label,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _ImagePreview(path: _imagePath),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Camera'),
                ),
                if (_imagePath != null)
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _imagePath = null),
                    icon: const Icon(Icons.hide_image),
                    label: const Text('Remove image'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Label or notes',
              ),
            ),
            const SizedBox(height: 16),
            _DetailRows(device: widget.device),
            const SizedBox(height: 18),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _saving ? null : _delete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Clear'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (picked == null) {
      return;
    }
    final documents = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${documents.path}/beacon_images');
    await imagesDir.create(recursive: true);
    final extension = picked.path.split('.').lastOrNull ?? 'jpg';
    final fileName = '${_safeFileName(widget.device.id)}.$extension';
    final destination = File('${imagesDir.path}/$fileName');
    await File(picked.path).copy(destination.path);
    if (!mounted) {
      return;
    }
    setState(() => _imagePath = destination.path);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final annotation = BeaconAnnotation(
      beaconId: widget.device.id,
      note: _noteController.text.trim(),
      imagePath: _imagePath,
      updatedAt: DateTime.now(),
    );
    await widget.annotationStore.save(annotation);
    if (!mounted) {
      return;
    }
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    setState(() => _saving = true);
    await widget.annotationStore.delete(widget.device.id);
    if (!mounted) {
      return;
    }
    Navigator.pop(context);
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final existingPath = path;
    final file = existingPath == null ? null : File(existingPath);
    final exists = file?.existsSync() ?? false;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: exists
              ? Image.file(file!, fit: BoxFit.cover)
              : Center(
                  child: Icon(
                    Icons.add_photo_alternate,
                    size: 40,
                    color: colors.onSurfaceVariant,
                  ),
                ),
        ),
      ),
    );
  }
}

class _DetailRows extends StatelessWidget {
  const _DetailRows({required this.device});

  final BeaconDevice device;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Protocol', device.kind.label),
      ('Identity', device.identity),
      ('Remote ID', device.remoteId),
      ('RSSI', '${device.rssi} dBm'),
      ('Last seen', _relativeAge(device.lastSeen)),
      if (device.approximateDistanceMeters != null)
        (
          'Approx distance',
          '${device.approximateDistanceMeters!.toStringAsFixed(2)} m',
        ),
      if (device.raw != null && device.raw!.isNotEmpty) ('Raw', device.raw!),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 108,
                    child: Text(
                      row.$1,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  Expanded(
                    child: SelectableText(
                      row.$2,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class AdvertisePage extends StatefulWidget {
  const AdvertisePage({super.key, required this.advertiser});

  final BeaconAdvertiser advertiser;

  @override
  State<AdvertisePage> createState() => _AdvertisePageState();
}

class _AdvertisePageState extends State<AdvertisePage> {
  final _uuidController = TextEditingController(text: const Uuid().v4());
  final _majorController = TextEditingController(text: '1');
  final _minorController = TextEditingController(text: '1');
  final _namespaceController = TextEditingController(
    text: '00112233445566778899',
  );
  final _instanceController = TextEditingController(text: 'aabbccddeeff');
  final _urlController = TextEditingController(text: 'https://example.com');
  final _measuredPowerController = TextEditingController(text: '-59');

  AdvertiseMode _mode = AdvertiseMode.iBeacon;
  AdvertiseCapabilities? _capabilities;
  bool _isAdvertising = false;
  bool _busy = false;
  String _status = 'Loading radio capabilities';

  @override
  void initState() {
    super.initState();
    unawaited(_loadCapabilities());
  }

  @override
  void dispose() {
    _uuidController.dispose();
    _majorController.dispose();
    _minorController.dispose();
    _namespaceController.dispose();
    _instanceController.dispose();
    _urlController.dispose();
    _measuredPowerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final capability = _capabilities;
    final canStart = !_busy && _canAdvertiseSelectedMode(capability);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: colors.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(
                  _isAdvertising ? Icons.sensors : Icons.sensors_off,
                  color: _isAdvertising
                      ? colors.primary
                      : colors.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _status,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Reload capabilities',
                  onPressed: _busy ? null : _loadCapabilities,
                  icon: const Icon(Icons.sync),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SegmentedButton<AdvertiseMode>(
          segments: const [
            ButtonSegment(
              value: AdvertiseMode.iBeacon,
              icon: Icon(Icons.adjust),
              label: Text('iBeacon'),
            ),
            ButtonSegment(
              value: AdvertiseMode.eddystoneUid,
              icon: Icon(Icons.tag),
              label: Text('UID'),
            ),
            ButtonSegment(
              value: AdvertiseMode.eddystoneUrl,
              icon: Icon(Icons.link),
              label: Text('URL'),
            ),
          ],
          selected: {_mode},
          onSelectionChanged: _busy
              ? null
              : (selection) => setState(() => _mode = selection.first),
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: switch (_mode) {
            AdvertiseMode.iBeacon => _IBeaconForm(
              key: const ValueKey('ibeacon-form'),
              uuidController: _uuidController,
              majorController: _majorController,
              minorController: _minorController,
              measuredPowerController: _measuredPowerController,
            ),
            AdvertiseMode.eddystoneUid => _EddystoneUidForm(
              key: const ValueKey('eddystone-uid-form'),
              namespaceController: _namespaceController,
              instanceController: _instanceController,
              measuredPowerController: _measuredPowerController,
            ),
            AdvertiseMode.eddystoneUrl => _EddystoneUrlForm(
              key: const ValueKey('eddystone-url-form'),
              urlController: _urlController,
              measuredPowerController: _measuredPowerController,
            ),
          },
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: canStart ? _startAdvertising : null,
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cell_tower),
                label: const Text('Start'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy || !_isAdvertising ? null : _stopAdvertising,
                icon: const Icon(Icons.stop),
                label: const Text('Stop'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _loadCapabilities() async {
    setState(() => _busy = true);
    try {
      final next = await widget.advertiser.capabilities();
      if (!mounted) {
        return;
      }
      setState(() {
        _capabilities = next;
        _status = next.message.isEmpty
            ? 'Ready on ${next.platform}'
            : next.message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _status = 'Unable to read capabilities: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  bool _canAdvertiseSelectedMode(AdvertiseCapabilities? capability) {
    if (capability == null || !capability.isSupported) {
      return false;
    }
    return switch (_mode) {
      AdvertiseMode.iBeacon => capability.iBeacon,
      AdvertiseMode.eddystoneUid ||
      AdvertiseMode.eddystoneUrl => capability.eddystone,
    };
  }

  Future<void> _startAdvertising() async {
    final measuredPower = int.tryParse(_measuredPowerController.text.trim());
    if (measuredPower == null || measuredPower < -127 || measuredPower > 20) {
      _setStatus('Measured power must be between -127 and 20');
      return;
    }

    setState(() => _busy = true);
    try {
      switch (_mode) {
        case AdvertiseMode.iBeacon:
          final major = int.tryParse(_majorController.text.trim());
          final minor = int.tryParse(_minorController.text.trim());
          final uuid = _uuidController.text.trim();
          if (!_uuidPattern.hasMatch(uuid) ||
              major == null ||
              minor == null ||
              major < 0 ||
              major > 65535 ||
              minor < 0 ||
              minor > 65535) {
            _setStatus('Check UUID, major, and minor values');
            return;
          }
          await widget.advertiser.startIBeacon(
            uuid: uuid,
            major: major,
            minor: minor,
            measuredPower: measuredPower,
          );
        case AdvertiseMode.eddystoneUid:
          final namespaceId = _namespaceController.text.trim();
          final instanceId = _instanceController.text.trim();
          if (!_hexPattern.hasMatch(namespaceId) ||
              namespaceId.length != 20 ||
              !_hexPattern.hasMatch(instanceId) ||
              instanceId.length != 12) {
            _setStatus('Namespace must be 10 bytes and instance 6 bytes');
            return;
          }
          await widget.advertiser.startEddystoneUid(
            namespaceId: namespaceId,
            instanceId: instanceId,
            measuredPower: measuredPower,
          );
        case AdvertiseMode.eddystoneUrl:
          final url = _urlController.text.trim();
          final parsed = Uri.tryParse(url);
          if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
            _setStatus('Enter a valid URL');
            return;
          }
          await widget.advertiser.startEddystoneUrl(
            url: url,
            measuredPower: measuredPower,
          );
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _isAdvertising = true;
        _status = 'Advertising ${_mode.label}';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      _setStatus('Unable to advertise: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _stopAdvertising() async {
    setState(() => _busy = true);
    try {
      await widget.advertiser.stop();
      if (!mounted) {
        return;
      }
      setState(() {
        _isAdvertising = false;
        _status = 'Advertising stopped';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      _setStatus('Unable to stop advertising: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _setStatus(String status) {
    if (!mounted) {
      return;
    }
    setState(() {
      _status = status;
      _busy = false;
    });
  }
}

class _IBeaconForm extends StatelessWidget {
  const _IBeaconForm({
    super.key,
    required this.uuidController,
    required this.majorController,
    required this.minorController,
    required this.measuredPowerController,
  });

  final TextEditingController uuidController;
  final TextEditingController majorController;
  final TextEditingController minorController;
  final TextEditingController measuredPowerController;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: uuidController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'UUID',
            prefixIcon: Icon(Icons.fingerprint),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: majorController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Major',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: minorController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Minor',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _MeasuredPowerField(controller: measuredPowerController),
      ],
    );
  }
}

class _EddystoneUidForm extends StatelessWidget {
  const _EddystoneUidForm({
    super.key,
    required this.namespaceController,
    required this.instanceController,
    required this.measuredPowerController,
  });

  final TextEditingController namespaceController;
  final TextEditingController instanceController;
  final TextEditingController measuredPowerController;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: namespaceController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Namespace ID',
            prefixIcon: Icon(Icons.numbers),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: instanceController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Instance ID',
            prefixIcon: Icon(Icons.confirmation_number),
          ),
        ),
        const SizedBox(height: 12),
        _MeasuredPowerField(controller: measuredPowerController),
      ],
    );
  }
}

class _EddystoneUrlForm extends StatelessWidget {
  const _EddystoneUrlForm({
    super.key,
    required this.urlController,
    required this.measuredPowerController,
  });

  final TextEditingController urlController;
  final TextEditingController measuredPowerController;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: urlController,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'URL',
            prefixIcon: Icon(Icons.link),
          ),
        ),
        const SizedBox(height: 12),
        _MeasuredPowerField(controller: measuredPowerController),
      ],
    );
  }
}

class _MeasuredPowerField extends StatelessWidget {
  const _MeasuredPowerField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(signed: true),
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        labelText: 'Measured power',
        prefixIcon: Icon(Icons.network_check),
        suffixText: 'dBm',
      ),
    );
  }
}

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
final RegExp _hexPattern = RegExp(r'^[0-9a-fA-F]+$');

String _relativeAge(DateTime time) {
  final elapsed = DateTime.now().difference(time);
  if (elapsed.inSeconds < 2) {
    return 'now';
  }
  if (elapsed.inSeconds < 60) {
    return '${elapsed.inSeconds}s ago';
  }
  if (elapsed.inMinutes < 60) {
    return '${elapsed.inMinutes}m ago';
  }
  return '${elapsed.inHours}h ago';
}

String _safeFileName(String input) {
  return input.replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '_');
}

extension _LastOrNull<T> on List<T> {
  T? get lastOrNull => isEmpty ? null : last;
}
