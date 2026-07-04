# Eddystone Playground

Flutter app for scanning nearby BLE beacon packets, tagging specific Eddystone/iBeacon identities with local notes and images, and advertising this device as a beacon where the platform allows it.

## Features

- Runs on Android and iOS.
- Self-refreshing scanner list backed by `flutter_blue_plus`.
- Parses iBeacon manufacturer frames and Eddystone UID, URL, and TLM service-data frames.
- Saves free-text labels and a local image per beacon identity.
- Advertises iBeacon on Android and iOS.
- Advertises Eddystone UID and URL on Android.
- Stores all annotations locally with `shared_preferences`; selected images are copied into the app documents directory.

## Platform Notes

| Capability | Android | iOS |
| --- | --- | --- |
| BLE scan list | Yes | Yes |
| iBeacon packet parsing | Yes, from Apple manufacturer data | iOS hides raw iBeacon packets from generic CoreBluetooth scans |
| Eddystone parsing | Yes | Yes when CoreBluetooth exposes the FEAA service data |
| iBeacon advertising | Yes | Yes, through CoreBluetooth/CoreLocation |
| Eddystone advertising | Yes | Not available through iOS public Bluetooth APIs |

Bluetooth hardware, OS privacy settings, and vendor BLE stack limits can change what a real phone exposes. For scanner validation, use at least one physical beacon or a second Android phone advertising a known frame.

## Development

```bash
flutter pub get
flutter run
```

Android requires Bluetooth scan/connect/advertise permissions. iOS requires Bluetooth, photo library, and camera usage descriptions; they are already declared in `ios/Runner/Info.plist`.

## Validation

Commands run during development:

```bash
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --simulator --no-codesign
```

The iOS simulator build passed from a temporary copy under `/tmp`. Building from this local `Documents` workspace can fail at CodeSign if macOS file-provider metadata attaches `com.apple.FinderInfo` to generated frameworks. If that happens, build from a non-synced path or clear extended attributes before signing.

## Dependency Note

`flutter_blue_plus` has its own license terms, including commercial-use terms. Review its package license before using this app in a for-profit product.
