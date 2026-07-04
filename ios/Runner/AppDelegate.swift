import Flutter
import CoreBluetooth
import CoreLocation
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, CBPeripheralManagerDelegate {
  private let channelName = "eddystone_playground/beacon_advertiser"
  private var peripheralManager: CBPeripheralManager?
  private var pendingIBeacon: PendingIBeacon?
  private var pendingStartResult: FlutterResult?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let registrar = self.registrar(forPlugin: "BeaconAdvertiser") {
      let channel = FlutterMethodChannel(
        name: channelName,
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { [weak self] call, result in
        self?.handle(call: call, result: result)
      }
    }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "capabilities":
      ensurePeripheralManager()
      result(capabilities())
    case "startIBeacon":
      startIBeacon(call: call, result: result)
    case "startEddystoneUid", "startEddystoneUrl":
      result(FlutterError(
        code: "unavailable",
        message: "Eddystone advertising is not available through iOS public Bluetooth APIs",
        details: nil
      ))
    case "stop":
      peripheralManager?.stopAdvertising()
      pendingIBeacon = nil
      pendingStartResult = nil
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func capabilities() -> [String: Any] {
    let state = peripheralManager?.state ?? .unknown
    let supported = state != .unsupported
    return [
      "isSupported": supported,
      "iBeacon": supported,
      "eddystone": false,
      "platform": "ios",
      "message": supported
        ? "iOS iBeacon advertiser ready; Eddystone advertising unavailable"
        : "Bluetooth LE advertising is unsupported on this device"
    ]
  }

  private func startIBeacon(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let uuidText = args["uuid"] as? String,
      let uuid = UUID(uuidString: uuidText),
      let majorNumber = args["major"] as? NSNumber,
      let minorNumber = args["minor"] as? NSNumber
    else {
      result(FlutterError(code: "bad_args", message: "Missing or invalid iBeacon values", details: nil))
      return
    }

    let major = majorNumber.intValue
    let minor = minorNumber.intValue
    guard (0...65535).contains(major), (0...65535).contains(minor) else {
      result(FlutterError(code: "bad_args", message: "Major and minor must be 0-65535", details: nil))
      return
    }

    let measuredPower = (args["measuredPower"] as? NSNumber)?.intValue ?? -59
    let request = PendingIBeacon(
      uuid: uuid,
      major: UInt16(major),
      minor: UInt16(minor),
      measuredPower: measuredPower,
      result: result
    )

    ensurePeripheralManager()
    guard let manager = peripheralManager else {
      result(FlutterError(code: "unsupported", message: "Bluetooth peripheral manager unavailable", details: nil))
      return
    }

    switch manager.state {
    case .poweredOn:
      advertise(request)
    case .unknown, .resetting:
      pendingIBeacon = request
    case .poweredOff:
      result(FlutterError(code: "bluetooth_off", message: "Bluetooth is off", details: nil))
    case .unauthorized:
      result(FlutterError(code: "unauthorized", message: "Bluetooth advertising is unauthorized", details: nil))
    case .unsupported:
      result(FlutterError(code: "unsupported", message: "Bluetooth LE advertising is unsupported", details: nil))
    @unknown default:
      result(FlutterError(code: "unknown_state", message: "Bluetooth is in an unknown state", details: nil))
    }
  }

  private func ensurePeripheralManager() {
    if peripheralManager == nil {
      peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }
  }

  private func advertise(_ request: PendingIBeacon) {
    let region = CLBeaconRegion(
      uuid: request.uuid,
      major: CLBeaconMajorValue(request.major),
      minor: CLBeaconMinorValue(request.minor),
      identifier: "EddystonePlayground"
    )
    let payload = region.peripheralData(
      withMeasuredPower: NSNumber(value: request.measuredPower)
    ) as NSDictionary
    pendingStartResult = request.result
    peripheralManager?.stopAdvertising()
    peripheralManager?.startAdvertising(payload as? [String: Any])
  }

  func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
    guard let request = pendingIBeacon else {
      return
    }
    switch peripheral.state {
    case .poweredOn:
      pendingIBeacon = nil
      advertise(request)
    case .unknown, .resetting:
      break
    case .poweredOff:
      pendingIBeacon = nil
      request.result(FlutterError(code: "bluetooth_off", message: "Bluetooth is off", details: nil))
    case .unauthorized:
      pendingIBeacon = nil
      request.result(FlutterError(code: "unauthorized", message: "Bluetooth advertising is unauthorized", details: nil))
    case .unsupported:
      pendingIBeacon = nil
      request.result(FlutterError(code: "unsupported", message: "Bluetooth LE advertising is unsupported", details: nil))
    @unknown default:
      pendingIBeacon = nil
      request.result(FlutterError(code: "unknown_state", message: "Bluetooth is in an unknown state", details: nil))
    }
  }

  func peripheralManagerDidStartAdvertising(
    _ peripheral: CBPeripheralManager,
    error: Error?
  ) {
    guard let result = pendingStartResult else {
      return
    }
    pendingStartResult = nil
    if let error {
      result(FlutterError(code: "advertise_failed", message: error.localizedDescription, details: nil))
    } else {
      result(nil)
    }
  }
}

private struct PendingIBeacon {
  let uuid: UUID
  let major: UInt16
  let minor: UInt16
  let measuredPower: Int
  let result: FlutterResult
}
