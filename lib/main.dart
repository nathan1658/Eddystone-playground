import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'models/beacon_annotation.dart';
import 'models/beacon_device.dart';
import 'services/annotation_store.dart';
import 'services/beacon_advertiser.dart';
import 'services/beacon_diagnostics.dart';
import 'services/beacon_scanner.dart';

void main() {
  runApp(const BeaconApp());
}

abstract final class Gds {
  static const googleBlue = Color(0xff4285f4);
  static const googleBlue700 = Color(0xff1a73e8);
  static const googleRed600 = Color(0xffd93025);
  static const googleYellow700 = Color(0xfff29900);
  static const googleGreen700 = Color(0xff1e8e3e);
  static const grey0 = Color(0xffffffff);
  static const grey50 = Color(0xfff8f9fa);
  static const grey100 = Color(0xfff1f3f4);
  static const grey200 = Color(0xffe8eaed);
  static const grey300 = Color(0xffdadce0);
  static const grey400 = Color(0xffbdc1c6);
  static const grey600 = Color(0xff80868b);
  static const grey700 = Color(0xff5f6368);
  static const grey800 = Color(0xff3c4043);
  static const grey900 = Color(0xff202124);
  static const blue50 = Color(0xffe8f0fe);
  static const green50 = Color(0xffe6f4ea);
  static const red50 = Color(0xfffce8e6);
  static const yellow50 = Color(0xfffff7e0);
  static const radiusXs = 4.0;
  static const radiusSm = 8.0;
  static const radiusMd = 12.0;
  static const controlSm = 32.0;
  static const controlMd = 36.0;

  static ThemeData theme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: googleBlue700,
      brightness: Brightness.light,
      primary: googleBlue700,
      secondary: googleGreen700,
      tertiary: googleYellow700,
      error: googleRed600,
      surface: grey0,
      surfaceContainerHighest: grey100,
      outline: grey300,
      outlineVariant: grey200,
    );
    final base = ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: grey0,
      fontFamily: 'Google Sans Flex',
    );
    final textTheme = base.textTheme.apply(
      bodyColor: grey900,
      displayColor: grey900,
      fontFamily: 'Google Sans Flex',
    );
    final pill = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(999),
    );
    return base.copyWith(
      textTheme: textTheme.copyWith(
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontSize: 26,
          height: 36 / 26,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.26,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontSize: 22,
          height: 28 / 22,
          fontWeight: FontWeight.w500,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontSize: 16,
          height: 24 / 16,
          fontWeight: FontWeight.w500,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          fontSize: 14,
          height: 20 / 14,
          letterSpacing: 0.1,
        ),
        bodySmall: textTheme.bodySmall?.copyWith(
          fontSize: 12,
          height: 16 / 12,
          letterSpacing: 0.2,
        ),
        labelLarge: textTheme.labelLarge?.copyWith(
          fontSize: 14,
          height: 20 / 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
        ),
        labelMedium: textTheme.labelMedium?.copyWith(
          fontSize: 12,
          height: 16 / 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: grey0,
        foregroundColor: grey900,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: grey0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: grey300),
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: grey200,
        thickness: 1,
        space: 1,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: grey700,
          minimumSize: const Size(controlMd, controlMd),
          fixedSize: const Size(controlMd, controlMd),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
          hoverColor: grey50,
          highlightColor: grey100,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, controlMd),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          foregroundColor: grey900,
          side: const BorderSide(color: grey300),
          shape: pill,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, controlMd),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          backgroundColor: googleBlue700,
          foregroundColor: grey0,
          shape: pill,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: googleBlue700,
          minimumSize: const Size(0, controlMd),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: pill,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: grey0,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: grey300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: grey300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: googleBlue700, width: 2),
        ),
        labelStyle: const TextStyle(color: grey700, fontSize: 12),
        prefixIconColor: grey600,
        suffixStyle: const TextStyle(color: grey700, fontSize: 12),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 28)),
          visualDensity: VisualDensity.compact,
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 14),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return grey0;
            }
            return grey100;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return grey900;
            }
            return grey700;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const BorderSide(color: grey300);
            }
            return BorderSide.none;
          }),
          shape: WidgetStatePropertyAll(pill),
          textStyle: WidgetStatePropertyAll(
            textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: grey0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: grey0,
        indicatorColor: grey200,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelMedium),
        iconTheme: const WidgetStatePropertyAll(IconThemeData(size: 20)),
      ),
    );
  }
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
    return MaterialApp(
      title: 'Eddystone Playground',
      debugShowCheckedModeBanner: false,
      theme: Gds.theme(),
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
  late final BeaconDiagnostics _diagnostics = BeaconDiagnostics(
    scanner: _scanner,
    advertiser: _advertiser,
  );

  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_annotationStore.load());
    unawaited(_scanner.start());
    unawaited(_diagnostics.start());
  }

  @override
  void dispose() {
    if (widget.scanner == null) {
      _scanner.dispose();
    }
    if (widget.annotationStore == null) {
      _annotationStore.dispose();
    }
    _diagnostics.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = switch (_selectedIndex) {
      0 => ScanPage(scanner: _scanner, annotationStore: _annotationStore),
      _ => AdvertisePage(advertiser: _advertiser),
    };

    return AnimatedBuilder(
      animation: _scanner,
      builder: (context, _) {
        return _StudioShell(
          selectedIndex: _selectedIndex,
          scanner: _scanner,
          onDestinationSelected: (index) {
            setState(() => _selectedIndex = index);
          },
          child: body,
        );
      },
    );
  }
}

