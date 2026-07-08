import 'package:eddystone_playground/main.dart';
import 'package:eddystone_playground/models/beacon_device.dart';
import 'package:eddystone_playground/services/annotation_store.dart';
import 'package:eddystone_playground/services/beacon_advertiser.dart';
import 'package:eddystone_playground/services/beacon_scanner.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('e2e: searches by name and MAC, then sorts by signal strength', (
    tester,
  ) async {
    final now = DateTime(2026);
    final scanner = MemoryBeaconScanner(
      devices: [
        BeaconDevice(
          id: 'ble:weak',
          kind: BeaconKind.ble,
          remoteId: 'AA:BB:CC:DD:EE:01',
          displayName: 'Warehouse anchor',
          identity: 'AA:BB:CC:DD:EE:01',
          rssi: -81,
          lastSeen: now,
        ),
        BeaconDevice(
          id: 'ble:strong',
          kind: BeaconKind.ble,
          remoteId: '11:22:33:44:55:66',
          displayName: 'Lobby Beacon',
          identity: '11:22:33:44:55:66',
          rssi: -39,
          lastSeen: now.add(const Duration(seconds: 1)),
        ),
        BeaconDevice(
          id: 'ble:middle',
          kind: BeaconKind.ble,
          remoteId: 'CC:DD:EE:FF:00:99',
          displayName: 'Atrium marker',
          identity: 'CC:DD:EE:FF:00:99',
          rssi: -55,
          lastSeen: now.add(const Duration(seconds: 2)),
        ),
      ],
      isScanning: true,
      statusText: 'Scanning in test',
    );

    await tester.pumpWidget(
      BeaconApp(
        scanner: scanner,
        annotationStore: MemoryAnnotationStore(),
        advertiser: const FakeBeaconAdvertiser(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      _topOf(tester, 'Warehouse anchor'),
      lessThan(_topOf(tester, 'Lobby Beacon')),
    );
    expect(
      _topOf(tester, 'Lobby Beacon'),
      lessThan(_topOf(tester, 'Atrium marker')),
    );

    await tester.tap(find.text('Signal'));
    await tester.pumpAndSettle();

    expect(
      _topOf(tester, 'Lobby Beacon'),
      lessThan(_topOf(tester, 'Atrium marker')),
    );
    expect(
      _topOf(tester, 'Atrium marker'),
      lessThan(_topOf(tester, 'Warehouse anchor')),
    );

    await tester.enterText(
      find.byKey(const ValueKey('scan-search-field')),
      'lObBy',
    );
    await tester.pumpAndSettle();

    expect(find.text('Lobby Beacon'), findsOneWidget);
    expect(find.text('Warehouse anchor'), findsNothing);
    expect(find.text('Atrium marker'), findsNothing);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('scan-search-field')),
      'aa:bb:cc',
    );
    await tester.pumpAndSettle();

    expect(find.text('Warehouse anchor'), findsOneWidget);
    expect(find.text('Lobby Beacon'), findsNothing);
    expect(find.text('Atrium marker'), findsNothing);
  });
}

double _topOf(WidgetTester tester, String text) {
  return tester.getTopLeft(find.text(text)).dy;
}
