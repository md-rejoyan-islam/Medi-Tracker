# bluetooth_ble

A cross-platform Flutter app for scanning, connecting to, and inspecting
Bluetooth Low Energy (BLE) devices.

Built with [`flutter_blue_plus`](https://pub.dev/packages/flutter_blue_plus)
(+ `flutter_blue_plus_winrt` for Windows) and `permission_handler`.

## Features

- Scan for nearby BLE devices with live RSSI signal strength
- Connect / disconnect and view connection state
- Discover GATT services and characteristics
- Read characteristics and subscribe to notifications/indications
- Runtime permission handling and Bluetooth adapter state display

## Project structure

```
lib/
  main.dart                 App entry + theme
  ble/ble_service.dart      flutter_blue_plus wrapper (scan, permissions, adapter)
  screens/scan_screen.dart  Device scan list
  screens/device_screen.dart Connect + services/characteristics explorer
```

## Platform support

| Platform | Status | Build requirements |
|----------|--------|--------------------|
| Android  | ✅ Full | Android SDK (install Android Studio) |
| iOS      | ✅ Full | A Mac with Xcode |
| macOS    | ✅ Full | A Mac with Xcode |
| Windows  | ✅ Supported (`flutter_blue_plus_winrt`) | VS Build Tools "Desktop development with C++" workload + **Developer Mode** enabled |
| Linux    | ⚠️ Partial (BlueZ) | `libdbus`, BlueZ; some features limited |

### One-time machine setup (this Windows PC)

The Flutter SDK is installed at `C:\flutter` and on the user PATH.
To build for each target you still need:

- **Windows builds:** enable Developer Mode — run `start ms-settings:developers`
  and toggle it on. Also install the *"Desktop development with C++"*
  workload via the Visual Studio Installer (incl. C++ CMake tools and the
  Windows 10/11 SDK).
- **Android builds:** install [Android Studio](https://developer.android.com/studio),
  let it install the SDK, then run `flutter doctor --android-licenses`.
- **iOS/macOS builds:** require a Mac with Xcode (cannot be built on Windows).

## Run

```sh
flutter pub get
flutter run                 # pick a connected device/emulator
flutter run -d windows      # Windows desktop (after setup above)
flutter run -d android      # Android (after SDK install)
```

## Verify

```sh
flutter analyze             # static analysis — currently clean
flutter test                # widget smoke test — currently passing
```

## Notes

- `flutter_blue_plus` 2.x requires a `License` argument on
  `BluetoothDevice.connect(...)`. This app passes `License.free`, valid for
  personal, educational, and nonprofit use. Commercial use requires the
  paid license — see the flutter_blue_plus LICENSE.
- BLE does not work in the headless test VM; the scan screen fails soft and
  shows an "unavailable on this platform" message instead of crashing.