class _StudioShell extends StatelessWidget {
  const _StudioShell({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.scanner,
    required this.child,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final BeaconScanner scanner;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showTopNavigation = constraints.maxWidth >= 640;
            return Column(
              children: [
                _StudioTopBar(
                  scanner: scanner,
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onDestinationSelected,
                  showNavigation: showTopNavigation,
                ),
                Expanded(child: child),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 640) {
            return const SizedBox.shrink();
          }
          return DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Gds.grey200)),
            ),
            child: NavigationBar(
              height: 64,
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              destinations: const [
                NavigationDestination(icon: Icon(Icons.radar), label: 'Scan'),
                NavigationDestination(
                  icon: Icon(Icons.sensors),
                  label: 'Advertise',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StudioTopBar extends StatelessWidget {
  const _StudioTopBar({
    required this.scanner,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.showNavigation,
  });

  final BeaconScanner scanner;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool showNavigation;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Gds.grey0,
        border: Border(bottom: BorderSide(color: Gds.grey200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Eddystone playground',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (showNavigation) ...[
            const SizedBox(width: 12),
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: 0,
                  icon: Icon(Icons.radar),
                  label: Text('Scan'),
                ),
                ButtonSegment(
                  value: 1,
                  icon: Icon(Icons.sensors),
                  label: Text('Advertise'),
                ),
              ],
              selected: {selectedIndex},
              onSelectionChanged: (selection) {
                onDestinationSelected(selection.first);
              },
            ),
          ],
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: scanner.isScanning ? scanner.stop : scanner.start,
            icon: Icon(
              scanner.isScanning ? Icons.pause : Icons.play_arrow,
              size: 18,
            ),
            label: Text(scanner.isScanning ? 'Pause scan' : 'Start scan'),
          ),
        ],
      ),
    );
  }
}

class _BorderIconButton extends StatelessWidget {
  const _BorderIconButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: SizedBox.square(
        dimension: Gds.controlSm,
        child: IconButton.outlined(
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          style: IconButton.styleFrom(
            side: const BorderSide(color: Gds.grey300),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Gds.radiusSm),
            ),
          ),
        ),
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontal = constraints.maxWidth >= 820 ? 36.0 : 16.0;
              return ListView(
                padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 28),
                children: [
                  _PageHeader(
                    title: 'Beacon inventory',
                    trailing: OutlinedButton.icon(
                      onPressed: scanner.refresh,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Refresh'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _ScanStatusPanel(scanner: scanner, count: devices.length),
                  const SizedBox(height: 12),
                  if (devices.isEmpty)
                    _EmptyScanState(scanner: scanner)
                  else
                    for (final device in devices)
                      Padding(
                        key: ValueKey('beacon-tile-${device.id}'),
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _BeaconTile(
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
                      ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.headlineMedium),
        ),
        ?trailing,
      ],
    );
  }
}

class _ScanStatusPanel extends StatelessWidget {
  const _ScanStatusPanel({required this.scanner, required this.count});

  final BeaconScanner scanner;
  final int count;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Gds.grey0,
        border: Border.all(color: Gds.grey300),
        borderRadius: BorderRadius.circular(Gds.radiusMd),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scanner.isSupported ? Gds.blue50 : Gds.red50,
                borderRadius: BorderRadius.circular(Gds.radiusSm),
              ),
              child: Icon(
                scanner.isScanning
                    ? Icons.bluetooth_searching
                    : Icons.bluetooth,
                size: 20,
                color: scanner.isSupported
                    ? Gds.googleBlue700
                    : Gds.googleRed600,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scanner.statusText,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$count visible ${count == 1 ? 'device' : 'devices'}',
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: Gds.grey700),
                  ),
                ],
              ),
            ),
            _BorderIconButton(
              icon: Icons.refresh,
              label: 'Refresh scan',
              onPressed: scanner.refresh,
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
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.48,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.bluetooth_searching,
              size: 38,
              color: Gds.googleBlue700,
            ),
            const SizedBox(height: 16),
            Text(
              'No beacon packets yet',
              style: textTheme.headlineMedium?.copyWith(
                color: Gds.grey700,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              scanner.isScanning ? 'Listening now' : 'Scan is paused',
              style: textTheme.bodyMedium?.copyWith(color: Gds.grey700),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
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
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Gds.grey700),
                    ),
                    if (note != null && note.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.label,
                            size: 16,
                            color: Gds.googleBlue700,
                          ),
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
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: Gds.grey700),
                  ),
                  if (annotation?.imagePath != null) ...[
                    const SizedBox(height: 6),
                    const Icon(Icons.image, size: 18, color: Gds.googleBlue700),
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
    final (icon, color, fill) = switch (kind) {
      BeaconKind.iBeacon => (Icons.adjust, Gds.googleBlue700, Gds.blue50),
      BeaconKind.eddystoneUid => (Icons.tag, Gds.googleGreen700, Gds.green50),
      BeaconKind.eddystoneUrl => (
        Icons.link,
        Gds.googleYellow700,
        Gds.yellow50,
      ),
      BeaconKind.eddystoneTlm => (
        Icons.monitor_heart,
        Gds.googleRed600,
        Gds.red50,
      ),
      BeaconKind.ble => (Icons.bluetooth, Gds.grey700, Gds.grey100),
    };
    return Tooltip(
      message: kind.label,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(Gds.radiusSm),
        ),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }
}

