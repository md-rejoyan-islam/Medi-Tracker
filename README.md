# Medi Tracker

A cross-platform Flutter **medication reminder & adherence tracker** with a
built-in Bluetooth Low Energy toolbox for linking a smart pill dispenser.

Data is stored **locally only** (Hive — no accounts, no network). Reminders
use local notifications; the original BLE explorer is kept as the "Devices"
tab for inspecting and linking hardware.

Built with [`flutter_blue_plus`](https://pub.dev/packages/flutter_blue_plus)
(+ `flutter_blue_plus_winrt` for Windows), `flutter_local_notifications`,
`hive_ce`, and `permission_handler`.

## Features

- Add medications with per-dose times and weekday repeat rules
- Scheduled local-notification reminders at each dose time
- "Today" screen: one-tap **Taken / Skip** for every scheduled dose
- Adherence history: taken / missed / skipped %, overall and per-med
- BLE toolbox: scan, connect, inspect GATT services/characteristics
- Optional auto-logging from a linked BLE pill dispenser (config-driven)

## Project structure

```
lib/
  main.dart                       App entry, Hive/notification init, nav shell
  models/medication.dart          Medication + schedule logic (Hive adapter)
  models/dose_log.dart            Dose log entry (Hive adapter)
  data/medi_store.dart            Hive-backed local store
  data/adherence.dart             Pure schedule/adherence logic (unit-tested)
  services/reminder_service.dart  Scheduled local notifications
  screens/today_screen.dart       Today's doses, Taken/Skip
  screens/medications_screen.dart Medication list
  screens/medication_edit_screen.dart  Add/edit + schedule builder
  screens/history_screen.dart     Adherence stats
  ble/ble_service.dart            flutter_blue_plus wrapper
  ble/pill_dispenser_service.dart Config-driven dispenser → dose-log bridge
  screens/scan_screen.dart        BLE device scan list
  screens/device_screen.dart      Connect + GATT explorer
```

## Linking a BLE pill dispenser

`pill_dispenser_service.dart` is intentionally **inert until configured** —
dispenser GATT layouts are vendor-specific. Supply the device's service
UUID, event-characteristic UUID, and a payload→slot parser via
`PillDispenserService.instance.configure(...)`, set each medication's
`dispenserSlot`, and dispensed doses auto-log as taken.

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
flutter test                # adherence unit tests + widget smoke test — passing
```

## Notes

- `flutter_blue_plus` 2.x requires a `License` argument on
  `BluetoothDevice.connect(...)`. This app passes `License.free`, valid for
  personal, educational, and nonprofit use. Commercial use requires the
  paid license — see the flutter_blue_plus LICENSE.
- BLE does not work in the headless test VM; the scan screen fails soft and
  shows an "unavailable on this platform" message instead of crashing.
- Local notifications are supported on Android, iOS, macOS and Linux. On
  Windows desktop the reminder service degrades to a safe no-op (the rest
  of the app — scheduling, logging, history — works normally).
- Android exact-alarm permission is not required: reminders use
  `inexactAllowWhileIdle`, which the OS may batch by a few minutes.
