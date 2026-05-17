import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Thin wrapper around flutter_blue_plus that centralizes scanning,
/// permission handling and adapter state for the rest of the app.
class BleService {
  BleService._();
  static final BleService instance = BleService._();

  /// Whether this platform has a Bluetooth radio the plugin can drive.
  Future<bool> get isSupported => FlutterBluePlus.isSupported;

  /// Adapter on/off/unauthorized state.
  Stream<BluetoothAdapterState> get adapterState =>
      FlutterBluePlus.adapterState;

  /// Live scan results (deduplicated by the plugin per device).
  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.onScanResults;

  /// Whether a scan is currently running.
  Stream<bool> get isScanning => FlutterBluePlus.isScanning;

  bool get isScanningNow => FlutterBluePlus.isScanningNow;

  /// Requests the runtime permissions BLE needs.
  ///
  /// Android 12+ needs BLUETOOTH_SCAN / BLUETOOTH_CONNECT; older Android
  /// versions need location. iOS/macOS prompt via the usage strings in
  /// Info.plist. Windows/Linux have no runtime prompt, so this is a no-op
  /// there.
  Future<bool> ensurePermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    // A permission that isn't applicable on the current OS reports as
    // granted/denied without a prompt; we only fail on a hard denial of
    // the scan/connect permissions.
    final scan = statuses[Permission.bluetoothScan];
    final connect = statuses[Permission.bluetoothConnect];
    final blocked = scan == PermissionStatus.permanentlyDenied ||
        connect == PermissionStatus.permanentlyDenied;
    return !blocked;
  }

  /// Asks the OS to enable Bluetooth (Android only; no-op elsewhere).
  Future<void> turnOn() async {
    try {
      await FlutterBluePlus.turnOn();
    } catch (_) {
      // turnOn is unsupported on iOS/desktop; the UI guides the user instead.
    }
  }

  Future<void> startScan({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (FlutterBluePlus.isScanningNow) return;
    await FlutterBluePlus.startScan(timeout: timeout);
  }

  Future<void> stopScan() => FlutterBluePlus.stopScan();
}
