# Eddystone Playground

Cross-platform Flutter app for discovering nearby BLE beacon packets, annotating
specific Eddystone/iBeacon identities locally, and advertising the phone as a
beacon where the operating system allows it.

Public repository: <https://github.com/nathan1658/Eddystone-playground>

## What It Does

- Runs on Android and iOS.
- Continuously scans nearby BLE packets with a self-refreshing, stable ListView.
- Parses iBeacon manufacturer frames and Eddystone UID, URL, and TLM frames.
- Lets users attach a free-text note and local image to each beacon identity.
- Stores annotations locally with `shared_preferences`; selected images are
  copied into the app documents directory.
- Advertises iBeacon on Android and iOS.
- Advertises Eddystone UID and URL on Android.
- Uses a compact console UI inspired by the Google AI design handoff, without
  shipping handoff assets in the app bundle.

## Platform Support

| Capability | Android | iOS |
| --- | --- | --- |
| BLE scan list | Yes | Yes |
| iBeacon scan parsing | Yes, from Apple manufacturer data | iOS hides raw iBeacon packets from generic CoreBluetooth scans |
| Eddystone scan parsing | Yes | Yes when CoreBluetooth exposes FEAA service data |
| iBeacon advertising | Yes | Yes, through CoreBluetooth/CoreLocation |
| Eddystone advertising | Yes | No, not exposed through public iOS APIs |

Bluetooth hardware, privacy settings, OS version, foreground/background state,
and vendor BLE stack behavior can all affect what a real phone exposes.

## Requirements

- Flutter 3.38.x or newer with Dart 3.10.x.
- Android Studio / Android SDK for Android builds.
- Xcode with a valid signing team for physical iPhone deployment.
- A physical phone for meaningful BLE scanner/advertiser validation.

## Getting Started

```bash
flutter pub get
flutter run
```

Choose a target device explicitly when more than one device is connected:

```bash
flutter devices
flutter run -d <device-id>
```

## Android Notes

The Android app declares Bluetooth scan/connect/advertise and fine location
permissions. Fine location is intentionally enabled for BLE scans because
Android can filter beacon-style packets when scanning is declared as unrelated
to location.

Useful install command for a connected Android phone:

```bash
flutter build apk --debug
adb -s <device-id> install -r build/app/outputs/flutter-apk/app-debug.apk
```

## iOS Notes

iOS requires Bluetooth, camera, and photo library usage descriptions; these are
declared in `ios/Runner/Info.plist`. Eddystone advertising is unavailable on iOS
through public APIs, so iOS advertise mode is limited to iBeacon.

If codesigning fails from a synced or metadata-heavy folder, build from a clean
temporary copy:

```bash
rsync -a --exclude .git --exclude build --exclude .dart_tool ./ /tmp/eddystone-ios/
cd /tmp/eddystone-ios
flutter run --release -d <ios-device-id>
```

## Diagnostics

The app includes hidden deterministic BLE diagnostics for physical-device
validation. They are only enabled with `--dart-define`:

```bash
flutter run -d <device-id> --dart-define=BEACON_DIAGNOSTIC_MODE=scan
flutter run -d <device-id> --dart-define=BEACON_DIAGNOSTIC_MODE=advertise_ibeacon
flutter run -d <device-id> --dart-define=BEACON_DIAGNOSTIC_MODE=advertise_eddystone_url
flutter run -d <device-id> --dart-define=BEACON_DIAGNOSTIC_MODE=advertise_eddystone_uid
```

Diagnostic logs use the `BEACON_DIAGNOSTIC` prefix.

## Validation

Current checks:

```bash
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --simulator --no-codesign
```

Physical validation performed during development:

- Android phone saw the iPhone diagnostic iBeacon advertisement.
- Android debug build installed and launched on a Samsung SM W9026.
- iOS release build installed and launched on a physical iPhone 17 Pro.

## License

No open-source license has been selected yet. If you plan to reuse or distribute
this project, add an explicit license first.
