# Build Guide — bluetooth_ble

How to build this Flutter BLE app for **Android, Windows, Linux, macOS, iOS, and Web**.

> Flutter SDK on this machine is at `C:\flutter`. In a terminal opened *after*
> setup, plain `flutter` works. Otherwise use the full path
> `C:\flutter\bin\flutter.bat`.

---

## 0. Common first steps (every platform)

```sh
cd "C:\Users\REJOYAN ISLAM\Desktop\bluetooth-ble"
flutter pub get          # fetch dependencies
flutter analyze          # static checks (should be clean)
flutter test             # widget smoke test (should pass)
flutter devices          # list what you can run/build on
```

Quick run on any connected device/emulator:

```sh
flutter run                 # picks a default device
flutter run -d <id>         # target a specific device from `flutter devices`
flutter run --release       # release-mode run (faster, no debug tools)
```

---

## 1. Android  ✅ (buildable on this Windows PC)

**Requirements**
- Android Studio + Android SDK (installed)
- SDK licenses accepted: `flutter doctor --android-licenses`
- For a *physical device*: enable **USB debugging** and authorize the PC

**Build APK** (single installable file, good for sideloading):

```sh
flutter build apk --release
# output: build\app\outputs\flutter-apk\app-release.apk
```

Smaller, per-architecture APKs:

```sh
flutter build apk --release --split-per-abi
```

**Build App Bundle** (required for Google Play):

```sh
flutter build appbundle --release
# output: build\app\outputs\bundle\release\app-release.aab
```

**Install on a connected phone**

```sh
flutter install
# or
adb install build\app\outputs\flutter-apk\app-release.apk
```

> The default release build is signed with the **debug key** (fine for
> testing/sideloading). For Play Store you must configure a real signing
> key — see "Release signing" at the bottom.

---

## 2. Windows desktop  ⚠️ (needs extra setup on this PC)

**Requirements**
- Enable **Developer Mode**: run `start ms-settings:developers` → toggle ON
  (needed for plugin symlink support)
- Visual Studio (or Build Tools) 2022 with the
  **"Desktop development with C++"** workload, including:
  - MSVC v142+ C++ build tools
  - C++ CMake tools for Windows
  - Windows 10/11 SDK

**Build**

```sh
flutter build windows --release
# output: build\windows\x64\runner\Release\  (bluetooth_ble.exe + DLLs)
```

Run directly:

```sh
flutter run -d windows
```

> Distribute the whole `Release\` folder (the .exe needs the DLLs beside it),
> or package it with an installer (e.g. MSIX via the `msix` package, or Inno
> Setup). Windows BLE is provided by `flutter_blue_plus_winrt`.

---

## 3. Linux desktop  ⚠️ (must build on Linux — cannot build from Windows)

Build on a Linux machine (Ubuntu/Debian example):

**Requirements**

```sh
sudo apt-get update
sudo apt-get install -y clang cmake ninja-build pkg-config \
  libgtk-3-dev liblzma-dev libstdc++-12-dev
# BLE on Linux uses BlueZ over D-Bus:
sudo apt-get install -y libdbus-1-dev bluez
```

Enable Linux desktop + build:

```sh
flutter config --enable-linux-desktop
flutter build linux --release
# output: build/linux/x64/release/bundle/
flutter run -d linux
```

> Linux BLE support is **partial / community-maintained** (via BlueZ). Core
> scan/connect works; some advanced features may be limited.

---

## 4. macOS desktop  ❌ (must build on a Mac)

On a Mac with Xcode installed:

```sh
flutter config --enable-macos-desktop
flutter build macos --release
# output: build/macos/Build/Products/Release/bluetooth_ble.app
flutter run -d macos
```

> Bluetooth entitlement is already configured in
> `macos/Runner/*.entitlements` and `macos/Runner/Info.plist`.
> Cannot be built on Windows — Apple toolchain is macOS-only.

---

## 5. iOS / iPhone  ❌ (must build on a Mac)

On a Mac with **Xcode** + an **Apple ID / Apple Developer account**:

```sh
cd ios && pod install && cd ..      # first time / after plugin changes
flutter build ipa --release
# output: build/ios/ipa/*.ipa
```

Run on a connected iPhone (from the Mac):

```sh
flutter run -d <iphone>
# or open ios/Runner.xcworkspace in Xcode, set your Team, and Run
```

Distribute via **TestFlight** / App Store Connect.

> Bluetooth usage strings are already set in `ios/Runner/Info.plist`.
> iOS apps **cannot** be built on Windows. Use a Mac, or a cloud macOS
> build service (Codemagic, Bitrise, GitHub Actions macOS runners).

---

## 6. Web  ✅ (buildable on this Windows PC)

```sh
flutter build web --release
# output: build\web\   (static site — host on any web server)
flutter run -d chrome
```

> Web BLE uses the **Web Bluetooth API** (Chrome/Edge). It is the most
> limited backend: requires HTTPS (or localhost) and a user click; the
> browser shows its own device-chooser instead of an in-app list.

---

## Build target summary

| Platform | Build on Windows here? | Command | Output |
|----------|------------------------|---------|--------|
| Android  | ✅ Yes | `flutter build apk --release` | `app-release.apk` |
| Windows  | ⚠️ Yes, after C++ workload + Dev Mode | `flutter build windows --release` | `Release\` folder |
| Web      | ✅ Yes | `flutter build web --release` | `build\web\` |
| Linux    | ❌ Build on Linux | `flutter build linux --release` | `bundle/` |
| macOS    | ❌ Build on a Mac | `flutter build macos --release` | `.app` |
| iOS      | ❌ Build on a Mac | `flutter build ipa --release` | `.ipa` |

---

## Release signing (Android, for Play Store)

The debug key is only for testing. For production:

1. Create a keystore:
   ```sh
   keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA \
     -keysize 2048 -validity 10000 -alias upload
   ```
2. Create `android/key.properties`:
   ```properties
   storePassword=<password>
   keyPassword=<password>
   keyAlias=upload
   storeFile=<absolute path to upload-keystore.jks>
   ```
3. Wire it into `android/app/build.gradle`'s `signingConfigs` / `release`
   buildType (replace the debug signing config).
4. Keep the keystore + passwords safe and **out of version control**.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `pub` not recognized | Command is `flutter pub get`, not `pub get` |
| `flutter` not recognized | Open a new terminal (PATH), or use `C:\flutter\bin\flutter.bat` |
| Windows: "requires symlink support" | Enable Developer Mode (`start ms-settings:developers`) |
| Windows: missing C++ components | Install "Desktop development with C++" workload in VS Installer |
| Android licenses not accepted | `flutter doctor --android-licenses` (answer `y`) |
| SDK path has spaces warning | NDK-only; this app builds fine. To remove: move SDK to a space-free path and `flutter config --android-sdk <path>` |
| iOS/macOS build attempted on Windows | Not possible — use a Mac or cloud macOS CI |

See also: [`README.md`](README.md) for project structure and features.
