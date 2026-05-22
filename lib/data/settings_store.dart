import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:hive_ce_flutter/hive_flutter.dart';

/// Voice language used by the device for reminder prompts (spec §9).
enum ReminderLanguage { english, bengali, bilingual }

/// A BLE device the user has previously paired with.
///
/// Stored as a plain map inside the settings box so we don't need a separate
/// Hive adapter / type id for it. Identity is the BLE remote id (MAC on
/// Android, UUID on iOS).
class KnownDevice {
  KnownDevice({
    required this.id,
    required this.name,
    required this.lastConnected,
  });

  factory KnownDevice.fromMap(Map m) => KnownDevice(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? 'MediTracker',
        lastConnected: DateTime.fromMillisecondsSinceEpoch(
          (m['lastConnected'] as int?) ?? 0,
        ),
      );

  final String id;
  final String name;
  final DateTime lastConnected;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'lastConnected': lastConnected.millisecondsSinceEpoch,
      };
}

/// App + device settings, persisted locally.
///
/// Exposed as a [ValueListenable] so widgets can rebuild reactively without
/// pulling in a state-management package. Keys are plain strings inside one
/// Hive box; values are primitives so no extra adapters are needed.
class SettingsStore extends ChangeNotifier {
  SettingsStore._();
  static final SettingsStore instance = SettingsStore._();

  static const _boxName = 'settings';
  late final Box _box;
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    _box = await Hive.openBox(_boxName);
    _ready = true;
  }

  // --- Appearance -------------------------------------------------------

  /// User-chosen app theme. Defaults to [ThemeMode.system] so the OS
  /// light/dark preference wins until the user picks one explicitly.
  ThemeMode get themeMode => ThemeMode.values[
      (_box.get('theme_mode', defaultValue: ThemeMode.system.index) as int)
          .clamp(0, ThemeMode.values.length - 1)];
  set themeMode(ThemeMode v) {
    _box.put('theme_mode', v.index);
    notifyListeners();
  }

  // --- Voice / reminder behaviour ---------------------------------------

  ReminderLanguage get language => ReminderLanguage
      .values[(_box.get('language', defaultValue: 2) as int)
          .clamp(0, ReminderLanguage.values.length - 1)];
  set language(ReminderLanguage v) {
    _box.put('language', v.index);
    notifyListeners();
  }

  /// 0..100 volume the device should use for the audio reminder.
  int get volume => (_box.get('volume', defaultValue: 80) as int).clamp(0, 100);
  set volume(int v) {
    _box.put('volume', v.clamp(0, 100));
    notifyListeners();
  }

  /// Minutes between repeat chimes if the drawer isn't opened.
  int get repeatIntervalMinutes =>
      (_box.get('repeat_min', defaultValue: 5) as int).clamp(1, 60);
  set repeatIntervalMinutes(int v) {
    _box.put('repeat_min', v.clamp(1, 60));
    notifyListeners();
  }

  /// When true, the foreground app also pops the full-screen reminder when
  /// a dose becomes due. Defaults to **true** so users see something when
  /// they happen to be looking at the phone (the OS notification is also
  /// shown). Can be turned off in Settings → Reminder.
  bool get inAppReminderPopup =>
      _box.get('in_app_reminder', defaultValue: true) as bool;
  set inAppReminderPopup(bool v) {
    _box.put('in_app_reminder', v);
    notifyListeners();
  }

  // --- Paired device ----------------------------------------------------

  /// Human-friendly device name shown on the dashboard.
  String get deviceName =>
      _box.get('device_name', defaultValue: 'MediTracker') as String;
  set deviceName(String v) {
    _box.put('device_name', v.trim().isEmpty ? 'MediTracker' : v.trim());
    notifyListeners();
  }

  /// BLE remote id (MAC on Android / UUID on iOS) of the paired device,
  /// or null if no device is paired yet.
  String? get pairedDeviceId => _box.get('paired_id') as String?;
  set pairedDeviceId(String? v) {
    if (v == null) {
      _box.delete('paired_id');
    } else {
      _box.put('paired_id', v);
    }
    notifyListeners();
  }

  bool get hasPairedDevice => pairedDeviceId != null;

  // --- Connection history -----------------------------------------------
  // Persists every device the user has paired with so the Pair screen can
  // show them as one-tap shortcuts after an app restart.

  static const _historyKey = 'known_devices';

  List<KnownDevice> get knownDevices {
    final raw =
        (_box.get(_historyKey, defaultValue: const <dynamic>[]) as List)
            .cast<dynamic>();
    final list = raw
        .map((e) => KnownDevice.fromMap(Map.from(e as Map)))
        .toList(growable: false);
    // Most recent first.
    list.sort((a, b) => b.lastConnected.compareTo(a.lastConnected));
    return list;
  }

  /// Add (or refresh) a device in the history, capped at 8 entries — the
  /// number of drawers on the hardware doubles as a sensible cap for how
  /// many MediTracker units a household would realistically pair.
  void rememberDevice({required String id, required String name}) {
    final existing = knownDevices.where((d) => d.id != id).toList();
    final updated = <KnownDevice>[
      KnownDevice(id: id, name: name, lastConnected: DateTime.now()),
      ...existing,
    ];
    final capped = updated.take(8).toList();
    _box.put(
      _historyKey,
      capped.map((d) => d.toMap()).toList(growable: false),
    );
    notifyListeners();
  }

  void forgetDevice(String id) {
    final filtered = knownDevices.where((d) => d.id != id).toList();
    _box.put(
      _historyKey,
      filtered.map((d) => d.toMap()).toList(growable: false),
    );
    if (pairedDeviceId == id) pairedDeviceId = null;
    notifyListeners();
  }

  // --- Onboarding -------------------------------------------------------

  /// True once the user has cleared the Welcome screen at least once.
  bool get onboardingComplete =>
      _box.get('onboarded', defaultValue: false) as bool;
  set onboardingComplete(bool v) {
    _box.put('onboarded', v);
    notifyListeners();
  }

  /// True once the user has been walked through the notification /
  /// alarm / battery permission prompts. Lets us run the bKash-style
  /// first-launch permission flow exactly once.
  bool get permissionsOnboardingComplete =>
      _box.get('perm_onboarded', defaultValue: false) as bool;
  set permissionsOnboardingComplete(bool v) {
    _box.put('perm_onboarded', v);
    notifyListeners();
  }
}
