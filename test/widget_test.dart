import 'package:eddystone_playground/main.dart';
import 'package:eddystone_playground/models/beacon_device.dart';
import 'package:eddystone_playground/services/annotation_store.dart';
import 'package:eddystone_playground/services/beacon_advertiser.dart';
import 'package:eddystone_playground/services/beacon_scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows scanner and advertiser modes', (tester) async {
    final scanner = MemoryBeaconScanner(
      devices: [
        BeaconDevice(
          id: 'ibeacon:00112233-4455-6677-8899-aabbccddeeff:1:2',
          kind: BeaconKind.iBeacon,
          remoteId: 'AA:BB:CC:DD:EE:FF',
          displayName: 'Lobby beacon',
          identity: '00112233-4455-6677-8899-aabbccddeeff:1:2',
          rssi: -62,
          lastSeen: DateTime.now(),
          uuid: '00112233-4455-6677-8899-aabbccddeeff',
          major: 1,
          minor: 2,
          txPower: -59,
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
    await tester.pump();

    expect(find.text('Eddystone Playground'), findsOneWidget);
    expect(find.text('Lobby beacon'), findsOneWidget);
    expect(find.text('Scanning in test'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.sensors).last);
    await tester.pumpAndSettle();

    expect(find.text('iBeacon'), findsWidgets);
    expect(find.text('Start'), findsOneWidget);
  });
}