class _RssiChip extends StatelessWidget {
  const _RssiChip({required this.rssi});

  final int rssi;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 60),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Gds.grey50,
        border: Border.all(color: Gds.grey300),
        borderRadius: BorderRadius.circular(999),
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
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
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
                        style: Theme.of(
                          context,
                        ).textTheme.labelLarge?.copyWith(color: Gds.grey700),
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
    final existingPath = path;
    final file = existingPath == null ? null : File(existingPath);
    final exists = file?.existsSync() ?? false;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Gds.grey50,
          border: Border.all(color: Gds.grey300),
          borderRadius: BorderRadius.circular(Gds.radiusMd),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Gds.radiusMd),
          child: exists
              ? Image.file(file!, fit: BoxFit.cover)
              : Center(
                  child: Icon(
                    Icons.add_photo_alternate,
                    size: 40,
                    color: Gds.grey600,
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
        color: Gds.grey0,
        border: Border.all(color: Gds.grey300),
        borderRadius: BorderRadius.circular(Gds.radiusMd),
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
                      style: Theme.of(
                        context,
                      ).textTheme.labelMedium?.copyWith(color: Gds.grey700),
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
    final capability = _capabilities;
    final canStart = !_busy && _canAdvertiseSelectedMode(capability);
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth >= 820 ? 36.0 : 16.0;
        return ListView(
          padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 28),
          children: [
            _PageHeader(
              title: 'Advertise mode',
              trailing: OutlinedButton.icon(
                onPressed: _busy ? null : _loadCapabilities,
                icon: const Icon(Icons.sync, size: 18),
                label: const Text('Reload'),
              ),
            ),
            const SizedBox(height: 24),
            _AdvertiseStatusPanel(
              isAdvertising: _isAdvertising,
              status: _status,
              busy: _busy,
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<AdvertiseMode>(
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
            ),
            const SizedBox(height: 16),
            _GeminiFocusPanel(
              child: AnimatedSwitcher(
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
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: canStart ? _startAdvertising : null,
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cell_tower, size: 18),
                  label: const Text('Start advertising'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _busy || !_isAdvertising ? null : _stopAdvertising,
                  icon: const Icon(Icons.stop, size: 18),
                  label: const Text('Stop'),
                ),
              ],
            ),
          ],
        );
      },
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

class _AdvertiseStatusPanel extends StatelessWidget {
  const _AdvertiseStatusPanel({
    required this.isAdvertising,
    required this.status,
    required this.busy,
  });

  final bool isAdvertising;
  final String status;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Gds.grey0,
        border: Border.all(color: Gds.grey300),
        borderRadius: BorderRadius.circular(Gds.radiusMd),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isAdvertising ? Gds.blue50 : Gds.grey100,
                borderRadius: BorderRadius.circular(Gds.radiusSm),
              ),
              child: Icon(
                isAdvertising ? Icons.sensors : Icons.sensors_off,
                size: 20,
                color: isAdvertising ? Gds.googleBlue700 : Gds.grey700,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    busy ? 'Checking capabilities' : 'Local radio profile',
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: Gds.grey700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GeminiFocusPanel extends StatelessWidget {
  const _GeminiFocusPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 26, sigmaY: 26),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: SweepGradient(
                    colors: [
                      Gds.googleBlue.withValues(alpha: 0.22),
                      Gds.googleRed600.withValues(alpha: 0.18),
                      Gds.googleYellow700.withValues(alpha: 0.16),
                      Gds.googleGreen700.withValues(alpha: 0.18),
                      Gds.googleBlue.withValues(alpha: 0.22),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Gds.grey0,
            border: Border.all(color: Gds.grey300),
            borderRadius: BorderRadius.circular(Gds.radiusMd),
          ),
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ],
    );
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
